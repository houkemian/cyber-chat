import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../controllers/login_terminal_controller.dart';

class LoginTerminalPage extends StatefulWidget {
  const LoginTerminalPage({super.key});

  @override
  State<LoginTerminalPage> createState() => _LoginTerminalPageState();
}

class _LoginTerminalPageState extends State<LoginTerminalPage> {
  final LoginTerminalController _controller = LoginTerminalController();
  final ScrollController _decodeScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.startBoot();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _decodeScroll.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.phase == LoginPhase.decoding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_decodeScroll.hasClients) {
          _decodeScroll.jumpTo(_decodeScroll.position.maxScrollExtent);
        }
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: CyberPalette.pureBlack,
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.8),
            radius: 1.5,
            colors: <Color>[Color(0x1200F0FF), CyberPalette.pureBlack],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
                decoration: BoxDecoration(
                  color: const Color(0xF5000800),
                  border: Border.all(color: CyberPalette.terminalGreen.withValues(alpha: 0.55)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: CyberPalette.terminalGreen.withValues(alpha: 0.22),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: _buildPhaseContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent(BuildContext context) {
    final title = _controller.phase == LoginPhase.boot
        ? _controller.bootText
        : '[ SYSTEM BOOT... 2000.exe ]';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                shadows: <Shadow>[
                  Shadow(color: CyberPalette.terminalGreen.withValues(alpha: 0.7), blurRadius: 12),
                ],
              ),
        ),
        const SizedBox(height: 8),
        if (_controller.phase == LoginPhase.boot)
          const Text('正在初始化赛博树洞时空接入协议...')
        else if (_controller.phase == LoginPhase.decoding)
          _buildDecodingBox()
        else if (_controller.phase == LoginPhase.success)
          _buildSuccessBox()
        else
          _buildInputBox(),
      ],
    );
  }

  Widget _buildInputBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 18),
        const Text('> 请输入地球维度的通讯终端号 (Phone Number):'),
        const SizedBox(height: 8),
        TextField(
          keyboardType: TextInputType.phone,
          enabled: _controller.phase != LoginPhase.countdown,
          onChanged: _controller.onPhoneChanged,
          decoration: const InputDecoration(hintText: '13800138000'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _controller.countdown > 0 ? null : _controller.requestKey,
            child: Text(
              _controller.countdown > 0
                  ? '> 密匙已发送至终端，正在维持信道 (${_controller.countdown}s)...'
                  : '[ 请求时空跃迁密匙 ]',
            ),
          ),
        ),
        if (_controller.phase == LoginPhase.countdown) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            '> 请输入 4 位跃迁密匙 (Auth Code):',
            style: const TextStyle(color: CyberPalette.neonCyan, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            onChanged: _controller.onCodeChanged,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CyberPalette.neonCyan,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              hintText: '· · · ·',
              fillColor: const Color(0x66000C12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: CyberPalette.neonCyan.withValues(alpha: 0.65)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(color: CyberPalette.neonPurple, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _controller.verify,
              style: ElevatedButton.styleFrom(
                foregroundColor: const Color(0xFFF0ABFC),
                side: BorderSide(color: CyberPalette.neonPurple.withValues(alpha: 0.85), width: 1.5),
              ),
              child: const Text('[ 执行身份覆写 (Override) ]'),
            ),
          ),
        ],
        if (_controller.error.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _controller.error,
            style: const TextStyle(color: CyberPalette.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildDecodingBox() {
    return Container(
      height: 260,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE5000600),
        border: Border.all(color: CyberPalette.terminalGreen.withValues(alpha: 0.35)),
      ),
      child: ListView.builder(
        controller: _decodeScroll,
        itemCount: _controller.decodingLines.length + 1,
        itemBuilder: (context, index) {
          if (index == _controller.decodingLines.length) {
            return const Text('>> PROCESSING...');
          }
          return Text(
            _controller.decodingLines[index],
            style: TextStyle(
              fontSize: 11,
              color: CyberPalette.terminalGreen.withValues(alpha: 0.76),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccessBox() {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        children: <Widget>[
          const Text('>> IDENTITY OVERRIDE COMPLETE'),
          const SizedBox(height: 24),
          Text(
            '身份覆写成功。欢迎登陆，代号：\n【${_controller.cyberName}】',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF86EFAC), height: 1.8),
          ),
        ],
      ),
    );
  }
}
