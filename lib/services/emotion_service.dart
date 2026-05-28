class EmotionService {
  static String detectEmotionTag(String text) {
    final String value = text.trim();
    if (value.isEmpty) {
      return 'reminder';
    }
    if (_containsAny(value, <String>['妈妈', '家人', '朋友', '关心', '陪'])) {
      return 'caring';
    }
    if (_containsAny(value, <String>['马上', '立刻', '紧急', '赶紧', 'deadline', '截止'])) {
      return 'urgent';
    }
    if (_containsAny(value, <String>['顺便', '有空', '记一下', '晚点'])) {
      return 'casual';
    }
    return 'reminder';
  }

  static String suggestVoiceId(String emotionTag) {
    switch (emotionTag) {
      case 'urgent':
        return 'calm_male';
      case 'caring':
        return 'warm_female';
      case 'casual':
        return 'default';
      case 'reminder':
      default:
        return 'default';
    }
  }

  static bool _containsAny(String text, List<String> keywords) {
    for (final String keyword in keywords) {
      if (text.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
}
