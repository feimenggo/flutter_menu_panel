import 'package:flutter/material.dart';

/// 文本菜单项
class TextMenuItem {
  final String name;
  final TextStyle? style;
  final VoidCallback? onTap;

  const TextMenuItem(
    this.name,
    this.onTap, {
    this.style,
  });
}

/// 自定义菜单项
class CustomMenuItem extends TextMenuItem {
  final WidgetBuilder builder;

  const CustomMenuItem(this.builder) : super('', null);
}
