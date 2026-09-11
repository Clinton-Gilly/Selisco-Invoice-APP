import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/copilot_repository.dart';
import '../../models/copilot_models.dart';

class CopilotSettingsScreen extends ConsumerStatefulWidget {
  const CopilotSettingsScreen({super.key});

  @override
  ConsumerState<CopilotSettingsScreen> createState() => _CopilotSettingsScreenState();
}

class _CopilotSettingsScreenState extends ConsumerState<CopilotSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testSuccessMessage;
  String? _testErrorMessage;
  bool _isVerified = false;

  CopilotConfig? _currentConfig;
  List<ProviderInfo> _providers = const [
    ProviderInfo(
      id: 'deepseek',
      name: 'DeepSeek',
      dialect: 'openai',
      defaultModel: 'deepseek-chat',
      models: ['deepseek-chat', 'deepseek-reasoner'],
    ),
    ProviderInfo(
      id: 'gemini',
      name: 'Google Gemini',
      dialect: 'gemini',
      defaultModel: 'gemini-2.5-flash',
      models: [
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'gemini-2.0-flash',
        'gemini-2.0-flash-lite',
        'gemini-1.5-flash',
        'gemini-1.5-pro',
      ],
    ),
    ProviderInfo(
      id: 'openai',
      name: 'OpenAI',
      dialect: 'openai',
      defaultModel: 'gpt-4o-mini',
      models: [
        'gpt-4o-mini',
        'gpt-4o',
        'gpt-4.1',
        'gpt-4.1-mini',
        'o3-mini',
        'o1',
      ],
    ),
    ProviderInfo(
      id: 'groq',
      name: 'Groq (Fast Llama & DeepSeek)',
      dialect: 'openai',
      defaultModel: 'llama-3.3-70b-versatile',
      models: [
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
        'deepseek-r1-distill-llama-70b',
        'mixtral-8x7b-32768',
      ],
    ),
    ProviderInfo(
      id: 'anthropic',
      name: 'Anthropic Claude',
      dialect: 'anthropic',
      defaultModel: 'claude-3-7-sonnet-latest',
      models: [
        'claude-3-7-sonnet-latest',
        'claude-3-5-sonnet-latest',
        'claude-3-5-haiku-latest',
        'claude-3-opus-latest',
      ],
    ),
  ];

  String _selectedProvider = 'deepseek';
  String _selectedModel = 'deepseek-chat';
  final TextEditingController _apiKeyController = TextEditingController();
  bool _readOnly = false;
  bool _confirmWrites = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(copilotRepositoryProvider);
      final data = await repo.getConfig();

      final rawConfig = data['config'];
      final config = rawConfig is Map
          ? CopilotConfig.fromJson(Map<String, dynamic>.from(rawConfig))
          : const CopilotConfig(provider: 'gemini', model: 'gemini-2.5-flash', hasKey: false);

      final rawProviders = (data['availableProviders'] as List<dynamic>?) ?? [];
      final providers = rawProviders
          .whereType<Map>()
          .map((p) => ProviderInfo.fromJson(Map<String, dynamic>.from(p)))
          .toList();

      setState(() {
        _currentConfig = config;
        if (providers.isNotEmpty) {
          _providers = providers;
        }
        // If config has an active key, respect it; otherwise default to DeepSeek as requested
        final targetProvider = (config.hasKey && _providers.any((p) => p.id == config.provider))
            ? config.provider
            : (_providers.any((p) => p.id == 'deepseek') ? 'deepseek' : _providers.first.id);
        _selectedProvider = targetProvider;

        final activeInfo = _providers.firstWhere(
          (p) => p.id == _selectedProvider,
          orElse: () => _providers.first,
        );
        _selectedModel = activeInfo.models.contains(config.model) ? config.model : activeInfo.defaultModel;
        _readOnly = config.readOnly;
        _confirmWrites = config.confirmWrites;
        _isVerified = config.hasKey; // Already verified if previously saved
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  ProviderInfo? get _activeProviderInfo {
    return _providers.firstWhere(
      (p) => p.id == _selectedProvider,
      orElse: () => _providers.isNotEmpty
          ? _providers.first
          : const ProviderInfo(id: 'gemini', name: 'Gemini', dialect: 'gemini', defaultModel: 'gemini-2.0-flash', models: ['gemini-2.0-flash']),
    );
  }

  Future<void> _runTestConnection() async {
    final keyToTest = _apiKeyController.text.trim();
    if (keyToTest.isEmpty && !(_currentConfig?.hasKey ?? false)) {
      setState(() {
        _testErrorMessage = 'Please enter an API key to test connection.';
        _testSuccessMessage = null;
        _isVerified = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testErrorMessage = null;
      _testSuccessMessage = null;
    });

    try {
      final repo = ref.read(copilotRepositoryProvider);
      final msg = await repo.testConnection(
        provider: _selectedProvider,
        model: _selectedModel,
        apiKey: keyToTest,
      );

      setState(() {
        _isTesting = false;
        _testSuccessMessage = msg;
        _testErrorMessage = null;
        _isVerified = true;
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testErrorMessage = e.toString().replaceAll('Exception: ', '');
        _testSuccessMessage = null;
        _isVerified = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(copilotRepositoryProvider);
      await repo.saveConfig(
        provider: _selectedProvider,
        model: _selectedModel,
        apiKey: _apiKeyController.text.trim().isNotEmpty ? _apiKeyController.text.trim() : null,
        readOnly: _readOnly,
        confirmWrites: _confirmWrites,
      );

      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copilot settings saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Copilot Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final activeInfo = _activeProviderInfo;
    final availableModels = activeInfo?.models ?? [_selectedModel];

    // Per build-in-app-copilot.md: Save stays disabled until Test Connection succeeds
    final hasNewKey = _apiKeyController.text.trim().isNotEmpty;
    final canSave = (!hasNewKey || _isVerified) && !_isSaving && !_isTesting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Copilot Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Provider & Model
          _buildCard(
            title: 'LLM Provider & Model',
            subtitle: 'Choose which AI model powers the assistant.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Provider', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedProvider,
                      items: _providers.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name, style: const TextStyle(fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedProvider) {
                          setState(() {
                            _selectedProvider = val;
                            final newInfo = _providers.firstWhere((p) => p.id == val);
                            _selectedModel = newInfo.defaultModel;
                            _isVerified = false;
                            _testSuccessMessage = null;
                            _testErrorMessage = null;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Model', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: availableModels.contains(_selectedModel) ? _selectedModel : availableModels.first,
                      items: availableModels.map((m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(m, style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedModel = val;
                            _isVerified = false;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: API Key Management
          _buildCard(
            title: 'API Authentication Key',
            subtitle: 'Keys are sealed server-side and never exposed to clients.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentConfig?.hasKey == true && _currentConfig?.apiKeyPreview != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Active Key: ${_currentConfig!.apiKeyPreview}',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _currentConfig?.hasKey == true ? 'Replace API Key (leave empty to keep current)' : 'Enter API Key',
                    hintText: 'sk-... or AIzaSy...',
                    prefixIcon: const Icon(Icons.key_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _isVerified = false;
                      _testSuccessMessage = null;
                      _testErrorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _runTestConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cable, size: 18),
                    label: Text(_isTesting ? 'Testing Connection...' : 'Test Connection'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                if (_testSuccessMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testSuccessMessage!,
                            style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_testErrorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _testErrorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Safety Gates
          _buildCard(
            title: 'Safety Controls',
            subtitle: 'Independent safety layers to prevent unintended modifications.',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Confirm Before Write', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                    'Presents a human-readable confirmation card with Approve & Decline buttons before any record is created or modified.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: _confirmWrites,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _confirmWrites = val),
                ),
                const Divider(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Read-Only Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                    'Disables all database write tools completely. Copilot can only search catalog, summarize invoices, and query analytics.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: _readOnly,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _readOnly = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: canSave ? _saveSettings : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              disabledBackgroundColor: AppColors.border,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
