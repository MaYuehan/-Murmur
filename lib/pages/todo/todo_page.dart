import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/date_time_utils.dart';
import 'package:murmur/models/reminder.dart';
import 'package:murmur/providers/reminder_provider.dart';
import 'package:murmur/services/voice_service.dart';

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  bool _showCompleted = false;

  Future<void> _createTaskManually() async {
    final TextEditingController controller = TextEditingController();
    final TextEditingController remindTextController = TextEditingController();
    bool remindEnabled = false;
    DateTime? remindTime;
    String remindFrequency = 'once';
    String remindVoiceId = 'default';

    final _TodoCreateResult? result = await showModalBottomSheet<_TodoCreateResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: mediaQuery.viewInsets.bottom + 16,
            ),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '手动输入',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: '添加待办事项...'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('需要提醒'),
                      value: remindEnabled,
                      onChanged: (bool value) {
                        setModalState(() => remindEnabled = value);
                      },
                    ),
                    if (remindEnabled) ...<Widget>[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final DateTime now = DateTime.now();
                          final DateTime? date = await showDatePicker(
                            context: context,
                            initialDate: now,
                            firstDate: DateTime(now.year - 1, 1, 1),
                            lastDate: DateTime(now.year + 3, 12, 31),
                          );
                          if (date == null || !mounted) {
                            return;
                          }
                          final TimeOfDay? time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(now),
                          );
                          if (time == null) {
                            return;
                          }
                          setModalState(() {
                            remindTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        },
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          remindTime == null
                              ? '选择提醒时间'
                              : DateTimeUtils.formatDateTime(remindTime!),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: remindFrequency,
                        decoration: const InputDecoration(labelText: '提醒频率'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'once', child: Text('仅一次')),
                          DropdownMenuItem(value: 'daily', child: Text('每天')),
                          DropdownMenuItem(value: 'weekly', child: Text('每周')),
                        ],
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setModalState(() => remindFrequency = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: remindTextController,
                        decoration: const InputDecoration(labelText: '提醒文案'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: remindVoiceId,
                        decoration: const InputDecoration(labelText: '提醒声音'),
                        items: VoiceService.presetVoices
                            .map(
                              (VoiceOption voice) => DropdownMenuItem<String>(
                                value: voice.id,
                                child: Text(voice.name),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          if (value == null) {
                            return;
                          }
                          setModalState(() => remindVoiceId = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (remindEnabled && remindTime == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '请先选择提醒时间',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: remindEnabled && remindTime == null
                            ? null
                            : () {
                          Navigator.of(context).pop(
                            _TodoCreateResult(
                              title: controller.text.trim(),
                              remindEnabled: remindEnabled,
                              remindTime: remindTime,
                              remindFrequency: remindFrequency,
                              remindText: remindTextController.text.trim(),
                              remindVoiceId: remindVoiceId,
                            ),
                          );
                        },
                        child: const Text('添加'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    final String value = (result?.title ?? '').trim();
    if (value.isEmpty) {
      return;
    }

    final bool shouldRemind = result?.remindEnabled ?? false;
    final DateTime? finalRemindTime = shouldRemind ? result?.remindTime : null;

    await ref.read(reminderListProvider.notifier).addReminder(
          title: value,
          scheduledTime: null,
          timeType: 'flexible',
          remindEnabled: shouldRemind,
          remindAt: finalRemindTime,
          remindFrequency: result?.remindFrequency ?? 'once',
          remindText: (result?.remindText ?? '').trim().isEmpty
              ? null
              : result?.remindText.trim(),
          remindVoiceId: result?.remindVoiceId,
          soundId: result?.remindVoiceId ?? 'default',
          voiceId: result?.remindVoiceId ?? 'default',
        );
  }

  Future<void> _showCreateMenu() async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('手动输入'),
              onTap: () => Navigator.of(context).pop('manual'),
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('语音输入'),
              onTap: () => Navigator.of(context).pop('voice'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'manual') {
      await _createTaskManually();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('语音输入功能开发中')),
    );
  }

  Future<void> _showPromoteSheet(Reminder reminder) async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) {
      return;
    }
    final DateTime scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    await ref.read(reminderListProvider.notifier).promoteReminderToFixed(
          reminderId: reminder.id,
          scheduledTime: scheduled,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已安排时间，已同步到日历')),
    );
  }

  Future<void> _showInlineTitleEdit(Reminder reminder) async {
    final TextEditingController controller = TextEditingController(text: reminder.title);
    final String? text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: mediaQuery.viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '编辑任务标题'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    final String value = (text ?? '').trim();
    if (value.isEmpty) {
      return;
    }
    await ref.read(reminderListProvider.notifier).updateReminder(
          reminderId: reminder.id,
          title: value,
        );
  }

  Future<void> _showEditSheet(Reminder reminder) async {
    final TextEditingController titleController = TextEditingController(text: reminder.title);
    final TextEditingController voiceIdController =
        TextEditingController(text: reminder.voiceId ?? '');
    final TextEditingController voicePathController =
        TextEditingController(text: reminder.voicePath ?? '');
    DateTime? scheduledTime = reminder.scheduledTime;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: mediaQuery.viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '标题'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: voiceIdController,
                    decoration: const InputDecoration(labelText: 'voiceId（可选）'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: voicePathController,
                    decoration: const InputDecoration(labelText: 'voicePath（可选）'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final DateTime now = DateTime.now();
                            final DateTime? date = await showDatePicker(
                              context: context,
                              initialDate: scheduledTime ?? now,
                              firstDate: DateTime(now.year - 1, 1, 1),
                              lastDate: DateTime(now.year + 3, 12, 31),
                            );
                            if (date == null || !mounted) {
                              return;
                            }
                            final TimeOfDay? time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(scheduledTime ?? now),
                            );
                            if (time == null) {
                              return;
                            }
                            setModalState(() {
                              scheduledTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          },
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            scheduledTime == null
                                ? '设置时间（可选）'
                                : DateTimeUtils.formatDateTime(scheduledTime!),
                          ),
                        ),
                      ),
                      if (scheduledTime != null)
                        IconButton(
                          onPressed: () => setModalState(() => scheduledTime = null),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                        final String title = titleController.text.trim();
                        if (title.isEmpty) {
                          return;
                        }
                        await ref.read(reminderListProvider.notifier).updateReminder(
                              reminderId: reminder.id,
                              title: title,
                              scheduledTime: scheduledTime,
                              timeType: scheduledTime != null ? 'fixed' : 'flexible',
                              voiceId: voiceIdController.text.trim().isEmpty
                                  ? null
                                  : voiceIdController.text.trim(),
                              voicePath: voicePathController.text.trim().isEmpty
                                  ? null
                                  : voicePathController.text.trim(),
                            );
                        if (!mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                        },
                        child: const Text('保存编辑'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _clearCompleted() async {
    await ref.read(reminderListProvider.notifier).clearCompletedFlexibleReminders();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清除完成事项')),
    );
  }

  Future<void> _toggleComplete(Reminder reminder, bool? checked) async {
    await ref.read(reminderListProvider.notifier).setReminderCompleted(
          reminderId: reminder.id,
          isCompleted: checked ?? false,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderListProvider);
    final reminderNotifier = ref.read(reminderListProvider.notifier);
    final List<Reminder> pending = reminderNotifier.getFlexibleReminders(includeCompleted: false);
    final List<Reminder> completed = reminderNotifier
        .getFlexibleReminders(includeCompleted: true)
      ..removeWhere((Reminder item) => !item.isCompleted);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办'),
        actions: <Widget>[
          IconButton(
            onPressed: _showCreateMenu,
            icon: const Icon(Icons.add),
            tooltip: '新增',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 10),
              Text('待安排', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Expanded(
                child: pending.isEmpty && completed.isEmpty
                    ? const Center(child: Text('还没有待办事项'))
                    : ListView(
                        children: <Widget>[
                          ...pending.map((Reminder reminder) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Slidable(
                                key: ValueKey<String>('todo_${reminder.id}'),
                                endActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  extentRatio: 0.42,
                                  children: <Widget>[
                                    SlidableAction(
                                      onPressed: (_) => _showPromoteSheet(reminder),
                                      icon: Icons.calendar_today_outlined,
                                      label: '',
                                      backgroundColor: const Color(0xFF007AFF),
                                      foregroundColor: Colors.white,
                                    ),
                                    SlidableAction(
                                      onPressed: (_) => _showEditSheet(reminder),
                                      icon: Icons.edit_outlined,
                                      label: '',
                                      backgroundColor: const Color(0xFF8E8E93),
                                      foregroundColor: Colors.white,
                                    ),
                                    SlidableAction(
                                      onPressed: (_) async {
                                        await ref
                                            .read(reminderListProvider.notifier)
                                            .deleteReminder(reminder.id);
                                      },
                                      icon: Icons.delete_outline,
                                      label: '',
                                      backgroundColor: const Color(0xFFFF3B30),
                                      foregroundColor: Colors.white,
                                    ),
                                  ],
                                ),
                                child: _TodoCard(
                                  reminder: reminder,
                                  onTapText: () => _showInlineTitleEdit(reminder),
                                  onCheckChanged: (bool? checked) =>
                                      _toggleComplete(reminder, checked),
                                ),
                              ),
                            );
                          }),
                          if (completed.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() {
                                  _showCompleted = !_showCompleted;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      _showCompleted
                                          ? Icons.keyboard_arrow_down
                                          : Icons.keyboard_arrow_right,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '已完成 (${completed.length})',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _clearCompleted,
                                      child: const Text('清除已完成'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showCompleted) ...<Widget>[
                              const SizedBox(height: 8),
                              ...completed.map((Reminder reminder) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _TodoCard(
                                    reminder: reminder,
                                    onTapText: () => _showInlineTitleEdit(reminder),
                                    onCheckChanged: (bool? checked) =>
                                        _toggleComplete(reminder, checked),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodoCreateResult {
  const _TodoCreateResult({
    required this.title,
    required this.remindEnabled,
    required this.remindTime,
    required this.remindFrequency,
    required this.remindText,
    required this.remindVoiceId,
  });

  final String title;
  final bool remindEnabled;
  final DateTime? remindTime;
  final String remindFrequency;
  final String remindText;
  final String remindVoiceId;
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.reminder,
    this.onTapText,
    this.onCheckChanged,
  });

  final Reminder reminder;
  final VoidCallback? onTapText;
  final ValueChanged<bool?>? onCheckChanged;

  @override
  Widget build(BuildContext context) {
    final Color textColor = reminder.isCompleted
        ? Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6) ??
            const Color(0xFF666666)
        : const Color(0xFF2B2B2B);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Checkbox(
                  value: reminder.isCompleted,
                  onChanged: onCheckChanged,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: onTapText,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        reminder.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: textColor,
                              decoration: reminder.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(
                  label: Text('创建于 ${DateTimeUtils.formatDateTime(reminder.createdAt)}'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
