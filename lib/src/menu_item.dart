import 'package:flutter/material.dart';

/// 文本菜单项
class MenuItem {
  final String name;
  final TextStyle? style;
  final VoidCallback? onTap;

  const MenuItem(
    this.name,
    this.onTap, {
    this.style,
  });
}

/// 自定义菜单项
class CustomMenuItem extends MenuItem {
  final WidgetBuilder builder;

  const CustomMenuItem(this.builder) : super('', null);
}
