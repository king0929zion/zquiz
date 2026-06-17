import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ai/openai_compatible_client.dart';
import '../models.dart';
import '../user_content_store.dart';

class DictationPage extends StatefulWidget {
  const DictationPage({
    super.key,
    required this.data,
    required this.store,
    this.client = const OpenAICompatibleClient(),
  });

  final ZQuizData data;
  final UserContentStore store;
  final OpenAICompatibleClient client;

  @override
  State<DictationPage> createState() => _DictationPageState();
}

class _DictationPageState extends State<DictationPage> {
  int _count = 5;
  int _pageIndex = 0;
  final List<_DictationResult> _results = [];
  bool _processing = false;

  List<QuizItem> get _dictationPool {
    return widget.data
        .quizFor('chinese')
        .where((q) => q.questionType == 'cloze' || q.questionType == 'knowledge_qa')
        .toList();
  }

  List<QuizItem> get _currentBatch {
    final pool = _dictationPool;
    if (pool.isEmpty) return [];
    final start = (_pageIndex * _count) % pool.length;
    final end = (start + _count).clamp(0, pool.length);
    if (end <= start) return pool.sublist(start);
    return pool.sublist(start, end);
  }

  void _prevPage() {
    if (_pageIndex > 0) setState(() => _pageIndex--);
  }

  void _nextPage() {
    final pool = _dictationPool;
    if ((_pageIndex + 1) * _count < pool.length) {
      setState(() => _pageIndex++);
    }
  }

  Future<void> _uploadAndGrade() async {
    if (!widget.store.settings.isConfigured) {
      _showSnack('请先在侧边栏底部设置 AI API');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _processing = true);

    try {
      final batch = _currentBatch;
      _results.clear();
      for (final item in batch) {
        final userAnswer = await _ocrOrManual(item, result.files.first);
        if (userAnswer == null) continue;
        try {
          final grade = await widget.client.gradeAnswer(
            settings: widget.store.settings,
            item: item,
            userAnswer: userAnswer,
          );
          _results.add(_DictationResult(item: item, userAnswer: userAnswer, grade: grade));
        } catch (_) {
          _results.add(_DictationResult(item: item, userAnswer: userAnswer, grade: null));
        }
      }
    } catch (_) {
      _showSnack('处理失败，请重试');
    }
    if (!mounted) return;
    setState(() => _processing = false);
  }

  Future<String?> _ocrOrManual(QuizItem item, PlatformFile file) async {
    return '';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final batch = _currentBatch;
    final pool = _dictationPool;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
      children: [
        Row(
          children: [
            Icon(LucideIcons.penTool, size: 24),
            const SizedBox(width: 8),
            Text('语文默写', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(99)),
              child: Text('${batch.length} 题', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _CountChip(label: '5 题', selected: _count == 5, onTap: () => setState(() { _count = 5; _pageIndex = 0; _results.clear(); })),
            const SizedBox(width: 8),
            _CountChip(label: '10 题', selected: _count == 10, onTap: () => setState(() { _count = 10; _pageIndex = 0; _results.clear(); })),
            const Spacer(),
            if (pool.isNotEmpty)
              Text('${_pageIndex + 1}/${((pool.length - 1) ~/ _count) + 1}页', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 16),
        ...batch.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final result = _results.length > index ? _results[index] : null;
          return _DictationItemTile(index: _pageIndex * _count + index + 1, item: item, result: result);
        }),
        const SizedBox(height: 20),
        Row(
          children: [
            if (_pageIndex > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _prevPage,
                  icon: const Icon(LucideIcons.chevronLeft, size: 16),
                  label: const Text('上一页'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Colors.black), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            if (_pageIndex > 0) const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _processing ? null : _uploadAndGrade,
                icon: Icon(_processing ? LucideIcons.loader : LucideIcons.camera, size: 16),
                label: Text(_processing ? '处理中...' : '拍照上传批改'),
                style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            if ((_pageIndex + 1) * _count < pool.length) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _nextPage,
                  icon: const Icon(LucideIcons.chevronRight, size: 16),
                  label: const Text('下一页'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Colors.black), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ],
        ),
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.barChart3, size: 18),
                    const SizedBox(width: 8),
                    Text('批改结果', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                ..._results.map((r) {
                  final correct = r.grade?.correct ?? false;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(correct ? LucideIcons.checkCircle : LucideIcons.xCircle, size: 16, color: correct ? Colors.green : Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(r.item.question, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        Text('${r.grade?.score ?? 0}分', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: correct ? Colors.green : Colors.red)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CountChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        )),
      ),
    );
  }
}

class _DictationItemTile extends StatelessWidget {
  final int index;
  final QuizItem item;
  final _DictationResult? result;

  const _DictationItemTile({required this.index, required this.item, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(18),
        color: result != null ? (result!.grade?.correct == true ? Colors.green.withAlpha(12) : Colors.red.withAlpha(12)) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26, height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                child: Text('$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item.question, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35))),
              if (result != null)
                Icon(result!.grade?.correct == true ? LucideIcons.checkCircle : LucideIcons.xCircle,
                    size: 18, color: result!.grade?.correct == true ? Colors.green : Colors.red),
            ],
          ),
          if (result != null && result!.userAnswer.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('你的答案：${result!.userAnswer}', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

class _DictationResult {
  final QuizItem item;
  final String userAnswer;
  final AiGradingResult? grade;
  _DictationResult({required this.item, required this.userAnswer, required this.grade});
}
