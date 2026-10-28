/// Sesión de entrenamiento en curso (se guarda en el dispositivo hasta terminarla).
library;

import 'dart:math' as math;

import '../common/date.dart';
import '../common/numbers.dart';
import 'models.dart';
import 'stats.dart';

/// Serie en edición. kg y reps son texto para no pelear con el teclado ("52,").
class DraftSet {
  const DraftSet({
    required this.key,
    this.type = SetType.normal,
    this.kg = '',
    this.reps = '',
    this.done = false,
    this.targetKg,
    this.targetReps,
  });

  factory DraftSet.fromJson(Map<String, dynamic> j) => DraftSet(
        key: j['key'] as String? ?? newKey(),
        type: setTypeFrom(j['type']),
        kg: j['kg'] as String? ?? '',
        reps: j['reps'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        targetKg: (j['targetKg'] as num?)?.toDouble(),
        targetReps: (j['targetReps'] as num?)?.toDouble(),
      );

  final String key;
  final SetType type;
  final String kg;
  final String reps;
  final bool done;

  /// Valores de la rutina; sugerencia (placeholder) si no hay sesión anterior.
  final double? targetKg;
  final double? targetReps;

  DraftSet copyWith({SetType? type, String? kg, String? reps, bool? done}) => DraftSet(
        key: key,
        type: type ?? this.type,
        kg: kg ?? this.kg,
        reps: reps ?? this.reps,
        done: done ?? this.done,
        targetKg: targetKg,
        targetReps: targetReps,
      );

  Map<String, dynamic> toJson() =>
      {'key': key, 'type': type.name, 'kg': kg, 'reps': reps, 'done': done, 'targetKg': targetKg, 'targetReps': targetReps};
}

class DraftExercise {
  const DraftExercise({required this.key, required this.exerciseId, required this.sets});

  factory DraftExercise.fromJson(Map<String, dynamic> j) => DraftExercise(
        key: j['key'] as String? ?? newKey(),
        exerciseId: j['exerciseId'] as String,
        sets: [for (final s in j['sets'] as List? ?? const []) DraftSet.fromJson((s as Map).cast<String, dynamic>())],
      );

  final String key;
  final String exerciseId;
  final List<DraftSet> sets;

  DraftExercise withSets(List<DraftSet> sets) => DraftExercise(key: key, exerciseId: exerciseId, sets: sets);

  Map<String, dynamic> toJson() => {'key': key, 'exerciseId': exerciseId, 'sets': sets.map((s) => s.toJson()).toList()};
}

class ActiveWorkout {
  const ActiveWorkout({this.routineId, required this.name, required this.startedAt, this.exercises = const []});

  factory ActiveWorkout.fromJson(Map<String, dynamic> j) => ActiveWorkout(
        routineId: j['routineId'] as String?,
        name: j['name'] as String? ?? 'Entrenamiento',
        startedAt: (j['startedAt'] as num).toInt(),
        exercises: [
          for (final e in j['exercises'] as List? ?? const []) DraftExercise.fromJson((e as Map).cast<String, dynamic>()),
        ],
      );

  final String? routineId;
  final String name;
  final int startedAt;
  final List<DraftExercise> exercises;

  ActiveWorkout copyWith({String? name, List<DraftExercise>? exercises}) =>
      ActiveWorkout(routineId: routineId, name: name ?? this.name, startedAt: startedAt, exercises: exercises ?? this.exercises);

  Map<String, dynamic> toJson() =>
      {'routineId': routineId, 'name': name, 'startedAt': startedAt, 'exercises': exercises.map((e) => e.toJson()).toList()};
}

const _defaultSets = 3;
final _random = math.Random();

String newKey() => List.generate(8, (_) => _random.nextInt(36).toRadixString(36)).join();

/// Número escrito por el usuario (acepta coma decimal); null si está vacío o no es válido.
double? parseAmount(String s) {
  final n = parseNum(s);
  return n != null && n >= 0 ? n : null;
}

DraftSet _draftSet(SetType type, [double? targetKg, double? targetReps]) =>
    DraftSet(key: newKey(), type: type, targetKg: targetKg, targetReps: targetReps);

ActiveWorkout emptyWorkout(int now, [String name = 'Entrenamiento libre']) => ActiveWorkout(name: name, startedAt: now);

ActiveWorkout workoutFromRoutine(Routine routine, int now) => ActiveWorkout(
      routineId: routine.id,
      name: routine.name,
      startedAt: now,
      exercises: [
        for (final e in routine.exercises)
          DraftExercise(key: newKey(), exerciseId: e.exerciseId, sets: [for (final s in e.sets) _draftSet(s.type, s.kg, s.reps)]),
      ],
    );

/// Estructura de series al agregar un ejercicio: la de la última vez o 3 series normales.
List<DraftSet> setsForNewExercise(String exerciseId, List<Workout> workouts) {
  final last = lastSetsFor(workouts, exerciseId);
  if (last != null && last.isNotEmpty) return [for (final s in last) _draftSet(s.type)];
  return List.generate(_defaultSets, (_) => _draftSet(SetType.normal));
}

/// Nueva serie al final: copia el tipo y la sugerencia de la última.
List<DraftSet> appendSet(List<DraftSet> sets) {
  final last = sets.lastOrNull;
  final type = last != null && last.type != SetType.warmup ? last.type : SetType.normal;
  return [...sets, _draftSet(type, last?.targetKg, last?.targetReps)];
}

SetType nextSetType(SetType t) => switch (t) {
      SetType.normal => SetType.warmup,
      SetType.warmup => SetType.failure,
      SetType.failure => SetType.normal,
    };

/// Sugerencia para una serie: lo que se hizo la última vez en esa serie o, si no
/// hay registro, lo que dice la rutina (la plantilla se queda atrás al progresar).
({double? kg, double? reps}) suggestion(DraftSet set, StrengthSet? previous) {
  if (previous != null) return (kg: previous.kg, reps: previous.reps);
  return (kg: set.targetKg, reps: set.targetReps);
}

/// Marca o desmarca una serie. Al marcarla, los campos vacíos se completan con la
/// sugerencia. Devuelve null si no hay repeticiones con qué completarla.
DraftSet? toggleDone(DraftSet set, StrengthSet? previous) {
  if (set.done) return set.copyWith(done: false);
  final hint = suggestion(set, previous);
  final kg = set.kg.trim().isNotEmpty ? set.kg : plainEs(hint.kg);
  final reps = set.reps.trim().isNotEmpty ? set.reps : plainEs(hint.reps);
  final r = parseAmount(reps);
  if (r == null || r <= 0) return null;
  return set.copyWith(kg: kg, reps: reps, done: true);
}

/// Anterior de cada serie del ejercicio, según la última sesión con él.
List<StrengthSet?> previousFor(DraftExercise exercise, List<Workout> workouts, int before) {
  final last = lastSetsFor(workouts, exercise.exerciseId, before: before);
  final types = exercise.sets.map((s) => s.type).toList();
  return [for (var i = 0; i < exercise.sets.length; i++) matchPrevious(last, types, i)];
}

int pendingSets(ActiveWorkout w) => w.exercises.fold(0, (n, e) => n + e.sets.where((s) => !s.done).length);

int doneSets(ActiveWorkout w) => w.exercises.fold(0, (n, e) => n + e.sets.where((s) => s.done).length);

/// Volumen de las series marcadas, sin calentamiento.
double activeVolume(ActiveWorkout w) => w.exercises.fold(
      0,
      (sum, e) =>
          sum +
          e.sets
              .where((s) => s.done && s.type != SetType.warmup)
              .fold<double>(0, (v, s) => v + (parseAmount(s.kg) ?? 0) * (parseAmount(s.reps) ?? 0)),
    );

/// Convierte la sesión en curso en lo que se guarda: solo series hechas y ejercicios con alguna.
NewWorkout finishWorkout(ActiveWorkout w, int now, String Function(String exerciseId) nameOf) {
  final exercises = <WorkoutExercise>[];
  for (final e in w.exercises) {
    final sets = [
      for (final s in e.sets.where((s) => s.done)) StrengthSet(type: s.type, kg: parseAmount(s.kg), reps: parseAmount(s.reps)),
    ].where((s) => (s.reps ?? 0) > 0).toList();
    if (sets.isNotEmpty) exercises.add(WorkoutExercise(exerciseId: e.exerciseId, name: nameOf(e.exerciseId), sets: sets));
  }
  return NewWorkout(
    routineId: w.routineId,
    name: w.name,
    date: toDateKey(DateTime.fromMillisecondsSinceEpoch(w.startedAt)),
    startedAt: w.startedAt,
    finishedAt: now,
    exercises: exercises,
  );
}

/// Ejercicios y series de una sesión, para actualizar la rutina con lo que se hizo.
List<RoutineExercise> routineExercisesFrom(Workout w) => [
      for (final e in w.exercises)
        RoutineExercise(exerciseId: e.exerciseId, sets: [for (final s in e.sets) StrengthSet(type: s.type, kg: s.kg, reps: s.reps)]),
    ];
