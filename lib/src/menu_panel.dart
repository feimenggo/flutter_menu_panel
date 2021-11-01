import 'package:after_layout/after_layout.dart';
import 'package:animations/animations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'menu_item.dart';

/// 菜单展示的位置
enum MenuAlign {
  left, // 鼠标左边
  right, // 鼠标右边
}

/// 关闭菜单
void dismiss(BuildContext context) {
  Navigator.of(context).pop();
}

const double _kMinTileHeight = 40;

/// The [MenuPanel] is the way to use a [_MenuPanelLayout]
///
/// It listens for right click and long press and executes [_showMenuPanelLayout]
/// with the corresponding location [Offset].
class MenuPanel extends StatelessWidget {
  /// The widget displayed inside the [MenuPanel]
  final Widget child;

  /// A [List] of items to be displayed in an opened [_MenuPanelLayout]
  ///
  /// Usually, a [ListTile] might be the way to go.
  final List<MenuItem>? _items;
  final List<MenuItem> Function()? _itemsBuilder;

  /// The width for the [_MenuPanelLayout]. 320 by default according to Material Design specs.
  final double width;

  /// 菜单展示的位置
  final MenuAlign align;

  /// The padding value at the top an bottom between the edge of the [_MenuPanelLayout] and the first / last item
  final double verticalPadding;

  /// 通过items数组传递菜单项
  const MenuPanel({
    Key? key,
    required this.child,
    required List<MenuItem> items,
    this.width = 85,
    this.align = MenuAlign.right,
    this.verticalPadding = 4,
  })  : _items = items,
        _itemsBuilder = null,
        super(key: key);

  /// 通过itemsBuilder按需动态生成菜单项
  const MenuPanel.builder({
    Key? key,
    required this.child,
    required List<MenuItem> Function() itemsBuilder,
    this.width = 85,
    this.align = MenuAlign.right,
    this.verticalPadding = 4,
  })  : _itemsBuilder = itemsBuilder,
        _items = null,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) => _showMenuPanelLayout(
        details.globalPosition,
        context,
      ),
      onSecondaryTapUp: (details) => _showMenuPanelLayout(
        details.globalPosition,
        context,
      ),
      child: child,
    );
  }

  /// Show a [_MenuPanelLayout] on the given [BuildContext]. For other parameters, see [_MenuPanelLayout].
  void _showMenuPanelLayout(Offset offset, BuildContext context) {
    final children = (_items ?? _itemsBuilder!()).map((item) {
      return InkResponse(
        onTap: () {
          Navigator.of(context).pop();
          item.onTap?.call();
        },
        splashColor: Colors.transparent,
        highlightShape: BoxShape.rectangle,
        child: item is CustomMenuItem
            ? item.builder(context)
            : Align(
                child: Text(
                  item.name,
                  style: item.style ??
                      const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
      );
    }).toList(growable: false);
    showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      builder: (context) => _MenuPanelLayout(
        position: offset,
        children: children,
        width: width,
        align: align,
        verticalPadding: verticalPadding,
      ),
    );
  }
}

/// The actual [_MenuPanelLayout] to be displayed
///
/// You will most likely use [_showMenuPanelLayout] to manually display a [_MenuPanelLayout].
///
/// If you just want to use a normal [_MenuPanelLayout], please use [MenuPanel].
class _MenuPanelLayout extends StatefulWidget {
  /// The [Offset] from coordinate origin the [_MenuPanelLayout] will be displayed at.
  final Offset position;

  /// The items to be displayed. [ListTile] is very useful in most cases.
  final List<Widget> children;

  /// The width for the [_MenuPanelLayout]. 320 by default according to Material Design specs.
  final double width;

  /// 菜单展示的位置
  final MenuAlign align;

  /// The padding value at the top an bottom between the edge of the [_MenuPanelLayout] and the first / last item
  final double verticalPadding;

  const _MenuPanelLayout({
    Key? key,
    required this.position,
    required this.children,
    this.width = 85,
    this.align = MenuAlign.right,
    this.verticalPadding = 4,
  }) : super(key: key);

  @override
  _MenuPanelLayoutState createState() => _MenuPanelLayoutState();
}

class _MenuPanelLayoutState extends State<_MenuPanelLayout> {
  final Map<ValueKey, double> _heights = {};

  @override
  Widget build(BuildContext context) {
    double height = 2 * widget.verticalPadding;

    for (var element in _heights.values) {
      height += element;
    }

    final heightsNotAvailable = widget.children.length - _heights.length;
    height += heightsNotAvailable * _kMinTileHeight;

    if (height > MediaQuery.of(context).size.height) {
      height = MediaQuery.of(context).size.height;
    }

    double paddingLeft;
    double paddingRight;
    if (widget.align == MenuAlign.right) {
      paddingLeft = widget.position.dx;
      paddingRight =
          MediaQuery.of(context).size.width - widget.position.dx - widget.width;
      if (paddingRight < 0) {
        paddingLeft += paddingRight;
        paddingRight = 0;
      }
    } else {
      paddingRight = MediaQuery.of(context).size.width - widget.position.dx;
      paddingLeft = widget.position.dx - widget.width;
      if (paddingLeft < 0) {
        paddingRight += paddingLeft;
        paddingLeft = 0;
      }
    }

    double paddingTop = widget.position.dy;
    double paddingBottom =
        MediaQuery.of(context).size.height - widget.position.dy - height;
    if (paddingBottom < 0) {
      paddingTop += paddingBottom;
      paddingBottom = 0;
    }
    return AnimatedPadding(
      padding: EdgeInsets.fromLTRB(
        paddingLeft,
        paddingTop,
        paddingRight,
        paddingBottom,
      ),
      duration: _kShortDuration,
      child: SizedBox.shrink(
        child: Container(
          decoration: BoxDecoration(
            boxShadow: const [
              // 投影
              BoxShadow(
                blurRadius: 12, // 延伸距离，会有模糊效果
                offset: Offset(0, 4), // x,y轴偏移量
                color: Color(0x141D1F4B), // 投影颜色
              ),
            ],
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Material(
              child: ListView(
                primary: false,
                shrinkWrap: true,
                itemExtent: _kMinTileHeight,
                padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
                children: widget.children
                    .map(
                      (e) => _GrowingWidget(
                        child: e,
                        onHeightChange: (height) {
                          setState(() {
                            _heights[ValueKey(e)] = height;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _kShortDuration = Duration(milliseconds: 75);

class _GrowingWidget extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onHeightChange;

  const _GrowingWidget(
      {Key? key, required this.child, required this.onHeightChange})
      : super(key: key);

  @override
  __GrowingWidgetState createState() => __GrowingWidgetState();
}

class __GrowingWidgetState extends State<_GrowingWidget> with AfterLayoutMixin {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Container(
      child: widget.child,
      key: _key,
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    final newHeight = _key.currentContext!.size!.height;
    widget.onHeightChange.call(newHeight);
  }
}
