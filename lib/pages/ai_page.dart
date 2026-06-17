import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../ai/openai_compatible_client.dart';
import '../ai/prompt_skills.dart';
import '../models.dart';
import '../user_content_store.dart';

class AiPage extends StatefulWidget {
  const AiPage({
    super.key,
    required this.data,
    required this.store,
    required this.subjectId,
    this.client = const OpenAICompatibleClient(),
  });

  final ZQuizData data;
  final UserContentStore store;
  final String subjectId;
  final OpenAICompatibleClient client;

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  late final TextEditingController _apiUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  final TextEditingController _materialTitleController = TextEditingController();
  final TextEditingController _materialTextController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: '8');

  String _materialSubject = 'chinese';
  String _selectedSourceId = 'default';
  final Set<String> _questionTypes = {'填空题', '选择题', '判断题', '知识点问答'};
  bool _busy = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    final settings = widget.store.settings;
    _apiUrlController = TextEditingController(text: settings.apiUrl);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _modelController = TextEditingController(text: settings.model);
    _materialSubject = _usableSubject(widget.subjectId);
  }

  @override
  void didUpdateWidget(covariant AiPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId && _selectedSourceId == 'default') {
      _materialSubject = _usableSubject(widget.subjectId);
    }
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _materialTitleController.dispose();
    _materialTextController.dispose();
    _countController.dispose();
    super.dispose();
  }

  String _usableSubject(String id) => id == 'all' ? 'chinese' : id;

  List<SubjectInfo> get _subjects => widget.data.subjects.where((item) => item.id != 'all').toList();

  Future<void> _saveSettings() async {
    await widget.store.saveSettings(
      AiSettings(
        apiUrl: _apiUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
      ),
    );
    _show('AI 设置已保存。');
  }

  Future<void> _testConnection() async {
    await _saveSettings();
    await _runBusy(() async {
      await widget.client.testConnection(widget.store.settings);
      _show('连接测试通过。');
    });
  }

  Future<void> _pickTextFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'json', 'csv', 'log'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _show('没有读取到文件内容。');
      return;
    }
    _materialTitleController.text = file.name;
    _materialTextController.text = utf8.decode(bytes, allowMalformed: true);
    _show('已导入文本，可以保存为资料。');
  }

  Future<void> _saveMaterial() async {
    final text = _materialTextController.text.trim();
    if (text.isEmpty) {
      _show('请先粘贴或导入资料。');
      return;
    }
    final material = await widget.store.addMaterial(
      subject: _materialSubject,
      title: _materialTitleController.text,
      text: text,
    );
    setState(() {
      _selectedSourceId = material.id;
      _materialTitleController.clear();
      _materialTextController.clear();
    });
    _show('资料已保存，可用于 AI 出题。');
  }

  Future<void> _generate() async {
    await _saveSettings();
    final source = _sourceText();
    if (source.text.trim().isEmpty) {
      _show('当前没有可用于出题的资料。');
      return;
    }
    final parsedCount = int.tryParse(_countController.text.trim()) ?? 8;
    final count = parsedCount.clamp(1, 30).toInt();
    await _runBusy(() async {
      final pack = await widget.client.generateFromText(
        settings: widget.store.settings,
        sourceText: source.text,
        subject: source.subject,
        sourceTitle: source.title,
        questionTypes: _questionTypes.toList(),
        count: count,
      );
      await widget.store.addGeneratedPack(pack, sourceId: source.id);
      _show('已生成 ${pack.cards.length} 张卡片、${pack.quiz.length} 道题。');
    });
  }

  ({String id, String subject, String title, String text}) _sourceText() {
    if (_selectedSourceId == 'default') {
      final subject = _usableSubject(widget.subjectId);
      return (
        id: 'default_$subject',
        subject: subject,
        title: '默认知识库',
        text: _defaultKnowledgeText(subject),
      );
    }
    final material = widget.store.materials.firstWhere(
      (item) => item.id == _selectedSourceId,
      orElse: () => ImportedMaterial(
        id: 'none',
        subject: 'chinese',
        title: '空资料',
        text: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    return (id: material.id, subject: material.subject, title: material.title, text: material.text);
  }

  String _defaultKnowledgeText(String subject) {
    final cards = widget.data.cardsFor(subject).take(80).map((card) {
      final details = card.details.map((item) => '${item.label}: ${item.value}').join('；');
      final units = card.units.map((item) => '${item.symbol}: ${item.name} ${item.unit}').join('；');
      return '【${card.title}】${card.primary}\n提示：${card.note}\n讲解：${card.explain}\n要点：$details\n单位：${card.unitText} $units';
    }).join('\n\n');

    final articles = widget.data.articles
        .where((item) => item.subject == subject)
        .take(30)
        .map((item) => '【${item.title}】${item.text.join(' ')}\n重点：${item.keyPoints.map((point) => '${point.text}(${point.cue})').join('；')}')
        .join('\n\n');
    return [cards, articles].where((item) => item.trim().isNotEmpty).join('\n\n');
  }

  Future<void> _runBusy(Future<void> Function() job) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      await job();
    } catch (error) {
      _show(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 106),
          children: [
            _Panel(
              title: 'AI 设置',
              child: Column(
                children: [
                  _Input(controller: _apiUrlController, label: 'API URL', hint: 'https://api.openai.com/v1'),
                  const SizedBox(height: 10),
                  _Input(controller: _apiKeyController, label: 'API Key', hint: 'sk-...', obscure: true),
                  const SizedBox(height: 10),
                  _Input(controller: _modelController, label: 'Model', hint: 'gpt-4o-mini'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _BlackButton(label: '保存', onTap: _busy ? null : _saveSettings)),
                      const SizedBox(width: 10),
                      Expanded(child: _OutlineButton(label: '测试连接', onTap: _busy ? null : _testConnection)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Key 只保存在本机 SharedPreferences。正式发布建议换成安全存储。', style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: '导入资料',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _materialSubject,
                    decoration: const InputDecoration(labelText: '学科', border: OutlineInputBorder()),
                    items: _subjects.map((subject) => DropdownMenuItem(value: subject.id, child: Text(subject.name))).toList(),
                    onChanged: (value) => setState(() => _materialSubject = value ?? _materialSubject),
                  ),
                  const SizedBox(height: 10),
                  _Input(controller: _materialTitleController, label: '资料标题', hint: '例如：酸碱盐专题'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _materialTextController,
                    minLines: 5,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: '资料内容',
                      hintText: '粘贴讲义、笔记、错题或公式表文本',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _OutlineButton(label: '导入文件', onTap: _busy ? null : _pickTextFile)),
                      const SizedBox(width: 10),
                      Expanded(child: _BlackButton(label: '保存资料', onTap: _busy ? null : _saveMaterial)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'AI 出题',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _Metric(label: '知识卡', value: widget.data.cardsFor(_usableSubject(widget.subjectId)).length.toString())),
                      const SizedBox(width: 10),
                      Expanded(child: _Metric(label: '题目', value: widget.data.quizFor(_usableSubject(widget.subjectId)).length.toString())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedSourceId,
                    decoration: const InputDecoration(labelText: '资料来源', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: 'default', child: Text('默认知识库')),
                      ...widget.store.materials.map((item) => DropdownMenuItem(value: item.id, child: Text(item.title))),
                    ],
                    onChanged: (value) => setState(() => _selectedSourceId = value ?? 'default'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['选择题', '填空题', '判断题', '公式/方程式', '单位解释', '知识点问答', '简答', '大题'].map((type) {
                      final selected = _questionTypes.contains(type);
                      return ChoiceChip(
                        label: Text(type),
                        selected: selected,
                        selectedColor: Colors.black,
                        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.w700),
                        onSelected: (_) {
                          setState(() {
                            if (selected) {
                              _questionTypes.remove(type);
                            } else {
                              _questionTypes.add(type);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  _Input(controller: _countController, label: '题目数量', hint: '8', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _BlackButton(label: _busy ? '处理中' : '生成卡片和题目', onTap: _busy ? null : _generate),
                  if (_message.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),
            _Panel(
              title: '出题 Skills',
              child: _SkillPreview(text: skillPromptForSubject(_usableSubject(widget.subjectId))),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: '本地资料',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已导入 ${widget.store.materials.length} 份资料，AI 生成 ${widget.store.generatedCards.length} 张卡片、${widget.store.generatedQuiz.length} 道题。'),
                  const SizedBox(height: 12),
                  ...widget.store.materials.take(8).map((item) => _MaterialTile(
                        material: item,
                        onDelete: () => widget.store.deleteMaterial(item.id),
                      )),
                  if (widget.store.generatedCards.isNotEmpty || widget.store.generatedQuiz.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _OutlineButton(label: '清空 AI 生成内容', onTap: _busy ? null : () => widget.store.clearGenerated()),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label, required this.hint, this.obscure = false, this.keyboardType});

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _BlackButton extends StatelessWidget {
  const _BlackButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: BorderSide(color: onTap == null ? Colors.black26 : Colors.black),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.material, required this.onDelete});

  final ImportedMaterial material;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text('${material.subject} · ${material.text.length} 字', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: onDelete, child: const Text('删除')),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SkillPreview extends StatelessWidget {
  const _SkillPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final compact = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(8)
        .join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('会随资料一起发给 AI，用来约束题型、答案、关键词和批改标准。', style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(16)),
          child: Text(compact, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.55, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
