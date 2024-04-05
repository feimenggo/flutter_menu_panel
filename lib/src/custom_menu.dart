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

  void toggleMenu([Offset? globalPosition]) {
    if (menuIsShowing) {
      hideMenu();
    } else {
      showMenu(globalPosition);
    }
  }
}

List<CustomMenuState>? _menuStates;

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
    this.enablePassEvent = false,
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
  final FutureOr<Widget> Function(CustomMenuController controller) menuBuilder;
  final CustomMenuController? controller;
  final Offset offset;
  final Color barrierColor;
  final MenuPosition position;
  final void Function(bool)? onMenuChange;
  final void Function(CustomMenuController controller)? onTap;
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
  Rect? _layoutRect;

  void _updateView() {
    bool menuIsShowing = _controller.menuIsShowing;
    widget.onMenuChange?.call(menuIsShowing);
    if (menuIsShowing) {
      _showMenu(_controller.globalPosition);
    } else {
      _hideMenu();
    }
  }

  Future<void> _showMenu(Offset? globalPosition) async {
    if (_overlayEntry != null) return;
    final menuChild = await widget.menuBuilder(_controller);
    if (mounted) {
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
            child: CustomSingleChildLayout(
              delegate: _MenuLayoutDelegate(
                  position: widget.position,
                  anchorSize: childBox.size,
                  anchorOffset: childBox.localToGlobal(widget.offset),
                  targetOffset: globalPosition,
                  onLayoutChange: (Rect rect) => _layoutRect = rect),
              child: Material(color: Colors.transparent, child: menuChild),
            ),
          );
          return Listener(
            behavior: widget.enablePassEvent
                ? HitTestBehavior.translucent
                : HitTestBehavior.opaque,
            onPointerDown: (PointerDownEvent event) {
              Offset offset = event.localPosition;
              // If tap position in menu
              if (_menuStates != null) {
                for (var state in _menuStates!) {
                  if (state._layoutRect
                          ?.contains(Offset(offset.dx, offset.dy)) ??
                      false) return;
                }
              }
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
      if (_menuStates == null) {
        _menuStates = [this];
      } else {
        _menuStates!.add(this);
      }
      Overlay.of(context, rootOverlay: widget.rootOverlay ?? true)
          .insert(_overlayEntry!, below: widget.below);
      widget.onShow?.call();
    }
  }

  void _hideMenu() {
    if (_overlayEntry == null) return;
    if (_menuStates!.length > 1) {
      _menuStates!.remove(this);
    } else {
      _menuStates = null;
    }
    _overlayEntry!.remove();
    _overlayEntry = null;
    widget.onHide?.call();
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
      onTap: widget.enablePress
          ? (widget.onTap != null ? () => widget.onTap!(_controller) : onTap)
          : null,
      onLongPress: widget.enableLongPress ? onTap : null,
      onSecondaryTapUp: widget.enablePointer
          ? (TapUpDetails details) => _cachePointer = details.globalPosition
          : null,
      onSecondaryTap: widget.enablePointer
          ? () {
              if (_canResponse) _controller.toggleMenu(_cachePointer);
            }
          : null,
      child: widget.child,
    );
    if (widget.cursor != null) {
      child = MouseRegion(cursor: widget.cursor!, child: child);
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      child = MouseRegion(cursor: SystemMouseCursors.click, child: child);
    }
    if (Platform.isAndroid) {
      return PopScope(onPopInvoked: (_) => _hideMenu(), child: child);
    } else {
      return child;
    }
  }

  void onTap() {
    if (_canResponse) _controller.toggleMenu();
  }
}

class _MenuLayoutDelegate extends SingleChildLayoutDelegate {
  _MenuLayoutDelegate({
    required this.position,
    required this.anchorSize,
    required this.anchorOffset,
    required this.targetOffset,
    required this.onLayoutChange,
  });

  final MenuPosition position;
  final Size anchorSize;
  final Offset anchorOffset;
  final Offset? targetOffset;
  final void Function(Rect rect) onLayoutChange;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.smallest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
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
            anchorLeftX - childSize.width,
            anchorTopY - childSize.height,
          );
          break;
        case MenuPosition.topAlignLeft:
          contentOffset = Offset(
            anchorLeftX,
            anchorTopY - childSize.height,
          );
          break;
        case MenuPosition.topCenter:
          contentOffset = Offset(
            anchorCenterX - childSize.width / 2,
            anchorTopY - childSize.height,
          );
          break;
        case MenuPosition.topRight:
          contentOffset = Offset(
            anchorRightX,
            anchorTopY - childSize.height,
          );
          break;
        case MenuPosition.topAlignRight:
          contentOffset = Offset(
            anchorRightX - childSize.width,
            anchorTopY - childSize.height,
          );
          break;
        case MenuPosition.bottomLeft:
          contentOffset = Offset(
            anchorLeftX - childSize.width,
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
            anchorCenterX - childSize.width / 2,
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
            anchorRightX - childSize.width,
            anchorBottomY,
          );
          break;
      }
    }

    if (contentOffset.dy < 0) {
      contentOffset = Offset(contentOffset.dx, 0);
    } else {
      double bottomOver = size.height - (contentOffset.dy + childSize.height);
      if (bottomOver < 0) {
        contentOffset = Offset(contentOffset.dx, contentOffset.dy + bottomOver);
      }
    }

    if (contentOffset.dx < 0) {
      contentOffset = Offset(0, contentOffset.dy);
    } else {
      double rightOver = size.width - (contentOffset.dx + childSize.width);
      if (rightOver < 0) {
        contentOffset = Offset(contentOffset.dx + rightOver, contentOffset.dy);
      }
    }
    onLayoutChange(Rect.fromLTWH(
      contentOffset.dx,
      contentOffset.dy,
      childSize.width,
      childSize.height,
    ));
    return contentOffset;
  }

  @override
  bool shouldRelayout(covariant SingleChildLayoutDelegate oldDelegate) => false;
}
