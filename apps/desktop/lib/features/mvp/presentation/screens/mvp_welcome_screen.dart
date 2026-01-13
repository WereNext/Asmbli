import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';

/// MVP Welcome Screen - First screen users see
/// Simple, focused on getting them to setup quickly
class MvpWelcomeScreen extends StatelessWidget {
  const MvpWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              colors.backgroundGradientStart,
              colors.backgroundGradientMiddle,
              colors.backgroundGradientEnd,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.pageHorizontal),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(BorderRadiusTokens.xl),
                      ),
                      child: Icon(
                        Icons.psychology_alt,
                        size: 64,
                        color: colors.primary,
                      ),
                    ),

                    const SizedBox(height: SpacingTokens.sectionSpacing),

                    // Welcome text
                    Text(
                      'Welcome to Asmbli',
                      style: TextStyles.pageTitle.copyWith(
                        color: colors.onSurface,
                        fontSize: 32,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: SpacingTokens.componentSpacing),

                    Text(
                      'Your customizable AI research assistant',
                      style: TextStyles.bodyLarge.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: SpacingTokens.sectionSpacing * 2),

                    // Features list
                    _FeatureItem(
                      icon: Icons.search,
                      text: 'Web-powered research with sources',
                    ),
                    const SizedBox(height: SpacingTokens.componentSpacing),
                    _FeatureItem(
                      icon: Icons.tune,
                      text: 'Customize personality and behavior',
                    ),
                    const SizedBox(height: SpacingTokens.componentSpacing),
                    _FeatureItem(
                      icon: Icons.history,
                      text: 'Conversation history saved locally',
                    ),

                    const SizedBox(height: SpacingTokens.sectionSpacing * 2),

                    // Get started button
                    SizedBox(
                      width: double.infinity,
                      child: AsmblButton.primary(
                        text: 'Get Started',
                        icon: Icons.arrow_forward,
                        onPressed: () => context.go('/mvp/setup'),
                        size: AsmblButtonSize.large,
                      ),
                    ),

                    const SizedBox(height: SpacingTokens.componentSpacing),

                    // Skip option
                    TextButton(
                      onPressed: () => context.go('/mvp/chat'),
                      child: Text(
                        'Skip setup (configure later)',
                        style: TextStyles.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(SpacingTokens.iconSpacing),
          decoration: BoxDecoration(
            color: colors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
          ),
          child: Icon(
            icon,
            size: 20,
            color: colors.success,
          ),
        ),
        const SizedBox(width: SpacingTokens.componentSpacing),
        Expanded(
          child: Text(
            text,
            style: TextStyles.bodyMedium.copyWith(
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
