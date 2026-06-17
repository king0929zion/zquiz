import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data_repository.dart';
import 'models.dart';
import 'ai/openai_compatible_client.dart';
import 'pages/ai_page.dart';
import 'pages/dictation_page.dart';
import 'pages/memorize_page.dart';
import 'pages/quiz_page.dart';
import 'study_progress.dart';
import 'user_content_store.dart';

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
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
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
          1 => QuizPage(data: data, progress: widget.progress, userContent: widget.userContent, subjectId: _subjectId),
          2 => DictationPage(data: data, store: widget.userContent, client: const OpenAICompatibleClient()),
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
          drawer: _buildDrawer(context, data),
          body: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                Scaffold.of(context).openDrawer();
              }
            },
            child: page,
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, ZQuizData data) {
    final subjects = data.subjects.where((s) => s.id != 'all').toList();
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.graduationCap, size: 28),
                  const SizedBox(width: 12),
                  const Text('ZQuiz', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(LucideIcons.bookOpen, size: 16),
                  const SizedBox(width: 8),
                  Text('学科', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[600])),
                ],
              ),
            ),
            ...subjects.map((subject) => _DrawerSubjectTile(
                  subject: subject,
                  selected: _subjectId == subject.id,
                  onTap: () {
                    setState(() => _subjectId = subject.id);
                    Navigator.of(context).pop();
                  },
                )),
            if (_subjectId != 'all')
              _DrawerSubjectTile(
                subject: const SubjectInfo(id: 'all', name: '全部'),
                selected: false,
                icon: LucideIcons.blocks,
                onTap: () {
                  setState(() => _subjectId = 'all');
                  Navigator.of(context).pop();
                },
              ),
            const Spacer(),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: ListTile(
                leading: Icon(LucideIcons.settings, size: 20),
                title: const Text('AI 设置', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                trailing: Icon(LucideIcons.chevronRight, size: 18),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AiPage(data: data, store: widget.userContent, subjectId: _subjectId),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (LucideIcons.book, '知识库'),
      (LucideIcons.scrollText, 'Quiz'),
      (LucideIcons.penTool, '默写'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              border: Border.all(color: Colors.black),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
                final (icon, label) = entry.value;
                final selected = _tabIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tabIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 20, color: selected ? Colors.black : Colors.black45),
                          const SizedBox(height: 2),
                          Text(label, style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.black : Colors.black45,
                          )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  String get _tabTitle {
    if (_tabIndex == 0) return 'Knowledge';
    if (_tabIndex == 1) return 'Quiz';
    if (_tabIndex == 2) return 'Dictation';
    return 'AI';
  }
}

class _DrawerSubjectTile extends StatelessWidget {
  final SubjectInfo subject;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _DrawerSubjectTile({
    required this.subject,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final icons = <String, IconData>{
      'chinese': LucideIcons.bookOpen,
      'chemistry': LucideIcons.flaskConical,
      'physics': LucideIcons.zap,
    };
    final effectiveIcon = icon ?? icons[subject.id] ?? LucideIcons.book;
    return ListTile(
      dense: true,
      leading: Icon(effectiveIcon, size: 20, color: selected ? Colors.black : Colors.black54),
      title: Text(subject.name, style: TextStyle(
        fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
        color: selected ? Colors.black : Colors.black87,
        fontSize: 15,
      )),
      trailing: selected ? Icon(LucideIcons.check, size: 16) : null,
      onTap: onTap,
      selected: selected,
      selectedTileColor: Colors.black.withAlpha(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
