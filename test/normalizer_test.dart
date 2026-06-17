import 'package:flutter_test/flutter_test.dart';
import 'package:zquiz/core/normalizer.dart';

void main() {
  test('normalizes Chinese punctuation', () {
    expect(answerMatches('水何澹澹 山岛竦峙', ['水何澹澹，山岛竦峙。']), true);
  });

  test('normalizes subscript formula tokens', () {
    expect(answerMatches('2Mg+O2点燃2MgO', ['2Mg + O₂ —点燃→ 2MgO']), true);
  });

  test('matches keyword answers', () {
    expect(
      keywordMatches('为了防止小车下滑太快，方便准确测量时间', ['下滑太快', '准确测量时间']),
      true,
    );
  });

  test('converts chemistry digits to subscripts', () {
    expect(withChemistrySubscripts('Fe3O4'), 'Fe₃O₄');
  });
}
