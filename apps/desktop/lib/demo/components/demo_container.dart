import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/constants/routes.dart';
import 'simple_chat_demo.dart';

/// Simplified demo container for all scenarios
class DemoContainer extends StatefulWidget {
  final String scenario;
  final String title;
  final IconData icon;
  final Widget? customContent;

  const DemoContainer({
    super.key,
    required this.scenario,
    required this.title,
    required this.icon,
    this.customContent,
  });

  @override
  State<DemoContainer> createState() => _DemoContainerState();
}

class _DemoContainerState extends State<DemoContainer> {
  bool _showSidebar = false;
  
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
          child: Column(
            children: [
              _buildHeader(colors),
              Expanded(
                child: Row(
                  children: [
                    // Main content
                    Expanded(
                      child: widget.customContent ?? SimpleChatDemo(
                        scenario: widget.scenario,
                      ),
                    ),
                    
                    // Optional sidebar
                    if (_showSidebar)
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          border: Border(left: BorderSide(color: colors.border)),
                        ),
                        child: _buildSidebar(colors),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () {
              if (!mounted) return;
              context.go(AppRoutes.demoOnboarding);
            },
            icon: Icon(Icons.arrow_back, color: colors.onSurface),
            tooltip: 'Back to Agent Selection',
          ),
          
          const SizedBox(width: SpacingTokens.md),
          
          // Icon and title
          Icon(widget.icon, color: colors.primary),
          const SizedBox(width: SpacingTokens.sm),
          Text(
            widget.title,
            style: TextStyles.pageTitle.copyWith(color: colors.onSurface),
          ),
          
          const Spacer(),
          
          // Demo controls
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.sm,
            ),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline, 
                  size: 16, 
                  color: colors.primary,
                ),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Demo Mode',
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: SpacingTokens.md),

          // Theme toggle
          const ThemeToggle(),

          const SizedBox(width: SpacingTokens.sm),

          // Toggle sidebar
          IconButton(
            onPressed: () {
              if (!mounted) return;
              setState(() => _showSidebar = !_showSidebar);
            },
            icon: Icon(
              _showSidebar ? Icons.close : Icons.settings,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ThemeColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(SpacingTokens.lg),
          child: Text(
            'Demo Settings',
            style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
          ),
        ),
        
        Divider(color: colors.border),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(SpacingTokens.lg),
            children: [
              _buildSidebarSection(
                'Scenario',
                widget.scenario,
                Icons.dashboard,
                colors,
              ),
              
              const SizedBox(height: SpacingTokens.lg),
              
              _buildSidebarSection(
                'Active Models',
                'Claude 4.5, GPT-4o',
                Icons.psychology,
                colors,
              ),
              
              const SizedBox(height: SpacingTokens.lg),
              
              _buildSidebarSection(
                'MCP Tools',
                '0 active',
                Icons.extension,
                colors,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarSection(
    String title, 
    String value, 
    IconData icon,
    ThemeColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: TextStyles.bodyMedium.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}