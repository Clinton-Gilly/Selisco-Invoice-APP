import 'package:flutter/foundation.dart';

enum CopilotRole { user, assistant, tool, system }

@immutable
class ProposedAction {
  final String id;
  final String callId;
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  final bool alwaysConfirm;
  final String? table;

  const ProposedAction({
    required this.id,
    required this.callId,
    required this.name,
    required this.description,
    required this.parameters,
    this.alwaysConfirm = false,
    this.table,
  });

  factory ProposedAction.fromJson(Map<String, dynamic> json) {
    return ProposedAction(
      id: json['id'] as String? ?? '',
      callId: json['callId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      parameters: (json['parameters'] as Map<String, dynamic>?) ?? {},
      alwaysConfirm: json['alwaysConfirm'] as bool? ?? false,
      table: json['table'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'callId': callId,
        'name': name,
        'description': description,
        'parameters': parameters,
        'alwaysConfirm': alwaysConfirm,
        'table': table,
      };
}

@immutable
class ActionExecuted {
  final String actionName;
  final String description;
  final String auditLogId;
  final dynamic result;
  final bool undone;

  const ActionExecuted({
    required this.actionName,
    required this.description,
    required this.auditLogId,
    this.result,
    this.undone = false,
  });

  factory ActionExecuted.fromJson(Map<String, dynamic> json) {
    return ActionExecuted(
      actionName: json['actionName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      auditLogId: json['auditLogId'] as String? ?? '',
      result: json['result'],
      undone: json['undone'] as bool? ?? false,
    );
  }

  ActionExecuted copyWith({bool? undone}) {
    return ActionExecuted(
      actionName: actionName,
      description: description,
      auditLogId: auditLogId,
      result: result,
      undone: undone ?? this.undone,
    );
  }
}

@immutable
class CopilotMessage {
  final String id;
  final CopilotRole role;
  final String text;
  final String? reasoning;
  final ProposedAction? pendingAction;
  final ActionExecuted? actionExecuted;
  final DateTime timestamp;
  final bool isError;
  // Server-side API message (preserves tool_calls, raw, etc.)
  final Map<String, dynamic>? rawApiMessage;

  const CopilotMessage({
    required this.id,
    required this.role,
    required this.text,
    this.reasoning,
    this.pendingAction,
    this.actionExecuted,
    required this.timestamp,
    this.isError = false,
    this.rawApiMessage,
  });

  CopilotMessage copyWith({
    String? text,
    String? reasoning,
    ProposedAction? pendingAction,
    ActionExecuted? actionExecuted,
    bool? isError,
    Map<String, dynamic>? rawApiMessage,
  }) {
    return CopilotMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      reasoning: reasoning ?? this.reasoning,
      pendingAction: pendingAction ?? this.pendingAction,
      actionExecuted: actionExecuted ?? this.actionExecuted,
      timestamp: timestamp,
      isError: isError ?? this.isError,
      rawApiMessage: rawApiMessage ?? this.rawApiMessage,
    );
  }

  Map<String, dynamic> toApiMessage() {
    // If we have a raw API message from the server, use that (preserves tool_calls etc.)
    if (rawApiMessage != null) return rawApiMessage!;
    return {
      'role': role.name,
      'text': text,
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    if (reasoning != null) 'reasoning': reasoning,
    if (pendingAction != null) 'pendingAction': pendingAction!.toJson(),
    if (actionExecuted != null) 'actionExecuted': {
      'actionName': actionExecuted!.actionName,
      'description': actionExecuted!.description,
      'auditLogId': actionExecuted!.auditLogId,
      'undone': actionExecuted!.undone,
    },
    'timestamp': timestamp.toIso8601String(),
    'isError': isError,
  };

  factory CopilotMessage.fromJson(Map<String, dynamic> json) {
    return CopilotMessage(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      role: CopilotRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => CopilotRole.assistant,
      ),
      text: json['text'] as String? ?? '',
      reasoning: json['reasoning'] as String?,
      pendingAction: json['pendingAction'] != null
          ? ProposedAction.fromJson(json['pendingAction'] as Map<String, dynamic>)
          : null,
      actionExecuted: json['actionExecuted'] != null
          ? ActionExecuted.fromJson(json['actionExecuted'] as Map<String, dynamic>)
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isError: json['isError'] as bool? ?? false,
    );
  }
}


@immutable
class CopilotConfig {
  final String provider;
  final String model;
  final bool hasKey;
  final String? apiKeyPreview;
  final bool readOnly;
  final bool confirmWrites;
  final String? savedAt;

  const CopilotConfig({
    required this.provider,
    required this.model,
    required this.hasKey,
    this.apiKeyPreview,
    this.readOnly = false,
    this.confirmWrites = true,
    this.savedAt,
  });

  factory CopilotConfig.fromJson(Map<String, dynamic> json) {
    return CopilotConfig(
      provider: json['provider'] as String? ?? 'gemini',
      model: json['model'] as String? ?? 'gemini-2.5-flash',
      hasKey: json['hasKey'] as bool? ?? false,
      apiKeyPreview: json['apiKeyPreview'] as String?,
      readOnly: json['readOnly'] as bool? ?? false,
      confirmWrites: json['confirmWrites'] as bool? ?? true,
      savedAt: json['savedAt'] as String?,
    );
  }
}

@immutable
class ProviderInfo {
  final String id;
  final String name;
  final String dialect;
  final String defaultModel;
  final List<String> models;

  const ProviderInfo({
    required this.id,
    required this.name,
    required this.dialect,
    required this.defaultModel,
    required this.models,
  });

  factory ProviderInfo.fromJson(Map<String, dynamic> json) {
    return ProviderInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dialect: json['dialect'] as String? ?? '',
      defaultModel: json['defaultModel'] as String? ?? '',
      models: (json['models'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

@immutable
class ScreenContext {
  final String route;
  final String screenName;
  final String? activeTab;
  final int? visibleCount;
  final Map<String, dynamic>? activeRecord;
  final Map<String, dynamic>? formData;
  final String? customNote;

  const ScreenContext({
    required this.route,
    required this.screenName,
    this.activeTab,
    this.visibleCount,
    this.activeRecord,
    this.formData,
    this.customNote,
  });

  Map<String, dynamic> toJson() => {
        'route': route,
        'screenName': screenName,
        if (activeTab != null) 'activeTab': activeTab,
        if (visibleCount != null) 'visibleCount': visibleCount,
        if (activeRecord != null) 'activeRecord': activeRecord,
        if (formData != null) 'formData': formData,
        if (customNote != null) 'customNote': customNote,
      };
}
