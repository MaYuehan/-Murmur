import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:murmur/core/theme/app_theme.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/core/utils/reminder_time_rules.dart';
import 'package:murmur/l10n/app_localizations.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/widgets/app_ui.dart';

class TodoCard extends StatefulWidget {
  const TodoCard({
    super.key,
    required this.reminder,
    required this.showCreatedDate,
    this.grouped = false,
    this.inlineEditEnabled = true,
    this.editing = false,
    this.requestFocus = false,
    this.selectAllOnFocus = true,
    this.isDraft = false,
    this.calendarScheduleLabel,
    this.onFocusHandled,
    this.onEditStart,
    this.onEditEnd,
    this.onTitleSave,
    this.onCreateBelow,
    this.onDiscardDraft,
    this.onNavigateAdjacent,
    this.onCheckChanged,
    this.onSubItemsTap,
  });

  final Reminder reminder;
  final bool showCreatedDate;
  final bool grouped;
  final bool inlineEditEnabled;
  final bool editing;
  final bool requestFocus;
  final bool selectAllOnFocus;
  final bool isDraft;
  final String? calendarScheduleLabel;
  final VoidCallback? onFocusHandled;
  final VoidCallback? onEditStart;
  final VoidCallback? onEditEnd;
  final Future<void> Function(String title)? onTitleSave;
  final VoidCallback? onCreateBelow;
  final VoidCallback? onDiscardDraft;
  final Future<void> Function(int delta, String title)? onNavigateAdjacent;
  final ValueChanged<bool?>? onCheckChanged;
  final VoidCallback? onSubItemsTap;

  @override
  State<TodoCard> createState() => _TodoCardState();
}

class _TodoCardState extends State<TodoCard> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  String _lastSavedTitle = '';
  bool _notesExpanded = false;
  bool _suppressFocusExit = false;
  bool _isExitingEdit = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder.title);
    _titleController.addListener(_onTitleTextChanged);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_onTitleFocusChange);
    _lastSavedTitle = widget.reminder.title;
    if (widget.requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    }
  }

  @override
  void didUpdateWidget(covariant TodoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing && !oldWidget.editing) {
      _lastSavedTitle = widget.reminder.title;
      _titleController.text = widget.reminder.title;
      _suppressFocusExit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestEditFocus());
    } else if (!widget.editing && oldWidget.editing) {
      _suppressFocusExit = false;
      _titleController.text = widget.reminder.title;
      _lastSavedTitle = widget.reminder.title;
    } else if (!widget.editing && oldWidget.reminder.title != widget.reminder.title) {
      _titleController.text = widget.reminder.title;
      _lastSavedTitle = widget.reminder.title;
    }
    if (oldWidget.reminder.notes != widget.reminder.notes) {
      _notesExpanded = false;
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
      widget.onFocusHandled?.call();
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
    if (!widget.inlineEditEnabled || widget.editing) {
      return;
    }
    widget.onEditStart?.call();
  }

  Future<void> _onArrowKey(int delta) async {
    if (!widget.editing ||
        _isExitingEdit ||
        widget.onNavigateAdjacent == null) {
      return;
    }
    _suppressFocusExit = true;
    try {
      await widget.onNavigateAdjacent!(delta, _titleController.text);
    } finally {
      if (mounted) {
        _suppressFocusExit = false;
      }
    }
  }

  KeyEventResult _onTitleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.editing || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      unawaited(_onArrowKey(-1));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      unawaited(_onArrowKey(1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _onTitleSubmitted(String _) async {
    if (!widget.editing || _isExitingEdit) {
      return;
    }
    final String value = _titleController.text.trim();
    if (value.isEmpty) {
      if (widget.isDraft) {
        _suppressFocusExit = true;
        widget.onDiscardDraft?.call();
      }
      return;
    }
    if (value != _lastSavedTitle) {
      _suppressFocusExit = true;
      await widget.onTitleSave?.call(value);
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
    widget.onCreateBelow?.call();
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
          widget.onDiscardDraft?.call();
        } else {
          _titleController.text = widget.reminder.title;
          widget.onEditEnd?.call();
        }
        return;
      }
      if (value != _lastSavedTitle) {
        await widget.onTitleSave?.call(value);
        if (!mounted) {
          return;
        }
        _lastSavedTitle = value;
      }
      widget.onEditEnd?.call();
    } finally {
      _isExitingEdit = false;
      _suppressFocusExit = false;
    }
  }

  TextStyle? _titleTextStyle(
    BuildContext context, {
    bool showEditUnderline = false,
  }) {
    final Color textColor = widget.reminder.isCompleted
        ? AppTheme.secondaryLabelColor
        : AppTheme.textPrimaryColor;
    return Theme.of(context).textTheme.titleMedium?.copyWith(
          color: textColor,
          decoration: showEditUnderline
              ? TextDecoration.underline
              : (widget.reminder.isCompleted
                  ? TextDecoration.lineThrough
                  : TextDecoration.none),
          decorationColor:
              showEditUnderline ? AppTheme.primaryColor : textColor,
          height: 1.3,
        );
  }

  Widget _buildNotes(BuildContext context, String notes) {
    final TextStyle style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.secondaryLabelColor,
        ) ??
        const TextStyle(color: AppTheme.secondaryLabelColor);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final TextPainter collapsedPainter = TextPainter(
          text: TextSpan(text: notes, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth - 20);
        final bool canExpand =
            notes.contains('\n') || collapsedPainter.didExceedMaxLines;

        if (!canExpand) {
          return Text(notes, style: style);
        }

        return GestureDetector(
          onTap: () => setState(() => _notesExpanded = !_notesExpanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  notes,
                  maxLines: _notesExpanded ? null : 1,
                  overflow: _notesExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: style,
                ),
              ),
              Icon(
                _notesExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 16,
                color: AppTheme.secondaryLabelColor,
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isDeadlineOverdue(Reminder reminder) {
    if (!reminder.hasDeadline || reminder.isCompleted || reminder.deadlineAt == null) {
      return false;
    }
    return DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!) < 0;
  }

  Color _deadlineAccentColor(Reminder reminder) {
    if (reminder.isCompleted) {
      return AppTheme.secondaryLabelColor;
    }
    if (!reminder.hasDeadline || reminder.deadlineAt == null) {
      return AppTheme.deadlineColor;
    }
    final int days = DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!);
    if (days <= 0) {
      return AppTheme.destructiveColor;
    }
    if (days == 1) {
      return AppTheme.primaryColor;
    }
    return AppTheme.textPrimaryColor;
  }

  Color _deadlineScheduleDateColor(Reminder reminder) {
    if (reminder.isCompleted) {
      return AppTheme.secondaryLabelColor;
    }
    if (!reminder.hasDeadline || reminder.deadlineAt == null) {
      return AppTheme.deadlineColor;
    }
    final int days = DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!);
    if (days <= 0) {
      return AppTheme.destructiveColor;
    }
    if (days == 1) {
      return AppTheme.primaryColor;
    }
    return AppTheme.secondaryLabelColor;
  }

  TextStyle? _scheduleDateTextStyle(
    BuildContext context, {
    required Color color,
    TextDecoration? decoration,
  }) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          decoration: decoration,
        );
  }

  Widget _buildDeadlineCountdown(BuildContext context, AppLocalizations l10n) {
    final Reminder reminder = widget.reminder;
    if (!reminder.hasDeadline || reminder.isCompleted || reminder.deadlineAt == null) {
      return const SizedBox.shrink();
    }

    final int days = DateTimeUtils.calendarDaysUntil(reminder.deadlineAt!);
    final String label;
    if (days < 0) {
      label = l10n.todoDeadlineOverdue(-days);
    } else if (days == 0) {
      label = l10n.todoDeadlineDueToday;
    } else if (days == 1) {
      label = l10n.todoDeadlineDueTomorrow;
    } else {
      label = l10n.todoDeadlineDaysLeft(days);
    }

    return Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: _deadlineAccentColor(reminder).withValues(alpha: 0.88),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
    );
  }

  Widget _buildSubItemsShortcut(BuildContext context, AppLocalizations l10n) {
    final Reminder reminder = widget.reminder;
    final Color accentColor = reminder.isCompleted
        ? AppTheme.secondaryLabelColor
        : AppTheme.primaryColor;

    return Tooltip(
      message: l10n.todoSubItemsPageTitle,
      child: Material(
        color: accentColor.withValues(alpha: reminder.isCompleted ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: widget.onSubItemsTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.checklist_outlined, size: 15, color: accentColor),
                const SizedBox(width: 4),
                Text(
                  l10n.todoSubItemsProgress(
                    reminder.subItemCompletedCount,
                    reminder.subItems.length,
                  ),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Icon(Icons.chevron_right, size: 16, color: accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Reminder reminder = widget.reminder;
    final TextStyle? titleStyle = _titleTextStyle(context);
    final TextStyle? editingTitleStyle = _titleTextStyle(
      context,
      showEditUnderline: _hasUnsavedTitleEdit,
    );

    final bool isOverdue = _isDeadlineOverdue(reminder);

    final bool showCountdown =
        reminder.hasDeadline && !reminder.isCompleted;
    final bool showSubItems =
        reminder.hasSubItems && widget.onSubItemsTap != null;
    final bool showSubItemsInColumn = showSubItems && reminder.hasDeadline;
    final bool showSubItemsOnRight = showSubItems && !reminder.hasDeadline;

    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
      child: Stack(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Checkbox(
                value: reminder.isCompleted,
                onChanged: widget.onCheckChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                  widget.editing
                      ? Focus(
                          focusNode: _titleFocusNode,
                          onKeyEvent: _onTitleKeyEvent,
                          child: TextField(
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
                          ),
                        )
                      : GestureDetector(
                          onTap: _startTitleEdit,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            reminder.title,
                            style: titleStyle,
                          ),
                        ),
                  if (showSubItemsInColumn) ...<Widget>[
                    const SizedBox(height: 6),
                    _buildSubItemsShortcut(context, l10n),
                  ],
                  if (reminder.notes?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(height: 4),
                    _buildNotes(context, reminder.notes!.trim()),
                  ],
                  if (reminder.hasDeadline) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          if (reminder.isSyncedToCalendar) ...<Widget>[
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: reminder.isCompleted
                                  ? AppTheme.secondaryLabelColor
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Icon(
                            Icons.flag_outlined,
                            size: 12,
                            color: reminder.isCompleted
                                ? AppTheme.secondaryLabelColor
                                : AppTheme.deadlineColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.todoDeadlineLabel(
                                DateTimeUtils.formatCardDateTime(reminder.deadlineAt!),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _scheduleDateTextStyle(
                                context,
                                color: _deadlineScheduleDateColor(reminder),
                                decoration: reminder.isCompleted
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (reminder.isSyncedToCalendar && !reminder.hasDeadline) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: reminder.isCompleted
                                ? AppTheme.secondaryLabelColor
                                : AppTheme.primaryColor,
                          ),
                          if (widget.calendarScheduleLabel != null) ...<Widget>[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.calendarScheduleLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _scheduleDateTextStyle(
                                  context,
                                  color: reminder.isCompleted
                                      ? AppTheme.secondaryLabelColor
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (reminder.remindEnabled) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.notifications_outlined,
                            size: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          if (reminder.voiceRemindEnabled) ...<Widget>[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.graphic_eq_rounded,
                              size: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              reminder.remindAt != null
                                  ? ReminderTimeRules.remindPreviewLabel(
                                      remindAt: reminder.remindAt,
                                      frequency: reminder.remindFrequency,
                                      repeatDays: reminder.remindRepeatDays,
                                    )
                                  : l10n.todoReminderSet,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.secondaryLabelColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  if (widget.showCreatedDate) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      l10n.todoCreatedAt(DateTimeUtils.formatDate(reminder.createdAt)),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
              if (showSubItemsOnRight)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _buildSubItemsShortcut(context, l10n),
                ),
              if (showCountdown) const SizedBox(width: 44),
            ],
          ),
          if (showCountdown)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 44,
              child: Center(
                child: _buildDeadlineCountdown(context, l10n),
              ),
            ),
        ],
      ),
    );

    if (widget.grouped) {
      if (!isOverdue) {
        return content;
      }
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(
            left: BorderSide(
              color: AppTheme.destructiveColor,
              width: 3,
            ),
          ),
        ),
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.groupedRadius),
        border: isOverdue
            ? Border.all(
                color: AppTheme.destructiveColor.withValues(alpha: 0.5),
                width: 1,
              )
            : null,
        boxShadow: isOverdue
            ? <BoxShadow>[
                BoxShadow(
                  color: AppTheme.destructiveColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : <BoxShadow>[
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
  }
}
