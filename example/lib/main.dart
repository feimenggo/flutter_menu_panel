import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_menu_panel/flutter_menu_panel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int positionIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Panel')),
      // backgroundColor: Colors.green,
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: MenuPanel(
                position: MenuPosition.topLeft,
                builder: buildItems,
                child: Content(MenuPosition.topLeft.name),
              ),
            ),
            Positioned(
              top: 0,
              child: MenuPanel(
                position: MenuPosition.topCenter,
                builder: buildItems,
                child: Content(MenuPosition.topCenter.name),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: MenuPanel(
                position: MenuPosition.topRight,
                builder: buildItems,
                child: Content(MenuPosition.topRight.name),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: MenuPanel(
                position: MenuPosition.bottomLeft,
                builder: buildItems,
                child: Content(MenuPosition.bottomLeft.name),
              ),
            ),
            Positioned(
              bottom: 0,
              child: MenuPanel(
                position: MenuPosition.bottomCenter,
                builder: buildItems,
                child: Content(MenuPosition.bottomCenter.name),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: MenuPanel(
                position: MenuPosition.bottomRight,
                builder: buildItems,
                child: Content(MenuPosition.bottomRight.name),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MenuPanel(
                  enablePointer: true,
                  position: MenuPosition
                      .values[positionIndex % MenuPosition.values.length],
                  builder: buildItems,
                  child: Content(
                    MenuPosition
                        .values[positionIndex % MenuPosition.values.length]
                        .name,
                    width: 150,
                  ),
                ),
                const SizedBox(height: 12),
                MenuPanel(
                  enablePointer: true,
                  position: MenuPosition
                      .values[positionIndex % MenuPosition.values.length],
                  height: 128,
                  builder: buildList,
                  child: Content(
                    MenuPosition
                        .values[positionIndex % MenuPosition.values.length]
                        .name,
                    width: 150,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: () => setState(() => positionIndex++),
                    child: const Text('切换位置')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  FutureOr<MenuData> buildItems(BuildContext context) {
    return MenuData([
      TextMenuItem('书籍设置', () {
        if (kDebugMode) print('点击：书籍设置');
      }),
      TextMenuItem('书籍预览', () {
        if (kDebugMode) print('点击：书籍预览');
      }),
      TextMenuItem('导出书籍', () {
        if (kDebugMode) print('点击：导出书籍');
      }),
      TextMenuItem('导入章节', () {
        if (kDebugMode) print('点击：导入章节');
      }),
      TextMenuItem('移至分组', () {
        if (kDebugMode) print('点击：移至分组');
      }),
      TextMenuItem(
        '删除书籍',
        () {
          if (kDebugMode) print('点击：删除书籍');
        },
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    ]);
  }

  FutureOr<MenuData> buildList(BuildContext context) {
    return MenuData(
        List.generate(
            100,
            (index) => TextMenuItem('字体$index', () {
                  if (kDebugMode) print('点击：字体$index');
                })),
        initialIndex: 55);
  }
}

class Content extends StatelessWidget {
  final String name;
  final double? width;

  const Content(this.name, {Key? key, this.width}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? 120,
      height: 50,
      color: Theme.of(context).primaryColor,
      child: Center(
        child: Text(
          name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
