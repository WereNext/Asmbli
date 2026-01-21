import 'package:flutter/material.dart';

/// Common models for demo scenarios

class ConfidenceNode {
  final String reasoning;
  final double confidence;
  final List<ConfidenceNode> children;
  
  const ConfidenceNode({
    required this.reasoning,
    required this.confidence,
    this.children = const [],
  });
}

class ConfidenceTree {
  final ConfidenceNode root;
  final double averageConfidence;
  
  const ConfidenceTree({
    required this.root,
    required this.averageConfidence,
  });
}

class HumanIntervention {
  final String reason;
  final double confidence;
  final String recommendation;
  final DateTime timestamp;
  
  HumanIntervention({
    required this.reason,
    required this.confidence,
    required this.recommendation,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class VerificationRequest {
  final String action;
  final String details;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const VerificationRequest({
    required this.action,
    required this.details,
    required this.onApprove,
    required this.onReject,
  });
}

class ProposedAction {
  final String title;
  final String description;
  final IconData icon;
  final Color? color;
  final bool isRecommended;
  final VoidCallback onSelect;

  const ProposedAction({
    required this.title,
    required this.description,
    required this.icon,
    this.color,
    this.isRecommended = false,
    required this.onSelect,
  });
}

class EnhancedVerificationRequest {
  final String title;
  final String situation;
  final List<ProposedAction> proposedActions;
  final VoidCallback? onChat;
  final String? codeBefore;  // Optional: code before changes (for coding agent)
  final String? codeAfter;   // Optional: code after changes (for coding agent)

  const EnhancedVerificationRequest({
    required this.title,
    required this.situation,
    required this.proposedActions,
    this.onChat,
    this.codeBefore,
    this.codeAfter,
  });
}