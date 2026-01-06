// Highly flexible, production-grade UI state switcher
// - Slot-based overrides
// - Animated transitions
// - Zero layout jumps
// - Works with shimmer, empty, error, success
// File: lib/core/widgets/common_switch_state.dart

import 'package:flutter/material.dart';

/// Canonical UI states
enum ViewState { loading, loaded, noData, networkError, serverError, error }

/// Signature for building a state-specific widget
typedef ViewStateBuilder = Widget Function(BuildContext context);

/// Advanced, slot-based state switcher
///
/// ✔ Animated transitions
/// ✔ Custom widget per state
/// ✔ Fallback defaults
/// ✔ No rebuild loops
/// ✔ Production-safe
class CommonSwitchState extends StatelessWidget {
  final ViewState state;

  /// Main success widget
  final Widget child;

  /// Retry callback (optional)
  final VoidCallback? onRetry;

  /// Optional animation config
  final Duration animationDuration;
  final Curve animationCurve;

  /// Optional custom widgets per state
  final Widget? loadingWidget;
  final Widget? noDataWidget;
  final Widget? networkErrorWidget;
  final Widget? serverErrorWidget;
  final Widget? errorWidget;

  /// Optional builders (override widgets if provided)
  final ViewStateBuilder? loadingBuilder;
  final ViewStateBuilder? noDataBuilder;
  final ViewStateBuilder? networkErrorBuilder;
  final ViewStateBuilder? serverErrorBuilder;
  final ViewStateBuilder? errorBuilder;

  const CommonSwitchState({
    super.key,
    required this.state,
    required this.child,
    this.onRetry,
    this.animationDuration = const Duration(milliseconds: 220),
    this.animationCurve = Curves.easeOutCubic,
    this.loadingWidget,
    this.noDataWidget,
    this.networkErrorWidget,
    this.serverErrorWidget,
    this.errorWidget,
    this.loadingBuilder,
    this.noDataBuilder,
    this.networkErrorBuilder,
    this.serverErrorBuilder,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: animationDuration,
      switchInCurve: animationCurve,
      switchOutCurve: animationCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey<ViewState>(state),
        child: _buildForState(context),
      ),
    );
  }

  Widget _buildForState(BuildContext context) {
    switch (state) {
      case ViewState.loading:
        return loadingBuilder?.call(context) ??
            loadingWidget ??
            const _DefaultLoading();

      case ViewState.loaded:
        return child;

      case ViewState.noData:
        return noDataBuilder?.call(context) ??
            noDataWidget ??
            _DefaultMessage(
              icon: Icons.inbox_outlined,
              title: 'Nothing here',
              message: 'No data available.',
              onRetry: onRetry,
            );

      case ViewState.networkError:
        return networkErrorBuilder?.call(context) ??
            networkErrorWidget ??
            _DefaultMessage(
              icon: Icons.wifi_off_rounded,
              title: 'No internet',
              message: 'Check your connection and try again.',
              onRetry: onRetry,
            );

      case ViewState.serverError:
        return serverErrorBuilder?.call(context) ??
            serverErrorWidget ??
            _DefaultMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Server error',
              message: 'Please try again later.',
              onRetry: onRetry,
            );

      case ViewState.error:
        return errorBuilder?.call(context) ??
            errorWidget ??
            _DefaultMessage(
              icon: Icons.error_outline_rounded,
              title: 'Something went wrong',
              message: 'Unexpected error occurred.',
              onRetry: onRetry,
            );
    }
  }
}

/// ─────────────────────────────────────────
/// Default widgets (minimal + neutral)
/// ─────────────────────────────────────────

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _DefaultMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const _DefaultMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white54,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              _RetryButton(onRetry: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onRetry;

  const _RetryButton({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white.withOpacity(.08),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Text(
          'Retry',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
