import 'dart:async';

import 'package:flutter/material.dart';

import 'custom_menu.dart';

const kItemHeight = 40.0;

typedef MenuWidgetBuilder = Widget Function(
    BuildContext context, CustomMenuController controller);

/// 文本菜单项
class TextMenuItem {
  final String name;
  final TextStyle? style;
  final VoidCallback? onTap;

  const TextMenuItem(this.name, this.onTap, {this.style});
}

/// 自定义菜单项
class CustomMenuItem extends TextMenuItem {
  final MenuWidgetBuilder builder;

  const CustomMenuItem(this.builder, {VoidCallback? onTap}) : super('', onTap);
}

/// 菜单数据
class MenuData {
  final List<TextMenuItem> items;
  final int? initialIndex; // 初始滚动定位

  MenuData(this.items, {this.initialIndex});
}

/// 构造菜单数据
typedef MenuDataBuilder = FutureOr<MenuData> Function(BuildContext context);

/// 菜单面板
class MenuPanel extends StatefulWidget {
  const MenuPanel({
    super.key,
    required this.child,
    required this.builder,
    this.controller,
    this.width = 100,
    this.height,
    this.maxHeight,
    this.position = MenuPosition.bottomAlignLeft,
    this.itemExtent,
    this.itemHeight = kItemHeight,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.listPadding = const EdgeInsets.symmetric(vertical: 4),
    this.itemAlignment = Alignment.centerLeft,
    this.offset = Offset.zero,
    this.splashColor,
    this.barrierColor = Colors.transparent,
    this.backgroundColor = Colors.white,
    this.backgroundShadow = const BoxShadow(
        blurRadius: 24, offset: Offset(0, 4), color: Color(0x33000000)),
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.onTap,
    this.enablePress = true,
    this.enableLongPress = false,
    this.enablePointer = false,
    this.enablePassEvent = true,
    this.style,
    this.below,
    this.onShow,
    this.onHide,
    this.rootOverlay,
    this.cursor = SystemMouseCursors.click,
  });

  final CustomMenuController? controller;
  final Widget child;
  final double width;
  final double? height;
  final double? maxHeight;
  final Offset offset;
  final Color? splashColor;
  final Color barrierColor;
  final Color backgroundColor;
  final BoxShadow backgroundShadow;
  final MenuPosition position;
  final MenuDataBuilder builder;
  final double? itemExtent;
  final double itemHeight;
  final EdgeInsetsGeometry itemPadding;
  final EdgeInsetsGeometry listPadding;
  final AlignmentGeometry itemAlignment;
  final BorderRadiusGeometry? borderRadius;
  final VoidCallback? onTap;
  final bool enablePress;
  final bool enableLongPress;
  final bool enablePointer;
  final bool enablePassEvent;
  final TextStyle? style;
  final OverlayEntry? below;
  final VoidCallback? onShow;
  final VoidCallback? onHide;
  final bool? rootOverlay;

  /// 鼠标样式
  final MouseCursor? cursor;

  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> {
  late final controller = widget.controller ?? CustomMenuController();
  ScrollController? scrollController;

  @override
  void dispose() {
    super.dispose();
    if (widget.controller == null) controller.dispose();
    scrollController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomMenu(
      controller: controller,
      offset: widget.offset,
      position: widget.position,
      barrierColor: widget.barrierColor,
      onTap: widget.onTap,
      enablePress: widget.enablePress,
      enableLongPress: widget.enableLongPress,
      enablePointer: widget.enablePointer,
      enablePassEvent: widget.enablePassEvent,
      below: widget.below,
      menuBuilder: buildMenu,
      onShow: widget.onShow,
      onHide: widget.onHide,
      rootOverlay: widget.rootOverlay,
      child: widget.child,
    );
  }

  Future<Widget> buildMenu() async {
    final menuData = await widget.builder(context);
    List<TextMenuItem> items = menuData.items;
    double? itemExtent = widget.itemExtent ?? widget.itemHeight;
    final children = items.map((item) {
      Widget child;
      if (item is CustomMenuItem) {
        if (widget.itemExtent == null) itemExtent = null;
        child = item.builder(context, controller);
      } else {
        child = Container(
          height: widget.itemHeight,
          padding: widget.itemPadding,
          alignment: widget.itemAlignment,
          child: Text(
            item.name,
            style: item.style ??
                widget.style ??
                const TextStyle(
                  color: Color(0xFF242A39),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
          ),
        );
      }
      if (item.onTap != null) {
        child = InkWell(
          onTap: () {
            controller.hideMenu();
            item.onTap!.call();
          },
          splashColor: widget.splashColor,
          child: child,
        );
      }
      return child;
    }).toList(growable: false);
    // 初始滚动定位
    if (menuData.initialIndex != null && menuData.initialIndex! > 0) {
      assert(
          itemExtent != null, '当CustomMenuItem使用initialIndex时，需要设置itemExtent');
      scrollController?.dispose();
      scrollController = ScrollController(
          initialScrollOffset: menuData.initialIndex! * itemExtent!);
    } else {
      scrollController?.dispose();
      scrollController = ScrollController();
    }
    return Container(
      width: widget.width,
      height: widget.height,
      constraints: widget.maxHeight != null
          ? BoxConstraints(maxHeight: widget.maxHeight!)
          : null,
      decoration: BoxDecoration(boxShadow: [widget.backgroundShadow]),
      child: Material(
        color: widget.backgroundColor,
        borderRadius: widget.borderRadius,
        child: ListView(
          primary: false,
          shrinkWrap: true,
          itemExtent: itemExtent,
          controller: scrollController,
          padding: widget.listPadding,
          children: children,
        ),
      ),
    );
  }
}
