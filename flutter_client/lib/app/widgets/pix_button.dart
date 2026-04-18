import 'package:flutter/material.dart';

/// `.cursorrules`：禁止 Material 按钮，用手势 + 直角容器。
class PixButton extends StatelessWidget {
  const PixButton({
    super.key,
    required this.onTap,
    required this.child,
    this.enabled = true,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.face = const Color(0xFF081108),
    this.topLeft = Colors.white,
    this.bottomRight = const Color(0xFF424242),
    this.borderWidth = 2,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool enabled;
  final double? width;
  final double? height;
  final EdgeInsets padding;
  final Color face;
  final Color topLeft;
  final Color bottomRight;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final Widget inner = Container(
      width: width,
      height: height,
      padding: padding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: face,
        border: Border(
          top: BorderSide(color: topLeft, width: borderWidth),
          left: BorderSide(color: topLeft, width: borderWidth),
          bottom: BorderSide(color: bottomRight, width: borderWidth),
          right: BorderSide(color: bottomRight, width: borderWidth),
        ),
      ),
      child: child,
    );

    if (!enabled || onTap == null) {
      return Opacity(opacity: enabled ? 1 : 0.45, child: inner);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: inner,
      ),
    );
  }
}
