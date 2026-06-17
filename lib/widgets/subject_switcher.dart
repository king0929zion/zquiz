import 'package:flutter/material.dart';

import '../models.dart';

class SubjectSwitcher extends StatelessWidget {
  const SubjectSwitcher({
    super.key,
    required this.subjects,
    required this.value,
    required this.onChanged,
  });

  final List<SubjectInfo> subjects;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: subjects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final subject = subjects[index];
          final selected = subject.id == value;
          return ChoiceChip(
            label: Text(subject.name),
            selected: selected,
            onSelected: (_) => onChanged(subject.id),
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: Colors.black,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99),
              side: const BorderSide(color: Colors.black),
            ),
          );
        },
      ),
    );
  }
}
