import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/design_system/design_system.dart';

/// Demo code editor with simulated MCP git integration
class DemoCodeEditor extends StatefulWidget {
  final String? initialFilePath;
  final VoidCallback? onClose;
  final String? actionContext;
  final String? deliverableType; // refactor, api, test, devops, review

  const DemoCodeEditor({
    super.key,
    this.initialFilePath,
    this.onClose,
    this.actionContext,
    this.deliverableType,
  });

  @override
  State<DemoCodeEditor> createState() => _DemoCodeEditorState();
}

class _DemoCodeEditorState extends State<DemoCodeEditor>
    with TickerProviderStateMixin {
  // File system simulation - initialized based on deliverable type
  late Map<String, FileNode> _fileTree;
  late String _currentFilePath;
  late String _currentContent;
  final TextEditingController _codeController = TextEditingController();
  final List<String> _gitLog = [];
  bool _hasChanges = false;
  bool _showGitPanel = false;
  bool _showCommandPalette = false;
  final List<String> _openFiles = [];
  bool _showPreview = false;
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _previewRefreshController;

  @override
  void initState() {
    super.initState();
    _initializeFileTree();
    _initializeAnimations();
    _loadFile(widget.initialFilePath ?? _currentFilePath);
    _simulateGitStatus();
  }

  void _initializeFileTree() {
    final config = _getFileTreeConfig();
    _fileTree = config['fileTree'] as Map<String, FileNode>;
    _currentFilePath = config['defaultFile'] as String;
  }

  Map<String, dynamic> _getFileTreeConfig() {
    final type = widget.deliverableType?.toLowerCase() ?? 'refactor';

    switch (type) {
      case 'api':
        return {
          'defaultFile': 'src/api/routes.ts',
          'fileTree': {
            'src': FileNode(
              name: 'src',
              isDirectory: true,
              children: {
                'api': FileNode(
                  name: 'api',
                  isDirectory: true,
                  children: {
                    'routes.ts': FileNode(
                      name: 'routes.ts',
                      content: _apiRoutesCode,
                      language: 'typescript',
                    ),
                    'middleware.ts': FileNode(
                      name: 'middleware.ts',
                      content: _apiMiddlewareCode,
                      language: 'typescript',
                    ),
                    'validators.ts': FileNode(
                      name: 'validators.ts',
                      content: _apiValidatorsCode,
                      language: 'typescript',
                    ),
                  },
                ),
                'models': FileNode(
                  name: 'models',
                  isDirectory: true,
                  children: {
                    'User.ts': FileNode(
                      name: 'User.ts',
                      content: _apiUserModelCode,
                      language: 'typescript',
                    ),
                  },
                ),
              },
            ),
            'package.json': FileNode(
              name: 'package.json',
              content: _apiPackageJson,
              language: 'json',
            ),
          },
        };

      case 'test':
        return {
          'defaultFile': 'tests/auth.test.ts',
          'fileTree': {
            'tests': FileNode(
              name: 'tests',
              isDirectory: true,
              children: {
                'auth.test.ts': FileNode(
                  name: 'auth.test.ts',
                  content: _testAuthCode,
                  language: 'typescript',
                ),
                'api.test.ts': FileNode(
                  name: 'api.test.ts',
                  content: _testApiCode,
                  language: 'typescript',
                ),
                'utils.test.ts': FileNode(
                  name: 'utils.test.ts',
                  content: _testUtilsCode,
                  language: 'typescript',
                ),
              },
            ),
            'src': FileNode(
              name: 'src',
              isDirectory: true,
              children: {
                'auth.ts': FileNode(
                  name: 'auth.ts',
                  content: _testAuthSourceCode,
                  language: 'typescript',
                ),
              },
            ),
            'jest.config.js': FileNode(
              name: 'jest.config.js',
              content: _jestConfigCode,
              language: 'javascript',
            ),
          },
        };

      case 'devops':
        return {
          'defaultFile': '.github/workflows/ci.yml',
          'fileTree': {
            '.github': FileNode(
              name: '.github',
              isDirectory: true,
              children: {
                'workflows': FileNode(
                  name: 'workflows',
                  isDirectory: true,
                  children: {
                    'ci.yml': FileNode(
                      name: 'ci.yml',
                      content: _devopsCiCode,
                      language: 'yaml',
                    ),
                    'deploy.yml': FileNode(
                      name: 'deploy.yml',
                      content: _devopsDeployCode,
                      language: 'yaml',
                    ),
                  },
                ),
              },
            ),
            'docker': FileNode(
              name: 'docker',
              isDirectory: true,
              children: {
                'Dockerfile': FileNode(
                  name: 'Dockerfile',
                  content: _dockerfileCode,
                  language: 'dockerfile',
                ),
                'docker-compose.yml': FileNode(
                  name: 'docker-compose.yml',
                  content: _dockerComposeCode,
                  language: 'yaml',
                ),
              },
            ),
            'terraform': FileNode(
              name: 'terraform',
              isDirectory: true,
              children: {
                'main.tf': FileNode(
                  name: 'main.tf',
                  content: _terraformCode,
                  language: 'hcl',
                ),
              },
            ),
          },
        };

      case 'review':
        return {
          'defaultFile': 'src/services/PaymentService.ts',
          'fileTree': {
            'src': FileNode(
              name: 'src',
              isDirectory: true,
              children: {
                'services': FileNode(
                  name: 'services',
                  isDirectory: true,
                  children: {
                    'PaymentService.ts': FileNode(
                      name: 'PaymentService.ts',
                      content: _reviewPaymentCode,
                      language: 'typescript',
                    ),
                    'UserService.ts': FileNode(
                      name: 'UserService.ts',
                      content: _reviewUserServiceCode,
                      language: 'typescript',
                    ),
                  },
                ),
                'utils': FileNode(
                  name: 'utils',
                  isDirectory: true,
                  children: {
                    'validation.ts': FileNode(
                      name: 'validation.ts',
                      content: _reviewValidationCode,
                      language: 'typescript',
                    ),
                  },
                ),
              },
            ),
            'REVIEW_NOTES.md': FileNode(
              name: 'REVIEW_NOTES.md',
              content: _reviewNotesCode,
              language: 'markdown',
            ),
          },
        };

      case 'refactor':
      default:
        return {
          'defaultFile': 'src/legacy/DataProcessor.ts',
          'fileTree': {
            'src': FileNode(
              name: 'src',
              isDirectory: true,
              children: {
                'legacy': FileNode(
                  name: 'legacy',
                  isDirectory: true,
                  children: {
                    'DataProcessor.ts': FileNode(
                      name: 'DataProcessor.ts',
                      content: _refactorLegacyCode,
                      language: 'typescript',
                    ),
                    'helpers.ts': FileNode(
                      name: 'helpers.ts',
                      content: _refactorHelpersCode,
                      language: 'typescript',
                    ),
                  },
                ),
                'refactored': FileNode(
                  name: 'refactored',
                  isDirectory: true,
                  children: {
                    'DataProcessor.ts': FileNode(
                      name: 'DataProcessor.ts',
                      content: _refactorNewCode,
                      language: 'typescript',
                    ),
                  },
                ),
              },
            ),
            'package.json': FileNode(
              name: 'package.json',
              content: _refactorPackageJson,
              language: 'json',
            ),
          },
        };
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    
    _previewRefreshController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _previewRefreshController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _loadFile(String path) {
    final file = _getFileAtPath(path);
    if (file != null && !file.isDirectory) {
      setState(() {
        _currentFilePath = path;
        _currentContent = file.content ?? '';
        _codeController.text = _currentContent;
        if (!_openFiles.contains(path)) {
          _openFiles.add(path);
        }
      });
    }
  }

  FileNode? _getFileAtPath(String path) {
    final parts = path.split('/');
    Map<String, FileNode> current = _fileTree;
    FileNode? result;
    
    for (final part in parts) {
      if (current.containsKey(part)) {
        result = current[part];
        if (result!.isDirectory && result.children != null) {
          current = result.children!;
        }
      } else {
        return null;
      }
    }
    
    return result;
  }

  void _simulateGitStatus() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _gitLog.add('[git] Detected changes in 2 files');
          _gitLog.add('[git] src/App.tsx (modified)');
          _gitLog.add('[git] src/components/Dashboard.tsx (modified)');
        });
      }
    });
  }

  void _executeGitCommand(String command) {
    setState(() {
      _gitLog.add('> $command');
      
      switch (command) {
        case 'git status':
          _gitLog.addAll([
            'On branch feature/ai-integration',
            'Changes not staged for commit:',
            '  modified: src/App.tsx',
            '  modified: src/components/Dashboard.tsx',
          ]);
          break;
        case 'git add .':
          _gitLog.add('Added 2 files to staging area');
          break;
        case 'git commit -m "Add AI-powered task management"':
          _gitLog.addAll([
            '[feature/ai-integration abc1234] Add AI-powered task management',
            '2 files changed, 45 insertions(+), 12 deletions(-)',
          ]);
          _hasChanges = false;
          break;
        case 'git push':
          _gitLog.addAll([
            'Counting objects: 100% (12/12), done.',
            'Writing objects: 100% (12/12), 2.34 KiB | 2.34 MiB/s, done.',
            'To github.com:asmbli/project-dashboard.git',
            '   def5678..abc1234  feature/ai-integration -> feature/ai-integration',
          ]);
          break;
        default:
          _gitLog.add('Command not recognized: $command');
      }
    });
  }

  // VS Code dark theme colors
  static const _editorBg = Color(0xFF1E1E1E);
  static const _tabBarBg = Color(0xFF252526);
  static const _sidebarBg = Color(0xFF252526);
  static const _panelBg = Color(0xFF1E1E1E);
  static const _borderColor = Color(0xFF3C3C3C);
  static const _textColor = Color(0xFFD4D4D4);
  static const _textMuted = Color(0xFF858585);
  static const _activeTabBg = Color(0xFF1E1E1E);
  static const _highlightBlue = Color(0xFF569CD6);
  static const _highlightGreen = Color(0xFF4EC9B0);
  static const _highlightOrange = Color(0xFFCE9178);
  static const _highlightYellow = Color(0xFFDCDCAA);

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: _editorBg,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
        ),
        child: Column(
          children: [
            // Editor header
            _buildEditorHeader(colors),
            
            // Tab bar
            _buildTabBar(colors),
            
            // Main editor area
            Expanded(
              child: Row(
                children: [
                  // File tree sidebar
                  _buildFileTree(colors),
                  
                  // Code editor or preview
                  Expanded(
                    child: _showPreview
                        ? _buildPreview(colors)
                        : _buildCodeEditor(colors),
                  ),
                  
                  // Git panel
                  if (_showGitPanel)
                    _buildGitPanel(colors),
                ],
              ),
            ),
            
            // Status bar
            _buildStatusBar(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorHeader(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.md,
        vertical: SpacingTokens.sm,
      ),
      decoration: BoxDecoration(
        color: _tabBarBg,
        border: Border(bottom: BorderSide(color: _borderColor)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(BorderRadiusTokens.lg),
          topRight: Radius.circular(BorderRadiusTokens.lg),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.code, color: _highlightBlue, size: 20),
          const SizedBox(width: SpacingTokens.sm),
          Text(
            'AI Code Editor',
            style: TextStyles.bodyLarge.copyWith(
              color: _textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (widget.actionContext != null) ...[
            const SizedBox(width: SpacingTokens.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.sm,
                vertical: SpacingTokens.xs,
              ),
              decoration: BoxDecoration(
                color: _highlightGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                border: Border.all(color: _highlightGreen, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.touch_app,
                    size: 14,
                    color: _highlightGreen,
                  ),
                  const SizedBox(width: SpacingTokens.xs),
                  Text(
                    'Selected: ${widget.actionContext}',
                    style: TextStyles.bodySmall.copyWith(
                      color: _highlightGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),

          // MCP integration indicator
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.sm,
              vertical: SpacingTokens.xs,
            ),
            decoration: BoxDecoration(
              color: _highlightGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _highlightGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  'MCP Git Connected',
                  style: TextStyles.bodySmall.copyWith(
                    color: _highlightGreen,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: SpacingTokens.md),

          // Preview toggle
          IconButton(
            onPressed: () {
              setState(() => _showPreview = !_showPreview);
              if (_showPreview) {
                _previewRefreshController.forward(from: 0);
              }
            },
            icon: Icon(
              Icons.preview,
              color: _showPreview ? _highlightBlue : _textMuted,
              size: 20,
            ),
            tooltip: 'Toggle Preview',
          ),

          // Git panel toggle
          IconButton(
            onPressed: () {
              setState(() => _showGitPanel = !_showGitPanel);
            },
            icon: Icon(
              Icons.source,
              color: _showGitPanel ? _highlightBlue : _textMuted,
              size: 20,
            ),
            tooltip: 'Toggle Git Panel',
          ),

          if (widget.onClose != null) ...[
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, color: _textMuted, size: 20),
              tooltip: 'Close Editor',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeColors colors) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: _tabBarBg,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          ..._openFiles.map((path) {
            final isActive = path == _currentFilePath;
            final fileName = path.split('/').last;

            return Container(
              decoration: BoxDecoration(
                color: isActive ? _activeTabBg : null,
                border: isActive
                    ? const Border(
                        bottom: BorderSide(color: _highlightBlue, width: 2),
                      )
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _loadFile(path),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.md,
                      vertical: SpacingTokens.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getFileIcon(fileName),
                          size: 14,
                          color: isActive ? _highlightYellow : _textMuted,
                        ),
                        const SizedBox(width: SpacingTokens.xs),
                        Text(
                          fileName,
                          style: TextStyles.bodySmall.copyWith(
                            color: isActive ? _textColor : _textMuted,
                          ),
                        ),
                        if (_hasChanges && isActive) ...[
                          const SizedBox(width: SpacingTokens.xs),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _highlightOrange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildFileTree(ThemeColors colors) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: _sidebarBg,
        border: Border(right: BorderSide(color: _borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            child: Text(
              'PROJECT FILES',
              style: TextStyles.bodySmall.copyWith(
                color: _textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xs),
              children: _buildFileTreeNodes(_fileTree, 0, colors),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFileTreeNodes(
    Map<String, FileNode> nodes,
    int depth,
    ThemeColors colors,
  ) {
    final widgets = <Widget>[];

    for (final entry in nodes.entries) {
      final node = entry.value;
      final indent = depth * SpacingTokens.md;

      widgets.add(
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: node.isDirectory
                ? null
                : () => _loadFile(_getNodePath(node, nodes)),
            child: Container(
              padding: EdgeInsets.only(
                left: indent + SpacingTokens.sm,
                right: SpacingTokens.sm,
                top: SpacingTokens.xs,
                bottom: SpacingTokens.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    node.isDirectory
                        ? Icons.folder
                        : _getFileIcon(node.name),
                    size: 16,
                    color: node.isDirectory
                        ? _highlightOrange
                        : _highlightBlue,
                  ),
                  const SizedBox(width: SpacingTokens.xs),
                  Text(
                    node.name,
                    style: TextStyles.bodySmall.copyWith(
                      color: _textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (node.isDirectory && node.children != null) {
        widgets.addAll(_buildFileTreeNodes(node.children!, depth + 1, colors));
      }
    }

    return widgets;
  }

  String _getNodePath(FileNode node, Map<String, FileNode> parent) {
    // Simplified path resolution
    if (parent == _fileTree) {
      return node.name;
    }
    return _currentFilePath; // In real implementation, would traverse tree
  }

  Widget _buildCodeEditor(ThemeColors colors) {
    return Container(
      color: _editorBg,
      child: Column(
        children: [
          // Breadcrumb
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.sm,
            ),
            decoration: const BoxDecoration(
              color: _tabBarBg,
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                ..._currentFilePath.split('/').map((part) => Row(
                  children: [
                    Text(
                      part,
                      style: TextStyles.bodySmall.copyWith(
                        color: _textMuted,
                      ),
                    ),
                    if (part != _currentFilePath.split('/').last)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.xs),
                        child: Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: _textMuted.withOpacity(0.5),
                        ),
                      ),
                  ],
                )),
              ],
            ),
          ),

          // Code area
          Expanded(
            child: Stack(
              children: [
                // Line numbers and code - wrapped in SingleChildScrollView to prevent RenderFlex overflow
                SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line numbers
                      Container(
                        width: 50,
                        padding: const EdgeInsets.only(
                          right: SpacingTokens.sm,
                          top: SpacingTokens.md,
                        ),
                        decoration: BoxDecoration(
                          color: _sidebarBg.withOpacity(0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(
                            _codeController.text.split('\n').length,
                            (index) => Container(
                              height: 20,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${index + 1}',
                                style: TextStyles.bodySmall.copyWith(
                                  color: _textMuted.withOpacity(0.6),
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Code editor
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          maxLines: null,
                          cursorColor: _highlightBlue,
                          style: const TextStyle(
                            color: _textColor,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.5,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(SpacingTokens.md),
                            fillColor: Colors.transparent,
                            filled: true,
                          ),
                          onChanged: (value) {
                            if (!_hasChanges && value != _currentContent) {
                              setState(() => _hasChanges = true);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // AI suggestion overlay (demo)
                if (_showAISuggestion)
                  Positioned(
                    top: 100,
                    left: 60,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(SpacingTokens.md),
                      decoration: BoxDecoration(
                        color: _highlightBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
                        border: Border.all(color: _highlightBlue.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: _highlightBlue,
                              ),
                              const SizedBox(width: SpacingTokens.xs),
                              Text(
                                'AI Suggestion',
                                style: TextStyles.bodySmall.copyWith(
                                  color: _highlightBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Tab to accept',
                                style: TextStyles.bodySmall.copyWith(
                                  color: _textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: SpacingTokens.sm),
                          Container(
                            padding: const EdgeInsets.all(SpacingTokens.sm),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D2D2D),
                              borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                            ),
                            child: Text(
                              '// Add error handling for API calls\ntry {\n  const response = await fetchTasks();\n  setTasks(response.data);\n} catch (error) {\n  console.error("Failed to fetch tasks:", error);\n  setError(error.message);\n}',
                              style: TextStyles.bodySmall.copyWith(
                                color: _textColor,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _showAISuggestion => _currentFilePath.endsWith('.tsx') && _hasChanges;

  Widget _buildGitPanel(ThemeColors colors) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: _sidebarBg,
        border: Border(left: BorderSide(color: _borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Git panel header
          Container(
            padding: const EdgeInsets.all(SpacingTokens.md),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                const Icon(Icons.source, color: _highlightBlue, size: 20),
                const SizedBox(width: SpacingTokens.sm),
                Text(
                  'Git Integration',
                  style: TextStyles.bodyMedium.copyWith(
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Quick actions
          Container(
            padding: const EdgeInsets.all(SpacingTokens.sm),
            child: Wrap(
              spacing: SpacingTokens.sm,
              children: [
                _buildGitAction('Status', Icons.info_outline, () {
                  _executeGitCommand('git status');
                }, colors),
                _buildGitAction('Add All', Icons.add, () {
                  _executeGitCommand('git add .');
                }, colors),
                _buildGitAction('Commit', Icons.check, () {
                  _executeGitCommand('git commit -m "Add AI-powered task management"');
                }, colors),
                _buildGitAction('Push', Icons.upload, () {
                  _executeGitCommand('git push');
                }, colors),
              ],
            ),
          ),

          // Git log
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(SpacingTokens.sm),
              padding: const EdgeInsets.all(SpacingTokens.sm),
              decoration: BoxDecoration(
                color: _editorBg,
                borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
              ),
              child: ListView.builder(
                itemCount: _gitLog.length,
                itemBuilder: (context, index) {
                  final log = _gitLog[index];
                  final isCommand = log.startsWith('>');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: SpacingTokens.xs),
                    child: Text(
                      log,
                      style: TextStyles.bodySmall.copyWith(
                        color: isCommand ? _highlightGreen : _textMuted,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGitAction(
    String label,
    IconData icon,
    VoidCallback onTap,
    ThemeColors colors,
  ) {
    return Material(
      color: _highlightBlue.withOpacity(0.15),
      borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.sm,
            vertical: SpacingTokens.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _highlightBlue),
              const SizedBox(width: SpacingTokens.xs),
              Text(
                label,
                style: TextStyles.bodySmall.copyWith(
                  color: _highlightBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeColors colors) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.md),
      decoration: const BoxDecoration(
        color: _tabBarBg,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          // Current branch
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_tree, size: 12, color: _textMuted),
              const SizedBox(width: SpacingTokens.xs),
              Text(
                'feature/ai-integration',
                style: TextStyles.bodySmall.copyWith(
                  color: _textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(width: SpacingTokens.lg),

          // Language mode
          Text(
            'TypeScript React',
            style: TextStyles.bodySmall.copyWith(
              color: _textMuted,
              fontSize: 11,
            ),
          ),

          const Spacer(),

          // AI status
          if (_showAISuggestion)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 12, color: _highlightBlue),
                const SizedBox(width: SpacingTokens.xs),
                Text(
                  'AI Ready',
                  style: TextStyles.bodySmall.copyWith(
                    color: _highlightBlue,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: SpacingTokens.lg),
              ],
            ),

          // Cursor position
          Text(
            'Ln 12, Col 24',
            style: TextStyles.bodySmall.copyWith(
              color: _textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    if (fileName.endsWith('.tsx') || fileName.endsWith('.ts')) {
      return Icons.code;
    } else if (fileName.endsWith('.json')) {
      return Icons.settings;
    } else if (fileName.endsWith('.md')) {
      return Icons.description;
    } else if (fileName.endsWith('.css') || fileName.endsWith('.scss')) {
      return Icons.style;
    }
    return Icons.insert_drive_file;
  }

  Widget _buildPreview(ThemeColors colors) {
    return Container(
      color: _sidebarBg,
      child: Column(
        children: [
          // Browser-like header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SpacingTokens.md,
              vertical: SpacingTokens.sm,
            ),
            decoration: const BoxDecoration(
              color: _tabBarBg,
              border: Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                // Browser controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, size: 16, color: _textMuted.withOpacity(0.5)),
                    const SizedBox(width: SpacingTokens.xs),
                    Icon(Icons.arrow_forward, size: 16, color: _textMuted.withOpacity(0.5)),
                    const SizedBox(width: SpacingTokens.sm),
                    AnimatedBuilder(
                      animation: _previewRefreshController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _previewRefreshController.value * 2 * 3.14159,
                          child: const Icon(
                            Icons.refresh,
                            size: 16,
                            color: _textMuted,
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(width: SpacingTokens.md),

                // URL bar
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.sm,
                      vertical: SpacingTokens.xs,
                    ),
                    decoration: BoxDecoration(
                      color: _editorBg,
                      borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, size: 12, color: _highlightGreen),
                        const SizedBox(width: SpacingTokens.xs),
                        Text(
                          'localhost:3000',
                          style: TextStyles.bodySmall.copyWith(
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: SpacingTokens.md),

                // Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.sm,
                    vertical: SpacingTokens.xs,
                  ),
                  decoration: BoxDecoration(
                    color: _highlightGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: _highlightGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.xs),
                      Text(
                        'Live',
                        style: TextStyles.bodySmall.copyWith(
                          color: _highlightGreen,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Preview content
          Expanded(
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: _buildPreviewContent(colors),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(ThemeColors colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4ECDC4), Color(0xFF44A08D)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.task_alt, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Text(
                  'AI-Powered Task Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Task grid
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2,
            children: [
              _buildTaskPreviewCard('Deploy AI Model', 'In Progress', Colors.blue, 75),
              _buildTaskPreviewCard('Code Review', 'Completed', Colors.green, 100),
              _buildTaskPreviewCard('UI Design', 'In Review', Colors.orange, 90),
              _buildTaskPreviewCard('Database Migration', 'Pending', Colors.grey, 0),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // AI Suggestions section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFFE1E8ED)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF4ECDC4), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI Recommendations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSuggestionItem('Prioritize "Deploy AI Model" - blocking 3 other tasks'),
                _buildSuggestionItem('Schedule code review for tomorrow morning'),
                _buildSuggestionItem('Assign UI design to Sarah - best availability'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskPreviewCard(String title, String status, Color color, int progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFE1E8ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (progress > 0)
                Text(
                  '$progress%',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF718096),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (progress > 0)
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Color(0xFFE1E8ED),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 4),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xFF4ECDC4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF4A5568),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ REFACTOR CODE SAMPLES ============
  static const _refactorLegacyCode = '''// Legacy DataProcessor - needs refactoring
class DataProcessor {
  data: any[] = [];

  processData(input: any) {
    // TODO: This function is too long and complex
    var result = [];
    for (var i = 0; i < input.length; i++) {
      var item = input[i];
      if (item.type == 'user') {
        if (item.status == 'active') {
          result.push({
            id: item.id,
            name: item.firstName + ' ' + item.lastName,
            email: item.email
          });
        }
      }
    }
    this.data = result;
    return result;
  }

  // Callback hell - needs async/await
  fetchAndProcess(url: string, callback: Function) {
    fetch(url).then(function(res) {
      res.json().then(function(data) {
        callback(null, data);
      });
    }).catch(function(err) {
      callback(err, null);
    });
  }
}''';

  static const _refactorHelpersCode = '''// Legacy helpers with poor typing
function formatDate(d: any): string {
  return d.getMonth() + '/' + d.getDate() + '/' + d.getFullYear();
}

function validateEmail(email: any) {
  var re = /\\S+@\\S+\\.\\S+/;
  return re.test(email);
}

function deepClone(obj: any) {
  return JSON.parse(JSON.stringify(obj));
}''';

  static const _refactorNewCode = '''// Refactored DataProcessor with modern patterns
interface User {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  status: 'active' | 'inactive';
  type: 'user' | 'admin';
}

interface ProcessedUser {
  id: string;
  name: string;
  email: string;
}

class DataProcessor {
  private data: ProcessedUser[] = [];

  processUsers(users: User[]): ProcessedUser[] {
    const activeUsers = users
      .filter(user => user.type === 'user' && user.status === 'active')
      .map(this.transformUser);

    this.data = activeUsers;
    return activeUsers;
  }

  private transformUser = (user: User): ProcessedUser => ({
    id: user.id,
    name: \`\${user.firstName} \${user.lastName}\`,
    email: user.email,
  });

  async fetchAndProcess(url: string): Promise<ProcessedUser[]> {
    const response = await fetch(url);
    const data = await response.json();
    return this.processUsers(data);
  }
}''';

  static const _refactorPackageJson = '''{
  "name": "legacy-refactor-project",
  "version": "2.0.0",
  "scripts": {
    "build": "tsc",
    "lint": "eslint src/",
    "test": "jest"
  }
}''';

  // ============ API CODE SAMPLES ============
  static const _apiRoutesCode = '''import { Router } from 'express';
import { authenticate } from './middleware';
import { validateUser } from './validators';

const router = Router();

// GET /api/users
router.get('/users', authenticate, async (req, res) => {
  const users = await UserService.findAll();
  res.json({ data: users, count: users.length });
});

// POST /api/users
router.post('/users', authenticate, validateUser, async (req, res) => {
  const user = await UserService.create(req.body);
  res.status(201).json({ data: user });
});

// GET /api/users/:id
router.get('/users/:id', authenticate, async (req, res) => {
  const user = await UserService.findById(req.params.id);
  if (!user) return res.status(404).json({ error: 'Not found' });
  res.json({ data: user });
});

// PUT /api/users/:id
router.put('/users/:id', authenticate, validateUser, async (req, res) => {
  const user = await UserService.update(req.params.id, req.body);
  res.json({ data: user });
});

// DELETE /api/users/:id
router.delete('/users/:id', authenticate, async (req, res) => {
  await UserService.delete(req.params.id);
  res.status(204).send();
});

export default router;''';

  static const _apiMiddlewareCode = '''import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET!);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

export const rateLimit = (maxRequests: number, windowMs: number) => {
  const requests = new Map();

  return (req: Request, res: Response, next: NextFunction) => {
    const ip = req.ip;
    const now = Date.now();
    // Rate limiting logic here
    next();
  };
};''';

  static const _apiValidatorsCode = '''import { body, validationResult } from 'express-validator';

export const validateUser = [
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 8 }),
  body('name').trim().notEmpty(),
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  }
];''';

  static const _apiUserModelCode = '''export interface User {
  id: string;
  email: string;
  name: string;
  role: 'user' | 'admin';
  createdAt: Date;
  updatedAt: Date;
}''';

  static const _apiPackageJson = '''{
  "name": "rest-api-service",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.0",
    "jsonwebtoken": "^9.0.0"
  }
}''';

  // ============ TEST CODE SAMPLES ============
  static const _testAuthCode = '''import { describe, it, expect, beforeEach } from '@jest/globals';
import { AuthService } from '../src/auth';

describe('AuthService', () => {
  let authService: AuthService;

  beforeEach(() => {
    authService = new AuthService();
  });

  describe('login', () => {
    it('should return token for valid credentials', async () => {
      const result = await authService.login('user@test.com', 'password123');
      expect(result.token).toBeDefined();
      expect(result.user.email).toBe('user@test.com');
    });

    it('should throw error for invalid credentials', async () => {
      await expect(
        authService.login('user@test.com', 'wrongpassword')
      ).rejects.toThrow('Invalid credentials');
    });
  });

  describe('validateToken', () => {
    it('should return true for valid token', () => {
      const token = authService.generateToken({ id: '123' });
      expect(authService.validateToken(token)).toBe(true);
    });

    it('should return false for expired token', () => {
      const expiredToken = 'expired.jwt.token';
      expect(authService.validateToken(expiredToken)).toBe(false);
    });
  });
});''';

  static const _testApiCode = '''import request from 'supertest';
import app from '../src/app';

describe('User API', () => {
  describe('GET /api/users', () => {
    it('should return all users', async () => {
      const res = await request(app)
        .get('/api/users')
        .set('Authorization', 'Bearer valid-token');

      expect(res.status).toBe(200);
      expect(res.body.data).toBeInstanceOf(Array);
    });
  });

  describe('POST /api/users', () => {
    it('should create a new user', async () => {
      const userData = { name: 'John', email: 'john@test.com' };
      const res = await request(app)
        .post('/api/users')
        .send(userData);

      expect(res.status).toBe(201);
      expect(res.body.data.email).toBe(userData.email);
    });
  });
});''';

  static const _testUtilsCode = '''import { formatDate, validateEmail, slugify } from '../src/utils';

describe('Utility Functions', () => {
  describe('formatDate', () => {
    it('should format date correctly', () => {
      const date = new Date('2024-01-15');
      expect(formatDate(date)).toBe('January 15, 2024');
    });
  });

  describe('validateEmail', () => {
    it('should return true for valid email', () => {
      expect(validateEmail('test@example.com')).toBe(true);
    });

    it('should return false for invalid email', () => {
      expect(validateEmail('invalid-email')).toBe(false);
    });
  });

  describe('slugify', () => {
    it('should convert string to slug', () => {
      expect(slugify('Hello World!')).toBe('hello-world');
    });
  });
});''';

  static const _testAuthSourceCode = '''export class AuthService {
  async login(email: string, password: string) {
    // Authentication logic
  }

  generateToken(payload: object): string {
    // Token generation
  }

  validateToken(token: string): boolean {
    // Token validation
  }
}''';

  static const _jestConfigCode = '''module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  coverageThreshold: {
    global: { branches: 80, functions: 80, lines: 80 }
  }
};''';

  // ============ DEVOPS CODE SAMPLES ============
  static const _devopsCiCode = '''name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'

      - run: npm ci
      - run: npm run lint
      - run: npm run test:coverage

      - uses: codecov/codecov-action@v3

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: npm ci
      - run: npm run build

      - uses: actions/upload-artifact@v3
        with:
          name: build
          path: dist/''';

  static const _devopsDeployCode = '''name: Deploy to Production

on:
  release:
    types: [published]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: \${{ secrets.AWS_ACCESS_KEY }}
          aws-secret-access-key: \${{ secrets.AWS_SECRET_KEY }}
          aws-region: us-east-1

      - name: Deploy to ECS
        run: |
          aws ecs update-service \\
            --cluster production \\
            --service api-service \\
            --force-new-deployment''';

  static const _dockerfileCode = '''FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 3000
CMD ["node", "dist/index.js"]''';

  static const _dockerComposeCode = '''version: '3.8'
services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgres://db:5432/app
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine

volumes:
  postgres_data:''';

  static const _terraformCode = '''provider "aws" {
  region = var.aws_region
}

resource "aws_ecs_cluster" "main" {
  name = "\${var.project}-cluster"
}

resource "aws_ecs_service" "api" {
  name            = "api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.desired_count

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 3000
  }
}''';

  // ============ CODE REVIEW SAMPLES ============
  static const _reviewPaymentCode = '''// PaymentService.ts - Code Review Requested
export class PaymentService {
  // REVIEW: Should we add retry logic here?
  async processPayment(amount: number, userId: string) {
    const user = await this.userRepo.findById(userId);

    // TODO: Add input validation
    const transaction = await this.stripe.charges.create({
      amount: amount * 100,
      currency: 'usd',
      customer: user.stripeCustomerId,
    });

    // FIXME: This could fail silently
    await this.notificationService.sendReceipt(user.email, transaction);

    return transaction;
  }

  // REVIEW: Consider caching frequently accessed plans
  async getSubscriptionPlans() {
    return await this.stripe.plans.list();
  }
}''';

  static const _reviewUserServiceCode = '''// UserService.ts
export class UserService {
  // REVIEW: N+1 query issue here
  async getUsersWithOrders() {
    const users = await this.userRepo.findAll();
    for (const user of users) {
      user.orders = await this.orderRepo.findByUserId(user.id);
    }
    return users;
  }

  // TODO: Add password complexity validation
  async updatePassword(userId: string, newPassword: string) {
    const hashed = await bcrypt.hash(newPassword, 10);
    await this.userRepo.update(userId, { password: hashed });
  }
}''';

  static const _reviewValidationCode = '''// validation.ts
// REVIEW: Consider using a validation library like Zod

export function validateEmail(email: string): boolean {
  // Basic regex - might miss edge cases
  return /^[^\\s@]+@[^\\s@]+\\.[^\\s@]+\$/.test(email);
}

export function validatePassword(password: string): string[] {
  const errors: string[] = [];
  if (password.length < 8) errors.push('Min 8 characters');
  // TODO: Add more rules
  return errors;
}''';

  static const _reviewNotesCode = '''# Code Review Notes

## Summary
PR #142: Payment Processing Updates

## Issues Found
1. **PaymentService.ts:12** - No input validation
2. **PaymentService.ts:18** - Silent failure on notification
3. **UserService.ts:4** - N+1 query performance issue

## Recommendations
- Add Zod validation schemas
- Implement retry mechanism for external API calls
- Use eager loading for user orders query

## Approved with Changes
Reviewer: @senior-dev
''';
}

class FileNode {
  final String name;
  final bool isDirectory;
  final String? content;
  final String? language;
  final Map<String, FileNode>? children;

  const FileNode({
    required this.name,
    this.isDirectory = false,
    this.content,
    this.language,
    this.children,
  });
}