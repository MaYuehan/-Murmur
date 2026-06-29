class VoiceRecordingEntry {
  const VoiceRecordingEntry({
    required this.filePath,
    required this.createdAt,
    this.savedName,
    required this.isSaved,
  });

  final String filePath;
  final DateTime createdAt;
  final String? savedName;
  final bool isSaved;

  String get displayName =>
      savedName ?? filePath.split('/').last;

  int get daysUntilExpiry {
    if (isSaved) {
      return -1;
    }
    const int retentionDays = 7;
    final int elapsed = DateTime.now().difference(createdAt).inDays;
    return retentionDays - elapsed;
  }

  bool get isExpired => !isSaved && daysUntilExpiry < 0;
}
