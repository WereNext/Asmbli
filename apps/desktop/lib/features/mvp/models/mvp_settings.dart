/// MVP Settings model - simplified for vertical slice
class MvpSettings {
  final String agentName;
  final String systemPrompt;
  final String selectedModel;
  final String selectedProvider;
  final double temperature;
  final bool webSearchEnabled;

  static const String defaultAgentName = 'Research Assistant';
  static const String defaultSystemPrompt = '''You are a helpful AI research assistant.
When answering questions about current events, recent developments, or topics that require up-to-date information, you will search the web for relevant sources.

Always cite your sources when providing information from web searches. Be conversational, helpful, and thorough in your responses.''';
  static const double defaultTemperature = 0.7;

  MvpSettings({
    this.agentName = defaultAgentName,
    this.systemPrompt = defaultSystemPrompt,
    this.selectedModel = 'gpt-4o',
    this.selectedProvider = 'openai',
    this.temperature = defaultTemperature,
    this.webSearchEnabled = true,
  });

  MvpSettings copyWith({
    String? agentName,
    String? systemPrompt,
    String? selectedModel,
    String? selectedProvider,
    double? temperature,
    bool? webSearchEnabled,
  }) {
    return MvpSettings(
      agentName: agentName ?? this.agentName,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      temperature: temperature ?? this.temperature,
      webSearchEnabled: webSearchEnabled ?? this.webSearchEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'agentName': agentName,
        'systemPrompt': systemPrompt,
        'selectedModel': selectedModel,
        'selectedProvider': selectedProvider,
        'temperature': temperature,
        'webSearchEnabled': webSearchEnabled,
      };

  factory MvpSettings.fromJson(Map<String, dynamic> json) => MvpSettings(
        agentName: json['agentName'] as String? ?? defaultAgentName,
        systemPrompt: json['systemPrompt'] as String? ?? defaultSystemPrompt,
        selectedModel: json['selectedModel'] as String? ?? 'gpt-4o',
        selectedProvider: json['selectedProvider'] as String? ?? 'openai',
        temperature: (json['temperature'] as num?)?.toDouble() ?? defaultTemperature,
        webSearchEnabled: json['webSearchEnabled'] as bool? ?? true,
      );

  /// Reset to defaults
  factory MvpSettings.defaults() => MvpSettings();
}
