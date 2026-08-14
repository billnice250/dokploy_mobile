import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';

class DokployMobileApp extends ConsumerWidget {
  const DokployMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Dokploy Mobile',
      debugShowCheckedModeBanner: false,
      theme: DokployTheme.light,
      darkTheme: DokployTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
