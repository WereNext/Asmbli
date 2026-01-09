import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/constants/routes.dart';
import '../../services/human_verification_service.dart';
import '../../models/verification_request.dart';
import '../../models/verification_rule.dart';
import '../widgets/verification_request_card.dart';

/// Human Verification Dashboard - shadcn/Radix inspired design
class HumanVerificationDashboard extends ConsumerStatefulWidget {
  const HumanVerificationDashboard({super.key});

  @override
  ConsumerState<HumanVerificationDashboard> createState() => _HumanVerificationDashboardState();
}

class _HumanVerificationDashboardState extends ConsumerState<HumanVerificationDashboard> {
  int _selectedTab = 0;
  String _filterSource = 'All';

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(humanVerificationServiceProvider);
    final rules = ref.watch(verificationRulesProvider);
    final colors = ThemeColors(context);

    return Scaffold(
      backgroundColor: colors.background,
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
              const AppNavigationBar(currentRoute: '/human-verification'),
              Expanded(
                child: StreamBuilder<List<VerificationRequest>>(
                  stream: service.requestsStream,
                  initialData: const [],
                  builder: (context, snapshot) {
                    final requests = snapshot.data ?? [];
                    final pending = requests.where((r) => r.status == VerificationStatus.pending).toList();
                    final history = requests.where((r) => r.status != VerificationStatus.pending).toList();
                    final sources = {'All', ...requests.map((r) => r.source)};

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(colors, pending.length),
                          const SizedBox(height: 32),
                          _buildTabs(colors, pending.length, history.length, rules.where((r) => r.enabled).length),
                          const SizedBox(height: 24),
                          Expanded(
                            child: _selectedTab == 0
                                ? _buildPendingContent(context, colors, service, _filterRequests(pending), sources)
                                : _selectedTab == 1
                                    ? _buildHistoryContent(context, colors, _filterRequests(history), sources)
                                    : _buildRulesContent(context, colors, rules),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<VerificationRequest> _filterRequests(List<VerificationRequest> requests) {
    if (_filterSource == 'All') return requests;
    return requests.where((r) => r.source == _filterSource).toList();
  }

  Widget _buildHeader(ThemeColors colors, int pendingCount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Human Verification',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review and approve actions from your agents and workflows.',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildGhostButton(
          colors,
          icon: Icons.science_outlined,
          label: 'Test Request',
          onPressed: () => _createTestRequest(),
        ),
      ],
    );
  }

  Widget _buildTabs(ThemeColors colors, int pendingCount, int historyCount, int activeRulesCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTab(colors, 0, 'Inbox', pendingCount > 0 ? pendingCount : null),
          _buildTab(colors, 1, 'History', null),
          _buildTab(colors, 2, 'Rules', activeRulesCount > 0 ? activeRulesCount : null),
        ],
      ),
    );
  }

  Widget _buildTab(ThemeColors colors, int index, String label, int? badge) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: colors.border.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? colors.onSurface : colors.onSurfaceVariant,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: index == 0 ? colors.primary.withValues(alpha: 0.15) : colors.onSurfaceVariant.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: index == 0 ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGhostButton(ThemeColors colors, {required IconData icon, required String label, required VoidCallback onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createTestRequest() {
    final service = ref.read(humanVerificationServiceProvider);
    service.requestVerification(
      source: 'Test Agent',
      title: 'Execute Shell Command',
      description: 'The agent wants to execute a shell command that may modify files.',
      data: {
        'command': 'rm -rf ./temp_cache',
        'working_directory': '/Users/demo/project',
        'risk_level': 'medium',
      },
      timeout: const Duration(minutes: 5),
      category: VerificationCategory.shellCommands,
      riskLevel: RiskLevel.medium,
    );
  }

  Widget _buildPendingContent(BuildContext context, ThemeColors colors, HumanVerificationService service, List<VerificationRequest> pending, Set<String> sources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sources.length > 2) _buildFilterBar(colors, sources),
        if (sources.length > 2) const SizedBox(height: 16),
        Expanded(
          child: pending.isEmpty
              ? _buildEmptyState(colors, Icons.inbox_outlined, 'No pending requests', 'When agents request approval, they\'ll appear here.')
              : ListView.separated(
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildRequestCard(context, colors, pending[index], service),
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryContent(BuildContext context, ThemeColors colors, List<VerificationRequest> history, Set<String> sources) {
    final sorted = List<VerificationRequest>.from(history)
      ..sort((a, b) => (b.resolvedAt ?? b.createdAt).compareTo(a.resolvedAt ?? a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sources.length > 2) _buildFilterBar(colors, sources),
        if (sources.length > 2) const SizedBox(height: 16),
        Expanded(
          child: sorted.isEmpty
              ? _buildEmptyState(colors, Icons.history_outlined, 'No history yet', 'Resolved requests will appear here.')
              : ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildHistoryCard(context, colors, sorted[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(ThemeColors colors, Set<String> sources) {
    return Row(
      children: [
        Text('Filter:', style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filterSource,
              isDense: true,
              style: TextStyle(fontSize: 13, color: colors.onSurface),
              dropdownColor: colors.surface,
              icon: Icon(Icons.keyboard_arrow_down, size: 16, color: colors.onSurfaceVariant),
              items: sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _filterSource = v ?? 'All'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(BuildContext context, ThemeColors colors, VerificationRequest request, HumanVerificationService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 12, color: colors.warning),
                    const SizedBox(width: 4),
                    Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.warning)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(request.source, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
              const Spacer(),
              Text(_formatTime(request.createdAt), style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Text(request.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface)),
          const SizedBox(height: 4),
          Text(request.description, style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant, height: 1.4)),
          if (request.data.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: request.data.entries.where((e) => !e.key.startsWith('_')).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.key}: ', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant, fontFamily: 'monospace')),
                      Expanded(child: Text('${e.value}', style: TextStyle(fontSize: 12, color: colors.onSurface, fontFamily: 'monospace'))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildOutlineButton(colors, 'Reject', onPressed: () => _showRejectDialog(context, colors, request, service), isDestructive: true),
              const SizedBox(width: 8),
              _buildPrimaryButton(colors, 'Approve', onPressed: () => service.approveRequest(request.id)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, ThemeColors colors, VerificationRequest request) {
    final isApproved = request.status == VerificationStatus.approved;
    final isRejected = request.status == VerificationStatus.rejected;
    final statusColor = isApproved ? colors.success : isRejected ? colors.error : colors.onSurfaceVariant;
    final statusText = isApproved ? 'Approved' : isRejected ? 'Rejected' : 'Timed Out';
    final statusIcon = isApproved ? Icons.check_circle_outline : isRejected ? Icons.cancel_outlined : Icons.timer_off_outlined;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 18, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface)),
                const SizedBox(height: 2),
                Text('${request.source} · ${_formatTime(request.resolvedAt ?? request.createdAt)}', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesContent(BuildContext context, ThemeColors colors, List<VerificationRule> rules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Configure when agents should ask for your approval.',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ),
            _buildGhostButton(colors, icon: Icons.restore, label: 'Reset', onPressed: () {
              ref.read(verificationRulesProvider.notifier).resetToDefaults();
            }),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.separated(
            itemCount: rules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildRuleRow(context, colors, rules[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleRow(BuildContext context, ThemeColors colors, VerificationRule rule) {
    final riskColors = {
      RiskLevel.low: colors.success,
      RiskLevel.medium: colors.warning,
      RiskLevel.high: Colors.orange,
      RiskLevel.critical: colors.error,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: rule.enabled ? colors.border : colors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getCategoryIcon(rule.category),
            size: 18,
            color: rule.enabled ? colors.onSurface : colors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rule.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: rule.enabled ? colors.onSurface : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: riskColors[rule.minimumRiskLevel]!.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        rule.minimumRiskLevel.displayName,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: riskColors[rule.minimumRiskLevel]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rule.description,
                  style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant.withValues(alpha: rule.enabled ? 1 : 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 16, color: colors.onSurfaceVariant),
            onPressed: () => _showEditRuleDialog(context, colors, rule),
            splashRadius: 16,
            tooltip: 'Edit',
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 20,
            child: Switch(
              value: rule.enabled,
              onChanged: (v) => ref.read(verificationRulesProvider.notifier).toggleRule(rule.id),
              activeThumbColor: colors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutlineButton(ThemeColors colors, String label, {required VoidCallback onPressed, bool isDestructive = false}) {
    final color = isDestructive ? colors.error : colors.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: isDestructive ? colors.error.withValues(alpha: 0.5) : colors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(ThemeColors colors, String label, {required VoidCallback onPressed}) {
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeColors colors, IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border),
            ),
            child: Icon(icon, size: 28, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, ThemeColors colors, VerificationRequest request, HumanVerificationService service) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Reject Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 14, color: colors.onSurface),
            decoration: InputDecoration(
              hintText: 'Reason (optional)',
              hintStyle: TextStyle(color: colors.onSurfaceVariant),
              filled: true,
              fillColor: colors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: colors.primary)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            maxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: colors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              service.rejectRequest(request.id, feedback: controller.text.isEmpty ? null : controller.text);
            },
            child: Text('Reject', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
  }

  void _showEditRuleDialog(BuildContext context, ThemeColors colors, VerificationRule rule) {
    final nameController = TextEditingController(text: rule.name);
    final descController = TextEditingController(text: rule.description);
    final patternsController = TextEditingController(text: rule.patterns.join(', '));
    var selectedRiskLevel = rule.minimumRiskLevel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Edit Rule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogField(colors, 'Name', nameController),
                const SizedBox(height: 14),
                _buildDialogField(colors, 'Description', descController, maxLines: 2),
                const SizedBox(height: 14),
                Text('Minimum Risk Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  children: RiskLevel.values.map((level) {
                    final isSelected = selectedRiskLevel == level;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setDialogState(() => selectedRiskLevel = level),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? colors.primary : colors.border),
                          ),
                          child: Text(
                            level.displayName,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? colors.primary : colors.onSurfaceVariant),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _buildDialogField(colors, 'Patterns (comma-separated)', patternsController, hint: 'e.g., delete, remove, rm\\s'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: colors.onSurfaceVariant)),
            ),
            TextButton(
              onPressed: () {
                final patterns = patternsController.text.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
                ref.read(verificationRulesProvider.notifier).updateRule(
                  rule.copyWith(name: nameController.text, description: descController.text, minimumRiskLevel: selectedRiskLevel, patterns: patterns),
                );
                Navigator.pop(context);
              },
              child: Text('Save', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(ThemeColors colors, String label, TextEditingController controller, {int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 13, color: colors.onSurface),
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
            filled: true,
            fillColor: colors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: colors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: colors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: colors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(VerificationCategory category) {
    switch (category) {
      case VerificationCategory.fileOperations: return Icons.folder_outlined;
      case VerificationCategory.shellCommands: return Icons.terminal;
      case VerificationCategory.apiCalls: return Icons.public_outlined;
      case VerificationCategory.dataModification: return Icons.storage_outlined;
      case VerificationCategory.externalCommunication: return Icons.mail_outline;
      case VerificationCategory.codeExecution: return Icons.code;
      case VerificationCategory.systemChanges: return Icons.settings_outlined;
      case VerificationCategory.financialOperations: return Icons.account_balance_outlined;
      case VerificationCategory.custom: return Icons.tune;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}';
  }
}
