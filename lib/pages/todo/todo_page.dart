import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/clear_completed_scope.dart';
import 'package:murmur/core/utils/completed_todo_section.dart';
import 'package:murmur/core/utils/list_sort_order.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/models/todo_group.dart';
import 'package:murmur/providers/calendar_week_start_provider.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/providers/todo_display_settings_provider.dart';
import 'package:murmur/providers/todo_group_provider.dart';
import 'package:murmur/providers/todo_section_expansion_provider.dart';
import 'package:murmur/providers/todo_section_order_provider.dart';
import 'package:murmur/core/utils/todo_section_id.dart';
import 'package:murmur/widgets/app_date_picker.dart';
import 'package:murmur/widgets/app_slidable_action_button.dart';
import 'package:murmur/widgets/app_ui.dart';
import 'package:murmur/pages/todo/todo_sub_items_page.dart';
import 'package:murmur/widgets/create_todo_sheet.dart';
import 'package:murmur/pages/todo/todo_card.dart';

part 'todo_page_models.dart';
part 'todo_page_drag.dart';
part 'todo_page_actions.dart';
part 'todo_page_inline_edit.dart';
part 'todo_list_sections.dart';

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}


abstract class _TodoPageStateBase extends ConsumerState<TodoPage> {
  static const double _todoGroupListBottomPadding = 8;
  static const double _todoGroupExpandedSectionGap = 14;
  static const double _todoGroupCollapsedSectionGap = 6;
  static const double _sectionHeaderDragShiftOffset = 14;
  static const double _todoRowDragShiftOffset = 14;

  bool _isCompletedView = false;
  bool _isCreatingTodoGroup = false;
  final TextEditingController _newTodoGroupNameController = TextEditingController();
  final FocusNode _newTodoGroupFocusNode = FocusNode();
  String? _editingTodoId;
  String? _pendingFocusTodoId;
  bool _pendingFocusSelectAll = true;
  final Set<String> _draftTodoIds = <String>{};
  final ValueNotifier<_SectionDragVisualState> _sectionDragVisualState =
      ValueNotifier<_SectionDragVisualState>(const _SectionDragVisualState());
  final ValueNotifier<_TodoDragVisualState> _todoDragVisualState =
      ValueNotifier<_TodoDragVisualState>(const _TodoDragVisualState());
  final Map<String, _TodoDropListContext> _todoDropListContexts =
      <String, _TodoDropListContext>{};
  final Map<String, Map<int, GlobalKey>> _todoRowMeasureKeys =
      <String, Map<int, GlobalKey>>{};
  final Map<String, GlobalKey> _todoEmptyDropMeasureKeys =
      <String, GlobalKey>{};
  final Map<int, GlobalKey> _sectionHeaderMeasureKeys = <int, GlobalKey>{};
  final Map<int, GlobalKey> _sectionFooterMeasureKeys = <int, GlobalKey>{};
  _SectionDragOrderContext? _sectionDragOrderContext;
  Offset? _todoDragAnchorOffset;
  Size? _todoDragFeedbackSize;
  Offset? _sectionDragAnchorOffset;
  Size? _sectionDragFeedbackSize;
}

class _TodoPageState extends _TodoPageStateBase {
  @override
  void dispose() {
    _sectionDragVisualState.dispose();
    _todoDragVisualState.dispose();
    _newTodoGroupNameController.dispose();
    _newTodoGroupFocusNode.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    ref.watch(reminderListProvider);
    ref.watch(todoGroupListProvider);
    ref.watch(todoSectionOrderProvider);
    ref.watch(calendarWeekStartsOnMondayProvider);
    final TodoSectionExpansionState sectionExpansion =
        ref.watch(todoSectionExpansionProvider);
    final bool showTodoCreatedDate = ref.watch(showTodoCreatedDateProvider);
    final reminderNotifier = ref.read(reminderListProvider.notifier);
    final List<TodoGroup> todoGroups = ref.watch(todoGroupListProvider);
    final List<Reminder> pending = reminderNotifier.getFlexibleReminders(includeCompleted: false);
    final List<Reminder> pendingDeadline =
        pending.where((Reminder item) => item.hasDeadline).toList();
    final List<Reminder> pendingNormal = pending
        .where((Reminder item) => !item.hasDeadline && item.todoGroupId == null)
        .toList();
    final List<Reminder> completed = reminderNotifier
        .getFlexibleReminders(includeCompleted: true)
        .where((Reminder item) => item.isCompleted)
        .toList()
      ..sort((Reminder a, Reminder b) {
        final DateTime aTime = a.completedAt ?? a.createdAt;
        final DateTime bTime = b.completedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color deadlineHeaderColor = _deadlineSectionHeaderColor(pendingDeadline);
    const Color normalHeaderColor = AppTheme.textPrimaryColor;
    final bool showEmptyState = !_isCompletedView &&
        pending.isEmpty &&
        todoGroups.isEmpty &&
        !_isCreatingTodoGroup;

    return Scaffold(
      appBar: AppBar(
        title: _buildTodoAppBarTitle(context: context, l10n: l10n),
        actions: <Widget>[
          AppBarTextAction(label: l10n.commonCreate, onPressed: _createTaskManually),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildTodoViewHeader(
                context: context,
                l10n: l10n,
                pendingCount: pending.length,
                completedCount: completed.length,
              ),
              Expanded(
                child: ValueListenableBuilder<_TodoDragVisualState>(
                  valueListenable: _todoDragVisualState,
                  builder: (
                    BuildContext context,
                    _TodoDragVisualState _,
                    Widget? __,
                  ) {
                    return CustomScrollView(
                      slivers: <Widget>[
                        if (_isCompletedView)
                          ..._buildCompletedTodoListSlivers(
                            context: context,
                            l10n: l10n,
                            reminderNotifier: reminderNotifier,
                            showTodoCreatedDate: showTodoCreatedDate,
                            completed: completed,
                          )
                        else ...<Widget>[
                          if (showEmptyState)
                            SliverToBoxAdapter(
                              child: AppEmptyState(
                                icon: Icons.checklist_outlined,
                                title: l10n.todoEmptyTitle,
                                subtitle: l10n.todoEmptySubtitle,
                              ),
                            ),
                          ..._buildTodoListSlivers(
                            context: context,
                            l10n: l10n,
                            reminderNotifier: reminderNotifier,
                            showTodoCreatedDate: showTodoCreatedDate,
                            pending: pending,
                            pendingDeadline: pendingDeadline,
                            pendingNormal: pendingNormal,
                            todoGroups: todoGroups,
                            deadlineHeaderColor: deadlineHeaderColor,
                            normalHeaderColor: normalHeaderColor,
                            showDeadlineTodos: sectionExpansion.showDeadlineTodos,
                            showNormalTodos: sectionExpansion.showNormalTodos,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
