import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/services/voice_service.dart';
import 'package:murmur/widgets/app_ui.dart';

class ProfileVoicesPage extends StatefulWidget {
  const ProfileVoicesPage({super.key});

  @override
  State<ProfileVoicesPage> createState() => _ProfileVoicesPageState();
}

class _ProfileVoicesPageState extends State<ProfileVoicesPage> {
  bool _isPlaying = false;
  String? _playingId;

  String _presetLabel(AppLocalizations l10n, String voiceId) {
    switch (voiceId) {
      case 'warm_female':
        return l10n.voicePresetWarmFemale;
      case 'calm_male':
        return l10n.voicePresetCalmMale;
      default:
        return l10n.voicePresetDefault;
    }
  }

  Future<void> _playPreset(VoiceOption voice) async {
    setState(() {
      _isPlaying = true;
      _playingId = voice.id;
    });
    await VoiceService.play(
      voiceId: voice.id,
      text: AppLocalizations.of(context).notificationDefaultBody,
    );
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

  Future<void> _setDefault(String voiceId) async {
    await VoiceService.setDefaultVoice(voiceId);
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String defaultVoiceId = VoiceService.defaultVoiceId;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.voicePageTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          8,
          AppTheme.pagePadding,
          32,
        ),
        children: <Widget>[
          AppSectionHeader(title: l10n.voiceSectionPresets),
          AppGroupedSection(
            children: <Widget>[
              ...VoiceService.presetVoices.asMap().entries.map((MapEntry<int, VoiceOption> entry) {
                final VoiceOption voice = entry.value;
                final bool isDefault = voice.id == defaultVoiceId;
                final bool isLast = entry.key == VoiceService.presetVoices.length - 1;
                final bool isPlayingThis = _playingId == voice.id && _isPlaying;

                return AppListTile(
                  title: _presetLabel(l10n, voice.id),
                  subtitle: isDefault ? l10n.voiceDefaultPreset : l10n.voiceTapToPreview,
                  leadingIcon: Icons.graphic_eq_rounded,
                  leadingIconColor: scheme.primary,
                  showDivider: !isLast,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: isPlayingThis ? _stopVoice : () => _playPreset(voice),
                        icon: Icon(
                          isPlayingThis ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        ),
                        color: scheme.primary,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => _setDefault(voice.id),
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
          AppSectionHeader(title: l10n.voiceSectionCustom),
          AppGroupedSection(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.voiceCustomCloneHint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondaryLabelColor,
                        height: 1.45,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
