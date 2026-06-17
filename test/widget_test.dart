import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zquiz/main.dart';
import 'package:zquiz/data_repository.dart';
import 'package:zquiz/user_content_store.dart';
import 'package:zquiz/study_progress.dart';

void main() {
  testWidgets('App renders without error', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final data = await const DataRepository().load();
    final progress = StudyProgress(prefs);
    final userContent = UserContentStore(prefs);
    await tester.pumpWidget(ZQuizApp(data: data, progress: progress, userContent: userContent));
    expect(find.byType(ZQuizApp), findsOneWidget);
  });
}
