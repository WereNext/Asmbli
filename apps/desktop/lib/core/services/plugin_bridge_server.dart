import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../di/service_locator.dart';
import 'mcp_server_execution_service.dart';

/// HTTP/WebSocket server that communicates with PenPot plugin
/// The plugin runs in the web browser (design.penpot.app) and communicates via:
/// - HTTP POST for connection status (backward compatibility)
/// - WebSocket for bidirectional MCP tool calls
class PluginBridgeServer {
  HttpServer? _server;
  final int port;

  // WebSocket connection to plugin
  WebSocket? _pluginWebSocket;

  // Stream controller for plugin connection events
  final _connectionStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get connectionStatusStream => _connectionStatusController.stream;

  // Stream controller for MCP tool results from plugin
  final _toolResultController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get toolResultStream => _toolResultController.stream;

  // Current connection status
  String? _connectionTimestamp;
  String? _connectionMessage;
  bool _isConnected = false;

  // Plugin health metrics
  Map<String, dynamic>? _pluginHealth;
  DateTime? _lastHeartbeat;

  // Getters
  String? get connectionTimestamp => _connectionTimestamp;
  String? get connectionMessage => _connectionMessage;
  bool get isConnected => _isConnected;
  bool get isWebSocketConnected => _pluginWebSocket != null;
  Map<String, dynamic>? get pluginHealth => _pluginHealth;
  DateTime? get lastHeartbeat => _lastHeartbeat;

  PluginBridgeServer({this.port = 3000});

  /// Start the HTTP server
  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('🌐 Plugin Bridge Server started on port $port');

      _server!.listen(_handleRequest);
    } catch (e) {
      debugPrint('❌ Failed to start Plugin Bridge Server: $e');
      rethrow;
    }
  }

  /// Handle incoming HTTP requests
  Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers for web plugin
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    // Handle OPTIONS preflight
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    try {
      // Handle WebSocket upgrade request
      if (request.uri.path == '/plugin-bridge') {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          await _handleWebSocketConnection(request);
        } else {
          request.response.statusCode = 400;
          request.response.write(jsonEncode({'error': 'WebSocket upgrade required'}));
          await request.response.close();
        }
      } else if (request.method == 'POST' && request.uri.path == '/plugin-connection') {
        await _handlePluginConnection(request);
      } else if (request.method == 'POST' && request.uri.path == '/mcp-command') {
        await _handleMCPCommand(request);
      } else if (request.method == 'POST' && request.uri.path == '/mcp/execute') {
        // NEW: MCP tool execution endpoint for DSPy agents
        await _handleMCPToolExecution(request);
      } else {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({'error': 'Not found'}));
        await request.response.close();
      }
    } catch (e) {
      debugPrint('❌ Error handling request: $e');
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  /// Handle plugin connection status
  Future<void> _handlePluginConnection(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    _isConnected = data['connected'] as bool? ?? false;
    _connectionTimestamp = data['timestamp'] as String?;
    _connectionMessage = data['message'] as String?;

    debugPrint('🔌 Plugin connection status received:');
    debugPrint('   Connected: $_isConnected');
    debugPrint('   Timestamp: $_connectionTimestamp');
    debugPrint('   Message: $_connectionMessage');

    // Broadcast to listeners
    _connectionStatusController.add(data);

    // Send success response
    request.response.statusCode = 200;
    request.response.write(jsonEncode({
      'success': true,
      'message': 'Connection status received',
    }));
  }

  /// Handle MCP command from plugin
  Future<void> _handleMCPCommand(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;

    debugPrint('🛠️ MCP command received: ${data['command']}');

    // TODO: Forward to MCPBridgeService

    request.response.statusCode = 200;
    request.response.write(jsonEncode({
      'success': true,
      'message': 'Command received',
    }));
  }

  /// Handle MCP tool execution request from DSPy backend
  /// This is the callback endpoint that DSPy agents use to execute MCP tools
  Future<void> _handleMCPToolExecution(HttpRequest request) async {
    final stopwatch = Stopwatch()..start();

    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final toolName = data['tool_name'] as String?;
      final serverId = data['server_id'] as String?;
      final arguments = data['arguments'] as Map<String, dynamic>? ?? {};
      final agentId = data['agent_id'] as String?;

      debugPrint('🤖 DSPy MCP tool execution request:');
      debugPrint('   Tool: $toolName');
      debugPrint('   Server: $serverId');
      debugPrint('   Agent: $agentId');

      if (toolName == null || serverId == null) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({
          'success': false,
          'error': 'Missing required fields: tool_name and server_id',
        }));
        await request.response.close();
        return;
      }

      // Get the MCP execution service
      final mcpService = ServiceLocator.instance.get<MCPServerExecutionService>();

      // Check if server is running
      if (!mcpService.isServerHealthy(serverId)) {
        debugPrint('⚠️ MCP server $serverId not running, attempting to start...');
        // TODO: Could auto-start the server here if needed
        request.response.statusCode = 503;
        request.response.write(jsonEncode({
          'success': false,
          'error': 'MCP server $serverId is not running or unhealthy',
        }));
        await request.response.close();
        return;
      }

      // Execute the tool via MCP JSON-RPC
      debugPrint('🔧 Executing MCP tool: $toolName on server $serverId');
      final result = await mcpService.sendMCPRequest(
        serverId,
        'tools/call',
        {
          'name': toolName,
          'arguments': arguments,
        },
      );

      stopwatch.stop();
      debugPrint('✅ MCP tool executed in ${stopwatch.elapsedMilliseconds}ms');

      // Extract the result content
      final toolResult = result['result'];

      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': true,
        'result': toolResult,
        'execution_time_ms': stopwatch.elapsedMilliseconds,
      }));
      await request.response.close();

    } catch (e, stack) {
      stopwatch.stop();
      debugPrint('❌ MCP tool execution failed: $e');
      debugPrint('Stack: $stack');

      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'success': false,
        'error': e.toString(),
        'execution_time_ms': stopwatch.elapsedMilliseconds,
      }));
      await request.response.close();
    }
  }

  /// Handle WebSocket connection from plugin
  Future<void> _handleWebSocketConnection(HttpRequest request) async {
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      _pluginWebSocket = socket;

      debugPrint('🔌 WebSocket connection established with plugin');

      // Update connection status
      _isConnected = true;
      _connectionTimestamp = DateTime.now().toIso8601String();
      _connectionMessage = 'WebSocket connected';
      _connectionStatusController.add({
        'connected': true,
        'timestamp': _connectionTimestamp,
        'message': _connectionMessage,
        'type': 'websocket',
      });

      // Listen for messages from plugin
      socket.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
        },
        onDone: () {
          debugPrint('🔌 WebSocket connection closed');
          _pluginWebSocket = null;
          _isConnected = false;
          _connectionStatusController.add({
            'connected': false,
            'timestamp': DateTime.now().toIso8601String(),
            'message': 'WebSocket disconnected',
          });
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to upgrade WebSocket: $e');
    }
  }

  /// Handle incoming WebSocket messages from plugin
  void _handleWebSocketMessage(dynamic rawMessage) {
    try {
      final message = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final type = message['type'] as String?;

      debugPrint('📥 WebSocket message received: $type');

      switch (type) {
        case 'plugin-ready':
          debugPrint('✅ Plugin is ready');
          _connectionStatusController.add({
            'connected': true,
            'timestamp': message['timestamp']?.toString(),
            'message': 'Plugin ready',
            'type': 'ready',
          });
          break;

        case 'connection-status':
          debugPrint('📡 Connection status update from plugin');
          _isConnected = message['connected'] as bool? ?? false;
          _connectionTimestamp = message['timestamp'] as String?;
          _connectionMessage = message['message'] as String?;
          _connectionStatusController.add(message);
          break;

        case 'tool-result':
          debugPrint('🛠️ Tool result received from plugin');
          _toolResultController.add(message);
          break;

        case 'health-status':
          debugPrint('💚 Health status received from plugin');
          _lastHeartbeat = DateTime.now();
          _pluginHealth = {
            'version': message['version'] as String?,
            'toolCount': message['toolCount'] as int?,
            'capabilities': message['capabilities'] as List<dynamic>?,
            'status': message['status'] as String?,
            'timestamp': message['timestamp'] as String?,
            'lastHeartbeat': _lastHeartbeat!.toIso8601String(),
          };
          _connectionStatusController.add({
            'connected': true,
            'type': 'health-update',
            'health': _pluginHealth,
          });
          break;

        case 'error':
          debugPrint('❌ Error from plugin: ${message['error']}');
          _connectionStatusController.add({
            'connected': true,
            'type': 'plugin-error',
            'error': message['error'],
            'timestamp': message['timestamp'],
          });
          break;

        default:
          debugPrint('⚠️ Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('❌ Error handling WebSocket message: $e');
    }
  }

  /// Send MCP tool call to plugin via WebSocket (for browser plugin health monitoring)
  /// Note: This is NOT used for Design Agent tool execution (which uses WebView's JavaScript channels)
  Future<bool> sendToolCall(String toolName, Map<String, dynamic> parameters) async {
    if (_pluginWebSocket == null) {
      debugPrint('⚠️ Cannot send tool call: WebSocket not connected');
      return false;
    }

    try {
      final message = jsonEncode({
        'type': 'tool-call',
        'tool': toolName,
        'parameters': parameters,
      });

      _pluginWebSocket!.add(message);
      debugPrint('📤 Sent tool call: $toolName');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending tool call: $e');
      return false;
    }
  }

  /// Request health status from plugin
  Future<bool> requestHealthStatus() async {
    if (_pluginWebSocket == null) {
      debugPrint('⚠️ Cannot request health: WebSocket not connected');
      return false;
    }

    try {
      final message = jsonEncode({
        'type': 'health-check',
        'timestamp': DateTime.now().toIso8601String(),
      });

      _pluginWebSocket!.add(message);
      debugPrint('🏥 Health check requested from plugin');
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting health: $e');
      return false;
    }
  }

  /// Get connection health summary
  Map<String, dynamic> getHealthSummary() {
    final now = DateTime.now();
    final isHealthy = _isConnected &&
                      _pluginWebSocket != null &&
                      (_lastHeartbeat != null &&
                       now.difference(_lastHeartbeat!).inSeconds < 30);

    return {
      'connected': _isConnected,
      'websocketActive': _pluginWebSocket != null,
      'healthy': isHealthy,
      'lastHeartbeat': _lastHeartbeat?.toIso8601String(),
      'secondsSinceHeartbeat': _lastHeartbeat != null
          ? now.difference(_lastHeartbeat!).inSeconds
          : null,
      'pluginHealth': _pluginHealth,
      'connectionTimestamp': _connectionTimestamp,
      'connectionMessage': _connectionMessage,
    };
  }

  /// Stop the server
  Future<void> stop() async {
    await _pluginWebSocket?.close();
    await _server?.close();
    await _connectionStatusController.close();
    await _toolResultController.close();
    debugPrint('🛑 Plugin Bridge Server stopped');
  }
}
