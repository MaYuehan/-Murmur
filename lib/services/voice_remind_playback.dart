import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/services/voice_service.dart';

class VoiceRemindPlayback {
  VoiceRemindPlayback._();

  static String resolveVoiceId(Reminder reminder) {
    return reminder.remindVoiceId ??
        reminder.voiceId ??
        (reminder.soundId.isEmpty ? VoiceService.defaultVoiceId : reminder.soundId);
  }

  static Future<void> playForReminder(Reminder reminder) async {
    if (AppSettingsStorage.voiceRemindMuted) {
      return;
    }
    if (!reminder.voiceRemindEnabled || reminder.isCompleted) {
      return;
    }

    await VoiceService.play(
      voicePath: reminder.voicePath,
      voiceId: resolveVoiceId(reminder),
    );
  }
}
