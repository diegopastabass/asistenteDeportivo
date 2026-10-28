import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/common/date.dart';
import '../../core/nutrition/macros.dart';
import '../../core/nutrition/models.dart';
import '../../core/nutrition/score.dart';
import '../../core/common/numbers.dart';
import '../../ui/format.dart';
import '../../ui/macros.dart';
import '../../ui/widgets.dart';
import '../activity/steps_card.dart';

/// Diario del día: puntaje, macros contra objetivos y comidas registradas.
class DiaryPage extends ConsumerStatefulWidget {
  const DiaryPage({super.key, this.initialDate});

  final String? initialDate;

  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  late String _date = isDateKey(widget.initialDate) ? widget.initialDate! : todayKey();

  @override
  void didUpdateWidget(DiaryPage old) {
    super.didUpdateWidget(old);
    if (widget.initialDate != old.initialDate && isDateKey(widget.initialDate)) _date = widget.initialDate!;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final goals = ref.watch(goalsProvider).value ?? defaultGoals;
    final entries = ref.watch(dayEntriesProvider(_date));
    final list = entries.value;
    final totals = sumMacros((list ?? const <DiaryEntry>[]).map((e) => e.macros));
    final score = dailyScore(totals, goals);
    final isEmpty = list != null && list.isEmpty;

    return PageBody(children: [
      Row(children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: DateNav(date: _date, onChanged: (d) => setState(() => _date = d)))),
        IconButton.filled(
          tooltip: 'Registrar comida',
          onPressed: () => context.go('/registrar?d=$_date'),
          icon: const Icon(Icons.playlist_add),
        ),
      ]),
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          ScoreRing(score: score.total, empty: isEmpty),
          const SizedBox(width: 16),
          Expanded(
            child: Column(children: [
              for (final k in MacroKey.values) ...[
                if (k != MacroKey.kcal) const SizedBox(height: 10),
                MacroBar(macro: k, value: totals[k], range: goals.range(k), score: score.perMacro[k]!),
              ],
            ]),
          ),
        ]),
      ),
      StepsCard(date: _date),
      if (entries is AsyncError) ErrorView(entries.error!),
      if (list == null && entries is! AsyncError) const LoadingView(),
      if (isEmpty)
        const AppCard(
          child: EmptyState(
            icon: Icons.restaurant_menu,
            title: 'Sin registros este día',
            message: 'Toca el botón de registrar para pegar una lista como "Arroz 100g, Huevos x3".',
          ),
        ),
      if (list != null)
        for (final slot in MealSlot.values)
          if (list.any((e) => e.meal == slot))
            _MealCard(
              slot: slot,
              items: list.where((e) => e.meal == slot).toList(),
              onDelete: (e) => runGuarded(context, () => ref.read(nutritionActionsProvider).deleteEntry(_date, e.id)),
            ),
      if (list != null && list.isNotEmpty)
        Text('Total del día: ${formatMacro(MacroKey.kcal, totals.kcal)} kcal', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
    ]);
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.slot, required this.items, required this.onDelete});

  final MealSlot slot;
  final List<DiaryEntry> items;
  final void Function(DiaryEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = mealMeta[slot]!;
    return CardList(
      header: CardHeader(meta.label, icon: meta.icon, trailing: MacroInline(sumMacros(items.map((i) => i.macros)), fontSize: 11)),
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(children: [
              if (e.kind == EntryKind.recipe) ...[Icon(Icons.menu_book_outlined, size: 14, color: c.primary), const SizedBox(width: 6)],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.fg)),
                    const SizedBox(height: 2),
                    Wrap(spacing: 8, children: [
                      Text('${e.servings != null ? '${plain(e.servings!)} porc. · ' : ''}${e.grams.round()} g',
                          style: TextStyle(fontSize: 12, color: c.faint, fontFeatures: tabular)),
                      MacroInline(e.macros),
                    ]),
                  ]),
                ),
              ),
              IconButton(
                tooltip: 'Eliminar ${e.name}',
                onPressed: () => onDelete(e),
                icon: Icon(Icons.delete_outline, size: 20, color: c.danger),
              ),
            ]),
          ),
      ],
    );
  }
}
