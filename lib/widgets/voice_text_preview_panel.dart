import 'dart:async';

import 'package:flutter/material.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/voice_preview_button.dart';

class VoiceTextPreviewPanel extends StatefulWidget {
  const VoiceTextPreviewPanel({
    super.key,
    required this.text,
    required this.voiceId,
  });

  final String text;
  final String voiceId;

  @override
  State<VoiceTextPreviewPanel> createState() => _VoiceTextPreviewPanelState();
}

class _VoiceTextPreviewPanelState extends State<VoiceTextPreviewPanel> {
  bool _isPlaying = false;

  bool get _canPreview =>
      widget.text.trim().isNotEmpty &&
      VoiceService.presetVoices.any((VoiceOption voice) => voice.id == widget.voiceId);

  @override
  void didUpdateWidget(covariant VoiceTextPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.voiceId != widget.voiceId) {
      unawaited(_stopPreview());
    }
  }

  @override
  void dispose() {
    if (_isPlaying) {
      unawaited(VoiceService.stop());
    }
    super.dispose();
  }

  Future<void> _stopPreview() async {
    if (!_isPlaying) {
      return;
    }
    await VoiceService.stop();
    if (!mounted) {
      return;
    }
    setState(() => _isPlaying = false);
  }

  Future<void> _togglePreview() async {
    if (!_canPreview) {
      return;
    }
    if (_isPlaying) {
      await _stopPreview();
      return;
    }
    setState(() => _isPlaying = true);
    await VoiceService.play(
      voiceId: widget.voiceId,
      text: widget.text.trim(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canPreview) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Center(
        child: VoicePreviewButton(
          isPlaying: _isPlaying,
          onPressed: _togglePreview,
        ),
      ),
    );
  }
}
