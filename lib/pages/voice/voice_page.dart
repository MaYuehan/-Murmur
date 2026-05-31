import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/app_ui.dart';

class VoicePage extends StatefulWidget {
  const VoicePage({super.key});

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  List<VoiceOption> _recordings = <VoiceOption>[];
  bool _isPlaying = false;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    final List<VoiceOption> list = await VoiceService.loadRecordings();
    if (!mounted) {
      return;
    }
    setState(() => _recordings = list);
  }

  Future<void> _playVoice(VoiceOption option) async {
    setState(() {
      _isPlaying = true;
      _playingId = option.id;
    });
    await VoiceService.play(voicePath: option.filePath, voiceId: option.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _isPlaying = false;
      _playingId = null;
    });
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

  String _voiceSubtitle(AppLocalizations l10n, VoiceOption voice, {required bool isDefault}) {
    if (isDefault) {
      return l10n.voiceDefaultPreset;
    }
    return l10n.voiceTapToPreview;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.voicePageTitle),
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
          if (_isPlaying)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppGroupedSection(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.volume_up_rounded, color: scheme.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l10n.voicePlaying,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _stopVoice,
                          icon: const Icon(Icons.stop_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.primary.withValues(alpha: 0.16),
                            foregroundColor: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          AppSectionHeader(title: l10n.voiceSectionPresets),
          AppGroupedSection(
            children: <Widget>[
              ...VoiceService.presetVoices.asMap().entries.map((MapEntry<int, VoiceOption> entry) {
                final VoiceOption voice = entry.value;
                final bool isDefault = voice.id == VoiceService.defaultVoiceId;
                final bool isLast = entry.key == VoiceService.presetVoices.length - 1;
                final bool isPlayingThis = _playingId == voice.id && _isPlaying;

                return AppListTile(
                  title: voice.name,
                  subtitle: _voiceSubtitle(l10n, voice, isDefault: isDefault),
                  leadingIcon: Icons.graphic_eq_rounded,
                  leadingIconColor: scheme.primary,
                  showDivider: !isLast,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: isPlayingThis ? _stopVoice : () => _playVoice(voice),
                        icon: Icon(
                          isPlayingThis ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                        ),
                        color: scheme.primary,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: () => setState(() => VoiceService.setDefaultVoice(voice.id)),
                        icon: Icon(
                          isDefault ? Icons.check_circle : Icons.circle_outlined,
                          color: isDefault ? scheme.primary : AppTheme.secondaryLabelColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 20),
          AppSectionHeader(title: l10n.voiceSectionRecordings),
          if (_recordings.isEmpty)
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
                ..._recordings.asMap().entries.map((MapEntry<int, VoiceOption> entry) {
                  final VoiceOption record = entry.value;
                  final bool isDefault = record.id == VoiceService.defaultVoiceId;
                  final bool isLast = entry.key == _recordings.length - 1;
                  final bool isPlayingThis = _playingId == record.id && _isPlaying;

                  return AppListTile(
                    title: record.name,
                    subtitle: isDefault ? l10n.voiceDefaultPreset : l10n.voiceLocalRecording,
                    leadingIcon: Icons.mic_none_rounded,
                    leadingIconColor: AppTheme.iosBlue,
                    showDivider: !isLast,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: isPlayingThis ? _stopVoice : () => _playVoice(record),
                          icon: Icon(
                            isPlayingThis ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                          ),
                          color: AppTheme.iosBlue,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          onPressed: () => setState(() => VoiceService.setDefaultVoice(record.id)),
                          icon: Icon(
                            isDefault ? Icons.check_circle : Icons.circle_outlined,
                            color: isDefault ? scheme.primary : AppTheme.secondaryLabelColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }
}
