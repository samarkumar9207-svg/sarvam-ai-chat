/// Settings screen — configure API key, model, system prompt, theme, language.
///
/// Also includes API key validation, temperature slider, and a danger zone.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../config/api_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _systemPromptController;
  bool _obscureKey = true;
  bool _isValidating = false;
  bool? _keyValid;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ChatProvider>();
    _apiKeyController = TextEditingController(text: provider.apiKey);
    _systemPromptController = TextEditingController(text: provider.systemPrompt);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── API Key ───────────────────────────────
          _buildSection(
            context,
            title: 'Sarvam AI API Key',
            icon: Icons.key,
            children: [
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  hintText: 'Paste your API key',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      provider.setApiKey(_apiKeyController.text.trim());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API key saved')),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Key'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isValidating
                        ? null
                        : () => _validateKey(provider),
                    icon: _isValidating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Test Key'),
                  ),
                  if (_keyValid != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      _keyValid! ? Icons.check_circle : Icons.cancel,
                      color: _keyValid! ? Colors.green : cs.error,
                      size: 24,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Get your key at dashboard.sarvam.ai',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Model ─────────────────────────────────
          _buildSection(
            context,
            title: 'AI Model',
            icon: Icons.model_training,
            children: [
              ...ApiConfig.chatModels.map((model) {
                return RadioListTile<String>(
                  value: model,
                  groupValue: provider.selectedModel,
                  title: Text(_modelDisplayName(model)),
                  subtitle: Text(_modelDescription(model)),
                  onChanged: (value) {
                    if (value != null) provider.setSelectedModel(value);
                  },
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }),
            ],
          ),

          const SizedBox(height: 24),

          // ─── System Prompt ─────────────────────────
          _buildSection(
            context,
            title: 'System Prompt',
            icon: Icons.psychology,
            children: [
              TextField(
                controller: _systemPromptController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'e.g. You are a helpful assistant that answers in Hindi.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    provider.setSystemPrompt(_systemPromptController.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('System prompt saved')),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Prompt'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Language ──────────────────────────────
          _buildSection(
            context,
            title: 'Document Language',
            icon: Icons.language,
            children: [
              Text(
                'Used for document/text extraction (OCR).',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: provider.languageCode,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.translate),
                ),
                items: ApiConfig.languages.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.value,
                    child: Text(e.key),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) provider.setLanguageCode(value);
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Temperature ───────────────────────────
          _buildSection(
            context,
            title: 'Temperature: ${provider.temperature.toStringAsFixed(1)}',
            icon: Icons.thermostat,
            children: [
              Slider(
                value: provider.temperature,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                label: provider.temperature.toStringAsFixed(1),
                onChanged: (value) => provider.setTemperature(value),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Precise', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  Text('Creative', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Theme ─────────────────────────────────
          _buildSection(
            context,
            title: 'Appearance',
            icon: Icons.palette,
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: provider.themeMode,
                title: const Text('System Default'),
                secondary: const Icon(Icons.brightness_auto),
                onChanged: (v) => provider.setThemeMode(v!),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: provider.themeMode,
                title: const Text('Light'),
                secondary: const Icon(Icons.light_mode),
                onChanged: (v) => provider.setThemeMode(v!),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: provider.themeMode,
                title: const Text('Dark'),
                secondary: const Icon(Icons.dark_mode),
                onChanged: (v) => provider.setThemeMode(v!),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Danger Zone ──────────────────────────
          _buildSection(
            context,
            title: 'Danger Zone',
            icon: Icons.warning,
            color: cs.error,
            children: [
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.errorContainer,
                  foregroundColor: cs.onErrorContainer,
                ),
                onPressed: () => _showClearConfirm(provider),
                child: const Text('Clear All Conversations'),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // About.
          Center(
            child: Text(
              'Sarvam AI Chat v1.0.0\nBuilt with Flutter',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color ?? cs.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _validateKey(ChatProvider provider) async {
    setState(() {
      _isValidating = true;
      _keyValid = null;
    });

    // Save the key first if the field has been edited.
    if (_apiKeyController.text.trim() != provider.apiKey) {
      await provider.setApiKey(_apiKeyController.text.trim());
    }

    final valid = await provider.apiService.validateApiKey();
    setState(() {
      _keyValid = valid;
      _isValidating = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(valid ? 'API key is valid!' : 'API key validation failed.'),
          backgroundColor: valid ? Colors.green : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showClearConfirm(ChatProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This will permanently delete ALL conversations and messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              provider.clearAllData();
              Navigator.pop(context);
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  String _modelDisplayName(String model) {
    return switch (model) {
      'sarvam-105b' => 'Sarvam-105B (Flagship)',
      'sarvam-105b-conversations' => 'Sarvam-105B Conversations',
      'gemma4' => 'Gemma 4 31B (Vision)',
      'glm5.2' => 'GLM-5.2 (512K context)',
      'deepseek-v4-flash' => 'DeepSeek V4 Flash (1M context)',
      _ => model,
    };
  }

  String _modelDescription(String model) {
    return switch (model) {
      'sarvam-105b' => 'Best for reasoning and Indian languages',
      'sarvam-105b-conversations' => 'Optimized for real-time dialogue',
      'gemma4' => 'Supports image input — use for visual tasks',
      'glm5.2' => 'Long context (512K) with tool calling',
      'deepseek-v4-flash' => '1M context, lower cost per token',
      _ => '',
    };
  }
}
