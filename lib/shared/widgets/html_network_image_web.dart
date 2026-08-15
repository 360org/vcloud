import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final _registeredNetworkImages = <String>{};

Widget? buildHtmlNetworkImage({
  required String url,
  BoxFit fit = BoxFit.cover,
}) {
  final clean = url.trim();
  // Ensure we only attempt HTML <img> rendering on valid web or data URLs
  if (clean.isEmpty ||
      (!clean.startsWith('http://') &&
          !clean.startsWith('https://') &&
          !clean.startsWith('data:image/'))) {
    return null;
  }

  final fitName = switch (fit) {
    BoxFit.contain => 'contain',
    BoxFit.fill => 'fill',
    BoxFit.fitHeight => 'contain',
    BoxFit.fitWidth => 'contain',
    BoxFit.none => 'none',
    BoxFit.scaleDown => 'scale-down',
    BoxFit.cover => 'cover',
  };
  final viewType =
      'vcloud-network-image-${Object.hash(clean, fitName) & 0x7fffffff}';
  if (_registeredNetworkImages.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (
      int viewId, {
      Object? params,
    }) {
      final image = web.document.createElement('img') as web.HTMLImageElement;
      image.src = clean;
      image.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = fitName
        ..display = 'block'
        ..border = '0'
        ..pointerEvents = 'none';

      final wrapper = web.document.createElement('div') as web.HTMLDivElement;
      wrapper.style
        ..width = '100%'
        ..height = '100%'
        ..overflow = 'hidden'
        ..pointerEvents = 'none';
      wrapper.appendChild(image);
      return wrapper;
    });
  }
  return HtmlElementView(viewType: viewType);
}
