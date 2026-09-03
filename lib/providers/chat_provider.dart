/// ChatProvider — central state management for the chat app.
///
/// Manages:
/// - API key and settings (persisted via SharedPreferences)
/// - Active conversation and messages
/// - Sending messages and receiving AI responses
/// - Conversation list (history)
/// - Theme mode, model selection, system prompt

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/sarvam_api_service.dart';
import '../services/chat_repository.dart';
import '../services/file_picker_service.dart';
import '../config/api_config.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _repository;
  final FilePickerService _filePicker;
  late SarvamApiService _apiService;

  // Settings
  String _apiKey = '';
  String _selectedModel = ApiConfig.defaultChatModel;
  String _systemPrompt = '';
  String _languageCode = 'en-IN';
  ThemeMode _themeMode = ThemeMode.system;
  double _temperature = 0.7;

  // State
  List<Conversation> _conversations = [];
  Conversation? _activeConversation;
  List<ChatMessage> _messages = [];
  List<Attachment> _pendingAttachments = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  // Getters
  String get apiKey => _apiKey;
  String get selectedModel => _selectedModel;
  String get systemPrompt => _systemPrompt;
  String get languageCode => _languageCode;
  ThemeMode get themeMode => _themeMode;
  double get temperature => _temperature;

  List<Conversation> get conversations => _conversations;
  Conversation? get activeConversation => _activeConversation;
  List<ChatMessage> get messages => _messages;
  List<Attachment> get pendingAttachments => _pendingAttachments;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get hasPendingAttachments => _pendingAttachments.isNotEmpty;
  String? get errorMessage => _errorMessage;
  SarvamApiService get apiService => _apiService;

  ChatProvider({
    ChatRepository? repository,
    FilePickerService? filePicker,
  })  : _repository = repository ?? LocalChatRepository(),
        _filePicker = filePicker ?? FilePickerService() {
    _apiService = SarvamApiService(apiKey: '');
  }

  /// Initialize — load settings and conversations.
  Future<void> init() async {
    await _repository.init();
    await _loadSettings();
    _apiService = SarvamApiService(apiKey: _apiKey);
    await loadConversations();
  }

  // ─── Settings ──────────────────────────────────────────

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key') ?? '';
    _selectedModel = prefs.getString('selected_model') ?? ApiConfig.defaultChatModel;
    _systemPrompt = prefs.getString('system_prompt') ?? '';
    _languageCode = prefs.getString('language_code') ?? 'en-IN';

    final themeIdx = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[themeIdx.clamp(0, 2)];

    _temperature = prefs.getDouble('temperature') ?? 0.7;
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    _apiService = SarvamApiService(apiKey: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', key);
    notifyListeners();
  }

  Future<void> setSelectedModel(String model) async {
    _selectedModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model', model);
    notifyListeners();
  }

  Future<void> setSystemPrompt(String prompt) async {
    _systemPrompt = prompt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('system_prompt', prompt);
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setTemperature(double value) async {
    _temperature = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('temperature', value);
    notifyListeners();
  }

  // ─── Conversations ────────────────────────────────────

  Future<void> loadConversations() async {
    _isLoading = true;
    notifyListeners();
    _conversations = await _repository.getConversations();
    _isLoading = false;
    notifyListeners();
  }

  Future<Conversation> startNewConversation() async {
    final conv = await _repository.createConversation(
      systemPrompt: _systemPrompt.isNotEmpty ? _systemPrompt : null,
    );
    _conversations.insert(0, conv);
    _activeConversation = conv;
    _messages = [];
    notifyListeners();
    return conv;
  }

  Future<void> selectConversation(Conversation conversation) async {
    _activeConversation = conversation;
    _messages = await _repository.getMessages(conversation.id);
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    await _repository.deleteConversation(id);
    _conversations.removeWhere((c) => c.id == id);
    if (_activeConversation?.id == id) {
      _activeConversation = null;
      _messages = [];
    }
    notifyListeners();
  }

  Future<void> renameConversation(String id, String newTitle) async {
    final conv = _conversations.firstWhere((c) => c.id == id);
    final updated = conv.copyWith(title: newTitle, updatedAt: DateTime.now());
    await _repository.updateConversation(updated);
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _conversations[idx] = updated;
      if (_activeConversation?.id == id) {
        _activeConversation = updated;
      }
    }
    notifyListeners();
  }

  // ─── Attachments ─────────────────────────────────────

  Future<void> pickImage() async {
    final att = await _filePicker.pickImage();
    if (att != null) {
      _pendingAttachments.add(att);
      notifyListeners();
    }
  }

  Future<void> takePhoto() async {
    final att = await _filePicker.takePhoto();
    if (att != null) {
      _pendingAttachments.add(att);
      notifyListeners();
    }
  }

  Future<void> pickFile() async {
    final att = await _filePicker.pickFile();
    if (att != null) {
      _pendingAttachments.add(att);
      notifyListeners();
    }
  }

  void removeAttachment(String id) {
    _pendingAttachments.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  // ─── Send Message ─────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty && _pendingAttachments.isEmpty) return;
    if (_activeConversation == null) {
      await startNewConversation();
    }

    _errorMessage = null;
    _isSending = true;
    notifyListeners();

    try {
      // 1. Process any non-image attachments (PDFs, text files) via Document AI
      //    and include the extracted text in the message.
      String messageContent = text.trim();
      final processedAttachments = <Attachment>[];

      for (final att in _pendingAttachments) {
        if (att.type == AttachmentType.pdf || att.type == AttachmentType.text) {
          try {
            final extracted = await _apiService.extractDocument(
              attachment: att,
              language: _languageCode,
            );
            messageContent += '\n\n[File: ${att.fileName}]\n$extracted';
          } catch (e) {
            // If Document AI fails, note it but continue.
            messageContent += '\n\n[File: ${att.fileName} — could not extract text: $e]';
          }
        } else {
          processedAttachments.add(att);
        }
      }

      // 2. Create and store the user message.
      final userMessage = ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        conversationId: _activeConversation!.id,
        role: 'user',
        content: messageContent.isEmpty ? 'Please analyze the attached image(s).' : messageContent,
        attachments: processedAttachments,
        createdAt: DateTime.now(),
      );
      await _repository.addMessage(userMessage);
      _messages.add(userMessage);

      // Auto-title the conversation from the first message.
      if (_activeConversation!.title == 'New Chat' && messageContent.isNotEmpty) {
        final title = messageContent.length > 40
            ? '${messageContent.substring(0, 40)}...'
            : messageContent;
        await renameConversation(_activeConversation!.id, title);
      }

      // Clear pending attachments.
      _pendingAttachments = [];
      notifyListeners();

      // 3. Create a placeholder for the AI response.
      final assistantMessage = ChatMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}_ai',
        conversationId: _activeConversation!.id,
        role: 'assistant',
        content: '',
        createdAt: DateTime.now(),
        isStreaming: true,
      );
      _messages.add(assistantMessage);
      notifyListeners();

      // 4. Build context messages for the API (all messages in the conversation).
      final contextMessages = _messages
          .where((m) => !m.isStreaming && !m.isError)
          .toList();

      // 5. Call the API.
      final response = await _apiService.chat(
        messages: contextMessages,
        model: _selectedModel,
        systemPrompt: _activeConversation?.systemPrompt ?? _systemPrompt,
        temperature: _temperature,
      );

      // 6. Update the assistant message with the response.
      final updatedAssistant = assistantMessage.copyWith(
        content: response,
        isStreaming: false,
      );
      await _repository.addMessage(updatedAssistant);

      final idx = _messages.indexWhere((m) => m.id == assistantMessage.id);
      if (idx >= 0) {
        _messages[idx] = updatedAssistant;
      }

      // Update conversation timestamp.
      await _repository.updateConversation(
        _activeConversation!.copyWith(updatedAt: DateTime.now()),
      );
    } catch (e) {
      // Show error message as the assistant's response.
      final errorIdx = _messages.indexWhere((m) => m.isStreaming);
      if (errorIdx >= 0) {
        final errorMsg = _messages[errorIdx].copyWith(
          content: e is SarvamApiException
              ? e.message
              : 'Something went wrong: $e',
          isError: true,
          isStreaming: false,
        );
        await _repository.addMessage(errorMsg);
        _messages[errorIdx] = errorMsg;
      }
      _errorMessage = e.toString();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> regenerateLastResponse() async {
    if (_messages.isEmpty) return;

    // Find the last user message.
    int lastUserIdx = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        lastUserIdx = i;
        break;
      }
    }
    if (lastUserIdx < 0) return;

    // Remove all messages after the last user message.
    final toRemove = _messages.sublist(lastUserIdx + 1);
    for (final msg in toRemove) {
      await _repository.deleteMessage(msg.id);
    }
    _messages = _messages.sublist(0, lastUserIdx + 1);
    notifyListeners();

    // Re-send the last user message content.
    final lastUserMsg = _messages[lastUserIdx];
    final userText = lastUserMsg.content;

    // Temporarily restore image attachments if any.
    _pendingAttachments = List.from(lastUserMsg.attachments);

    // Remove the user message from the list (sendMessage will re-add it).
    _messages.removeAt(lastUserIdx);
    await _repository.deleteMessage(lastUserMsg.id);

    await sendMessage(userText);
  }

  Future<void> clearAllData() async {
    await _repository.clearAll();
    _conversations = [];
    _activeConversation = null;
    _messages = [];
    _pendingAttachments = [];
    notifyListeners();
  }
}
