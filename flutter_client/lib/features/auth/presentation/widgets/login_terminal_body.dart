import 'package:flutter/material.dart';

import '../../../../app/widgets/pix_button.dart';
import '../../../../core/theme/pixel_style.dart';
import '../../../../core/theme/theme.dart';
import '../controllers/login_terminal_controller.dart';

/// 与 Web `LoginTerminal` 终端内容一致；可嵌入全屏页或登录弹层。
class LoginTerminalBody extends StatelessWidget {
  const LoginTerminalBody({
    super.key,
    required this.controller,
    required this.decodeScroll,
  });

  final LoginTerminalController controller;
  final ScrollController decodeScroll;

  @override
  Widget build(BuildContext context) {
    final title = controller.phase == LoginPhase.boot
        ? controller.bootText
        : '[ SYSTEM BOOT... 2000.exe ]';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: PixelStyle.vt323(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            shadows: PixelStyle.neonGlow(CyberPalette.terminalGreen),
          ),
        ),
        const SizedBox(height: 8),
        if (controller.phase == LoginPhase.boot)
          Text('正在初始化赛博树洞时空接入协议...', style: PixelStyle.vt323(fontSize: 14))
        else if (controller.phase == LoginPhase.decoding)
          _DecodingBox(controller: controller, scroll: decodeScroll)
        else if (controller.phase == LoginPhase.success)
          _SuccessBox(cyberName: controller.cyberName)
        else
          _InputPhase(controller: controller),
      ],
    );
  }
}

class _InputPhase extends StatelessWidget {
  const _InputPhase({required this.controller});

  final LoginTerminalController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 18),
        Text('> 请输入地球维度的通讯终端号 (Phone Number):', style: PixelStyle.vt323(fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.phone,
          enabled: controller.phase != LoginPhase.countdown,
          onChanged: controller.onPhoneChanged,
          style: PixelStyle.vt323(fontSize: 15),
          decoration: const InputDecoration(hintText: '13800138000'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: PixButton(
            onTap: controller.countdown > 0 ? null : controller.requestKey,
            enabled: controller.countdown == 0,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              controller.countdown > 0
                  ? '> 密匙已发送至终端，正在维持信道 (${controller.countdown}s)...'
                  : '[ 请求时空跃迁密匙 ]',
              textAlign: TextAlign.center,
              style: PixelStyle.vt323(fontSize: 14),
            ),
          ),
        ),
        if (controller.phase == LoginPhase.countdown) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            '> 请输入 4 位跃迁密匙 (Auth Code):',
            style: PixelStyle.vt323(fontSize: 14, color: CyberPalette.neonCyan, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: controller.onCodeChanged,
            textAlign: TextAlign.center,
            style: PixelStyle.vt323(
              fontSize: 20,
              color: CyberPalette.neonCyan,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              hintText: '· · · ·',
              filled: true,
              fillColor: const Color(0x66000C12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: CyberPalette.neonCyan.withValues(alpha: 0.65)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: CyberPalette.neonPurple, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PixButton(
              onTap: controller.verify,
              face: CyberPalette.frameDark,
              topLeft: CyberPalette.neonPurple.withValues(alpha: 0.9),
              bottomRight: const Color(0xFF2D0A40),
              child: Text(
                '[ 执行身份覆写 (Override) ]',
                textAlign: TextAlign.center,
                style: PixelStyle.vt323(fontSize: 14, color: const Color(0xFFF0ABFC)),
              ),
            ),
          ),
        ],
        if (controller.error.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            controller.error,
            style: PixelStyle.vt323(fontSize: 12, color: CyberPalette.danger),
          ),
        ],
      ],
    );
  }
}

class _DecodingBox extends StatelessWidget {
  const _DecodingBox({required this.controller, required this.scroll});

  final LoginTerminalController controller;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE5000600),
        border: Border.all(color: CyberPalette.terminalGreen.withValues(alpha: 0.35)),
      ),
      child: ListView.builder(
        controller: scroll,
        itemCount: controller.decodingLines.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == controller.decodingLines.length) {
            return Text('>> PROCESSING...', style: PixelStyle.vt323(fontSize: 11));
          }
          return Text(
            controller.decodingLines[index],
            style: PixelStyle.vt323(
              fontSize: 11,
              color: CyberPalette.terminalGreen.withValues(alpha: 0.76),
            ),
          );
        },
      ),
    );
  }
}

class _SuccessBox extends StatelessWidget {
  const _SuccessBox({required this.cyberName});

  final String cyberName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: <Widget>[
          Text('>> IDENTITY OVERRIDE COMPLETE', style: PixelStyle.vt323(fontSize: 14)),
          const SizedBox(height: 24),
          Text(
            '身份覆写成功。欢迎登陆，代号：\n【$cyberName】',
            textAlign: TextAlign.center,
            style: PixelStyle.vt323(fontSize: 14, color: const Color(0xFF86EFAC), height: 1.8),
          ),
        ],
      ),
    );
  }
}
