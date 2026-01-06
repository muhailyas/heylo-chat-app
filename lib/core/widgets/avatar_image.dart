import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AvatarImage extends StatelessWidget {
  final String? url;
  final double radius;
  final String? fallbackName;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? fontSize;
  final String? heroTag;

  const AvatarImage({
    super.key,
    required this.url,
    this.radius = 24,
    this.fallbackName,
    this.backgroundColor,
    this.foregroundColor,
    this.fontSize,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor =
        backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final fgColor = foregroundColor ?? theme.colorScheme.onSurfaceVariant;
    final fSize = fontSize ?? radius * 0.8;

    Widget imageWidget;
    if (url != null && url!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: url!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          child: Icon(Icons.person, color: fgColor.withOpacity(0.5)),
        ),
        errorWidget: (context, url, error) =>
            _buildFallback(bgColor, fgColor, fSize),
      );
    } else {
      imageWidget = _buildFallback(bgColor, fgColor, fSize);
    }

    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        transitionOnUserGestures:
            true, // Enable gesture support for back swipes
        flightShuttleBuilder:
            (
              flightContext,
              animation,
              flightDirection,
              fromHeroContext,
              toHeroContext,
            ) {
              // Use a simple material wrapper to ensure text/icons don't lose theme context
              // during flight, but generally just returning the widget is safest for consistent
              // headers.
              return toHeroContext.widget;
            },
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildFallback(Color bgColor, Color fgColor, double fSize) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: fallbackName != null && fallbackName!.isNotEmpty
          ? Text(
              fallbackName!.characters.first.toUpperCase(),
              style: TextStyle(
                color: fgColor,
                fontWeight: FontWeight.bold,
                fontSize: fSize,
              ),
            )
          : Icon(Icons.person, color: fgColor.withOpacity(0.5)),
    );
  }
}
