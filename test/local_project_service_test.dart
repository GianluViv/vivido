// Round-trip tests for LocalProjectService: a Project saved to disk, reopened,
// and fed back through the existing widgetClassToJsonData()/applyScreenJsonToView()
// parser must reconstruct an identical widget tree. See docs/local-desktop-plan.md Fase 2.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_viz/local/app_localizations.dart';
import 'package:flutter_viz/local_storage/local_project_service.dart';
import 'package:flutter_viz/main.dart';
import 'package:flutter_viz/model/widget_model.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter_viz/widgets/screen_json_parser_class.dart';
import 'package:flutter_viz/widgetsClass/container_class.dart';
import 'package:flutter_viz/widgetsClass/text_class.dart';

void main() {
  late Directory tempDir;
  late LocalProjectService service;

  setUpAll(() async {
    // getWidgetTitle() and other helpers read the global `language`, which is
    // normally populated by main()'s startup sequence — never run in tests.
    language ??= await AppLocalizations().load(const Locale('en'));
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flutterviz_test_');
    service = LocalProjectService()..setAppDataDirectoryForTesting(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('newProject crea project.json + media/ + export/ su disco', () async {
    final project = await service.newProject('DemoApp');

    expect(project.projectFile.existsSync(), isTrue);
    expect(project.mediaDirectory.existsSync(), isTrue);
    expect(project.exportDirectory.existsSync(), isTrue);

    final onDisk = jsonDecode(project.projectFile.readAsStringSync()) as Map<String, dynamic>;
    expect(onDisk['projectName'], 'DemoApp');
    expect(onDisk['formatVersion'], 1);
  });

  test('round-trip: albero widget -> widgetClassToJsonData -> disco -> applyScreenJsonToView identico', () async {
    final project = await service.newProject('DemoApp');

    // Costruiamo una schermata minimale (Container -> Text) come farebbe l'editor.
    final textWidget = WidgetModel(
      id: 'text-1',
      widgetSubType: WidgetTypeText,
      widgetType: WidgetTypeNormal,
      widgetViewModel: TextClass(text: 'Ciao FlutterViz'),
    );
    final rootWidget = WidgetModel(
      id: 'root-1',
      widgetSubType: WidgetTypeContainer,
      widgetType: WidgetTypeContainerLayout,
      widgetViewModel: ContainerClass(),
      subWidgetsList: [],
    );
    rootWidget.subWidgetsList!.add(textWidget);

    appStore.selectedWidgetList.clear();
    appStore.selectedWidgetList.add(rootWidget);
    appStore.appBarClass = null;
    appStore.bottomNavigationBarClass = null;
    appStore.drawerClass = null;
    appStore.rootView = null;

    final screenJson = jsonEncode(await widgetClassToJsonData());

    final screen = await service.addScreen(project, name: 'Home', screenJsonData: screenJson);
    expect(project.screens, hasLength(1));
    expect(screen.id, 1);

    // Riapriamo il progetto da zero (nuova istanza, stesso path su disco).
    final reopened = await service.openProject(project.directory);
    expect(reopened.name, 'DemoApp');
    expect(reopened.screens, hasLength(1));
    expect(reopened.screens.first.screenJsonData, screenJson);

    // Integrazione con il parser esistente: il json ricaricato deve ricostruire
    // un albero di widget identico all'originale.
    appStore.selectedWidgetList.clear();
    await applyScreenJsonToView(reopened.screens.first.screenJsonData);

    expect(appStore.selectedWidgetList, hasLength(1));
    final rebuiltRoot = appStore.selectedWidgetList.first;
    expect(rebuiltRoot.widgetSubType, WidgetTypeContainer);
    expect(rebuiltRoot.subWidgetsList, hasLength(1));
    expect(rebuiltRoot.subWidgetsList!.first!.widgetSubType, WidgetTypeText);
    expect((rebuiltRoot.subWidgetsList!.first!.widgetViewModel as TextClass).text, 'Ciao FlutterViz');
  });

  test('listRecentProjects riflette i progetti creati/aperti, più recenti prima', () async {
    final alpha = await service.newProject('Alpha');
    await Future.delayed(const Duration(milliseconds: 5));
    await service.newProject('Beta');

    var recent = await service.listRecentProjects();
    expect(recent.map((e) => e.name).toList(), ['Beta', 'Alpha']);

    await Future.delayed(const Duration(milliseconds: 5));
    await service.openProject(alpha.directory);

    recent = await service.listRecentProjects();
    expect(recent.first.name, 'Alpha');
  });

  test('CRUD schermate: add/rename/clone/delete persistono su project.json', () async {
    final project = await service.newProject('CrudTest');

    final s1 = await service.addScreen(project, name: 'Screen 1');
    await service.renameScreen(project, s1.id!, 'Screen 1 renamed');
    final clone = await service.cloneScreen(project, s1.id!);

    expect(clone.id, isNot(s1.id));
    expect(project.screens, hasLength(2));

    await service.deleteScreen(project, s1.id!);

    final reopened = await service.openProject(project.directory);
    expect(reopened.screens, hasLength(1));
    expect(reopened.screens.first.name, contains('copy'));
  });

  test('importMedia copia il file in <progetto>/media e assegna un path relativo', () async {
    final project = await service.newProject('MediaTest');
    final sourceFile = File('${tempDir.path}/logo.png')..writeAsBytesSync([1, 2, 3, 4]);

    final relativePath = await service.importMedia(project, sourceFile);
    expect(relativePath, 'media/logo.png');
    expect(File('${project.directory.path}/$relativePath').existsSync(), isTrue);

    final reopened = await service.openProject(project.directory);
    expect(reopened.media, hasLength(1));
    expect(reopened.media.first.path, 'media/logo.png');
  });
}
