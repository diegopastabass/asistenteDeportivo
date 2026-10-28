import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/activity/streak.dart';
import '../data/repositories.dart';
import '../features/strength/active_workout_pill.dart';
import 'modules.dart';
import 'providers.dart';
import 'theme.dart';

/// Marco de la app: selector de módulos arriba y secciones del módulo abajo.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final module = moduleForPath(location);
    final sections = module.sections;
    final selected = sections.indexWhere((s) => s.matches(location));
    final user = ref.watch(sessionUserProvider);
    final backend = ref.watch(backendProvider).kind;
    ref.listen(pendingMilestoneProvider, (_, milestone) {
      if (milestone != null) _celebrate(context, ref, milestone);
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          const AppLogo(size: 32),
          if (backend != BackendKind.firebase) ...[const SizedBox(width: 8), _BackendBadge(backend)],
          const Spacer(),
          _ModuleSwitcher(current: module),
        ]),
        actions: [
          const _StreakChip(),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => context.push('/ajustes'),
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: c.primarySoft,
              foregroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
              child: Text(user?.initial ?? '?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primary)),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Divider(height: 1, color: c.border)),
      ),
      body: Stack(children: [
        Positioned.fill(child: child),
        if (module.id == ModuleId.fuerza && location != '/fuerza' && location != '/fuerza/entrenar')
          const Positioned(left: 0, right: 0, bottom: 12, child: Center(child: ActiveWorkoutPill())),
      ]),
      bottomNavigationBar: sections.isEmpty
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: NavigationBar(
                selectedIndex: selected < 0 ? 0 : selected,
                labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                onDestinationSelected: (i) => context.go(sections[i].path),
                destinations: [for (final s in sections) NavigationDestination(icon: Icon(s.icon), label: s.label, tooltip: s.label)],
              ),
            ),
    );
  }
}

/// Celebra un hito de la racha. Se marca como celebrado antes de mostrarlo para
/// que no se repita (tampoco en otro dispositivo).
void _celebrate(BuildContext context, WidgetRef ref, int milestone) {
  final streak = ref.read(streakProvider).value;
  if (streak?.start == null) return;
  ref.read(nutritionActionsProvider).markStreakCelebrated(StreakCelebration(start: streak!.start!, milestone: milestone)).ignore();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    showDialog<void>(context: context, builder: (_) => _MilestoneDialog(milestone: milestone, onCalendar: () => context.push('/actividad')));
  });
}

class _MilestoneDialog extends StatelessWidget {
  const _MilestoneDialog({required this.milestone, required this.onCalendar});

  final int milestone;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final next = nextStreakMilestone(milestone);
    return AlertDialog(
      icon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(gradient: c.gradient, shape: BoxShape.circle),
        child: Icon(Icons.local_fire_department, size: 38, color: c.onPrimary),
      ),
      title: Text(streakMilestoneTitle(milestone), textAlign: TextAlign.center),
      content: Text(
        'Llevas $milestone días seguidos registrando comidas o entrenamientos. La constancia es lo que más rinde: '
        'tu próximo hito es a los $next días.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onCalendar();
          },
          child: const Text('Ver calendario'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('¡Vamos!')),
      ],
    );
  }
}

/// Racha de uso en el encabezado; abre el calendario de actividad.
class _StreakChip extends ConsumerWidget {
  const _StreakChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final streak = ref.watch(streakProvider).value;
    final days = streak?.current ?? 0;
    final active = streak?.activeToday ?? false;
    final color = days == 0 ? c.faint : (active ? c.warning : c.muted);
    return Semantics(
      button: true,
      label: 'Racha: $days ${days == 1 ? 'día' : 'días'}${days > 0 && !active ? ', registra algo hoy para mantenerla' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push('/actividad'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(active ? Icons.local_fire_department : Icons.local_fire_department_outlined, size: 20, color: color),
            Text('$days', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      ),
    );
  }
}

/// Logo de NutriApp (la nutria). Mismo dibujo que el ícono de la pantalla de inicio.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/logo.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'NutriApp',
      );
}

class _BackendBadge extends StatelessWidget {
  const _BackendBadge(this.kind);

  final BackendKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = kind == BackendKind.memory ? 'demo' : 'emulador';
    return Tooltip(
      message: kind == BackendKind.memory ? 'Datos de prueba en memoria: se borran al cerrar la app' : 'Conectado al emulador de Firebase',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c.warning)),
      ),
    );
  }
}

class _ModuleSwitcher extends StatelessWidget {
  const _ModuleSwitcher({required this.current});

  final AppModule current;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final m in modules)
          Semantics(
            button: true,
            selected: m.id == current.id,
            label: m.ready ? m.label : '${m.label}, en desarrollo',
            child: GestureDetector(
              onTap: () => context.go(m.path),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 32,
                padding: EdgeInsets.symmetric(horizontal: m.id == current.id ? 10 : 8),
                decoration: BoxDecoration(
                  gradient: m.id == current.id ? c.gradient : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Icon(m.icon, size: 17, color: m.id == current.id ? c.onPrimary : c.muted),
                    if (!m.ready && m.id != current.id)
                      Positioned(
                        right: -3,
                        top: -2,
                        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.warning, shape: BoxShape.circle)),
                      ),
                  ]),
                  if (m.id == current.id) ...[
                    const SizedBox(width: 6),
                    Text(m.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onPrimary)),
                  ],
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
