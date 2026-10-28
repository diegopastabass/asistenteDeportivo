import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/common/numbers.dart';
import '../../core/strength/catalog.dart';
import '../../core/strength/models.dart';
import '../../core/strength/session.dart';
import '../../ui/format.dart';
import '../../ui/widgets.dart';
import 'exercise_widgets.dart';

/// Fila editable de la tabla de series (rutina o sesión en curso).
class SetRow {
  const SetRow({required this.key, required this.type, required this.kg, required this.reps, this.done, this.hintKg, this.hintReps});

  final String key;
  final SetType type;
  final String kg;
  final String reps;

  /// Solo en la sesión en curso.
  final bool? done;

  /// Sugerencias (placeholder) cuando el campo está vacío.
  final double? hintKg;
  final double? hintReps;
}

class SetPatch {
  const SetPatch({this.type, this.kg, this.reps});

  final SetType? type;
  final String? kg;
  final String? reps;
}

/// Tarjeta de un ejercicio con su tabla de series.
class ExerciseBlock extends StatelessWidget {
  const ExerciseBlock({
    super.key,
    required this.index,
    required this.total,
    required this.exercise,
    required this.name,
    required this.rows,
    required this.previous,
    required this.onChange,
    required this.onRemoveSet,
    required this.onAddSet,
    required this.onMove,
    required this.onRemove,
    this.onToggleDone,
    this.note,
    this.highlight,
  });

  final int index;
  final int total;
  final Exercise? exercise;
  final String name;
  final List<SetRow> rows;

  /// Serie equivalente de la última sesión con este ejercicio.
  final List<StrengthSet?> previous;
  final void Function(int setIndex, SetPatch patch) onChange;
  final void Function(int setIndex) onRemoveSet;
  final VoidCallback onAddSet;
  final void Function(int delta) onMove;
  final VoidCallback onRemove;

  /// Si se entrega, se muestra la columna ✓ (sesión en curso).
  final void Function(int setIndex)? onToggleDone;

  /// Texto bajo el encabezado ("Objetivo: 8–12 reps").
  final String? note;

  /// Aviso destacado (sugerencia de subir el peso).
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = rows.where((r) => r.done == true).length;
    final muscles = exercise != null && exercise!.primary.isNotEmpty ? ' · ${exercise!.primary.map(muscleLabel).join(', ')}' : '';
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: exercise == null ? null : () => showExerciseInfo(context, exercise!),
                child: Row(children: [
                  ExerciseThumb(exercise),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.primary)),
                      Text(
                        '${onToggleDone != null ? '$done/${rows.length} series' : '${rows.length} ${rows.length == 1 ? 'serie' : 'series'}'}$muscles',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.faint),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opciones de $name',
              icon: Icon(Icons.more_vert, color: c.muted),
              onSelected: (v) => switch (v) {
                'up' => onMove(-1),
                'down' => onMove(1),
                _ => onRemove(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'up', enabled: index > 0, child: const Text('Subir')),
                PopupMenuItem(value: 'down', enabled: index < total - 1, child: const Text('Bajar')),
                PopupMenuItem(value: 'remove', child: Text('Quitar', style: TextStyle(color: c.danger))),
              ],
            ),
          ]),
        ),
        if (highlight != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: c.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.trending_up, size: 18, color: c.success),
              const SizedBox(width: 8),
              Expanded(child: Text(highlight!, style: TextStyle(fontSize: 12, color: c.fgStrong, height: 1.3))),
            ]),
          ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text(note!, style: TextStyle(fontSize: 11, color: c.muted)),
          ),
        _SetTable(rows: rows, previous: previous, onChange: onChange, onRemove: onRemoveSet, onToggleDone: onToggleDone),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: TextButton.icon(
            style: TextButton.styleFrom(backgroundColor: c.surface2, foregroundColor: c.muted, minimumSize: const Size.fromHeight(36)),
            onPressed: onAddSet,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar serie', style: TextStyle(fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}

/// Tabla SERIE · ANTERIOR · KG · REPS · ✓
class _SetTable extends StatelessWidget {
  const _SetTable({required this.rows, required this.previous, required this.onChange, required this.onRemove, this.onToggleDone});

  final List<SetRow> rows;
  final List<StrengthSet?> previous;
  final void Function(int, SetPatch) onChange;
  final void Function(int) onRemove;
  final void Function(int)? onToggleDone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labels = setLabels(rows.map((r) => r.type).toList());
    final head = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: c.faint);

    Widget cells({required Widget serie, required Widget prev, required Widget kg, required Widget reps, Widget? check, required Widget remove}) =>
        Row(children: [
          SizedBox(width: 34, child: serie),
          const SizedBox(width: 4),
          Expanded(child: prev),
          SizedBox(width: 64, child: kg),
          const SizedBox(width: 6),
          SizedBox(width: 54, child: reps),
          if (check != null) ...[const SizedBox(width: 6), SizedBox(width: 36, child: check)],
          SizedBox(width: 30, child: remove),
        ]);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: cells(
          serie: Text('SERIE', textAlign: TextAlign.center, style: head),
          prev: Text('ANTERIOR', style: head),
          kg: Text('KG', textAlign: TextAlign.center, style: head),
          reps: Text('REPS', textAlign: TextAlign.center, style: head),
          check: onToggleDone != null ? Icon(Icons.check, size: 14, color: c.faint) : null,
          remove: const SizedBox(),
        ),
      ),
      for (var i = 0; i < rows.length; i++)
        _SetRowView(
          key: ValueKey(rows[i].key),
          row: rows[i],
          label: labels[i],
          prev: i < previous.length ? previous[i] : null,
          cells: cells,
          onChange: (p) => onChange(i, p),
          onRemove: () => onRemove(i),
          onToggleDone: onToggleDone == null ? null : () => onToggleDone!(i),
        ),
    ]);
  }
}

class _SetRowView extends StatefulWidget {
  const _SetRowView({
    super.key,
    required this.row,
    required this.label,
    required this.prev,
    required this.cells,
    required this.onChange,
    required this.onRemove,
    this.onToggleDone,
  });

  final SetRow row;
  final String label;
  final StrengthSet? prev;
  final Widget Function({required Widget serie, required Widget prev, required Widget kg, required Widget reps, Widget? check, required Widget remove}) cells;
  final ValueChanged<SetPatch> onChange;
  final VoidCallback onRemove;
  final VoidCallback? onToggleDone;

  @override
  State<_SetRowView> createState() => _SetRowViewState();
}

class _SetRowViewState extends State<_SetRowView> {
  late final _kg = TextEditingController(text: widget.row.kg);
  late final _reps = TextEditingController(text: widget.row.reps);

  @override
  void didUpdateWidget(_SetRowView old) {
    super.didUpdateWidget(old);
    // Valores que cambian desde fuera (al marcar con sugerencia o al copiar la anterior).
    if (widget.row.kg != _kg.text) _kg.text = widget.row.kg;
    if (widget.row.reps != _reps.text) _reps.text = widget.row.reps;
  }

  @override
  void dispose() {
    _kg.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final row = widget.row;
    final done = row.done == true;
    final typeColor = switch (row.type) {
      SetType.warmup => c.warning,
      SetType.failure => c.danger,
      SetType.normal => c.fgStrong,
    };
    final typeLabel = switch (row.type) {
      SetType.warmup => 'Calentamiento',
      SetType.failure => 'Al fallo',
      SetType.normal => 'Serie efectiva',
    };
    final prev = widget.prev;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: done ? c.primarySoft : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: widget.cells(
        serie: Tooltip(
          message: '$typeLabel. Toca para cambiar el tipo',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => widget.onChange(SetPatch(type: nextSetType(row.type))),
            child: SizedBox(
              height: 36,
              child: Center(child: Text(widget.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: typeColor))),
            ),
          ),
        ),
        prev: InkWell(
          onTap: prev == null ? null : () => widget.onChange(SetPatch(kg: plainEs(prev.kg), reps: plainEs(prev.reps))),
          child: Text(prev == null ? '—' : formatSet(kg: prev.kg, reps: prev.reps),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.faint, fontFeatures: tabular)),
        ),
        kg: NumberField(
          controller: _kg,
          dense: true,
          textAlign: TextAlign.center,
          hint: plainEs(row.hintKg).isEmpty ? '0' : plainEs(row.hintKg),
          onChanged: (v) => widget.onChange(SetPatch(kg: v)),
        ),
        reps: NumberField(
          controller: _reps,
          dense: true,
          decimal: false,
          // En el editor de rutinas se puede escribir un rango ("8-12").
          allowRange: widget.onToggleDone == null,
          textAlign: TextAlign.center,
          hint: plainEs(row.hintReps).isEmpty ? '0' : plainEs(row.hintReps),
          onChanged: (v) => widget.onChange(SetPatch(reps: v)),
        ),
        check: widget.onToggleDone == null
            ? null
            : Semantics(
                button: true,
                toggled: done,
                label: done ? 'Desmarcar serie ${widget.label}' : 'Marcar serie ${widget.label} como hecha',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: widget.onToggleDone,
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: done ? c.gradient : null,
                      color: done ? null : c.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check, size: 18, color: done ? c.onPrimary : c.faint),
                  ),
                ),
              ),
        remove: IconButton(
          tooltip: 'Quitar serie ${widget.label}',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: widget.onRemove,
          icon: Icon(Icons.close, size: 16, color: c.faint),
        ),
      ),
    );
  }
}
