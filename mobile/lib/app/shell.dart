import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          const AppLogo(size: 28),
          if (backend != BackendKind.firebase) ...[const SizedBox(width: 8), _BackendBadge(backend)],
          const Spacer(),
          _ModuleSwitcher(current: module),
        ]),
        actions: [
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

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(Icons.eco, size: size * 0.6, color: c.onPrimary),
    );
  }
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
