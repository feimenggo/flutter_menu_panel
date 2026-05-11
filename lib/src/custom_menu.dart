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
  leftCenter,
  rightCenter,

  /// 位于锚点右侧，与锚点顶部对齐（多级菜单常用）
  rightTop,

  /// 位于锚点左侧，与锚点顶部对齐（多级菜单常用）
  leftTop,
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

  void hideAllMenu() {
    if (_menuStates == null) return;
    for (var menu in _menuStates!.reversed.toList()) {
      if (menu.mounted) menu._controller.hideMenu();
    }
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

/// 通过 [InheritedWidget] 在每个菜单的 overlay 子树中注入"宿主菜单"引用。
/// 由于 [OverlayEntry] 的 widget 不会成为创建它的 widget 的子节点，
/// 需要借助此 widget 让 overlay 内部的子菜单能够找到自己的"父菜单"。
class _MenuScope extends InheritedWidget {
  const _MenuScope({required this.host, required super.child});

  final CustomMenuState host;

  @override
  bool updateShouldNotify(covariant _MenuScope oldWidget) =>
      !identical(host, oldWidget.host);

  static CustomMenuState? of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_MenuScope>();
    return scope?.host;
  }
}

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
    this.onTap,
    this.enablePress = true,
    this.enableLongPress = false,
    this.enablePointer = false,
    this.enablePassEvent = false,
    this.below,
    this.onShow,
    this.onHide,
    this.rootOverlay,
    this.cursor,
    this.flipIfOverflow = false,
    this.enableHover = false,
    this.hoverCloseDelay = const Duration(milliseconds: 150),
    this.gap = 0,
    this.onPositionResolved,
  });

  final Widget child;
  final FutureOr<Widget> Function(CustomMenuController controller, Size size) menuBuilder;
  final CustomMenuController? controller;
  final Offset offset;
  final Color barrierColor;
  final MenuPosition position;
  final void Function(bool)? onMenuChange;
  final void Function(CustomMenuController controller)? onTap;
  final bool enablePress;
  final bool enableLongPress;
  final bool enablePointer;

  /// Pass tap event to the widgets below the mask.
  /// It only works when [barrierColor] is transparent.
  final bool enablePassEvent;
  final OverlayEntry? below;
  final VoidCallback? onShow;
  final VoidCallback? onHide;
  final bool? rootOverlay;

  /// 鼠标样式
  final MouseCursor? cursor;

  /// 当菜单在指定[position]方向上无法完全展示时，是否自动翻转到相反方向。
  /// 目前主要用于多级菜单：当[MenuPosition.rightTop]右侧空间不足时，自动翻转到左侧。
  final bool flipIfOverflow;

  /// 鼠标悬停触发显示菜单（用于多级菜单子项），鼠标离开后延时关闭。
  final bool enableHover;

  /// 悬停模式下，鼠标离开 child / 菜单后延迟关闭的时长。
  final Duration hoverCloseDelay;

  /// 菜单与锚点之间的间距（仅对 [MenuPosition.rightTop]/[MenuPosition.leftTop]
  /// 等贴边类位置生效，水平方向上向远离锚点的方向偏移 [gap] 像素）。
  /// 用于多级菜单父子之间留白。
  final double gap;

  /// 当本菜单经过 [flipIfOverflow] 后确定实际方向时回调（仅 layout 阶段触发）。
  /// 可用于外部根据方向做差异化渲染（例如多级菜单贴父侧不显示阴影）。
  final void Function(MenuPosition position)? onPositionResolved;

  /// 在 overlay 子树中查找包含该 [context] 的"宿主菜单"。
  /// 返回的 [CustomMenuState] 即创建当前 overlay 的菜单对象。
  /// 当 [context] 不在任何菜单 overlay 中时返回 null。
  static CustomMenuState? hostMenuOf(BuildContext context) =>
      _MenuScope.of(context);

  @override
  CustomMenuState createState() => CustomMenuState();
}

class CustomMenuState extends State<CustomMenu> {
  late final _controller = widget.controller ?? CustomMenuController();
  bool _canResponse = true;
  Offset? _cachePointer;
  OverlayEntry? _overlayEntry;
  Rect? _layoutRect;

  /// 本菜单的悬浮关闭计时器（每个 enableHover 菜单实例独立）。
  /// 仅在 onExit 时 schedule、onEnter 时 cancel；触发时只关闭本菜单
  /// （其 hover 后代会被一并关闭以避免孤立）。
  Timer? _hoverCloseTimer;

  /// 菜单当前在屏幕（root overlay）坐标系下的矩形；layout 阶段更新。
  Rect? get layoutRect => _layoutRect;

  /// 我所在的父级 [CustomMenuState]：即我的 child 在哪个上层菜单的 overlay 中构建。
  /// 用于实现同级互斥：当兄弟节点要展开子菜单时，先关闭其它已展开的兄弟。
  /// 仅在 [_showMenu] 时延迟解析（此时 context 已挂载）。
  CustomMenuState? _parentMenu;

  /// 公开访问当前菜单的父级菜单（仅 [_showMenu] 之后有值）。
  CustomMenuState? get parentMenu => _parentMenu;

  /// 本菜单经过 [flipIfOverflow] 后实际采用的方向。
  /// 子菜单在 build 时会读取父菜单的此值，以保持整条多级菜单链方向一致。
  /// 同时也用于子菜单内部判断在父侧裁掉阴影。
  final ValueNotifier<MenuPosition?> effectivePosition =
      ValueNotifier<MenuPosition?>(null);

  /// 关闭与本菜单"同父级"的、已展开的兄弟 hover 菜单（及其子孙 hover 菜单）。
  void _closeSiblingHoverMenus() {
    if (_menuStates == null) return;
    // 复制一份避免迭代时修改
    final list = _menuStates!.toList();
    for (var state in list) {
      if (!identical(state, this) &&
          state.mounted &&
          state.widget.enableHover &&
          identical(state._parentMenu, _parentMenu)) {
        // 关闭兄弟自身（其子孙在 _hideMenu 时不会自动收起，需要单独遍历）
        _closeDescendantsOf(state);
        state._controller.hideMenu();
      }
    }
  }

  /// 关闭以 [parent] 为父级的所有 hover 后代菜单（深层优先）。
  void _closeDescendantsOf(CustomMenuState parent) {
    if (_menuStates == null) return;
    final descendants = <CustomMenuState>[];
    for (var s in _menuStates!) {
      // 沿 _parentMenu 链向上查找是否包含 parent
      CustomMenuState? p = s._parentMenu;
      while (p != null) {
        if (identical(p, parent)) {
          descendants.add(s);
          break;
        }
        p = p._parentMenu;
      }
    }
    // 从最深处开始关闭
    for (var s in descendants.reversed) {
      if (s.mounted && s.widget.enableHover) {
        s._controller.hideMenu();
      }
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

  Future<void> _showMenu(Offset? globalPosition) async {
    if (_overlayEntry != null) return;
    // 解析父级菜单（用于同级互斥判断）。
    // 优先通过 _MenuScope（InheritedWidget）从 overlay 子树中拿到宿主菜单；
    // 若不存在（例如根菜单），再退回 widget 树查找。
    _parentMenu = _MenuScope.of(context) ??
        context.findAncestorStateOfType<CustomMenuState>();
    // 关闭同级已展开的兄弟 hover 菜单
    _closeSiblingHoverMenus();
    final childBox = context.findRenderObject() as RenderBox;
    final menuChild = await widget.menuBuilder(_controller, childBox.size);
    if (mounted) {
      _overlayEntry = OverlayEntry(
        builder: (ctx) {
          MediaQuery.sizeOf(ctx); // 监听窗口尺寸变化
          final childBox = context.findRenderObject() as RenderBox;
          final parentBox = Overlay.of(context).context.findRenderObject() as RenderBox;
          // print('pSize:${parentBox.size} cSize:${childBox.size}');
          Widget menuContent =
              Material(color: Colors.transparent, child: menuChild);
          if (widget.enableHover) {
            menuContent = MouseRegion(
              opaque: false,
              onEnter: (_) => _cancelHoverClose(),
              onExit: (_) => _scheduleHoverClose(),
              child: menuContent,
            );
          }
          // 方向锁定：若父菜单已确定为 leftTop / rightTop 中的某个，
          // 则本菜单也优先沿用同一方向，避免子菜单"折返"覆盖祖父级菜单。
          MenuPosition resolvedPosition = widget.position;
          final parentDir = _parentMenu?.effectivePosition.value;
          if ((widget.position == MenuPosition.rightTop ||
                  widget.position == MenuPosition.leftTop) &&
              (parentDir == MenuPosition.rightTop ||
                  parentDir == MenuPosition.leftTop)) {
            resolvedPosition = parentDir!;
          }
          Widget menu = Container(
            constraints: BoxConstraints(
              minWidth: 0,
              maxWidth: parentBox.size.width,
            ),
            child: CustomSingleChildLayout(
              delegate: _MenuLayoutDelegate(
                  position: resolvedPosition,
                  anchorSize: childBox.size,
                  anchorOffset: childBox.localToGlobal(widget.offset),
                  targetOffset: globalPosition,
                  flipIfOverflow: widget.flipIfOverflow,
                  gap: widget.gap,
                  onLayoutChange: (Rect rect) => _layoutRect = rect,
                  onPositionResolved: (MenuPosition pos) {
                    if (effectivePosition.value != pos) {
                      // 推迟到下一帧通知，避免在 layout 期间触发监听者重建。
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && effectivePosition.value != pos) {
                          effectivePosition.value = pos;
                          widget.onPositionResolved?.call(pos);
                        }
                      });
                    }
                  }),
              child: menuContent,
            ),
          );
          return _MenuScope(
            host: this,
            child: Listener(
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
            ),
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

  void _scheduleHoverClose() {
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = Timer(widget.hoverCloseDelay, () {
      _hoverCloseTimer = null;
      if (!mounted) return;
      // 仅关闭自身（及其 hover 后代以避免孤立）。
      // 父菜单是否关闭由父菜单自己的 timer 决定：
      // - 若鼠标回到父菜单 overlay 内（如父菜单的兄弟项），则父菜单的
      //   menuContent MouseRegion 不会触发新的 onExit，父菜单保留；
      // - 若鼠标已彻底离开父菜单 overlay，则父菜单的 menuContent MouseRegion
      //   早在鼠标外移时 onExit → 已 schedule 关闭，会自然关闭。
      // 这样可避免"从子菜单父项挪到同级兄弟项"时误关本层菜单。
      _closeDescendantsOf(this);
      _controller.hideMenu();
    });
  }

  void _cancelHoverClose() {
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = null;
    // 鼠标进入本菜单（child 或 overlay）时，意味着鼠标处于以本菜单为叶子的
    // 整条菜单链内部，应一并取消父链的悬浮关闭计时，避免父菜单在子菜单
    // 仍处于交互中时被错误地延时关闭。
    CustomMenuState? p = _parentMenu;
    while (p != null) {
      if (p.widget.enableHover) {
        p._hoverCloseTimer?.cancel();
        p._hoverCloseTimer = null;
      }
      p = p._parentMenu;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateView);
  }

  @override
  void dispose() {
    _hoverCloseTimer?.cancel();
    _hideMenu();
    _parentMenu = null;
    effectivePosition.dispose();
    _controller.removeListener(_updateView);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enablePress
          ? widget.onTap != null
              ? () {
                  if (_canResponse) widget.onTap!(_controller);
                }
              : onTap
          : null,
      onLongPress: widget.enableLongPress ? onTap : null,
      onSecondaryTapUp:
          widget.enablePointer ? (details) => _cachePointer = details.globalPosition : null,
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
    if (widget.enableHover) {
      child = MouseRegion(
        opaque: false,
        onEnter: (_) {
          _cancelHoverClose();
          if (!_controller.menuIsShowing && _canResponse) {
            _controller.showMenu();
          }
        },
        onExit: (_) => _scheduleHoverClose(),
        child: child,
      );
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
    this.flipIfOverflow = false,
    this.gap = 0,
    this.onPositionResolved,
  });

  final MenuPosition position;
  final Size anchorSize;
  final Offset anchorOffset;
  final Offset? targetOffset;
  final bool flipIfOverflow;
  final double gap;
  final void Function(Rect rect) onLayoutChange;
  final void Function(MenuPosition position)? onPositionResolved;

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
      double anchorCenterY = anchorOffset.dy + anchorSize.height / 2;
      // 智能翻转：right 不下时改为 left；left 不下时改为 right
      MenuPosition effectivePosition = position;
      if (flipIfOverflow) {
        if (position == MenuPosition.rightTop &&
            anchorRightX + gap + childSize.width > size.width &&
            anchorLeftX - gap - childSize.width >= 0) {
          effectivePosition = MenuPosition.leftTop;
        } else if (position == MenuPosition.leftTop &&
            anchorLeftX - gap - childSize.width < 0 &&
            anchorRightX + gap + childSize.width <= size.width) {
          effectivePosition = MenuPosition.rightTop;
        }
      }
      onPositionResolved?.call(effectivePosition);
      switch (effectivePosition) {
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
        case MenuPosition.leftCenter:
          contentOffset = Offset(
            anchorLeftX - childSize.width,
            anchorCenterY - childSize.height / 2,
          );
          break;
        case MenuPosition.rightCenter:
          contentOffset = Offset(
            anchorRightX,
            anchorCenterY - childSize.height / 2,
          );
          break;
        case MenuPosition.rightTop:
          contentOffset = Offset(anchorRightX + gap, anchorTopY);
          break;
        case MenuPosition.leftTop:
          contentOffset =
              Offset(anchorLeftX - gap - childSize.width, anchorTopY);
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
