import 'dart:math' as math;
import 'dart:ui' show ColorSpace;
import 'package:flutter/material.dart';
import 'generated/rosemary_tokens.dart';

enum RosemaryThemeMode { inherit, system, light, dark }

/// Paired palettes imported without a platform-specific approximation.
class RosemaryColorScheme {
  final RosemaryColors light, dark;
  const RosemaryColorScheme({required this.light, required this.dark});
  static const defaults = RosemaryColorScheme(
    light: RosemaryTokens.light,
    dark: RosemaryTokens.dark,
  );
  factory RosemaryColorScheme.fromJson(Map<String, dynamic> document) {
    final modes = document['colors'] ?? document['themes'] ?? document;
    if (modes is! Map || modes['light'] is! Map || modes['dark'] is! Map)
      throw ArgumentError('Expected paired light/dark palettes');
    return RosemaryColorScheme(
      light: RosemaryColors.fromHex(
        Map<String, dynamic>.from(modes['light'] as Map),
      ),
      dark: RosemaryColors.fromHex(
        Map<String, dynamic>.from(modes['dark'] as Map),
      ),
    );
  }
}

enum RosemaryTone { neutral, info, success, warning, danger }

enum RosemaryDismissReason {
  confirm,
  cancel,
  outside,
  escape,
  back,
  programmatic,
  unmount,
}

typedef RosemaryStrings = String Function(String english);
String _identity(String key) => key;
String rosemaryChinese(String key) =>
    const <String, String>{
      'Choose': '请选择',
      'Expanded': '已展开',
      'Collapsed': '已收起',
      'Search': '搜索',
      'Clear': '清除',
      'Cancel': '取消',
      'Apply': '应用',
      'Close': '关闭',
      'Year': '年份',
      'Hours': '小时',
      'Minutes': '分钟',
      'Previous month': '上个月',
      'Next month': '下个月',
      'Previous years': '前十二年',
      'Next years': '后十二年',
      'Date (YYYY-MM-DD)': '日期 (YYYY-MM-DD)',
      'Time (HH:mm)': '时间 (HH:mm)',
      'Invalid date': '日期无效',
      'Invalid time': '时间无效',
      'End must not precede start': '结束日期不能早于开始日期',
      'Start': '开始日期',
      'End': '结束日期',
      'Choose files': '选择文件',
      'Remove': '移除',
      'Retry': '重试',
      'Loading': '正在加载',
      'Completed': '已完成',
      'Cancelled': '已取消',
      'Error': '错误',
      'Timeout': '超时',
      'In progress': '进行中',
      'Indeterminate': '进度未知',
      'Paused': '已暂停',
      'Not started': '尚未开始',
      'Selected': '已选择',
      'Validating': '校验中',
      'Uploading': '上传中',
      'File selection failed': '文件选择失败',
      'Breadcrumb': '面包屑导航',
      'Current step': '当前步骤',
      'Unavailable': '不可进入',
      'Previous': '上一页',
      'Next': '下一页',
      'Mon': '一',
      'Tue': '二',
      'Wed': '三',
      'Thu': '四',
      'Fri': '五',
      'Sat': '六',
      'Sun': '日',
      'Mixed': '部分选中',
      'On': '开',
      'Off': '关',
      'Ascending': '升序',
      'Descending': '降序',
    }[key] ??
    key;

@immutable
class RosemaryThemeData extends ThemeExtension<RosemaryThemeData> {
  final RosemaryColors colors;
  final bool reduceMotion;
  final bool isDark;
  final RosemaryStrings strings;
  const RosemaryThemeData({
    required this.colors,
    this.reduceMotion = false,
    this.isDark = false,
    this.strings = _identity,
  });
  static RosemaryThemeData of(BuildContext context) =>
      _RosemaryScope.maybeOf(context)?.data ??
      Theme.of(context).extension<RosemaryThemeData>() ??
      const RosemaryThemeData(colors: RosemaryTokens.light);
  Color get canvas => colors.canvas;
  Color get surface => colors.surface;
  Color get raised => colors.raised;
  Color get ink => colors.ink;
  Color get muted => colors.muted;
  Color get border => colors.border;
  Color get control => colors.control;
  Color get primary => colors.primary;
  Color get onPrimary => colors.onPrimary;
  Color get primarySoft => colors.primarySoft;
  Color get sun => colors.sun;
  Color get onSun => colors.onSun;
  Color get sky => colors.sky;
  Color get onSky => colors.onSky;
  Color get success => colors.success;
  Color get successSoft => colors.successSoft;
  Color get warning => colors.warning;
  Color get warningSoft => colors.warningSoft;
  Color get danger => colors.danger;
  Color get dangerSoft => colors.dangerSoft;
  Color get onDanger => colors.onDanger;
  Color get info => colors.info;
  Color get infoSoft => colors.infoSoft;
  Color get focus => colors.focus;
  Color get surfaceNavigation => colors.surfaceNavigation;
  Color get onNavigation => colors.onNavigation;
  Color get navigationMuted => colors.navigationMuted;
  Color get navigationActive => colors.navigationActive;
  Color get onNavigationActive => colors.onNavigationActive;
  Color get surfaceTopbar => colors.surfaceTopbar;
  Color get onTopbar => colors.onTopbar;
  Color get onTopbarMuted => colors.onTopbarMuted;
  Color get topbarControl => colors.topbarControl;
  Color get surfaceGroup => colors.surfaceGroup;
  Color get surfaceInset => colors.surfaceInset;
  Color get surfaceFloating => colors.surfaceFloating;
  Color get fieldFill => colors.fieldFill;
  Color get fieldHover => colors.fieldHover;
  Color get fieldLine => colors.fieldLine;
  Color get fieldLineHover => colors.fieldLineHover;
  Color get edgeSoft => colors.edgeSoft;
  Color get secondaryContainer => colors.secondaryContainer;
  Color get onSecondaryContainer => colors.onSecondaryContainer;
  Color get tertiaryContainer => colors.tertiaryContainer;
  Color get onTertiaryContainer => colors.onTertiaryContainer;

  RosemaryThemeData copyWith({
    RosemaryColors? colors,
    bool? reduceMotion,
    bool? isDark,
    RosemaryStrings? strings,
  }) => RosemaryThemeData(
    colors: colors ?? this.colors,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    isDark: isDark ?? this.isDark,
    strings: strings ?? this.strings,
  );
  @override
  RosemaryThemeData lerp(covariant RosemaryThemeData? other, double t) =>
      other == null
      ? this
      : RosemaryThemeData(
          colors: colors.lerp(other.colors, t),
          reduceMotion: t < .5 ? reduceMotion : other.reduceMotion,
          isDark: t < .5 ? isDark : other.isDark,
          strings: t < .5 ? strings : other.strings,
        );
}

class RosemaryContrastDiagnostic {
  final String foreground, background;
  final double ratio, target;
  const RosemaryContrastDiagnostic(
    this.foreground,
    this.background,
    this.ratio,
    this.target,
  );
  bool get passes => ratio >= target;
}

double rosemaryContrast(Color foreground, Color background) {
  double luminance(Color value) {
    final c = value.withValues(colorSpace: ColorSpace.sRGB);
    double linear(double v) =>
        v <= .04045 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
    return .2126 * linear(c.r) + .7152 * linear(c.g) + .0722 * linear(c.b);
  }

  final a = luminance(foreground), b = luminance(background);
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

List<RosemaryContrastDiagnostic> rosemaryValidateTheme(RosemaryColors colors) {
  final roles = colors.toMap();
  for (final entry in roles.entries) {
    final c = entry.value;
    if (c.colorSpace != ColorSpace.sRGB ||
        c.a != 1 ||
        ![c.r, c.g, c.b, c.a].every((v) => v.isFinite && v >= 0 && v <= 1)) {
      throw ArgumentError(
        '${entry.key} must be an opaque finite sRGB color; convert wide-gamut colors explicitly',
      );
    }
  }
  return List.unmodifiable(
    RosemaryTokens.contrastPairs.map(
      (p) => RosemaryContrastDiagnostic(
        p.foreground,
        p.background,
        rosemaryContrast(roles[p.foreground]!, roles[p.background]!),
        p.target,
      ),
    ),
  );
}

class RosemaryTheme extends StatefulWidget {
  final Widget child;
  final RosemaryThemeMode mode;
  final RosemaryColors? colors, highContrastColors;
  final RosemaryColorScheme? scheme;
  final bool reduceMotion;
  final TextDirection? direction;
  final Locale? locale;
  final RosemaryStrings? strings;
  final ValueChanged<List<RosemaryContrastDiagnostic>>? onContrastDiagnostics;
  const RosemaryTheme({
    super.key,
    required this.child,
    this.mode = RosemaryThemeMode.inherit,
    this.colors,
    this.scheme,
    this.highContrastColors,
    this.reduceMotion = false,
    this.direction,
    this.locale,
    this.strings,
    this.onContrastDiagnostics,
  });
  @override
  State<RosemaryTheme> createState() => _ThemeState();
}

class _ThemeState extends State<RosemaryTheme> {
  Map<String, Color>? previousPalette;
  int notification = 0;
  @override
  Widget build(BuildContext context) {
    final mode = widget.mode,
        colors = widget.colors,
        reduceMotion = widget.reduceMotion,
        direction = widget.direction,
        locale = widget.locale,
        strings = widget.strings,
        child = widget.child;
    final ancestor = _RosemaryScope.maybeOf(context)?.data;
    final dark = switch (mode) {
      RosemaryThemeMode.dark => true,
      RosemaryThemeMode.light => false,
      RosemaryThemeMode.inherit =>
        ancestor?.isDark ??
            (MediaQuery.platformBrightnessOf(context) == Brightness.dark),
      RosemaryThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    final effectiveLocale = locale ?? Localizations.maybeLocaleOf(context);
    final palette =
        (MediaQuery.highContrastOf(context)
            ? widget.highContrastColors
            : null) ??
        colors ??
        (mode == RosemaryThemeMode.inherit &&
                ancestor != null &&
                widget.scheme == null
            ? ancestor.colors
            : dark
            ? (widget.scheme ?? RosemaryColorScheme.defaults).dark
            : (widget.scheme ?? RosemaryColorScheme.defaults).light);
    final diagnostics = rosemaryValidateTheme(palette);
    final roles = palette.toMap();
    if (previousPalette == null ||
        roles.entries.any((e) => previousPalette![e.key] != e.value)) {
      previousPalette = Map.unmodifiable(roles);
      final generation = ++notification;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && notification == generation)
          widget.onContrastDiagnostics?.call(diagnostics);
      });
    }
    final data = RosemaryThemeData(
      colors: palette,
      isDark: dark,
      reduceMotion:
          reduceMotion ||
          (ancestor?.reduceMotion ?? false) ||
          MediaQuery.disableAnimationsOf(context),
      strings:
          strings ??
          (locale != null
              ? (locale.languageCode == 'zh' ? rosemaryChinese : _identity)
              : ancestor?.strings ??
                    (effectiveLocale?.languageCode == 'zh'
                        ? rosemaryChinese
                        : _identity)),
    );
    return _RosemaryScope(
      data: data,
      child: Theme(
        data: Theme.of(context).copyWith(
          extensions: [
            ...Theme.of(
              context,
            ).extensions.values.where((e) => e is! RosemaryThemeData),
            data,
          ],
        ),
        child: Localizations.override(
          context: context,
          locale: effectiveLocale,
          child: Directionality(
            textDirection: direction ?? Directionality.of(context),
            child: DefaultTextStyle(
              style: rosemaryTextStyle(context, 'body', colors: palette),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _RosemaryScope extends InheritedTheme {
  final RosemaryThemeData data;
  const _RosemaryScope({required this.data, required super.child});
  static _RosemaryScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RosemaryScope>();
  @override
  bool updateShouldNotify(_RosemaryScope old) => old.data != data;
  @override
  Widget wrap(BuildContext context, Widget child) =>
      _RosemaryScope(data: data, child: child);
}

TextStyle rosemaryTextStyle(
  BuildContext context,
  String role, {
  RosemaryColors? colors,
  Color? color,
}) {
  final value = RosemaryTokens.typography.roles[role];
  if (value == null) throw ArgumentError.value(role, 'role');
  final fonts = RosemaryTokens.typography.families[value.family]!
      .split(',')
      .map((s) => s.trim())
      .toList();
  return TextStyle(
    fontSize: value.fontSize,
    height: value.lineHeight,
    fontWeight: FontWeight.values[(value.weight ~/ 100 - 1).clamp(0, 8)],
    fontFamily: fonts.first,
    fontFamilyFallback: fonts.skip(1).toList(),
    color: color ?? colors?.ink ?? RosemaryThemeData.of(context).ink,
  );
}

double rosemaryDimension(String component, String dimension) =>
    RosemaryTokens.componentTokens[component]!.dimensions[dimension] ??
    (throw ArgumentError('$component.$dimension'));
int rosemaryMotion(String name) =>
    RosemaryTokens.motion.durations[name] ??
    (throw ArgumentError.value(name, 'motion'));
Duration rosemaryDuration(BuildContext context, String name) => Duration(
  milliseconds: RosemaryThemeData.of(context).reduceMotion
      ? 0
      : rosemaryMotion(name),
);
String rString(BuildContext context, String key) =>
    RosemaryThemeData.of(context).strings(key);

class RosemaryText extends StatelessWidget {
  final String text, role;
  final Color? color;
  final TextAlign? textAlign;
  const RosemaryText(
    this.text, {
    super.key,
    this.role = 'body',
    this.color,
    this.textAlign,
  });
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: rosemaryTextStyle(context, role, color: color),
    textAlign: textAlign,
  );
}

/// Captures both InheritedTheme and the non-theme context required by overlays.
class RosemaryOverlaySnapshot {
  final CapturedThemes themes;
  final TextDirection direction;
  final MediaQueryData media;
  final Locale? locale;
  final BuildContext source;
  RosemaryOverlaySnapshot._(
    this.themes,
    this.direction,
    this.media,
    this.locale,
    this.source,
  );
  factory RosemaryOverlaySnapshot.capture(
    BuildContext source,
    BuildContext destination,
  ) => RosemaryOverlaySnapshot._(
    InheritedTheme.capture(from: source, to: destination),
    Directionality.of(source),
    MediaQuery.of(source),
    Localizations.maybeLocaleOf(source),
    source,
  );
  Widget wrap(Widget child) {
    final wrapped = themes.wrap(
      Directionality(
        textDirection: direction,
        child: MediaQuery(data: media, child: child),
      ),
    );
    return locale == null
        ? wrapped
        : Localizations.override(
            context: source,
            locale: locale,
            child: wrapped,
          );
  }
}
