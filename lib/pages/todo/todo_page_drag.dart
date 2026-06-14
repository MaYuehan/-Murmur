part of 'todo_page.dart';

extension _TodoPageDragExtension on _TodoPageState {
  void _clearSectionDragState() {
    _sectionDragAnchorOffset = null;
    _sectionDragFeedbackSize = null;
    if (!_sectionDragVisualState.value.isActive) {
      return;
    }
    _sectionDragVisualState.value = const _SectionDragVisualState();
  }

  void _clearTodoDragState() {
    _todoDragAnchorOffset = null;
    _todoDragFeedbackSize = null;
    if (!_todoDragVisualState.value.isActive) {
      return;
    }
    _todoDragVisualState.value = const _TodoDragVisualState();
  }

  bool _shouldShiftSectionHeaderDown(
    int sectionIndex,
    _SectionDragVisualState dragState,
  ) {
    if (dragState.draggingSectionId == null) {
      return false;
    }
    if (dragState.insertAtTop) {
      return true;
    }
    final int? hoverIndex = dragState.hoverIndex;
    if (hoverIndex == null) {
      return false;
    }
    return sectionIndex > hoverIndex;
  }

  bool _shouldShiftTodoRowDown({
    required String listKey,
    required int rowIndex,
    required _TodoDragVisualState dragState,
  }) {
    if (dragState.draggingTodoId == null ||
        dragState.targetListKey != listKey) {
      return false;
    }
    if (dragState.insertAtTop) {
      return true;
    }
    final int? hoverRowIndex = dragState.hoverRowIndex;
    if (hoverRowIndex == null) {
      return false;
    }
    return rowIndex > hoverRowIndex;
  }

  GlobalKey _todoRowMeasureKey(String listKey, int rowIndex) {
    final Map<int, GlobalKey> keys = _todoRowMeasureKeys.putIfAbsent(
      listKey,
      () => <int, GlobalKey>{},
    );
    return keys.putIfAbsent(rowIndex, GlobalKey.new);
  }

  GlobalKey _todoEmptyDropMeasureKey(String listKey) {
    return _todoEmptyDropMeasureKeys.putIfAbsent(listKey, GlobalKey.new);
  }

  GlobalKey _sectionHeaderMeasureKey(int sectionIndex) {
    return _sectionHeaderMeasureKeys.putIfAbsent(sectionIndex, GlobalKey.new);
  }

  GlobalKey _sectionFooterMeasureKey(int sectionIndex) {
    return _sectionFooterMeasureKeys.putIfAbsent(sectionIndex, GlobalKey.new);
  }

  Rect _bottomHalfOfRect(Rect rect) {
    return Rect.fromLTWH(
      rect.left,
      rect.top + rect.height / 2,
      rect.width,
      rect.height / 2,
    );
  }

  Rect _topHalfOfRect(Rect rect) {
    return Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height / 2,
    );
  }

  Rect? _sectionBoundsGlobalRect(int sectionIndex) {
    final RenderBox? headerBox = _sectionHeaderMeasureKeys[sectionIndex]
        ?.currentContext
        ?.findRenderObject() as RenderBox?;
    if (headerBox == null || !headerBox.hasSize) {
      return null;
    }

    final RenderBox? footerBox = _sectionFooterMeasureKeys[sectionIndex]
        ?.currentContext
        ?.findRenderObject() as RenderBox?;
    if (footerBox != null && footerBox.hasSize) {
      final Offset headerTopLeft = headerBox.localToGlobal(Offset.zero);
      final Offset footerBottomRight = footerBox.localToGlobal(
        Offset(footerBox.size.width, footerBox.size.height),
      );
      final Rect sectionBounds = Rect.fromLTRB(
        headerTopLeft.dx,
        headerTopLeft.dy,
        footerBottomRight.dx,
        footerBottomRight.dy,
      );
      if (sectionBounds.height > 0) {
        return sectionBounds;
      }
    }

    return headerBox.localToGlobal(Offset.zero) & headerBox.size;
  }

  Rect? _sectionBottomHalfGlobalRect(int sectionIndex) {
    final Rect? sectionBounds = _sectionBoundsGlobalRect(sectionIndex);
    if (sectionBounds == null) {
      return null;
    }
    return _bottomHalfOfRect(sectionBounds);
  }

  Rect? _sectionTopHalfGlobalRect(int sectionIndex) {
    final Rect? sectionBounds = _sectionBoundsGlobalRect(sectionIndex);
    if (sectionBounds == null) {
      return null;
    }
    return _topHalfOfRect(sectionBounds);
  }

  Rect _sectionDragFeedbackGlobalRect(Offset pointerGlobal) {
    if (_sectionDragAnchorOffset == null || _sectionDragFeedbackSize == null) {
      return Rect.zero;
    }
    final Offset topLeft = pointerGlobal - _sectionDragAnchorOffset!;
    return topLeft & _sectionDragFeedbackSize!;
  }

  void _updateSectionDragHoverFromFeedback(Offset pointerGlobal) {
    final _SectionDragVisualState current = _sectionDragVisualState.value;
    final _SectionDragOrderContext? orderContext = _sectionDragOrderContext;
    if (current.draggingSectionId == null || orderContext == null) {
      return;
    }

    final Rect feedbackRect = _sectionDragFeedbackGlobalRect(pointerGlobal);
    if (feedbackRect.isEmpty) {
      return;
    }

    int? bestSectionIndex;
    bool bestInsertAtTop = false;
    double bestOverlap = 0;

    if (orderContext.orderedSectionIds.isNotEmpty) {
      final String firstSectionId = orderContext.orderedSectionIds.first;
      if (firstSectionId != current.draggingSectionId) {
        final Rect? topHalf = _sectionTopHalfGlobalRect(0);
        if (topHalf != null) {
          final double overlap = _rectOverlapArea(feedbackRect, topHalf);
          if (overlap > bestOverlap) {
            bestOverlap = overlap;
            bestSectionIndex = 0;
            bestInsertAtTop = true;
          }
        }
      }
    }

    for (final MapEntry<int, GlobalKey> entry
        in _sectionHeaderMeasureKeys.entries) {
      final int sectionIndex = entry.key;
      if (sectionIndex < 0 ||
          sectionIndex >= orderContext.orderedSectionIds.length) {
        continue;
      }
      if (orderContext.orderedSectionIds[sectionIndex] ==
          current.draggingSectionId) {
        continue;
      }

      final Rect? bottomHalf = _sectionBottomHalfGlobalRect(sectionIndex);
      if (bottomHalf == null) {
        continue;
      }

      final double overlap = _rectOverlapArea(
        feedbackRect,
        bottomHalf,
      );
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        bestSectionIndex = sectionIndex;
        bestInsertAtTop = false;
      }
    }

    if (bestOverlap <= 0) {
      if (current.hoverIndex != null || current.insertAtTop) {
        _sectionDragVisualState.value = _SectionDragVisualState(
          draggingSectionId: current.draggingSectionId,
        );
      }
      return;
    }

    if (current.hoverIndex != bestSectionIndex ||
        current.insertAtTop != bestInsertAtTop) {
      _sectionDragVisualState.value = _SectionDragVisualState(
        draggingSectionId: current.draggingSectionId,
        hoverIndex: bestSectionIndex,
        insertAtTop: bestInsertAtTop,
      );
    }
  }

  void _finishSectionDragReorder() {
    final _SectionDragVisualState state = _sectionDragVisualState.value;
    final _SectionDragOrderContext? orderContext = _sectionDragOrderContext;
    if (state.draggingSectionId == null ||
        orderContext == null ||
        (!state.insertAtTop && state.hoverIndex == null)) {
      return;
    }

    final List<String> orderedSectionIds = orderContext.orderedSectionIds;
    final int fromIndex = orderedSectionIds.indexOf(state.draggingSectionId!);
    if (fromIndex < 0) {
      return;
    }

    int toIndex;
    if (state.insertAtTop) {
      toIndex = 0;
    } else {
      toIndex = state.hoverIndex! + 1;
      if (fromIndex < toIndex) {
        toIndex -= 1;
      }
    }
    if (toIndex < 0 ||
        toIndex >= orderedSectionIds.length ||
        fromIndex == toIndex) {
      return;
    }

    ref.read(todoSectionOrderProvider.notifier).reorderSections(
          fromIndex: fromIndex,
          toIndex: toIndex,
          groups: orderContext.todoGroups,
        );
  }

  Rect _todoDragFeedbackGlobalRect(Offset pointerGlobal) {
    if (_todoDragAnchorOffset == null || _todoDragFeedbackSize == null) {
      return Rect.zero;
    }
    final Offset topLeft = pointerGlobal - _todoDragAnchorOffset!;
    return topLeft & _todoDragFeedbackSize!;
  }

  Rect _rowBottomHalfGlobalRect(RenderBox box) {
    return _bottomHalfOfRect(box.localToGlobal(Offset.zero) & box.size);
  }

  Rect _rowTopHalfGlobalRect(RenderBox box) {
    return _topHalfOfRect(box.localToGlobal(Offset.zero) & box.size);
  }

  bool _shouldSkipTodoTopInsert({
    required String listKey,
    required _TodoDragVisualState current,
  }) {
    if (current.sourceListKey != listKey) {
      return false;
    }
    final _TodoDropListContext? listContext = _todoDropListContexts[listKey];
    if (listContext == null || listContext.todos.isEmpty) {
      return false;
    }
    return listContext.todos.first.id == current.draggingTodoId;
  }

  double _rectOverlapArea(Rect a, Rect b) {
    final Rect intersection = a.intersect(b);
    if (intersection.isEmpty) {
      return 0;
    }
    return intersection.width * intersection.height;
  }

  void _updateTodoDragHoverFromFeedback(Offset pointerGlobal) {
    final _TodoDragVisualState current = _todoDragVisualState.value;
    if (current.draggingTodoId == null) {
      return;
    }

    final Rect feedbackRect = _todoDragFeedbackGlobalRect(pointerGlobal);
    if (feedbackRect.isEmpty) {
      return;
    }

    String? bestListKey;
    int? bestRowIndex;
    bool bestInsertAtTop = false;
    double bestOverlap = 0;

    for (final MapEntry<String, _TodoDropListContext> entry
        in _todoDropListContexts.entries) {
      final String listKey = entry.key;
      final _TodoDropListContext listContext = entry.value;
      if (!_canDropTodoIntoList(listKey, current.draggingTodoId!)) {
        continue;
      }

      if (listContext.todos.isEmpty) {
        final RenderBox? box = _todoEmptyDropMeasureKey(listKey)
            .currentContext
            ?.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) {
          continue;
        }
        final Rect dropZone = box.localToGlobal(Offset.zero) & box.size;
        final double overlap = _rectOverlapArea(feedbackRect, dropZone);
        if (overlap > bestOverlap) {
          bestOverlap = overlap;
          bestListKey = listKey;
          bestRowIndex = -1;
          bestInsertAtTop = false;
        }
        continue;
      }

      if (!_shouldSkipTodoTopInsert(listKey: listKey, current: current)) {
        final GlobalKey? firstRowKey = _todoRowMeasureKeys[listKey]?[0];
        final RenderBox? firstRowBox = firstRowKey
            ?.currentContext
            ?.findRenderObject() as RenderBox?;
        if (firstRowBox != null && firstRowBox.hasSize) {
          final double overlap = _rectOverlapArea(
            feedbackRect,
            _rowTopHalfGlobalRect(firstRowBox),
          );
          if (overlap > bestOverlap) {
            bestOverlap = overlap;
            bestListKey = listKey;
            bestRowIndex = 0;
            bestInsertAtTop = true;
          }
        }
      }

      final Map<int, GlobalKey>? rowKeys = _todoRowMeasureKeys[listKey];
      if (rowKeys == null) {
        continue;
      }

      for (final MapEntry<int, GlobalKey> rowEntry in rowKeys.entries) {
        final RenderBox? box = rowEntry.value.currentContext?.findRenderObject()
            as RenderBox?;
        if (box == null || !box.hasSize) {
          continue;
        }
        final double overlap = _rectOverlapArea(
          feedbackRect,
          _rowBottomHalfGlobalRect(box),
        );
        if (overlap > bestOverlap) {
          bestOverlap = overlap;
          bestListKey = listKey;
          bestRowIndex = rowEntry.key;
          bestInsertAtTop = false;
        }
      }
    }

    if (bestOverlap <= 0) {
      if (current.targetListKey != null ||
          current.hoverRowIndex != null ||
          current.insertAtTop) {
        _todoDragVisualState.value = _TodoDragVisualState(
          draggingTodoId: current.draggingTodoId,
          sourceListKey: current.sourceListKey,
        );
      }
      return;
    }

    if (current.targetListKey != bestListKey ||
        current.hoverRowIndex != bestRowIndex ||
        current.insertAtTop != bestInsertAtTop) {
      _todoDragVisualState.value = _TodoDragVisualState(
        draggingTodoId: current.draggingTodoId,
        sourceListKey: current.sourceListKey,
        targetListKey: bestListKey,
        hoverRowIndex: bestRowIndex,
        insertAtTop: bestInsertAtTop,
      );
    }
  }

  void _finishTodoDragDrop() {
    final _TodoDragVisualState state = _todoDragVisualState.value;
    final String? draggedId = state.draggingTodoId;
    final String? targetListKey = state.targetListKey;
    if (draggedId == null ||
        targetListKey == null ||
        (!state.insertAtTop && state.hoverRowIndex == null)) {
      return;
    }

    final _TodoDropListContext? listContext = _todoDropListContexts[targetListKey];
    if (listContext == null ||
        !_canDropTodoIntoList(targetListKey, draggedId)) {
      return;
    }

    final int insertIndex;
    if (state.insertAtTop) {
      insertIndex = 0;
    } else if (state.hoverRowIndex! < 0) {
      insertIndex = 0;
    } else {
      insertIndex = state.hoverRowIndex! + 1;
    }

    _moveTodoAtInsertGap(
      targetList: listContext.todos,
      draggedId: draggedId,
      insertIndex: insertIndex,
      targetTodoGroupId: listContext.targetTodoGroupId,
    );
  }

  Widget _buildTodoRowShiftWrapper({
    required String listKey,
    required int rowIndex,
    required Widget child,
  }) {
    return ValueListenableBuilder<_TodoDragVisualState>(
      valueListenable: _todoDragVisualState,
      builder: (
        BuildContext context,
        _TodoDragVisualState dragState,
        Widget? wrappedChild,
      ) {
        final bool shouldShiftDown = _shouldShiftTodoRowDown(
          listKey: listKey,
          rowIndex: rowIndex,
          dragState: dragState,
        );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            shouldShiftDown ? _TodoPageStateBase._todoRowDragShiftOffset : 0,
            0,
          ),
          transformAlignment: Alignment.topCenter,
          child: wrappedChild,
        );
      },
      child: child,
    );
  }
  Widget _buildReorderableSectionHeader({
    required String sectionId,
    required int sectionIndex,
    required List<String> orderedSectionIds,
    required List<TodoGroup> todoGroups,
    required Widget child,
  }) {
    final double headerWidth =
        MediaQuery.sizeOf(context).width - AppTheme.pagePadding * 2;

    return ValueListenableBuilder<_SectionDragVisualState>(
      valueListenable: _sectionDragVisualState,
      builder: (
        BuildContext context,
        _SectionDragVisualState dragState,
        Widget? _,
      ) {
        final bool shouldShiftDown =
            _shouldShiftSectionHeaderDown(sectionIndex, dragState);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            shouldShiftDown ? _TodoPageStateBase._sectionHeaderDragShiftOffset : 0,
            0,
          ),
          transformAlignment: Alignment.topCenter,
          child: KeyedSubtree(
            key: _sectionHeaderMeasureKey(sectionIndex),
            child: Builder(
              builder: (BuildContext headerBuilderContext) {
                return Listener(
                  onPointerDown: (PointerDownEvent event) {
                    _sectionDragAnchorOffset = event.localPosition;
                  },
                  child: LongPressDraggable<String>(
                    data: sectionId,
                    onDragStarted: () {
                      final RenderObject? renderObject =
                          headerBuilderContext.findRenderObject();
                      if (renderObject is RenderBox && renderObject.hasSize) {
                        _sectionDragFeedbackSize = renderObject.size;
                      }
                      _sectionDragVisualState.value = _SectionDragVisualState(
                        draggingSectionId: sectionId,
                      );
                    },
                    onDragUpdate: (DragUpdateDetails details) {
                      _updateSectionDragHoverFromFeedback(
                        details.globalPosition,
                      );
                    },
                    onDragEnd: (_) {
                      _finishSectionDragReorder();
                      _clearSectionDragState();
                    },
                    onDraggableCanceled: (_, __) => _clearSectionDragState(),
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: headerWidth,
                        child: Opacity(
                          opacity: 0.92,
                          child: KeyedSubtree(
                            key: ValueKey<String>(
                              'section_drag_feedback_$sectionId',
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: child,
                    ),
                    child: child,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  TodoGroup? _todoGroupForSectionId(String sectionId, List<TodoGroup> todoGroups) {
    final String? groupId = groupIdFromSectionId(sectionId);
    if (groupId == null) {
      return null;
    }
    for (final TodoGroup group in todoGroups) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  bool _isDeadlineTodoListKey(String listKey) =>
      listKey == _todoDeadlineListKey;

  String _todoGroupListKey(String groupId) => 'todo_group:$groupId';

  bool _canDropTodoIntoList(String listKey, String draggedId) {
    if (_isDeadlineTodoListKey(listKey)) {
      return false;
    }
    final Reminder? reminder =
        ref.read(reminderListProvider.notifier).getReminderById(draggedId);
    return reminder != null && !reminder.hasDeadline;
  }

  bool get _isTodoCrossDragActive =>
      _todoDragVisualState.value.draggingTodoId != null;

  Widget _buildReorderableTodoRow({
    required Reminder reminder,
    required int rowIndex,
    required List<Reminder> todos,
    required String listKey,
    required String? targetTodoGroupId,
    required bool reorderEnabled,
    required bool dropEnabled,
    required Widget child,
  }) {
    if (_editingTodoId != null) {
      return child;
    }
    if (!reorderEnabled && !dropEnabled) {
      return child;
    }

    final double rowWidth =
        MediaQuery.sizeOf(context).width - AppTheme.pagePadding * 2;

    if (!reorderEnabled) {
      return child;
    }

    return Builder(
      builder: (BuildContext rowBuilderContext) {
        return Listener(
          onPointerDown: (PointerDownEvent event) {
            _todoDragAnchorOffset = event.localPosition;
          },
          child: LongPressDraggable<String>(
            data: reminder.id,
            onDragStarted: () {
              final RenderObject? renderObject =
                  rowBuilderContext.findRenderObject();
              if (renderObject is RenderBox && renderObject.hasSize) {
                _todoDragFeedbackSize = renderObject.size;
              }
              _todoDragVisualState.value = _TodoDragVisualState(
                draggingTodoId: reminder.id,
                sourceListKey: listKey,
              );
            },
            onDragUpdate: (DragUpdateDetails details) {
              _updateTodoDragHoverFromFeedback(details.globalPosition);
            },
            onDragEnd: (_) {
              _finishTodoDragDrop();
              _clearTodoDragState();
            },
            onDraggableCanceled: (_, __) => _clearTodoDragState(),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: rowWidth,
                child: Opacity(
                  opacity: 0.92,
                  child: KeyedSubtree(
                    key: ValueKey<String>('todo_drag_feedback_${reminder.id}'),
                    child: child,
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: child,
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _moveTodoAtInsertGap({
    required List<Reminder> targetList,
    required String draggedId,
    required int insertIndex,
    required String? targetTodoGroupId,
  }) {
    ref.read(reminderListProvider.notifier).moveFlexibleTodoToInsertIndex(
          reminderId: draggedId,
          targetList: targetList,
          insertIndex: insertIndex,
          targetTodoGroupId: targetTodoGroupId,
        );
  }

}
