import 'dart:async';

import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/microphone_permission.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/services/voice_service.dart';

class VoiceRecordPanel extends StatefulWidget {
  const VoiceRecordPanel({
    super.key,
    this.recordingPath,
    required this.onRecordingPathChanged,
    this.onRecordingStateChanged,
  });

  final String? recordingPath;
  final ValueChanged<String?> onRecordingPathChanged;
  final ValueChanged<bool>? onRecordingStateChanged;

  @override
  State<VoiceRecordPanel> createState() => _VoiceRecordPanelState();
}

class _VoiceRecordPanelState extends State<VoiceRecordPanel> {
  bool _isRecording = false;
  bool _isPreviewPlaying = false;
  bool _holdActive = false;
  Timer? _maxDurationTimer;
  StreamSubscription<void>? _playbackSub;

  bool get _hasRecording =>
      widget.recordingPath != null && widget.recordingPath!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _playbackSub = VoiceService.onPlaybackComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _isPreviewPlaying = false);
    });
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    _playbackSub?.cancel();
    if (_isPreviewPlaying) {
      unawaited(VoiceService.stop());
    }
    super.dispose();
  }

  void _setRecording(bool value) {
    if (_isRecording == value) {
      return;
    }
    setState(() => _isRecording = value);
    widget.onRecordingStateChanged?.call(value);
  }

  Future<void> _beginRecording() async {
    if (_holdActive || _isRecording) {
      return;
    }
    if (!await requestMicrophoneForRecording(context)) {
      return;
    }
    try {
      await VoiceService.stop();
      if (mounted) {
        setState(() => _isPreviewPlaying = false);
      }
      await VoiceService.startRecording();
      if (!mounted) {
        return;
      }
      setState(() => _holdActive = true);
      _setRecording(true);
      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(const Duration(seconds: 30), _finishRecording);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).reminderSnackMicPermission)),
      );
    }
  }

  Future<void> _finishRecording() async {
    _maxDurationTimer?.cancel();
    if (!_isRecording && !_holdActive) {
      return;
    }
    final String? path = await VoiceService.stopRecording();
    if (!mounted) {
      return;
    }
    setState(() {
      _holdActive = false;
      if (path != null && path.isNotEmpty) {
        widget.onRecordingPathChanged(path);
      }
    });
    _setRecording(false);
  }

  Future<void> _togglePreview() async {
    if (!_hasRecording) {
      return;
    }
    if (_isPreviewPlaying) {
      await VoiceService.stop();
      if (!mounted) {
        return;
      }
      setState(() => _isPreviewPlaying = false);
      return;
    }
    await VoiceService.play(voicePath: widget.recordingPath);
    if (!mounted) {
      return;
    }
    setState(() => _isPreviewPlaying = true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String holdLabel = _isRecording
        ? l10n.reminderReleaseToStop
        : (_hasRecording ? l10n.reminderRerecord : l10n.reminderHoldToRecord);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (_hasRecording) ...<Widget>[
            _PreviewButton(
              isPlaying: _isPreviewPlaying,
              onPressed: _togglePreview,
            ),
            const SizedBox(width: 12),
          ],
          Listener(
            onPointerDown: (_) => unawaited(_beginRecording()),
            onPointerUp: (_) => unawaited(_finishRecording()),
            onPointerCancel: (_) => unawaited(_finishRecording()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: _isRecording
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                boxShadow: _isRecording
                    ? <BoxShadow>[
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.mic_rounded,
                    size: 20,
                    color: _isRecording ? Colors.white : AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    holdLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _isRecording ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.isPlaying,
    required this.onPressed,
  });

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primaryColor.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: AppTheme.primaryColor,
            size: 26,
          ),
        ),
      ),
    );
  }
}
