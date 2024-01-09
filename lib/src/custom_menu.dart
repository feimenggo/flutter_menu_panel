import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

enum MenuPosition {
  topLeft,
  topAlignLeft,
  topCenter,
  topRight,
  topAlignRight,
  bottomLeft,
  bottomAlignLeft, // 默认
  bottomCenter,
  bottomRight,
  bottomAlignRight,
}

class CustomMenuController extends ChangeNotifier {
  bool menuIsShowing = false;
  Offset? globalPosition;

  void showMenu([Offset? globalPosition]) {
    menuIsShowing = true;
    this.globalPosition = globalPosition;
    notifyListeners();
  }

  void hideMenu() {
    menuIsShowing = false;
    globalPosition = null;
    notifyListeners();
  }

  void toggleMenu() {
    if (menuIsShowing) {
      hideMenu();
    } else {
      showMenu();
    }
  }
}

Rect _menuRect = Rect.zero;

class CustomMenu extends StatefulWidget {
  const CustomMenu({
    super.key,
    required this.child,
    required this.menuBuilder,
    this.controller,
    this.offset = Offset.zero,
    this.barrierColor = Colors.transparent,
    this.position = MenuPosition.bottomAlignLeft,
    this.onMenuChange,
    this.enablePassEvent = true,
    this.below,
    this.onTap,
    this.enablePress = true,
    this.enableLongPress = false,
    this.enablePointer = false,
    this.onShow,
    this.onHide,
    this.rootOverlay,
    this.cursor,
  });

  final Widget child;
  final FutureOr<Widget> Function() menuBuilder;
  final CustomMenuController? controller;
  final Offset offset;
  final Color barrierColor;
  final MenuPosition position;
  final void Function(bool)? onMenuChange;
  final VoidCallback? onTap;
  final bool enablePress;
  final bool enableLongPress;
  final bool enablePointer;
  final OverlayEntry? below;

  /// Pass tap event to the widgets below the mask.
  /// It only works when [barrierColor] is transparent.
  final bool enablePassEvent;

  final VoidCallback? onShow;
  final VoidCallback? onHide;
  final bool? rootOverlay;

  /// 鼠标样式
  final MouseCursor? cursor;

  @override
  CustomMenuState createState() => CustomMenuState();
}

class CustomMenuState extends State<CustomMenu> {
  late final _controller = widget.controller ?? CustomMenuController();
  bool _canResponse = true;
  Offset? _cachePointer;
  OverlayEntry? _overlayEntry;

  Future<void> _showMenu(Offset? globalPosition) async {
    final menuChild = await widget.menuBuilder();
    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        MediaQuery.sizeOf(ctx); // 监听窗口尺寸变化
        final childBox = context.findRenderObject() as RenderBox;
        final parentBox =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        // print('pSize:${parentBox.size} cSize:${childBox.size}');
        Widget menu = Container(
          constraints: BoxConstraints(
            minWidth: 0,
            maxWidth: parentBox.size.width,
          ),
          child: CustomMultiChildLayout(
            delegate: _MenuLayoutDelegate(
              position: widget.position,
              anchorSize: childBox.size,
              anchorOffset: childBox.localToGlobal(widget.offset),
              targetOffset: globalPosition,
            ),
            children: <Widget>[
              LayoutId(
                  id: 0,
                  child: Material(color: Colors.transparent, child: menuChild))
            ],
          ),
        );
        return Listener(
          behavior: widget.enablePassEvent
              ? HitTestBehavior.translucent
              : HitTestBehavior.opaque,
          onPointerDown: (PointerDownEvent event) {
            Offset offset = event.localPosition;
            // If tap position in menu
            if (_menuRect.contains(Offset(offset.dx, offset.dy))) return;
            _controller.hideMenu();
            // When [enablePassEvent] works and we tap the [child] to [hideMenu],
            // but the passed event would trigger [showMenu] again.
            // So, we use time threshold to solve this bug.
            _canResponse = false;
            Future.delayed(const Duration(milliseconds: 300))
                .then((_) => _canResponse = true);
          },
          child: widget.barrierColor == Colors.transparent
              ? menu
              : ColoredBox(color: widget.barrierColor, child: menu),
        );
      },
    );
    if (mounted) {
      Overlay.of(context, rootOverlay: widget.rootOverlay ?? true)
          .insert(_overlayEntry!, below: widget.below);
      widget.onShow?.call();
    }
  }

  void _hideMenu() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      widget.onHide?.call();
    }
  }

  void _updateView() {
    bool menuIsShowing = _controller.menuIsShowing;
    widget.onMenuChange?.call(menuIsShowing);
    if (menuIsShowing) {
      _showMenu(_controller.globalPosition);
    } else {
      _hideMenu();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateView);
  }

  @override
  void dispose() {
    _hideMenu();
    _controller.removeListener(_updateView);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enablePress ? widget.onTap ?? onTap : null,
      onLongPress: widget.enableLongPress ? onTap : null,
      onSecondaryTapUp: widget.enablePointer
          ? (TapUpDetails details) => _cachePointer = details.globalPosition
          : null,
      onSecondaryTap: widget.enablePointer
          ? () {
              if (_canResponse) _controller.showMenu(_cachePointer);
            }
          : null,
      child: widget.child,
    );
    if (widget.cursor != null) {
      child = MouseRegion(cursor: widget.cursor!, child: child);
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      child = MouseRegion(cursor: SystemMouseCursors.click, child: child);
    }
    if (Platform.isIOS) {
      return child;
    } else {
      return WillPopScope(
        onWillPop: () {
          _hideMenu();
          return Future.value(true);
        },
        child: child,
      );
    }
  }

  void onTap() {
    if (_canResponse) _controller.showMenu();
  }
}

class _MenuLayoutDelegate extends MultiChildLayoutDelegate {
  _MenuLayoutDelegate({
    required this.position,
    required this.anchorSize,
    required this.anchorOffset,
    required this.targetOffset,
  });

  final MenuPosition position;
  final Size anchorSize;
  final Offset anchorOffset;
  final Offset? targetOffset;

  @override
  void performLayout(Size size) {
    Size contentSize = layoutChild(0, BoxConstraints.loose(size));
    Offset contentOffset;
    if (targetOffset != null) {
      contentOffset = targetOffset!;
    } else {
      double anchorLeftX = anchorOffset.dx;
      double anchorRightX = anchorOffset.dx + anchorSize.width;
      double anchorCenterX = anchorOffset.dx + anchorSize.width / 2;
      double anchorTopY = anchorOffset.dy;
      double anchorBottomY = anchorTopY + anchorSize.height;
      switch (position) {
        case MenuPosition.topLeft:
          contentOffset = Offset(
            anchorLeftX - contentSize.width,
            anchorTopY - contentSize.height,
          );
          break;
        case MenuPosition.topAlignLeft:
          contentOffset = Offset(
            anchorLeftX,
            anchorTopY - contentSize.height,
          );
          break;
        case MenuPosition.topCenter:
          contentOffset = Offset(
            anchorCenterX - contentSize.width / 2,
            anchorTopY - contentSize.height,
          );
          break;
        case MenuPosition.topRight:
          contentOffset = Offset(
            anchorRightX,
            anchorTopY - contentSize.height,
          );
          break;
        case MenuPosition.topAlignRight:
          contentOffset = Offset(
            anchorRightX - contentSize.width,
            anchorTopY - contentSize.height,
          );
          break;
        case MenuPosition.bottomLeft:
          contentOffset = Offset(
            anchorLeftX - contentSize.width,
            anchorBottomY,
          );
          break;
        case MenuPosition.bottomAlignLeft:
          contentOffset = Offset(
            anchorLeftX,
            anchorBottomY,
          );
          break;
        case MenuPosition.bottomCenter:
          contentOffset = Offset(
            anchorCenterX - contentSize.width / 2,
            anchorBottomY,
          );
          break;
        case MenuPosition.bottomRight:
          contentOffset = Offset(
            anchorRightX,
            anchorBottomY,
          );
          break;
        case MenuPosition.bottomAlignRight:
          contentOffset = Offset(
            anchorRightX - contentSize.width,
            anchorBottomY,
          );
          break;
      }
    }

    if (contentOffset.dy < 0) {
      contentOffset = Offset(contentOffset.dx, 0);
    } else {
      double bottomOver = size.height - (contentOffset.dy + contentSize.height);
      if (bottomOver < 0) {
        contentOffset = Offset(contentOffset.dx, contentOffset.dy + bottomOver);
      }
    }

    if (contentOffset.dx < 0) {
      contentOffset = Offset(0, contentOffset.dy);
    } else {
      double rightOver = size.width - (contentOffset.dx + contentSize.width);
      if (rightOver < 0) {
        contentOffset = Offset(contentOffset.dx + rightOver, contentOffset.dy);
      }
    }

    positionChild(0, contentOffset);

    _menuRect = Rect.fromLTWH(
      contentOffset.dx,
      contentOffset.dy,
      contentSize.width,
      contentSize.height,
    );
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) => false;
}
