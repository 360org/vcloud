import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final _registeredAvatarViews = <String>{};

Widget? buildHtmlAvatarImage({required String url, required Widget fallback}) {
  final viewType = 'vcloud-avatar-${url.hashCode & 0x7fffffff}';
  if (_registeredAvatarViews.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (
      int viewId, {
      Object? params,
    }) {
      final image = web.document.createElement('img') as web.HTMLImageElement;
      image.src = url;
      image.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'cover'
        ..display = 'block'
        ..border = '0'
        ..pointerEvents = 'none';

      final wrapper = web.document.createElement('div') as web.HTMLDivElement;
      wrapper.style
        ..width = '100%'
        ..height = '100%'
        ..overflow = 'hidden'
        ..borderRadius = '9999px'
        ..pointerEvents = 'none';
      wrapper.appendChild(image);
      return wrapper;
    });
  }
  return HtmlElementView(viewType: viewType);
}
