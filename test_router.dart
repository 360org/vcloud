import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void test(GoRouter router) {
  router.routerDelegate.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => Container()));
}
