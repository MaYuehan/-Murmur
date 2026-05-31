import 'package:flutter/material.dart';
import 'package:murmur/core/constants/app_strings.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/widgets/app_ui.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
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
                      AppStrings.appTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.comingSoon,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const AppSectionHeader(title: '提醒'),
          AppGroupedSection(
            children: <Widget>[
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                secondary: const Icon(
                  Icons.volume_off_outlined,
                  color: AppTheme.secondaryLabelColor,
                ),
                title: const Text('亲声静音'),
                subtitle: const Text('开启后，到点只显示通知，不自动播放亲声'),
                value: _voiceRemindMuted,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: _setVoiceRemindMuted,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const AppSectionHeader(title: '即将推出'),
          AppGroupedSection(
            children: <Widget>[
              const AppListTile(
                title: '习惯学习',
                subtitle: '了解你的提醒偏好',
                leadingIcon: Icons.auto_awesome_outlined,
                leadingIconColor: AppTheme.primaryColor,
              ),
              const AppListTile(
                title: '亲声库管理',
                subtitle: '统一管理录音与预设',
                leadingIcon: Icons.library_music_outlined,
                leadingIconColor: AppTheme.iosBlue,
              ),
              const AppListTile(
                title: '同步与备份',
                subtitle: '跨设备保留你的亲声',
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
