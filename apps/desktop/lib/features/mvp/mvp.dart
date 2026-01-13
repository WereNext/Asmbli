/// MVP Feature - Vertical Slice for Asmbli
///
/// This module provides a streamlined, focused experience for the MVP:
/// - Simple welcome and setup flow
/// - Core chat with web search
/// - Basic customization
///
/// Usage:
/// ```dart
/// import 'package:asmbli/features/mvp/mvp.dart';
/// ```

// Models
export 'models/mvp_message.dart';
export 'models/mvp_settings.dart';

// Services
export 'services/mvp_llm_service.dart';
export 'services/mvp_storage_service.dart';
export 'services/mvp_web_search_service.dart';

// Screens
export 'presentation/screens/mvp_welcome_screen.dart';
export 'presentation/screens/mvp_setup_screen.dart';
export 'presentation/screens/mvp_chat_screen.dart';
export 'presentation/screens/mvp_settings_screen.dart';

// Widgets
export 'presentation/widgets/mvp_message_bubble.dart';
export 'presentation/widgets/mvp_source_citation.dart';
