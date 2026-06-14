part of 'todo_page.dart';

extension _TodoListSectionsExtension on _TodoPageState {
  List<Reminder> _pendingTodosForGroup(List<Reminder> pending, String groupId) {
    return pending
        .where((Reminder item) => item.todoGroupId == groupId)
        .toList();
  }

  bool _isDeadlineDueTodayOrOverdue(Reminder reminder) {
    if (!reminder.hasDeadline || reminder.isCompleted || reminder.deadlineAt == null) {
      return false;
    }
    return DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!) <= 0;
  }

  Color _deadlineSectionHeaderColor(List<Reminder> deadlineTodos) {
    if (deadlineTodos.isEmpty) {
      return AppTheme.secondaryLabelColor;
    }
    final bool hasUrgentDeadline =
        deadlineTodos.any(_isDeadlineDueTodayOrOverdue);
    return hasUrgentDeadline ? AppTheme.destructiveColor : AppTheme.primaryColor;
  }

  Color _todoGroupSectionHeaderColor(List<Reminder> groupTodos) {
    if (groupTodos.isEmpty) {
      return AppTheme.secondaryLabelColor;
    }
    final List<Reminder> deadlineTodos = groupTodos
        .where((Reminder item) => item.hasDeadline)
        .toList();
    if (deadlineTodos.isEmpty) {
      return AppTheme.textPrimaryColor;
    }
    return _deadlineSectionHeaderColor(deadlineTodos);
  }

  String? _calendarScheduleLabel(Reminder todo, ReminderNotifier notifier) {
    if (!todo.isSyncedToCalendar || todo.hasDeadline || todo.calendarLinkedId == null) {
      return null;
    }
    final Reminder? linked = notifier.getReminderById(todo.calendarLinkedId!);
    if (linked?.scheduledTime == null) {
      return null;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (linked!.isAllDay) {
      return '${DateTimeUtils.formatCardDate(linked.scheduledTime!)} ${l10n.reminderAllDay}';
    }
    return DateTimeUtils.formatCardDateTime(linked.scheduledTime!);
  }

  bool _groupHasDraftTodo(String groupId) {
    if (_draftTodoIds.isEmpty) {
      return false;
    }
    final ReminderNotifier notifier = ref.read(reminderListProvider.notifier);
    for (final String todoId in _draftTodoIds) {
      final Reminder? todo = notifier.getReminderById(todoId);
      if (todo?.todoGroupId == groupId) {
        return true;
      }
    }
    return false;
  }

  bool _normalHasDraftTodo() {
    if (_draftTodoIds.isEmpty) {
      return false;
    }
    final ReminderNotifier notifier = ref.read(reminderListProvider.notifier);
    for (final String todoId in _draftTodoIds) {
      final Reminder? todo = notifier.getReminderById(todoId);
      if (todo != null && !todo.hasDeadline && todo.todoGroupId == null) {
        return true;
      }
    }
    return false;
  }
  Widget _buildTodoConnectedList({
    required List<Reminder> todos,
    required ReminderNotifier reminderNotifier,
    required bool showCreatedDate,
    String keyPrefix = 'todo_connected',
    String? targetTodoGroupId,
    double bottomPadding = _TodoPageStateBase._todoGroupListBottomPadding,
    bool deleteOnly = false,
    bool reorderEnabled = true,
    bool dropEnabled = true,
  }) {
    final bool canDrag = reorderEnabled && !deleteOnly;
    final bool canDrop = dropEnabled && !deleteOnly;
    if (canDrop) {
      _todoDropListContexts[keyPrefix] = _TodoDropListContext(
        todos: todos,
        targetTodoGroupId: targetTodoGroupId,
      );
      _todoRowMeasureKeys[keyPrefix]
          ?.removeWhere((int index, GlobalKey _) => index >= todos.length);
    } else {
      _todoDropListContexts.remove(keyPrefix);
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AppGroupedSection(
        children: <Widget>[
          if (todos.isEmpty && canDrop)
            _buildTodoEmptyDropTarget(
              listKey: keyPrefix,
              todos: todos,
              targetTodoGroupId: targetTodoGroupId,
            ),
          for (int index = 0; index < todos.length; index++) ...<Widget>[
            if (index > 0)
              _buildTodoRowShiftWrapper(
                listKey: keyPrefix,
                rowIndex: index,
                child: _buildTodoListDivider(),
              ),
            _buildTodoRowShiftWrapper(
              listKey: keyPrefix,
              rowIndex: index,
              child: KeyedSubtree(
                key: _todoRowMeasureKey(keyPrefix, index),
                child: _buildReorderableTodoRow(
              reminder: todos[index],
              rowIndex: index,
              todos: todos,
              listKey: keyPrefix,
              targetTodoGroupId: targetTodoGroupId,
              reorderEnabled: canDrag,
              dropEnabled: canDrop,
              child: _buildTodoSlidable(
                reminder: todos[index],
                reminderNotifier: reminderNotifier,
                keyPrefix: keyPrefix,
                deleteOnly: deleteOnly,
                child: TodoCard(
                key: ValueKey<String>('todo_card_${todos[index].id}'),
                reminder: todos[index],
                showCreatedDate: showCreatedDate,
                grouped: true,
                inlineEditEnabled: !deleteOnly,
                editing: _editingTodoId == todos[index].id,
                requestFocus: _pendingFocusTodoId == todos[index].id,
                selectAllOnFocus: _pendingFocusSelectAll,
                isDraft: _draftTodoIds.contains(todos[index].id),
                calendarScheduleLabel:
                    _calendarScheduleLabel(todos[index], reminderNotifier),
                onFocusHandled: () => _handleTodoFocusHandled(todos[index].id),
                onEditStart: () =>
                    _startTodoTitleEdit(todos[index].id, selectAll: true),
                onEditEnd: () => _endTodoTitleEdit(todos[index].id),
                onTitleSave: (String title) async {
                  await _commitTodoTitle(todos[index], title);
                  _draftTodoIds.remove(todos[index].id);
                },
                onCreateBelow: () => _createTodoBelow(
                  afterReminder: todos[index],
                  listContext: todos,
                  index: index,
                ),
                onDiscardDraft: () => _discardDraftTodo(todos[index].id),
                onNavigateAdjacent: !deleteOnly
                    ? (int delta, String title) => _navigateAdjacentTodoEdit(
                          current: todos[index],
                          listContext: todos,
                          currentIndex: index,
                          delta: delta,
                          title: title,
                        )
                    : null,
                onCheckChanged: (bool? checked) =>
                    _onTodoCheckChanged(todos[index], checked),
                onSubItemsTap: todos[index].hasSubItems
                    ? () => _openSubItems(todos[index])
                    : null,
              ),
            ),
            ),
            ),
            ),
          ],
          if (bottomPadding > 0) SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  Widget _buildTodoEmptyDropTarget({
    required String listKey,
    required List<Reminder> todos,
    required String? targetTodoGroupId,
  }) {
    return ValueListenableBuilder<_TodoDragVisualState>(
      valueListenable: _todoDragVisualState,
      builder: (
        BuildContext context,
        _TodoDragVisualState dragState,
        Widget? _,
      ) {
        if (dragState.draggingTodoId == null) {
          return const SizedBox.shrink();
        }
        return KeyedSubtree(
          key: _todoEmptyDropMeasureKey(listKey),
          child: const SizedBox(
            height: 44,
            width: double.infinity,
          ),
        );
      },
    );
  }

  Widget _buildTodoSlidable({
    required Reminder reminder,
    required ReminderNotifier reminderNotifier,
    required Widget child,
    String keyPrefix = 'todo',
    bool deleteOnly = false,
  }) {
    return Slidable(
      key: ValueKey<String>('${keyPrefix}_${reminder.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: deleteOnly ? 0.14 : 0.48,
        children: deleteOnly
            ? <Widget>[
                AppSlidableActionButton(
                  onPressed: () => _deleteTodo(reminder),
                  icon: Icons.delete_outline,
                  iconColor: AppTheme.destructiveColor,
                  backgroundColor: AppTheme.destructiveColor.withValues(alpha: 0.16),
                ),
              ]
            : <Widget>[
                AppSlidableActionButton(
                  onPressed: () => _openSubItems(reminder),
                  icon: Icons.checklist_outlined,
                  iconColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
                ),
                AppSlidableActionButton(
                  onPressed: () => _onCalendarAction(reminder),
                  icon: reminder.isSyncedToCalendar
                      ? Icons.event_busy_outlined
                      : Icons.calendar_today_outlined,
                  iconColor: AppTheme.iosBlue,
                  backgroundColor: AppTheme.iosBlue.withValues(alpha: 0.16),
                ),
                AppSlidableActionButton(
                  onPressed: () => _editTodo(reminder),
                  icon: Icons.edit_outlined,
                  iconColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
                ),
                AppSlidableActionButton(
                  onPressed: () => _deleteTodo(reminder),
                  icon: Icons.delete_outline,
                  iconColor: AppTheme.destructiveColor,
                  backgroundColor: AppTheme.destructiveColor.withValues(alpha: 0.16),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _buildTodoAppBarTitle({
    required BuildContext context,
    required AppLocalizations l10n,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        _buildTodoViewTab(
          context: context,
          label: l10n.todoSectionTitle,
          selected: !_isCompletedView,
          onTap: () {
            if (_isCompletedView) {
              setState(() => _isCompletedView = false);
            }
          },
        ),
        const SizedBox(width: 16),
        _buildTodoViewTab(
          context: context,
          label: l10n.todoCompletedSection,
          selected: _isCompletedView,
          onTap: () {
            if (!_isCompletedView) {
              setState(() => _isCompletedView = true);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTodoViewTab({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final TextStyle selectedStyle = Theme.of(context).textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.w700,
        );
    final TextStyle unselectedStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
          color: AppTheme.secondaryLabelColor,
          fontWeight: FontWeight.w500,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
          child: selected
              ? AppChalkUnderlineLabel(
                  label: label,
                  style: selectedStyle,
                  underlineColor: AppTheme.primaryColor,
                )
              : Text(label, style: unselectedStyle),
        ),
      ),
    );
  }

  Widget _buildTodoViewHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required int pendingCount,
    required int completedCount,
  }) {
    final TextStyle? countStyle = Theme.of(context).textTheme.bodySmall;
    final TextStyle? sectionLabelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.secondaryLabelColor,
          fontWeight: FontWeight.w600,
        );
    final TextStyle? clearStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                _isCompletedView ? l10n.todoAllCompleted : l10n.todoAllPending,
                style: sectionLabelStyle,
              ),
              const Spacer(),
              if (!_isCompletedView && pendingCount > 0)
                Text('$pendingCount', style: countStyle),
              if (_isCompletedView && completedCount > 0)
                Text('$completedCount', style: countStyle),
            ],
          ),
          if (_isCompletedView && completedCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _onClearCompletedPressed,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  foregroundColor: AppTheme.primaryColor,
                  textStyle: clearStyle,
                ),
                child: Text(l10n.todoClearCompleted),
              ),
            ),
          if (!_isCompletedView && !_isCreatingTodoGroup)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _startCreateTodoGroup,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  foregroundColor: AppTheme.primaryColor,
                  textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                child: Text(l10n.todoAddGroup),
              ),
            ),
          if (!_isCompletedView && _isCreatingTodoGroup)
            _buildNewTodoGroupEditor(l10n),
        ],
      ),
    );
  }

  List<Widget> _buildCompletedTodoListSlivers({
    required BuildContext context,
    required AppLocalizations l10n,
    required ReminderNotifier reminderNotifier,
    required bool showTodoCreatedDate,
    required List<Reminder> completed,
  }) {
    if (completed.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: AppEmptyState(
            icon: Icons.task_alt_outlined,
            title: l10n.todoCompletedEmptyTitle,
          ),
        ),
      ];
    }

    final Map<CompletedTodoSection, List<Reminder>> grouped =
        CompletedTodoSectionUtils.groupCompleted(completed);
    final List<Widget> slivers = <Widget>[];
    var isFirstSection = true;

    for (final CompletedTodoSection section
        in CompletedTodoSectionUtils.displayOrder) {
      final List<Reminder>? sectionTodos = grouped[section];
      if (sectionTodos == null || sectionTodos.isEmpty) {
        continue;
      }

      slivers.add(
        SliverToBoxAdapter(
          child: _buildCompletedSectionHeader(
            context: context,
            title: CompletedTodoSectionUtils.sectionTitle(section, l10n),
            count: sectionTodos.length,
            isFirst: isFirstSection,
          ),
        ),
      );
      isFirstSection = false;

      slivers.add(
        SliverToBoxAdapter(
          child: _buildTodoConnectedList(
            todos: sectionTodos,
            reminderNotifier: reminderNotifier,
            showCreatedDate: showTodoCreatedDate,
            keyPrefix:
                'todo_completed_${CompletedTodoSectionUtils.sectionKey(section)}',
            deleteOnly: true,
          ),
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 20)));
    return slivers;
  }

  Widget _buildCompletedSectionHeader({
    required BuildContext context,
    required String title,
    required int count,
    required bool isFirst,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, isFirst ? 4 : 16, 4, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.secondaryLabelColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.secondaryLabelColor,
                ),
          ),
        ],
      ),
    );
  }

  double _expandedSectionHeaderExtent(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return 40 * textScale + 14;
  }

  double _collapsedSectionHeaderExtent(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
    return 46 * textScale + 12;
  }

  double _todoGroupSectionGap({
    required bool isExpanded,
    required bool hasListItems,
  }) {
    return isExpanded && hasListItems
        ? _TodoPageStateBase._todoGroupExpandedSectionGap
        : _TodoPageStateBase._todoGroupCollapsedSectionGap;
  }

  List<Widget> _buildTodoListSlivers({
    required BuildContext context,
    required AppLocalizations l10n,
    required ReminderNotifier reminderNotifier,
    required bool showTodoCreatedDate,
    required List<Reminder> pending,
    required List<Reminder> pendingDeadline,
    required List<Reminder> pendingNormal,
    required List<TodoGroup> todoGroups,
    required Color deadlineHeaderColor,
    required Color normalHeaderColor,
    required bool showDeadlineTodos,
    required bool showNormalTodos,
  }) {
    final List<String> sectionOrder = ref
        .read(todoSectionOrderProvider.notifier)
        .normalizedOrder(todoGroups);
    _sectionDragOrderContext = _SectionDragOrderContext(
      orderedSectionIds: sectionOrder,
      todoGroups: todoGroups,
    );
    _sectionHeaderMeasureKeys
        .removeWhere((int index, GlobalKey _) => index >= sectionOrder.length);
    _sectionFooterMeasureKeys
        .removeWhere((int index, GlobalKey _) => index >= sectionOrder.length);
    final List<Widget> slivers = <Widget>[];

    for (int sectionIndex = 0; sectionIndex < sectionOrder.length; sectionIndex++) {
      final String sectionId = sectionOrder[sectionIndex];

      if (sectionId == kTodoDeadlineSectionId) {
        slivers.add(
          SliverMainAxisGroup(
            slivers: <Widget>[
              _pinnedSectionHeader(
                extent: showDeadlineTodos
                    ? _expandedSectionHeaderExtent(context)
                    : _collapsedSectionHeaderExtent(context),
                child: _buildReorderableSectionHeader(
                  sectionId: sectionId,
                  sectionIndex: sectionIndex,
                  orderedSectionIds: sectionOrder,
                  todoGroups: todoGroups,
                  child: _buildDeadlineSectionHeader(
                    context: context,
                    l10n: l10n,
                    deadlineHeaderColor: deadlineHeaderColor,
                    count: pendingDeadline.length,
                    showSection: showDeadlineTodos,
                  ),
                ),
              ),
              if (showDeadlineTodos && pendingDeadline.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildTodoConnectedList(
                    todos: pendingDeadline,
                    reminderNotifier: reminderNotifier,
                    showCreatedDate: showTodoCreatedDate,
                    keyPrefix: _todoDeadlineListKey,
                    reorderEnabled: false,
                    dropEnabled: false,
                  ),
                ),
              SliverToBoxAdapter(
                child: _buildSectionFooterGap(
                  sectionIndex: sectionIndex,
                  height: _todoGroupSectionGap(
                    isExpanded: showDeadlineTodos,
                    hasListItems: pendingDeadline.isNotEmpty,
                  ),
                ),
              ),
            ],
          ),
        );
        continue;
      }

      if (sectionId == kTodoNormalSectionId) {
        slivers.add(
          SliverMainAxisGroup(
            slivers: <Widget>[
              _pinnedSectionHeader(
                extent: showNormalTodos
                    ? _expandedSectionHeaderExtent(context)
                    : _collapsedSectionHeaderExtent(context),
                child: _buildReorderableSectionHeader(
                  sectionId: sectionId,
                  sectionIndex: sectionIndex,
                  orderedSectionIds: sectionOrder,
                  todoGroups: todoGroups,
                  child: _buildNormalSectionHeader(
                    context: context,
                    l10n: l10n,
                    normalHeaderColor: normalHeaderColor,
                    pendingNormal: pendingNormal,
                    count: pendingNormal.length,
                    showSection: showNormalTodos,
                  ),
                ),
              ),
              if (showNormalTodos &&
                  (pendingNormal.isNotEmpty ||
                      _normalHasDraftTodo() ||
                      (_isTodoCrossDragActive && pendingNormal.isEmpty)))
                SliverToBoxAdapter(
                  child: _buildTodoConnectedList(
                    todos: pendingNormal,
                    reminderNotifier: reminderNotifier,
                    showCreatedDate: showTodoCreatedDate,
                    keyPrefix: _todoNormalListKey,
                    targetTodoGroupId: null,
                  ),
                ),
              SliverToBoxAdapter(
                child: _buildSectionFooterGap(
                  sectionIndex: sectionIndex,
                  height: _todoGroupSectionGap(
                    isExpanded: showNormalTodos,
                    hasListItems:
                        pendingNormal.isNotEmpty || _normalHasDraftTodo(),
                  ),
                ),
              ),
            ],
          ),
        );
        continue;
      }

      final TodoGroup? group = _todoGroupForSectionId(sectionId, todoGroups);
      if (group == null) {
        continue;
      }

      final List<Reminder> groupTodos = _pendingTodosForGroup(pending, group.id);
      final bool isExpanded = _isTodoGroupExpanded(group.id);
      final Color groupHeaderColor = _todoGroupSectionHeaderColor(groupTodos);
      final bool showGroupList = isExpanded &&
          (groupTodos.isNotEmpty ||
              _groupHasDraftTodo(group.id) ||
              (_isTodoCrossDragActive && groupTodos.isEmpty));

      slivers.add(
        SliverMainAxisGroup(
          slivers: <Widget>[
            _pinnedSectionHeader(
              extent: isExpanded
                  ? _expandedSectionHeaderExtent(context)
                  : _collapsedSectionHeaderExtent(context),
              child: _buildReorderableSectionHeader(
                sectionId: sectionId,
                sectionIndex: sectionIndex,
                orderedSectionIds: sectionOrder,
                todoGroups: todoGroups,
                child: _buildTodoGroupSectionHeader(
                  context: context,
                  group: group,
                  groupTodos: groupTodos,
                  count: groupTodos.length,
                  headerColor: groupHeaderColor,
                  isExpanded: isExpanded,
                ),
              ),
            ),
            if (showGroupList)
              SliverToBoxAdapter(
                child: _buildTodoConnectedList(
                  todos: groupTodos,
                  reminderNotifier: reminderNotifier,
                  showCreatedDate: showTodoCreatedDate,
                  keyPrefix: _todoGroupListKey(group.id),
                  targetTodoGroupId: group.id,
                ),
              ),
            SliverToBoxAdapter(
              child: _buildSectionFooterGap(
                sectionIndex: sectionIndex,
                height: _todoGroupSectionGap(
                  isExpanded: isExpanded,
                  hasListItems: showGroupList,
                ),
              ),
            ),
          ],
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 20)));
    return slivers;
  }

  Widget _buildSectionFooterGap({
    required int sectionIndex,
    required double height,
  }) {
    return KeyedSubtree(
      key: _sectionFooterMeasureKey(sectionIndex),
      child: SizedBox(height: height),
    );
  }

  Widget _pinnedSectionHeader({
    required double extent,
    required Widget child,
  }) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TodoPinnedSectionHeaderDelegate(
        extent: extent,
        child: child,
      ),
    );
  }

  Widget _buildNewTodoGroupEditor(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AppGroupedSection(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _newTodoGroupNameController,
                      focusNode: _newTodoGroupFocusNode,
                      style: Theme.of(context).textTheme.titleSmall,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l10n.todoGroupNameHint,
                        hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.secondaryLabelColor,
                            ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _commitNewTodoGroup(),
                    ),
                  ),
                  IconButton(
                    onPressed: _cancelCreateTodoGroup,
                    icon: const Icon(Icons.close, size: 18),
                    color: AppTheme.secondaryLabelColor,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: l10n.commonCancel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoGroupSectionHeader({
    required BuildContext context,
    required TodoGroup group,
    required List<Reminder> groupTodos,
    required int count,
    required Color headerColor,
    required bool isExpanded,
  }) {
    if (isExpanded) {
      return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _toggleTodoGroupExpanded(group.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: headerColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            group.name,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: headerColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: headerColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSectionAddTodoButton(
                onPressed: () => _createTaskInGroup(group, groupTodos),
              ),
            ],
          ),
        ),
      );
    }

    return Slidable(
      key: ValueKey<String>('todo_group_${group.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: <Widget>[
          AppSlidableActionButton(
            onPressed: () => _renameTodoGroup(group),
            icon: Icons.edit_outlined,
            iconColor: AppTheme.primaryColor,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.18),
          ),
          AppSlidableActionButton(
            onPressed: () => _deleteTodoGroup(group),
            icon: Icons.delete_outline,
            iconColor: AppTheme.destructiveColor,
            backgroundColor: AppTheme.destructiveColor.withValues(alpha: 0.16),
          ),
        ],
      ),
      child: AppGroupedSection(
        backgroundColor: Colors.transparent,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleTodoGroupExpanded(group.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.keyboard_arrow_right,
                      size: 22,
                      color: headerColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: headerColor,
                            ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: headerColor,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineSectionHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required Color deadlineHeaderColor,
    required int count,
    required bool showSection,
  }) {
    if (showSection) {
      return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    ref
                        .read(todoSectionExpansionProvider.notifier)
                        .toggleShowDeadlineTodos();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: deadlineHeaderColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.todoDeadlineSection,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: deadlineHeaderColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: deadlineHeaderColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSectionAddTodoButton(
                onPressed: _createDeadlineTask,
              ),
            ],
          ),
        ),
      );
    }

    return AppGroupedSection(
      backgroundColor: Colors.transparent,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ref
                  .read(todoSectionExpansionProvider.notifier)
                  .toggleShowDeadlineTodos();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.keyboard_arrow_right,
                    size: 22,
                    color: deadlineHeaderColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.todoDeadlineSection,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: deadlineHeaderColor,
                          ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: deadlineHeaderColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalSectionHeader({
    required BuildContext context,
    required AppLocalizations l10n,
    required Color normalHeaderColor,
    required List<Reminder> pendingNormal,
    required int count,
    required bool showSection,
  }) {
    if (showSection) {
      return Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    ref
                        .read(todoSectionExpansionProvider.notifier)
                        .toggleShowNormalTodos();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: normalHeaderColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.todoNormalSection,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: normalHeaderColor,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Text(
                          '$count',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: normalHeaderColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSectionAddTodoButton(
                onPressed: () => _createNormalTask(pendingNormal),
              ),
            ],
          ),
        ),
      );
    }

    return AppGroupedSection(
      backgroundColor: Colors.transparent,
      children: <Widget>[
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ref
                  .read(todoSectionExpansionProvider.notifier)
                  .toggleShowNormalTodos();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.keyboard_arrow_right,
                    size: 22,
                    color: normalHeaderColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.todoNormalSection,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: normalHeaderColor,
                          ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: normalHeaderColor,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

}

class _TodoPinnedSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TodoPinnedSectionHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: AppTheme.groupedBackgroundColor,
      child: SizedBox(
        height: extent,
        width: double.infinity,
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TodoPinnedSectionHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}
