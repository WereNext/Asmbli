import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/models/model_config.dart';
import '../../../../core/services/model_config_service.dart';
import '../widgets/reasoning_canvas.dart';
import '../widgets/properties_panel.dart';
import '../widgets/execution_overlay.dart';
import '../widgets/workflow_template_dialog.dart';
import '../../providers/canvas_provider.dart';
import '../../services/workflow_execution_service.dart';
import '../../services/agent_workflow_integration_service.dart';

/// Main orchestration screen for visual reasoning workflows
/// This will be integrated as a tab in the agent builder
class OrchestrationScreen extends ConsumerStatefulWidget {
  const OrchestrationScreen({super.key});

  @override
  ConsumerState<OrchestrationScreen> createState() => _OrchestrationScreenState();
}

class _OrchestrationScreenState extends ConsumerState<OrchestrationScreen> {
  String? _selectedModelId; // Will be set to first available model
  
  // Execution state
  bool _isExecuting = false;
  WorkflowExecutionContext? _currentExecution;
  String? _executionError;
  
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
              // Header with AppNavigationBar
              const AppNavigationBar(currentRoute: AppRoutes.orchestration),
              
              // Main content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.lg),
                  child: Row(
                    children: [
                      // Main canvas area
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCanvasHeader(colors),
                            const SizedBox(height: SpacingTokens.md),
                            const Expanded(child: ReasoningCanvas()),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: SpacingTokens.lg),
                      
                      // Properties panel with execution trace
                      SizedBox(
                        width: 320,
                        child: Column(
                          children: [
                            const Expanded(
                              flex: 2,
                              child: PropertiesPanel(),
                            ),
                            const SizedBox(height: SpacingTokens.md),
                            Expanded(
                              flex: 1,
                              child: ExecutionTraceViewer(
                                executionUpdates: ServiceLocator.instance.get<WorkflowExecutionService>().executionUpdates,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasHeader(ThemeColors colors) {
    final canvasState = ref.watch(canvasProvider);
    
    return AsmblCard(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.md),
        child: Row(
          children: [
            // Workflow info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canvasState.workflow.name,
                  style: TextStyles.sectionTitle.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Visual Reasoning Workflow',
                  style: TextStyles.caption.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Workflow actions - compact layout
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _createNewWorkflow,
                      icon: const Icon(Icons.add),
                      tooltip: 'New',
                      iconSize: 18,
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                    IconButton(
                      onPressed: _openWorkflowLibrary,
                      icon: const Icon(Icons.folder_open),
                      tooltip: 'Library',
                      iconSize: 18,
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                    IconButton(
                      onPressed: _showTemplateDialog,
                      icon: const Icon(Icons.account_tree),
                      tooltip: 'Templates',
                      iconSize: 18,
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                    IconButton(
                      onPressed: _saveWorkflow,
                      icon: const Icon(Icons.save),
                      tooltip: 'Save',
                      iconSize: 18,
                    ),
                    const SizedBox(width: SpacingTokens.xs),
                    IconButton(
                      onPressed: _exportWorkflow,
                      icon: const Icon(Icons.download),
                      tooltip: 'Export',
                      iconSize: 18,
                    ),
                    const SizedBox(width: SpacingTokens.md),
                    // Execution Controls
                    _buildExecutionControls(colors),
                  ],
                ),
              ),
            ),
            const SizedBox(width: SpacingTokens.md),
            
            // Model selector
            _buildModelSelector(colors),
            const SizedBox(width: SpacingTokens.sm),
            
            // Execution controls
            if (canvasState.workflow.isValid) ...[
              AsmblButton.primary(
                text: ref.watch(canvasProvider.notifier).isExecuting ? 'Executing...' : 'Execute',
                onPressed: ref.watch(canvasProvider.notifier).isExecuting ? null : _executeWorkflow,
                icon: ref.watch(canvasProvider.notifier).isExecuting ? Icons.hourglass_empty : Icons.play_arrow,
              ),
            ] else ...[
              AsmblButton.secondary(
                text: 'Invalid Workflow',
                onPressed: null,
                icon: Icons.error_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _createNewWorkflow() {
    ref.read(canvasProvider.notifier).createNewWorkflow();
  }

  void _openWorkflowLibrary() {
    Navigator.of(context).pushNamed(AppRoutes.workflowBrowser);
  }

  void _showTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => const WorkflowTemplateDialog(),
    );
  }

  void _saveWorkflow() async {
    try {
      await ref.read(canvasProvider.notifier).saveWorkflow();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workflow saved successfully',
              style: TextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: ThemeColors(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save workflow: $e',
              style: TextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: ThemeColors(context).error,
          ),
        );
      }
    }
  }

  void _exportWorkflow() {
    // In Phase 1, show export options
    _showExportDialog();
  }

  void _showExportDialog() {
    final colors = ThemeColors(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Export Workflow',
          style: TextStyles.cardTitle.copyWith(color: colors.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose export format:',
              style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: SpacingTokens.md),
            
            ListTile(
              leading: Icon(Icons.code, color: colors.primary),
              title: Text(
                'JSON Configuration',
                style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
              ),
              subtitle: Text(
                'Raw workflow data',
                style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _exportAsJson();
              },
            ),
            
            ListTile(
              leading: Icon(Icons.image, color: colors.primary),
              title: Text(
                'Visual Diagram',
                style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
              ),
              subtitle: Text(
                'PNG image of the workflow',
                style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _exportAsImage();
              },
            ),
            
            ListTile(
              leading: Icon(Icons.description, color: colors.primary),
              title: Text(
                'Documentation',
                style: TextStyles.bodyMedium.copyWith(color: colors.onSurface),
              ),
              subtitle: Text(
                'Markdown description',
                style: TextStyles.caption.copyWith(color: colors.onSurfaceVariant),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _exportAsMarkdown();
              },
            ),
          ],
        ),
        actions: [
          AsmblButton.secondary(
            text: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _exportAsJson() async {
    try {
      final jsonData = await ref.read(canvasProvider.notifier).exportWorkflowAsJson();
      
      // In Phase 1, just show the JSON (later we'll implement file export)
      _showExportResult('JSON Export', jsonData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to export workflow: $e',
              style: TextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: ThemeColors(context).error,
          ),
        );
      }
    }
  }

  void _exportAsImage() {
    _showExportResult('Image Export', 'Image export will be available in Phase 2');
  }

  void _exportAsMarkdown() {
    final workflow = ref.read(canvasProvider).workflow;
    final markdown = _generateMarkdownDocumentation(workflow);
    _showExportResult('Markdown Export', markdown);
  }

  Future<void> _executeWorkflow() async {
    try {
      await ref.read(canvasProvider.notifier).executeWorkflow(
        modelId: _selectedModelId ?? 'default',
        initialContext: {
          'context_data': 'Example context for testing the reasoning workflow',
          'user_input': 'This is a test execution of the visual reasoning flow',
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workflow execution completed',
              style: TextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: ThemeColors(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Execution failed: $e',
              style: TextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: ThemeColors(context).error,
          ),
        );
      }
    }
  }

  String _generateMarkdownDocumentation(workflow) {
    final buffer = StringBuffer();
    
    buffer.writeln('# ${workflow.name}');
    buffer.writeln();
    
    if (workflow.description?.isNotEmpty == true) {
      buffer.writeln(workflow.description);
      buffer.writeln();
    }
    
    buffer.writeln('## Workflow Overview');
    buffer.writeln('- **Blocks**: ${workflow.blocks.length}');
    buffer.writeln('- **Connections**: ${workflow.connections.length}');
    buffer.writeln('- **Created**: ${workflow.createdAt.toIso8601String()}');
    buffer.writeln('- **Updated**: ${workflow.updatedAt.toIso8601String()}');
    buffer.writeln();
    
    buffer.writeln('## Logic Blocks');
    for (final block in workflow.blocks) {
      buffer.writeln('### ${block.label}');
      buffer.writeln('- **Type**: ${block.type.name}');
      buffer.writeln('- **ID**: ${block.id}');
      if (block.properties.isNotEmpty) {
        buffer.writeln('- **Properties**: ${block.properties}');
      }
      buffer.writeln();
    }
    
    if (workflow.connections.isNotEmpty) {
      buffer.writeln('## Connections');
      for (final connection in workflow.connections) {
        final sourceBlock = workflow.blocks.firstWhere((b) => b.id == connection.sourceBlockId);
        final targetBlock = workflow.blocks.firstWhere((b) => b.id == connection.targetBlockId);
        buffer.writeln('- ${sourceBlock.label} → ${targetBlock.label} (${connection.type.name})');
      }
    }
    
    return buffer.toString();
  }

  Widget _buildExecutionControls(ThemeColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Run Workflow Button
        if (!_isExecuting) ...[
          AsmblButton.primary(
            text: 'Run Workflow',
            onPressed: _canExecuteWorkflow() ? _runWorkflow : null,
            icon: Icons.play_arrow,
          ),
        ] else ...[
          AsmblButton.secondary(
            text: 'Running...',
            onPressed: null,
            icon: Icons.hourglass_empty,
          ),
        ],
        
        const SizedBox(width: SpacingTokens.xs),
        
        // Stop Execution Button (if running)
        if (_isExecuting) ...[
          IconButton(
            onPressed: _stopWorkflowExecution,
            icon: Icon(Icons.stop, color: colors.error),
            tooltip: 'Stop Execution',
            iconSize: 18,
          ),
        ],
        
        // Execution Status Indicator
        if (_currentExecution != null) ...[
          const SizedBox(width: SpacingTokens.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.sm,
              vertical: SpacingTokens.xs,
            ),
            decoration: BoxDecoration(
              color: _isExecuting ? colors.accent.withValues(alpha: 0.1) : colors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
              border: Border.all(
                color: _isExecuting ? colors.accent : colors.success,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isExecuting ? Icons.pending : Icons.check_circle,
                  size: 12,
                  color: _isExecuting ? colors.accent : colors.success,
                ),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  _isExecuting ? 'Step ${_currentExecution!.blockResults.length + 1}' : 'Complete',
                  style: TextStyles.caption.copyWith(
                    color: _isExecuting ? colors.accent : colors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Error Indicator
        if (_executionError != null) ...[
          const SizedBox(width: SpacingTokens.xs),
          Tooltip(
            message: _executionError!,
            child: Icon(
              Icons.error,
              color: colors.error,
              size: 18,
            ),
          ),
        ],
      ],
    );
  }

  bool _canExecuteWorkflow() {
    final canvasState = ref.read(canvasProvider);
    return canvasState.workflow.isValid && !_isExecuting;
  }

  Future<void> _runWorkflow() async {
    if (_isExecuting) return;

    setState(() {
      _isExecuting = true;
      _executionError = null;
    });

    try {
      final canvasState = ref.read(canvasProvider);
      final workflowExecutionService = ServiceLocator.instance.get<WorkflowExecutionService>();
      
      // Execute the workflow
      final executionContext = await workflowExecutionService.executeWorkflow(
        workflow: canvasState.workflow,
        agentId: 'test-agent-id', // TODO: Get actual agent ID from context
        userId: 'test-user-id', // TODO: Get actual user ID from auth
        inputs: {
          'user_input': 'Test workflow execution from orchestration UI',
          'model_id': _selectedModelId ?? 'default',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      setState(() {
        _currentExecution = executionContext;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workflow executed successfully',
              style: TextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: ThemeColors(context).success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _executionError = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workflow execution failed: $e',
              style: TextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: ThemeColors(context).error,
          ),
        );
      }
    } finally {
      setState(() {
        _isExecuting = false;
      });
    }
  }

  void _stopWorkflowExecution() {
    // TODO: Implement workflow cancellation in execution service
    setState(() {
      _isExecuting = false;
      _executionError = 'Execution stopped by user';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Workflow execution stopped',
            style: TextStyles.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: ThemeColors(context).warning,
        ),
      );
    }
  }

  void _showExportResult(String title, String content) {
    final colors = ThemeColors(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          title,
          style: TextStyles.cardTitle.copyWith(color: colors.onSurface),
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: TextStyles.bodySmall.copyWith(
                color: colors.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        actions: [
          AsmblButton.secondary(
            text: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelector(ThemeColors colors) {
    final allModels = ref.watch(allModelConfigsProvider);
    final availableModels = allModels.values
        .where((model) => model.status == ModelStatus.ready)
        .toList();
    
    // Set default model if not already set
    if (_selectedModelId == null && availableModels.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedModelId = availableModels.first.id;
          });
        }
      });
    }
    
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String>(
        value: _selectedModelId,
        decoration: InputDecoration(
          labelText: 'Model',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.sm,
            vertical: SpacingTokens.xs,
          ),
          isDense: true,
        ),
        items: availableModels.isEmpty
            ? [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    'No models available',
                    style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]
            : availableModels.map((model) {
                // Format the display name
                String displayName = model.name;
                if (model.isLocal) {
                  // For Ollama models, include size info
                  final sizeMatch = RegExp(r'(\d+(\.\d+)?)[ ]?[Bb]').firstMatch(model.id);
                  if (sizeMatch != null) {
                    displayName = '${displayName.split(' ').first} ${sizeMatch.group(0)!.toUpperCase()}';
                  }
                }
                
                return DropdownMenuItem(
                  value: model.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        model.isLocal ? Icons.computer : Icons.cloud,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: SpacingTokens.xs),
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          onChanged: availableModels.isEmpty
            ? null
            : (value) {
                if (value != null) {
                  setState(() => _selectedModelId = value);
                }
              },
      ),
    );
  }
}