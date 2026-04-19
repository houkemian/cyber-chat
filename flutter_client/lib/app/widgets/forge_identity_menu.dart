import 'package:flutter/material.dart';

import '../../core/theme/pixel_style.dart';
import '../../core/theme/theme.dart';
import '../../features/auth/data/auth_repository.dart';

/// 头像菜单「身份区」整块：当前密匙文案 + Win98 [伪造新身份] 按钮（自定义 PopupMenuEntry，保证按钮可点击）。
class IdentityForgeMenuEntry extends PopupMenuEntry<Object?> {
  const IdentityForgeMenuEntry({
    super.key,
    required this.cyberName,
    required this.onForge,
  });

  final String? cyberName;
  final Future<void> Function() onForge;

  @override
  double get height => 118;

  @override
  bool represents(Object? value) => false;

  @override
  State<IdentityForgeMenuEntry> createState() => _IdentityForgeMenuEntryState();
}

class _IdentityForgeMenuEntryState extends State<IdentityForgeMenuEntry> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DefaultTextStyle(
            style: PixelStyle.vt323(fontSize: 12, color: const Color(0xFF99F6E4), height: 1.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('>> 当前身份密匙 (Uplink Key):'),
                Text(widget.cyberName ?? 'ANON', style: const TextStyle(color: Color(0xFFE0F2FE))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Win98ForgeIdentityButton(onForge: widget.onForge),
        ],
      ),
    );
  }
}

/// Win98 凸起按钮 + 伪造流程（800ms 延迟 + 闪烁绿底），完成后 [onForge] 成功则通常由调用方 [Navigator.pop] 关闭菜单。
class Win98ForgeIdentityButton extends StatefulWidget {
  const Win98ForgeIdentityButton({super.key, required this.onForge});

  final Future<void> Function() onForge;

  @override
  State<Win98ForgeIdentityButton> createState() => _Win98ForgeIdentityButtonState();
}

class _Win98ForgeIdentityButtonState extends State<Win98ForgeIdentityButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _busy = false;
  late final AnimationController _blink;

  static const Color _face = Color(0xFFC0C0C0);
  static const Color _greenFlash = Color(0xFF39FF14);

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    _blink.repeat(reverse: true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _blink.stop();
    _blink.reset();
    if (!mounted) return;
    setState(() {});
    try {
      await widget.onForge();
      if (mounted) Navigator.of(context).pop<Object?>(null);
    } on AuthRepositoryException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(e.message, style: const TextStyle(fontFamily: CyberFonts.pixel, fontSize: 12)),
            backgroundColor: const Color(0xFF4A1515),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('$e', style: const TextStyle(fontFamily: CyberFonts.pixel, fontSize: 12)),
            backgroundColor: const Color(0xFF4A1515),
          ),
        );
      }
    }
  }

  BoxDecoration _decoration(bool pressed) {
    final bool raised = !pressed;
    final Color bg = _busy
        ? Color.lerp(_face, _greenFlash, 0.35 + _blink.value * 0.65)!
        : _face;
    final Color hi = const Color(0xFFFFFFFF);
    final Color lo = const Color(0xFF424242);
    return BoxDecoration(
      color: bg,
      border: Border(
        top: BorderSide(color: raised ? hi : lo, width: 2),
        left: BorderSide(color: raised ? hi : lo, width: 2),
        bottom: BorderSide(color: raised ? lo : hi, width: 2),
        right: BorderSide(color: raised ? lo : hi, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const String idleLabel = ' [ 伪造新身份 ] ';
    const String busyLabel = ' [ IDENTITY_OVERRIDE... ] ';

    return GestureDetector(
      onTapDown: (_) {
        if (!_busy) setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _busy ? null : _handleTap,
      child: Container(
        decoration: _decoration(_pressed && !_busy),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          _busy ? busyLabel : idleLabel,
          style: const TextStyle(
            fontFamily: CyberFonts.pixel,
            fontSize: 11,
            height: 1.2,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
