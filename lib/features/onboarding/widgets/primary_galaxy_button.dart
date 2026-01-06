import 'package:flutter/material.dart';

import 'loaders.dart';

enum GalaxyLoaderType { tripleDots, warpRings, nanoParticles, waveDots }

class PrimaryGalaxyButton extends StatefulWidget {
  final String title;
  final Future<void> Function() onSubmit;
  final GalaxyLoaderType loader;
  final double? width;

  const PrimaryGalaxyButton({
    super.key,
    required this.title,
    required this.onSubmit,
    this.loader = GalaxyLoaderType.warpRings,
    this.width,
  });

  @override
  State<PrimaryGalaxyButton> createState() => _PrimaryGalaxyButtonState();
}

class _PrimaryGalaxyButtonState extends State<PrimaryGalaxyButton>
    with TickerProviderStateMixin {
  final ValueNotifier<bool> _loading = ValueNotifier(false);

  late final AnimationController _morphCtrl;
  late final AnimationController _loaderCtrl;
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();

    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _loaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
    )..forward();
  }

  @override
  void dispose() {
    _loading.dispose();
    _morphCtrl.dispose();
    _loaderCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_loading.value) return;

    _loading.value = true;
    _pressCtrl.reverse();
    _morphCtrl.forward();
    _loaderCtrl.repeat();

    await widget.onSubmit();

    if (!mounted) return;
    _loaderCtrl.stop();
    await _morphCtrl.reverse();
    _pressCtrl.forward();
    _loading.value = false;
  }

  Widget _loaderSelector() {
    switch (widget.loader) {
      case GalaxyLoaderType.tripleDots:
        return TripleDotsOrbit(
          key: const ValueKey("tripleDots"),
          controller: _loaderCtrl,
        );
      case GalaxyLoaderType.warpRings:
        return WarpRings(
          key: const ValueKey("warpRings"),
          controller: _loaderCtrl,
        );
      case GalaxyLoaderType.nanoParticles:
        return NanoParticles(
          key: const ValueKey("nanoParticles"),
          controller: _loaderCtrl,
        );
      case GalaxyLoaderType.waveDots:
        return WaveDots(
          key: const ValueKey("waveDots"),
          controller: _loaderCtrl,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const double size = 54;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.reverse(),
      onTapUp: (_) => _pressCtrl.forward(),
      onTapCancel: () => _pressCtrl.forward(),
      onTap: _tap,
      child: ValueListenableBuilder<bool>(
        valueListenable: _loading,
        builder: (_, loadingValue, _) {
          return AnimatedBuilder(
            animation: Listenable.merge([_morphCtrl, _pressCtrl]),
            builder: (_, __) {
              final t = Curves.easeInOutCubic.transform(_morphCtrl.value);
              final radius = lerpDouble(28, size / 2, t)!;

              return Transform.scale(
                scale: _pressCtrl.value,
                child: Container(
                  width: widget.width ?? .maxFinite,
                  margin: widget.width != null
                      ? null
                      : const EdgeInsets.symmetric(horizontal: 16),
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.8),
                        Theme.of(context).primaryColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(.46),
                        blurRadius: 32 + (t * 16),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 30),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: loadingValue
                        ? KeyedSubtree(
                            key: ValueKey(
                              "loader-${DateTime.now().microsecondsSinceEpoch}",
                            ),
                            child: _loaderSelector(),
                          )
                        : KeyedSubtree(
                            key: ValueKey(
                              "label-${DateTime.now().microsecondsSinceEpoch}",
                            ),
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Utils
double? lerpDouble(num a, num b, double t) => a + (b - a) * t;
