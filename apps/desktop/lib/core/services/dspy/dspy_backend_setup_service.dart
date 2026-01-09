/// DSPy Backend Setup Service
///
/// Handles first-run setup including:
/// - Detecting Python installation
/// - Installing DSPy backend dependencies
/// - Downloading spaCy model
/// - Managing backend process
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Status of a setup step
enum SetupStepStatus {
  pending,
  inProgress,
  completed,
  failed,
  skipped,
}

/// A single step in the setup process
class SetupStep {
  final String id;
  final String title;
  final String description;
  SetupStepStatus status;
  String? errorMessage;
  double progress; // 0.0 to 1.0

  SetupStep({
    required this.id,
    required this.title,
    required this.description,
    this.status = SetupStepStatus.pending,
    this.errorMessage,
    this.progress = 0.0,
  });

  SetupStep copyWith({
    SetupStepStatus? status,
    String? errorMessage,
    double? progress,
  }) {
    return SetupStep(
      id: id,
      title: title,
      description: description,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

/// Result of Python detection
class PythonInfo {
  final bool isInstalled;
  final String? pythonPath;
  final String? version;
  final String? pipPath;
  final bool hasUv; // uv is a fast Python package manager

  PythonInfo({
    required this.isInstalled,
    this.pythonPath,
    this.version,
    this.pipPath,
    this.hasUv = false,
  });
}

/// Backend health status
class BackendHealth {
  final bool isRunning;
  final bool isHealthy;
  final String? version;
  final List<String> availableModels;
  final bool graphAvailable;
  final bool spacyAvailable;
  final int? entitiesCount;

  BackendHealth({
    required this.isRunning,
    required this.isHealthy,
    this.version,
    this.availableModels = const [],
    this.graphAvailable = false,
    this.spacyAvailable = false,
    this.entitiesCount,
  });
}

/// Service for setting up the DSPy backend
class DspyBackendSetupService {
  static const String _setupCompleteKey = 'dspy_setup_complete';
  static const String _backendPathKey = 'dspy_backend_path';
  static const String _pythonPathKey = 'dspy_python_path';

  Process? _backendProcess;
  final StreamController<String> _logController = StreamController<String>.broadcast();

  /// Stream of log messages during setup
  Stream<String> get logs => _logController.stream;

  /// Get the backend installation directory
  Future<String> getBackendPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_backendPathKey);
    if (saved != null && Directory(saved).existsSync()) {
      return saved;
    }

    // Default to app data directory
    final appDir = await getApplicationSupportDirectory();
    return path.join(appDir.path, 'dspy-backend');
  }

  /// Check if first-run setup has been completed
  Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool(_setupCompleteKey) ?? false;

    if (!complete) return false;

    // Also verify backend actually exists
    final backendPath = await getBackendPath();
    final mainPy = File(path.join(backendPath, 'main.py'));
    return mainPy.existsSync();
  }

  /// Mark setup as complete
  Future<void> markSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, true);
  }

  /// Detect Python installation
  Future<PythonInfo> detectPython() async {
    _log('Detecting Python installation...');

    // Try common Python commands
    final pythonCommands = Platform.isWindows
        ? ['python', 'python3', 'py']
        : ['python3', 'python'];

    for (final cmd in pythonCommands) {
      try {
        final result = await Process.run(cmd, ['--version']);
        if (result.exitCode == 0) {
          final version = result.stdout.toString().trim();
          _log('Found Python: $version at $cmd');

          // Get pip path
          final pipCmd = Platform.isWindows ? '$cmd -m pip' : 'pip3';

          // Check for uv (fast Python package manager)
          bool hasUv = false;
          try {
            final uvResult = await Process.run('uv', ['--version']);
            hasUv = uvResult.exitCode == 0;
            if (hasUv) {
              _log('Found uv package manager');
            }
          } catch (_) {}

          return PythonInfo(
            isInstalled: true,
            pythonPath: cmd,
            version: version,
            pipPath: pipCmd,
            hasUv: hasUv,
          );
        }
      } catch (e) {
        // Command not found, try next
      }
    }

    _log('Python not found');
    return PythonInfo(isInstalled: false);
  }

  /// Copy backend files from bundled assets or download
  Future<void> installBackendFiles(String targetPath) async {
    _log('Installing backend files to $targetPath...');

    final targetDir = Directory(targetPath);
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    // For now, we assume the backend is bundled with the app or already exists
    // In a real scenario, you'd either:
    // 1. Bundle it with the Flutter app assets
    // 2. Download it from a release URL
    // 3. Clone from git

    // Check if we're in development (backend in sibling directory)
    final devBackendPath = _findDevBackendPath();
    if (devBackendPath != null) {
      _log('Found development backend at $devBackendPath');
      await _copyDirectory(Directory(devBackendPath), targetDir);
      _log('Backend files copied successfully');
      return;
    }

    // TODO: In production, download from release URL
    throw Exception('Backend files not found. Please ensure dspy-backend is available.');
  }

  /// Find development backend path (for dev mode)
  String? _findDevBackendPath() {
    // Try relative paths from the app
    final possiblePaths = [
      // When running from apps/desktop
      '../../dspy-backend',
      // When running from project root
      'dspy-backend',
      // Absolute fallback (for your specific setup)
      r'c:\Users\Mike\OneDrive\Desktop\Asmbli\dspy-backend',
    ];

    for (final p in possiblePaths) {
      final dir = Directory(p);
      if (dir.existsSync()) {
        final mainPy = File(path.join(p, 'main.py'));
        if (mainPy.existsSync()) {
          return dir.absolute.path;
        }
      }
    }
    return null;
  }

  /// Copy directory recursively
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false)) {
      final newPath = path.join(destination.path, path.basename(entity.path));

      if (entity is Directory) {
        final newDir = Directory(newPath);
        await newDir.create(recursive: true);
        await _copyDirectory(entity, newDir);
      } else if (entity is File) {
        // Skip __pycache__, .git, and other unnecessary files
        final basename = path.basename(entity.path);
        if (basename.startsWith('.') ||
            entity.path.contains('__pycache__') ||
            entity.path.contains('.git')) {
          continue;
        }
        await entity.copy(newPath);
      }
    }
  }

  /// Install Python dependencies
  Future<void> installDependencies(String backendPath, PythonInfo python) async {
    if (!python.isInstalled || python.pythonPath == null) {
      throw Exception('Python is not installed');
    }

    _log('Installing Python dependencies...');

    // Use uv if available (much faster), otherwise pip
    final List<String> installCmd;
    if (python.hasUv) {
      installCmd = ['uv', 'pip', 'install', '-e', '.[nlp]'];
    } else {
      installCmd = [python.pythonPath!, '-m', 'pip', 'install', '-e', '.[nlp]'];
    }

    _log('Running: ${installCmd.join(' ')}');

    final result = await Process.run(
      installCmd[0],
      installCmd.sublist(1),
      workingDirectory: backendPath,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      _log('ERROR: ${result.stderr}');
      throw Exception('Failed to install dependencies: ${result.stderr}');
    }

    _log('Dependencies installed successfully');
  }

  /// Download spaCy English model
  Future<void> downloadSpacyModel(PythonInfo python) async {
    if (!python.isInstalled || python.pythonPath == null) {
      throw Exception('Python is not installed');
    }

    _log('Downloading spaCy English model...');

    final result = await Process.run(
      python.pythonPath!,
      ['-m', 'spacy', 'download', 'en_core_web_sm'],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      _log('WARNING: spaCy model download failed: ${result.stderr}');
      _log('Graph features will use regex fallback');
      // Don't throw - this is optional
      return;
    }

    _log('spaCy model downloaded successfully');
  }

  /// Create .env file with default settings
  Future<void> createEnvFile(String backendPath, {String? anthropicKey, String? openaiKey}) async {
    _log('Creating configuration file...');

    final envContent = '''
# DSPy Backend Configuration
# Generated by Asmbli Setup

${anthropicKey != null ? 'ANTHROPIC_API_KEY=$anthropicKey' : '# ANTHROPIC_API_KEY='}
${openaiKey != null ? 'OPENAI_API_KEY=$openaiKey' : '# OPENAI_API_KEY='}

# Default model
DEFAULT_MODEL=anthropic/claude-sonnet-4-20250514

# Server Configuration
HOST=0.0.0.0
PORT=8000
DEBUG=false

# Vector Database (ChromaDB)
CHROMA_PERSIST_DIR=./data/chroma
CHROMA_COLLECTION_NAME=asmbli_docs
''';

    final envFile = File(path.join(backendPath, '.env'));
    await envFile.writeAsString(envContent);
    _log('Configuration file created');
  }

  /// Start the backend process
  Future<bool> startBackend() async {
    final backendPath = await getBackendPath();
    final python = await detectPython();

    if (!python.isInstalled || python.pythonPath == null) {
      _log('Cannot start backend: Python not found');
      return false;
    }

    _log('Starting DSPy backend...');

    try {
      _backendProcess = await Process.start(
        python.pythonPath!,
        ['main.py'],
        workingDirectory: backendPath,
        runInShell: true,
      );

      // Log stdout
      _backendProcess!.stdout.transform(utf8.decoder).listen((data) {
        _log('[Backend] $data');
      });

      // Log stderr
      _backendProcess!.stderr.transform(utf8.decoder).listen((data) {
        _log('[Backend ERROR] $data');
      });

      // Wait a bit for startup
      await Future.delayed(const Duration(seconds: 3));

      // Check if it's running
      final health = await checkBackendHealth();
      if (health.isRunning) {
        _log('Backend started successfully');
        return true;
      } else {
        _log('Backend failed to start');
        return false;
      }
    } catch (e) {
      _log('Failed to start backend: $e');
      return false;
    }
  }

  /// Stop the backend process
  Future<void> stopBackend() async {
    if (_backendProcess != null) {
      _log('Stopping backend...');
      _backendProcess!.kill();
      _backendProcess = null;
    }
  }

  /// Check backend health
  Future<BackendHealth> checkBackendHealth() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final request = await client.getUrl(Uri.parse('http://localhost:8000/health'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        // Also check graph stats
        int? entitiesCount;
        bool spacyAvailable = false;
        try {
          final graphRequest = await client.getUrl(Uri.parse('http://localhost:8000/graph/stats'));
          final graphResponse = await graphRequest.close();
          if (graphResponse.statusCode == 200) {
            final graphBody = await graphResponse.transform(utf8.decoder).join();
            final graphJson = jsonDecode(graphBody) as Map<String, dynamic>;
            entitiesCount = graphJson['entity_count'] as int?;
            spacyAvailable = graphJson['spacy_available'] as bool? ?? false;
          }
        } catch (_) {}

        client.close();

        return BackendHealth(
          isRunning: true,
          isHealthy: json['status'] == 'healthy',
          version: json['version'] as String?,
          availableModels: (json['models_available'] as List?)?.cast<String>() ?? [],
          graphAvailable: true,
          spacyAvailable: spacyAvailable,
          entitiesCount: entitiesCount,
        );
      }

      client.close();
      return BackendHealth(isRunning: true, isHealthy: false);
    } catch (e) {
      return BackendHealth(isRunning: false, isHealthy: false);
    }
  }

  /// Run complete setup process
  Future<List<SetupStep>> runFullSetup({
    String? anthropicKey,
    String? openaiKey,
    void Function(List<SetupStep>)? onProgress,
  }) async {
    final steps = [
      SetupStep(
        id: 'python',
        title: 'Detect Python',
        description: 'Checking for Python installation',
      ),
      SetupStep(
        id: 'backend',
        title: 'Install Backend',
        description: 'Setting up DSPy backend files',
      ),
      SetupStep(
        id: 'dependencies',
        title: 'Install Dependencies',
        description: 'Installing Python packages',
      ),
      SetupStep(
        id: 'spacy',
        title: 'Download NLP Model',
        description: 'Downloading spaCy English model',
      ),
      SetupStep(
        id: 'config',
        title: 'Configure',
        description: 'Creating configuration file',
      ),
      SetupStep(
        id: 'start',
        title: 'Start Backend',
        description: 'Starting the DSPy backend service',
      ),
    ];

    void updateStep(int index, SetupStepStatus status, {String? error, double? progress}) {
      steps[index] = steps[index].copyWith(
        status: status,
        errorMessage: error,
        progress: progress,
      );
      onProgress?.call(List.from(steps));
    }

    try {
      // Step 1: Detect Python
      updateStep(0, SetupStepStatus.inProgress);
      final python = await detectPython();
      if (!python.isInstalled) {
        updateStep(0, SetupStepStatus.failed, error: 'Python not found. Please install Python 3.9+');
        return steps;
      }
      updateStep(0, SetupStepStatus.completed, progress: 1.0);

      // Step 2: Install backend files
      updateStep(1, SetupStepStatus.inProgress);
      final backendPath = await getBackendPath();
      await installBackendFiles(backendPath);

      // Save backend path
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backendPathKey, backendPath);
      await prefs.setString(_pythonPathKey, python.pythonPath!);

      updateStep(1, SetupStepStatus.completed, progress: 1.0);

      // Step 3: Install dependencies
      updateStep(2, SetupStepStatus.inProgress);
      await installDependencies(backendPath, python);
      updateStep(2, SetupStepStatus.completed, progress: 1.0);

      // Step 4: Download spaCy model
      updateStep(3, SetupStepStatus.inProgress);
      try {
        await downloadSpacyModel(python);
        updateStep(3, SetupStepStatus.completed, progress: 1.0);
      } catch (e) {
        // spaCy is optional
        updateStep(3, SetupStepStatus.skipped, error: 'Optional: Using regex fallback');
      }

      // Step 5: Create config
      updateStep(4, SetupStepStatus.inProgress);
      await createEnvFile(backendPath, anthropicKey: anthropicKey, openaiKey: openaiKey);
      updateStep(4, SetupStepStatus.completed, progress: 1.0);

      // Step 6: Start backend
      updateStep(5, SetupStepStatus.inProgress);
      final started = await startBackend();
      if (started) {
        updateStep(5, SetupStepStatus.completed, progress: 1.0);
        await markSetupComplete();
      } else {
        updateStep(5, SetupStepStatus.failed, error: 'Backend failed to start');
      }

      return steps;
    } catch (e) {
      _log('Setup failed: $e');
      // Mark current step as failed
      for (int i = 0; i < steps.length; i++) {
        if (steps[i].status == SetupStepStatus.inProgress) {
          updateStep(i, SetupStepStatus.failed, error: e.toString());
          break;
        }
      }
      return steps;
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logController.add('[$timestamp] $message');
  }

  void dispose() {
    stopBackend();
    _logController.close();
  }
}
