import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ai/openai_compatible_client.dart';
import '../core/normalizer.dart';
import '../models.dart';
import '../study_progress.dart';
import '../user_content_store.dart';
import '../widgets/empty_state.dart';
import 'detail_page.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    required this.data,
    required this.progress,
    required this.userContent,
    required this.subjectId,
    this.aiClient = const OpenAICompatibleClient(),
  });

  final ZQuizData data;
  final StudyProgress progress;
  final UserContentStore userContent;
  final String subjectId;
  final OpenAICompatibleClient aiClient;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Set<String> _selectedOptions = <String>{};
  final _random = Random();

  bool _reviewWrong = false;
  QuizItem? _current;
  bool? _isCorrect;
  bool _answerVisible = false;
  bool _submitting = false;
  String _feedback = '';
  String _judgeMode = 'exact';

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_progressChanged);
    _pickNext();
  }

  @override
  void didUpdateWidget(covariant QuizPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId || oldWidget.progress != widget.progress || oldWidget.data != widget.data) {
      oldWidget.progress.removeListener(_progressChanged);
      widget.progress.addListener(_progressChanged);
      _reviewWrong = false;
      _pickNext();
    }
  }

  @override
  void dispose() {
    widget.progress.removeListener(_progressChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _progressChanged() {
    if (!mounted) return;
    setState(() {});
  }

  List<QuizItem> _pool() {
    final all = widget.data.quizFor(widget.subjectId).toList()..shuffle(_random);
    if (_reviewWrong) {
      return all.where((item) => widget.progress.isWrong(item.id)).toList();
    }
    return all.where((item) => !widget.progress.isCompleted(item.id)).toList();
  }

  String _initialJudgeMode(QuizItem item) {
    if (item.prefersAi && widget.userContent.settings.isConfigured) return 'ai';
    if (item.usesKeywords) return 'keyword';
    return 'exact';
  }

  void _pickNext() {
    final pool = _pool();
    final item = pool.isEmpty ? null : pool.first;
    setState(() {
      _controller.clear();
      _selectedOptions.clear();
      _current = item;
      _isCorrect = null;
      _answerVisible = false;
      _submitting = false;
      _feedback = '';
      _judgeMode = item == null ? 'exact' : _initialJudgeMode(item);
    });
    if (item != null && !item.isObjective) {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  String _currentAnswerInput(QuizItem item) {
    if (item.questionType == 'multiple_choice') {
      final list = _selectedOptions.toList()..sort();
      return list.join();
    }
    if (item.questionType == 'true_false') {
      return _selectedOptions.isEmpty ? '' : _selectedOptions.first;
    }
    return _controller.text.trim();
  }

  Future<void> _submit() async {
    final item = _current;
    if (item == null || _answerVisible || _submitting) return;
    final userAnswer = _currentAnswerInput(item);
    if (userAnswer.trim().isEmpty) {
      setState(() => _feedback = '先写下答案，再提交。');
      return;
    }

    final localMode = _judgeMode == 'keyword' ? 'keyword' : item.gradingMode;
    final localCorrect = flexibleMatches(
      input: userAnswer,
      accepts: item.accepts,
      keywords: item.keywords,
      gradingMode: localMode,
    );

    if (_judgeMode != 'ai' && (localCorrect || !item.prefersAi)) {
      await _fallbackGrade(item, localCorrect);
      return;
    }

    if (_judgeMode == 'ai' && widget.userContent.settings.isConfigured) {
      setState(() => _submitting = true);
      try {
        final result = await widget.aiClient.gradeAnswer(
          settings: widget.userContent.settings,
          item: item,
          userAnswer: userAnswer,
        );
        if (result.correct) {
          await widget.progress.markCorrect(item.id);
        } else {
          await widget.progress.markWrong(item.id);
        }
        if (!mounted) return;
        setState(() {
          _isCorrect = result.correct;
          _answerVisible = true;
          _feedback = '${result.score} 分 · ${result.feedback}';
          _submitting = false;
        });
      } catch (error) {
        await _fallbackGrade(item, localCorrect, message: 'AI 判断失败，已改用本地规则。$error');
      }
      return;
    }

    await _fallbackGrade(item, localCorrect, message: item.prefersAi ? '未配置 AI，已改用本地关键词或标准答案判断。' : '');
  }

  Future<void> _fallbackGrade(QuizItem item, bool correct, {String message = ''}) async {
    if (correct) {
      await widget.progress.markCorrect(item.id);
    } else {
      await widget.progress.markWrong(item.id);
    }
    if (!mounted) return;
    setState(() {
      _isCorrect = correct;
      _answerVisible = !correct || item.prefersAi || item.usesKeywords;
      _feedback = message;
      _submitting = false;
    });
    if (correct && !item.prefersAi && !item.usesKeywords) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) _pickNext();
    }
  }

  Future<void> _dontKnow() async {
    final item = _current;
    if (item == null || _submitting) return;
    await widget.progress.markWrong(item.id);
    if (!mounted) return;
    setState(() {
      _isCorrect = false;
      _answerVisible = true;
      _feedback = '';
    });
  }

  Future<void> _resetCompleted() async {
    await widget.progress.clearCompletedFor(widget.subjectId, widget.data.quiz);
    if (!mounted) return;
    setState(() => _reviewWrong = false);
    _pickNext();
  }

  Future<void> _reviewWrongOnly() async {
    setState(() => _reviewWrong = true);
    _pickNext();
  }

  void _openDetail() {
    final item = _current;
    if (item == null) return;
    final card = item.cardId.isEmpty ? null : widget.data.cardById(item.cardId);
    final article = item.articleId.isEmpty ? null : widget.data.articleById(item.articleId);
    if (card == null && article == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuizExplainPage(item: item)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailPage(data: widget.data, card: card, article: article)));
  }

  void _toggleOption(String value, bool multi) {
    if (_answerVisible || _submitting) return;
    setState(() {
      if (multi) {
        if (_selectedOptions.contains(value)) {
          _selectedOptions.remove(value);
        } else {
          _selectedOptions.add(value);
        }
      } else {
        _selectedOptions..clear()..add(value);
      }
      _feedback = '';
    });
  }

  void _insertToken(String token) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final next = text.replaceRange(start, end, token);
    _controller.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: start + token.length));
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.data.quizFor(widget.subjectId);
    final completedCount = all.where((item) => widget.progress.isCompleted(item.id)).length;
    final wrongCount = all.where((item) => widget.progress.isWrong(item.id)).length;

    return AnimatedBuilder(
      animation: widget.progress,
      builder: (context, _) {
        final current = _current;
        if (current == null) {
          return EmptyState(
            title: _reviewWrong ? '没有错题' : '这一组已经完成',
            message: _reviewWrong ? '当前范围没有需要重练的题。' : '考过的题会暂时收起，刷新后会重新进入题池。',
            action: _QuizActions(wrongCount: wrongCount, onReset: _resetCompleted, onWrong: wrongCount == 0 ? null : _reviewWrongOnly),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 104),
          children: [
            _ProgressLine(completed: completedCount, total: all.length, wrong: wrongCount, reviewWrong: _reviewWrong),
            const SizedBox(height: 20),
            _QuizSurface(
              item: current,
              controller: _controller,
              focusNode: _focusNode,
              selectedOptions: _selectedOptions,
              judgeMode: _judgeMode,
              aiAvailable: widget.userContent.settings.isConfigured,
              isCorrect: _isCorrect,
              answerVisible: _answerVisible,
              submitting: _submitting,
              feedback: _feedback,
              onSubmit: _submit,
              onDontKnow: _dontKnow,
              onNext: _pickNext,
              onOpenDetail: _openDetail,
              onToggleOption: _toggleOption,
              onJudgeModeChanged: (mode) => setState(() => _judgeMode = mode),
              onInsertToken: _insertToken,
            ),
            const SizedBox(height: 18),
            _QuizActions(wrongCount: wrongCount, onReset: _resetCompleted, onWrong: wrongCount == 0 ? null : _reviewWrongOnly),
          ],
        );
      },
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.completed, required this.total, required this.wrong, required this.reviewWrong});

  final int completed;
  final int total;
  final int wrong;
  final bool reviewWrong;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : completed / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.scrollText, size: 24),
            const SizedBox(width: 8),
            Text(reviewWrong ? '错题重练' : 'Quiz', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(99)),
              child: Text('$completed/$total', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            if (wrong > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(99)),
                child: Text('错 $wrong', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
          ),
        ),
      ],
    );
  }
}

class _QuizSurface extends StatelessWidget {
  const _QuizSurface({
    required this.item,
    required this.controller,
    required this.focusNode,
    required this.selectedOptions,
    required this.judgeMode,
    required this.aiAvailable,
    required this.isCorrect,
    required this.answerVisible,
    required this.submitting,
    required this.feedback,
    required this.onSubmit,
    required this.onDontKnow,
    required this.onNext,
    required this.onOpenDetail,
    required this.onToggleOption,
    required this.onJudgeModeChanged,
    required this.onInsertToken,
  });

  final QuizItem item;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Set<String> selectedOptions;
  final String judgeMode;
  final bool aiAvailable;
  final bool? isCorrect;
  final bool answerVisible;
  final bool submitting;
  final String feedback;
  final VoidCallback onSubmit;
  final VoidCallback onDontKnow;
  final VoidCallback onNext;
  final VoidCallback onOpenDetail;
  final void Function(String value, bool multi) onToggleOption;
  final ValueChanged<String> onJudgeModeChanged;
  final ValueChanged<String> onInsertToken;

  @override
  Widget build(BuildContext context) {
    final showChemInput = item.subject == 'chemistry' || item.questionType == 'equation';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SmallTag(label: _typeLabel(item.questionType)),
            if (item.kind.trim().isNotEmpty) _SmallTag(label: item.kind),
            if (item.usesKeywords) _SmallTag(label: '关键词'),
            if (item.prefersAi) _SmallTag(label: 'AI可判'),
          ],
        ),
        const SizedBox(height: 14),
        Text(item.question, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, height: 1.45, letterSpacing: -0.3)),
        const SizedBox(height: 18),
        if (item.questionType == 'multiple_choice')
          _ChoiceOptions(item: item, selected: selectedOptions, answerVisible: answerVisible, onTap: onToggleOption)
        else if (item.questionType == 'true_false')
          _TrueFalseOptions(selected: selectedOptions, answerVisible: answerVisible, onTap: onToggleOption)
        else ...[
          if (item.usesKeywords || item.prefersAi)
            _JudgeModeSwitch(value: judgeMode, aiAvailable: aiAvailable, onChanged: answerVisible || submitting ? null : onJudgeModeChanged),
          if (item.usesKeywords || item.prefersAi) const SizedBox(height: 10),
          TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: !answerVisible && !submitting,
            minLines: item.prefersAi ? 3 : 1,
            maxLines: item.prefersAi ? 8 : 4,
            textInputAction: item.prefersAi ? TextInputAction.newline : TextInputAction.done,
            onSubmitted: (_) { if (!item.prefersAi) onSubmit(); },
            decoration: InputDecoration(
              hintText: item.prefersAi ? '写出依据、步骤或结论' : '填写答案',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
            ),
          ),
          if (showChemInput && !answerVisible) ...[
            const SizedBox(height: 10),
            _ChemInputBar(onInsert: onInsertToken),
          ],
        ],
        if (isCorrect != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(isCorrect! ? LucideIcons.checkCircle : LucideIcons.alertTriangle, size: 20, color: isCorrect! ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(isCorrect! ? '正确' : '需要回看', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: isCorrect! ? Colors.green : Colors.red)),
            ],
          ),
        ],
        if (feedback.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(feedback, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
        ],
        if (answerVisible) ...[
          const SizedBox(height: 14),
          _AnswerPanel(item: item),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: submitting ? null : (answerVisible ? onNext : onSubmit),
                style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: Icon(submitting ? LucideIcons.loader : (answerVisible ? LucideIcons.arrowRight : LucideIcons.send), size: 16),
                label: Text(submitting ? '判断中' : (answerVisible ? '下一题' : '提交')),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: submitting ? null : (answerVisible ? onOpenDetail : onDontKnow),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Colors.black), padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18)),
              icon: Icon(answerVisible ? LucideIcons.bookmark : LucideIcons.helpCircle, size: 16),
              label: Text(answerVisible ? '讲解' : '不会'),
            ),
          ],
        ),
      ],
    );
  }

  String _typeLabel(String type) {
    const map = {
      'cloze': '填空',
      'equation': '方程式',
      'formula': '公式',
      'unit': '单位',
      'multiple_choice': '选择',
      'true_false': '判断',
      'knowledge_qa': '问答',
      'open_answer': '简答',
      'big_question': '大题',
    };
    return map[type] ?? type;
  }
}

class _ChoiceOptions extends StatelessWidget {
  const _ChoiceOptions({required this.item, required this.selected, required this.answerVisible, required this.onTap});

  final QuizItem item;
  final Set<String> selected;
  final bool answerVisible;
  final void Function(String value, bool multi) onTap;

  @override
  Widget build(BuildContext context) {
    final multi = normalizeAnswer(item.answer).length > 1;
    final options = item.options.isEmpty ? const ['A', 'B', 'C', 'D'] : item.options;
    return Column(
      children: options.map((option) {
        final value = _optionValue(option);
        final isSelected = selected.contains(value);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: answerVisible ? null : () => onTap(value, multi),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black : Colors.white,
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  if (isSelected) ...[
                    Icon(LucideIcons.check, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: Text(option, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w800, height: 1.35))),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _optionValue(String option) {
    final trimmed = option.trim();
    if (trimmed.isEmpty) return '';
    final first = trimmed.substring(0, 1).toUpperCase();
    if ('ABCDEFGHIJKLMNOPQRSTUVWXYZ'.contains(first)) return first;
    return trimmed;
  }
}

class _TrueFalseOptions extends StatelessWidget {
  const _TrueFalseOptions({required this.selected, required this.answerVisible, required this.onTap});

  final Set<String> selected;
  final bool answerVisible;
  final void Function(String value, bool multi) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['对', '错'].map((value) {
        final isSelected = selected.contains(value);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: value == '对' ? 10 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: answerVisible ? null : () => onTap(value, false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isSelected ? LucideIcons.check : LucideIcons.x, size: 18, color: isSelected ? Colors.white : Colors.black45),
                    const SizedBox(width: 6),
                    Text(value, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _JudgeModeSwitch extends StatelessWidget {
  const _JudgeModeSwitch({required this.value, required this.aiAvailable, required this.onChanged});

  final String value;
  final bool aiAvailable;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final modes = <({String id, String label})>[
      (id: 'keyword', label: '关键词判断'),
      (id: 'ai', label: aiAvailable ? 'AI 判断' : 'AI 未配置'),
    ];
    return Row(
      children: modes.map((mode) {
        final disabled = mode.id == 'ai' && !aiAvailable;
        final selected = value == mode.id;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: mode.id == 'keyword' ? 8 : 0),
            child: OutlinedButton(
              onPressed: disabled || onChanged == null ? null : () => onChanged!(mode.id),
              style: OutlinedButton.styleFrom(
                backgroundColor: selected ? Colors.black : Colors.white,
                foregroundColor: selected ? Colors.white : Colors.black,
                side: BorderSide(color: disabled ? Colors.black26 : Colors.black),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(mode.label),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChemInputBar extends StatelessWidget {
  const _ChemInputBar({required this.onInsert});

  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    const tokens = ['₂', '₃', '₄', '₅', '₆', '↑', '↓', '+', '=', '→', '(', ')'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tokens.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final token = tokens[index];
          return InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => onInsert(token),
            child: Container(
              width: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(99)),
              child: Text(token, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          );
        },
      ),
    );
  }
}

class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({required this.item});

  final QuizItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withAlpha(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.checkCircle, size: 16),
              const SizedBox(width: 6),
              const Text('答案', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.answer, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, height: 1.35)),
          if (item.explain.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(item.explain, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
          ],
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _QuizActions extends StatelessWidget {
  const _QuizActions({required this.wrongCount, required this.onReset, required this.onWrong});

  final int wrongCount;
  final VoidCallback onReset;
  final VoidCallback? onWrong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Colors.black), padding: const EdgeInsets.symmetric(vertical: 13)),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('刷新全部题目'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onWrong,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: BorderSide(color: onWrong == null ? Colors.black26 : Colors.black), padding: const EdgeInsets.symmetric(vertical: 13)),
            icon: const Icon(LucideIcons.alertTriangle, size: 16),
            label: Text('重练错题 $wrongCount'),
          ),
        ),
      ],
    );
  }
}

class QuizExplainPage extends StatelessWidget {
  const QuizExplainPage({super.key, required this.item});

  final QuizItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('讲解')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          Text(item.title.isEmpty ? '题目讲解' : item.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          _ExplainBlock(title: '题目', text: item.question),
          const SizedBox(height: 12),
          _ExplainBlock(title: '答案', text: item.answer),
          if (item.explain.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _ExplainBlock(title: '讲解', text: item.explain),
          ],
        ],
      ),
    );
  }
}

class _ExplainBlock extends StatelessWidget {
  const _ExplainBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(height: 1.65, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
