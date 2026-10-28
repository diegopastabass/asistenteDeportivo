/// Piezas de interfaz reutilizables.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';

/// Tarjeta con borde (equivalente a `.card` de la web).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap, this.borderColor});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderColor ?? c.border));
    return Material(
      color: c.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? Padding(padding: padding, child: child) : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Encabezado gris de una tarjeta ("Historial", "Tus avances"…).
class CardHeader extends StatelessWidget {
  const CardHeader(this.text, {super.key, this.trailing, this.icon});

  final String text;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      color: c.surface2.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 16, color: c.primary), const SizedBox(width: 8)],
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: icon != null ? c.fgStrong : c.muted)),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Lista dentro de una tarjeta con separadores.
class CardList extends StatelessWidget {
  const CardList({super.key, required this.children, this.header});

  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (header != null) ...[header!, const Divider()],
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(), children[i]],
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.colors.fgStrong))),
      ?trailing,
    ]);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: c.primary),
        ),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: c.fgStrong)),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(message!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: c.muted, height: 1.4)),
        ],
      ]),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.text = 'Cargando…'});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text(text, style: TextStyle(fontSize: 12, color: context.colors.muted))),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView(this.error, {super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.1),
        border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(errorMessage(error), style: TextStyle(fontSize: 12, color: c.danger)),
    );
  }
}

String errorMessage(Object e) {
  final text = e.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}

/// Muestra datos asíncronos con estados de carga y error uniformes.
class AsyncView<T> extends StatelessWidget {
  const AsyncView(this.value, {super.key, required this.builder, this.loadingText = 'Cargando…'});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String loadingText;

  @override
  Widget build(BuildContext context) => switch (value) {
        AsyncData(:final value) => builder(value),
        AsyncError(:final error) => ErrorView(error),
        _ => LoadingView(text: loadingText),
      };
}

/// Contenido desplazable de una sección, con márgenes y ancho máximo.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.gap = 16, this.bottomPadding = 24});

  final List<Widget> children;
  final double gap;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    // Respeta los bordes laterales seguros (cámara o franja de estado al costado).
    final side = MediaQuery.paddingOf(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16 + side.left, 12, 16 + side.right, bottomPadding),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila superior de una pantalla de detalle: volver, título y acciones.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.onBack, this.actions = const []});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      if (onBack != null) IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back), tooltip: 'Volver'),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.fgStrong)),
          if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: c.muted)),
        ]),
      ),
      ...actions,
    ]);
  }
}

/// Indicador pequeño: ícono, etiqueta y valor destacado.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.caption, this.trailing, this.tooltip});

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Widget? trailing;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tile = AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: c.muted),
          const SizedBox(width: 6),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.muted))),
        ]),
        const SizedBox(height: 2),
        Row(children: [
          Flexible(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.fgStrong, fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ]),
        if (caption != null) Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.faint)),
      ]),
    );
    return tooltip == null ? tile : Tooltip(message: tooltip!, child: tile);
  }
}

/// Grilla de indicadores de 2 o 3 columnas.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.columns = 2});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var j = 0; j < columns; j++) ...[
          if (j > 0) const SizedBox(width: 8),
          Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()),
        ],
      ]));
    }
    return Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]]]);
  }
}

/// Fila de opciones exclusivas (filtros, períodos, métricas).
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({super.key, required this.options, required this.selected, required this.onSelected, required this.label, this.scrollable = false});

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) label;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final chips = [
      for (final o in options)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label(o)),
            selected: o == selected,
            onSelected: (_) => onSelected(o),
            visualDensity: VisualDensity.compact,
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: o == selected ? c.primary : c.muted),
            side: BorderSide(color: o == selected ? c.primary : c.border),
          ),
        ),
    ];
    return scrollable
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: chips))
        : Wrap(runSpacing: 6, children: chips);
  }
}

/// Botón cuadrado con ícono y degradado (acción principal de una fila).
class GradientIcon extends StatelessWidget {
  const GradientIcon(this.icon, {super.key, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: c.gradient, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, color: c.onPrimary, size: size * 0.5),
    );
  }
}

/// Campo numérico que acepta coma decimal.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.hint,
    this.label,
    this.decimal = true,
    this.allowRange = false,
    this.textAlign = TextAlign.start,
    this.width,
    this.error = false,
    this.dense = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hint;
  final String? label;
  final bool decimal;

  /// Acepta un rango de enteros ("8-12").
  final bool allowRange;
  final TextAlign textAlign;
  final double? width;
  final bool error;
  final bool dense;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final field = TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      focusNode: focusNode,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textAlign: textAlign,
      // `signed` muestra la tecla "-" en el teclado numérico de iOS.
      keyboardType: TextInputType.numberWithOptions(decimal: decimal, signed: allowRange),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(allowRange ? r'[0-9-]' : decimal ? r'[0-9.,]' : r'[0-9]'))],
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        hintText: hint,
        labelText: label,
        contentPadding: dense ? const EdgeInsets.symmetric(horizontal: 6, vertical: 8) : null,
        enabledBorder: error
            ? OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.danger))
            : null,
      ),
    );
    return width == null ? field : SizedBox(width: width, child: field);
  }
}

/// Aviso breve en la parte inferior.
void showToast(BuildContext context, String message, {bool error = false}) {
  final c = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: error ? c.onPrimary : c.fgStrong)),
      backgroundColor: error ? c.danger : c.surface2,
      duration: const Duration(seconds: 3),
    ));
}

/// Diálogo de confirmación; devuelve true si el usuario acepta.
Future<bool> confirm(BuildContext context, String message, {String accept = 'Aceptar', bool destructive = false}) async {
  final c = context.colors;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar', style: TextStyle(color: c.muted))),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(accept, style: TextStyle(color: destructive ? c.danger : c.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Ejecuta una acción mostrando su error como aviso. Devuelve true si terminó bien.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showToast(context, success);
    return true;
  } on Object catch (e) {
    if (context.mounted) showToast(context, errorMessage(e), error: true);
    return false;
  }
}

/// Hoja inferior a pantalla casi completa con título.
Future<T?> showSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Encima de la barra de secciones del shell.
    useRootNavigator: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.fgStrong))),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Cerrar'),
          ]),
        ),
        Expanded(child: builder(context)),
      ]),
    ),
  );
}

const tabular = [FontFeature.tabularFigures()];
