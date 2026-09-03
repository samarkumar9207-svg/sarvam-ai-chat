/// Sarvam AI API service.
///
/// Handles:
/// - Text chat completions via /v1/chat/completions (sarvam-105b)
/// - Vision (image) chat via /v2/chat/completions (gemma4)
/// - Document AI OCR via /doc-ai/v1/digitise (sarvam-vision)
///
/// API reference: https://docs.sarvam.ai

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/chat_message.dart';

class SarvamApiException implements Exception {
  final String message;
  final int? statusCode;
  SarvamApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'SarvamApiException: $message (code: $statusCode)';
}

class SarvamApiService {
  String apiKey;

  SarvamApiService({required this.apiKey});

  /// Send a chat completion request.
  ///
  /// If [messages] contain image attachments, the request is routed to
  /// the /v2/chat/completions endpoint with the gemma4 model.
  /// Otherwise, /v1/chat/completions with sarvam-105b is used.
  ///
  /// Returns the assistant's text response.
  Future<String> chat({
    required List<ChatMessage> messages,
    String? model,
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
  }) async {
    if (apiKey.isEmpty) {
      throw SarvamApiException('API key is not set. Please add your Sarvam AI API key in Settings.');
    }

    // Build the messages array for the API.
    final apiMessages = <Map<String, dynamic>>[];

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      apiMessages.add({'role': 'system', 'content': systemPrompt});
    }

    // Check if any user message has image attachments → use vision endpoint.
    bool hasImages = messages.any((m) => m.hasImages);

    for (final msg in messages) {
      apiMessages.add(msg.toApiJson());
    }

    final String endpoint;
    final String useModel;

    if (hasImages) {
      endpoint = ApiConfig.visionChatEndpoint;
      useModel = model ?? ApiConfig.defaultVisionModel;
    } else {
      endpoint = ApiConfig.chatEndpoint;
      useModel = model ?? ApiConfig.defaultChatModel;
    }

    final body = <String, dynamic>{
      'model': useModel,
      'messages': apiMessages,
    };

    if (temperature != null) body['temperature'] = temperature;
    if (maxTokens != null) body['max_tokens'] = maxTokens;

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    try {
      final response = await http.post(
        url,
        headers: {
          'api-subscription-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(Duration(seconds: ApiConfig.requestTimeoutSeconds));

      if (response.statusCode != 200) {
        String errMsg;
        try {
          final errorBody = jsonDecode(response.body);
          errMsg = errorBody['error']?['message'] ??
              errorBody['message'] ??
              response.body;
        } catch (_) {
          errMsg = response.body;
        }
        throw SarvamApiException(errMsg, response.statusCode);
      }

      final data = jsonDecode(response.body);

      // OpenAI-compatible response format: choices[0].message.content
      final content = data['choices']?[0]?['message']?['content'];
      if (content == null) {
        throw SarvamApiException('Unexpected response format: no content in response.');
      }

      return content as String;
    } on SarvamApiException {
      rethrow;
    } catch (e) {
      throw SarvamApiException('Network error: $e');
    }
  }

  /// Extract text from a PDF or image using Sarvam Vision Document AI.
  ///
  /// Returns the extracted text (markdown format).
  Future<String> extractDocument({
    required Attachment attachment,
    String language = ApiConfig.defaultDocLanguage,
  }) async {
    if (apiKey.isEmpty) {
      throw SarvamApiException('API key is not set.');
    }

    if (attachment.base64Data == null) {
      throw SarvamApiException('Attachment has no data.');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.docAiEndpoint}');

    // Determine mime type for the multipart upload.
    String mimeType = attachment.mimeType ?? 'application/octet-stream';
    if (attachment.type == AttachmentType.image) {
      mimeType = attachment.mimeType ?? 'image/png';
    } else if (attachment.type == AttachmentType.pdf) {
      mimeType = 'application/pdf';
    }

    final request = http.MultipartRequest('POST', url);
    request.headers['api-subscription-key'] = apiKey;

    request.fields['language'] = language;
    request.fields['output_format'] = 'md';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        base64Decode(attachment.base64Data!),
        filename: attachment.fileName,
      ),
    );

    try {
      final streamedResponse = await request.send().timeout(
        Duration(seconds: ApiConfig.requestTimeoutSeconds),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw SarvamApiException(
          'Document AI failed: ${response.body}',
          response.statusCode,
        );
      }

      // The response contains extracted text.
      final data = jsonDecode(response.body);

      // Try multiple possible response shapes.
      final extracted = data['output'] ??
          data['text'] ??
          data['content'] ??
          data['markdown'] ??
          data['result'];

      if (extracted != null) {
        return extracted.toString();
      }

      // If the response is a ZIP (for md format), we just return the raw text.
      // For simplicity, request JSON output format.
      return data.toString();
    } catch (e) {
      if (e is SarvamApiException) rethrow;
      throw SarvamApiException('Document AI error: $e');
    }
  }

  /// Validate the API key by making a minimal chat request.
  Future<bool> validateApiKey() async {
    try {
      final result = await chat(
        messages: [
          ChatMessage(
            id: 'test',
            conversationId: 'test',
            role: 'user',
            content: 'Hi',
            createdAt: DateTime.now(),
          ),
        ],
        maxTokens: 5,
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
