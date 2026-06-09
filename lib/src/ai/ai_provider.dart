enum AiProvider {
  openai('openai'),
  google('google');

  const AiProvider(this.wireName);

  final String wireName;

  String get defaultAnswerModel {
    return switch (this) {
      AiProvider.openai => 'gpt-5.5',
      AiProvider.google => 'gemini-2.5-flash',
    };
  }

  String get defaultExtractionModel {
    return switch (this) {
      AiProvider.openai => 'gpt-5.5',
      AiProvider.google => 'gemini-2.5-flash',
    };
  }

  String get defaultGroundednessModel {
    return switch (this) {
      AiProvider.openai => 'gpt-5.5',
      AiProvider.google => 'gemini-2.5-flash',
    };
  }

  String get defaultEmbeddingModel {
    return switch (this) {
      AiProvider.openai => 'text-embedding-3-large',
      AiProvider.google => 'gemini-embedding-001',
    };
  }

  static AiProvider fromWireName(String? value) {
    for (final provider in AiProvider.values) {
      if (provider.wireName == value) {
        return provider;
      }
    }
    return AiProvider.openai;
  }
}
