import 'package:flutter/material.dart';

/// FixPose design tokens — "Liquid Glass" (sample/styles.css is the source of truth).
///
/// Light  = cream translucent surfaces + subtle grid lines.
/// Dark   = near-black green-tinted glass + grid glow.
/// Accent = chartreuse green with gradient shading (bright → deep), dynamic look.
/// Theme follows the device ([ThemeMode.system]); manual picker lives in Settings.
abstract final class AppColors {
  // ---- Accent: chartreuse (identical in both themes) ----
  static const accentBright = Color(0xFFD9FF57);
  static const accent = Color(0xFFA9E92C);
  static const accentMid = Color(0xFF7CC414);
  static const accentInk = Color(0xFF1C2A06); // text on chartreuse
  static const danger = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);

  // ---- Light theme ----
  static const cream = Color(0xFFFFFDF5); // primary light surface
  static const lightBgTop = Color(0xFFF8F4E7);
  static const lightBgBottom = Color(0xFFEFE9D8);
  static const lightInk = Color(0xFF0F172A);
  static const lightInk2 = Color(0xFF5B6472);
  static const lightInk3 = Color(0xFF98A2B3);
  static const lightAccentDeep = Color(0xFF3F6212); // accent text on light
  static const lightAccentSoft = Color(0xFFF0FDCE);
  static const lightGrid = Color(0x120F172A);
  static const lightBlobA = Color(0x2EA9E92C); // chartreuse bloom
  static const lightBlobB = Color(0x1C0EA5E9); // soft blue bloom
  static const lightGlass = Color(0xB8FFFBEE);
  static const lightGlassWeak = Color(0x80FFFBEE);
  static const lightGlassHi = Color(0xBFFFFFFF);
  static const lightBorder = Color(0xE6FFFDF6);
  static const lightSolid = Color(0xE6FFFCF4);
  static const lightFieldBorder = Color(0x140F172A);
  static const lightFieldInset = Color(0x0A0F172A);
  static const lightTrack = Color(0x170F172A);
  static const lightTrackStrong = Color(0x1F0F172A);
  static const lightSegBg = Color(0x0F0F172A);
  static const lightLine = Color(0x1F0F172A);
  static const lightSelBg = Color(0xFF0F172A);
  static const lightSelFg = Color(0xFFFFFFFF);
  static const lightSelDot = Color(0xFFA9E92C);
  static const lightSwitchOff = Color(0x290F172A);
  static const lightShadow = Color(0x1A0F172A);
  static const lightShadowSoft = Color(0x120F172A);
  static const lightComposerTop = Color(0x00F8F4E7);
  static const lightComposerBottom = Color(0xEBF8F4E7);

  // ---- Dark theme ----
  static const darkPage = Color(0xFF0A0D08);
  static const darkBgTop = Color(0xFF141810);
  static const darkBgBottom = Color(0xFF0B0E09);
  static const darkInk = Color(0xFFEDF2E4);
  static const darkInk2 = Color(0xFFA7B29D);
  static const darkInk3 = Color(0xFF77826E);
  static const darkAccentDeep = Color(0xFFC3F53C); // accent text on dark
  static const darkAccentSoft = Color(0x29C3F53C);
  static const darkGrid = Color(0x0DFFFFFF);
  static const darkBlobA = Color(0x21A9E92C);
  static const darkBlobB = Color(0x1A0EA5E9);
  static const darkGlass = Color(0xB81B2118);
  static const darkGlassWeak = Color(0x8C1B2118);
  static const darkGlassHi = Color(0x14FFFFFF);
  static const darkBorder = Color(0x1FFFFFFF);
  static const darkSolid = Color(0xF01F251C);
  static const darkFieldBorder = Color(0x21FFFFFF);
  static const darkFieldInset = Color(0x4D000000);
  static const darkTrack = Color(0x1FFFFFFF);
  static const darkTrackStrong = Color(0x29FFFFFF);
  static const darkSegBg = Color(0x14FFFFFF);
  static const darkLine = Color(0x24FFFFFF);
  static const darkSelBg = Color(0xFFEDF2E4);
  static const darkSelFg = Color(0xFF12160F);
  static const darkSelDot = Color(0xFF7CC414);
  static const darkSwitchOff = Color(0x33FFFFFF);
  static const darkShadow = Color(0x73000000);
  static const darkShadowSoft = Color(0x59000000);
  static const darkComposerTop = Color(0x000B0E09);
  static const darkComposerBottom = Color(0xEB0B0E09);
}

/// Theme-carried palette so widgets never hardcode colors
/// (keeps light/dark switch automatic everywhere — sample §themes).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bgTop,
    required this.bgBottom,
    required this.grid,
    required this.blobA,
    required this.blobB,
    required this.glass,
    required this.glassWeak,
    required this.glassHi,
    required this.border,
    required this.solid,
    required this.fieldBorder,
    required this.fieldInset,
    required this.track,
    required this.trackStrong,
    required this.segBg,
    required this.line,
    required this.selBg,
    required this.selFg,
    required this.selDot,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.accentDeep,
    required this.accentSoft,
    required this.amberPillBg,
    required this.amberPillFg,
    required this.switchOff,
    required this.shadow,
    required this.shadowSoft,
    required this.composerTop,
    required this.composerBottom,
  });

  final Color bgTop;
  final Color bgBottom;
  final Color grid;
  final Color blobA;
  final Color blobB;
  final Color glass;
  final Color glassWeak;
  final Color glassHi;
  final Color border;
  final Color solid;
  final Color fieldBorder;
  final Color fieldInset;
  final Color track;
  final Color trackStrong;
  final Color segBg;
  final Color line;
  final Color selBg;
  final Color selFg;
  final Color selDot;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color accentDeep;
  final Color accentSoft;
  final Color amberPillBg;
  final Color amberPillFg;
  final Color switchOff;
  final Color shadow;
  final Color shadowSoft;
  final Color composerTop;
  final Color composerBottom;

  static const light = AppPalette(
    bgTop: AppColors.lightBgTop,
    bgBottom: AppColors.lightBgBottom,
    grid: AppColors.lightGrid,
    blobA: AppColors.lightBlobA,
    blobB: AppColors.lightBlobB,
    glass: AppColors.lightGlass,
    glassWeak: AppColors.lightGlassWeak,
    glassHi: AppColors.lightGlassHi,
    border: AppColors.lightBorder,
    solid: AppColors.lightSolid,
    fieldBorder: AppColors.lightFieldBorder,
    fieldInset: AppColors.lightFieldInset,
    track: AppColors.lightTrack,
    trackStrong: AppColors.lightTrackStrong,
    segBg: AppColors.lightSegBg,
    line: AppColors.lightLine,
    selBg: AppColors.lightSelBg,
    selFg: AppColors.lightSelFg,
    selDot: AppColors.lightSelDot,
    ink: AppColors.lightInk,
    ink2: AppColors.lightInk2,
    ink3: AppColors.lightInk3,
    accentDeep: AppColors.lightAccentDeep,
    accentSoft: AppColors.lightAccentSoft,
    amberPillBg: Color(0xFFFEF3C7),
    amberPillFg: Color(0xFFB45309),
    switchOff: AppColors.lightSwitchOff,
    shadow: AppColors.lightShadow,
    shadowSoft: AppColors.lightShadowSoft,
    composerTop: AppColors.lightComposerTop,
    composerBottom: AppColors.lightComposerBottom,
  );

  static const dark = AppPalette(
    bgTop: AppColors.darkBgTop,
    bgBottom: AppColors.darkBgBottom,
    grid: AppColors.darkGrid,
    blobA: AppColors.darkBlobA,
    blobB: AppColors.darkBlobB,
    glass: AppColors.darkGlass,
    glassWeak: AppColors.darkGlassWeak,
    glassHi: AppColors.darkGlassHi,
    border: AppColors.darkBorder,
    solid: AppColors.darkSolid,
    fieldBorder: AppColors.darkFieldBorder,
    fieldInset: AppColors.darkFieldInset,
    track: AppColors.darkTrack,
    trackStrong: AppColors.darkTrackStrong,
    segBg: AppColors.darkSegBg,
    line: AppColors.darkLine,
    selBg: AppColors.darkSelBg,
    selFg: AppColors.darkSelFg,
    selDot: AppColors.darkSelDot,
    ink: AppColors.darkInk,
    ink2: AppColors.darkInk2,
    ink3: AppColors.darkInk3,
    accentDeep: AppColors.darkAccentDeep,
    accentSoft: AppColors.darkAccentSoft,
    amberPillBg: Color(0x2EF59E0B),
    amberPillFg: Color(0xFFFBBF24),
    switchOff: AppColors.darkSwitchOff,
    shadow: AppColors.darkShadow,
    shadowSoft: AppColors.darkShadowSoft,
    composerTop: AppColors.darkComposerTop,
    composerBottom: AppColors.darkComposerBottom,
  );

  @override
  AppPalette copyWith({
    Color? bgTop,
    Color? bgBottom,
    Color? grid,
    Color? blobA,
    Color? blobB,
    Color? glass,
    Color? glassWeak,
    Color? glassHi,
    Color? border,
    Color? solid,
    Color? fieldBorder,
    Color? fieldInset,
    Color? track,
    Color? trackStrong,
    Color? segBg,
    Color? line,
    Color? selBg,
    Color? selFg,
    Color? selDot,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? accentDeep,
    Color? accentSoft,
    Color? amberPillBg,
    Color? amberPillFg,
    Color? switchOff,
    Color? shadow,
    Color? shadowSoft,
    Color? composerTop,
    Color? composerBottom,
  }) {
    return AppPalette(
      bgTop: bgTop ?? this.bgTop,
      bgBottom: bgBottom ?? this.bgBottom,
      grid: grid ?? this.grid,
      blobA: blobA ?? this.blobA,
      blobB: blobB ?? this.blobB,
      glass: glass ?? this.glass,
      glassWeak: glassWeak ?? this.glassWeak,
      glassHi: glassHi ?? this.glassHi,
      border: border ?? this.border,
      solid: solid ?? this.solid,
      fieldBorder: fieldBorder ?? this.fieldBorder,
      fieldInset: fieldInset ?? this.fieldInset,
      track: track ?? this.track,
      trackStrong: trackStrong ?? this.trackStrong,
      segBg: segBg ?? this.segBg,
      line: line ?? this.line,
      selBg: selBg ?? this.selBg,
      selFg: selFg ?? this.selFg,
      selDot: selDot ?? this.selDot,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      accentDeep: accentDeep ?? this.accentDeep,
      accentSoft: accentSoft ?? this.accentSoft,
      amberPillBg: amberPillBg ?? this.amberPillBg,
      amberPillFg: amberPillFg ?? this.amberPillFg,
      switchOff: switchOff ?? this.switchOff,
      shadow: shadow ?? this.shadow,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      composerTop: composerTop ?? this.composerTop,
      composerBottom: composerBottom ?? this.composerBottom,
    );
  }

  @override
  AppPalette lerp(covariant ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color lerpC(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      bgTop: lerpC(bgTop, other.bgTop),
      bgBottom: lerpC(bgBottom, other.bgBottom),
      grid: lerpC(grid, other.grid),
      blobA: lerpC(blobA, other.blobA),
      blobB: lerpC(blobB, other.blobB),
      glass: lerpC(glass, other.glass),
      glassWeak: lerpC(glassWeak, other.glassWeak),
      glassHi: lerpC(glassHi, other.glassHi),
      border: lerpC(border, other.border),
      solid: lerpC(solid, other.solid),
      fieldBorder: lerpC(fieldBorder, other.fieldBorder),
      fieldInset: lerpC(fieldInset, other.fieldInset),
      track: lerpC(track, other.track),
      trackStrong: lerpC(trackStrong, other.trackStrong),
      segBg: lerpC(segBg, other.segBg),
      line: lerpC(line, other.line),
      selBg: lerpC(selBg, other.selBg),
      selFg: lerpC(selFg, other.selFg),
      selDot: lerpC(selDot, other.selDot),
      ink: lerpC(ink, other.ink),
      ink2: lerpC(ink2, other.ink2),
      ink3: lerpC(ink3, other.ink3),
      accentDeep: lerpC(accentDeep, other.accentDeep),
      accentSoft: lerpC(accentSoft, other.accentSoft),
      amberPillBg: lerpC(amberPillBg, other.amberPillBg),
      amberPillFg: lerpC(amberPillFg, other.amberPillFg),
      switchOff: lerpC(switchOff, other.switchOff),
      shadow: lerpC(shadow, other.shadow),
      shadowSoft: lerpC(shadowSoft, other.shadowSoft),
      composerTop: lerpC(composerTop, other.composerTop),
      composerBottom: lerpC(composerBottom, other.composerBottom),
    );
  }
}

/// Convenience: `final p = context.palette;`
extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

abstract final class AppTheme {
  /// Light liquid-glass theme (cream + grid).
  static ThemeData light() => _base(
        brightness: Brightness.light,
        palette: AppPalette.light,
        surface: AppColors.cream,
        onSurface: AppColors.lightInk,
        scaffold: AppColors.lightBgTop,
        outline: AppColors.lightLine,
      );

  /// Dark liquid-glass theme (near-black green glass).
  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        palette: AppPalette.dark,
        surface: const Color(0xFF1F251C),
        onSurface: AppColors.darkInk,
        scaffold: AppColors.darkBgTop,
        outline: AppColors.darkLine,
      );

  static ThemeData _base({
    required Brightness brightness,
    required AppPalette palette,
    required Color surface,
    required Color onSurface,
    required Color scaffold,
    required Color outline,
  }) {
    final isLight = brightness == Brightness.light;
    final ink = palette.ink;
    final ink2 = palette.ink2;
    final ink3 = palette.ink3;

    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: AppColors.accentInk,
        secondary: AppColors.accentMid,
        onSecondary: AppColors.accentInk,
        tertiary: isLight ? AppColors.lightAccentDeep : AppColors.darkAccentDeep,
        onTertiary: isLight ? AppColors.accentInk : AppColors.accentInk,
        error: AppColors.danger,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
        surfaceContainer: surface,
        surfaceContainerLow: surface,
        surfaceContainerHigh: surface,
        surfaceContainerHighest: surface,
        outline: outline,
        outlineVariant: outline,
        shadow: palette.shadow,
        inverseSurface: isLight ? AppColors.darkSelBg : AppColors.lightSelBg,
        onInverseSurface: isLight ? AppColors.darkSelFg : AppColors.lightSelFg,
      ),
      extensions: [palette],
      textTheme: _textTheme(ink: ink, ink2: ink2, ink3: ink3),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: ink,
        titleTextStyle: _titleStyle(ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.solid,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: TextStyle(color: ink3, fontSize: 14.5, fontWeight: FontWeight.w600),
        labelStyle: TextStyle(color: ink2, fontSize: 12, fontWeight: FontWeight.w800),
        prefixIconColor: ink3,
        suffixIconColor: ink3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.fieldBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.fieldBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accentMid, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentInk,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          shape: StadiumBorder(),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentInk,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.solid,
          foregroundColor: ink,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          side: BorderSide(color: palette.line, width: 1.5),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accentDeep,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.glass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 70,
        indicatorColor: palette.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected) ? palette.accentDeep : ink3,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected) ? palette.accentDeep : ink3,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accentMid
              : palette.switchOff,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accentMid),
      dividerTheme: DividerThemeData(color: palette.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? AppColors.lightSelBg : AppColors.darkSelBg,
        contentTextStyle: TextStyle(
          color: isLight ? Colors.white : AppColors.darkSelFg,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.accentMid,
        thumbColor: AppColors.accent,
        inactiveTrackColor: Color(0x337CC414),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ink2,
        textColor: ink,
        titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink),
        subtitleTextStyle: TextStyle(fontSize: 12, color: ink3),
      ),
    );
    return theme;
  }

  static TextStyle _titleStyle(Color ink) =>
      TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.2);

  static TextTheme _textTheme({required Color ink, required Color ink2, required Color ink3}) {
    return TextTheme(
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: ink),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: ink),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: ink),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: ink),
      titleMedium: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.1, color: ink),
      titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ink),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: ink),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ink),
      bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: ink2),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink2),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ink2, letterSpacing: 0.5),
      labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ink3),
    );
  }
}
