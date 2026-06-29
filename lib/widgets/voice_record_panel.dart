import 'dart:async';

import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/microphone_permission.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/voice_recording_entry.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/app_ui.dart';

enum VoiceRecordInputMode { record, saved }

class VoiceRecordPanelStatus {
  const VoiceRecordPanelStatus({
    required this.inputMode,
    required this.hasSelection,
  });

  final VoiceRecordInputMode inputMode;
  final bool hasSelection;

  static String? footnoteFor({
    required AppLocalizations l10n,
    required VoiceRecordPanelStatus status,
    required bool isRecording,
  }) {
    if (isRecording) {
      return l10n.reminderRecordingInProgress;
    }
    if (status.hasSelection) {
      return null;
    }
    if (status.inputMode == VoiceRecordInputMode.saved) {
      return l10n.voiceSavedTabEmptyHint;
    }
    return l10n.voiceRecordTabEmptyHint;
  }
}

class VoiceRecordPanel extends StatefulWidget {
  const VoiceRecordPanel({
    super.key,
    this.recordingPath,
    required this.onRecordingPathChanged,
    this.onRecordingStateChanged,
    this.onStatusChanged,
  });

  final String? recordingPath;
  final ValueChanged<String?> onRecordingPathChanged;
  final ValueChanged<bool>? onRecordingStateChanged;
  final ValueChanged<VoiceRecordPanelStatus>? onStatusChanged;

  @override
  State<VoiceRecordPanel> createState() => _VoiceRecordPanelState();
}

class _VoiceRecordPanelState extends State<VoiceRecordPanel> {
  static const double _recordButtonSize = 68;
  static const double _recordButtonRingSize = 84;
  static const double _rerecordIdleSize = 52;
  static const double _rerecordActiveSize = 72;
  static const double _rerecordActiveRingSize = 80;
  static const double _compactControlHeight = 44;

  VoiceRecordInputMode _inputMode = VoiceRecordInputMode.record;
  VoiceRecordInputMode _committedInputMode = VoiceRecordInputMode.record;
  String? _tempRecordingPath;
  String? _savedRecordingPath;
  bool _isRecording = false;
  bool _isPreviewPlaying = false;
  bool _holdActive = false;
  Timer? _maxDurationTimer;
  StreamSubscription<void>? _playbackSub;
  StreamSubscription<void>? _recordingsChangedSub;
  List<VoiceRecordingEntry> _savedRecordings = <VoiceRecordingEntry>[];

  String? get _committedPath => _committedInputMode == VoiceRecordInputMode.record
      ? _tempRecordingPath
      : _savedRecordingPath;

  @override
  void initState() {
    super.initState();
    _applyExternalPath(widget.recordingPath, notifyStatus: false);
    unawaited(_loadSavedRecordings());
    _playbackSub = VoiceService.onPlaybackComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _isPreviewPlaying = false);
    });
    _recordingsChangedSub = VoiceService.onRecordingsChanged.listen((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadSavedRecordings());
    });
    _scheduleSyncStatus();
  }

  @override
  void didUpdateWidget(covariant VoiceRecordPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recordingPath != widget.recordingPath) {
      _applyExternalPath(widget.recordingPath, notifyStatus: false);
      _scheduleSyncStatus();
    }
  }

  void _applyExternalPath(String? path, {bool notifyStatus = true}) {
    void apply() {
      if (path == null || path.isEmpty) {
        _tempRecordingPath = null;
        _savedRecordingPath = null;
        _inputMode = VoiceRecordInputMode.record;
        _committedInputMode = VoiceRecordInputMode.record;
        return;
      }
      if (path.contains('/saved/')) {
        _savedRecordingPath = path;
        _inputMode = VoiceRecordInputMode.saved;
        _committedInputMode = VoiceRecordInputMode.saved;
      } else {
        _tempRecordingPath = path;
        _inputMode = VoiceRecordInputMode.record;
        _committedInputMode = VoiceRecordInputMode.record;
      }
    }

    if (!notifyStatus) {
      apply();
      return;
    }

    if (mounted) {
      setState(apply);
      _scheduleSyncStatus();
    } else {
      apply();
    }
  }

  VoiceRecordPanelStatus _buildStatus() {
    final bool hasSelection =
        _committedPath != null && _committedPath!.isNotEmpty;
    return VoiceRecordPanelStatus(
      inputMode: hasSelection ? _committedInputMode : _inputMode,
      hasSelection: hasSelection,
    );
  }

  bool _statusSyncScheduled = false;

  void _scheduleSyncStatus() {
    if (!mounted || widget.onStatusChanged == null || _statusSyncScheduled) {
      return;
    }
    _statusSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _statusSyncScheduled = false;
      if (!mounted || widget.onStatusChanged == null) {
        return;
      }
      widget.onStatusChanged!(_buildStatus());
    });
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    if (_isRecording || _holdActive) {
      unawaited(VoiceService.stopRecording());
    }
    unawaited(_playbackSub?.cancel());
    unawaited(_recordingsChangedSub?.cancel());
    if (_isPreviewPlaying) {
      unawaited(VoiceService.stop());
    }
    super.dispose();
  }

  Future<void> _loadSavedRecordings() async {
    final List<VoiceRecordingEntry> saved = await VoiceService.loadSavedRecordings();
    if (!mounted) {
      return;
    }
    setState(() {
      _savedRecordings = saved;
      if (_savedRecordingPath != null &&
          !saved.any((VoiceRecordingEntry entry) => entry.filePath == _savedRecordingPath)) {
        _savedRecordingPath = null;
        if (_committedInputMode == VoiceRecordInputMode.saved) {
          _notifyCommittedPath();
        }
      }
      _scheduleSyncStatus();
    });
  }

  String? _savedSelectionLabel() {
    if (_savedRecordingPath == null) {
      return null;
    }
    for (final VoiceRecordingEntry entry in _savedRecordings) {
      if (entry.filePath == _savedRecordingPath) {
        return entry.displayName;
      }
    }
    return _savedRecordingPath!.split('/').last;
  }

  Future<void> _stopPreview() async {
    await VoiceService.stop();
    if (!mounted) {
      return;
    }
    setState(() => _isPreviewPlaying = false);
  }

  void _notifyCommittedPath() {
    widget.onRecordingPathChanged(_committedPath);
    _scheduleSyncStatus();
  }

  Future<void> _selectInputMode(VoiceRecordInputMode mode) async {
    if (_inputMode == mode) {
      return;
    }
    await _stopPreview();
    if (!mounted) {
      return;
    }
    setState(() => _inputMode = mode);
    _scheduleSyncStatus();
  }

  Future<void> _pickSavedRecording() async {
    if (_savedRecordings.isEmpty) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    await _stopPreview();
    if (!mounted) {
      return;
    }

    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTheme.groupedBackgroundColor,
      builder: (BuildContext sheetContext) {
        return _SavedRecordingPickerSheet(
          title: l10n.voicePickSavedRecordingTitle,
          recordings: _savedRecordings,
          currentPath: _savedRecordingPath,
        );
      },
    );
    if (picked == null || picked.isEmpty || !mounted) {
      return;
    }
    if (picked == _savedRecordingPath &&
        _committedInputMode == VoiceRecordInputMode.saved) {
      return;
    }
    final String? previousTemp = _tempRecordingPath;
    setState(() {
      _savedRecordingPath = picked;
      _inputMode = VoiceRecordInputMode.saved;
      _committedInputMode = VoiceRecordInputMode.saved;
      _tempRecordingPath = null;
    });
    _notifyCommittedPath();
    if (previousTemp != null && previousTemp.isNotEmpty) {
      unawaited(VoiceService.deleteRecordingIfUnused(previousTemp));
    }
  }

  void _setRecording(bool value) {
    if (_isRecording == value) {
      return;
    }
    setState(() => _isRecording = value);
    widget.onRecordingStateChanged?.call(value);
    _scheduleSyncStatus();
  }

  Future<void> _beginRecording() async {
    if (_holdActive || _isRecording) {
      return;
    }
    if (!await requestMicrophoneForRecording(context)) {
      return;
    }
    try {
      await _stopPreview();
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
    final String? previousPath = _tempRecordingPath;
    final String? path = await VoiceService.stopRecording();
    if (!mounted) {
      return;
    }
    setState(() {
      _holdActive = false;
      if (path != null && path.isNotEmpty) {
        _tempRecordingPath = path;
        _inputMode = VoiceRecordInputMode.record;
        _committedInputMode = VoiceRecordInputMode.record;
        _savedRecordingPath = null;
      }
    });
    _setRecording(false);
    if (path != null && path.isNotEmpty) {
      _notifyCommittedPath();
    }
    if (previousPath != null &&
        previousPath.isNotEmpty &&
        path != null &&
        path.isNotEmpty &&
        previousPath != path) {
      unawaited(VoiceService.deleteRecordingIfUnused(previousPath));
    }
  }

  Future<void> _togglePreview() async {
    if (_tempRecordingPath == null || _tempRecordingPath!.isEmpty) {
      return;
    }
    if (_isPreviewPlaying) {
      await _stopPreview();
      return;
    }
    await VoiceService.play(voicePath: _tempRecordingPath);
    if (!mounted) {
      return;
    }
    setState(() => _isPreviewPlaying = true);
  }

  Widget _buildInputModeSelector(AppLocalizations l10n) {
    if (_savedRecordings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Center(
        child: AppUnderlineTabControl<VoiceRecordInputMode>(
          options: <AppSegmentOption<VoiceRecordInputMode>>[
            AppSegmentOption(
              value: VoiceRecordInputMode.record,
              label: l10n.voiceRecordInputTab,
            ),
            AppSegmentOption(
              value: VoiceRecordInputMode.saved,
              label: l10n.voiceSavedInputTab,
            ),
          ],
          selected: _inputMode,
          onChanged: (VoiceRecordInputMode mode) => unawaited(_selectInputMode(mode)),
        ),
      ),
    );
  }

  Widget _buildInitialRecordButton() {
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

  Widget _buildRerecordButton() {
    final double micSize =
        _isRecording ? _rerecordActiveSize : _rerecordIdleSize;
    final double ringSize =
        _isRecording ? _rerecordActiveRingSize : _rerecordIdleSize + 10;

    return Listener(
      onPointerDown: (_) => unawaited(_beginRecording()),
      onPointerUp: (_) => unawaited(_finishRecording()),
      onPointerCancel: (_) => unawaited(_finishRecording()),
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (!_isRecording)
              Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: micSize,
              height: micSize,
              decoration: BoxDecoration(
                color: _isRecording
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                boxShadow: _isRecording
                    ? <BoxShadow>[
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.mic_rounded,
                size: _isRecording ? 30 : 24,
                color: _isRecording ? Colors.white : AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPreviewButton(AppLocalizations l10n) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: _compactControlHeight,
      child: OutlinedButton.icon(
        onPressed: () => unawaited(_togglePreview()),
        icon: Icon(
          _isPreviewPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 20,
        ),
        label: Text(
          _isPreviewPlaying ? l10n.voiceStop : l10n.reminderPreviewPlay,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, _compactControlHeight),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildCompactRecordedRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: _isRecording
                ? SizedBox(
                    height: _compactControlHeight,
                    child: Center(
                      child: Text(
                        l10n.reminderReleaseToStop,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  )
                : _buildCompactPreviewButton(l10n),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Center(child: _buildRerecordButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordSection(AppLocalizations l10n) {
    final bool hasTempRecording =
        _tempRecordingPath != null && _tempRecordingPath!.isNotEmpty;

    if (hasTempRecording) {
      return _buildCompactRecordedRow(l10n);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildInitialRecordButton(),
        const SizedBox(height: 8),
        Text(
          _isRecording ? l10n.reminderReleaseToStop : l10n.reminderHoldToRecord,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _isRecording
                ? AppTheme.primaryColor
                : AppTheme.secondaryLabelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSavedSection(AppLocalizations l10n) {
    final String? savedSelectionLabel = _savedSelectionLabel();

    return AppDetailTile(
      icon: Icons.favorite_rounded,
      iconColor: AppTheme.primaryColor,
      title: l10n.voicePickSavedRecording,
      value: savedSelectionLabel ?? l10n.commonPleaseSelect,
      placeholder: savedSelectionLabel == null,
      onTap: _pickSavedRecording,
      showDivider: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildInputModeSelector(l10n),
          if (_savedRecordings.isEmpty || _inputMode == VoiceRecordInputMode.record)
            _buildRecordSection(l10n)
          else
            _buildSavedSection(l10n),
        ],
      ),
    );
  }
}

class _SavedRecordingPickerSheet extends StatefulWidget {
  const _SavedRecordingPickerSheet({
    required this.title,
    required this.recordings,
    this.currentPath,
  });

  final String title;
  final List<VoiceRecordingEntry> recordings;
  final String? currentPath;

  @override
  State<_SavedRecordingPickerSheet> createState() => _SavedRecordingPickerSheetState();
}

class _SavedRecordingPickerSheetState extends State<_SavedRecordingPickerSheet> {
  String? _playingPath;
  StreamSubscription<void>? _playbackSub;

  @override
  void initState() {
    super.initState();
    _playbackSub = VoiceService.onPlaybackComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _playingPath = null);
    });
  }

  @override
  void dispose() {
    unawaited(_playbackSub?.cancel());
    if (_playingPath != null) {
      unawaited(VoiceService.stop());
    }
    super.dispose();
  }

  Future<void> _togglePreview(VoiceRecordingEntry entry) async {
    final bool isPlayingThis = _playingPath == entry.filePath;
    if (isPlayingThis) {
      await VoiceService.stop();
      if (!mounted) {
        return;
      }
      setState(() => _playingPath = null);
      return;
    }
    await VoiceService.stop();
    await VoiceService.play(voicePath: entry.filePath);
    if (!mounted) {
      return;
    }
    setState(() => _playingPath = entry.filePath);
  }

  Widget _playButton({
    required bool isPlayingThis,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.iosBlue.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 20,
            color: AppTheme.iosBlue,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          AppGroupedSection(
            children: <Widget>[
              ...widget.recordings.asMap().entries.map((MapEntry<int, VoiceRecordingEntry> entry) {
                final VoiceRecordingEntry recording = entry.value;
                final bool isSelected = recording.filePath == widget.currentPath;
                final bool isPlayingThis = _playingPath == recording.filePath;
                final bool isLast = entry.key == widget.recordings.length - 1;

                return Column(
                  children: <Widget>[
                    Material(
                      color: AppTheme.cardColor,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(
                          children: <Widget>[
                            _playButton(
                              isPlayingThis: isPlayingThis,
                              onPressed: () => unawaited(_togglePreview(recording)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(recording.filePath),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    recording.displayName,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight:
                                              isSelected ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check,
                                color: AppTheme.iosBlue,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        thickness: 0.5,
                        indent: 62,
                        color: AppTheme.separatorColor,
                      ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
