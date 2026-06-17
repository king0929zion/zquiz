import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class UserContentStore extends ChangeNotifier {
  static const _settingsKey = 'zquiz.ai.settings';
  static const _materialsKey = 'zquiz.imported.materials';
  static const _cardsKey = 'zquiz.ai.generated.cards';
  static const _quizKey = 'zquiz.ai.generated.quiz';

  UserContentStore(this._preferences) {
    _settings = _loadSettings();
    _materials = _loadList(_materialsKey).map(ImportedMaterial.fromJson).toList();
    _generatedCards = _loadList(_cardsKey).map(StudyCard.fromJson).toList();
    _generatedQuiz = _loadList(_quizKey).map(QuizItem.fromJson).toList();
  }

  final SharedPreferences _preferences;
  late AiSettings _settings;
  late List<ImportedMaterial> _materials;
  late List<StudyCard> _generatedCards;
  late List<QuizItem> _generatedQuiz;

  AiSettings get settings => _settings;
  List<ImportedMaterial> get materials => List.unmodifiable(_materials);
  List<StudyCard> get generatedCards => List.unmodifiable(_generatedCards);
  List<QuizItem> get generatedQuiz => List.unmodifiable(_generatedQuiz);

  Future<void> saveSettings(AiSettings settings) async {
    _settings = settings;
    await _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Future<ImportedMaterial> addMaterial({
    required String subject,
    required String title,
    required String text,
  }) async {
    final now = DateTime.now();
    final material = ImportedMaterial(
      id: 'mat_${now.millisecondsSinceEpoch}',
      subject: subject,
      title: title.trim().isEmpty ? '导入资料' : title.trim(),
      text: text.trim(),
      createdAt: now,
    );
    _materials = [material, ..._materials];
    await _saveMaterials();
    notifyListeners();
    return material;
  }

  Future<void> deleteMaterial(String id) async {
    _materials = _materials.where((item) => item.id != id).toList();
    _generatedCards = _generatedCards.where((item) => item.sourceId != id).toList();
    _generatedQuiz = _generatedQuiz.where((item) => item.sourceId != id).toList();
    await Future.wait([_saveMaterials(), _saveGeneratedCards(), _saveGeneratedQuiz()]);
    notifyListeners();
  }

  Future<void> addGeneratedPack(AiGeneratedPack pack, {required String sourceId}) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final cards = <StudyCard>[];
    final quiz = <QuizItem>[];

    for (var index = 0; index < pack.cards.length; index++) {
      final card = pack.cards[index];
      final id = card.id.trim().isEmpty ? 'ai_card_${stamp}_$index' : card.id;
      cards.add(card.copyWith(id: id, sourceId: sourceId, generatedByAi: true));
    }

    for (var index = 0; index < pack.quiz.length; index++) {
      final item = pack.quiz[index];
      final id = item.id.trim().isEmpty ? 'ai_quiz_${stamp}_$index' : item.id;
      final linkIndex = cards.isEmpty ? -1 : index.clamp(0, cards.length - 1).toInt();
      final fallbackCardId = linkIndex < 0 ? '' : cards[linkIndex].id;
      quiz.add(item.copyWith(
        id: id,
        sourceId: sourceId,
        cardId: item.cardId.trim().isEmpty ? fallbackCardId : item.cardId,
      ));
    }

    _generatedCards = [...cards, ..._generatedCards];
    _generatedQuiz = [...quiz, ..._generatedQuiz];
    await Future.wait([_saveGeneratedCards(), _saveGeneratedQuiz()]);
    notifyListeners();
  }

  Future<void> clearGenerated() async {
    _generatedCards = <StudyCard>[];
    _generatedQuiz = <QuizItem>[];
    await Future.wait([_saveGeneratedCards(), _saveGeneratedQuiz()]);
    notifyListeners();
  }

  AiSettings _loadSettings() {
    final raw = _preferences.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) return AiSettings.empty();
    try {
      return AiSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AiSettings.empty();
    }
  }

  List<Map<String, dynamic>> _loadList(String key) {
    final raw = _preferences.getString(key);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _saveMaterials() async {
    await _preferences.setString(_materialsKey, jsonEncode(_materials.map((item) => item.toJson()).toList()));
  }

  Future<void> _saveGeneratedCards() async {
    await _preferences.setString(_cardsKey, jsonEncode(_generatedCards.map((item) => item.toJson()).toList()));
  }

  Future<void> _saveGeneratedQuiz() async {
    await _preferences.setString(_quizKey, jsonEncode(_generatedQuiz.map((item) => item.toJson()).toList()));
  }
}
