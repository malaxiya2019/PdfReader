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
        return _buildPageRoute(
          const HomePage(),
          settings,
          transition: TransitionType.fade,
        );
      case reader:
        final args = settings.arguments as Map<String, String>?;
        return _buildPageRoute(
          PdfReaderPage(
            filePath: args?['path'] ?? '',
            fileName: args?['name'] ?? 'Unknown',
          ),
          settings,
          transition: TransitionType.slideFromRight,
        );
      default:
        return _buildPageRoute(
          const HomePage(),
          settings,
          transition: TransitionType.fade,
        );
    }
  }

  static PageRouteBuilder _buildPageRoute(
    Widget page,
    RouteSettings settings, {
    TransitionType transition = TransitionType.fade,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        switch (transition) {
          case TransitionType.fade:
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          case TransitionType.slideFromRight:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          case TransitionType.slideFromBottom:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          case TransitionType.scale:
            return ScaleTransition(
              scale: Tween<double>(
                begin: 0.9,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
        }
      },
    );
  }
}

enum TransitionType { fade, slideFromRight, slideFromBottom, scale }
