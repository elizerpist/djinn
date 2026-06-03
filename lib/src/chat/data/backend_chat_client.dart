import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_citation.dart';

class BackendChatException implements Exception {
  BackendChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendChatResponse {
  const BackendChatResponse({
    required this.conversationId,
    required this.answer,
    required this.status,
    required this.citations,
    this.refusalReason,
  });

  final String conversationId;
  final String answer;
  final String status;
  final List<ChatCitation> citations;
  final String? refusalReason;

  factory BackendChatResponse.fromJson(Map<String, Object?> json) {
    final citations = (json['citations'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ChatCitation.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
    return BackendChatResponse(
      conversationId: json['conversation_id'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      status: json['status'] as String? ?? 'insufficient_evidence',
      citations: citations,
      refusalReason: json['refusal_reason'] as String?,
    );
  }
}

class BackendChatClient {
  BackendChatClient({required Uri baseUri, http.Client? client})
    : _baseUri = baseUri,
      _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Future<BackendChatResponse> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/chat'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'conversation_id': conversationId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendChatException('backend chat failed: ${response.statusCode}');
    }
    return BackendChatResponse.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }
}
