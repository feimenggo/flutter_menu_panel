import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'custom_menu.dart';

const kItemHeight = 40.0;

typedef MenuWidgetBuilder = Widget Function(BuildContext context, CustomMenuController controller);

/// 文本菜单项
class TextMenuItem {
  final String name;
  final TextStyle? style;
  final VoidCallback? onTap;

  /// 子菜单项；不为空时该项作为父级，悬浮/点击展开下一级菜单。
  /// 子级菜单优先在右侧展示，如果空间不足则自动切换到左侧。
  final List<TextMenuItem>? children;

  /// 子菜单尾部的指示图标（默认为右箭头）。仅当 [children] 非空时生效。
  final Widget? trailing;

  const TextMenuItem(
    this.name,
    this.onTap, {
    this.style,
    this.children,
    this.trailing,
  });

  bool get hasChildren => children != null && children!.isNotEmpty;
}

/// 自定义菜单项
class CustomMenuItem extends TextMenuItem {
  final MenuWidgetBuilder builder;
  final bool keepWidth;

  const CustomMenuItem(this.builder, {VoidCallback? onTap, this.keepWidth = true})
      : super('', onTap);
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
    this.backgroundShadow =
        const BoxShadow(blurRadius: 24, offset: Offset(0, 4), color: Color(0x33000000)),
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.onTap,
    this.enablePress = true,
    this.enableLongPress = false,
    this.enablePointer = false,
    this.enablePassEvent = false,
    this.style,
    this.overflow = TextOverflow.ellipsis,
    this.below,
    this.onShow,
    this.onHide,
    this.rootOverlay,
    this.cursor = SystemMouseCursors.click,
    this.subMenuOffset = Offset.zero,
    this.subMenuIndicator,
    this.subMenuPosition = MenuPosition.rightTop,
    this.subMenuFlipIfOverflow = true,
    this.subMenuHoverDelay = const Duration(milliseconds: 150),
    this.subMenuGap = 4,
  });

  final CustomMenuController? controller;
  final Widget child;
  final double? width;
  final double? height;
  final double? maxHeight;
  final Offset offset;
  final Color? splashColor;
  final Color barrierColor;
  final Color backgroundColor;
  final BoxShadow? backgroundShadow;
  final MenuPosition position;
  final MenuDataBuilder builder;
  final double? itemExtent;
  final double itemHeight;
  final EdgeInsetsGeometry itemPadding;
  final EdgeInsetsGeometry listPadding;
  final AlignmentGeometry itemAlignment;
  final BorderRadiusGeometry? borderRadius;
  final void Function(CustomMenuController controller)? onTap;
  final bool enablePress;
  final bool enableLongPress;
  final bool enablePointer;
  final bool enablePassEvent;
  final TextStyle? style;
  final TextOverflow? overflow;
  final OverlayEntry? below;
  final VoidCallback? onShow;
  final VoidCallback? onHide;
  final bool? rootOverlay;

  /// 鼠标样式
  final MouseCursor? cursor;

  /// 子菜单相对父项的偏移（默认略微向上以使其与父项对齐到 panel 顶部）。
  final Offset subMenuOffset;

  /// 子菜单指示图标（默认右箭头）。
  final Widget? subMenuIndicator;

  /// 子菜单首选弹出位置。默认为锚点右侧。
  final MenuPosition subMenuPosition;

  /// 子菜单空间不足时是否翻转方向（rightTop ↔ leftTop）。
  final bool subMenuFlipIfOverflow;

  /// 子菜单悬停关闭延时。
  final Duration subMenuHoverDelay;

  /// 子菜单与父项之间的水平间距，默认 4。
  final double subMenuGap;

  @override
  State<MenuPanel> createState() => MenuPanelState();
}

class MenuPanelState extends State<MenuPanel> {
  ScrollController? scrollController;

  @override
  void dispose() {
    super.dispose();
    scrollController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomMenu(
      controller: widget.controller,
      offset: widget.offset,
      position: widget.position,
      barrierColor: widget.barrierColor,
      onTap: widget.onTap,
      enablePress: widget.enablePress,
      enableLongPress: widget.enableLongPress,
      enablePointer: widget.enablePointer,
      enablePassEvent: widget.enablePassEvent,
      below: widget.below,
      onShow: widget.onShow,
      onHide: widget.onHide,
      rootOverlay: widget.rootOverlay,
      menuBuilder: buildMenu,
      cursor: widget.cursor,
      child: widget.child,
    );
  }

  Future<Widget> buildMenu(CustomMenuController controller, Size size) async {
    final menuData = await widget.builder(context);
    return _buildPanelContent(menuData, controller, size, isRoot: true);
  }

  /// 构建面板的内容（外观/容器）
  Widget _buildPanelContent(
    MenuData menuData,
    CustomMenuController controller,
    Size anchorSize, {
    required bool isRoot,
    ValueListenable<MenuPosition?>? directionListenable,
  }) {
    final List<TextMenuItem> items = menuData.items;
    double? itemExtent = widget.itemExtent ?? widget.itemHeight;
    final children = items.map((item) {
      Widget child;
      if (item is CustomMenuItem) {
        if (widget.itemExtent == null) itemExtent = null;
        child = item.builder(context, controller);
        if (item.keepWidth) {
          child = SizedBox(width: widget.width ?? anchorSize.width, child: child);
        } else {
          // 由于外层 Column 使用 CrossAxisAlignment.stretch，
          // 这里用 Align 让自定义 child 维持其原本的尺寸而不被强制拉伸。
          child = Align(alignment: widget.itemAlignment, child: child);
        }
        if (item.onTap != null) {
          child = InkWell(
            onTap: () {
              controller.hideAllMenu();
              item.onTap!.call();
            },
            splashColor: widget.splashColor,
            child: child,
          );
        }
        return child;
      }

      // 普通文本菜单项（可能带 children）
      final textWidget = Text(
        item.name,
        style: item.style ??
            widget.style ??
            const TextStyle(color: Color(0xFF242A39), fontSize: 13, fontWeight: FontWeight.bold),
        overflow: widget.overflow,
      );

      Widget rowContent;
      if (item.hasChildren) {
        // 文本 + 尾部箭头
        rowContent = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: textWidget),
            const SizedBox(width: 8),
            item.trailing ??
                widget.subMenuIndicator ??
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFF8A8F99)),
          ],
        );
      } else {
        rowContent = textWidget;
      }

      child = Container(
        padding: widget.itemPadding,
        alignment: widget.itemAlignment,
        constraints: BoxConstraints(
          minWidth: widget.width ?? anchorSize.width,
          minHeight: widget.itemHeight,
        ),
        child: rowContent,
      );

      if (item.hasChildren) {
        // 包一层 InkWell，便于 hover 高亮；点击不关闭，让子菜单自行展开
        child = InkWell(
          onTap: () {}, // 占位：点击不关闭主菜单
          splashColor: widget.splashColor,
          child: child,
        );
        // 用一个新 MenuPanel 作为子菜单容器；child 即当前菜单项行
        child = _buildSubMenuPanel(item, child);
      } else if (item.onTap != null) {
        child = InkWell(
          onTap: () {
            controller.hideAllMenu();
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
      assert(itemExtent != null, '当CustomMenuItem使用initialIndex时，需要设置itemExtent');
      scrollController?.dispose();
      scrollController = ScrollController(
        initialScrollOffset: menuData.initialIndex! * itemExtent!,
      );
    } else if (isRoot) {
      scrollController?.dispose();
      scrollController = ScrollController();
    }

    // 内容层：实际可见的菜单内容（不绘制阴影）。
    final Widget contentLayer = Material(
      color: widget.backgroundColor,
      borderRadius: widget.borderRadius,
      child: SingleChildScrollView(
        controller: isRoot ? scrollController : null,
        padding: widget.listPadding,
        // IntrinsicWidth 让 Column 取所有子项中最长的 intrinsic 宽度，
        // 配合 stretch 让每个 row 都填满该宽度，避免父 row 比 panel 窄
        // 导致多级菜单间距视觉不一致。
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );

    final BoxShadow? shadow = widget.backgroundShadow;
    // 阴影层：与内容层同尺寸，但仅绘制 BoxShadow（无 background color）。
    // 使用 Positioned.fill 跟随 Stack 尺寸（由 contentLayer 决定）。
    Widget? shadowLayer;
    if (shadow != null) {
      shadowLayer = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: [shadow],
          // 这里需要一个不透明的 color 才能让阴影绘制可见（BoxShadow 实际由
          // RenderDecoratedBox 在背景下方绘制；如果没有 background color，
          // 阴影仍然会绘制——经过测试 BoxDecoration 无 color 时阴影正常）。
        ),
        child: const SizedBox.expand(),
      );
      // 子菜单：仅裁掉与父菜单"垂直交集"区域内、贴父侧的阴影绘制；
      // 但重叠区段的阴影也允许向外延伸到 [subMenuGap] 距离（即不越过父菜单边缘）。
      if (!isRoot && directionListenable != null) {
        shadowLayer = _SubMenuShadowMask(
          directionListenable: directionListenable,
          shadow: shadow,
          nearSideExtent: widget.subMenuGap,
          parentBorderRadius: widget.borderRadius,
          child: shadowLayer,
        );
      }
    }

    // 用 Stack 把阴影层与内容层叠在一起：阴影层在下，内容层在上。
    final Widget panelBody = Container(
      height: widget.height,
      constraints: widget.maxHeight != null ? BoxConstraints(maxHeight: widget.maxHeight!) : null,
      child: shadowLayer == null
          ? contentLayer
          : Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: shadowLayer),
                contentLayer,
              ],
            ),
    );

    return panelBody;
  }

  /// 为带 children 的菜单项构建一个嵌套的子菜单面板
  Widget _buildSubMenuPanel(TextMenuItem parent, Widget child) {
    return _SubMenu(
      parent: parent,
      panel: widget,
      buildContent: (
        BuildContext ctx,
        CustomMenuController subController,
        Size anchorSize,
        ValueListenable<MenuPosition?> directionListenable,
      ) {
        return _buildPanelContent(
          MenuData(parent.children!),
          subController,
          anchorSize,
          isRoot: false,
          directionListenable: directionListenable,
        );
      },
      child: child,
    );
  }
}

/// 内部使用的子菜单组件，基于 [CustomMenu] 但额外提供：
/// - 悬浮显示
/// - 优先右侧、不下时自动翻转到左侧
/// - 贴父菜单一侧裁掉阴影，避免阴影覆盖到上一级菜单
class _SubMenu extends StatefulWidget {
  const _SubMenu({
    required this.parent,
    required this.panel,
    required this.buildContent,
    required this.child,
  });

  final TextMenuItem parent;
  final MenuPanel panel;
  final Widget Function(
    BuildContext context,
    CustomMenuController controller,
    Size anchorSize,
    ValueListenable<MenuPosition?> directionListenable,
  ) buildContent;
  final Widget child;

  @override
  State<_SubMenu> createState() => _SubMenuState();
}

class _SubMenuState extends State<_SubMenu> {
  late final ValueNotifier<MenuPosition?> _direction =
      // 初始值用默认方向作猜测，避免首帧裁切方向未知导致阴影闪烁；
      // layout 后会根据实际方向更新。
      ValueNotifier<MenuPosition?>(widget.panel.subMenuPosition);

  @override
  void dispose() {
    _direction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panel = widget.panel;
    return CustomMenu(
      position: panel.subMenuPosition,
      offset: panel.subMenuOffset,
      flipIfOverflow: panel.subMenuFlipIfOverflow,
      gap: panel.subMenuGap,
      enableHover: true,
      hoverCloseDelay: panel.subMenuHoverDelay,
      enablePress: true,
      barrierColor: Colors.transparent,
      enablePassEvent: true,
      rootOverlay: panel.rootOverlay,
      cursor: panel.cursor,
      onPositionResolved: (pos) {
        if (_direction.value != pos) _direction.value = pos;
      },
      menuBuilder: (controller, size) async {
        return widget.buildContent(context, controller, size, _direction);
      },
      child: widget.child,
    );
  }
}

/// 子菜单阴影遮罩：根据方向 + 与父菜单"垂直交集"动态裁切阴影。
///
/// 仅裁掉子菜单与父菜单**垂直方向重叠区段**内、贴向父菜单一侧的阴影；
/// 重叠区段之外（子菜单超出父菜单的上下部分）阴影正常显示。
///
/// 这样既避免子菜单阴影遮盖父菜单内容，又最大限度保留阴影自然晕染。
class _SubMenuShadowMask extends StatefulWidget {
  const _SubMenuShadowMask({
    required this.directionListenable,
    required this.shadow,
    required this.nearSideExtent,
    required this.parentBorderRadius,
    required this.child,
  });

  final ValueListenable<MenuPosition?> directionListenable;
  final BoxShadow shadow;

  /// 重叠区段贴父侧允许保留的阴影外延宽度（通常 = subMenuGap）。
  final double nearSideExtent;

  /// 父菜单的 border radius（凹切出入口会按此半径做圆弧过渡，
  /// 让阴影裁切与父菜单圆角自然衔接）。
  final BorderRadiusGeometry? parentBorderRadius;

  final Widget child;

  @override
  State<_SubMenuShadowMask> createState() => _SubMenuShadowMaskState();
}

class _SubMenuShadowMaskState extends State<_SubMenuShadowMask> {
  /// 父菜单在自身本地坐标系下的 Y 区间（仅 y 范围内贴父侧裁掉阴影）。
  /// null 表示尚未解析或父菜单不可用，此时退化为不裁切（保留阴影）。
  Range? _overlapY;

  @override
  void initState() {
    super.initState();
    widget.directionListenable.addListener(_scheduleRecalc);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalcOverlap());
  }

  @override
  void didUpdateWidget(covariant _SubMenuShadowMask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directionListenable != widget.directionListenable) {
      oldWidget.directionListenable.removeListener(_scheduleRecalc);
      widget.directionListenable.addListener(_scheduleRecalc);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalcOverlap());
  }

  @override
  void dispose() {
    widget.directionListenable.removeListener(_scheduleRecalc);
    super.dispose();
  }

  void _scheduleRecalc() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalcOverlap());
  }

  /// 计算父菜单在本组件本地坐标系下的 Y 区间。
  void _recalcOverlap() {
    if (!mounted) return;
    // host 即"创建本 overlay 的菜单"——对子菜单来说就是它自己；
    // 父菜单 = host.parentMenu。
    final host = CustomMenu.hostMenuOf(context);
    final parent = host?.parentMenu;
    final parentRect = parent?.layoutRect; // 相对 root overlay 的坐标
    final selfBox = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (parentRect == null || selfBox == null || !selfBox.hasSize || overlayBox == null) {
      if (_overlapY != null) setState(() => _overlapY = null);
      return;
    }
    // 用 overlay 作为公共 ancestor，确保与 _layoutRect 同坐标系
    final selfTopInOverlay = selfBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final localParentTop = parentRect.top - selfTopInOverlay.dy;
    final localParentBottom = parentRect.bottom - selfTopInOverlay.dy;
    // 与本菜单 y=[0, height] 的交集
    final selfHeight = selfBox.size.height;
    final overlapTop = math.max(0.0, localParentTop);
    final overlapBottom = math.min(selfHeight, localParentBottom);
    Range? newRange;
    if (overlapBottom > overlapTop) {
      newRange = Range(overlapTop, overlapBottom);
    }
    if (newRange != _overlapY) {
      setState(() => _overlapY = newRange);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MenuPosition?>(
      valueListenable: widget.directionListenable,
      builder: (context, dir, _) {
        final shadowExtent = widget.shadow.blurRadius +
            widget.shadow.spreadRadius +
            math.max(widget.shadow.offset.dx.abs(), widget.shadow.offset.dy.abs());
        // 限制 nearSide 不超过 shadowExtent，避免无意义的越界。
        final double nearSide = math.min(widget.nearSideExtent, shadowExtent);
        // 用父菜单的最大圆角半径作为凹切出入口的圆弧半径，
        // 让凹切路径在 yTop/yBot 转角处与父菜单圆角协调过渡，
        // 避免生硬直角以及在衔接处"削平"阴影的视觉瑕疵。
        final double cornerRadius = _extractMaxCornerRadius(
          widget.parentBorderRadius,
          Directionality.maybeOf(context) ?? TextDirection.ltr,
        );
        return ClipPath(
          clipBehavior: Clip.hardEdge,
          clipper: _SubMenuShadowClipper(
            direction: dir,
            extent: shadowExtent,
            nearSideExtent: nearSide,
            overlapY: _overlapY,
            cornerRadius: cornerRadius,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// 从 [BorderRadiusGeometry] 中提取最大半径（用于凹切出入口的圆弧过渡）。
double _extractMaxCornerRadius(BorderRadiusGeometry? geom, TextDirection direction) {
  if (geom == null) return 0;
  final br = geom.resolve(direction);
  return math.max(
    math.max(br.topLeft.y, br.topRight.y),
    math.max(br.bottomLeft.y, br.bottomRight.y),
  );
}

/// 简单的 Y 区间值对象（用于 setState 比较）。
@immutable
class Range {
  const Range(this.start, this.end);

  final double start;
  final double end;

  @override
  bool operator ==(Object other) => other is Range && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// 子菜单阴影裁切器（凹形）：
/// - 默认整体外扩 [extent]，让阴影正常绘制；
/// - 如果方向是 [MenuPosition.rightTop]/[MenuPosition.leftTop] 且存在父菜单
///   重叠 Y 区间 [overlapY]，则把贴父侧的"重叠区段"凹进去，使该段阴影
///   只能向外延伸 [nearSideExtent]（通常 = subMenuGap），不再越界覆盖父菜单；
/// - 重叠区段之外（菜单超出父菜单上下部分）的阴影完整保留；
/// - 凹切出入口的两个外角会按 [cornerRadius] 做圆弧过渡，避免直角突变、
///   让衔接处阴影过渡更柔和；
/// - 仅当该端的凹切端点位于子菜单内部（即此端为"凹切回到完整外扩阴影"
///   的拐角）时才绘制圆弧；如果凹切区段直接延伸到子菜单顶/底边缘
///   （子菜单未在该方向超出父菜单），对应端不绘制圆弧——否则圆弧会
///   在子菜单边缘外侧凸出，覆盖到父菜单一侧形成视觉瑕疵。
class _SubMenuShadowClipper extends CustomClipper<Path> {
  _SubMenuShadowClipper({
    required this.direction,
    required this.extent,
    this.nearSideExtent = 0,
    this.overlapY,
    this.cornerRadius = 0,
  });

  final MenuPosition? direction;
  final double extent;

  /// 重叠区段贴父侧允许保留的阴影外延宽度（默认 0 表示完全裁齐到 panel 边缘）。
  final double nearSideExtent;

  final Range? overlapY;

  /// 凹切出入口外角的圆弧半径（通常取父菜单圆角半径），
  /// 用于让凹切路径与父菜单圆角协调过渡，避免直角造成的视觉生硬。
  final double cornerRadius;

  @override
  Path getClip(Size size) {
    final path = Path();
    final double L = -extent;
    final double T = -extent;
    final double R = size.width + extent;
    final double B = size.height + extent;

    // 没有有效方向 / 重叠区，直接返回外扩矩形（不做凹切）
    final dir = direction;
    final overlap = overlapY;
    if (overlap == null || (dir != MenuPosition.rightTop && dir != MenuPosition.leftTop)) {
      path.addRect(Rect.fromLTRB(L, T, R, B));
      return path;
    }

    // 与 panel 的 y 范围夹紧（凹切仅作用在面板高度内部）。
    final double yTop = overlap.start.clamp(0.0, size.height);
    final double yBot = overlap.end.clamp(0.0, size.height);
    if (yBot <= yTop) {
      path.addRect(Rect.fromLTRB(L, T, R, B));
      return path;
    }

    // 凹切外凸角（阴影轮廓突变处）的圆角半径：
    // - 不超过凹切区的一半高度（(yBot-yTop)/2），避免上下弧线相交；
    // - 以 cornerRadius 为目标值（通常 = 父菜单圆角半径），让阴影
    //   "突变"改为弧形过渡，衔接处更自然。
    final double maxArc = (yBot - yTop) / 2;
    final double arc = math.max(0.0, math.min(cornerRadius, maxArc));

    // 仅当"凹切端点位于子菜单内部"时才需要弧形过渡——这意味着该端点
    // 是凹切回归到完整外扩阴影的拐角。当凹切区段一直延伸到子菜单顶/底
    // 边缘时（即子菜单在该方向未超出父菜单），不绘制圆弧、并把凹切线
    // 直接延伸到外扩区边界 T/B，这样 panel 自身圆角在贴父侧产生的弧形
    // 阴影也会被一同裁掉，避免视觉上仍残留一段圆弧。
    // - 顶部弧：当 yTop > 0（重叠区上端在子菜单内部，即子菜单顶部
    //   高于父菜单顶部 / 子菜单向上延伸超过父菜单）时才绘制；
    // - 底部弧：当 yBot < size.height（重叠区下端在子菜单内部，即
    //   子菜单底部低于父菜单底部 / 子菜单向下延伸超过父菜单）时才绘制。
    const double eps = 0.5;
    final bool arcTop = arc > 0 && yTop > eps;
    final bool arcBot = arc > 0 && yBot < size.height - eps;

    if (dir == MenuPosition.rightTop) {
      // 子菜单在父右侧：左侧凹切（凹槽开口朝左）。
      final double nearLeft = -nearSideExtent;
      path.moveTo(L, T);
      path.lineTo(R, T);
      path.lineTo(R, B);
      if (arcBot) {
        // 重叠区下端在子菜单内部：在 (nearLeft, yBot) 处做弧形过渡回外扩区。
        path.lineTo(L, B);
        path.lineTo(L, yBot);
        path.lineTo(nearLeft - arc, yBot);
        path.arcToPoint(
          Offset(nearLeft, yBot - arc),
          radius: Radius.circular(arc),
          clockwise: false,
        );
      } else {
        // 重叠区一直延伸到子菜单底部：凹切线直接下沉到外扩底部 B，
        // 把 panel 自身底部圆角的阴影也一并裁掉（避免贴父菜单一侧
        // 仍能看到一段 panel 圆角形成的弧形阴影）。
        path.lineTo(nearLeft, B);
        path.lineTo(nearLeft, yBot);
      }
      if (arcTop) {
        // 重叠区上端在子菜单内部：在 (nearLeft, yTop) 处做弧形过渡回外扩区。
        path.lineTo(nearLeft, yTop + arc);
        path.arcToPoint(
          Offset(nearLeft - arc, yTop),
          radius: Radius.circular(arc),
          clockwise: false,
        );
        path.lineTo(L, yTop);
      } else {
        // 重叠区一直延伸到子菜单顶部：凹切线直接上拔到外扩顶部 T。
        path.lineTo(nearLeft, yTop);
        path.lineTo(nearLeft, T);
      }
      path.close();
    } else {
      // leftTop：子菜单在父左侧：右侧凹切（凹槽开口朝右）。
      final double nearRight = size.width + nearSideExtent;
      path.moveTo(L, T);
      if (arcTop) {
        path.lineTo(R, T);
        path.lineTo(R, yTop);
        path.lineTo(nearRight + arc, yTop);
        path.arcToPoint(
          Offset(nearRight, yTop + arc),
          radius: Radius.circular(arc),
          clockwise: false,
        );
      } else {
        path.lineTo(nearRight, T);
        path.lineTo(nearRight, yTop);
      }
      if (arcBot) {
        path.lineTo(nearRight, yBot - arc);
        path.arcToPoint(
          Offset(nearRight + arc, yBot),
          radius: Radius.circular(arc),
          clockwise: false,
        );
        path.lineTo(R, yBot);
        path.lineTo(R, B);
      } else {
        path.lineTo(nearRight, yBot);
        path.lineTo(nearRight, B);
      }
      path.lineTo(L, B);
      path.close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _SubMenuShadowClipper oldClipper) {
    return oldClipper.direction != direction ||
        oldClipper.extent != extent ||
        oldClipper.nearSideExtent != nearSideExtent ||
        oldClipper.overlapY != overlapY ||
        oldClipper.cornerRadius != cornerRadius;
  }
}
