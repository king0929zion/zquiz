# ZQuiz Flutter 测试记录

当前会话环境中没有 `flutter` 和 `dart` 命令，因此无法在容器内真实执行 Flutter 编译、单元测试或打包。

已完成的静态检查：

- `assets/data/zquiz_data.json` 可被 Python 正常解析。
- 默认知识库统计：4 个学科、211 张知识卡、58 篇/首语文内容、271 道 Quiz。
- 检查了卡片 ID 和 Quiz ID：无重复。
- 检查了 Quiz 对应的 `cardId` / `articleId`：均能找到对应内容。
- 检查了选择题：新增选择题均包含 options。
- 检查了关键词题：新增关键词题均包含 keywords。
- 粗略检查了主要 Dart 文件花括号平衡。
- 更新了 `normalizer_test.dart`，覆盖古诗标点容错、化学下标容错、关键词判断和下标生成。

建议在本地执行：

```bash
flutter pub get
flutter test
flutter analyze
flutter run
```

如果缺少平台工程目录：

```bash
flutter create --platforms=android,ios,web .
flutter pub get
flutter run
```
