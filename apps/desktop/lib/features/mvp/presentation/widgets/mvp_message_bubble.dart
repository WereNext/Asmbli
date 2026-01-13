import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design_system/design_system.dart';
import '../../models/mvp_message.dart';

/// Message bubble widget for MVP chat
class MvpMessageBubble extends StatelessWidget {
  final MvpMessage message;
  final bool isStreaming;

  const MvpMessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    final isUser = message.role == MvpMessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
          decoration: BoxDecoration(
            color: isUser
                ? colors.primary.withValues(alpha: 0.1)
                : colors.surface,
            borderRadius: BorderRadius.circular(BorderRadiusTokens.md).copyWith(
              bottomRight: isUser
                  ? const Radius.circular(BorderRadiusTokens.xs)
                  : null,
              bottomLeft: !isUser
                  ? const Radius.circular(BorderRadiusTokens.xs)
                  : null,
            ),
            border: Border.all(
              color: isUser
                  ? colors.primary.withValues(alpha: 0.2)
                  : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Message content
              SelectableText(
                message.content.isEmpty && isStreaming
                    ? '...'
                    : message.content,
                style: TextStyles.bodyMedium.copyWith(
                  color: colors.onSurface,
                ),
              ),

              // Streaming indicator
              if (isStreaming && message.content.isNotEmpty) ...[
                const SizedBox(height: SpacingTokens.iconSpacing),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.iconSpacing),
                    Text(
                      'Thinking...',
                      style: TextStyles.caption.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],

              // Actions row (copy button for assistant messages)
              if (!isUser && !isStreaming && message.content.isNotEmpty) ...[
                const SizedBox(height: SpacingTokens.iconSpacing),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionButton(
                      icon: Icons.copy,
                      tooltip: 'Copy',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.xs_precise),
            child: Icon(
              icon,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
