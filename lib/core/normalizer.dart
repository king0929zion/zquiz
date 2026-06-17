String normalizeAnswer(String input) {
  var value = input.trim().toLowerCase();

  const subscripts = {
    '₀': '0',
    '₁': '1',
    '₂': '2',
    '₃': '3',
    '₄': '4',
    '₅': '5',
    '₆': '6',
    '₇': '7',
    '₈': '8',
    '₉': '9',
    '⁰': '0',
    '¹': '1',
    '²': '2',
    '³': '3',
    '⁴': '4',
    '⁵': '5',
    '⁶': '6',
    '⁷': '7',
    '⁸': '8',
    '⁹': '9',
    '⁺': '+',
    '⁻': '-',
  };

  for (final entry in subscripts.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }

  value = value
      .replaceAll('——', '=')
      .replaceAll('—', '=')
      .replaceAll('→', '=')
      .replaceAll('⇌', '=')
      .replaceAll('＋', '+')
      .replaceAll('－', '-')
      .replaceAll('＝', '=')
      .replaceAll('×', 'x')
      .replaceAll('·', '')
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('，', ',')
      .replaceAll('。', '.')
      .replaceAll('；', ';')
      .replaceAll('：', ':')
      .replaceAll('“', '')
      .replaceAll('”', '')
      .replaceAll('‘', '')
      .replaceAll('’', '');

  return value.replaceAll(RegExp(r"""[\s,.;:、，。；："'`!！?？\[\]【】{}]"""), '');
}

String normalizeForKeywords(String input) {
  return normalizeAnswer(input).replaceAll(RegExp(r'[-_=/\\]'), '');
}

bool answerMatches(String input, List<String> accepts) {
  final normalizedInput = normalizeAnswer(input);
  if (normalizedInput.isEmpty) return false;
  return accepts.any((answer) => normalizeAnswer(answer) == normalizedInput);
}

bool keywordMatches(String input, List<String> keywords, {double minRatio = 1.0}) {
  final normalizedInput = normalizeForKeywords(input);
  if (normalizedInput.isEmpty || keywords.isEmpty) return false;
  final normalizedKeywords = keywords
      .map(normalizeForKeywords)
      .where((item) => item.trim().isNotEmpty)
      .toList();
  if (normalizedKeywords.isEmpty) return false;
  final hit = normalizedKeywords.where(normalizedInput.contains).length;
  return hit / normalizedKeywords.length >= minRatio;
}

bool flexibleMatches({
  required String input,
  required List<String> accepts,
  List<String> keywords = const [],
  String gradingMode = 'exact',
}) {
  if (answerMatches(input, accepts)) return true;
  if (gradingMode == 'keyword' || keywords.isNotEmpty) {
    return keywordMatches(input, keywords);
  }
  return false;
}

String withChemistrySubscripts(String input) {
  const digits = {
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
  };
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(digits[char] ?? char);
  }
  return buffer.toString();
}
