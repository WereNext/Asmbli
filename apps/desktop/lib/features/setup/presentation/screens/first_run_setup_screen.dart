import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/services/dspy/dspy_backend_setup_service.dart';

/// Provider for the setup service
final setupServiceProvider = Provider((ref) => DspyBackendSetupService());

/// Provider for setup state
final setupStateProvider = StateNotifierProvider<SetupStateNotifier, SetupState>((ref) {
  return SetupStateNotifier(ref.read(setupServiceProvider));
});

/// Setup state
class SetupState {
  final SetupPhase phase;
  final List<SetupStep> steps;
  final List<String> logs;
  final PythonInfo? pythonInfo;
  final String? anthropicKey;
  final String? openaiKey;
  final String? errorMessage;

  SetupState({
    this.phase = SetupPhase.welcome,
    this.steps = const [],
    this.logs = const [],
    this.pythonInfo,
    this.anthropicKey,
    this.openaiKey,
    this.errorMessage,
  });

  SetupState copyWith({
    SetupPhase? phase,
    List<SetupStep>? steps,
    List<String>? logs,
    PythonInfo? pythonInfo,
    String? anthropicKey,
    String? openaiKey,
    String? errorMessage,
  }) {
    return SetupState(
      phase: phase ?? this.phase,
      steps: steps ?? this.steps,
      logs: logs ?? this.logs,
      pythonInfo: pythonInfo ?? this.pythonInfo,
      anthropicKey: anthropicKey ?? this.anthropicKey,
      openaiKey: openaiKey ?? this.openaiKey,
      errorMessage: errorMessage,
    );
  }
}

enum SetupPhase {
  welcome,
  checkingPython,
  pythonNotFound,
  apiKeys,
  installing,
  complete,
  error,
}

/// State notifier for setup
class SetupStateNotifier extends StateNotifier<SetupState> {
  final DspyBackendSetupService _service;

  SetupStateNotifier(this._service) : super(SetupState()) {
    // Listen to logs
    _service.logs.listen((log) {
      state = state.copyWith(logs: [...state.logs, log]);
    });
  }

  Future<void> checkPython() async {
    state = state.copyWith(phase: SetupPhase.checkingPython);

    final python = await _service.detectPython();
    state = state.copyWith(pythonInfo: python);

    if (python.isInstalled) {
      state = state.copyWith(phase: SetupPhase.apiKeys);
    } else {
      state = state.copyWith(phase: SetupPhase.pythonNotFound);
    }
  }

  void setApiKeys(String? anthropicKey, String? openaiKey) {
    state = state.copyWith(
      anthropicKey: anthropicKey?.isNotEmpty == true ? anthropicKey : null,
      openaiKey: openaiKey?.isNotEmpty == true ? openaiKey : null,
    );
  }

  Future<void> runSetup() async {
    state = state.copyWith(phase: SetupPhase.installing, logs: []);

    final steps = await _service.runFullSetup(
      anthropicKey: state.anthropicKey,
      openaiKey: state.openaiKey,
      onProgress: (updatedSteps) {
        state = state.copyWith(steps: updatedSteps);
      },
    );

    state = state.copyWith(steps: steps);

    // Check if all required steps completed
    final failed = steps.where((s) => s.status == SetupStepStatus.failed).toList();
    if (failed.isEmpty) {
      state = state.copyWith(phase: SetupPhase.complete);
    } else {
      state = state.copyWith(
        phase: SetupPhase.error,
        errorMessage: failed.first.errorMessage,
      );
    }
  }

  void goToPhase(SetupPhase phase) {
    state = state.copyWith(phase: phase);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

/// First Run Setup Screen
class FirstRunSetupScreen extends ConsumerStatefulWidget {
  const FirstRunSetupScreen({super.key});

  @override
  ConsumerState<FirstRunSetupScreen> createState() => _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends ConsumerState<FirstRunSetupScreen> {
  final _anthropicController = TextEditingController();
  final _openaiController = TextEditingController();

  @override
  void dispose() {
    _anthropicController.dispose();
    _openaiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);
    final state = ref.watch(setupStateProvider);

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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.xl),
                child: _buildContent(context, state, colors),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, SetupState state, ThemeColors colors) {
    switch (state.phase) {
      case SetupPhase.welcome:
        return _buildWelcome(context, colors);
      case SetupPhase.checkingPython:
        return _buildCheckingPython(context, colors);
      case SetupPhase.pythonNotFound:
        return _buildPythonNotFound(context, colors);
      case SetupPhase.apiKeys:
        return _buildApiKeys(context, state, colors);
      case SetupPhase.installing:
        return _buildInstalling(context, state, colors);
      case SetupPhase.complete:
        return _buildComplete(context, colors);
      case SetupPhase.error:
        return _buildError(context, state, colors);
    }
  }

  Widget _buildWelcome(BuildContext context, ThemeColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.rocket_launch_rounded,
          size: 80,
          color: colors.primary,
        ),
        const SizedBox(height: SpacingTokens.xl),
        Text(
          'Welcome to Asmbli',
          style: TextStyles.pageTitle.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: SpacingTokens.md),
        Text(
          'Let\'s set up your AI backend to get started.\nThis will only take a minute.',
          textAlign: TextAlign.center,
          style: TextStyles.bodyLarge.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.xxl),
        AsmblButton.primary(
          text: 'Get Started',
          onPressed: () {
            ref.read(setupStateProvider.notifier).checkPython();
          },
          icon: Icons.arrow_forward_rounded,
        ),
      ],
    );
  }

  Widget _buildCheckingPython(BuildContext context, ThemeColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: SpacingTokens.xl),
        Text(
          'Checking System Requirements',
          style: TextStyles.cardTitle.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: SpacingTokens.md),
        Text(
          'Looking for Python installation...',
          style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildPythonNotFound(BuildContext context, ThemeColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 80,
          color: colors.warning,
        ),
        const SizedBox(height: SpacingTokens.xl),
        Text(
          'Python Not Found',
          style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: SpacingTokens.md),
        Text(
          'Asmbli requires Python 3.9 or higher to run the AI backend.\nPlease install Python and restart the app.',
          textAlign: TextAlign.center,
          style: TextStyles.bodyLarge.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AsmblButton.secondary(
              text: 'Download Python',
              onPressed: () {
                // TODO: Open Python download page
              },
              icon: Icons.download_rounded,
            ),
            const SizedBox(width: SpacingTokens.md),
            AsmblButton.primary(
              text: 'Check Again',
              onPressed: () {
                ref.read(setupStateProvider.notifier).checkPython();
              },
              icon: Icons.refresh_rounded,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildApiKeys(BuildContext context, SetupState state, ThemeColors colors) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(
              Icons.key_rounded,
              size: 60,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: SpacingTokens.lg),
          Center(
            child: Text(
              'API Keys (Optional)',
              style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
            ),
          ),
          const SizedBox(height: SpacingTokens.sm),
          Center(
            child: Text(
              'Add API keys for LLM features. You can skip this and add them later.',
              textAlign: TextAlign.center,
              style: TextStyles.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: SpacingTokens.xl),

          // Python info
          if (state.pythonInfo != null) ...[
            Container(
              padding: const EdgeInsets.all(SpacingTokens.md),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: colors.success),
                  const SizedBox(width: SpacingTokens.sm),
                  Expanded(
                    child: Text(
                      'Python ${state.pythonInfo!.version ?? "detected"} ${state.pythonInfo!.hasUv ? "(with uv)" : ""}',
                      style: TextStyles.bodyMedium.copyWith(color: colors.success),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.lg),
          ],

          // Anthropic API Key
          Text(
            'Anthropic API Key',
            style: TextStyles.labelMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.xs),
          TextField(
            controller: _anthropicController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'sk-ant-...',
              hintStyle: TextStyle(color: colors.mutedForeground),
              filled: true,
              fillColor: colors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.vpn_key_rounded, color: colors.mutedForeground),
            ),
            style: TextStyle(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.md),

          // OpenAI API Key
          Text(
            'OpenAI API Key',
            style: TextStyles.labelMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.xs),
          TextField(
            controller: _openaiController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'sk-...',
              hintStyle: TextStyle(color: colors.mutedForeground),
              filled: true,
              fillColor: colors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.vpn_key_rounded, color: colors.mutedForeground),
            ),
            style: TextStyle(color: colors.onSurface),
          ),
          const SizedBox(height: SpacingTokens.lg),

          // Info note
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: colors.info, size: 20),
                const SizedBox(width: SpacingTokens.sm),
                Expanded(
                  child: Text(
                    'Graph features work offline. API keys are only needed for chat and agent features.',
                    style: TextStyles.bodySmall.copyWith(color: colors.info),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpacingTokens.xl),

          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AsmblButton.outline(
                text: 'Skip',
                onPressed: () {
                  ref.read(setupStateProvider.notifier).setApiKeys(null, null);
                  ref.read(setupStateProvider.notifier).runSetup();
                },
              ),
              const SizedBox(width: SpacingTokens.md),
              AsmblButton.primary(
                text: 'Continue',
                onPressed: () {
                  ref.read(setupStateProvider.notifier).setApiKeys(
                    _anthropicController.text,
                    _openaiController.text,
                  );
                  ref.read(setupStateProvider.notifier).runSetup();
                },
                icon: Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstalling(BuildContext context, SetupState state, ThemeColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Setting Up',
          style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: SpacingTokens.xl),

        // Steps list
        ...state.steps.map((step) => _buildStepTile(step, colors)),

        const SizedBox(height: SpacingTokens.lg),

        // Log output
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: state.logs.length,
              itemBuilder: (context, index) {
                final log = state.logs[index];
                return Text(
                  log,
                  style: TextStyles.caption.copyWith(
                    color: log.contains('ERROR')
                        ? colors.error
                        : log.contains('WARNING')
                            ? colors.warning
                            : colors.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTile(SetupStep step, ThemeColors colors) {
    IconData icon;
    Color iconColor;

    switch (step.status) {
      case SetupStepStatus.pending:
        icon = Icons.circle_outlined;
        iconColor = colors.mutedForeground;
        break;
      case SetupStepStatus.inProgress:
        icon = Icons.sync_rounded;
        iconColor = colors.primary;
        break;
      case SetupStepStatus.completed:
        icon = Icons.check_circle_rounded;
        iconColor = colors.success;
        break;
      case SetupStepStatus.failed:
        icon = Icons.error_rounded;
        iconColor = colors.error;
        break;
      case SetupStepStatus.skipped:
        icon = Icons.skip_next_rounded;
        iconColor = colors.warning;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.xs),
      child: Row(
        children: [
          if (step.status == SetupStepStatus.inProgress)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          else
            Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: SpacingTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyles.bodyMedium.copyWith(
                    color: step.status == SetupStepStatus.pending
                        ? colors.mutedForeground
                        : colors.onSurface,
                  ),
                ),
                if (step.errorMessage != null)
                  Text(
                    step.errorMessage!,
                    style: TextStyles.bodySmall.copyWith(
                      color: step.status == SetupStepStatus.failed
                          ? colors.error
                          : colors.warning,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplete(BuildContext context, ThemeColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 80,
          color: colors.success,
        ),
        const SizedBox(height: SpacingTokens.xl),
        Text(
          'Setup Complete!',
          style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: SpacingTokens.md),
        Text(
          'Your AI backend is ready.\nYou can now start building agents!',
          textAlign: TextAlign.center,
          style: TextStyles.bodyLarge.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.xxl),
        AsmblButton.primary(
          text: 'Start Using Asmbli',
          onPressed: () {
            context.go('/');
          },
          icon: Icons.arrow_forward_rounded,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, SetupState state, ThemeColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 80,
          color: colors.error,
        ),
        const SizedBox(height: SpacingTokens.xl),
        Text(
          'Setup Failed',
          style: TextStyles.sectionTitle.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: SpacingTokens.md),
        Text(
          state.errorMessage ?? 'An error occurred during setup.',
          textAlign: TextAlign.center,
          style: TextStyles.bodyLarge.copyWith(color: colors.error),
        ),
        const SizedBox(height: SpacingTokens.xxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AsmblButton.secondary(
              text: 'View Logs',
              onPressed: () {
                // Show logs dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Setup Logs'),
                    content: SizedBox(
                      width: 500,
                      height: 400,
                      child: ListView.builder(
                        itemCount: state.logs.length,
                        itemBuilder: (context, index) => Text(
                          state.logs[index],
                          style: TextStyles.caption.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
              icon: Icons.article_outlined,
            ),
            const SizedBox(width: SpacingTokens.md),
            AsmblButton.primary(
              text: 'Try Again',
              onPressed: () {
                ref.read(setupStateProvider.notifier).goToPhase(SetupPhase.welcome);
              },
              icon: Icons.refresh_rounded,
            ),
          ],
        ),
        const SizedBox(height: SpacingTokens.lg),
        AsmblButton.outline(
          text: 'Skip Setup',
          onPressed: () {
            context.go('/');
          },
        ),
      ],
    );
  }
}
