import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:agent_engine_core/models/agent.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/services/dspy/dspy_service.dart';
import '../../../../core/services/dspy/dspy_agent_service.dart';
import '../../../../providers/agent_provider.dart';

/// Agent Execution Screen
///
/// Allows users to run tasks against an agent using DSPy backend.
/// Supports multiple execution modes: Chat, CoT, ReAct, ToT, RAG.
class AgentExecutionScreen extends ConsumerStatefulWidget {
  final String agentId;

  const AgentExecutionScreen({
    super.key,
    required this.agentId,
  });

  @override
  ConsumerState<AgentExecutionScreen> createState() => _AgentExecutionScreenState();
}

class _AgentExecutionScreenState extends ConsumerState<AgentExecutionScreen> {
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocusNode = FocusNode();
  AgentExecutionMode _selectedMode = AgentExecutionMode.react;
  bool _isExecuting = false;
  AgentExecutionResult? _lastResult;
  String? _error;

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    final agentAsync = ref.watch(agentProvider(widget.agentId));
    final dspyConnection = ref.watch(dspyIsConnectedProvider);

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
          ),
        ),
        child: SafeArea(
          child: agentAsync.when(
            data: (agent) => _buildContent(context, agent, dspyConnection),
            loading: () => Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
            error: (error, stack) => _buildError(context, error.toString()),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Agent agent, bool isConnected) {
    return Column(
      children: [
        _buildHeader(context, agent, isConnected),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left panel - Task input
              Expanded(
                flex: 2,
                child: _buildInputPanel(context, agent),
              ),
              // Right panel - Results
              Expanded(
                flex: 3,
                child: _buildResultsPanel(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Agent agent, bool isConnected) {
    final colors = ThemeColors(context);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
            tooltip: 'Back',
          ),
          const SizedBox(width: SpacingTokens.md),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            ),
            child: Icon(Icons.smart_toy, color: colors.primary, size: 24),
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Execute: ${agent.name}',
                  style: TextStyles.pageTitle.copyWith(fontSize: 18),
                ),
                Text(
                  agent.description,
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.xs,
            ),
            decoration: BoxDecoration(
              color: isConnected
                  ? colors.success.withValues(alpha: 0.1)
                  : colors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
              border: Border.all(
                color: isConnected
                    ? colors.success.withValues(alpha: 0.3)
                    : colors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error_outline,
                  size: 14,
                  color: isConnected ? colors.success : colors.error,
                ),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  isConnected ? 'DSPy Connected' : 'DSPy Offline',
                  style: TextStyles.bodySmall.copyWith(
                    color: isConnected ? colors.success : colors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel(BuildContext context, Agent agent) {
    final colors = ThemeColors(context);

    return Container(
      margin: const EdgeInsets.all(SpacingTokens.lg),
      padding: const EdgeInsets.all(SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode selector
          Text(
            'Execution Mode',
            style: TextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: SpacingTokens.sm),
          _buildModeSelector(context, agent),
          const SizedBox(height: SpacingTokens.lg),

          // Task input
          Text(
            'Task / Question',
            style: TextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Expanded(
            child: TextField(
              controller: _taskController,
              focusNode: _taskFocusNode,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: _getHintForMode(_selectedMode),
                hintStyle: TextStyles.bodyMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                  borderSide: BorderSide(color: colors.border),
                ),
                filled: true,
                fillColor: colors.inputBackground,
              ),
              style: TextStyles.bodyMedium,
              onSubmitted: (_) => _executeTask(agent),
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Execute button
          Row(
            children: [
              Expanded(
                child: AsmblButton.primary(
                  text: _isExecuting ? 'Executing...' : 'Execute Task',
                  onPressed: _isExecuting ? null : () => _executeTask(agent),
                  icon: _isExecuting ? null : Icons.play_arrow,
                ),
              ),
              const SizedBox(width: SpacingTokens.sm),
              IconButton(
                onPressed: _taskController.clear,
                icon: const Icon(Icons.clear),
                tooltip: 'Clear',
              ),
            ],
          ),

          // Quick actions
          const SizedBox(height: SpacingTokens.md),
          _buildQuickActions(context),
        ],
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context, Agent agent) {
    final colors = ThemeColors(context);

    // Determine default mode from agent config
    final defaultMode = _getDefaultModeForAgent(agent);

    return Wrap(
      spacing: SpacingTokens.sm,
      runSpacing: SpacingTokens.sm,
      children: AgentExecutionMode.values.map((mode) {
        final isSelected = _selectedMode == mode;
        final isDefault = mode == defaultMode;

        return GestureDetector(
          onTap: () => setState(() => _selectedMode = mode),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                  : colors.surfaceVariant,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: isSelected
                  ? null
                  : Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getModeIcon(mode),
                  size: 16,
                  color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  _getModeLabel(mode),
                  style: TextStyles.bodySmall.copyWith(
                    color: isSelected ? colors.onPrimary : colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isDefault) ...[
                  const SizedBox(width: SpacingTokens.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.onPrimary.withValues(alpha: 0.2)
                          : colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.xs),
                    ),
                    child: Text(
                      'Default',
                      style: TextStyles.caption.copyWith(
                        fontSize: 9,
                        color: isSelected ? colors.onPrimary : colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final colors = ThemeColors(context);

    final quickTasks = _getQuickTasksForMode(_selectedMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Tasks',
          style: TextStyles.caption.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: SpacingTokens.xs),
        Wrap(
          spacing: SpacingTokens.xs,
          runSpacing: SpacingTokens.xs,
          children: quickTasks.map((task) {
            return GestureDetector(
              onTap: () {
                _taskController.text = task;
                _taskFocusNode.requestFocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.sm,
                  vertical: SpacingTokens.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  task,
                  style: TextStyles.caption.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultsPanel(BuildContext context) {
    final colors = ThemeColors(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, SpacingTokens.lg, SpacingTokens.lg, SpacingTokens.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Results header
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.output, size: 18, color: colors.primary),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Execution Results',
                  style: TextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_lastResult != null)
                  IconButton(
                    onPressed: () => _copyResult(),
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copy result',
                  ),
              ],
            ),
          ),

          // Results content
          Expanded(
            child: _buildResultContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildResultContent(BuildContext context) {
    final colors = ThemeColors(context);

    if (_isExecuting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: SpacingTokens.lg),
            Text(
              'Executing task...',
              style: TextStyles.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              'Mode: ${_getModeLabel(_selectedMode)}',
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: SpacingTokens.md),
            Text(
              'Execution Failed',
              style: TextStyles.bodyLarge.copyWith(color: colors.error),
            ),
            const SizedBox(height: SpacingTokens.sm),
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                border: Border.all(color: colors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                style: TextStyles.bodySmall.copyWith(color: colors.error),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (_lastResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 64,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: SpacingTokens.lg),
            Text(
              'No results yet',
              style: TextStyles.bodyLarge.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: SpacingTokens.sm),
            Text(
              'Enter a task and click Execute to run the agent',
              style: TextStyles.bodyMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Show result
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success/failure indicator
          _buildResultHeader(context),
          const SizedBox(height: SpacingTokens.md),

          // Answer
          _buildSection(
            context,
            'Answer',
            Icons.check_circle_outline,
            _lastResult!.answer,
          ),

          // Reasoning (for CoT/ToT)
          if (_lastResult!.reasoning != null) ...[
            const SizedBox(height: SpacingTokens.lg),
            _buildSection(
              context,
              'Reasoning',
              Icons.psychology,
              _lastResult!.reasoning!,
            ),
          ],

          // Steps (for ReAct)
          if (_lastResult!.steps.isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.lg),
            _buildStepsSection(context),
          ],

          // Metadata
          const SizedBox(height: SpacingTokens.lg),
          _buildMetadataSection(context),
        ],
      ),
    );
  }

  Widget _buildResultHeader(BuildContext context) {
    final colors = ThemeColors(context);
    final result = _lastResult!;

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: result.success
            ? colors.success.withValues(alpha: 0.1)
            : colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(
          color: result.success
              ? colors.success.withValues(alpha: 0.3)
              : colors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.warning,
            color: result.success ? colors.success : colors.warning,
            size: 20,
          ),
          const SizedBox(width: SpacingTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.success ? 'Execution Successful' : 'Partial Success',
                  style: TextStyles.bodyMedium.copyWith(
                    color: result.success ? colors.success : colors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Mode: ${_getModeLabel(result.mode)} | Time: ${result.executionTime.inMilliseconds}ms',
                  style: TextStyles.caption.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Confidence
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.sm,
              vertical: SpacingTokens.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            ),
            child: Text(
              '${(result.confidence * 100).toStringAsFixed(0)}%',
              style: TextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: _getConfidenceColor(result.confidence, colors),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    String content,
  ) {
    final colors = ThemeColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              title,
              style: TextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SpacingTokens.md),
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            border: Border.all(color: colors.border),
          ),
          child: SelectableText(
            content,
            style: TextStyles.bodyMedium.copyWith(height: 1.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsSection(BuildContext context) {
    final colors = ThemeColors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline, size: 16, color: colors.primary),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              'Execution Steps (${_lastResult!.steps.length})',
              style: TextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        ..._lastResult!.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == _lastResult!.steps.length - 1;

          return _buildStepItem(context, step, index, isLast);
        }),
      ],
    );
  }

  Widget _buildStepItem(
    BuildContext context,
    AgentExecutionStep step,
    int index,
    bool isLast,
  ) {
    final colors = ThemeColors(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyles.caption.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: colors.border,
              ),
          ],
        ),
        const SizedBox(width: SpacingTokens.md),
        // Step content
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: SpacingTokens.md),
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thought
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 14, color: colors.warning),
                    const SizedBox(width: SpacingTokens.xs),
                    Expanded(
                      child: Text(
                        step.thought,
                        style: TextStyles.bodySmall.copyWith(
                          color: colors.onSurface,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpacingTokens.sm),
                // Action
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.play_arrow, size: 14, color: colors.primary),
                    const SizedBox(width: SpacingTokens.xs),
                    Expanded(
                      child: Text(
                        step.action,
                        style: TextStyles.bodySmall.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                // Observation
                if (step.observation != null) ...[
                  const SizedBox(height: SpacingTokens.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.visibility, size: 14, color: colors.success),
                      const SizedBox(width: SpacingTokens.xs),
                      Expanded(
                        child: Text(
                          step.observation!,
                          style: TextStyles.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataSection(BuildContext context) {
    final colors = ThemeColors(context);
    final metadata = _lastResult!.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: colors.onSurfaceVariant),
            const SizedBox(width: SpacingTokens.xs),
            Text(
              'Metadata',
              style: TextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.sm),
        Wrap(
          spacing: SpacingTokens.md,
          runSpacing: SpacingTokens.xs,
          children: metadata.entries.map((entry) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.sm,
                vertical: SpacingTokens.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
              ),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: TextStyles.caption.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, String error) {
    final colors = ThemeColors(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colors.error),
          const SizedBox(height: SpacingTokens.lg),
          Text(
            'Agent not found',
            style: TextStyles.pageTitle.copyWith(color: colors.error),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            error,
            style: TextStyles.bodyMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          AsmblButton.secondary(
            text: 'Go Back',
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Future<void> _executeTask(Agent agent) async {
    if (_taskController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a task');
      return;
    }

    setState(() {
      _isExecuting = true;
      _error = null;
    });

    try {
      final agentService = ref.read(dspyAgentServiceProvider);
      final result = await agentService.execute(
        agentId: agent.id,
        task: _taskController.text.trim(),
        mode: _selectedMode,
      );

      setState(() {
        _lastResult = result;
        _isExecuting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isExecuting = false;
      });
    }
  }

  void _copyResult() {
    if (_lastResult != null) {
      Clipboard.setData(ClipboardData(text: _lastResult!.answer));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Result copied to clipboard')),
      );
    }
  }

  AgentExecutionMode _getDefaultModeForAgent(Agent agent) {
    final dspyConfig = agent.configuration['dspy'] as Map<String, dynamic>?;
    if (dspyConfig != null) {
      final agentType = dspyConfig['agentType'] as String?;
      switch (agentType) {
        case 'react':
          return AgentExecutionMode.react;
        case 'code':
          return AgentExecutionMode.chainOfThought;
        case 'reasoning':
          final pattern = dspyConfig['reasoningPattern'] as String?;
          if (pattern == 'treeOfThought') return AgentExecutionMode.treeOfThought;
          return AgentExecutionMode.chainOfThought;
      }
    }
    return AgentExecutionMode.react;
  }

  String _getModeLabel(AgentExecutionMode mode) {
    switch (mode) {
      case AgentExecutionMode.chat:
        return 'Chat';
      case AgentExecutionMode.chainOfThought:
        return 'Chain of Thought';
      case AgentExecutionMode.react:
        return 'ReAct';
      case AgentExecutionMode.treeOfThought:
        return 'Tree of Thought';
      case AgentExecutionMode.rag:
        return 'RAG';
    }
  }

  IconData _getModeIcon(AgentExecutionMode mode) {
    switch (mode) {
      case AgentExecutionMode.chat:
        return Icons.chat_bubble_outline;
      case AgentExecutionMode.chainOfThought:
        return Icons.linear_scale;
      case AgentExecutionMode.react:
        return Icons.smart_toy;
      case AgentExecutionMode.treeOfThought:
        return Icons.account_tree;
      case AgentExecutionMode.rag:
        return Icons.source;
    }
  }

  String _getHintForMode(AgentExecutionMode mode) {
    switch (mode) {
      case AgentExecutionMode.chat:
        return 'Ask a question or request information...';
      case AgentExecutionMode.chainOfThought:
        return 'Ask a question requiring step-by-step reasoning...';
      case AgentExecutionMode.react:
        return 'Describe a task that may require tool use (e.g., calculate 25 * 4.5)...';
      case AgentExecutionMode.treeOfThought:
        return 'Ask a question with multiple possible approaches (e.g., compare options)...';
      case AgentExecutionMode.rag:
        return 'Ask a question about your uploaded documents...';
    }
  }

  List<String> _getQuickTasksForMode(AgentExecutionMode mode) {
    switch (mode) {
      case AgentExecutionMode.chat:
        return ['Hello!', 'What can you help me with?', 'Tell me about yourself'];
      case AgentExecutionMode.chainOfThought:
        return ['Explain why the sky is blue', 'How does photosynthesis work?', 'What causes inflation?'];
      case AgentExecutionMode.react:
        return ['Calculate 125 * 8.5', 'What is 2^10?', 'Find the square root of 144'];
      case AgentExecutionMode.treeOfThought:
        return ['Compare Python vs JavaScript', 'Pros and cons of remote work', 'Should I use SQL or NoSQL?'];
      case AgentExecutionMode.rag:
        return ['Summarize the main points', 'What does the document say about...', 'Find relevant sections about...'];
    }
  }

  Color _getConfidenceColor(double confidence, ThemeColors colors) {
    if (confidence >= 0.8) return colors.success;
    if (confidence >= 0.5) return colors.warning;
    return colors.error;
  }
}
