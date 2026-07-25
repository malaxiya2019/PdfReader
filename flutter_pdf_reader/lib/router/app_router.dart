import 'package:flutter/material.dart';
import '../features/home/home_page.dart';
import '../features/reader/pdf_reader_page.dart';

class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String reader = '/reader';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
          settings: settings,
        );
      case reader:
        final args = settings.arguments as Map<String, String>?;
        return MaterialPageRoute(
          builder: (_) => PdfReaderPage(
            filePath: args?['path'] ?? '',
            fileName: args?['name'] ?? 'Unknown',
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
          settings: settings,
        );
    }
  }
}
