import 'dart:async';

import 'package:flutter/material.dart';

import 'custom_menu.dart';
import 'menu_item.dart';

const kItemHeight = 40.0;

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
    this.enablePointer = false,
    this.enableLongPress = false,
    this.below,
  });

  final CustomMenuController? controller;
  final Widget child;
  final double width;
  final double? height;
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
  final bool enablePointer;
  final bool enableLongPress;
  final OverlayEntry? below;

  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> {
  late final controller = widget.controller ?? CustomMenuController();
  ScrollController? scrollController;

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
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
      enablePointer: widget.enablePointer,
      enableLongPress: widget.enableLongPress,
      below: widget.below,
      menuBuilder: buildMenu,
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
        child = item.builder(context);
      } else {
        child = Container(
          height: widget.itemHeight,
          padding: widget.itemPadding,
          alignment: widget.itemAlignment,
          child: Text(
            item.name,
            style: item.style ??
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
