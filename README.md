# ZQuiz Flutter

ZQuiz 是一个黑白极简风格的多学科背记与 Quiz 应用。当前版本面向语文古诗文、中考化学、中考物理，同时支持 OpenAI-compatible API 的本地 AI 出题与 AI 批改。

## 主要功能

- 多学科知识库：语文、化学、物理可独立筛选，也可以查看全部。
- 知识卡：支持古诗文、化学式、化学方程式、化合价、物理公式、物理实验探究和知识点问答。
- Quiz：支持选择题、填空题、判断题、方程式题、公式题、单位题、知识点问答、简答题和综合大题。
- 本地练习记录：已考题暂时不再出现；支持刷新全部题目和重练错题。
- 两种答案判断：本地精确匹配/关键词判断，以及 AI 判断。
- 化学快速输入：Quiz 输入区内置 ₂、₃、₄、₅、₆、↑、↓、+、=、→ 等符号。
- 物理单位解释：公式卡展示公式、符号含义、单位和易错点。
- AI 模块：支持自定义 OpenAI 格式 API URL、API Key、Model；支持导入资料并基于资料生成知识卡与题目。
- 出题 Skills：内置语文、化学、物理出题规则，会随默认知识库或导入资料一起提供给 AI。

## AI API

API URL 可填写：

```text
https://api.openai.com/v1
```

也可以填写完整的兼容端点：

```text
https://example.com/v1/chat/completions
```

Key 当前保存在本机 SharedPreferences。若要正式发布，请改用 `flutter_secure_storage`。

## 本地运行

```bash
flutter pub get
flutter test
flutter analyze
flutter run
```

如果项目没有 Android / iOS / Web 平台目录，可以在项目根目录执行：

```bash
flutter create --platforms=android,ios,web .
flutter pub get
flutter run
```

## 数据文件

默认知识库位于：

```text
assets/data/zquiz_data.json
```

新增默认题库时建议沿用以下字段：

- `questionType`: `cloze` / `equation` / `formula` / `unit` / `multiple_choice` / `true_false` / `knowledge_qa` / `open_answer` / `big_question`
- `gradingMode`: `exact` / `keyword` / `ai`
- `options`: 选择题选项
- `keywords`: 关键词判断所需关键词
- `accepts`: 可接受答案，化学式建议同时写下标形式和普通数字形式

## 本轮更新

- 顶部不再固定显示旧的“古诗文速背”语义，只保留 ZQuiz 与当前模块。
- 知识库入口重构为多学科卡片和分类筛选。
- Quiz 页面去掉厚重题框，题干直接呈现，答题区域更轻。
- 新增选择题、判断题、关键词判断、AI 判断切换。
- 化学输入区支持下标和方程式常用符号。
- 物理加入实验探究技能与题型规则，默认题库新增实验探究、选择、判断、知识点问答和综合应用题。
- AI 生成提示词加入出题 Skills，约束 AI 按中考考法生成题目与标准答案。
