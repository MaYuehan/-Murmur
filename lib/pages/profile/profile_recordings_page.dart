import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/models/voice_recording_entry.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/app_ui.dart';

class ProfileRecordingsPage extends ConsumerStatefulWidget {
  const ProfileRecordingsPage({super.key});

  @override
  ConsumerState<ProfileRecordingsPage> createState() => _ProfileRecordingsPageState();
}

class _ProfileRecordingsPageState extends ConsumerState<ProfileRecordingsPage> {
  List<VoiceRecordingEntry> _saved = <VoiceRecordingEntry>[];
  List<VoiceRecordingEntry> _temporary = <VoiceRecordingEntry>[];
  bool _isPlaying = false;
  String? _playingId;
  String? _editingRecordingPath;
  StreamSubscription<void>? _recordingsChangedSub;
  StreamSubscription<void>? _playbackSub;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _recordingsChangedSub = VoiceService.onRecordingsChanged.listen((_) {
      if (!mounted || _editingRecordingPath != null) {
        return;
      }
      unawaited(_loadRecordings());
    });
    _playbackSub = VoiceService.onPlaybackComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _playingId = null;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_recordingsChangedSub?.cancel());
    unawaited(_playbackSub?.cancel());
    if (_isPlaying) {
      unawaited(VoiceService.stop());
    }
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    final List<VoiceRecordingEntry> saved = await VoiceService.loadSavedRecordings();
    final List<VoiceRecordingEntry> temporary =
        await VoiceService.loadTemporaryRecordings();
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = saved;
      _temporary = temporary;
    });
  }

  Future<void> _playRecording(VoiceRecordingEntry entry) async {
    setState(() {
      _isPlaying = true;
      _playingId = entry.filePath;
    });
    await VoiceService.play(voicePath: entry.filePath);
  }

  Future<void> _stopVoice() async {
    await VoiceService.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = false;
      _playingId = null;
    });
  }

  Future<void> _saveRecording(VoiceRecordingEntry entry) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = entry.displayName.trim();
    if (name.isEmpty || !mounted) {
      return;
    }
    await VoiceService.saveRecordingToLibrary(
      tempPath: entry.filePath,
      displayName: name,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.voiceRecordingSavedToast)),
    );
    await _loadRecordings();
  }

  Future<void> _renameRecording({
    required String filePath,
    required String displayName,
  }) async {
    await VoiceService.renameRecording(
      filePath: filePath,
      displayName: displayName,
    );
    if (!mounted) {
      return;
    }
    await _loadRecordings();
  }

  Future<void> _unsaveRecording(VoiceRecordingEntry entry) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int reminderUsageCount = ref
        .read(reminderListProvider)
        .where((Reminder reminder) => reminder.voicePath == entry.filePath)
        .length;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.voiceUnsaveRecordingTitle),
          content: Text(
            reminderUsageCount > 0
                ? l10n.voiceUnsaveRecordingMessageWithReminders(
                    entry.displayName,
                    reminderUsageCount,
                  )
                : l10n.voiceUnsaveRecordingMessage(entry.displayName),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.voiceUnsaveRecordingConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    if (_playingId == entry.filePath) {
      await _stopVoice();
    }
    final String oldPath = entry.filePath;
    final VoiceRecordingEntry moved = await VoiceService.removeRecordingFromLibrary(
      savedPath: oldPath,
    );
    await ref.read(reminderListProvider.notifier).remapVoicePath(
          oldPath,
          moved.filePath,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.voiceRecordingUnsavedToast)),
    );
    await _loadRecordings();
  }

  Widget _recordingTile({
    required AppLocalizations l10n,
    required VoiceRecordingEntry entry,
    required bool showDivider,
    required bool showSaveAction,
    required bool showUnsaveAction,
  }) {
    final bool isPlayingThis = _playingId == entry.filePath && _isPlaying;
    final String subtitle = entry.isSaved
        ? l10n.voiceRecordingSavedToast
        : (entry.daysUntilExpiry > 0
            ? l10n.voiceRecordingExpiresIn(entry.daysUntilExpiry)
            : l10n.voiceLocalRecording);

    return _RecordingListTile(
      entry: entry,
      subtitle: subtitle,
      showDivider: showDivider,
      showSaveAction: showSaveAction,
      showUnsaveAction: showUnsaveAction,
      editing: _editingRecordingPath == entry.filePath,
      isPlayingThis: isPlayingThis,
      onEditStart: () => setState(() => _editingRecordingPath = entry.filePath),
      onEditEnd: () => setState(() => _editingRecordingPath = null),
      onRename: (String name) => _renameRecording(
        filePath: entry.filePath,
        displayName: name,
      ),
      onPlay: () => _playRecording(entry),
      onStop: _stopVoice,
      onSave: () => _saveRecording(entry),
      onUnsave: () => _unsaveRecording(entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voiceSectionRecordings),
        actions: <Widget>[
          AppBarTextAction(label: l10n.commonRefresh, onPressed: _loadRecordings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          8,
          AppTheme.pagePadding,
          32,
        ),
        children: <Widget>[
          AppFootnote(
            text: l10n.voiceRecordingsRetentionHint,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          ),
          AppSectionHeader(title: l10n.voiceSectionSavedRecordings),
          if (_saved.isEmpty)
            AppGroupedSection(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      l10n.voiceEmptySavedRecordings,
                      style: const TextStyle(color: AppTheme.secondaryLabelColor),
                    ),
                  ),
                ),
              ],
            )
          else
            AppGroupedSection(
              children: <Widget>[
                ..._saved.asMap().entries.map((MapEntry<int, VoiceRecordingEntry> entry) {
                  return _recordingTile(
                    l10n: l10n,
                    entry: entry.value,
                    showDivider: entry.key < _saved.length - 1,
                    showSaveAction: false,
                    showUnsaveAction: true,
                  );
                }),
              ],
            ),
          const SizedBox(height: 20),
          AppSectionHeader(title: l10n.voiceSectionRecentRecordings),
          if (_temporary.isEmpty)
            AppGroupedSection(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      l10n.voiceEmptyRecordings,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.secondaryLabelColor,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            AppGroupedSection(
              children: <Widget>[
                ..._temporary.asMap().entries.map((MapEntry<int, VoiceRecordingEntry> entry) {
                  return _recordingTile(
                    l10n: l10n,
                    entry: entry.value,
                    showDivider: entry.key < _temporary.length - 1,
                    showSaveAction: true,
                    showUnsaveAction: false,
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}

class _RecordingListTile extends StatefulWidget {
  const _RecordingListTile({
    required this.entry,
    required this.subtitle,
    required this.showDivider,
    required this.showSaveAction,
    required this.showUnsaveAction,
    required this.editing,
    required this.isPlayingThis,
    required this.onEditStart,
    required this.onEditEnd,
    required this.onRename,
    required this.onPlay,
    required this.onStop,
    required this.onSave,
    required this.onUnsave,
  });

  final VoiceRecordingEntry entry;
  final String subtitle;
  final bool showDivider;
  final bool showSaveAction;
  final bool showUnsaveAction;
  final bool editing;
  final bool isPlayingThis;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;
  final Future<void> Function(String name) onRename;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onSave;
  final VoidCallback onUnsave;

  @override
  State<_RecordingListTile> createState() => _RecordingListTileState();
}

class _RecordingListTileState extends State<_RecordingListTile> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  String _lastSavedName = '';
  bool _suppressFocusExit = false;
  bool _isExitingEdit = false;

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppTheme.textPrimaryColor,
  );

  @override
  void initState() {
    super.initState();
    _lastSavedName = widget.entry.displayName;
    _nameController = TextEditingController(text: widget.entry.displayName);
    _nameFocusNode = FocusNode();
    _nameFocusNode.addListener(_onNameFocusChange);
    if (widget.editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    }
  }

  @override
  void didUpdateWidget(covariant _RecordingListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing && !oldWidget.editing) {
      _lastSavedName = widget.entry.displayName;
      _nameController.text = widget.entry.displayName;
      _suppressFocusExit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    } else if (!widget.editing && oldWidget.editing) {
      _suppressFocusExit = false;
      _nameController.text = widget.entry.displayName;
      _lastSavedName = widget.entry.displayName;
    } else if (!widget.editing &&
        oldWidget.entry.displayName != widget.entry.displayName) {
      _nameController.text = widget.entry.displayName;
      _lastSavedName = widget.entry.displayName;
    }
  }

  @override
  void dispose() {
    _suppressFocusExit = true;
    _nameFocusNode.removeListener(_onNameFocusChange);
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _requestEditFocus() {
    if (!mounted || !widget.editing) {
      return;
    }
    _nameFocusNode.requestFocus();
    _nameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _nameController.text.length,
    );
  }

  void _onNameFocusChange() {
    if (_suppressFocusExit || !_nameFocusNode.hasFocus || !widget.editing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _suppressFocusExit ||
          _nameFocusNode.hasFocus ||
          !widget.editing) {
        return;
      }
      unawaited(_exitNameEdit());
    });
  }

  Future<void> _exitNameEdit() async {
    if (!widget.editing || _isExitingEdit) {
      return;
    }
    _isExitingEdit = true;
    try {
      final String value = _nameController.text.trim();
      if (value.isEmpty) {
        _nameController.text = _lastSavedName;
        widget.onEditEnd();
        return;
      }
      if (value != _lastSavedName) {
        await widget.onRename(value);
        if (!mounted) {
          return;
        }
        _lastSavedName = value;
      }
      widget.onEditEnd();
    } finally {
      _isExitingEdit = false;
      _suppressFocusExit = false;
    }
  }

  Future<void> _onNameSubmitted(String _) async {
    if (!widget.editing || _isExitingEdit) {
      return;
    }
    _suppressFocusExit = true;
    await _exitNameEdit();
  }

  Widget _playLeadingButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.isPlayingThis ? widget.onStop : widget.onPlay,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.iosBlue.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isPlayingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 20,
            color: AppTheme.iosBlue,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Material(
          color: AppTheme.cardColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _playLeadingButton(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (widget.editing)
                        TextField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          style: _titleStyle,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isCollapsed: true,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (String value) => unawaited(_onNameSubmitted(value)),
                        )
                      else
                        GestureDetector(
                          onDoubleTap: widget.onEditStart,
                          child: Text(
                            widget.entry.displayName,
                            style: _titleStyle,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showSaveAction)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: widget.onSave,
                    icon: const Icon(Icons.favorite_border_rounded),
                    color: AppTheme.secondaryLabelColor,
                  )
                else if (widget.showUnsaveAction)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    onPressed: widget.onUnsave,
                    icon: const Icon(Icons.favorite_rounded),
                    color: AppTheme.primaryColor,
                  ),
              ],
            ),
          ),
        ),
        if (widget.showDivider)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 62,
            color: AppTheme.separatorColor,
          ),
      ],
    );
  }
}
