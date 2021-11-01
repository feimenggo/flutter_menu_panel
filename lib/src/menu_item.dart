import 'package:flutter/material.dart';

class MenuItem {
  final String name;
  final TextStyle? style;

  // final List<SubMenuItem>? subItems;
  final VoidCallback? onTap;

  MenuItem(
    this.name,
    this.onTap, {
    this.style,
    // this.subItems
  });
}

// class SubMenuItem extends MenuItem {
//   SubMenuItem(String name, VoidCallback? onTap) : super(name, onTap);
// }
