import '../../../core/network/api_client.dart';

class PreferencesModel {
  PreferencesModel({
    required this.assistantName,
    required this.wakeWord,
    required this.language,
    required this.voice,
    required this.voiceVerificationEnabled,
    required this.theme,
    required this.aiProvider,
    this.aiModel,
  });

  final String assistantName;
  final String wakeWord;
  final String language;
  final String voice;
  final bool voiceVerificationEnabled;
  final String theme;
  final String aiProvider;
  final String? aiModel;

  factory PreferencesModel.fromJson(Map<String, dynamic> json) => PreferencesModel(
        assistantName: json['assistantName'],
        wakeWord: json['wakeWord'],
        language: json['language'],
        voice: json['voice'],
        voiceVerificationEnabled: json['voiceVerificationEnabled'],
        theme: json['theme'],
        aiProvider: json['aiProvider'],
        aiModel: json['aiModel'],
      );

  PreferencesModel copyWith({
    String? assistantName,
    String? wakeWord,
    bool? voiceVerificationEnabled,
    String? theme,
    String? aiProvider,
  }) =>
      PreferencesModel(
        assistantName: assistantName ?? this.assistantName,
        wakeWord: wakeWord ?? this.wakeWord,
        language: language,
        voice: voice,
        voiceVerificationEnabled: voiceVerificationEnabled ?? this.voiceVerificationEnabled,
        theme: theme ?? this.theme,
        aiProvider: aiProvider ?? this.aiProvider,
        aiModel: aiModel,
      );
}

class PreferencesRepository {
  PreferencesRepository(this._api);
  final ApiClient _api;

  Future<PreferencesModel> get() {
    return _api.request(
      () => _api.raw.get('/preferences'),
      (data) => PreferencesModel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<PreferencesModel> update(Map<String, dynamic> patch) {
    return _api.request(
      () => _api.raw.patch('/preferences', data: patch),
      (data) => PreferencesModel.fromJson(data as Map<String, dynamic>),
    );
  }
}
