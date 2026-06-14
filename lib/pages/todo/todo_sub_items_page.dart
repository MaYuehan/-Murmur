import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/list_sort_order.dart';
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
  bool _pendingFocusSelectAll = true;
  final Set<String> _draftSubItemIds = <String>{};

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
    pending.sort((TodoSubItem a, TodoSubItem b) => a.sortOrder.compareTo(b.sortOrder));
    done.sort((TodoSubItem a, TodoSubItem b) => a.sortOrder.compareTo(b.sortOrder));
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

  void _startSubItemEdit(String subItemId, {required bool selectAll}) {
    setState(() {
      _editingSubItemId = subItemId;
      _pendingFocusSubItemId = subItemId;
      _pendingFocusSelectAll = selectAll;
    });
  }

  void _endSubItemEdit(String subItemId) {
    setState(() {
      if (_editingSubItemId == subItemId) {
        _editingSubItemId = null;
      }
      if (_pendingFocusSubItemId == subItemId) {
        _pendingFocusSubItemId = null;
      }
    });
  }

  void _handleSubItemFocusHandled(String subItemId) {
    if (_pendingFocusSubItemId != subItemId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingFocusSubItemId != subItemId) {
        return;
      }
      setState(() => _pendingFocusSubItemId = null);
    });
  }

  Future<void> _discardDraftSubItem(String subItemId) async {
    _draftSubItemIds.remove(subItemId);
    await ref.read(reminderListProvider.notifier).deleteTodoSubItem(
          parentId: widget.todoId,
          subItemId: subItemId,
        );
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_editingSubItemId == subItemId) {
          _editingSubItemId = null;
        }
        if (_pendingFocusSubItemId == subItemId) {
          _pendingFocusSubItemId = null;
        }
      });
    });
  }

  Future<void> _saveSubItemTitle(TodoSubItem item, String title) async {
    await ref.read(reminderListProvider.notifier).updateTodoSubItemTitle(
          parentId: widget.todoId,
          subItemId: item.id,
          title: title,
        );
    _draftSubItemIds.remove(item.id);
  }

  Future<void> _createSubItemBelow({
    required List<TodoSubItem> listContext,
    required int index,
  }) async {
    setState(() {
      _editingSubItemId = null;
      _pendingFocusSubItemId = null;
    });

    final String newSubItemId =
        await ref.read(reminderListProvider.notifier).insertTodoSubItemAfter(
              parentId: widget.todoId,
              afterIndex: index,
              listContext: listContext,
            );
    if (!mounted || newSubItemId.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _draftSubItemIds.add(newSubItemId);
        _editingSubItemId = newSubItemId;
        _pendingFocusSubItemId = newSubItemId;
        _pendingFocusSelectAll = false;
      });
    });
  }

  Future<void> _addSubItemInline({List<TodoSubItem>? listContext}) async {
    if (listContext == null || listContext.isEmpty) {
      final String newSubItemId =
          await ref.read(reminderListProvider.notifier).addTodoSubItem(
                parentId: widget.todoId,
                title: '',
                sortOrder: ListSortOrder.defaultNow(),
              );
      if (!mounted || newSubItemId.isEmpty) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _draftSubItemIds.add(newSubItemId);
          _editingSubItemId = newSubItemId;
          _pendingFocusSubItemId = newSubItemId;
          _pendingFocusSelectAll = false;
        });
      });
      return;
    }
    await _createSubItemBelow(
      listContext: listContext,
      index: listContext.length - 1,
    );
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
      _draftSubItemIds.remove(item.id);
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

  Widget _buildSubItemList({
    required AppLocalizations l10n,
    required List<TodoSubItem> subItems,
  }) {
    return ListView(
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
                  selectAllOnFocus: _pendingFocusSelectAll,
                  isDraft: _draftSubItemIds.contains(subItems[index].id),
                  onFocusHandled: () => _handleSubItemFocusHandled(subItems[index].id),
                  onSelectionToggle: () => _toggleSelected(subItems[index].id),
                  onEditStart: () =>
                      _startSubItemEdit(subItems[index].id, selectAll: true),
                  onEditEnd: () => _endSubItemEdit(subItems[index].id),
                  onTitleSave: (String title) =>
                      _saveSubItemTitle(subItems[index], title),
                  onCreateBelow: () => _createSubItemBelow(
                    listContext: subItems,
                    index: index,
                  ),
                  onDiscardDraft: () => _discardDraftSubItem(subItems[index].id),
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
    );
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
    final bool showList = subItems.isNotEmpty || _draftSubItemIds.isNotEmpty;

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
              onPressed: () => _addSubItemInline(listContext: subItems),
              icon: const Icon(Icons.add),
            ),
          ],
        ],
      ),
      body: !showList
          ? GestureDetector(
              onTap: () => _addSubItemInline(),
              behavior: HitTestBehavior.opaque,
              child: AppEmptyState(
                icon: Icons.checklist_outlined,
                title: l10n.todoSubItemsEmptyTitle,
                subtitle: l10n.todoSubItemsEmptySubtitle,
              ),
            )
          : _buildSubItemList(l10n: l10n, subItems: subItems),
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
    required this.selectAllOnFocus,
    required this.isDraft,
    required this.onFocusHandled,
    required this.onSelectionToggle,
    required this.onEditStart,
    required this.onEditEnd,
    required this.onTitleSave,
    required this.onCreateBelow,
    required this.onDiscardDraft,
    required this.onDelete,
  });

  final TodoSubItem item;
  final String parentId;
  final bool grouped;
  final bool selectionMode;
  final bool selected;
  final bool editing;
  final bool requestFocus;
  final bool selectAllOnFocus;
  final bool isDraft;
  final VoidCallback onFocusHandled;
  final VoidCallback onSelectionToggle;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;
  final Future<void> Function(String title) onTitleSave;
  final VoidCallback onCreateBelow;
  final VoidCallback onDiscardDraft;
  final VoidCallback onDelete;

  @override
  ConsumerState<_SubItemRow> createState() => _SubItemRowState();
}

class _SubItemRowState extends ConsumerState<_SubItemRow> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  String _lastSavedTitle = '';
  bool _suppressFocusExit = false;
  bool _isExitingEdit = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _titleController.addListener(_onTitleTextChanged);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_onTitleFocusChange);
    _lastSavedTitle = widget.item.title;
    if (widget.requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    }
  }

  @override
  void didUpdateWidget(covariant _SubItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing && !oldWidget.editing) {
      _lastSavedTitle = widget.item.title;
      _titleController.text = widget.item.title;
      _suppressFocusExit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    } else if (!widget.editing && oldWidget.editing) {
      _suppressFocusExit = false;
      _titleController.text = widget.item.title;
      _lastSavedTitle = widget.item.title;
    } else if (!widget.editing && oldWidget.item.title != widget.item.title) {
      _titleController.text = widget.item.title;
      _lastSavedTitle = widget.item.title;
    } else if (widget.editing &&
        widget.requestFocus &&
        !oldWidget.requestFocus &&
        oldWidget.editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    }
  }

  @override
  void dispose() {
    _suppressFocusExit = true;
    _titleController.removeListener(_onTitleTextChanged);
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _titleFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _onTitleTextChanged() {
    if (!widget.editing) {
      return;
    }
    setState(() {});
  }

  bool get _hasUnsavedTitleEdit =>
      widget.editing && _titleController.text.trim() != _lastSavedTitle.trim();

  void _requestEditFocus() {
    if (!mounted || !widget.editing) {
      return;
    }
    _titleFocusNode.requestFocus();
    if (widget.selectAllOnFocus) {
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
    } else {
      _titleController.selection = TextSelection.collapsed(
        offset: _titleController.text.length,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onFocusHandled();
    });
  }

  void _onTitleFocusChange() {
    if (_suppressFocusExit || !_titleFocusNode.hasFocus || !widget.editing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _suppressFocusExit ||
          _titleFocusNode.hasFocus ||
          !widget.editing) {
        return;
      }
      unawaited(_exitTitleEdit());
    });
  }

  void _startTitleEdit() {
    if (widget.selectionMode) {
      widget.onSelectionToggle();
      return;
    }
    if (widget.editing) {
      return;
    }
    widget.onEditStart();
  }

  Future<void> _onTitleSubmitted(String _) async {
    if (!widget.editing || _isExitingEdit) {
      return;
    }
    final String value = _titleController.text.trim();
    if (value.isEmpty) {
      if (widget.isDraft) {
        _suppressFocusExit = true;
        widget.onDiscardDraft();
      }
      return;
    }
    if (value != _lastSavedTitle) {
      _suppressFocusExit = true;
      await widget.onTitleSave(value);
      if (!mounted || !widget.editing) {
        _suppressFocusExit = false;
        return;
      }
      _lastSavedTitle = value;
      _suppressFocusExit = false;
      if (mounted) {
        setState(() {});
      }
      _titleFocusNode.requestFocus();
      return;
    }
    _suppressFocusExit = true;
    widget.onCreateBelow();
  }

  Future<void> _exitTitleEdit() async {
    if (!widget.editing || _isExitingEdit) {
      return;
    }
    _isExitingEdit = true;
    try {
      final String value = _titleController.text.trim();
      if (value.isEmpty) {
        if (widget.isDraft) {
          widget.onDiscardDraft();
        } else {
          _titleController.text = widget.item.title;
          widget.onEditEnd();
        }
        return;
      }
      if (value != _lastSavedTitle) {
        await widget.onTitleSave(value);
        if (!mounted) {
          return;
        }
        _lastSavedTitle = value;
      }
      widget.onEditEnd();
    } finally {
      _isExitingEdit = false;
      _suppressFocusExit = false;
    }
  }

  TextStyle? _titleTextStyle(
    BuildContext context, {
    bool showEditUnderline = false,
  }) {
    final Color textColor = widget.item.isCompleted
        ? AppTheme.secondaryLabelColor
        : AppTheme.textPrimaryColor;
    return Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: textColor,
          decoration: showEditUnderline
              ? TextDecoration.underline
              : (widget.item.isCompleted
                  ? TextDecoration.lineThrough
                  : TextDecoration.none),
          decorationColor:
              showEditUnderline ? AppTheme.primaryColor : textColor,
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
    final TextStyle? editingTitleStyle = _titleTextStyle(
      context,
      showEditUnderline: _hasUnsavedTitleEdit,
    );

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
                      style: editingTitleStyle,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      onSubmitted: _onTitleSubmitted,
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
