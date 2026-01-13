import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design_system/design_system.dart';
import '../../models/mvp_message.dart';

/// Widget to display source citations from web search
class MvpSourceCitation extends StatefulWidget {
  final List<MvpSource> sources;

  const MvpSourceCitation({
    super.key,
    required this.sources,
  });

  @override
  State<MvpSourceCitation> createState() => _MvpSourceCitationState();
}

class _MvpSourceCitationState extends State<MvpSourceCitation> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    if (widget.sources.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.componentSpacing),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  Icons.source,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: SpacingTokens.iconSpacing),
                Text(
                  'Sources (${widget.sources.length})',
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),

          // Collapsed view - show first 2 sources inline
          if (!_expanded) ...[
            const SizedBox(height: SpacingTokens.iconSpacing),
            Wrap(
              spacing: SpacingTokens.iconSpacing,
              runSpacing: SpacingTokens.xs_precise,
              children: widget.sources.take(3).map((source) {
                return _SourceChip(source: source);
              }).toList(),
            ),
          ],

          // Expanded view - show all sources with details
          if (_expanded) ...[
            const SizedBox(height: SpacingTokens.componentSpacing),
            ...widget.sources.asMap().entries.map((entry) {
              final index = entry.key;
              final source = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < widget.sources.length - 1
                      ? SpacingTokens.iconSpacing
                      : 0,
                ),
                child: _SourceDetail(
                  index: index + 1,
                  source: source,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final MvpSource source;

  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openUrl(source.url),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.iconSpacing,
            vertical: SpacingTokens.xs_precise,
          ),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
            border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link,
                size: 12,
                color: colors.primary,
              ),
              const SizedBox(width: SpacingTokens.xs_precise),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  source.title,
                  style: TextStyles.caption.copyWith(
                    color: colors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _SourceDetail extends StatelessWidget {
  final int index;
  final MvpSource source;

  const _SourceDetail({
    required this.index,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return InkWell(
      onTap: () => _openUrl(source.url),
      borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
      child: Container(
        padding: const EdgeInsets.all(SpacingTokens.iconSpacing),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index badge
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: TextStyles.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.iconSpacing),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.title,
                    style: TextStyles.bodySmall.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatUrl(source.url),
                    style: TextStyles.caption.copyWith(
                      color: colors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (source.snippet != null) ...[
                    const SizedBox(height: SpacingTokens.xs_precise),
                    Text(
                      source.snippet!,
                      style: TextStyles.caption.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // External link icon
            Icon(
              Icons.open_in_new,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _formatUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url;
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
