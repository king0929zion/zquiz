import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

class DataRepository {
  const DataRepository();

  Future<ZQuizData> load() async {
    final source = await rootBundle.loadString('assets/data/zquiz_data.json');
    final json = jsonDecode(source) as Map<String, dynamic>;
    return ZQuizData.fromJson(json);
  }
}
