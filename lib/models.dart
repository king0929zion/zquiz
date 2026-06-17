class SubjectInfo {
  const SubjectInfo({required this.id, required this.name});

  final String id;
  final String name;

  factory SubjectInfo.fromJson(Map<String, dynamic> json) {
    return SubjectInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class DetailPair {
  const DetailPair({required this.label, required this.value});

  final String label;
  final String value;

  factory DetailPair.fromAny(dynamic source) {
    if (source is List && source.length >= 2) {
      return DetailPair(label: source[0].toString(), value: source[1].toString());
    }
    if (source is Map<String, dynamic>) {
      return DetailPair(
        label: source['label']?.toString() ?? '',
        value: source['value']?.toString() ?? '',
      );
    }
    return DetailPair(label: '', value: source?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

class UnitInfo {
  const UnitInfo({required this.symbol, required this.name, required this.unit});

  final String symbol;
  final String name;
  final String unit;

  factory UnitInfo.fromAny(dynamic source) {
    if (source is List && source.length >= 3) {
      return UnitInfo(
        symbol: source[0].toString(),
        name: source[1].toString(),
        unit: source[2].toString(),
      );
    }
    if (source is Map<String, dynamic>) {
      return UnitInfo(
        symbol: source['symbol']?.toString() ?? '',
        name: source['name']?.toString() ?? '',
        unit: source['unit']?.toString() ?? '',
      );
    }
    return UnitInfo(symbol: '', name: '', unit: source?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'symbol': symbol, 'name': name, 'unit': unit};
}

class KeyPoint {
  const KeyPoint({required this.text, required this.cue, required this.freq});

  final String text;
  final String cue;
  final int freq;

  factory KeyPoint.fromJson(Map<String, dynamic> json) {
    return KeyPoint(
      text: json['text']?.toString() ?? '',
      cue: json['cue']?.toString() ?? '',
      freq: int.tryParse(json['freq']?.toString() ?? '') ?? 0,
    );
  }
}

class Article {
  const Article({
    required this.id,
    required this.type,
    required this.title,
    required this.author,
    required this.dynasty,
    required this.text,
    required this.keyPoints,
    required this.explain,
    required this.subject,
  });

  final String id;
  final String type;
  final String title;
  final String author;
  final String dynasty;
  final List<String> text;
  final List<KeyPoint> keyPoints;
  final String explain;
  final String subject;

  String get subtitle {
    final parts = [dynasty, author].where((item) => item.trim().isNotEmpty).toList();
    return parts.join(' · ');
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      dynasty: json['dynasty']?.toString() ?? '',
      text: (json['text'] as List<dynamic>? ?? const []).map((item) => item.toString()).toList(),
      keyPoints: (json['keyPoints'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(KeyPoint.fromJson)
          .toList(),
      explain: json['explain']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'chinese',
    );
  }
}

class StudyCard {
  const StudyCard({
    required this.id,
    required this.subject,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.note,
    required this.explain,
    required this.articleId,
    required this.detailTitle,
    required this.details,
    required this.unitText,
    required this.units,
    this.sourceId = '',
    this.generatedByAi = false,
  });

  final String id;
  final String subject;
  final String kind;
  final String title;
  final String subtitle;
  final String primary;
  final String note;
  final String explain;
  final String articleId;
  final String detailTitle;
  final List<DetailPair> details;
  final String unitText;
  final List<UnitInfo> units;
  final String sourceId;
  final bool generatedByAi;

  factory StudyCard.fromJson(Map<String, dynamic> json) {
    return StudyCard(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      primary: json['primary']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      explain: json['explain']?.toString() ?? '',
      articleId: json['articleId']?.toString() ?? '',
      detailTitle: json['detailTitle']?.toString() ?? json['title']?.toString() ?? '',
      details: (json['details'] as List<dynamic>? ?? const []).map(DetailPair.fromAny).toList(),
      unitText: json['unitText']?.toString() ?? '',
      units: (json['units'] as List<dynamic>? ?? const []).map(UnitInfo.fromAny).toList(),
      sourceId: json['sourceId']?.toString() ?? '',
      generatedByAi: json['generatedByAi'] == true || json['source']?.toString() == 'ai',
    );
  }

  StudyCard copyWith({
    String? id,
    String? subject,
    String? kind,
    String? title,
    String? subtitle,
    String? primary,
    String? note,
    String? explain,
    String? articleId,
    String? detailTitle,
    List<DetailPair>? details,
    String? unitText,
    List<UnitInfo>? units,
    String? sourceId,
    bool? generatedByAi,
  }) {
    return StudyCard(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      primary: primary ?? this.primary,
      note: note ?? this.note,
      explain: explain ?? this.explain,
      articleId: articleId ?? this.articleId,
      detailTitle: detailTitle ?? this.detailTitle,
      details: details ?? this.details,
      unitText: unitText ?? this.unitText,
      units: units ?? this.units,
      sourceId: sourceId ?? this.sourceId,
      generatedByAi: generatedByAi ?? this.generatedByAi,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'kind': kind,
      'title': title,
      'subtitle': subtitle,
      'primary': primary,
      'note': note,
      'explain': explain,
      'articleId': articleId,
      'detailTitle': detailTitle,
      'details': details.map((item) => item.toJson()).toList(),
      'unitText': unitText,
      'units': units.map((item) => item.toJson()).toList(),
      'sourceId': sourceId,
      'generatedByAi': generatedByAi,
    };
  }
}

class QuizItem {
  const QuizItem({
    required this.id,
    required this.subject,
    required this.kind,
    required this.question,
    required this.answer,
    required this.accepts,
    required this.cardId,
    required this.articleId,
    required this.title,
    required this.freq,
    this.explain = '',
    this.aiGrading = false,
    this.sourceId = '',
    this.questionType = 'cloze',
    this.options = const [],
    this.keywords = const [],
    this.gradingMode = 'exact',
  });

  final String id;
  final String subject;
  final String kind;
  final String question;
  final String answer;
  final List<String> accepts;
  final String cardId;
  final String articleId;
  final String title;
  final int freq;
  final String explain;
  final bool aiGrading;
  final String sourceId;
  final String questionType;
  final List<String> options;
  final List<String> keywords;
  final String gradingMode;

  bool get isObjective => questionType == 'multiple_choice' || questionType == 'true_false';
  bool get prefersAi => aiGrading || gradingMode == 'ai' || questionType == 'open_answer' || questionType == 'big_question';
  bool get usesKeywords => gradingMode == 'keyword' || keywords.isNotEmpty || questionType == 'knowledge_qa';

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    final acceptsValue = json['accepts'];
    final rawAccepts = acceptsValue is List
        ? acceptsValue.map((item) => item.toString()).toList()
        : acceptsValue == null
            ? <String>[]
            : <String>[acceptsValue.toString()];
    final keywordValue = json['keywords'] ?? json['answerKeywords'];
    final rawKeywords = keywordValue is List ? keywordValue.map((item) => item.toString()).toList() : <String>[];
    final answer = json['answer']?.toString() ?? '';
    final type = json['questionType']?.toString() ?? json['type']?.toString() ?? json['kind']?.toString() ?? 'cloze';
    final mode = json['gradingMode']?.toString() ?? (rawKeywords.isNotEmpty ? 'keyword' : 'exact');
    return QuizItem(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      question: json['question']?.toString() ?? json['prompt']?.toString() ?? '',
      answer: answer,
      accepts: rawAccepts.isEmpty ? [answer] : rawAccepts,
      cardId: json['cardId']?.toString() ?? '',
      articleId: json['articleId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      freq: int.tryParse(json['freq']?.toString() ?? '') ?? 0,
      explain: json['explain']?.toString() ?? json['explanation']?.toString() ?? '',
      aiGrading: json['aiGrading'] == true || mode == 'ai' || type == 'open_answer' || type == 'big_question',
      sourceId: json['sourceId']?.toString() ?? '',
      questionType: type,
      options: json['options'] is List ? (json['options'] as List).map((item) => item.toString()).toList() : const <String>[],
      keywords: rawKeywords,
      gradingMode: mode,
    );
  }

  QuizItem copyWith({
    String? id,
    String? subject,
    String? kind,
    String? question,
    String? answer,
    List<String>? accepts,
    String? cardId,
    String? articleId,
    String? title,
    int? freq,
    String? explain,
    bool? aiGrading,
    String? sourceId,
    String? questionType,
    List<String>? options,
    List<String>? keywords,
    String? gradingMode,
  }) {
    return QuizItem(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      kind: kind ?? this.kind,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      accepts: accepts ?? this.accepts,
      cardId: cardId ?? this.cardId,
      articleId: articleId ?? this.articleId,
      title: title ?? this.title,
      freq: freq ?? this.freq,
      explain: explain ?? this.explain,
      aiGrading: aiGrading ?? this.aiGrading,
      sourceId: sourceId ?? this.sourceId,
      questionType: questionType ?? this.questionType,
      options: options ?? this.options,
      keywords: keywords ?? this.keywords,
      gradingMode: gradingMode ?? this.gradingMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'kind': kind,
      'question': question,
      'answer': answer,
      'accepts': accepts,
      'cardId': cardId,
      'articleId': articleId,
      'title': title,
      'freq': freq,
      'explain': explain,
      'aiGrading': aiGrading,
      'sourceId': sourceId,
      'questionType': questionType,
      'options': options,
      'keywords': keywords,
      'gradingMode': gradingMode,
    };
  }
}

class ImportedMaterial {
  const ImportedMaterial({
    required this.id,
    required this.subject,
    required this.title,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String subject;
  final String title;
  final String text;
  final DateTime createdAt;

  factory ImportedMaterial.fromJson(Map<String, dynamic> json) {
    return ImportedMaterial(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'chinese',
      title: json['title']?.toString() ?? '导入资料',
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'title': title,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class AiSettings {
  const AiSettings({
    required this.apiUrl,
    required this.apiKey,
    required this.model,
  });

  final String apiUrl;
  final String apiKey;
  final String model;

  bool get isConfigured => apiUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  String get normalizedApiUrl {
    final value = apiUrl.trim();
    if (value.endsWith('/')) return value.substring(0, value.length - 1);
    return value;
  }

  factory AiSettings.empty() {
    return const AiSettings(
      apiUrl: 'https://api.openai.com/v1',
      apiKey: '',
      model: 'gpt-4o-mini',
    );
  }

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      apiUrl: json['apiUrl']?.toString() ?? 'https://api.openai.com/v1',
      apiKey: json['apiKey']?.toString() ?? '',
      model: json['model']?.toString() ?? 'gpt-4o-mini',
    );
  }

  Map<String, dynamic> toJson() => {'apiUrl': apiUrl, 'apiKey': apiKey, 'model': model};
}

class AiGeneratedPack {
  const AiGeneratedPack({required this.cards, required this.quiz, required this.rawText});

  final List<StudyCard> cards;
  final List<QuizItem> quiz;
  final String rawText;
}

class AiGradingResult {
  const AiGradingResult({
    required this.correct,
    required this.score,
    required this.feedback,
    required this.referenceAnswer,
  });

  final bool correct;
  final int score;
  final String feedback;
  final String referenceAnswer;
}

class ZQuizData {
  const ZQuizData({
    required this.subjects,
    required this.cards,
    required this.articles,
    required this.quiz,
  });

  final List<SubjectInfo> subjects;
  final List<StudyCard> cards;
  final List<Article> articles;
  final List<QuizItem> quiz;

  factory ZQuizData.fromJson(Map<String, dynamic> json) {
    return ZQuizData(
      subjects: (json['subjects'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SubjectInfo.fromJson)
          .toList(),
      cards: (json['cards'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StudyCard.fromJson)
          .toList(),
      articles: (json['articles'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Article.fromJson)
          .toList(),
      quiz: (json['quiz'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(QuizItem.fromJson)
          .toList(),
    );
  }

  ZQuizData withUserContent({
    List<StudyCard> extraCards = const [],
    List<QuizItem> extraQuiz = const [],
  }) {
    return ZQuizData(
      subjects: subjects,
      cards: [...cards, ...extraCards],
      articles: articles,
      quiz: [...quiz, ...extraQuiz],
    );
  }

  List<StudyCard> cardsFor(String subjectId) {
    if (subjectId == 'all') return cards;
    return cards.where((card) => card.subject == subjectId).toList();
  }

  List<QuizItem> quizFor(String subjectId) {
    final items = subjectId == 'all' ? quiz : quiz.where((item) => item.subject == subjectId).toList();
    final list = items.toList();
    list.sort((a, b) {
      final byFreq = b.freq.compareTo(a.freq);
      if (byFreq != 0) return byFreq;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  StudyCard? cardById(String id) {
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  Article? articleById(String id) {
    for (final article in articles) {
      if (article.id == id) return article;
    }
    return null;
  }

  QuizItem? quizById(String id) {
    for (final item in quiz) {
      if (item.id == id) return item;
    }
    return null;
  }
}
