import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/providers/locale_provider.dart';
import 'package:murmur/providers/todo_display_settings_provider.dart';
import 'package:murmur/widgets/app_ui.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _voiceRemindMuted = AppSettingsStorage.voiceRemindMuted;

  Future<void> _setVoiceRemindMuted(bool value) async {
    await AppSettingsStorage.setVoiceRemindMuted(value);
    if (!mounted) {
      return;
    }
    setState(() => _voiceRemindMuted = value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Locale locale = ref.watch(localeProvider);
    final bool showTodoCreatedDate = ref.watch(showTodoCreatedDateProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profilePageTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.pagePadding,
          8,
          AppTheme.pagePadding,
          32,
        ),
        children: <Widget>[
          AppGroupedSection(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 36,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.appTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.comingSoon,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppSectionHeader(title: l10n.profileSectionReminders),
          AppGroupedSection(
            children: <Widget>[
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: const Icon(
                  Icons.volume_off_outlined,
                  color: AppTheme.secondaryLabelColor,
                ),
                title: Text(l10n.profileVoiceMuteTitle),
                subtitle: Text(l10n.profileVoiceMuteSubtitle),
                value: _voiceRemindMuted,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: _setVoiceRemindMuted,
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: const Icon(
                  Icons.schedule_outlined,
                  color: AppTheme.secondaryLabelColor,
                ),
                title: Text(l10n.profileShowTodoCreatedDateTitle),
                subtitle: Text(l10n.profileShowTodoCreatedDateSubtitle),
                value: showTodoCreatedDate,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (bool value) {
                  ref
                      .read(showTodoCreatedDateProvider.notifier)
                      .setShowTodoCreatedDate(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppSectionHeader(title: l10n.profileSectionLanguage),
          AppGroupedSection(
            children: <Widget>[
              RadioListTile<Locale>(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(l10n.profileLanguageChinese),
                value: const Locale('zh'),
                groupValue: locale,
                activeColor: AppTheme.primaryColor,
                onChanged: (Locale? value) {
                  if (value != null) {
                    ref.read(localeProvider.notifier).setLanguageCode('zh');
                  }
                },
              ),
              RadioListTile<Locale>(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(l10n.profileLanguageEnglish),
                value: const Locale('en'),
                groupValue: locale,
                activeColor: AppTheme.primaryColor,
                onChanged: (Locale? value) {
                  if (value != null) {
                    ref.read(localeProvider.notifier).setLanguageCode('en');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppSectionHeader(title: l10n.profileSectionComingSoon),
          AppGroupedSection(
            children: <Widget>[
              AppListTile(
                title: l10n.profileHabitLearningTitle,
                subtitle: l10n.profileHabitLearningSubtitle,
                leadingIcon: Icons.auto_awesome_outlined,
                leadingIconColor: AppTheme.primaryColor,
              ),
              AppListTile(
                title: l10n.profileVoiceLibraryTitle,
                subtitle: l10n.profileVoiceLibrarySubtitle,
                leadingIcon: Icons.library_music_outlined,
                leadingIconColor: AppTheme.iosBlue,
              ),
              AppListTile(
                title: l10n.profileSyncBackupTitle,
                subtitle: l10n.profileSyncBackupSubtitle,
                leadingIcon: Icons.cloud_outlined,
                leadingIconColor: AppTheme.secondaryLabelColor,
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
