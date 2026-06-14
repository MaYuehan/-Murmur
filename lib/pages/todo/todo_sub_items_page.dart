import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/models/todo_sub_item.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/widgets/app_slidable_action_button.dart';
import 'package:murmur/widgets/app_ui.dart';

class TodoSubItemsPage extends ConsumerStatefulWidget {
  const TodoSubItemsPage({
    super.key,
    required this.todoId,
  });

  final String todoId;

  @override
  ConsumerState<TodoSubItemsPage> createState() => _TodoSubItemsPageState();
}

class _TodoSubItemsPageState extends ConsumerState<TodoSubItemsPage> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};
  String? _editingSubItemId;
  String? _pendingFocusSubItemId;

  List<TodoSubItem> _sortedSubItems(List<TodoSubItem> items) {
    final List<TodoSubItem> pending = <TodoSubItem>[];
    final List<TodoSubItem> done = <TodoSubItem>[];
    for (final TodoSubItem item in items) {
      if (item.isCompleted) {
        done.add(item);
      } else {
        pending.add(item);
      }
    }
    return <TodoSubItem>[...pending, ...done];
  }

  Reminder? _parentTodo() {
    return ref.read(reminderListProvider.notifier).getReminderById(widget.todoId);
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectionMode() {
    if (_selectionMode) {
      _exitSelectionMode();
      return;
    }
    setState(() => _selectionMode = true);
  }

  void _toggleSelected(String subItemId) {
    setState(() {
      if (_selectedIds.contains(subItemId)) {
        _selectedIds.remove(subItemId);
      } else {
        _selectedIds.add(subItemId);
      }
    });
  }

  Future<void> _addSubItem() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ReminderNotifier notifier = ref.read(reminderListProvider.notifier);
    final Reminder? parent = _parentTodo();
    if (parent == null) {
      return;
    }
    await notifier.addTodoSubItem(
      parentId: widget.todoId,
      title: l10n.todoSubItemNewDefault,
    );
    if (!mounted) {
      return;
    }
    final Reminder? updated = notifier.getReminderById(widget.todoId);
    if (updated == null || updated.subItems.isEmpty) {
      return;
    }
    final TodoSubItem newest = updated.subItems.last;
    setState(() {
      _pendingFocusSubItemId = newest.id;
      _editingSubItemId = newest.id;
    });
  }

  Future<void> _deleteSubItem(TodoSubItem item) async {
    await ref.read(reminderListProvider.notifier).deleteTodoSubItem(
          parentId: widget.todoId,
          subItemId: item.id,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIds.remove(item.id);
      if (_editingSubItemId == item.id) {
        _editingSubItemId = null;
      }
    });
  }

  Future<bool?> _confirmDeleteSelected() {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.todoSubItemsDeleteSelectedTitle),
          content: Text(l10n.todoSubItemsDeleteSelectedBody(_selectedIds.length)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                l10n.commonDelete,
                style: const TextStyle(color: AppTheme.destructiveColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) {
      return;
    }
    final bool? confirmed = await _confirmDeleteSelected();
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(reminderListProvider.notifier).deleteTodoSubItems(
          parentId: widget.todoId,
          subItemIds: _selectedIds.toList(),
        );
    if (!mounted) {
      return;
    }
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderListProvider);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Reminder? parent = _parentTodo();

    if (parent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return Scaffold(
        appBar: AppBar(title: Text(l10n.todoSubItemsPageTitle)),
        body: const SizedBox.shrink(),
      );
    }

    final List<TodoSubItem> subItems = _sortedSubItems(parent.subItems);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${l10n.todoSubItemsSelect} (${_selectedIds.length})'
              : parent.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          if (_selectionMode) ...<Widget>[
            AppBarTextAction(
              label: l10n.todoSubItemsCancelSelect,
              onPressed: _exitSelectionMode,
            ),
            AppBarTextAction(
              label: l10n.todoSubItemsDeleteSelected,
              onPressed: _selectedIds.isEmpty ? () {} : _deleteSelected,
            ),
          ] else ...<Widget>[
            if (subItems.isNotEmpty)
              AppBarTextAction(
                label: l10n.todoSubItemsSelect,
                onPressed: _toggleSelectionMode,
              ),
            IconButton(
              tooltip: l10n.todoAdd,
              onPressed: _addSubItem,
              icon: const Icon(Icons.add),
            ),
          ],
        ],
      ),
      body: subItems.isEmpty
          ? AppEmptyState(
              icon: Icons.checklist_outlined,
              title: l10n.todoSubItemsEmptyTitle,
              subtitle: l10n.todoSubItemsEmptySubtitle,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                Container(
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
                      for (int index = 0; index < subItems.length; index++) ...<Widget>[
                        _SubItemRow(
                          key: ValueKey<String>(subItems[index].id),
                          item: subItems[index],
                          parentId: widget.todoId,
                          grouped: true,
                          selectionMode: _selectionMode,
                          selected: _selectedIds.contains(subItems[index].id),
                          editing: _editingSubItemId == subItems[index].id,
                          requestFocus: _pendingFocusSubItemId == subItems[index].id,
                          onFocusHandled: () {
                            if (_pendingFocusSubItemId == subItems[index].id) {
                              setState(() => _pendingFocusSubItemId = null);
                            }
                          },
                          onSelectionToggle: () => _toggleSelected(subItems[index].id),
                          onEditStart: () =>
                              setState(() => _editingSubItemId = subItems[index].id),
                          onEditEnd: () {
                            if (_editingSubItemId == subItems[index].id) {
                              setState(() => _editingSubItemId = null);
                            }
                          },
                          onDelete: () => _deleteSubItem(subItems[index]),
                        ),
                        if (index < subItems.length - 1)
                          const Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 16,
                            color: AppTheme.separatorColor,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SubItemRow extends ConsumerStatefulWidget {
  const _SubItemRow({
    super.key,
    required this.item,
    required this.parentId,
    this.grouped = false,
    required this.selectionMode,
    required this.selected,
    required this.editing,
    required this.requestFocus,
    required this.onFocusHandled,
    required this.onSelectionToggle,
    required this.onEditStart,
    required this.onEditEnd,
    required this.onDelete,
  });

  final TodoSubItem item;
  final String parentId;
  final bool grouped;
  final bool selectionMode;
  final bool selected;
  final bool editing;
  final bool requestFocus;
  final VoidCallback onFocusHandled;
  final VoidCallback onSelectionToggle;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;
  final VoidCallback onDelete;

  @override
  ConsumerState<_SubItemRow> createState() => _SubItemRowState();
}

class _SubItemRowState extends ConsumerState<_SubItemRow> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_onTitleFocusChange);
    if (widget.requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus(selectAll: true));
    }
  }

  @override
  void didUpdateWidget(covariant _SubItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing && oldWidget.item.title != widget.item.title) {
      _titleController.text = widget.item.title;
    }
    if (widget.requestFocus && !oldWidget.requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus(selectAll: true));
    }
    if (!widget.editing && oldWidget.editing) {
      _titleController.text = widget.item.title;
    }
    if (widget.editing && !oldWidget.editing) {
      _titleController.text = widget.item.title;
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus(selectAll: false));
    }
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _titleFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _requestEditFocus({required bool selectAll}) {
    if (!mounted) {
      return;
    }
    widget.onFocusHandled();
    _titleFocusNode.requestFocus();
    if (selectAll) {
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
    }
  }

  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus && widget.editing) {
      _commitTitleEdit();
    }
  }

  void _startTitleEdit() {
    if (widget.selectionMode) {
      widget.onSelectionToggle();
      return;
    }
    widget.onEditStart();
  }

  Future<void> _commitTitleEdit() async {
    if (!widget.editing) {
      return;
    }
    final String value = _titleController.text.trim();
    if (value.isEmpty) {
      _titleController.text = widget.item.title;
      widget.onEditEnd();
      _titleFocusNode.unfocus();
      return;
    }
    if (value != widget.item.title) {
      await ref.read(reminderListProvider.notifier).updateTodoSubItemTitle(
            parentId: widget.parentId,
            subItemId: widget.item.id,
            title: value,
          );
    }
    widget.onEditEnd();
    _titleFocusNode.unfocus();
  }

  TextStyle? _titleTextStyle(BuildContext context) {
    final Color textColor = widget.item.isCompleted
        ? AppTheme.secondaryLabelColor
        : AppTheme.textPrimaryColor;
    return Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: textColor,
          decoration:
              widget.item.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
          height: 1.3,
        );
  }

  Widget _buildCompleteCheckbox(TodoSubItem item) {
    return Theme(
      data: Theme.of(context).copyWith(
        checkboxTheme: CheckboxThemeData(
          shape: const CircleBorder(),
          side: const BorderSide(color: Color(0xFFD1D1D6), width: 1.5),
          fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return AppTheme.primaryColor;
            }
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Colors.white),
        ),
      ),
      child: Checkbox(
        value: item.isCompleted,
        onChanged: (bool? checked) {
          ref.read(reminderListProvider.notifier).toggleTodoSubItemCompleted(
                parentId: widget.parentId,
                subItemId: item.id,
                isCompleted: checked ?? false,
              );
        },
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TodoSubItem item = widget.item;
    final TextStyle? titleStyle = _titleTextStyle(context);

    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (widget.selectionMode)
            Checkbox(
              value: widget.selected,
              onChanged: (_) => widget.onSelectionToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )
          else
            _buildCompleteCheckbox(item),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: widget.editing
                  ? TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      style: titleStyle,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _commitTitleEdit(),
                    )
                  : GestureDetector(
                      onTap: _startTitleEdit,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        item.title,
                        style: titleStyle,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );

    final Widget row = widget.grouped
        ? content
        : Container(
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
              children: <Widget>[content],
            ),
          );

    if (widget.selectionMode) {
      return row;
    }

    return Slidable(
      key: ValueKey<String>('subitem_${item.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.14,
        children: <Widget>[
          AppSlidableActionButton(
            onPressed: widget.onDelete,
            icon: Icons.delete_outline,
            iconColor: AppTheme.destructiveColor,
            backgroundColor: AppTheme.destructiveColor.withValues(alpha: 0.16),
          ),
        ],
      ),
      child: row,
    );
  }
}
