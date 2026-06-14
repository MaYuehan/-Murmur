const String kTodoDeadlineSectionId = '__deadline__';
const String kTodoNormalSectionId = '__normal__';

String todoGroupSectionId(String groupId) => 'group:$groupId';

bool isTodoGroupSectionId(String sectionId) => sectionId.startsWith('group:');

String? groupIdFromSectionId(String sectionId) {
  if (!isTodoGroupSectionId(sectionId)) {
    return null;
  }
  return sectionId.substring('group:'.length);
}
