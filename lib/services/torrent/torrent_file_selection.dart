/// 文件操作的临时多选状态，与任务的下载优先级独立。
class TorrentFileSelection {
  final Set<int> selected = {};
  bool active = false;
  int? _anchor;
  bool _selectRange = true;

  void tap(int index) {
    _anchor = index;
    if (!active) return;
    _selectRange = !selected.remove(index);
    if (_selectRange) selected.add(index);
  }

  void longPress(int index, List<int> order) {
    final anchor = _anchor;
    final wasActive = active;
    active = true;
    final start = anchor == null ? -1 : order.indexOf(anchor);
    final end = order.indexOf(index);
    if (start < 0 || end < 0) {
      _selectRange = !selected.contains(index);
      if (_selectRange) {
        selected.add(index);
      } else {
        selected.remove(index);
      }
    } else {
      final lo = start < end ? start : end;
      final hi = start > end ? start : end;
      final range = order.sublist(lo, hi + 1);
      if (!wasActive) {
        _selectRange = true;
      } else if (range.every(selected.contains)) {
        // A second long press over an already selected range reverses it.
        _selectRange = false;
      }
      if (_selectRange) {
        selected.addAll(range);
      } else {
        selected.removeAll(range);
      }
    }
    _anchor = index;
  }

  void toggleGroup(Iterable<int> indices) {
    final group = indices.toList();
    if (group.isEmpty) return;
    active = true;
    _selectRange = !group.every(selected.contains);
    if (_selectRange) {
      selected.addAll(group);
    } else {
      selected.removeAll(group);
    }
    _anchor = group.last;
  }

  void selectAll(Iterable<int> indices) {
    active = true;
    selected
      ..clear()
      ..addAll(indices);
    _anchor = null;
  }

  void invert(Iterable<int> indices) {
    final next = indices.toSet().difference(selected);
    active = true;
    selected
      ..clear()
      ..addAll(next);
    _anchor = null;
  }

  void clear() {
    active = false;
    selected.clear();
    _anchor = null;
    _selectRange = true;
  }
}
