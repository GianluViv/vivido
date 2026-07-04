import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_viz/local/language_en.dart';
import 'package:flutter_viz/main.dart';
import 'package:flutter_viz/model/root_screen_json_data.dart';
import 'package:flutter_viz/templates/builtin_templates.dart';
import 'package:flutter_viz/templates/template_builder.dart';
import 'package:flutter_viz/templates/template_theme.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter_viz/widgets/screen_json_parser_class.dart';
import 'package:flutter_viz/widgets/widgets.dart';

void main() {
  // getWidgets() reads the global localization; initialize it for tests.
  setUpAll(() => language = LanguageEn());

  test('built-in templates round-trip through the screen JSON parser', () {
    for (final template in builtinTemplates()) {
      final decoded = json.decode(template.screenJsonData);
      final root = RootScreenJsonData.fromJson(decoded);

      expect(root.widgetsData, isNotNull, reason: template.name);
      expect(root.widgetsData!.id, isNotEmpty, reason: template.name);
      expect(root.widgetsData!.childData, isNotEmpty, reason: '${template.name} has no children');
      expect(root.scaffoldData, isNotNull, reason: template.name);
    }
  });

  test('recolor swaps the brand color everywhere', () {
    final template = builtinTemplates().firstWhere((t) => t.name == 'Login');
    final recolored = recolorScreenJson(
      template.screenJsonData,
      from: kTemplateBaseColor,
      to: const Color(0xFF2E9E5B),
    );

    // Original brand hex must be gone, new one present.
    expect(template.screenJsonData.toLowerCase().contains('5567ff'), isTrue);
    expect(recolored.toLowerCase().contains('5567ff'), isFalse);
    expect(recolored.toLowerCase().contains('2e9e5b'), isTrue);

    // Still valid JSON after recolor.
    final root = RootScreenJsonData.fromJson(json.decode(recolored));
    expect(root.widgetsData, isNotNull);
  });

  testWidgets('templates load into the editor via applyScreenJsonToView', (tester) async {
    language = LanguageEn();
    for (final template in builtinTemplates()) {
      await applyScreenJsonToView(template.screenJsonData);
      expect(appStore.selectedWidgetList, isNotEmpty, reason: template.name);
      expect(appStore.selectedWidgetList[0].subWidgetsList, isNotEmpty, reason: '${template.name} produced an empty root');
    }
  });

  testWidgets('CircularProgressIndicator round-trips (build, reload, code-gen)', (tester) async {
    language = LanguageEn();
    final circular = tNode(WidgetTypeCircularProgressIndicator);
    final screenJson = buildScreenJson(root: tColumn(children: [circular]));

    // Reloads into the editor without throwing.
    await applyScreenJsonToView(screenJson);
    final loaded = appStore.selectedWidgetList[0].subWidgetsList!.first!;
    expect(loaded.widgetSubType, WidgetTypeCircularProgressIndicator);

    // Emits valid Dart source on export.
    final code = getWidgetsClassData(loaded, isCodeAsString: true) as String;
    expect(code.contains('CircularProgressIndicator('), isTrue);
    expect(code.contains('strokeWidth'), isTrue);
  });

  testWidgets('FloatingActionButton round-trips (build, reload, code-gen)', (tester) async {
    language = LanguageEn();
    final fab = tNode(WidgetTypeFAB);
    final screenJson = buildScreenJson(root: tColumn(children: [fab]));

    await applyScreenJsonToView(screenJson);
    final loaded = appStore.selectedWidgetList[0].subWidgetsList!.first!;
    expect(loaded.widgetSubType, WidgetTypeFAB);

    final code = getWidgetsClassData(loaded, isCodeAsString: true) as String;
    expect(code.contains('FloatingActionButton('), isTrue);
    expect(code.contains('onPressed'), isTrue);
  });
}
