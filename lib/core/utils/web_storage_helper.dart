export 'web_storage_stub.dart'
    if (dart.library.js_interop) 'web_storage_web.dart'
    if (dart.library.html) 'web_storage_web.dart';
