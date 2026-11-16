import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'theme.dart';
import 'primitives.dart';
import 'generated/rosemary_tokens.dart';
import 'feedback.dart';

@immutable
class RosemaryLocalDate implements Comparable<RosemaryLocalDate> {
  final int year, month, day;
  RosemaryLocalDate(this.year, this.month, this.day) {
    if (year < 1 ||
        year > 9999 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > daysInMonth(year, month))
      throw ArgumentError('Gregorian date must be in 0001-01-01…9999-12-31');
  }
  static int daysInMonth(int year, int month) => [
    31,
    year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) ? 29 : 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ][month - 1];
  static RosemaryLocalDate? parse(String input) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) return null;
    final parts = input.split('-').map(int.parse).toList();
    try {
      return RosemaryLocalDate(parts[0], parts[1], parts[2]);
    } on ArgumentError {
      return null;
    }
  }

  int get weekday => DateTime.utc(year, month, day).weekday;
  RosemaryLocalDate? addDays(int days) {
    final date = DateTime.utc(year, month, day + days);
    if (date.year < 1 || date.year > 9999) return null;
    return RosemaryLocalDate(date.year, date.month, date.day);
  }

  @override
  int compareTo(RosemaryLocalDate other) => (year * 10000 + month * 100 + day)
      .compareTo(other.year * 10000 + other.month * 100 + other.day);
  @override
  bool operator ==(Object other) =>
      other is RosemaryLocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

@immutable
class RosemaryLocalTime {
  final int hour, minute;
  RosemaryLocalTime(this.hour, this.minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59)
      throw ArgumentError('Local time must be HH:mm');
  }
  static RosemaryLocalTime? parse(String input) {
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(input)) return null;
    final parts = input.split(':').map(int.parse).toList();
    try {
      return RosemaryLocalTime(parts[0], parts[1]);
    } on ArgumentError {
      return null;
    }
  }

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  @override
  bool operator ==(Object other) =>
      other is RosemaryLocalTime &&
      hour == other.hour &&
      minute == other.minute;
  @override
  int get hashCode => Object.hash(hour, minute);
}

class RosemaryDateRange {
  final RosemaryLocalDate start, end;
  RosemaryDateRange(this.start, this.end) {
    if (start.compareTo(end) > 0)
      throw ArgumentError('End must not precede start');
  }
}

enum RosemaryDateMode { date, time, dateTime, range }

class RosemaryDate extends StatefulWidget {
  final RosemaryLocalDate? value;
  final ValueChanged<RosemaryLocalDate>? onChanged;
  final RosemaryLocalTime? time;
  final ValueChanged<RosemaryLocalTime>? onTimeChanged;
  final RosemaryDateRange? range;
  final ValueChanged<RosemaryDateRange>? onRangeChanged;
  final RosemaryDateMode mode;
  final String label;
  final bool enabled;
  final bool? expanded;
  final ValueChanged<bool>? onOpenChanged;
  const RosemaryDate({
    super.key,
    this.value,
    this.onChanged,
    this.time,
    this.onTimeChanged,
    this.range,
    this.onRangeChanged,
    this.mode = RosemaryDateMode.date,
    required this.label,
    this.enabled = true,
    this.expanded,
    this.onOpenChanged,
  });
  @override
  State<RosemaryDate> createState() => _DateState();
}

class _DateState extends State<RosemaryDate> {
  bool internalOpen = false;
  RosemaryLocalDate draft = RosemaryLocalDate(2000, 1, 1);
  RosemaryLocalTime timeDraft = RosemaryLocalTime(0, 0);
  late String dateText, endText, timeText;
  String? error;
  final trigger = FocusNode();
  final panelScope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  bool get open => widget.expanded ?? internalOpen;
  bool get dateMode => widget.mode != RosemaryDateMode.time;
  bool get timeMode =>
      widget.mode == RosemaryDateMode.time ||
      widget.mode == RosemaryDateMode.dateTime;
  void initialize() {
    draft =
        widget.range?.start ?? widget.value ?? RosemaryLocalDate(2000, 1, 1);
    timeDraft = widget.time ?? RosemaryLocalTime(0, 0);
    dateText = (widget.range?.start ?? widget.value)?.toString() ?? '';
    endText = widget.range?.end.toString() ?? '';
    timeText = widget.time?.toString() ?? '';
    error = null;
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void didUpdateWidget(RosemaryDate old) {
    super.didUpdateWidget(old);
    if (!open &&
        (old.value != widget.value ||
            old.time != widget.time ||
            old.range != widget.range))
      initialize();
    if (old.expanded != true && widget.expanded == true) initialize();
    if (!widget.enabled && open)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) changeOpen(false);
      });
  }

  void changeOpen(bool value, {bool restoreFocus = true}) {
    if (value == open) return;
    initialize();
    setState(() => internalOpen = value);
    widget.onOpenChanged?.call(value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (value && open) panelScope.requestFocus();
      if (!value && !open && restoreFocus) trigger.requestFocus();
    });
  }

  void apply() {
    final date = RosemaryLocalDate.parse(dateText),
        end = RosemaryLocalDate.parse(endText),
        time = RosemaryLocalTime.parse(timeText);
    if (dateMode && date == null) {
      setState(() => error = 'Invalid date');
      return;
    }
    if (timeMode && time == null) {
      setState(() => error = 'Invalid time');
      return;
    }
    if (widget.mode == RosemaryDateMode.range &&
        (end == null || end.compareTo(date!) < 0)) {
      setState(() => error = 'End must not precede start');
      return;
    }
    if (widget.mode == RosemaryDateMode.range) {
      widget.onRangeChanged?.call(RosemaryDateRange(date!, end!));
    } else if (dateMode) {
      widget.onChanged?.call(date!);
    }
    if (timeMode) widget.onTimeChanged?.call(time!);
    if (open) {
      changeOpen(false);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !open) setState(initialize);
      });
    }
  }

  @override
  void dispose() {
    trigger.dispose();
    panelScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TapRegion(
    onTapOutside: (_) {
      if (open) changeOpen(false, restoreFocus: false);
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: RosemaryTokens.spacing[1],
      children: [
        Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (widget.enabled) changeOpen(true);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            spacing: RosemaryTokens.spacing[1],
            children: [
              if (dateMode)
                RosemaryInput(
                  value: dateText,
                  label:
                      '${widget.label} ${rString(context, 'Date (YYYY-MM-DD)')}',
                  enabled: widget.enabled,
                  onCommit: apply,
                  onChanged: (v) => setState(() {
                    dateText = v;
                    error = null;
                    final parsed = RosemaryLocalDate.parse(v);
                    if (parsed != null) draft = parsed;
                  }),
                ),
              if (widget.mode == RosemaryDateMode.range)
                RosemaryInput(
                  value: endText,
                  label: rString(context, 'End'),
                  enabled: widget.enabled,
                  onCommit: apply,
                  onChanged: (v) => setState(() {
                    endText = v;
                    error = null;
                  }),
                ),
              if (timeMode)
                RosemaryInput(
                  value: timeText,
                  label: rString(context, 'Time (HH:mm)'),
                  enabled: widget.enabled,
                  onCommit: apply,
                  onChanged: (v) => setState(() {
                    timeText = v;
                    error = null;
                    final parsed = RosemaryLocalTime.parse(v);
                    if (parsed != null) timeDraft = parsed;
                  }),
                ),
            ],
          ),
        ),
        RosemaryButton(
          label: rString(context, 'Choose'),
          onPressed: () => changeOpen(!open),
          enabled: widget.enabled,
          focusNode: trigger,
          leading: RosemaryIcon(timeMode ? 'clock' : 'calendar', size: 18),
          trailing: const RosemaryIcon('down', size: 18),
          variant: RosemaryButtonVariant.secondary,
        ),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: RosemaryText(
              rString(context, error!),
              color: RosemaryThemeData.of(context).danger,
            ),
          ),
        if (open && widget.enabled)
          FocusScope(
            node: panelScope,
            onFocusChange: (focused) {
              if (!focused && open) changeOpen(false, restoreFocus: false);
            },
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  changeOpen(false);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Semantics(
                label: widget.label,
                container: true,
                explicitChildNodes: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: RosemaryThemeData.of(context).surfaceFloating,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: MediaQuery.highContrastOf(context)
                          ? RosemaryThemeData.of(context).control
                          : RosemaryThemeData.of(context).edgeSoft,
                    ),
                    borderRadius: BorderRadius.circular(
                      RosemaryTokens.controlRadius,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(RosemaryTokens.spacing[2]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: RosemaryTokens.spacing[2],
                      children: [
                        if (dateMode)
                          RosemaryCalendar(
                            value: draft,
                            onChanged: (v) => setState(() {
                              draft = v;
                              dateText = v.toString();
                              error = null;
                            }),
                          ),
                        if (timeMode)
                          RosemaryTimeColumns(
                            value: timeDraft,
                            onChanged: (v) => setState(() {
                              timeDraft = v;
                              timeText = v.toString();
                              error = null;
                            }),
                          ),
                        Wrap(
                          spacing: RosemaryTokens.spacing[1],
                          runSpacing: RosemaryTokens.spacing[1],
                          children: [
                            RosemaryButton(
                              label: rString(context, 'Cancel'),
                              onPressed: () => changeOpen(false),
                              variant: RosemaryButtonVariant.secondary,
                            ),
                            RosemaryButton(
                              label: rString(context, 'Apply'),
                              onPressed: apply,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class RosemaryCalendar extends StatefulWidget {
  final RosemaryLocalDate value;
  final ValueChanged<RosemaryLocalDate> onChanged;
  const RosemaryCalendar({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  State<RosemaryCalendar> createState() => _CalendarState();
}

class _CalendarState extends State<RosemaryCalendar> {
  late int year, month, yearPage;
  late RosemaryLocalDate focused;
  String view = 'days', yearText = '';
  final grid = FocusNode();
  @override
  void initState() {
    super.initState();
    sync();
  }

  void sync() {
    year = widget.value.year;
    month = widget.value.month;
    focused = widget.value;
    yearPage = ((year - 1) ~/ 12) * 12 + 1;
    yearText = '$year';
  }

  @override
  void didUpdateWidget(RosemaryCalendar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      year = widget.value.year;
      month = widget.value.month;
      focused = widget.value;
      yearText = '$year';
    }
  }

  void shiftMonth(int delta) {
    final index = (year - 1) * 12 + month - 1 + delta;
    if (index < 0 || index >= 9999 * 12) return;
    setState(() {
      year = index ~/ 12 + 1;
      month = index % 12 + 1;
      focused = RosemaryLocalDate(
        year,
        month,
        focused.day.clamp(1, RosemaryLocalDate.daysInMonth(year, month)),
      );
    });
  }

  KeyEventResult key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    int? delta;
    if (key == LogicalKeyboardKey.arrowLeft)
      delta = Directionality.of(context) == TextDirection.rtl ? 1 : -1;
    if (key == LogicalKeyboardKey.arrowRight)
      delta = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    if (key == LogicalKeyboardKey.arrowUp) delta = -7;
    if (key == LogicalKeyboardKey.arrowDown) delta = 7;
    if (key == LogicalKeyboardKey.home) delta = 1 - focused.weekday;
    if (key == LogicalKeyboardKey.end) delta = 7 - focused.weekday;
    if (delta != null) {
      final next = focused.addDays(delta);
      if (next != null)
        setState(() {
          focused = next;
          year = next.year;
          month = next.month;
        });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.pageDown) {
      shiftMonth(
        (key == LogicalKeyboardKey.pageUp ? -1 : 1) *
            (HardwareKeyboard.instance.isControlPressed ? 12 : 1),
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      widget.onChanged(focused);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    grid.dispose();
    super.dispose();
  }

  Widget choice(
    String label,
    bool selected,
    VoidCallback activate, {
    String? semantics,
  }) {
    final c = RosemaryThemeData.of(context);
    return Semantics(
      button: true,
      label: semantics ?? label,
      selected: selected,
      onTap: activate,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: activate,
        excludeFromSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: RosemaryText(label, color: selected ? c.primary : c.ink),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = RosemaryLocalDate.daysInMonth(year, month),
        offset = RosemaryLocalDate(year, month, 1).weekday - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            RosemaryButton(
              label: year.toString().padLeft(4, '0'),
              trailing: const RosemaryIcon('down', size: 18),
              onPressed: () => setState(() {
                view = 'years';
                yearPage = ((year - 1) ~/ 12) * 12 + 1;
                yearText = '$year';
              }),
              variant: RosemaryButtonVariant.secondary,
            ),
            RosemaryButton(
              label: '$month',
              trailing: const RosemaryIcon('down', size: 18),
              onPressed: () => setState(() => view = 'months'),
              variant: RosemaryButtonVariant.secondary,
            ),
          ],
        ),
        if (view == 'years') ...[
          RosemaryInput(
            value: yearText,
            onChanged: (v) => setState(() {
              yearText = v;
              final next = int.tryParse(v);
              if (next != null && next >= 1 && next <= 9999) {
                year = next;
                yearPage = ((next - 1) ~/ 12) * 12 + 1;
              }
            }),
            label: rString(context, 'Year'),
            keyboardType: TextInputType.number,
            error:
                int.tryParse(yearText) == null ||
                    (int.tryParse(yearText) ?? 0) < 1 ||
                    (int.tryParse(yearText) ?? 0) > 9999
                ? rString(context, 'Invalid date')
                : null,
          ),
          for (var row = 0; row < 4; row++)
            Row(
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: yearPage + row * 3 + col > 9999
                        ? const SizedBox(height: 44)
                        : choice(
                            '${yearPage + row * 3 + col}',
                            year == yearPage + row * 3 + col,
                            () => setState(() {
                              year = yearPage + row * 3 + col;
                              view = 'months';
                            }),
                          ),
                  ),
              ],
            ),
          Wrap(
            children: [
              RosemaryButton(
                label: rString(context, 'Previous years'),
                onPressed: yearPage == 1
                    ? null
                    : () => setState(
                        () => yearPage = (yearPage - 12).clamp(1, 9997),
                      ),
                variant: RosemaryButtonVariant.text,
              ),
              RosemaryButton(
                label: rString(context, 'Next years'),
                onPressed: yearPage + 12 > 9999
                    ? null
                    : () => setState(() => yearPage += 12),
                variant: RosemaryButtonVariant.text,
              ),
            ],
          ),
        ] else if (view == 'months') ...[
          for (var row = 0; row < 4; row++)
            Row(
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: choice(
                      '${row * 3 + col + 1}',
                      month == row * 3 + col + 1,
                      () => setState(() {
                        month = row * 3 + col + 1;
                        focused = RosemaryLocalDate(
                          year,
                          month,
                          focused.day.clamp(
                            1,
                            RosemaryLocalDate.daysInMonth(year, month),
                          ),
                        );
                        view = 'days';
                      }),
                    ),
                  ),
              ],
            ),
        ] else ...[
          Row(
            children: [
              for (final day in [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ])
                Expanded(
                  child: RosemaryText(
                    rString(context, day),
                    role: 'caption',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          Focus(
            focusNode: grid,
            onKeyEvent: key,
            child: Semantics(
              label: '$year-$month',
              child: Column(
                children: [
                  for (var row = 0; row < (offset + days + 6) ~/ 7; row++)
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(
                            child:
                                row * 7 + col - offset + 1 < 1 ||
                                    row * 7 + col - offset + 1 > days
                                ? const SizedBox(height: 44)
                                : Builder(
                                    builder: (context) {
                                      final date = RosemaryLocalDate(
                                        year,
                                        month,
                                        row * 7 + col - offset + 1,
                                      );
                                      return DecoratedBox(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color:
                                                grid.hasFocus && date == focused
                                                ? RosemaryThemeData.of(
                                                    context,
                                                  ).focus
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: choice(
                                          '${date.day}',
                                          date == widget.value,
                                          () {
                                            setState(() => focused = date);
                                            grid.requestFocus();
                                            widget.onChanged(date);
                                          },
                                          semantics: date.toString(),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Wrap(
            children: [
              RosemaryButton(
                label: rString(context, 'Previous month'),
                onPressed: year == 1 && month == 1
                    ? null
                    : () => shiftMonth(-1),
                variant: RosemaryButtonVariant.text,
              ),
              RosemaryButton(
                label: rString(context, 'Next month'),
                onPressed: year == 9999 && month == 12
                    ? null
                    : () => shiftMonth(1),
                variant: RosemaryButtonVariant.text,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class RosemaryTimeColumns extends StatefulWidget {
  final RosemaryLocalTime value;
  final ValueChanged<RosemaryLocalTime> onChanged;
  const RosemaryTimeColumns({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  State<RosemaryTimeColumns> createState() => _TimeColumnsState();
}

class _TimeColumnsState extends State<RosemaryTimeColumns> {
  late final ScrollController hours, minutes;
  final hourFocus = FocusNode(debugLabel: 'Rosemary hours'),
      minuteFocus = FocusNode(debugLabel: 'Rosemary minutes');
  late int hour, minute;
  @override
  void initState() {
    super.initState();
    hour = widget.value.hour;
    minute = widget.value.minute;
    hours = ScrollController(
      initialScrollOffset: (hour - 1).clamp(0, 21) * 44.0,
    );
    minutes = ScrollController(
      initialScrollOffset: (minute - 1).clamp(0, 57) * 44.0,
    );
  }

  void reveal(bool isHour) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = isHour ? hours : minutes;
      final value = isHour ? hour : minute;
      if (controller.hasClients)
        controller.jumpTo(
          ((value - 1) * 44.0).clamp(0, controller.position.maxScrollExtent),
        );
    });
  }

  @override
  void didUpdateWidget(RosemaryTimeColumns old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      hour = widget.value.hour;
      minute = widget.value.minute;
      reveal(true);
      reveal(false);
    }
  }

  KeyEventResult key(bool isHour, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    final max = isHour ? 23 : 59;
    final current = isHour ? hour : minute;
    int? next;
    if (k == LogicalKeyboardKey.home) next = 0;
    if (k == LogicalKeyboardKey.end) next = max;
    if (k == LogicalKeyboardKey.arrowUp) next = (current - 1).clamp(0, max);
    if (k == LogicalKeyboardKey.arrowDown) next = (current + 1).clamp(0, max);
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight) {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final toHour = k == LogicalKeyboardKey.arrowLeft ? !rtl : rtl;
      (toHour ? hourFocus : minuteFocus).requestFocus();
      return KeyEventResult.handled;
    }
    if (next != null) {
      setState(() {
        if (isHour)
          hour = next!;
        else
          minute = next!;
      });
      reveal(isHour);
      widget.onChanged(RosemaryLocalTime(hour, minute));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) {
      widget.onChanged(RosemaryLocalTime(hour, minute));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    hours.dispose();
    minutes.dispose();
    hourFocus.dispose();
    minuteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final isHour in [true, false])
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RosemaryText(
                rString(context, isHour ? 'Hours' : 'Minutes'),
                role: 'small',
              ),
              Focus(
                focusNode: isHour ? hourFocus : minuteFocus,
                onKeyEvent: (node, event) => key(isHour, event),
                onFocusChange: (_) => setState(() {}),
                child: Semantics(
                  label: rString(context, isHour ? 'Hours' : 'Minutes'),
                  value: (isHour ? hour : minute).toString().padLeft(2, '0'),
                  child: SizedBox(
                    height: 132,
                    child: ListView.builder(
                      controller: isHour ? hours : minutes,
                      itemExtent: 44,
                      itemCount: isHour ? 24 : 60,
                      itemBuilder: (context, index) {
                        final selected = index == (isHour ? hour : minute);
                        return Semantics(
                          button: true,
                          selected: selected,
                          label: index.toString().padLeft(2, '0'),
                          onTap: () => widget.onChanged(
                            RosemaryLocalTime(
                              isHour ? index : hour,
                              isHour ? minute : index,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () {
                              (isHour ? hourFocus : minuteFocus).requestFocus();
                              widget.onChanged(
                                RosemaryLocalTime(
                                  isHour ? index : hour,
                                  isHour ? minute : index,
                                ),
                              );
                            },
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? RosemaryThemeData.of(context).primarySoft
                                    : null,
                                border: Border.all(
                                  color:
                                      selected &&
                                          (isHour ? hourFocus : minuteFocus)
                                              .hasFocus
                                      ? RosemaryThemeData.of(context).focus
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: RosemaryText(
                                index.toString().padLeft(2, '0'),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

enum RosemaryFileState {
  selected,
  validating,
  uploading,
  completed,
  error,
  cancelled,
}

class RosemaryFile {
  final String id, name, status;
  final double? progress;
  final bool canRetry, canCancel;
  final RosemaryFileState state;
  final String? error;
  const RosemaryFile({
    required this.id,
    required this.name,
    this.status = '',
    this.progress,
    this.canRetry = false,
    this.canCancel = false,
    this.state = RosemaryFileState.selected,
    this.error,
  });
}

class RosemaryUpload extends StatefulWidget {
  final String label;
  final List<RosemaryFile> files;
  final ValueChanged<List<XFile>> onFilesSelected;
  final ValueChanged<String>? onRemoved, onRetry, onCancel;
  final List<XTypeGroup> acceptedTypes;
  final bool enabled, multiple;
  final Future<List<XFile>> Function()? chooseFiles;
  final ValueChanged<Object>? onPickerError;
  const RosemaryUpload({
    super.key,
    required this.label,
    required this.files,
    required this.onFilesSelected,
    this.onRemoved,
    this.onRetry,
    this.onCancel,
    this.acceptedTypes = const [],
    this.enabled = true,
    this.multiple = true,
    this.chooseFiles,
    this.onPickerError,
  });
  @override
  State<RosemaryUpload> createState() => _UploadState();
}

class _UploadState extends State<RosemaryUpload> {
  bool choosing = false;
  bool pickerFailed = false;
  Future<void> choose() async {
    if (choosing || !widget.enabled) return;
    setState(() {
      choosing = true;
      pickerFailed = false;
    });
    try {
      final files = widget.chooseFiles != null
          ? await widget.chooseFiles!()
          : widget.multiple
          ? await openFiles(acceptedTypeGroups: widget.acceptedTypes)
          : [?await openFile(acceptedTypeGroups: widget.acceptedTypes)];
      if (mounted && widget.enabled && files.isNotEmpty)
        widget.onFilesSelected(files);
    } catch (error) {
      if (mounted) {
        setState(() => pickerFailed = true);
        widget.onPickerError?.call(error);
      }
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RosemaryText(widget.label),
      RosemaryButton(
        label: rString(context, 'Choose files'),
        onPressed: choose,
        enabled: widget.enabled,
        busy: choosing,
      ),
      if (pickerFailed)
        RosemaryText(
          rString(context, 'File selection failed'),
          color: RosemaryThemeData.of(context).danger,
        ),
      for (final file in widget.files)
        Column(
          key: ValueKey(file.id),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RosemaryText(file.name),
            if (file.progress != null ||
                file.state == RosemaryFileState.uploading)
              RosemaryProgress(
                value: file.progress,
                label: file.name,
                state: switch (file.state) {
                  RosemaryFileState.uploading => RosemaryProgressState.running,
                  RosemaryFileState.completed =>
                    RosemaryProgressState.completed,
                  RosemaryFileState.error => RosemaryProgressState.error,
                  RosemaryFileState.cancelled =>
                    RosemaryProgressState.cancelled,
                  _ => RosemaryProgressState.idle,
                },
              ),
            if (file.error != null)
              RosemaryText(
                file.error!,
                color: RosemaryThemeData.of(context).danger,
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RosemaryText(
                  file.status.isEmpty
                      ? rString(context, switch (file.state) {
                          RosemaryFileState.selected => 'Selected',
                          RosemaryFileState.validating => 'Validating',
                          RosemaryFileState.uploading => 'Uploading',
                          RosemaryFileState.completed => 'Completed',
                          RosemaryFileState.error => 'Error',
                          RosemaryFileState.cancelled => 'Cancelled',
                        })
                      : file.status,
                ),
                if (widget.onRemoved != null)
                  RosemaryButton(
                    label: '${rString(context, 'Remove')} ${file.name}',
                    enabled: widget.enabled,
                    onPressed: () => widget.onRemoved!(file.id),
                    variant: RosemaryButtonVariant.text,
                  ),
                if (file.canRetry && widget.onRetry != null)
                  RosemaryButton(
                    label: rString(context, 'Retry'),
                    semanticLabel: '${rString(context, 'Retry')} ${file.name}',
                    enabled: widget.enabled,
                    onPressed: () => widget.onRetry!(file.id),
                    variant: RosemaryButtonVariant.text,
                  ),
                if (file.canCancel && widget.onCancel != null)
                  RosemaryButton(
                    label: rString(context, 'Cancel'),
                    semanticLabel: '${rString(context, 'Cancel')} ${file.name}',
                    enabled: widget.enabled,
                    onPressed: () => widget.onCancel!(file.id),
                    variant: RosemaryButtonVariant.text,
                  ),
              ],
            ),
          ],
        ),
    ],
  );
}
