import 'dart:async';

import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/microphone_permission.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/voice_preview_button.dart';

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
  static const double _recordButtonSize = 68;
  static const double _recordButtonRingSize = 84;

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

  String _recordHint(AppLocalizations l10n) {
    if (_isRecording) {
      return l10n.reminderReleaseToStop;
    }
    if (_hasRecording) {
      return l10n.reminderRerecord;
    }
    return l10n.reminderHoldToRecord;
  }

  Widget _buildRecordButton() {
    return Listener(
      onPointerDown: (_) => unawaited(_beginRecording()),
      onPointerUp: (_) => unawaited(_finishRecording()),
      onPointerCancel: (_) => unawaited(_finishRecording()),
      child: SizedBox(
        width: _recordButtonRingSize,
        height: _recordButtonRingSize,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (!_isRecording)
              Container(
                width: _recordButtonRingSize,
                height: _recordButtonRingSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.18),
                    width: 2,
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: _isRecording ? _recordButtonRingSize : _recordButtonSize,
              height: _isRecording ? _recordButtonRingSize : _recordButtonSize,
              decoration: BoxDecoration(
                color: _isRecording
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                boxShadow: _isRecording
                    ? <BoxShadow>[
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.mic_rounded,
                size: _isRecording ? 34 : 30,
                color: _isRecording ? Colors.white : AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String recordHint = _recordHint(l10n);

    final Widget recordSection = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildRecordButton(),
        const SizedBox(height: 8),
        Text(
          recordHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _hasRecording ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: _isRecording
                ? AppTheme.primaryColor
                : AppTheme.secondaryLabelColor,
          ),
        ),
        if (_hasRecording && !_isRecording) ...<Widget>[
          const SizedBox(height: 16),
          VoicePreviewButton(
            isPlaying: _isPreviewPlaying,
            onPressed: _togglePreview,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: SizedBox(
        width: double.infinity,
        child: _hasRecording
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: recordSection,
              )
            : recordSection,
      ),
    );
  }
}
