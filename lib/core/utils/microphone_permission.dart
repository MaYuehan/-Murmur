import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/services/voice_service.dart';

Future<bool> requestMicrophoneForRecording(BuildContext context) async {
  final MicrophonePermissionStatus status =
      await VoiceService.ensureRecordingPermission();
  if (status == MicrophonePermissionStatus.granted) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }

  final AppLocalizations l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(l10n.reminderMicPermissionTitle),
        content: Text(l10n.reminderMicPermissionBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              AppSettings.openAppSettings(type: AppSettingsType.settings);
            },
            child: Text(
              l10n.reminderMicPermissionOpenSettings,
              style: const TextStyle(color: AppTheme.iosBlue),
            ),
          ),
        ],
      );
    },
  );
  return false;
}
