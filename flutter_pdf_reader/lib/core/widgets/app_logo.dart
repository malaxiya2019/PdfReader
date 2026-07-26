import 'package:flutter/material.dart';

/// All PDF Reader 应用 Logo 组件
///
/// Phase 10: 统一的品牌 Logo
/// 在首页、启动页、关于页等位置复用
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool animated;

  const AppLogo({
    super.key,
    this.size = 72,
    this.showText = true,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(theme),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            'All PDF Reader',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: size > 60 ? 22 : 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '高颜值暗黑风 PDF 阅读器',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: size > 60 ? 14 : 11,
            ),
          ),
        ],
      ],
    );

    if (animated) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(opacity: value, child: child),
          );
        },
        child: logo,
      );
    }

    return logo;
  }

  Widget _buildIcon(ThemeData theme) {
    final iconSize = size * 0.7;
    final iconRadius = size / 2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(iconRadius * 0.5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF121222),
          ],
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.6),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // PDF Document Icon
          Icon(
            Icons.picture_as_pdf_rounded,
            size: iconSize,
            color: theme.colorScheme.primary,
          ),

          // Play indicator (bottom overlay)
          Positioned(
            bottom: size * 0.08,
            right: size * 0.08,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(size * 0.07),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: size * 0.16,
                color: Colors.black87,
              ),
            ),
          ),

          // Decorative rings
          Positioned(
            top: -size * 0.08,
            left: -size * 0.08,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.amber.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 全屏启动页 Logo
class SplashLogo extends StatelessWidget {
  const SplashLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121222),
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value < 0.3 ? 0 : (value - 0.3) / 0.7,
              child: Transform.scale(
                scale: 0.8 + value * 0.2,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulse animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1500),
                builder: (context, value, child) {
                  return Container(
                    width: 120 + value * 8,
                    height: 120 + value * 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF1A1A2E),
                          Color(0xFF121222),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.3 + value * 0.3),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.15 + value * 0.15),
                          blurRadius: 20 + value * 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 52,
                          color: Colors.redAccent,
                        ),
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'All PDF Reader',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'v1.0.0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.redAccent.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 关于页 Logo + 版本信息
class AboutLogo extends StatelessWidget {
  const AboutLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 96),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'v1.0.0',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'All PDF Reader — Android PDF 阅读器',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
