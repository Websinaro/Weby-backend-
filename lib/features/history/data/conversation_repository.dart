import '../../../core/network/api_client.dart';

class ConversationSummary {
  ConversationSummary({required this.id, required this.title, required this.updatedAt});
  final String id;
  final String title;
  final DateTime updatedAt;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) => ConversationSummary(
        id: json['id'],
        title: json['title'],
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}

class MessageModel {
  MessageModel({required this.id, required this.role, required this.content, required this.createdAt});
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'],
        role: json['role'],
        content: json['content'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class ConversationRepository {
  ConversationRepository(this._api);
  final ApiClient _api;

  Future<List<ConversationSummary>> list({int page = 1, int limit = 20}) {
    return _api.request(
      () => _api.raw.get('/conversations', queryParameters: {'page': page, 'limit': limit}),
      (data) => (data['items'] as List)
          .map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<MessageModel>> messages(String conversationId, {int page = 1, int limit = 50}) {
    return _api.request(
      () => _api.raw.get(
        '/conversations/$conversationId/messages',
        queryParameters: {'page': page, 'limit': limit},
      ),
      (data) =>
          (data['items'] as List).map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<String> create({String? title}) {
    return _api.request(
      () => _api.raw.post('/conversations', data: {if (title != null) 'title': title}),
      (data) => data['id'] as String,
    );
  }

  Future<void> delete(String conversationId) {
    return _api.request(() => _api.raw.delete('/conversations/$conversationId'), (data) => data);
  }

  /// Sends a prompt to Weby's AI backend and returns the assistant's reply.
  Future<String> askAi(String prompt, {String? conversationId}) {
    return _api.request(
      () => _api.raw.post(
        '/ai/chat',
        data: {'prompt': prompt, if (conversationId != null) 'conversationId': conversationId},
      ),
      (data) => data['text'] as String,
    );
  }
}
