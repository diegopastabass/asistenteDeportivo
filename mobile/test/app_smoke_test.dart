// Prueba de humo: arranca la app completa con el backend en memoria y recorre
// todas las pantallas. Falla si alguna lanza una excepción o se desborda
// (overflow) en un ancho de iPhone.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:asistente_deportivo/app/app.dart';
import 'package:asistente_deportivo/app/providers.dart';
import 'package:asistente_deportivo/app/router.dart';
import 'package:asistente_deportivo/core/body/energy.dart';
import 'package:asistente_deportivo/core/common/date.dart';
import 'package:asistente_deportivo/core/nutrition/models.dart';
import 'package:asistente_deportivo/core/nutrition/score.dart';
import 'package:asistente_deportivo/core/nutrition/seed.dart';
import 'package:asistente_deportivo/core/strength/models.dart';
import 'package:asistente_deportivo/core/activity/reminders.dart';
import 'package:asistente_deportivo/data/local/local_store.dart';
import 'package:asistente_deportivo/platform/capability.dart';
import 'package:asistente_deportivo/platform/notifications/notification_service.dart';
import 'package:asistente_deportivo/platform/platform_providers.dart';
import 'package:asistente_deportivo/ui/format.dart';
import 'package:asistente_deportivo/data/memory/memory_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registra lo que se programaría y permite simular el toque de un aviso.
class _FakeNotifications implements NotificationService {
  List<PlannedReminder> scheduled = const [];
  final _taps = StreamController<String>.broadcast();

  void tap(String route) => _taps.add(route);

  @override
  Future<CapabilityStatus> status() async => CapabilityStatus.granted;

  @override
  Future<CapabilityStatus> requestPermission() async => CapabilityStatus.granted;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async => scheduled = reminders;

  @override
  Future<String?> launchRoute() async => null;

  @override
  Stream<String> get taps => _taps.stream;
}

Future<ProviderContainer> _boot(WidgetTester tester, {bool signedIn = true, bool withSampleData = true, NotificationService? notifications}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final seed = seedFoodsFromJson(jsonDecode(File('assets/data/foods.seed.json').readAsStringSync()) as Map<String, dynamic>, demoUser.uid);
  final container = ProviderContainer(overrides: [
    backendProvider.overrideWithValue(memoryBackend(seedFoods: seed, lookup: OfflineLookupRepository(), signedIn: signedIn, withSampleData: withSampleData)),
    localStoreProvider.overrideWithValue(LocalStore(prefs)),
    if (notifications != null) notificationServiceProvider.overrideWithValue(notifications),
  ]);
  addTearDown(container.dispose);
  // iPhone 15/16 (390 × 844 pt).
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // El catálogo de ejercicios se lee de los assets (E/S real, fuera del reloj simulado).
  await tester.runAsync(() => container.read(exerciseCatalogProvider.future));
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const AsistenteApp()));
  await _settle(tester);
  return container;
}

/// Avanza el reloj sin esperar a que terminen los cronómetros (que nunca terminan).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _go(WidgetTester tester, ProviderContainer container, String location) async {
  container.read(routerProvider).go(location);
  await _settle(tester);
}

void main() {
  testWidgets('sin sesión muestra el ingreso y entra en modo demostración', (tester) async {
    await _boot(tester, signedIn: false);
    expect(find.text('Entrar en modo demostración'), findsOneWidget);
    await _tap(tester, find.text('Entrar en modo demostración'));
    expect(find.text('PUNTAJE'), findsOneWidget);
  });

  testWidgets('registra la lista de ejemplo y la ve en el diario', (tester) async {
    final container = await _boot(tester);
    expect(find.text('Sin registros este día'), findsOneWidget);

    await _go(tester, container, '/registrar');
    await _tap(tester, find.text('Analizar'));
    expect(find.text('Arroz blanco cocido'), findsOneWidget);
    expect(find.textContaining('4 ok · 0 revisar · 0 faltan'), findsOneWidget);

    await _tap(tester, find.text('Guardar'));
    expect(find.text('PUNTAJE'), findsOneWidget);
    expect(find.text('Arroz blanco cocido'), findsOneWidget);
    expect(find.text('Sin registros este día'), findsNothing);
  });

  testWidgets('recorre nutrición, fuerza, cardio y ajustes', (tester) async {
    final container = await _boot(tester);
    final screens = {
      '/alimentos': 'Arroz blanco cocido',
      '/recetas': 'Aún no tienes recetas',
      '/recetas/nueva': 'Nueva receta',
      '/progreso': 'Registrar peso',
      '/objetivos': 'Objetivos diarios',
      '/fuerza': 'Rutina de pecho',
      '/fuerza/rutinas/demo-pecho': 'Editar rutina',
      '/fuerza/historial': 'Historial',
      '/fuerza/historial/demo-w2': 'Tus avances',
      '/fuerza/progreso': 'Constancia',
      '/fuerza/ejercicios': 'Ejercicios',
      '/fuerza/ejercicios/Barbell_Bench_Press_-_Medium_Grip': 'Press de banca con barra',
      '/cardio': 'Módulo de cardio',
      '/ajustes': 'Integraciones del sistema',
      '/actividad': '12 días seguidos',
      '/perfil': 'Gasto calórico estimado',
      '/notificaciones': 'Racha en riesgo',
      '/fuerza/programas': 'Sugeridos para ti',
    };
    for (final MapEntry(key: location, value: text) in screens.entries) {
      await _go(tester, container, location);
      expect(find.textContaining(text), findsWidgets, reason: location);
    }
  });

  testWidgets('repite el desayuno de ayer con un toque', (tester) async {
    final container = await _boot(tester);
    expect(find.text('Repetir de ayer'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Copiar desayuno'));
    expect(find.text('Avena en hojuelas'), findsOneWidget);
    expect(find.bySemanticsLabel('Copiar desayuno'), findsNothing);
    final today = await tester.runAsync(() => container.read(dayEntriesProvider(todayKey()).future));
    expect(today!.map((e) => e.name), ['Avena en hojuelas', 'Leche semidescremada']);
  });

  testWidgets('el calendario abre el detalle de un día', (tester) async {
    final container = await _boot(tester);
    await _go(tester, container, '/actividad');
    final yesterday = addDays(todayKey(), -1);
    await _tap(tester, find.bySemanticsLabel(RegExp('^${longDate(yesterday)}, con registro')));
    expect(find.text('4 registros'), findsOneWidget);
  });

  testWidgets('el perfil calcula el gasto y aplica los objetivos sugeridos', (tester) async {
    final container = await _boot(tester);
    await container
        .read(backendProvider)
        .profile
        .saveBodyProfile(demoUser.uid, const BodyProfile(heightCm: 178, birthDate: '1990-01-01', sex: Sex.male, activity: ActivityLevel.high));
    await _go(tester, container, '/perfil');
    expect(find.textContaining('Reposo'), findsOneWidget);
    await _tap(tester, find.text('Aplicar a mis objetivos'));
    await _tap(tester, find.text('Aplicar'));
    expect(find.text('Objetivos diarios'), findsOneWidget);
    final goals = container.read(goalsProvider).value!;
    expect(goals.range(MacroKey.kcal), isNot(defaultGoals.range(MacroKey.kcal)));
  });

  testWidgets('la racha suma el día al registrar y celebra el hito', (tester) async {
    final container = await _boot(tester, withSampleData: false);
    // Cuatro días seguidos de entrenamiento antes de hoy.
    final strength = container.read(backendProvider).strength;
    for (var i = 4; i >= 1; i--) {
      final start = fromDateKey(addDays(todayKey(), -i)).add(const Duration(hours: 8)).millisecondsSinceEpoch;
      await strength.saveWorkout(demoUser.uid, NewWorkout(routineId: null, name: 'Libre', date: addDays(todayKey(), -i), startedAt: start, finishedAt: start + 3600000, exercises: const []));
    }
    await _settle(tester);
    expect(find.bySemanticsLabel(RegExp(r'^Racha: 4 días')), findsOneWidget);

    await _go(tester, container, '/registrar');
    await _tap(tester, find.text('Analizar'));
    await _tap(tester, find.text('Guardar'));
    expect(find.text('¡5 días seguidos!'), findsOneWidget);
    await _tap(tester, find.text('¡Vamos!'));
    expect(find.text('¡5 días seguidos!'), findsNothing);
    expect(find.bySemanticsLabel('Racha: 5 días'), findsOneWidget);
  });

  testWidgets('elige un programa sugerido y la pantalla de fuerza dice qué rutina toca', (tester) async {
    final container = await _boot(tester);
    await _go(tester, container, '/fuerza/programas');
    expect(find.text('MEJOR OPCIÓN'), findsOneWidget);
    await _tap(tester, find.text('Usar este programa').first);
    await _tap(tester, find.text('Usar programa'));
    expect(find.text('Tu programa'), findsOneWidget);
    expect(find.text('Cuerpo completo · 3 días'), findsOneWidget);
    expect(find.text('Toca: Cuerpo completo A'), findsOneWidget);
    final plan = container.read(trainingPlanProvider).value!;
    expect((plan.programId, plan.routineIds.length, (plan.weekdays.toList()..sort()).join(',')), ('cuerpo-completo-3', 2, '1,3,5'));

    // La rutina creada lleva el rango de repeticiones.
    await _tap(tester, find.text('Toca: Cuerpo completo A'));
    expect(find.textContaining('Objetivo: 6–8 reps'), findsOneWidget);
  });

  testWidgets('programa los recordatorios y abre la pantalla del aviso tocado', (tester) async {
    final fake = _FakeNotifications();
    final container = await _boot(tester, notifications: fake);
    expect(fake.scheduled, isEmpty);
    container.read(reminderSettingsProvider.notifier).set(ReminderSettings.suggested);
    await _settle(tester);
    expect(fake.scheduled.where((r) => r.kind == ReminderKind.meal), isNotEmpty);
    expect(fake.scheduled.where((r) => r.kind == ReminderKind.streak), isNotEmpty);

    fake.tap('/fuerza');
    await _settle(tester);
    expect(container.read(routerProvider).state.uri.path, '/fuerza');

    // Desactivar todo cancela los avisos.
    container.read(reminderSettingsProvider.notifier).set(const ReminderSettings());
    await _settle(tester);
    expect(fake.scheduled, isEmpty);
  });

  testWidgets('hace un entrenamiento desde la rutina y lo guarda', (tester) async {
    final container = await _boot(tester);
    await _go(tester, container, '/fuerza');
    await _tap(tester, find.byTooltip('Empezar Rutina de pecho'));
    expect(find.text('Terminar'), findsOneWidget);

    // Marca la primera serie: toma los valores de la sesión anterior.
    await _tap(tester, find.bySemanticsLabel('Marcar serie C como hecha').first);
    expect(find.text('1 serie'), findsOneWidget);

    await _tap(tester, find.text('Terminar'));
    await _tap(tester, find.text('Terminar').last); // confirma las series sin marcar
    expect(find.text('¡Entrenamiento terminado!'), findsOneWidget);
    expect(container.read(activeWorkoutProvider), isNull);
  });
}
