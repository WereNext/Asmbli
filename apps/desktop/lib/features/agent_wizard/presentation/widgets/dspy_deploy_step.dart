import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/models/dspy_types.dart' as dspy_models;
import '../../../../core/services/dspy/dspy.dart';
import '../../models/dspy_agent_wizard_state.dart';

/// Step 5: Deploy & Test
///
/// Validates the configuration and tests the agent against the DSPy backend.
class DspyDeployStep extends ConsumerStatefulWidget {
  final DspyAgentWizardState wizardState;
  final VoidCallback onChanged;
  final VoidCallback onDeploy;

  const DspyDeployStep({
    super.key,
    required this.wizardState,
    required this.onChanged,
    required this.onDeploy,
  });

  @override
  ConsumerState<DspyDeployStep> createState() => _DspyDeployStepState();
}

class _DspyDeployStepState extends ConsumerState<DspyDeployStep> {
  bool _isTestingConnection = false;
  bool _isTesting = false;
  String? _connectionStatus;
  String? _testResult;
  String? _testError;

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(dspyIsConnectedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(SpacingTokens.xxl),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: SpacingTokens.xxl),
              _buildConfigurationSummary(context),
              const SizedBox(height: SpacingTokens.xxl),
              _buildConnectionStatus(context, isConnected),
              const SizedBox(height: SpacingTokens.xxl),
              _buildTestSection(context, isConnected),
              const SizedBox(height: SpacingTokens.xxl),
              _buildDeployButton(context, isConnected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Deploy & Test', style: TextStyles.pageTitle),
        const SizedBox(height: SpacingTokens.sm),
        Text(
          'Review your agent configuration and test it against the DSPy backend.',
          style: TextStyles.bodyMedium.copyWith(
            color: ThemeColors(context).onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationSummary(BuildContext context) {
    final colors = ThemeColors(context);
    final config = widget.wizardState.buildAgentConfig();

    return AsmblCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text('Configuration Summary', style: TextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: SpacingTokens.md),
          _buildSummaryRow(context, 'Agent Name', config.name),
          _buildSummaryRow(context, 'Agent Type', config.agentType.displayName),
          _buildSummaryRow(
              context, 'Reasoning Pattern', config.reasoningPattern.displayName),
          _buildSummaryRow(context, 'Model ID', config.modelId,
              isCode: true),
          if (config.tools.isNotEmpty)
            _buildSummaryRow(
              context,
              'Tools',
              config.tools.map((t) => t.name).join(', '),
            ),
          _buildSummaryRow(
              context, 'Max Iterations', config.maxIterations.toString()),
          if (config.reasoningPattern == dspy_models.DspyReasoningPattern.treeOfThought)
            _buildSummaryRow(
                context, 'Branches', config.numBranches.toString()),
          const SizedBox(height: SpacingTokens.md),
          Container(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend Request Preview',
                  style: TextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: SpacingTokens.xs),
                Text(
                  _getBackendEndpoint(config),
                  style: TextStyles.bodySmall.copyWith(
                    fontFamily: 'monospace',
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value,
      {bool isCode = false}) {
    final colors = ThemeColors(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: SpacingTokens.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isCode
                  ? TextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      color: colors.onSurface,
                    )
                  : TextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context, bool isConnected) {
    final colors = ThemeColors(context);

    return Container(
      padding: const EdgeInsets.all(SpacingTokens.md),
      decoration: BoxDecoration(
        color: isConnected
            ? colors.success.withValues(alpha: 0.1)
            : colors.error.withValues(alpha: 0.1),
        border: Border.all(
          color: isConnected
              ? colors.success.withValues(alpha: 0.3)
              : colors.error.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.check_circle : Icons.error,
            color: isConnected ? colors.success : colors.error,
            size: 24,
          ),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected
                      ? 'DSPy Backend Connected'
                      : 'DSPy Backend Not Connected',
                  style: TextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isConnected ? colors.success : colors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected
                      ? 'Ready to deploy and test your agent'
                      : 'Start the DSPy backend: cd dspy-backend && python main.py',
                  style: TextStyles.bodySmall.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                if (_connectionStatus != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _connectionStatus!,
                    style: TextStyles.bodySmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isConnected)
            TextButton(
              onPressed: _isTestingConnection ? null : _testConnection,
              child: _isTestingConnection
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _buildTestSection(BuildContext context, bool isConnected) {
    final colors = ThemeColors(context);

    return AsmblCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: colors.primary, size: 20),
              const SizedBox(width: SpacingTokens.sm),
              Text('Test Agent', style: TextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: SpacingTokens.sm),
          Text(
            'Send a test request to verify your agent configuration works',
            style: TextStyles.bodySmall.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpacingTokens.md),
          Row(
            children: [
              Expanded(
                child: AsmblButton.secondary(
                  text: _isTesting ? 'Testing...' : 'Run Test',
                  onPressed: isConnected && !_isTesting ? _runTest : null,
                  icon: _isTesting ? Icons.hourglass_empty : Icons.play_arrow,
                ),
              ),
            ],
          ),
          if (_testResult != null || _testError != null) ...[
            const SizedBox(height: SpacingTokens.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: _testError != null
                    ? colors.error.withValues(alpha: 0.1)
                    : colors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _testError != null ? Icons.error : Icons.check,
                        size: 16,
                        color:
                            _testError != null ? colors.error : colors.success,
                      ),
                      const SizedBox(width: SpacingTokens.xs),
                      Text(
                        _testError != null ? 'Test Failed' : 'Test Passed',
                        style: TextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _testError != null
                              ? colors.error
                              : colors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.sm),
                  Text(
                    _testError ?? _testResult ?? '',
                    style: TextStyles.bodySmall.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeployButton(BuildContext context, bool isConnected) {
    final colors = ThemeColors(context);
    final isValid = widget.wizardState.isValid;

    return Column(
      children: [
        if (!isValid)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SpacingTokens.md),
            margin: const EdgeInsets.only(bottom: SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.1),
              border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: colors.warning, size: 20),
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Text(
                    'Please complete all required fields before deploying',
                    style:
                        TextStyles.bodySmall.copyWith(color: colors.warning),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: AsmblButton.primary(
            text: 'Deploy Agent',
            onPressed: isValid && isConnected ? widget.onDeploy : null,
            icon: Icons.rocket_launch,
          ),
        ),
      ],
    );
  }

  String _getBackendEndpoint(dspy_models.DspyAgentConfig config) {
    switch (config.agentType) {
      case dspy_models.DspyAgentType.react:
        return 'POST /agent/execute';
      case dspy_models.DspyAgentType.code:
        return 'POST /code/generate';
      case dspy_models.DspyAgentType.reasoning:
        return 'POST /reasoning (pattern=${config.reasoningPattern.backendValue})';
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Checking connection...';
    });

    try {
      final dspyService = ref.read(dspyServiceProvider);
      final isAvailable = await dspyService.isAvailable();

      if (isAvailable) {
        await dspyService.connect();
        final state = dspyService.state;
        setState(() {
          _connectionStatus =
              'Connected! ${state.documentsIndexed} documents indexed';
        });
      } else {
        setState(() {
          _connectionStatus = 'Failed to connect to DSPy backend';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _runTest() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
      _testError = null;
    });

    try {
      final config = widget.wizardState.buildAgentConfig();
      final dspyService = ref.read(dspyServiceProvider);

      // Run appropriate test based on agent type
      String testPrompt;
      switch (config.agentType) {
        case dspy_models.DspyAgentType.react:
          testPrompt = 'What is 25 * 4?'; // Test with calculator tool
          break;
        case dspy_models.DspyAgentType.code:
          testPrompt = 'Write a hello world function';
          break;
        case dspy_models.DspyAgentType.reasoning:
          testPrompt = 'What is 2 + 2?';
          break;
      }

      // Execute based on agent type
      if (config.agentType == dspy_models.DspyAgentType.react) {
        final result = await dspyService.executeAgent(
          testPrompt,
          tools: config.tools.map((t) => {'name': t.name, 'description': t.description}).toList(),
          maxIterations: config.maxIterations,
        );

        setState(() {
          _testResult = 'Answer: ${result.answer}\n'
              'Success: ${result.success}\n'
              'Iterations: ${result.iterationsUsed}';
        });
      } else if (config.agentType == dspy_models.DspyAgentType.reasoning) {
        // Map our reasoning pattern to the DspyReasoningPattern enum
        DspyReasoningPattern pattern;
        switch (config.reasoningPattern) {
          case dspy_models.DspyReasoningPattern.chainOfThought:
            pattern = DspyReasoningPattern.chainOfThought;
            break;
          case dspy_models.DspyReasoningPattern.treeOfThought:
            pattern = DspyReasoningPattern.treeOfThought;
            break;
          case dspy_models.DspyReasoningPattern.basic:
            pattern = DspyReasoningPattern.basic;
            break;
        }

        final result = await dspyService.reason(
          testPrompt,
          pattern: pattern,
        );

        setState(() {
          _testResult = 'Answer: ${result.answer}\n'
              'Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%';
        });
      } else {
        // Simple chat for code agents
        final result = await dspyService.chat(testPrompt);

        final responsePreview = result.response.length > 200
            ? '${result.response.substring(0, 200)}...'
            : result.response;

        setState(() {
          _testResult = 'Response: $responsePreview';
        });
      }

      widget.wizardState.setValidated(true);
    } catch (e) {
      setState(() {
        _testError = e.toString();
      });
      widget.wizardState.setValidated(false);
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }
}
