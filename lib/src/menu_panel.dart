import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'menu_item.dart';

/// 菜单展示的方向
enum MenuAlign {
  left, // 鼠标左边
  right, // 鼠标右边
}

/// 菜单展示的位置
enum MenuLocation {
  pointer, // 指针处
  childBottomLeft, // child左下角
  childBottomRight, // child右下角
}

/// 菜单数据
class MenuData {
  final int selectIndex;
  final List<TextMenuItem> items;

  MenuData(this.items, {int selectIndex = 0})
      : selectIndex = min(max(selectIndex, 0), items.length);
}

typedef MenuItemBuilder = FutureOr<MenuData> Function(BuildContext context);

/// The [MenuPanel] is the way to use a [_MenuPanelLayout]
///
/// It listens for right click and long press and executes [_showMenuPanelLayout]
/// with the corresponding location [Offset].
class MenuPanel extends StatefulWidget {
  /// 条目最小高度
  static const double kMinItemHeight = 40;

  /// 关闭菜单面板
  static void dismiss(BuildContext context, {bool useRootNavigator = true}) {
    Navigator.of(context, rootNavigator: useRootNavigator).pop();
  }

  /// The widget displayed inside the [MenuPanel]
  final Widget child;

  /// A [List] of items to be displayed in an opened [_MenuPanelLayout]
  ///
  /// Usually, a [ListTile] might be the way to go.
  final List<TextMenuItem>? _items;
  final MenuItemBuilder? _itemsBuilder;

  /// The width for the [_MenuPanelLayout]. 320 by default according to Material Design specs.
  final double width;

  /// 菜单展示的方向
  final MenuAlign align;

  /// 菜单展示的位置
  final MenuLocation location;

  /// 菜单展示的偏移量
  final Offset offset;

  /// The padding value at the top an bottom between the edge of the [_MenuPanelLayout] and the first / last item
  final double verticalPadding;

  final Alignment alignment;

  final EdgeInsets padding;

  final double? height;
  final double maxHeight;

  final bool useRootNavigator;

  final GestureTapCallback? onTapUp;

  final bool enableLongPress;

  /// 鼠标样式
  final MouseCursor? cursor;

  final VoidCallback? onShow;
  final VoidCallback? onHide;

  /// 通过items数组传递菜单项
  const MenuPanel({
    Key? key,
    required this.child,
    required List<TextMenuItem> items,
    this.width = 85,
    this.align = MenuAlign.right,
    this.location = MenuLocation.pointer,
    this.offset = Offset.zero,
    this.alignment = Alignment.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.verticalPadding = 4,
    this.height,
    this.maxHeight = 0,
    this.useRootNavigator = true,
    this.onTapUp,
    this.enableLongPress = false,
    this.cursor = SystemMouseCursors.click,
    this.onShow,
    this.onHide,
  })  : _items = items,
        _itemsBuilder = null,
        super(key: key);

  /// 通过itemsBuilder按需动态生成菜单项
  const MenuPanel.builder({
    Key? key,
    required this.child,
    required MenuItemBuilder itemsBuilder,
    this.width = 85,
    this.align = MenuAlign.right,
    this.location = MenuLocation.pointer,
    this.offset = Offset.zero,
    this.alignment = Alignment.centerLeft,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.verticalPadding = 4,
    this.height,
    this.maxHeight = 0,
    this.useRootNavigator = true,
    this.onTapUp,
    this.enableLongPress = false,
    this.cursor = SystemMouseCursors.click,
    this.onShow,
    this.onHide,
  })  : _itemsBuilder = itemsBuilder,
        _items = null,
        super(key: key);

  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> {
  final GlobalKey _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (widget.location == MenuLocation.pointer) {
      onPointerTap(TapUpDetails details) =>
          _onPointerTap(details.globalPosition);
      child = GestureDetector(
        key: _childKey,
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.onTapUp != null
            ? (details) => widget.onTapUp!.call()
            : onPointerTap,
        onSecondaryTapUp: onPointerTap,
        onLongPressStart: widget.enableLongPress
            ? (details) => _onPointerTap(details.globalPosition)
            : null,
        child: widget.child,
      );
    } else {
      child = GestureDetector(
        key: _childKey,
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTapUp ?? _onTargetTap,
        onSecondaryTap: _onTargetTap,
        child: widget.child,
      );
    }
    if (widget.cursor != null) {
      child = MouseRegion(cursor: widget.cursor!, child: child);
    }
    return child;
  }

  void _onPointerTap(Offset globalPosition) {
    if (Platform.isAndroid || Platform.isIOS) {
      final renderBox =
          _childKey.currentContext!.findRenderObject() as RenderBox;
      globalPosition -= Offset(0, renderBox.size.height); // 需要减去自身高度
    }
    _showMenuPanelLayout(globalPosition);
  }

  void _onTargetTap() {
    final renderBox = _childKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    Offset offset;
    if (Platform.isAndroid || Platform.isIOS) {
      // 移动端localToGlobal已经包含自身高度
      if (widget.location == MenuLocation.childBottomLeft) {
        offset = position;
      } else {
        offset = position + Offset(size.width, 0);
      }
    } else {
      if (widget.location == MenuLocation.childBottomLeft) {
        offset = position + Offset(0, size.height);
      } else {
        offset = position + Offset(size.width, size.height);
      }
    }
    _showMenuPanelLayout(offset);
  }

  /// Show a [_MenuPanelLayout] on the given [BuildContext]. For other parameters, see [_MenuPanelLayout].
  void _showMenuPanelLayout(Offset location) async {
    int initSelectIndex;
    List<TextMenuItem> items;
    if (widget._items != null) {
      items = widget._items!;
      initSelectIndex = 0;
    } else {
      final result = widget._itemsBuilder!(context);
      if (result is Future<MenuData>) {
        final data = await result;
        items = data.items;
        initSelectIndex = data.selectIndex;
      } else {
        items = result.items;
        initSelectIndex = result.selectIndex;
      }
    }
    if (!mounted) return;
    final children = items.map((item) {
      if (item is CustomMenuItem) return item.builder(context);
      return InkResponse(
        onTap: () {
          MenuPanel.dismiss(context, useRootNavigator: widget.useRootNavigator);
          item.onTap?.call();
        },
        splashColor: Colors.transparent,
        highlightShape: BoxShape.rectangle,
        child: Container(
          padding: widget.padding,
          alignment: widget.alignment,
          height: MenuPanel.kMinItemHeight,
          child: Text(
            item.name,
            style: item.style ??
                const TextStyle(
                  color: Color(0xFF242A39),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );
    }).toList(growable: false);
    widget.onShow?.call();
    await showModal(
      context: context,
      useRootNavigator: widget.useRootNavigator,
      configuration: const FadeScaleTransitionConfiguration(
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
      builder: (context) => _MenuPanelLayout(
        position: location + widget.offset,
        width: widget.width,
        align: widget.align,
        verticalPadding: widget.verticalPadding,
        height: widget.height,
        maxHeight: widget.maxHeight,
        initSelectIndex: initSelectIndex,
        children: children,
      ),
    );
    widget.onHide?.call();
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

  final double? height;
  final double maxHeight;

  final int initSelectIndex;

  const _MenuPanelLayout(
      {Key? key,
      required this.position,
      required this.children,
      this.width = 85,
      this.align = MenuAlign.right,
      this.verticalPadding = 4,
      this.height,
      this.maxHeight = 0,
      this.initSelectIndex = 0})
      : super(key: key);

  @override
  _MenuPanelLayoutState createState() => _MenuPanelLayoutState();
}

class _MenuPanelLayoutState extends State<_MenuPanelLayout> {
  final Map<ValueKey, double> _heights = {};
  ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    double height = 2 * widget.verticalPadding;

    if (widget.height == null) {
      for (var element in _heights.values) {
        height += element;
      }

      final heightsNotAvailable = widget.children.length - _heights.length;
      height += heightsNotAvailable * MenuPanel.kMinItemHeight;

      if (height > size.height) {
        height = size.height;
      }

      if (widget.maxHeight != 0 && height > widget.maxHeight) {
        height = widget.maxHeight;
      }
    } else {
      height = widget.height!;
    }

    // 移动端需要加上状态栏高度
    final viewPaddingTop =
        View.of(context).viewPadding.top / View.of(context).devicePixelRatio;
    height += viewPaddingTop;

    double paddingLeft;
    double paddingRight;
    if (widget.align == MenuAlign.right) {
      paddingLeft = widget.position.dx;
      paddingRight = size.width - widget.position.dx - widget.width;
      if (paddingRight < 0) {
        paddingLeft += paddingRight;
        paddingRight = 0;
      }
    } else {
      paddingRight = size.width - widget.position.dx;
      paddingLeft = widget.position.dx - widget.width;
      if (paddingLeft < 0) {
        paddingRight += paddingLeft;
        paddingLeft = 0;
      }
    }

    double paddingTop = widget.position.dy;
    double paddingBottom = size.height - widget.position.dy - height;
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
                offset: Offset(0, 2), // x,y轴偏移量
                color: Color(0x33000000), // 投影颜色
              ),
            ],
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: ListView(
                primary: false,
                shrinkWrap: true,
                controller: scrollController ??= ScrollController(
                    initialScrollOffset: widget.initSelectIndex >= 0
                        ? widget.initSelectIndex * MenuPanel.kMinItemHeight
                        : 0),
                padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
                children: widget.children.map((e) {
                  return _GrowingWidget(
                    child: e,
                    onHeightChange: (height) {
                      setState(() => _heights[ValueKey(e)] = height);
                    },
                  );
                }).toList(),
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

class __GrowingWidgetState extends State<_GrowingWidget>
    with AfterLayoutMixin<_GrowingWidget> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      child: widget.child,
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    if (mounted) {
      final newHeight = _key.currentContext!.size!.height;
      widget.onHeightChange.call(newHeight);
    }
  }
}

mixin AfterLayoutMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then(
      (_) {
        if (mounted) afterFirstLayout(context);
      },
    );
  }

  void afterFirstLayout(BuildContext context);
}
