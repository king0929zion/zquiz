import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'prompt_skills.dart';

class OpenAICompatibleClient {
  const OpenAICompatibleClient({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  Future<String> chat({
    required AiSettings settings,
    required List<Map<String, String>> messages,
    double temperature = 0.2,
  }) async {
    if (!settings.isConfigured) {
      throw const AiClientException('请先填写 API URL、Key 和 Model。');
    }

    final client = _httpClient ?? http.Client();
    final shouldClose = _httpClient == null;
    try {
      final response = await client.post(
        _chatCompletionsUri(settings),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.apiKey.trim()}',
        },
        body: jsonEncode({
          'model': settings.model.trim(),
          'messages': messages,
          'temperature': temperature,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiClientException('AI 请求失败：${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) throw const AiClientException('AI 没有返回内容。');
      final message = choices.first is Map<String, dynamic> ? choices.first['message'] as Map<String, dynamic>? : null;
      final content = message?['content']?.toString() ?? '';
      if (content.trim().isEmpty) throw const AiClientException('AI 返回内容为空。');
      return content;
    } finally {
      if (shouldClose) client.close();
    }
  }

  Future<void> testConnection(AiSettings settings) async {
    final reply = await chat(
      settings: settings,
      messages: const [
        {'role': 'system', 'content': '你是一个连接测试助手。'},
        {'role': 'user', 'content': '请只回复 OK'},
      ],
      temperature: 0,
    );
    if (!reply.toLowerCase().contains('ok')) {
      throw AiClientException('连接成功，但模型回复异常：$reply');
    }
  }

  Future<AiGeneratedPack> generateFromText({
    required AiSettings settings,
    required String sourceText,
    required String subject,
    required String sourceTitle,
    required List<String> questionTypes,
    required int count,
  }) async {
    final prompt = _buildGenerationPrompt(
      sourceText: sourceText,
      subject: subject,
      sourceTitle: sourceTitle,
      questionTypes: questionTypes,
      count: count,
    );
    final raw = await chat(
      settings: settings,
      messages: [
        {
          'role': 'system',
          'content': '你是中考复习题库生成器。你必须遵守内置出题技能，只返回可解析 JSON，不要返回 Markdown。',
        },
        {'role': 'user', 'content': prompt},
      ],
      temperature: 0.25,
    );
    return _parseGeneratedPack(raw, subject: subject, sourceTitle: sourceTitle);
  }

  Future<AiGradingResult> gradeAnswer({
    required AiSettings settings,
    required QuizItem item,
    required String userAnswer,
  }) async {
    final raw = await chat(
      settings: settings,
      messages: [
        {
          'role': 'system',
          'content': '你是严格但简明的中考阅卷老师。优先按题目要求和关键词批改，公式、单位、方程式配平要严谨。只返回 JSON。',
        },
        {
          'role': 'user',
          'content': '''
请批改这道题。宽容同义表达，但关键公式、单位、化学方程式配平、古诗原句必须严格。

题目：${item.question}
标准答案：${item.answer}
参考讲解：${item.explain}
学生答案：$userAnswer

请只返回 JSON：
{"correct":true/false,"score":0到100的整数,"feedback":"一句话说明得失","referenceAnswer":"标准答案"}
''',
        },
      ],
      temperature: 0,
    );
    return _parseGrading(raw, fallbackAnswer: item.answer);
  }

  Uri _chatCompletionsUri(AiSettings settings) {
    final url = settings.normalizedApiUrl;
    if (url.endsWith('/chat/completions')) return Uri.parse(url);
    return Uri.parse('$url/chat/completions');
  }

  String _buildGenerationPrompt({
    required String sourceText,
    required String subject,
    required String sourceTitle,
    required List<String> questionTypes,
    required int count,
  }) {
    final typeText = questionTypes.isEmpty ? '填空题、选择题、判断题、知识点问答' : questionTypes.join('、');
    final skills = skillPromptForSubject(subject);
    return '''
请根据资料生成 ZQuiz 可用的记忆卡和 Quiz。学科：$subject。资料标题：$sourceTitle。

出题类型：$typeText。
数量要求：生成 $count 道 Quiz，必要时生成对应记忆卡。优先中考高频考点。

$skills

通用规则：
1. 只围绕资料和中考高频考法出题，避免偏题和冷知识。
2. 题型字段 questionType 只能使用：cloze、equation、formula、unit、multiple_choice、true_false、knowledge_qa、open_answer、big_question。
3. 选择题必须提供 options，通常为 A-D 四项；answer 用 A/B/C/D，若多选则用如 AC。
4. 判断题 questionType 使用 true_false，options 可为空，answer 只能写“对”或“错”。
5. 填空、公式、方程式可以使用 exact；概念问答、现象分析、实验原因要使用 keyword 并提供 keywords；大题或开放题使用 ai 且 aiGrading 为 true。
6. 所有题都要有 answer；keyword 题必须给 keywords；方程式题 accepts 必须包含下标形式和普通数字形式。
7. Quiz 中不要重复输出资料全文，只保留题干、答案、讲解和必要选项。
8. 只返回 JSON，结构必须如下：
{
  "cards": [
    {
      "subject": "$subject",
      "kind": "知识卡类型",
      "title": "标题",
      "subtitle": "可为空",
      "primary": "核心内容",
      "note": "记忆提示",
      "explain": "讲解",
      "detailTitle": "详情页标题",
      "details": [{"label":"要点","value":"说明"}],
      "unitText": "物理单位解释，可为空",
      "units": [{"symbol":"v","name":"速度","unit":"m/s"}]
    }
  ],
  "quiz": [
    {
      "subject": "$subject",
      "kind": "题型",
      "questionType": "cloze/multiple_choice/true_false/knowledge_qa/equation/formula/unit/open_answer/big_question",
      "question": "题干",
      "options": ["A. 选项一", "B. 选项二"],
      "answer": "标准答案",
      "accepts": ["可接受答案1"],
      "keywords": ["关键词1", "关键词2"],
      "gradingMode": "exact/keyword/ai",
      "title": "来源标题",
      "freq": 1到5,
      "aiGrading": false,
      "explain": "答案讲解"
    }
  ]
}

资料：
$sourceText
''';
  }

  AiGeneratedPack _parseGeneratedPack(String raw, {required String subject, required String sourceTitle}) {
    final json = _extractJson(raw);
    final cards = (json['cards'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => StudyCard.fromJson({
              'subject': subject,
              'title': sourceTitle,
              'detailTitle': sourceTitle,
              ...item,
            }))
        .where((item) => item.primary.trim().isNotEmpty)
        .toList();
    final quiz = (json['quiz'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => QuizItem.fromJson({
              'subject': subject,
              'title': sourceTitle,
              ...item,
            }))
        .where((item) => item.question.trim().isNotEmpty && item.answer.trim().isNotEmpty)
        .toList();
    return AiGeneratedPack(cards: cards, quiz: quiz, rawText: raw);
  }

  AiGradingResult _parseGrading(String raw, {required String fallbackAnswer}) {
    final json = _extractJson(raw);
    return AiGradingResult(
      correct: json['correct'] == true || json['correct']?.toString().toLowerCase() == 'true',
      score: (int.tryParse(json['score']?.toString() ?? '') ?? 0).clamp(0, 100).toInt(),
      feedback: json['feedback']?.toString() ?? '已批改。',
      referenceAnswer: json['referenceAnswer']?.toString() ?? fallbackAnswer,
    );
  }

  Map<String, dynamic> _extractJson(String raw) {
    final trimmed = raw.trim();
    try {
      return jsonDecode(trimmed) as Map<String, dynamic>;
    } catch (_) {
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final inner = trimmed.substring(start, end + 1);
        return jsonDecode(inner) as Map<String, dynamic>;
      }
      throw AiClientException('AI 返回内容不是有效 JSON：$raw');
    }
  }
}

class AiClientException implements Exception {
  const AiClientException(this.message);

  final String message;

  @override
  String toString() => message;
}
