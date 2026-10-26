import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final _registeredFrames = <String>{};

Widget? buildHtmlIframe({
  required String url,
  required VoidCallback onLoaded,
}) {
  final clean = url.trim();
  if (clean.isEmpty) return null;

  final viewType = 'vcloud-odoo-frame-${clean.hashCode & 0x7fffffff}';
  if (_registeredFrames.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (
      int viewId, {
      Object? params,
    }) {
      final iframe =
          web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = clean;
      iframe.style
        ..width = '100%'
        ..height = '100%'
        ..border = '0'
        ..display = 'block';
      iframe.allow = 'camera; microphone; geolocation; fullscreen';
      iframe.onload = ((web.Event e) {
        onLoaded();
      }).toJS;
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}
