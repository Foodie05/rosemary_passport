import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'primitives.dart';
import 'controls.dart';
import 'overlays.dart';
import 'generated/rosemary_tokens.dart';

class RosemaryTabs extends StatefulWidget {
  final String value;
  final List<RosemaryOption> options;
  final ValueChanged<String> onChanged;
  final Widget Function(String id)? panelBuilder;
  const RosemaryTabs({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.panelBuilder,
  });
  @override
  State<RosemaryTabs> createState() => _TabsState();
}

class _TabsState extends State<RosemaryTabs> {
  final root = GlobalKey();
  final keys = <String, GlobalKey>{}, nodes = <String, FocusNode>{};
  double left = 0, width = 0;
  bool measurementPending = false;
  void measure() {
    if (measurementPending) return;
    measurementPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      measurementPending = false;
      if (!mounted) return;
      final box = root.currentContext?.findRenderObject() as RenderBox?,
          selected =
              keys[widget.value]?.currentContext?.findRenderObject()
                  as RenderBox?;
      if (box != null && selected != null) {
        final x = selected.localToGlobal(Offset.zero, ancestor: box).dx,
            w = selected.size.width;
        if (x != left || w != width)
          setState(() {
            left = x;
            width = w;
          });
      }
    });
  }

  KeyEventResult key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final enabled = widget.options.where((o) => o.enabled).toList();
    if (enabled.isEmpty) return KeyEventResult.ignored;
    final focusedId = nodes.entries
        .where((e) => e.value.hasFocus)
        .firstOrNull
        ?.key;
    var index = enabled.indexWhere((o) => o.id == (focusedId ?? widget.value));
    if (index < 0) index = 0;
    final k = event.logicalKey,
        rtl = Directionality.of(context) == TextDirection.rtl;
    if (k == LogicalKeyboardKey.home)
      index = 0;
    else if (k == LogicalKeyboardKey.end)
      index = enabled.length - 1;
    else if (k == LogicalKeyboardKey.arrowRight)
      index = (index + (rtl ? -1 : 1)) % enabled.length;
    else if (k == LogicalKeyboardKey.arrowLeft)
      index = (index + (rtl ? 1 : -1)) % enabled.length;
    else {
      return KeyEventResult.ignored;
    }
    widget.onChanged(enabled[index].id);
    nodes[enabled[index].id]?.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    for (final node in nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final option in widget.options) {
      keys.putIfAbsent(option.id, GlobalKey.new);
      nodes.putIfAbsent(option.id, FocusNode.new);
      nodes[option.id]!.skipTraversal = option.id != widget.value;
    }
    measure();
    final c = RosemaryThemeData.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Focus(
            onKeyEvent: key,
            child: Stack(
              key: root,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in widget.options)
                      RosemaryActionSurface(
                        key: keys[option.id],
                        focusNode: nodes[option.id],
                        selected: option.id == widget.value,
                        enabled: option.enabled,
                        onActivate: () => widget.onChanged(option.id),
                        child: Text(option.label),
                      ),
                  ],
                ),
                AnimatedPositioned(
                  duration: rosemaryDuration(context, 'tabsMs'),
                  left: left,
                  bottom: 0,
                  width: width,
                  height: 3,
                  child: ExcludeSemantics(child: ColoredBox(color: c.primary)),
                ),
              ],
            ),
          ),
        ),
        if (widget.panelBuilder != null)
          AnimatedSwitcher(
            duration: rosemaryDuration(context, 'tabsMs'),
            child: KeyedSubtree(
              key: ValueKey(widget.value),
              child: widget.panelBuilder!(widget.value),
            ),
          ),
      ],
    );
  }
}

class RosemaryBreadcrumb extends StatelessWidget {
  final List<RosemaryOption> items;
  final ValueChanged<String> onNavigate;
  const RosemaryBreadcrumb({
    super.key,
    required this.items,
    required this.onNavigate,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: rString(context, 'Breadcrumb'),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i != 0) const ExcludeSemantics(child: RosemaryText(' / ')),
          RosemaryLink(
            label: items[i].label,
            current: i == items.length - 1,
            onNavigate: () => onNavigate(items[i].id),
          ),
        ],
      ],
    ),
  );
}

class RosemaryPagination extends StatelessWidget {
  final int page, count;
  final ValueChanged<int> onChanged;
  final bool busy;
  final String? error;
  const RosemaryPagination({
    super.key,
    required this.page,
    required this.count,
    required this.onChanged,
    this.busy = false,
    this.error,
  });
  @override
  Widget build(BuildContext context) {
    if (count < 1 || page < 1 || page > count)
      throw ArgumentError('Pagination requires page within positive count');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            RosemaryButton(
              label: rString(context, 'Previous'),
              onPressed: page > 1 && !busy ? () => onChanged(page - 1) : null,
              variant: RosemaryButtonVariant.secondary,
            ),
            Semantics(liveRegion: true, child: RosemaryText('$page / $count')),
            RosemaryButton(
              label: rString(context, 'Next'),
              onPressed: page < count && !busy
                  ? () => onChanged(page + 1)
                  : null,
              variant: RosemaryButtonVariant.secondary,
            ),
          ],
        ),
        if (error != null)
          RosemaryText(error!, color: RosemaryThemeData.of(context).danger),
      ],
    );
  }
}

class RosemaryMenu extends StatefulWidget {
  final bool open;
  final Widget trigger;
  final List<RosemaryOption> items;
  final ValueChanged<String> onActivate;
  final ValueChanged<bool> onOpenChanged;
  const RosemaryMenu({
    super.key,
    required this.open,
    required this.trigger,
    required this.items,
    required this.onActivate,
    required this.onOpenChanged,
  });
  @override
  State<RosemaryMenu> createState() => _MenuState();
}

class _MenuState extends State<RosemaryMenu> {
  int active = 0;
  String prefix = '';
  DateTime last = DateTime.fromMillisecondsSinceEpoch(0);
  final scope = FocusNode();
  final itemKeys = <String, GlobalKey>{};
  List<int> get enabled => [
    for (var i = 0; i < widget.items.length; i++)
      if (widget.items[i].enabled) i,
  ];
  void normalize([String? previousId]) {
    final found = widget.items.indexWhere(
      (item) => item.id == previousId && item.enabled,
    );
    active = found >= 0 ? found : (enabled.firstOrNull ?? -1);
  }

  void revealActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.open || !enabled.contains(active)) return;
      final target = itemKeys[widget.items[active].id]?.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: .5);
    });
  }

  @override
  void initState() {
    super.initState();
    normalize();
    if (widget.open)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open) scope.requestFocus();
      });
  }

  @override
  void didUpdateWidget(RosemaryMenu old) {
    super.didUpdateWidget(old);
    final previousId = active >= 0 && active < old.items.length
        ? old.items[active].id
        : null;
    normalize(previousId);
    if (!old.open && widget.open && enabled.isNotEmpty) {
      active = enabled.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) scope.requestFocus();
      });
    }
    if (widget.open) revealActive();
  }

  KeyEventResult key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || enabled.isEmpty)
      return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.tab) {
      widget.onOpenChanged(false);
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) {
      if (!enabled.contains(active)) normalize();
      widget.onActivate(widget.items[active].id);
      widget.onOpenChanged(false);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.home)
      active = enabled.first;
    else if (k == LogicalKeyboardKey.end)
      active = enabled.last;
    else if (k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowUp)
      active =
          enabled[(enabled.indexOf(active) +
                  (k == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
              enabled.length];
    else if (event.character != null && event.character!.length == 1) {
      final now = DateTime.now();
      prefix = now.difference(last).inMilliseconds < 700
          ? prefix + event.character!.toLowerCase()
          : event.character!.toLowerCase();
      last = now;
      final found = enabled.where(
        (i) => widget.items[i].label.toLowerCase().startsWith(prefix),
      );
      if (found.isNotEmpty) active = found.first;
    } else {
      return KeyEventResult.ignored;
    }
    setState(() {});
    revealActive();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RosemaryPopover(
    open: widget.open,
    trigger: widget.trigger,
    onDismiss: (_) => widget.onOpenChanged(false),
    child: Focus(
      focusNode: scope,
      autofocus: widget.open,
      onKeyEvent: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.items.length; i++)
            RosemaryActionSurface(
              key: itemKeys.putIfAbsent(widget.items[i].id, GlobalKey.new),
              enabled: widget.items[i].enabled,
              selected: i == active,
              background: i == active
                  ? RosemaryThemeData.of(context).primarySoft
                  : null,
              onActivate: () {
                widget.onActivate(widget.items[i].id);
                widget.onOpenChanged(false);
              },
              child: Text(widget.items[i].label),
            ),
        ],
      ),
    ),
  );
}

class RosemaryCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onActivate;
  final bool selected;
  const RosemaryCard({
    super.key,
    required this.child,
    this.onActivate,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) {
    final c = RosemaryThemeData.of(context);
    final decoration = BoxDecoration(
      color: selected ? c.primarySoft : c.surfaceGroup,
      borderRadius: BorderRadius.circular(RosemaryTokens.contentRadius),
      border: MediaQuery.highContrastOf(context)
          ? Border.all(color: c.control, width: 2)
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
    return onActivate == null
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: decoration,
            child: child,
          )
        : RosemaryActionSurface(
            selected: selected,
            onActivate: onActivate,
            background: selected ? c.primarySoft : c.surfaceGroup,
            border: MediaQuery.highContrastOf(context) ? c.control : null,
            radius: RosemaryTokens.contentRadius,
            padding: const EdgeInsets.all(16),
            child: child,
          );
  }
}

class RosemaryListItem {
  final String id, title;
  final String? description;
  final bool enabled;
  const RosemaryListItem(
    this.id,
    this.title, {
    this.description,
    this.enabled = true,
  });
}

class RosemaryList extends StatelessWidget {
  final List<RosemaryListItem> items;
  final Set<String> selected;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final ValueChanged<String>? onActivate;
  final Widget? empty;
  const RosemaryList({
    super.key,
    required this.items,
    this.selected = const {},
    this.onSelectionChanged,
    this.onActivate,
    this.empty,
  });
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return empty ?? const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Semantics(
            key: ValueKey(item.id),
            selected: selected.contains(item.id),
            child: RosemaryActionSurface(
              enabled: item.enabled,
              onActivate: onSelectionChanged == null && onActivate == null
                  ? null
                  : () {
                      onActivate?.call(item.id);
                      if (onSelectionChanged != null) {
                        final next = {...selected};
                        next.contains(item.id)
                            ? next.remove(item.id)
                            : next.add(item.id);
                        onSelectionChanged!(Set.unmodifiable(next));
                      }
                    },
              background: selected.contains(item.id)
                  ? RosemaryThemeData.of(context).primarySoft
                  : null,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RosemaryText(item.title),
                  if (item.description != null)
                    RosemaryText(
                      item.description!,
                      role: 'small',
                      color: RosemaryThemeData.of(context).muted,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class RosemaryTableColumn {
  final String id, label;
  final bool sortable;
  const RosemaryTableColumn(this.id, this.label, {this.sortable = false});
}

class RosemaryTableRow {
  final String id;
  final List<String> cells;
  const RosemaryTableRow(this.id, this.cells);
}

class RosemaryTable extends StatelessWidget {
  final String label;
  final List<RosemaryTableColumn> columns;
  final List<RosemaryTableRow> rows;
  final String? sortColumn;
  final bool ascending;
  final void Function(String id, bool ascending)? onSortChanged;
  final Set<String> selected;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final ValueChanged<String>? onActivate;
  final Widget? empty;
  const RosemaryTable({
    super.key,
    required this.label,
    required this.columns,
    required this.rows,
    this.sortColumn,
    this.ascending = true,
    this.onSortChanged,
    this.selected = const {},
    this.onSelectionChanged,
    this.onActivate,
    this.empty,
  });
  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty ||
        rows.any((row) => row.cells.length != columns.length))
      throw ArgumentError('Table rows must match the columns');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: RosemaryText(label, role: 'lead')),
        LayoutBuilder(
          builder: (context, bounds) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: bounds.maxWidth.clamp(
                columns.length * 140.0,
                double.infinity,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (onSelectionChanged != null) const SizedBox(width: 44),
                      for (final column in columns)
                        Expanded(
                          child: Semantics(
                            header: true,
                            value: sortColumn == column.id
                                ? rString(
                                    context,
                                    ascending ? 'Ascending' : 'Descending',
                                  )
                                : null,
                            child: RosemaryActionSurface(
                              onActivate:
                                  column.sortable && onSortChanged != null
                                  ? () => onSortChanged!(
                                      column.id,
                                      sortColumn == column.id
                                          ? !ascending
                                          : true,
                                    )
                                  : null,
                              child: RosemaryText(column.label, role: 'small'),
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final row in rows)
                    Row(
                      key: ValueKey(row.id),
                      children: [
                        if (onSelectionChanged != null)
                          RosemaryCheckbox(
                            value: selected.contains(row.id),
                            label: '',
                            onChanged: (v) {
                              final next = {...selected};
                              v ? next.add(row.id) : next.remove(row.id);
                              onSelectionChanged!(Set.unmodifiable(next));
                            },
                          ),
                        for (final cell in row.cells)
                          Expanded(
                            child: RosemaryActionSurface(
                              onActivate: onActivate == null
                                  ? null
                                  : () => onActivate!(row.id),
                              child: RosemaryText(cell),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (rows.isEmpty && empty != null) empty!,
      ],
    );
  }
}

enum RosemaryStepState { notStarted, current, completed, error, unavailable }

class RosemaryStep {
  final String id, label;
  final RosemaryStepState state;
  final bool enabled;
  const RosemaryStep(
    this.id,
    this.label, {
    this.state = RosemaryStepState.notStarted,
    this.enabled = true,
  });
}

class RosemaryStepper extends StatelessWidget {
  final List<RosemaryStep> steps;
  final String value;
  final ValueChanged<String>? onChanged;
  const RosemaryStepper({
    super.key,
    required this.steps,
    required this.value,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (var i = 0; i < steps.length; i++)
        Semantics(
          value: steps[i].state.name,
          selected: steps[i].id == value,
          child: RosemaryActionSurface(
            enabled:
                steps[i].enabled &&
                steps[i].state != RosemaryStepState.unavailable,
            selected: steps[i].id == value,
            background: steps[i].id == value
                ? RosemaryThemeData.of(context).primarySoft
                : null,
            foreground: steps[i].state == RosemaryStepState.error
                ? RosemaryThemeData.of(context).danger
                : null,
            onActivate: onChanged == null
                ? null
                : () => onChanged!(steps[i].id),
            child: RosemaryText('${i + 1}. ${steps[i].label}'),
          ),
        ),
    ],
  );
}
