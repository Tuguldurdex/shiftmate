import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/groq_service.dart';
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
  late double _temperature;
  late int _maxContext;
  late TextEditingController _systemPromptController;
  bool _isTesting = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _aiEnabled = widget.group.aiEnabled;
    _temperature = widget.group.aiTemperature;
    _maxContext = widget.group.aiMaxContextMessages;
    _systemPromptController = TextEditingController(
      text: widget.group.aiSystemPrompt ?? '',
    );
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

    final groq = ref.read(groqServiceProvider);
    final response = await groq.chat(
      messages: [GroqMessage(role: 'user', content: 'Hi')],
    );

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _connectionStatus = response.success ? 'Connected ✅' : 'Could not connect ❌';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.success
              ? '✅ Groq API connected!'
              : '❌ Cannot connect to Groq API.\nCheck your GROQ_API_KEY in .env file.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            response.success ? AppTheme.accentColor : AppTheme.errorColor,
        duration: const Duration(seconds: 4),
      ),
    );

    ref.read(groqConnectionProvider.notifier).state = response.success;
  }

  void _saveSettings() {
    ref.read(chatProvider.notifier).updateGroupInfo(
      widget.group.id,
      aiEnabled: _aiEnabled,
      aiTemperature: _temperature,
      aiMaxContextMessages: _maxContext,
      aiSystemPrompt: _systemPromptController.text.trim().isEmpty
          ? null
          : _systemPromptController.text.trim(),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Switch(
              value: _aiEnabled,
              onChanged: (v) => setState(() => _aiEnabled = v),
              activeThumbColor: AppTheme.secondaryColor,
            ),
          ],
        ),
        if (_aiEnabled) ...[
          const SizedBox(height: 16),
          _buildModelInfo(),
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

  Widget _buildModelInfo() {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.smart_toy, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'llama3-8b-8192 (Groq)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Set GROQ_API_KEY in your .env file',
          style: TextStyle(fontSize: 11, color: AppTheme.textLight),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
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
              color: _connectionStatus!.contains('✅')
                  ? AppTheme.accentColor.withValues(alpha: 0.15)
                  : AppTheme.errorColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _connectionStatus!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _connectionStatus!.contains('✅')
                    ? AppTheme.accentColor
                    : AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
