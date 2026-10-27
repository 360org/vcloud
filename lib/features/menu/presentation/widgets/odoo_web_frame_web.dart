import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final _registeredFrames = <String>{};

Widget? buildHtmlIframe({
  required String url,
  required VoidCallback onLoaded,
  void Function(String error)? onError,
}) {
  try {
    final clean = url.trim();
    if (clean.isEmpty) {
      debugPrint('[OdooWebFrame] Cảnh báo: URL trống!');
      return null;
    }

    final viewType = 'vcloud-odoo-frame-${clean.hashCode & 0x7fffffff}';
    debugPrint('[OdooWebFrame] Khởi tạo HtmlIframe: viewType=$viewType, url=$clean');

    if (_registeredFrames.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (
        int viewId, {
        Object? params,
      }) {
        try {
          final iframe =
              web.document.createElement('iframe') as web.HTMLIFrameElement;
          iframe.src = clean;
          iframe.style
            ..width = '100%'
            ..height = '100%'
            ..border = '0'
            ..display = 'block'
            ..backgroundColor = '#FFFFFF';
          iframe.allow =
              'camera; microphone; geolocation; fullscreen; clipboard-read; clipboard-write';

          iframe.onload = ((web.Event e) {
            debugPrint('[OdooWebFrame] Iframe onload thành công: viewId=$viewId');
            try {
              onLoaded();
            } catch (err) {
              debugPrint('[OdooWebFrame] Lỗi trong onLoaded callback: $err');
            }
          }).toJS;

          iframe.onerror = ((web.Event e) {
            final errMsg = 'Iframe onerror triggered: viewId=$viewId';
            debugPrint('[OdooWebFrame] $errMsg');
            try {
              onError?.call(errMsg);
            } catch (err) {
              debugPrint('[OdooWebFrame] Lỗi trong onError callback: $err');
            }
          }).toJS;

          return iframe;
        } catch (e, stack) {
          debugPrint('[OdooWebFrame] Lỗi khi tạo iframe element: $e\n$stack');
          onError?.call(e.toString());
          final fallback = web.document.createElement('div') as web.HTMLDivElement;
          fallback.innerText = 'Lỗi khởi tạo iframe: $e';
          return fallback;
        }
      });
    }

    return HtmlElementView(viewType: viewType);
  } catch (e, stack) {
    debugPrint('[OdooWebFrame] Ngoại lệ ngoài buildHtmlIframe: $e\n$stack');
    onError?.call(e.toString());
    return null;
  }
}
