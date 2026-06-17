import 'package:flutter/material.dart';

import '../models.dart';
import 'detail_page.dart';

class MemorizePage extends StatefulWidget {
  const MemorizePage({super.key, required this.data, required this.subjectId});

  final ZQuizData data;
  final String subjectId;

  @override
  State<MemorizePage> createState() => _MemorizePageState();
}

class _MemorizePageState extends State<MemorizePage> {
  String _kindFilter = 'all';

  @override
  void didUpdateWidget(covariant MemorizePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId) {
      _kindFilter = 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceCards = widget.data.cardsFor(widget.subjectId);
    final cards = _kindFilter == 'all' ? sourceCards : sourceCards.where((card) => card.kind == _kindFilter).toList();
    final subjects = widget.data.subjects.where((item) => item.id != 'all').toList();
    final kinds = _kinds(sourceCards);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          sliver: SliverToBoxAdapter(
            child: widget.subjectId == 'all'
                ? _SubjectOverview(data: widget.data, subjects: subjects)
                : _SubjectHeader(subject: _subjectName(widget.subjectId), count: sourceCards.length),
          ),
        ),
        if (kinds.length > 1)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final kind = kinds[index];
                  final selected = kind.id == _kindFilter;
                  return InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => setState(() => _kindFilter = kind.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? Colors.black : Colors.white,
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        kind.label,
                        style: TextStyle(color: selected ? Colors.white : Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: kinds.length,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
          sliver: SliverList.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) => _KnowledgeCard(
              card: cards[index],
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailPage(data: widget.data, card: cards[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _subjectName(String id) {
    for (final subject in widget.data.subjects) {
      if (subject.id == id) return subject.name;
    }
    return id;
  }

  List<_KindFilter> _kinds(List<StudyCard> cards) {
    final names = <String>{};
    for (final card in cards) {
      if (card.kind.trim().isNotEmpty) names.add(card.kind);
    }
    final items = [_KindFilter('all', '全部')];
    items.addAll(names.map((kind) => _KindFilter(kind, _kindLabel(kind))).toList()..sort((a, b) => a.label.compareTo(b.label)));
    return items;
  }

  String _kindLabel(String kind) {
    const map = {
      'poetryLine': '诗句',
      'article': '古文',
      'chemReaction': '方程式',
      'chemFormula': '化学式',
      'valence': '化合价',
      'physicsFormula': '公式',
      'physicsExperiment': '实验',
      'physicsConcept': '概念',
    };
    return map[kind] ?? kind;
  }
}

class _SubjectOverview extends StatelessWidget {
  const _SubjectOverview({required this.data, required this.subjects});

  final ZQuizData data;
  final List<SubjectInfo> subjects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('知识库', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.18,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: subjects.map((subject) {
            final count = data.cardsFor(subject.id).length;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(subject.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  Text('$count cards', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({required this.subject, required this.count});

  final String subject;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(subject, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(99)),
          child: Text('$count cards', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ],
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  const _KnowledgeCard({required this.card, required this.onTap});

  final StudyCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final units = card.units.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(card.title.isEmpty ? card.primary : card.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                    if (card.generatedByAi)
                      const Text('AI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  card.primary,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.28, letterSpacing: -0.2),
                ),
                if (card.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(card.note, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
                ],
                if (units.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: units.map((unit) => _UnitPill(unit: unit)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnitPill extends StatelessWidget {
  const _UnitPill({required this.unit});

  final UnitInfo unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(99)),
      child: Text('${unit.symbol} · ${unit.unit}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _KindFilter {
  const _KindFilter(this.id, this.label);
  final String id;
  final String label;
}
