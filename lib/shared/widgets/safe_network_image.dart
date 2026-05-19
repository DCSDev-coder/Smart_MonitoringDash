import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Flutter Web: `Image.network` defaults to fetching via XHR in some cases,
/// which requires CORS. Using the HTML `<img>` element avoids CORS for simple
/// display (we're not reading pixels).
class SafeNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final WidgetBuilder? errorBuilder;

  const SafeNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // Prefer HTML `<img>` on web to avoid CORS failures for external hosts.
      webHtmlElementStrategy:
          kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
      errorBuilder: errorBuilder != null
          ? (context, _, __) => errorBuilder!(context)
          : null,
    );
  }
}

