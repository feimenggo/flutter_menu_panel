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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu Panel')),
      body: Align(
        alignment: Alignment.topCenter,
        child: MenuPanel(
          align: MenuAlign.left,
          location: MenuLocation.childBottomRight,
          items: [
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
          ],
          child: Container(
            width: 100,
            height: 50,
            color: Theme.of(context).primaryColor,
            child: Center(
              child: Text(
                '打开菜单',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
