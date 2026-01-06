import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A Scaffold wrapper that automatically adjusts system UI
/// (status bar & navigation bar) for both Android and iOS.
///
/// Supports edge-to-edge layouts (Android 10+).
class SystemUIHandler extends StatelessWidget {
  final Color? scaffoldBackgroundColor;

  // Scaffold properties
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomSheet;
  final bool resizeToAvoidBottomInset;
  final bool extendBody;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  // System UI colors
  final Color? statusBarColor;
  final Color? navBarColor;
  final Color? navBarDividerColor;

  const SystemUIHandler({
    super.key,
    this.scaffoldBackgroundColor,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.bottomSheet,
    this.resizeToAvoidBottomInset = true,
    this.extendBody = false,
    this.statusBarColor,
    this.navBarColor,
    this.navBarDividerColor,
  });

  /// Builds an overlay style automatically based on luminance.
  static SystemUiOverlayStyle overlayStyle({
    required Color scaffoldBackgroundColor,
    Color? statusBarColor,
    Color? navBarColor,
    Color? navBarDividerColor,
  }) {
    final effectiveStatusBar = statusBarColor ?? scaffoldBackgroundColor;
    final effectiveNavBar = navBarColor ?? scaffoldBackgroundColor;
    final effectiveDivider = navBarDividerColor ?? navBarColor;

    // brightness for status bar icons (Android)
    final isLightStatus = effectiveStatusBar.computeLuminance() > 0.5;
    final androidStatusIconBrightness = isLightStatus
        ? Brightness.dark
        : Brightness.light;

    // iOS flips the meaning
    final iosStatusBarBrightness = isLightStatus
        ? Brightness.light
        : Brightness.dark;

    // brightness for nav bar icons
    final isLightNav = effectiveNavBar.computeLuminance() > 0.5;
    final androidNavIconBrightness = isLightNav
        ? Brightness.dark
        : Brightness.light;

    return SystemUiOverlayStyle(
      statusBarColor: effectiveStatusBar,
      statusBarIconBrightness: androidStatusIconBrightness,
      // Android
      statusBarBrightness: iosStatusBarBrightness,
      // iOS
      systemNavigationBarColor: effectiveNavBar,
      systemNavigationBarDividerColor: effectiveDivider,
      systemNavigationBarIconBrightness: androidNavIconBrightness,
    );
  }

  /// Syncs AppBar systemOverlayStyle with provided colors
  PreferredSizeWidget? _syncAppBar() {
    if (appBar == null) return null;

    if (appBar is AppBar) {
      final original = appBar as AppBar;

      return AppBar(
        key: original.key,
        title: original.title,
        actions: original.actions,
        leading: original.leading,
        automaticallyImplyLeading: original.automaticallyImplyLeading,
        flexibleSpace: original.flexibleSpace,
        bottom: original.bottom,
        elevation: original.elevation,
        scrolledUnderElevation: original.scrolledUnderElevation,
        shadowColor: original.shadowColor,
        surfaceTintColor: original.surfaceTintColor,
        shape: original.shape,
        backgroundColor: original.backgroundColor ?? scaffoldBackgroundColor,
        foregroundColor: original.foregroundColor,
        iconTheme: original.iconTheme,
        actionsIconTheme: original.actionsIconTheme,
        primary: original.primary,
        centerTitle: original.centerTitle,
        excludeHeaderSemantics: original.excludeHeaderSemantics,
        titleSpacing: original.titleSpacing,
        toolbarOpacity: original.toolbarOpacity,
        bottomOpacity: original.bottomOpacity,
        toolbarHeight: original.toolbarHeight,
        leadingWidth: original.leadingWidth,
        toolbarTextStyle: original.toolbarTextStyle,
        titleTextStyle: original.titleTextStyle,
        systemOverlayStyle: overlayStyle(
          scaffoldBackgroundColor: scaffoldBackgroundColor ?? Colors.white,
          statusBarColor: statusBarColor ?? original.backgroundColor,
          navBarColor: navBarColor,
          navBarDividerColor: navBarDividerColor,
        ),
      );
    }

    return appBar;
  }

  @override
  Widget build(BuildContext context) {
    final style = overlayStyle(
      scaffoldBackgroundColor: scaffoldBackgroundColor ?? Colors.white,
      statusBarColor: statusBarColor,
      navBarColor: navBarColor,
      navBarDividerColor: navBarDividerColor,
    );

    // Enable edge-to-edge UI (Android 10+)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: Scaffold(
        backgroundColor: scaffoldBackgroundColor,
        appBar: _syncAppBar(),
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
        drawer: drawer,
        endDrawer: endDrawer,
        bottomSheet: bottomSheet,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        extendBody: extendBody,
      ),
    );
  }
}
