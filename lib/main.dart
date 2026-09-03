/// Sarvam AI Chat — a beautiful AI chat app powered by Sarvam AI.
///
/// Features:
/// - Chat with Sarvam-105B (supports Indian languages natively)
/// - Image input via Gemma 4 vision model
/// - Document AI for PDF/image text extraction
/// - Conversation history (SQLite)
/// - File & image uploads
/// - Markdown rendering
/// - Dark/Light/System theme
/// - Configurable system prompt, temperature, model

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/chat_provider.dart';
import 'theme/app_theme.dart';
import 'screens/chat_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SarvamAIChatApp());
}

class SarvamAIChatApp extends StatelessWidget {
  const SarvamAIChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'Sarvam AI Chat',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: provider.themeMode,
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

/// Shows a loading screen while initializing, then transitions to the chat screen.
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final provider = context.read<ChatProvider>();
    await provider.init();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final cs = Theme.of(context).colorScheme;

    // While settings are loading, show a splash.
    return provider.conversations.isEmpty && provider.isLoading
        ? Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                    child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sarvam AI',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          )
        : const ChatScreen();
  }
}
