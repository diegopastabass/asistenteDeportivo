// Prueba de humo: arranca la app completa con el backend en memoria y recorre
// todas las pantallas. Falla si alguna lanza una excepción o se desborda
// (overflow) en un ancho de iPhone.
import 'dart:convert';
import 'dart:io';

import 'package:asistente_deportivo/app/app.dart';
import 'package:asistente_deportivo/app/providers.dart';
import 'package:asistente_deportivo/app/router.dart';
import 'package:asistente_deportivo/core/nutrition/seed.dart';
import 'package:asistente_deportivo/data/local/local_store.dart';
import 'package:asistente_deportivo/data/memory/memory_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _boot(WidgetTester tester, {bool signedIn = true}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final seed = seedFoodsFromJson(jsonDecode(File('assets/data/foods.seed.json').readAsStringSync()) as Map<String, dynamic>, demoUser.uid);
  final container = ProviderContainer(overrides: [
    backendProvider.overrideWithValue(memoryBackend(seedFoods: seed, lookup: OfflineLookupRepository(), signedIn: signedIn)),
    localStoreProvider.overrideWithValue(LocalStore(prefs)),
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
    };
    for (final MapEntry(key: location, value: text) in screens.entries) {
      await _go(tester, container, location);
      expect(find.textContaining(text), findsWidgets, reason: location);
    }
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
