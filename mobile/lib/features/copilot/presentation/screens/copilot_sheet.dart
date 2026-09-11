import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/copilot_repository.dart';
import '../../models/copilot_models.dart';
import '../../services/screen_context_service.dart';
import '../widgets/action_confirmation_card.dart';
import '../widgets/screen_context_pill.dart';
import 'copilot_settings_screen.dart';

class CopilotSheet extends ConsumerStatefulWidget {
  const CopilotSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CopilotSheet(),
    );
  }

  @override
  ConsumerState<CopilotSheet> createState() => _CopilotSheetState();
}

class _CopilotSheetState extends ConsumerState<CopilotSheet> {
  final List<CopilotMessage> _messages = [];
  // Authoritative backend conversation history (preserves tool_calls, raw, etc.)
  List<Map<String, dynamic>> _backendHistory = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isProcessingAction = false;

  static const _kHistoryKey = 'copilot_chat_history';
  static const _kBackendHistoryKey = 'copilot_backend_history';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    final rawBackend = prefs.getString(_kBackendHistoryKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        final loaded = list
            .map((e) => CopilotMessage.fromJson(e as Map<String, dynamic>))
            .where((m) => !m.isError)
            .toList();
        if (loaded.isNotEmpty) {
          if (mounted) setState(() => _messages.addAll(loaded));
        } else {
          if (mounted) _addInitialGreeting();
        }
      } catch (_) {
        if (mounted) _addInitialGreeting();
      }
    } else {
      if (mounted) _addInitialGreeting();
    }
    if (rawBackend != null) {
      try {
        final List<dynamic> list = jsonDecode(rawBackend) as List<dynamic>;
        _backendHistory = list
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } catch (_) {}
    }
    if (mounted) _scrollToBottom();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // Only save user and assistant display messages (not tool/system)
    final toSave = _messages
        .where((m) => m.role == CopilotRole.user || m.role == CopilotRole.assistant)
        .map((m) => m.toJson())
        .toList();
    await prefs.setString(_kHistoryKey, jsonEncode(toSave));
    await prefs.setString(_kBackendHistoryKey, jsonEncode(_backendHistory));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addInitialGreeting() {
    final screenContext = ref.read(screenContextProvider);
    setState(() {
      _messages.add(
        CopilotMessage(
          id: 'msg_welcome',
          role: CopilotRole.assistant,
          text: 'Hello! I\'m your **Selisco Assistant** on **${screenContext.screenName}**. I can create invoices, add catalog items, convert delivery notes, and report revenue metrics. How can I help?',
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage([String? overrideText]) async {
    final text = overrideText ?? _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (overrideText == null) {
      _inputController.clear();
    }

    final userMsg = CopilotMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: CopilotRole.user,
      text: text,
      timestamp: DateTime.now(),
    );

    // Add user message to backend history
    _backendHistory.add({'role': 'user', 'text': text});

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final repo = ref.read(copilotRepositoryProvider);
      final screenContext = ref.read(screenContextProvider);

      final data = await repo.sendChatTurn(
        messages: _backendHistory,
        screenContext: screenContext,
      );

      // Update backend history with server-returned authoritative messages
      if (data['messages'] is List) {
        _backendHistory = (data['messages'] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }

      final replyText = data['text'] as String? ?? 'Done.';
      final reasoning = data['reasoning'] as String?;

      ProposedAction? pendingAction;
      if (data['pendingAction'] is Map) {
        pendingAction = ProposedAction.fromJson(
          Map<String, dynamic>.from(data['pendingAction'] as Map),
        );
      }

      ActionExecuted? actionExecuted;
      if (data['actionExecuted'] is Map) {
        actionExecuted = ActionExecuted.fromJson(
          Map<String, dynamic>.from(data['actionExecuted'] as Map),
        );
      }

      final assistantMsg = CopilotMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        role: CopilotRole.assistant,
        text: replyText,
        reasoning: reasoning,
        pendingAction: pendingAction,
        actionExecuted: actionExecuted,
        timestamp: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _messages.add(assistantMsg);
        _isLoading = false;
      });
      _scrollToBottom();
      _saveHistory();
    } catch (e) {
      // Rollback the user message from backend history on error
      if (_backendHistory.isNotEmpty) _backendHistory.removeLast();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(
          CopilotMessage(
            id: 'err_${DateTime.now().millisecondsSinceEpoch}',
            role: CopilotRole.assistant,
            text: 'Error: ${e.toString().replaceAll('Exception: ', '')}',
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleApproveAction(ProposedAction action, int messageIndex) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    try {
      final repo = ref.read(copilotRepositoryProvider);
      final screenContext = ref.read(screenContextProvider);

      final data = await repo.sendChatTurn(
        messages: _backendHistory,
        screenContext: screenContext,
        approvedCall: {
          'callId': action.callId,
          'name': action.name,
          'parameters': action.parameters,
        },
      );

      // Update backend history
      if (data['messages'] is List) {
        _backendHistory = (data['messages'] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }

      final replyText = data['text'] as String? ?? 'Action executed.';
      final reasoning = data['reasoning'] as String?;

      ActionExecuted? executed;
      if (data['actionExecuted'] is Map) {
        executed = ActionExecuted.fromJson(
          Map<String, dynamic>.from(data['actionExecuted'] as Map),
        );
      }

      if (!mounted) return;
      setState(() {
        _messages[messageIndex] = _messages[messageIndex].copyWith(pendingAction: null);
        _messages.add(
          CopilotMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            role: CopilotRole.assistant,
            text: replyText,
            reasoning: reasoning,
            actionExecuted: executed,
            timestamp: DateTime.now(),
          ),
        );
        _isProcessingAction = false;
      });
      _scrollToBottom();
      _saveHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action execution failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleDeclineAction(ProposedAction action, int messageIndex) async {
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    try {
      final repo = ref.read(copilotRepositoryProvider);
      final screenContext = ref.read(screenContextProvider);

      final data = await repo.sendChatTurn(
        messages: _backendHistory,
        screenContext: screenContext,
        declinedCall: {
          'callId': action.callId,
          'name': action.name,
        },
      );

      // Update backend history
      if (data['messages'] is List) {
        _backendHistory = (data['messages'] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }

      final replyText = data['text'] as String? ?? 'Action cancelled.';

      if (!mounted) return;
      setState(() {
        _messages[messageIndex] = _messages[messageIndex].copyWith(pendingAction: null);
        _messages.add(
          CopilotMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            role: CopilotRole.assistant,
            text: replyText,
            timestamp: DateTime.now(),
          ),
        );
        _isProcessingAction = false;
      });
      _scrollToBottom();
      _saveHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingAction = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline action: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleUndo(ActionExecuted action, int messageIndex) async {
    try {
      final repo = ref.read(copilotRepositoryProvider);
      final msg = await repo.undoAction(action.auditLogId);

      if (!mounted) return;
      setState(() {
        final updatedAction = action.copyWith(undone: true);
        _messages[messageIndex] = _messages[messageIndex].copyWith(actionExecuted: updatedAction);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Undo failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  List<String> _getQuickSuggestions(ScreenContext screen) {
    switch (screen.route) {
      case '/catalog':
        return [
          'Add new product: Titanium Mesh 10x10cm at KES 35,000',
          'Find cortical screws in catalog',
          'List available straight plates',
        ];
      case '/deliveries':
        return [
          'List pending delivery notes',
          'What is our delivery completion rate?',
        ];
      case '/analytics':
        return [
          'Summarize total revenue and outstanding collections',
          'Give me an operational breakdown',
        ];
      case '/invoices':
      default:
        return [
          'Create invoice for Nairobi Hospital with 2 Straight T-plates',
          'Show unpaid invoices',
          'Which invoices are overdue?',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenContext = ref.watch(screenContextProvider);
    final suggestions = _getQuickSuggestions(screenContext);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selisco Copilot',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    Text(
                      'Operational AI Assistant',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const Spacer(),
                ScreenContextPill(context: screenContext),
                const SizedBox(width: 4),
                // Clear history button
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: AppColors.textSecondary),
                  tooltip: 'Clear history',
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove(_kHistoryKey);
                    await prefs.remove(_kBackendHistoryKey);
                    setState(() {
                      _messages.clear();
                      _backendHistory.clear();
                    });
                    _addInitialGreeting();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20, color: AppColors.textSecondary),
                  tooltip: 'Copilot Settings',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CopilotSettingsScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Message history
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildLoadingIndicator();
                }

                final msg = _messages[index];
                return _buildMessageItem(msg, index);
              },
            ),
          ),

          // Quick suggestions chips
          if (!_isLoading) ...[
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final text = suggestions[i];
                  return ActionChip(
                    label: Text(text, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onPressed: () => _handleSendMessage(text),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask or instruct Copilot...',
                        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _isLoading ? null : () => _handleSendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(CopilotMessage msg, int index) {
    final isUser = msg.role == CopilotRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: msg.isError
                        ? AppColors.errorBg
                        : AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    msg.isError ? Icons.error_outline : Icons.auto_awesome,
                    size: 14,
                    color: msg.isError ? AppColors.error : AppColors.primary,
                  ),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : msg.isError
                            ? AppColors.errorBg
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: isUser
                        ? null
                        : Border.all(
                            color: msg.isError
                                ? AppColors.error.withValues(alpha: 0.3)
                                : AppColors.border,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reasoning disclosure (if present)
                      if (msg.reasoning != null && msg.reasoning!.isNotEmpty) ...[
                        _buildReasoningTile(msg.reasoning!),
                        const SizedBox(height: 6),
                      ],
                      _buildMarkdownText(
                        msg.text,
                        baseColor: isUser
                            ? Colors.white
                            : msg.isError
                                ? AppColors.error
                                : AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Action confirmation card
          if (msg.pendingAction != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: ActionConfirmationCard(
                action: msg.pendingAction!,
                isProcessing: _isProcessingAction,
                onApprove: () => _handleApproveAction(msg.pendingAction!, index),
                onDecline: () => _handleDeclineAction(msg.pendingAction!, index),
              ),
            ),
          ],

          // Action executed badge with Undo button
          if (msg.actionExecuted != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: msg.actionExecuted!.undone ? AppColors.warningBg : AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: msg.actionExecuted!.undone
                        ? AppColors.warning.withValues(alpha: 0.3)
                        : AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      msg.actionExecuted!.undone ? Icons.undo : Icons.check_circle_outline,
                      size: 14,
                      color: msg.actionExecuted!.undone ? AppColors.warning : AppColors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      msg.actionExecuted!.undone ? 'Action Undone' : 'Action Recorded in Audit Log',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: msg.actionExecuted!.undone ? AppColors.warning : AppColors.success,
                      ),
                    ),
                    if (!msg.actionExecuted!.undone) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _handleUndo(msg.actionExecuted!, index),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.undo, size: 12, color: AppColors.textSecondary),
                              SizedBox(width: 2),
                              Text('Undo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReasoningTile(String reasoning) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        dense: true,
        leading: const Icon(Icons.psychology_outlined, size: 16, color: AppColors.primary),
        title: const Text(
          'Model Thinking',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              reasoning,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders text with **bold** and *italic* markdown as real rich text.
  Widget _buildMarkdownText(String text, {required Color baseColor}) {
    final spans = <TextSpan>[];
    // Match **bold**, *italic*, or plain text segments
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|([^*]+)', dotAll: true);
    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: baseColor,
            height: 1.35,
          ),
        ));
      } else if (match.group(2) != null) {
        // *italic*
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontSize: 14,
            color: baseColor,
            height: 1.35,
          ),
        ));
      } else if (match.group(3) != null) {
        // plain text
        spans.add(TextSpan(
          text: match.group(3),
          style: TextStyle(
            fontSize: 14,
            color: baseColor,
            height: 1.35,
          ),
        ));
      }
    }
    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(width: 8),
                Text('Thinking & querying...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
