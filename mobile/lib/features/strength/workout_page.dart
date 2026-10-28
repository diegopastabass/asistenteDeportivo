import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/strength/session.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';
import 'active_workout_pill.dart';
import 'exercise_block.dart';
import 'exercise_widgets.dart';

/// Sesión en curso: marcar series, agregar ejercicios y terminar.
class WorkoutPage extends ConsumerStatefulWidget {
  const WorkoutPage({super.key});

  @override
  ConsumerState<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends ConsumerState<WorkoutPage> {
  late final TextEditingController _name = TextEditingController(text: ref.read(activeWorkoutProvider)?.name ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  ActiveWorkoutController get _ctrl => ref.read(activeWorkoutProvider.notifier);

  void _updateExercise(String key, DraftExercise Function(DraftExercise) fn) =>
      _ctrl.update((w) => w.copyWith(exercises: [for (final e in w.exercises) e.key == key ? fn(e) : e]));

  Future<void> _finish(ActiveWorkout active, StrengthData data) async {
    if (doneSets(active) == 0) {
      showToast(context, 'Marca al menos una serie como hecha (✓)', error: true);
      return;
    }
    final pending = pendingSets(active);
    if (pending > 0 &&
        !await confirm(context, 'Hay $pending ${pending == 1 ? 'serie sin marcar: no se guardará' : 'series sin marcar: no se guardarán'}. ¿Terminar igual?',
            accept: 'Terminar')) {
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref.read(strengthActionsProvider).saveWorkout(finishWorkout(active, DateTime.now().millisecondsSinceEpoch, data.nameOf));
      if (!mounted) return;
      _ctrl.set(null);
      context.pushReplacement('/fuerza/historial/$id?nuevo=1');
    } on Object catch (e) {
      if (!mounted) return;
      showToast(context, errorMessage(e), error: true);
      setState(() => _saving = false);
    }
  }

  Future<void> _discard() async {
    if (!await confirm(context, '¿Descartar este entrenamiento? Se perderán las series registradas.', accept: 'Descartar', destructive: true)) return;
    if (!mounted) return;
    _ctrl.set(null);
    context.go('/fuerza');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = ref.watch(activeWorkoutProvider);
    if (active == null) {
      return PageBody(children: [
        const AppCard(child: EmptyState(icon: Icons.fitness_center, title: 'No hay un entrenamiento en curso')),
        FilledButton(onPressed: () => context.go('/fuerza'), child: const Text('Volver')),
      ]);
    }

    return AsyncView(ref.watch(strengthDataProvider), builder: (data) {
      final volume = activeVolume(active);
      final done = doneSets(active);
      return PageBody(gap: 12, bottomPadding: 48, children: [
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.fgStrong),
                  decoration: const InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, isDense: true),
                  onChanged: (v) => _ctrl.update((w) => w.copyWith(name: v)),
                ),
              ),
              IconButton(tooltip: 'Descartar entrenamiento', onPressed: _discard, icon: Icon(Icons.delete_outline, color: c.danger)),
              FilledButton.icon(onPressed: _saving ? null : () => _finish(active, data), icon: const Icon(Icons.check), label: const Text('Terminar')),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.timer_outlined, size: 15, color: c.primary),
              const SizedBox(width: 4),
              ElapsedText(active.startedAt, style: TextStyle(fontSize: 12, color: c.muted)),
              const SizedBox(width: 16),
              Tooltip(
                message: 'Volumen de las series hechas (sin calentamiento)',
                child: Row(children: [
                  Icon(Icons.scale_outlined, size: 15, color: c.primary),
                  const SizedBox(width: 4),
                  Text(formatVolume(volume), style: TextStyle(fontSize: 12, color: c.muted, fontFeatures: tabular)),
                ]),
              ),
              const SizedBox(width: 16),
              Icon(Icons.check, size: 15, color: c.primary),
              const SizedBox(width: 4),
              Text('$done ${done == 1 ? 'serie' : 'series'}', style: TextStyle(fontSize: 12, color: c.muted)),
            ]),
          ]),
        ),
        if (active.exercises.isEmpty)
          const AppCard(
            child: EmptyState(icon: Icons.fitness_center, title: 'Agrega tu primer ejercicio', message: 'Busca en el catálogo de más de 800 ejercicios o crea uno propio.'),
          ),
        for (var i = 0; i < active.exercises.length; i++)
          () {
            final ex = active.exercises[i];
            final prev = previousFor(ex, data.workouts, active.startedAt);
            return ExerciseBlock(
              key: ValueKey(ex.key),
              index: i,
              total: active.exercises.length,
              exercise: data.exercise(ex.exerciseId),
              name: data.nameOf(ex.exerciseId),
              previous: prev,
              rows: [
                for (var j = 0; j < ex.sets.length; j++)
                  () {
                    final s = ex.sets[j];
                    final hint = suggestion(s, prev[j]);
                    return SetRow(key: s.key, type: s.type, kg: s.kg, reps: s.reps, done: s.done, hintKg: hint.kg, hintReps: hint.reps);
                  }(),
              ],
              onChange: (j, p) => _updateExercise(ex.key, (e) => e.withSets([
                    for (var k = 0; k < e.sets.length; k++) k == j ? e.sets[k].copyWith(type: p.type, kg: p.kg, reps: p.reps) : e.sets[k],
                  ])),
              onRemoveSet: (j) => _updateExercise(ex.key, (e) => e.withSets([...e.sets]..removeAt(j))),
              onAddSet: () => _updateExercise(ex.key, (e) => e.withSets(appendSet(e.sets))),
              onToggleDone: (j) {
                final next = toggleDone(ex.sets[j], prev[j]);
                if (next == null) {
                  showToast(context, 'Escribe las repeticiones de la serie', error: true);
                  return;
                }
                if (next.done) HapticFeedback.lightImpact();
                _updateExercise(ex.key, (e) => e.withSets([for (var k = 0; k < e.sets.length; k++) k == j ? next : e.sets[k]]));
              },
              onMove: (d) => _ctrl.update((w) {
                final list = [...w.exercises];
                final item = list.removeAt(i);
                list.insert(i + d, item);
                return w.copyWith(exercises: list);
              }),
              onRemove: () async {
                if (ex.sets.any((s) => s.done) &&
                    !await confirm(context, '¿Quitar ${data.nameOf(ex.exerciseId)} y sus series?', accept: 'Quitar', destructive: true)) {
                  return;
                }
                _ctrl.update((w) => w.copyWith(exercises: w.exercises.where((e) => e.key != ex.key).toList()));
              },
            );
          }(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          onPressed: () async {
            final exercise = await pickExercise(context, selected: active.exercises.map((e) => e.exerciseId).toList());
            if (exercise == null) return;
            _ctrl.update((w) => w.copyWith(exercises: [
                  ...w.exercises,
                  DraftExercise(key: newKey(), exerciseId: exercise.id, sets: setsForNewExercise(exercise.id, data.workouts)),
                ]));
          },
          icon: const Icon(Icons.add),
          label: const Text('Agregar ejercicio'),
        ),
      ]);
    });
  }
}
