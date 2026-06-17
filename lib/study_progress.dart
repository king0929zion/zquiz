import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class StudyProgress extends ChangeNotifier {
  static const _completedKey = 'zquiz.completed.quiz.ids';
  static const _wrongKey = 'zquiz.wrong.quiz.ids';

  StudyProgress(this._preferences) {
    _completed = _preferences.getStringList(_completedKey)?.toSet() ?? <String>{};
    _wrong = _preferences.getStringList(_wrongKey)?.toSet() ?? <String>{};
  }

  final SharedPreferences _preferences;
  late Set<String> _completed;
  late Set<String> _wrong;

  Set<String> get completed => Set.unmodifiable(_completed);
  Set<String> get wrong => Set.unmodifiable(_wrong);

  bool isCompleted(String id) => _completed.contains(id);
  bool isWrong(String id) => _wrong.contains(id);

  Future<void> markCorrect(String id) async {
    _completed.add(id);
    _wrong.remove(id);
    await _save();
  }

  Future<void> markWrong(String id) async {
    _completed.add(id);
    _wrong.add(id);
    await _save();
  }

  Future<void> clearCompletedFor(String subjectId, Iterable<QuizItem> allItems) async {
    final targetIds = _idsFor(subjectId, allItems);
    _completed.removeAll(targetIds);
    await _save();
  }

  Future<void> clearWrongFor(String subjectId, Iterable<QuizItem> allItems) async {
    final targetIds = _idsFor(subjectId, allItems);
    _wrong.removeAll(targetIds);
    await _save();
  }

  Future<void> clearAll() async {
    _completed.clear();
    _wrong.clear();
    await _save();
  }

  Set<String> _idsFor(String subjectId, Iterable<QuizItem> allItems) {
    return allItems
        .where((item) => subjectId == 'all' || item.subject == subjectId)
        .map((item) => item.id)
        .toSet();
  }

  Future<void> _save() async {
    await _preferences.setStringList(_completedKey, _completed.toList()..sort());
    await _preferences.setStringList(_wrongKey, _wrong.toList()..sort());
    notifyListeners();
  }
}
