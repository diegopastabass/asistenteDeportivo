import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../core/strength/calendar.dart';
import '../../core/strength/models.dart';
import '../../core/strength/session.dart';
import '../../core/strength/stats.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';
import 'active_workout_pill.dart';

const _weekDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Empieza un entrenamiento (desde una rutina o libre), confirmando si ya hay otro en curso.
Future<void> startWorkout(BuildContext context, WidgetRef ref, [Routine? routine]) async {
  if (ref.read(activeWorkoutProvider) != null &&
      !await confirm(context, 'Ya tienes un entrenamiento en curso. ¿Descartarlo y empezar otro?', accept: 'Empezar otro', destructive: true)) {
    return;
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  ref.read(activeWorkoutProvider.notifier).set(routine != null ? workoutFromRoutine(routine, now) : emptyWorkout(now));
  if (context.mounted) context.push('/fuerza/entrenar');
}

class StrengthHomePage extends ConsumerWidget {
  const StrengthHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final active = ref.watch(activeWorkoutProvider);
    final data = ref.watch(strengthDataProvider);

    return AsyncView(data, builder: (s) {
      final today = todayKey();
      final monday = weekStart(today);
      final trainedDays = s.workouts.map((w) => w.date).toSet();
      final streak = weeklyStreak(trainedDays, today);
      final lastByRoutine = <String, String>{};
      for (final w in s.workouts) {
        if (w.routineId != null) lastByRoutine.putIfAbsent(w.routineId!, () => w.date);
      }

      return PageBody(children: [
        if (active != null)
          AppCard(
            borderColor: c.primary.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(12),
            onTap: () => context.push('/fuerza/entrenar'),
            child: Row(children: [
              const GradientIcon(Icons.timer_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Entrenamiento en curso', style: TextStyle(fontSize: 12, color: c.muted)),
                  Row(children: [
                    Flexible(
                      child: Text('${active.name} · ', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
                    ),
                    ElapsedText(active.startedAt, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
                  ]),
                ]),
              ),
              Icon(Icons.chevron_right, color: c.faint),
            ]),
          ),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Esta semana', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong))),
              if (streak > 0)
                Tooltip(
                  message: 'Semanas seguidas con al menos un entrenamiento',
                  child: Row(children: [
                    Icon(Icons.local_fire_department, size: 16, color: c.warning),
                    Text(' $streak ${streak == 1 ? 'semana seguida' : 'semanas seguidas'}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.warning)),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: () {
                    final date = addDays(monday, i);
                    final done = trainedDays.contains(date);
                    final isToday = date == today;
                    final future = date.compareTo(today) > 0;
                    return Column(children: [
                      Text(_weekDays[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isToday ? c.primary : c.faint)),
                      const SizedBox(height: 4),
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: done ? c.gradient : null,
                          color: done ? null : (future ? null : c.bgHard),
                          shape: BoxShape.circle,
                          border: future && !done ? Border.all(color: c.border) : (isToday && !done ? Border.all(color: c.primary) : null),
                        ),
                        child: done
                            ? Icon(Icons.fitness_center, size: 15, color: c.onPrimary, semanticLabel: 'Entrenaste')
                            : Text('${fromDateKey(date).day}', style: TextStyle(fontSize: 12, color: future ? c.faint : c.muted)),
                      ),
                    ]);
                  }(),
                ),
            ]),
          ]),
        ),
        SectionTitle(
          'Rutinas',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            OutlinedButton.icon(
              onPressed: () => startWorkout(context, ref),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Libre'),
            ),
            const SizedBox(width: 6),
            IconButton.filled(tooltip: 'Nueva rutina', onPressed: () => context.push('/fuerza/rutinas/nueva'), icon: const Icon(Icons.add)),
          ]),
        ),
        if (s.routines.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.playlist_add,
              title: 'Crea tu primera rutina',
              message: 'Por ejemplo "Rutina de pecho": eliges los ejercicios y sus series una vez y después solo la empiezas y la rellenas.',
            ),
          ),
        for (final r in s.routines)
          AppCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.fgStrong)),
                  Text(
                    () {
                      final names = r.exercises.map((e) => s.nameOf(e.exerciseId)).toList();
                      return '${names.take(3).join(', ')}${names.length > 3 ? ' y ${names.length - 3} más' : ''}';
                    }(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
                  Text(
                    '${r.exercises.length} ejercicios · ${r.exercises.fold<int>(0, (n, e) => n + e.sets.length)} series'
                    '${lastByRoutine[r.id] != null ? ' · última vez ${relativeDay(lastByRoutine[r.id]!)}' : ' · aún no la haces'}',
                    style: TextStyle(fontSize: 11, color: c.faint),
                  ),
                ]),
              ),
              IconButton(tooltip: 'Editar ${r.name}', onPressed: () => context.push('/fuerza/rutinas/${r.id}'), icon: const Icon(Icons.edit_outlined)),
              IconButton.filled(tooltip: 'Empezar ${r.name}', onPressed: () => startWorkout(context, ref, r), icon: const Icon(Icons.play_arrow)),
            ]),
          ),
        if (s.workouts.isNotEmpty) ...[
          SectionTitle(
            'Últimos entrenamientos',
            trailing: TextButton(onPressed: () => context.go('/fuerza/historial'), child: const Text('Ver todo')),
          ),
          CardList(children: [
            for (final w in s.workouts.take(3))
              ListTile(
                onTap: () => context.push('/fuerza/historial/${w.id}'),
                title: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: () {
                  final t = workoutTotals(w);
                  return Text('${shortDate(w.date)} · ${t.sets} series · ${formatVolume(t.volume)}', style: TextStyle(fontSize: 12, color: c.faint));
                }(),
                trailing: Icon(Icons.chevron_right, color: c.faint),
              ),
          ]),
        ],
      ]);
    });
  }
}
