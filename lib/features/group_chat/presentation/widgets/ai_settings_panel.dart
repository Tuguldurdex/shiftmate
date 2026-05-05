import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/ollama_service.dart';
import '../../../../services/storage_service.dart';
import '../../domain/group_chat_model.dart';
import '../providers/chat_provider.dart';

class AiSettingsPanel extends ConsumerStatefulWidget {
  final GroupChat group;

  const AiSettingsPanel({super.key, required this.group});

  @override
  ConsumerState<AiSettingsPanel> createState() => _AiSettingsPanelState();
}

class _AiSettingsPanelState extends ConsumerState<AiSettingsPanel> {
  late bool _aiEnabled;
  late String _selectedModel;
  late double _temperature;
  late int _maxContext;
  late TextEditingController _systemPromptController;
  late TextEditingController _baseUrlController;
  bool _isTesting = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _aiEnabled = widget.group.aiEnabled;
    _selectedModel = widget.group.aiModel;
    _temperature = widget.group.aiTemperature;
    _maxContext = widget.group.aiMaxContextMessages;
    _systemPromptController = TextEditingController(text: widget.group.aiSystemPrompt ?? '');
    
    // Load saved URL: storage first, then group setting, then empty
    final savedUrl = StorageService.getOllamaBaseUrl();
    final initialUrl = savedUrl?.isNotEmpty == true 
        ? savedUrl! 
        : (widget.group.aiBaseUrl ?? '');
    _baseUrlController = TextEditingController(text: initialUrl);
    
    // Update the provider if we have a URL
    if (initialUrl.isNotEmpty) {
      ref.read(ollamaBaseUrlProvider.notifier).state = initialUrl;
    }
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _connectionStatus = null;
    });

    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isEmpty) {
      setState(() {
        _isTesting = false;
        _connectionStatus = 'Enter a URL first';
      });
      return;
    }

    final ollama = OllamaService(baseUrl: baseUrl);
    final connected = await ollama.checkConnection();

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _connectionStatus = connected ? 'Connected ✅' : 'Could not connect ❌';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? '✅ Ollama connected at $baseUrl!'
              : '❌ Cannot reach Ollama at $baseUrl.\nMake sure Ollama is running and the IP is correct.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: connected ? AppTheme.accentColor : AppTheme.errorColor,
        duration: const Duration(seconds: 4),
      ),
    );

    ref.read(ollamaConnectionProvider.notifier).state = connected;
    // Update the base URL provider so the chat provider picks it up
    ref.read(ollamaBaseUrlProvider.notifier).state = baseUrl;
    // Save to persistent storage
    await StorageService.saveOllamaBaseUrl(baseUrl);
  }

  void _saveSettings() {
    final baseUrl = _baseUrlController.text.trim();
    if (baseUrl.isNotEmpty) {
      ref.read(ollamaBaseUrlProvider.notifier).state = baseUrl;
      StorageService.saveOllamaBaseUrl(baseUrl);
    }
    ref.read(chatProvider.notifier).updateAiSettings(
      widget.group.id,
      aiEnabled: _aiEnabled,
      aiModel: _selectedModel,
      aiTemperature: _temperature,
      aiMaxContextMessages: _maxContext,
      aiSystemPrompt: _systemPromptController.text.trim().isEmpty ? null : _systemPromptController.text.trim(),
      aiBaseUrl: baseUrl.isNotEmpty ? baseUrl : null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'AI Assistant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(
              value: _aiEnabled,
              onChanged: (v) => setState(() => _aiEnabled = v),
              activeThumbColor: AppTheme.secondaryColor,
            ),
          ],
        ),
        if (_aiEnabled) ...[
          _buildBaseUrlField(),
          const SizedBox(height: 16),
          _buildModelSelector(),
          const SizedBox(height: 16),
          _buildTemperatureSlider(),
          const SizedBox(height: 16),
          _buildContextSlider(),
          const SizedBox(height: 16),
          _buildSystemPromptField(),
          const SizedBox(height: 16),
          _buildConnectionTest(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save AI Settings'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBaseUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Ollama Server URL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Finding Your Computer\'s IP'),
                    content: const Text(
                      '1. Make sure your phone and computer are on the same WiFi\n'
                      '2. On your computer, open terminal and run:\n'
                      '   • Windows: ipconfig → look for "IPv4 Address"\n'
                      '   • Mac/Linux: ifconfig or ip addr\n'
                      '3. Use that IP with port 11434\n'
                      '   Example: http://192.168.1.100:11434',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: AppTheme.textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _baseUrlController,
          decoration: InputDecoration(
            hintText: 'http://192.168.1.XXX:11434',
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildModelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Model',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedModel,
              isExpanded: true,
              items: OllamaService.availableModels.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(model),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedModel = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Temperature',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              _temperature.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
        Slider(
          value: _temperature,
          min: 0.1,
          max: 1.0,
          divisions: 9,
          activeColor: AppTheme.secondaryColor,
          onChanged: (v) => setState(() => _temperature = v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Precise', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
              Text('Creative', style: TextStyle(fontSize: 11, color: AppTheme.textLight)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContextSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Max Context Messages',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              '$_maxContext',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryColor,
              ),
            ),
          ],
        ),
        Slider(
          value: _maxContext.toDouble(),
          min: 5,
          max: 50,
          divisions: 9,
          activeColor: AppTheme.secondaryColor,
          onChanged: (v) => setState(() => _maxContext = v.round()),
        ),
      ],
    );
  }

  Widget _buildSystemPromptField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Prompt (optional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _systemPromptController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Customize AI behavior...',
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildConnectionTest() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isTesting ? null : _testConnection,
            icon: _isTesting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Icon(Icons.wifi_find),
            label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (_connectionStatus != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _connectionStatus == 'Connected'
                  ? AppTheme.accentColor.withValues(alpha: 0.15)
                  : AppTheme.errorColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _connectionStatus!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _connectionStatus == 'Connected' ? AppTheme.accentColor : AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
