import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models.dart';

class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.data,
    this.card,
    this.article,
  });

  final ZQuizData data;
  final StudyCard? card;
  final Article? article;

  @override
  Widget build(BuildContext context) {
    final resolvedArticle = article ?? _articleFromCard();
    final title = card?.detailTitle.isNotEmpty == true
        ? card!.detailTitle
        : resolvedArticle?.title ?? '讲解';
    final subtitle = card?.subtitle.isNotEmpty == true ? card!.subtitle : resolvedArticle?.subtitle ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (card != null) ...[
            const SizedBox(height: 24),
            _Section(title: '记忆卡', children: [
              _PrimaryBlock(text: card!.primary),
              if (card!.note.trim().isNotEmpty) _BodyText(card!.note),
              if (card!.explain.trim().isNotEmpty) _BodyText(card!.explain),
            ]),
          ],
          if (card?.details.isNotEmpty == true) ...[
            const SizedBox(height: 18),
            _Section(
              title: '要点',
              children: card!.details.map((item) => _DetailRow(label: item.label, value: item.value)).toList(),
            ),
          ],
          if (card?.units.isNotEmpty == true) ...[
            const SizedBox(height: 18),
            _Section(
              title: '单位解释',
              children: card!.units
                  .map((unit) => _DetailRow(label: unit.symbol, value: '${unit.name} · ${unit.unit}'))
                  .toList(),
            ),
          ] else if (card?.unitText.trim().isNotEmpty == true) ...[
            const SizedBox(height: 18),
            _Section(title: '单位解释', children: [_BodyText(card!.unitText)]),
          ],
          if (resolvedArticle != null) ...[
            const SizedBox(height: 18),
            _Section(
              title: '全文',
              children: [
                Text(
                  resolvedArticle.text.join('\n'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.9, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Section(
              title: '重点',
              children: resolvedArticle.keyPoints
                  .map((point) => _DetailRow(label: point.text, value: point.cue))
                  .toList(),
            ),
            if (resolvedArticle.explain.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              _Section(title: '讲解', children: [_BodyText(resolvedArticle.explain)]),
            ],
          ],
        ],
      ),
    );
  }

  Article? _articleFromCard() {
    final id = card?.articleId ?? '';
    if (id.isEmpty) return null;
    return data.articleById(id);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(22),
      ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.fileText, size: 16),
                  const SizedBox(width: 6),
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _PrimaryBlock extends StatelessWidget {
  const _PrimaryBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.35),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (value.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55)),
          ],
        ],
      ),
    );
  }
}
