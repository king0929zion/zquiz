import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_repository.dart';
import 'models.dart';
import 'pages/ai_page.dart';
import 'pages/memorize_page.dart';
import 'pages/quiz_page.dart';
import 'study_progress.dart';
import 'user_content_store.dart';
import 'widgets/subject_switcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = const DataRepository();
  final data = await repository.load();
  final preferences = await SharedPreferences.getInstance();
  final progress = StudyProgress(preferences);
  final userContent = UserContentStore(preferences);
  runApp(ZQuizApp(data: data, progress: progress, userContent: userContent));
}

class ZQuizApp extends StatelessWidget {
  const ZQuizApp({
    super.key,
    required this.data,
    required this.progress,
    required this.userContent,
  });

  final ZQuizData data;
  final StudyProgress progress;
  final UserContentStore userContent;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZQuiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.light,
          primary: Colors.black,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(letterSpacing: -0.4),
          titleLarge: TextStyle(letterSpacing: -0.25),
          titleMedium: TextStyle(letterSpacing: -0.15),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        dividerTheme: const DividerThemeData(color: Colors.black12),
      ),
      home: ZQuizHome(data: data, progress: progress, userContent: userContent),
    );
  }
}

class ZQuizHome extends StatefulWidget {
  const ZQuizHome({
    super.key,
    required this.data,
    required this.progress,
    required this.userContent,
  });

  final ZQuizData data;
  final StudyProgress progress;
  final UserContentStore userContent;

  @override
  State<ZQuizHome> createState() => _ZQuizHomeState();
}

class _ZQuizHomeState extends State<ZQuizHome> {
  int _tabIndex = 0;
  String _subjectId = 'all';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.userContent,
      builder: (context, _) {
        final data = widget.data.withUserContent(
          extraCards: widget.userContent.generatedCards,
          extraQuiz: widget.userContent.generatedQuiz,
        );
        final page = switch (_tabIndex) {
          0 => MemorizePage(data: data, subjectId: _subjectId),
          1 => QuizPage(
              data: data,
              progress: widget.progress,
              userContent: widget.userContent,
              subjectId: _subjectId,
            ),
          _ => AiPage(data: data, store: widget.userContent, subjectId: _subjectId),
        };

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 56,
            title: const Text('ZQuiz'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Center(
                  child: Text(
                    _tabTitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              SubjectSwitcher(
                subjects: data.subjects,
                value: _subjectId,
                onChanged: (id) => setState(() => _subjectId = id),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              Expanded(child: page),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  _NavButton(
                    label: '知识库',
                    selected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                  _NavButton(
                    label: 'Quiz',
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                  _NavButton(
                    label: 'AI',
                    selected: _tabIndex == 2,
                    onTap: () => setState(() => _tabIndex = 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _tabTitle {
    if (_tabIndex == 0) return 'Knowledge';
    if (_tabIndex == 1) return 'Quiz';
    return 'AI';
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
