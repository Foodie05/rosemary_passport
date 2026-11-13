// Generated from design/tokens.json. Do not edit; run pnpm design:generate.
import 'dart:ui';
class RosemaryMotion { final Map<String,int> durations; final String easing; const RosemaryMotion(this.durations,this.easing); }
class RosemaryTypeRole { final String family; final double fontSize, lineHeight; final int weight; const RosemaryTypeRole(this.family,this.fontSize,this.lineHeight,this.weight); }
class RosemaryTypography { final Map<String,String> families; final Map<String,RosemaryTypeRole> roles; final Map<String,double> lineHeights; final Map<String,int> weights; const RosemaryTypography(this.families,this.roles,this.lineHeights,this.weights); }
class RosemaryComponentToken { final String foreground, background, focus, border, radiusRole; final double radius; final Map<String,double> dimensions; final Map<String,String> behavior; final Map<String,bool> flags; final List<double> sizes; const RosemaryComponentToken(this.foreground,this.background,this.focus,this.border,this.radiusRole,this.radius,this.dimensions,this.behavior,this.flags,this.sizes); }
class RosemaryContrastPair { final String foreground, background; final double target; const RosemaryContrastPair(this.foreground,this.background,this.target); }
class RosemaryColors {
  final Color canvas;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color border;
  final Color control;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color sun;
  final Color onSun;
  final Color sky;
  final Color onSky;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color onDanger;
  final Color info;
  final Color infoSoft;
  final Color focus;
  final Color surfaceNavigation;
  final Color onNavigation;
  final Color navigationMuted;
  final Color navigationActive;
  final Color onNavigationActive;
  final Color surfaceTopbar;
  final Color onTopbar;
  final Color onTopbarMuted;
  final Color topbarControl;
  final Color surfaceGroup;
  final Color surfaceInset;
  final Color surfaceFloating;
  final Color fieldFill;
  final Color fieldHover;
  final Color fieldLine;
  final Color fieldLineHover;
  final Color edgeSoft;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  const RosemaryColors({required this.canvas, required this.surface, required this.raised, required this.ink, required this.muted, required this.border, required this.control, required this.primary, required this.onPrimary, required this.primarySoft, required this.sun, required this.onSun, required this.sky, required this.onSky, required this.success, required this.successSoft, required this.warning, required this.warningSoft, required this.danger, required this.dangerSoft, required this.onDanger, required this.info, required this.infoSoft, required this.focus, required this.surfaceNavigation, required this.onNavigation, required this.navigationMuted, required this.navigationActive, required this.onNavigationActive, required this.surfaceTopbar, required this.onTopbar, required this.onTopbarMuted, required this.topbarControl, required this.surfaceGroup, required this.surfaceInset, required this.surfaceFloating, required this.fieldFill, required this.fieldHover, required this.fieldLine, required this.fieldLineHover, required this.edgeSoft, required this.secondaryContainer, required this.onSecondaryContainer, required this.tertiaryContainer, required this.onTertiaryContainer});
  RosemaryColors copyWith({Color? canvas, Color? surface, Color? raised, Color? ink, Color? muted, Color? border, Color? control, Color? primary, Color? onPrimary, Color? primarySoft, Color? sun, Color? onSun, Color? sky, Color? onSky, Color? success, Color? successSoft, Color? warning, Color? warningSoft, Color? danger, Color? dangerSoft, Color? onDanger, Color? info, Color? infoSoft, Color? focus, Color? surfaceNavigation, Color? onNavigation, Color? navigationMuted, Color? navigationActive, Color? onNavigationActive, Color? surfaceTopbar, Color? onTopbar, Color? onTopbarMuted, Color? topbarControl, Color? surfaceGroup, Color? surfaceInset, Color? surfaceFloating, Color? fieldFill, Color? fieldHover, Color? fieldLine, Color? fieldLineHover, Color? edgeSoft, Color? secondaryContainer, Color? onSecondaryContainer, Color? tertiaryContainer, Color? onTertiaryContainer}) => RosemaryColors(canvas: canvas ?? this.canvas, surface: surface ?? this.surface, raised: raised ?? this.raised, ink: ink ?? this.ink, muted: muted ?? this.muted, border: border ?? this.border, control: control ?? this.control, primary: primary ?? this.primary, onPrimary: onPrimary ?? this.onPrimary, primarySoft: primarySoft ?? this.primarySoft, sun: sun ?? this.sun, onSun: onSun ?? this.onSun, sky: sky ?? this.sky, onSky: onSky ?? this.onSky, success: success ?? this.success, successSoft: successSoft ?? this.successSoft, warning: warning ?? this.warning, warningSoft: warningSoft ?? this.warningSoft, danger: danger ?? this.danger, dangerSoft: dangerSoft ?? this.dangerSoft, onDanger: onDanger ?? this.onDanger, info: info ?? this.info, infoSoft: infoSoft ?? this.infoSoft, focus: focus ?? this.focus, surfaceNavigation: surfaceNavigation ?? this.surfaceNavigation, onNavigation: onNavigation ?? this.onNavigation, navigationMuted: navigationMuted ?? this.navigationMuted, navigationActive: navigationActive ?? this.navigationActive, onNavigationActive: onNavigationActive ?? this.onNavigationActive, surfaceTopbar: surfaceTopbar ?? this.surfaceTopbar, onTopbar: onTopbar ?? this.onTopbar, onTopbarMuted: onTopbarMuted ?? this.onTopbarMuted, topbarControl: topbarControl ?? this.topbarControl, surfaceGroup: surfaceGroup ?? this.surfaceGroup, surfaceInset: surfaceInset ?? this.surfaceInset, surfaceFloating: surfaceFloating ?? this.surfaceFloating, fieldFill: fieldFill ?? this.fieldFill, fieldHover: fieldHover ?? this.fieldHover, fieldLine: fieldLine ?? this.fieldLine, fieldLineHover: fieldLineHover ?? this.fieldLineHover, edgeSoft: edgeSoft ?? this.edgeSoft, secondaryContainer: secondaryContainer ?? this.secondaryContainer, onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer, tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer, onTertiaryContainer: onTertiaryContainer ?? this.onTertiaryContainer);
  RosemaryColors lerp(RosemaryColors other, double t) => RosemaryColors(canvas: Color.lerp(canvas, other.canvas, t)!, surface: Color.lerp(surface, other.surface, t)!, raised: Color.lerp(raised, other.raised, t)!, ink: Color.lerp(ink, other.ink, t)!, muted: Color.lerp(muted, other.muted, t)!, border: Color.lerp(border, other.border, t)!, control: Color.lerp(control, other.control, t)!, primary: Color.lerp(primary, other.primary, t)!, onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!, primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!, sun: Color.lerp(sun, other.sun, t)!, onSun: Color.lerp(onSun, other.onSun, t)!, sky: Color.lerp(sky, other.sky, t)!, onSky: Color.lerp(onSky, other.onSky, t)!, success: Color.lerp(success, other.success, t)!, successSoft: Color.lerp(successSoft, other.successSoft, t)!, warning: Color.lerp(warning, other.warning, t)!, warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!, danger: Color.lerp(danger, other.danger, t)!, dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!, onDanger: Color.lerp(onDanger, other.onDanger, t)!, info: Color.lerp(info, other.info, t)!, infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!, focus: Color.lerp(focus, other.focus, t)!, surfaceNavigation: Color.lerp(surfaceNavigation, other.surfaceNavigation, t)!, onNavigation: Color.lerp(onNavigation, other.onNavigation, t)!, navigationMuted: Color.lerp(navigationMuted, other.navigationMuted, t)!, navigationActive: Color.lerp(navigationActive, other.navigationActive, t)!, onNavigationActive: Color.lerp(onNavigationActive, other.onNavigationActive, t)!, surfaceTopbar: Color.lerp(surfaceTopbar, other.surfaceTopbar, t)!, onTopbar: Color.lerp(onTopbar, other.onTopbar, t)!, onTopbarMuted: Color.lerp(onTopbarMuted, other.onTopbarMuted, t)!, topbarControl: Color.lerp(topbarControl, other.topbarControl, t)!, surfaceGroup: Color.lerp(surfaceGroup, other.surfaceGroup, t)!, surfaceInset: Color.lerp(surfaceInset, other.surfaceInset, t)!, surfaceFloating: Color.lerp(surfaceFloating, other.surfaceFloating, t)!, fieldFill: Color.lerp(fieldFill, other.fieldFill, t)!, fieldHover: Color.lerp(fieldHover, other.fieldHover, t)!, fieldLine: Color.lerp(fieldLine, other.fieldLine, t)!, fieldLineHover: Color.lerp(fieldLineHover, other.fieldLineHover, t)!, edgeSoft: Color.lerp(edgeSoft, other.edgeSoft, t)!, secondaryContainer: Color.lerp(secondaryContainer, other.secondaryContainer, t)!, onSecondaryContainer: Color.lerp(onSecondaryContainer, other.onSecondaryContainer, t)!, tertiaryContainer: Color.lerp(tertiaryContainer, other.tertiaryContainer, t)!, onTertiaryContainer: Color.lerp(onTertiaryContainer, other.onTertiaryContainer, t)!);
  factory RosemaryColors.fromHex(Map<String,dynamic> values) {
    const roles = ["canvas","surface","raised","ink","muted","border","control","primary","on-primary","primary-soft","sun","on-sun","sky","on-sky","success","success-soft","warning","warning-soft","danger","danger-soft","on-danger","info","info-soft","focus","surface-navigation","on-navigation","navigation-muted","navigation-active","on-navigation-active","surface-topbar","on-topbar","on-topbar-muted","topbar-control","surface-group","surface-inset","surface-floating","field-fill","field-hover","field-line","field-line-hover","edge-soft","secondary-container","on-secondary-container","tertiary-container","on-tertiary-container"];
    if(values.length != roles.length || values.keys.any((k)=>!roles.contains(k))) throw ArgumentError('Expected all 45 semantic roles');
    Color color(String name) { final value=values[name]; if(value is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) throw ArgumentError('Invalid color: '+name); return Color(0xFF000000 | int.parse(value.substring(1),radix:16)); }
    return RosemaryColors(canvas: color("canvas"), surface: color("surface"), raised: color("raised"), ink: color("ink"), muted: color("muted"), border: color("border"), control: color("control"), primary: color("primary"), onPrimary: color("on-primary"), primarySoft: color("primary-soft"), sun: color("sun"), onSun: color("on-sun"), sky: color("sky"), onSky: color("on-sky"), success: color("success"), successSoft: color("success-soft"), warning: color("warning"), warningSoft: color("warning-soft"), danger: color("danger"), dangerSoft: color("danger-soft"), onDanger: color("on-danger"), info: color("info"), infoSoft: color("info-soft"), focus: color("focus"), surfaceNavigation: color("surface-navigation"), onNavigation: color("on-navigation"), navigationMuted: color("navigation-muted"), navigationActive: color("navigation-active"), onNavigationActive: color("on-navigation-active"), surfaceTopbar: color("surface-topbar"), onTopbar: color("on-topbar"), onTopbarMuted: color("on-topbar-muted"), topbarControl: color("topbar-control"), surfaceGroup: color("surface-group"), surfaceInset: color("surface-inset"), surfaceFloating: color("surface-floating"), fieldFill: color("field-fill"), fieldHover: color("field-hover"), fieldLine: color("field-line"), fieldLineHover: color("field-line-hover"), edgeSoft: color("edge-soft"), secondaryContainer: color("secondary-container"), onSecondaryContainer: color("on-secondary-container"), tertiaryContainer: color("tertiary-container"), onTertiaryContainer: color("on-tertiary-container"));
  }
  Map<String,Color> toMap() => {'canvas': canvas, 'surface': surface, 'raised': raised, 'ink': ink, 'muted': muted, 'border': border, 'control': control, 'primary': primary, 'on-primary': onPrimary, 'primary-soft': primarySoft, 'sun': sun, 'on-sun': onSun, 'sky': sky, 'on-sky': onSky, 'success': success, 'success-soft': successSoft, 'warning': warning, 'warning-soft': warningSoft, 'danger': danger, 'danger-soft': dangerSoft, 'on-danger': onDanger, 'info': info, 'info-soft': infoSoft, 'focus': focus, 'surface-navigation': surfaceNavigation, 'on-navigation': onNavigation, 'navigation-muted': navigationMuted, 'navigation-active': navigationActive, 'on-navigation-active': onNavigationActive, 'surface-topbar': surfaceTopbar, 'on-topbar': onTopbar, 'on-topbar-muted': onTopbarMuted, 'topbar-control': topbarControl, 'surface-group': surfaceGroup, 'surface-inset': surfaceInset, 'surface-floating': surfaceFloating, 'field-fill': fieldFill, 'field-hover': fieldHover, 'field-line': fieldLine, 'field-line-hover': fieldLineHover, 'edge-soft': edgeSoft, 'secondary-container': secondaryContainer, 'on-secondary-container': onSecondaryContainer, 'tertiary-container': tertiaryContainer, 'on-tertiary-container': onTertiaryContainer};
}
class RosemaryTokens {
  static const sdkVersion = '0.5.0';
  static const specVersion = '1.3.0';
  static const light = RosemaryColors(
    canvas: Color(0xFFFEF7FC),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    ink: Color(0xFF1D1B1E),
    muted: Color(0xFF494649),
    border: Color(0xFFD0CACF),
    control: Color(0xFF6D696D),
    primary: Color(0xFF6A4E81),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFF6EAF9),
    sun: Color(0xFFFFEADE),
    onSun: Color(0xFF4B270C),
    sky: Color(0xFFFFE8F6),
    onSky: Color(0xFF3F2A3A),
    success: Color(0xFF235D37),
    successSoft: Color(0xFFEEF6EB),
    warning: Color(0xFF654900),
    warningSoft: Color(0xFFFFF2E0),
    danger: Color(0xFF972C25),
    dangerSoft: Color(0xFFFFF0EE),
    onDanger: Color(0xFFFFFFFF),
    info: Color(0xFF1B577E),
    infoSoft: Color(0xFFEFF4FC),
    focus: Color(0xFF563B6D),
    surfaceNavigation: Color(0xFFEFE5F0),
    onNavigation: Color(0xFF342E37),
    navigationMuted: Color(0xFF4B454D),
    navigationActive: Color(0xFF785D8E),
    onNavigationActive: Color(0xFFFFFFFF),
    surfaceTopbar: Color(0xFFFDF0F7),
    onTopbar: Color(0xFF352E33),
    onTopbarMuted: Color(0xFF4C454A),
    topbarControl: Color(0xFFEEE2E9),
    surfaceGroup: Color(0xFFFFFFFF),
    surfaceInset: Color(0xFFF6EFF3),
    surfaceFloating: Color(0xFFFFFFFF),
    fieldFill: Color(0xFFF3ECF1),
    fieldHover: Color(0xFFEDE6EB),
    fieldLine: Color(0xFF6D696D),
    fieldLineHover: Color(0xFF5C585C),
    edgeSoft: Color(0xFFD9D3D7),
    secondaryContainer: Color(0xFFFFE8F6),
    onSecondaryContainer: Color(0xFF3F2A3A),
    tertiaryContainer: Color(0xFFFFEADE),
    onTertiaryContainer: Color(0xFF4B270C),
  );
  static const dark = RosemaryColors(
    canvas: Color(0xFF211F22),
    surface: Color(0xFF2E2B2F),
    raised: Color(0xFF3B383C),
    ink: Color(0xFFF6EFF3),
    muted: Color(0xFFC5BFC4),
    border: Color(0xFF5A565A),
    control: Color(0xFFAFAAAE),
    primary: Color(0xFFDCB9F5),
    onPrimary: Color(0xFF3A2050),
    primarySoft: Color(0xFF403944),
    sun: Color(0xFF4A372B),
    onSun: Color(0xFFFFDCC7),
    sky: Color(0xFF463742),
    onSky: Color(0xFFFAD9F0),
    success: Color(0xFF97D5A5),
    successSoft: Color(0xFF2F3730),
    warning: Color(0xFFF3C666),
    warningSoft: Color(0xFF3B3428),
    danger: Color(0xFFFFB4AB),
    dangerSoft: Color(0xFF403130),
    onDanger: Color(0xFF540003),
    info: Color(0xFF98CCF9),
    infoSoft: Color(0xFF30353B),
    focus: Color(0xFFEED3FF),
    surfaceNavigation: Color(0xFF18141B),
    onNavigation: Color(0xFFEFE5F0),
    navigationMuted: Color(0xFFC7BEC9),
    navigationActive: Color(0xFF785D8E),
    onNavigationActive: Color(0xFFFFFFFF),
    surfaceTopbar: Color(0xFF201A1E),
    onTopbar: Color(0xFFF1E5EB),
    onTopbarMuted: Color(0xFFC9BEC4),
    topbarControl: Color(0xFF352E33),
    surfaceGroup: Color(0xFF2E2B2F),
    surfaceInset: Color(0xFF322F33),
    surfaceFloating: Color(0xFF3B383C),
    fieldFill: Color(0xFF373437),
    fieldHover: Color(0xFF3E3A3E),
    fieldLine: Color(0xFFAFAAAE),
    fieldLineHover: Color(0xFFC5BFC4),
    edgeSoft: Color(0xFF575458),
    secondaryContainer: Color(0xFF463742),
    onSecondaryContainer: Color(0xFFFAD9F0),
    tertiaryContainer: Color(0xFF4A372B),
    onTertiaryContainer: Color(0xFFFFDCC7),
  );
  static const contentMax = 1480.0;
  static const gridGap = 24.0;
  static const compactGridGap = 16.0;
  static const shellHeight = 76.0;
  static const headerIconSize = 20.0;
  static const controlRadius = 8.0;
  static const contentRadius = 12.0;
  static const dialogRadius = 20.0;
  static const touchTarget = 44.0;
  static const buttonSmallHeight = 32.0;
  static const buttonMediumHeight = 40.0;
  static const buttonLargeHeight = 48.0;
  static const drawerEnterMs = 220;
  static const drawerExitMs = 180;
  static const tabsMs = 180;
  static const loadingCycleMs = 1200;
  static const progressMs = 320;
  static const radius = <String,double>{"control": 8.0, "content": 12.0, "dialog": 20.0, "pill": 999.0};
  static const motion = RosemaryMotion({"instantFeedback": 120, "state": 180, "transition": 260, "exit": 160, "layout": 240, "confirmation": 220, "restoration": 480, "page": 220, "drawerEnterMs": 220, "drawerExitMs": 180, "tabsMs": 180, "loadingCycleMs": 1200, "progressMs": 320, "progressFlowMs": 1800, "skeletonCycleMs": 1500}, "cubic-bezier(0.2, 0.7, 0.2, 1)");
  static const typography = RosemaryTypography({"ui": "-apple-system, BlinkMacSystemFont, Segoe UI, PingFang SC, Microsoft YaHei, sans-serif", "editorial": "Songti SC, STSong, Noto Serif CJK SC, Georgia, serif", "latinEditorial": "Georgia, Times New Roman, serif", "code": "SFMono-Regular, Consolas, Liberation Mono, monospace"}, {"caption": RosemaryTypeRole("ui", 12.0, 1.5, 400), "small": RosemaryTypeRole("ui", 14.0, 1.75, 400), "body": RosemaryTypeRole("ui", 16.0, 1.75, 400), "lead": RosemaryTypeRole("ui", 20.0, 1.75, 400), "heading": RosemaryTypeRole("editorial", 28.0, 1.3, 400), "title": RosemaryTypeRole("editorial", 40.0, 1.3, 400), "display": RosemaryTypeRole("editorial", 64.0, 1.3, 400)}, {"body": 1.75, "compact": 1.5, "heading": 1.3}, {"regular": 400, "medium": 500, "semibold": 600});
  static const componentTokens = <String,RosemaryComponentToken>{"button": RosemaryComponentToken("on-primary", "primary", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0, "heightSmall": 32.0, "heightMedium": 40.0, "heightLarge": 48.0, "paddingInline": 15.0, "darkFillInset": 1.0, "paddingBlock": 9.0, "fontSize": 13.0, "lineHeight": 18.2}, {}, {}, <double>[]), "link": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "iconButton": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "input": RosemaryComponentToken("ink", "field-fill", "focus", "field-line", "control", 8.0, {"minTouchTarget": 44.0, "minHeight": 44.0, "fontSize": 16.0, "lineHeight": 24.0, "labelFontSize": 13.0, "labelLineHeight": 18.2, "paddingBlock": 9.0}, {}, {}, <double>[]), "textarea": RosemaryComponentToken("ink", "field-fill", "focus", "field-line", "control", 8.0, {"minTouchTarget": 44.0, "fontSize": 16.0, "lineHeight": 24.0, "labelFontSize": 13.0, "labelLineHeight": 18.2, "paddingBlock": 9.0}, {}, {}, <double>[]), "select": RosemaryComponentToken("ink", "field-fill", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0, "minHeight": 44.0, "fontSize": 16.0, "lineHeight": 24.0, "labelFontSize": 13.0, "labelLineHeight": 18.2, "paddingBlock": 9.0, "popupMaxHeight": 340.0, "popupPadding": 6.0}, {}, {}, <double>[]), "search": RosemaryComponentToken("ink", "field-fill", "focus", "field-line", "control", 8.0, {"minTouchTarget": 44.0, "minHeight": 44.0}, {}, {}, <double>[]), "checkbox": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "radio": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "switch": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "slider": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0, "trackHeight": 4.0, "thumbSize": 16.0, "trackInset": 8.0}, {}, {}, <double>[]), "date": RosemaryComponentToken("ink", "field-fill", "focus", "field-line", "control", 8.0, {"minTouchTarget": 44.0, "minHeight": 44.0}, {}, {}, <double>[]), "upload": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "tabs": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0, "indicatorMs": 180.0, "contentMs": 180.0}, {}, {}, <double>[]), "breadcrumb": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "pagination": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "menu": RosemaryComponentToken("ink", "surface-floating", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "tooltip": RosemaryComponentToken("ink", "surface-floating", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "popover": RosemaryComponentToken("ink", "surface-floating", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "dialog": RosemaryComponentToken("ink", "surface-floating", "focus", "control", "dialog", 20.0, {"minTouchTarget": 44.0, "enterMs": 260.0, "exitMs": 160.0}, {"completion": "animation-finished"}, {"interruptible": true}, <double>[]), "drawer": RosemaryComponentToken("ink", "surface-floating", "focus", "control", "dialog", 20.0, {"minTouchTarget": 44.0, "enterMs": 220.0, "exitMs": 180.0}, {"completion": "animation-finished"}, {"interruptible": true}, <double>[]), "toast": RosemaryComponentToken("ink", "surface-floating", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "alert": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "card": RosemaryComponentToken("ink", "surface-group", "focus", "border", "content", 12.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "list": RosemaryComponentToken("ink", "surface-group", "focus", "border", "content", 12.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "table": RosemaryComponentToken("ink", "surface-group", "focus", "border", "content", 12.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "badge": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "avatar": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "empty": RosemaryComponentToken("ink", "surface-group", "focus", "border", "content", 12.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "skeleton": RosemaryComponentToken("ink", "surface", "focus", "border", "content", 12.0, {"minTouchTarget": 44.0}, {}, {}, <double>[]), "loading": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0, "cycleMs": 1200.0, "appearanceDelayMs": 300.0}, {"reducedMotion": "static", "shape": "two-fold-long-axis"}, {}, <double>[17.0, 32.0, 48.0]), "progress": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0, "transitionMs": 320.0}, {"reducedMotion": "immediate", "valueSemantics": "actual-completed-work"}, {}, <double>[]), "stepper": RosemaryComponentToken("ink", "surface", "focus", "control", "control", 8.0, {"minTouchTarget": 44.0}, {}, {}, <double>[])};
  static const spacing = <double>[4.0, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0, 64.0, 96.0];
  static const contrastPairs = [RosemaryContrastPair('ink', 'canvas', 4.5), RosemaryContrastPair('muted', 'canvas', 4.5), RosemaryContrastPair('ink', 'surface', 4.5), RosemaryContrastPair('muted', 'surface', 4.5), RosemaryContrastPair('ink', 'raised', 4.5), RosemaryContrastPair('muted', 'raised', 4.5), RosemaryContrastPair('primary', 'primary-soft', 4.5), RosemaryContrastPair('ink', 'primary-soft', 4.5), RosemaryContrastPair('on-primary', 'primary', 4.5), RosemaryContrastPair('on-sun', 'sun', 4.5), RosemaryContrastPair('on-sky', 'sky', 4.5), RosemaryContrastPair('success', 'success-soft', 4.5), RosemaryContrastPair('warning', 'warning-soft', 4.5), RosemaryContrastPair('danger', 'danger-soft', 4.5), RosemaryContrastPair('on-danger', 'danger', 4.5), RosemaryContrastPair('info', 'info-soft', 4.5), RosemaryContrastPair('on-navigation', 'surface-navigation', 4.5), RosemaryContrastPair('on-navigation-active', 'navigation-active', 4.5), RosemaryContrastPair('navigation-muted', 'surface-navigation', 4.5), RosemaryContrastPair('on-topbar', 'surface-topbar', 4.5), RosemaryContrastPair('on-topbar-muted', 'surface-topbar', 4.5), RosemaryContrastPair('navigation-muted', 'surface-topbar', 4.5), RosemaryContrastPair('ink', 'surface-group', 4.5), RosemaryContrastPair('muted', 'surface-group', 4.5), RosemaryContrastPair('ink', 'surface-inset', 4.5), RosemaryContrastPair('muted', 'surface-inset', 4.5), RosemaryContrastPair('ink', 'surface-floating', 4.5), RosemaryContrastPair('muted', 'surface-floating', 4.5), RosemaryContrastPair('on-topbar', 'topbar-control', 4.5), RosemaryContrastPair('on-topbar-muted', 'topbar-control', 4.5), RosemaryContrastPair('primary', 'canvas', 4.5), RosemaryContrastPair('primary', 'surface', 4.5), RosemaryContrastPair('primary', 'raised', 4.5), RosemaryContrastPair('ink', 'field-fill', 4.5), RosemaryContrastPair('muted', 'field-fill', 4.5), RosemaryContrastPair('ink', 'field-hover', 4.5), RosemaryContrastPair('muted', 'field-hover', 4.5), RosemaryContrastPair('on-secondary-container', 'secondary-container', 4.5), RosemaryContrastPair('on-tertiary-container', 'tertiary-container', 4.5), RosemaryContrastPair('navigation-active', 'surface-navigation', 3.0), RosemaryContrastPair('control', 'canvas', 3.0), RosemaryContrastPair('control', 'surface', 3.0), RosemaryContrastPair('control', 'raised', 3.0), RosemaryContrastPair('field-line', 'field-fill', 3.0), RosemaryContrastPair('field-line', 'canvas', 3.0), RosemaryContrastPair('field-line', 'surface-inset', 3.0), RosemaryContrastPair('field-line-hover', 'field-hover', 3.0), RosemaryContrastPair('focus', 'canvas', 3.0), RosemaryContrastPair('focus', 'raised', 3.0), RosemaryContrastPair('focus', 'surface-group', 3.0), RosemaryContrastPair('focus', 'surface-inset', 3.0), RosemaryContrastPair('focus', 'surface-floating', 3.0), RosemaryContrastPair('focus', 'field-fill', 3.0), RosemaryContrastPair('focus', 'surface', 3.0), RosemaryContrastPair('focus', 'surface-navigation', 3.0), RosemaryContrastPair('focus', 'surface-topbar', 3.0)];
}
