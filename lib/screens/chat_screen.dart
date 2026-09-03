/// Main chat screen — the primary interface where users chat with the AI.
///
/// Features:
/// - Message list with auto-scroll
/// - Empty state with welcome message and suggested prompts
/// - API key setup banner if no key is set
/// - Message bubbles with markdown rendering
/// - Copy message text on long press
/// - Regenerate response

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import 'settings_screen.dart';
import 'conversations_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-scroll when messages change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final cs = Theme.of(context).colorScheme;

    // Auto-scroll on new messages.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.messages.isNotEmpty) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => _showRenameDialog(provider),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.activeConversation?.title ?? 'Sarvam AI',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                provider.apiKey.isEmpty
                    ? 'No API key'
                    : _modelDisplayName(provider.selectedModel),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Chat History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConversationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: () => provider.startNewConversation(),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  break;
                case 'clear':
                  _showClearConfirm(provider);
                  break;
                case 'rename':
                  _showRenameDialog(provider);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename Chat')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'clear', child: Text('Clear All Data')),
            ],
          ),
        ],
      ),
      body: provider.apiKey.isEmpty
          ? _buildApiKeyPrompt(context, provider)
          : provider.messages.isEmpty
              ? _buildEmptyState(context, provider)
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: provider.messages.length,
                        itemBuilder: (context, index) {
                          final msg = provider.messages[index];
                          return MessageBubble(
                            message: msg,
                            onRegenerate: msg.isError || (index == provider.messages.length - 1 && !msg.isUser)
                                ? () => provider.regenerateLastResponse()
                                : null,
                          );
                        },
                      ),
                    ),
                    ChatInputBar(controller: _textController),
                  ],
                ),
    );
  }

  Widget _buildApiKeyPrompt(BuildContext context, ChatProvider provider) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.key, size: 64, color: cs.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Set Your Sarvam AI API Key',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'To start chatting, you need a Sarvam AI API key. Get one for free at dashboard.sarvam.ai.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ChatProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final suggestions = [
      'Explain quantum computing in simple terms',
      'भारत का इतिहास बताओ (Tell me about India\'s history)',
      'Write a Flutter function to reverse a string',
      'தமிழில் கவிதை எழுது (Write a poem in Tamil)',
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / icon.
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ask Anything',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Powered by Sarvam AI — supports Indian languages, images, and files.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Suggested prompts.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions.map((s) {
                return ActionChip(
                  label: Text(s),
                  onPressed: () {
                    provider.startNewConversation();
                    provider.sendMessage(s);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(ChatProvider provider) {
    if (provider.activeConversation == null) return;
    final controller =
        TextEditingController(text: provider.activeConversation!.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.renameConversation(
                provider.activeConversation!.id,
                controller.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirm(ChatProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all conversations and messages. This cannot be undone.',
        ),
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
      'sarvam-105b' => 'Sarvam-105B',
      'sarvam-105b-conversations' => 'Sarvam-105B Conversations',
      'gemma4' => 'Gemma 4 (Vision)',
      'glm5.2' => 'GLM-5.2',
      'deepseek-v4-flash' => 'DeepSeek V4 Flash',
      _ => model,
    };
  }
}
