enum AiProvider {
  openAi('openai', 'OpenAI'),
  gemini('gemini', 'Gemini');

  const AiProvider(this.wireName, this.label);

  final String wireName;
  final String label;

  static AiProvider fromWireName(String? value) {
    return AiProvider.values.firstWhere(
      (provider) => provider.wireName == value,
      orElse: () => AiProvider.openAi,
    );
  }
}

enum AiModelSlot {
  answer('answer'),
  extraction('extraction'),
  groundedness('groundedness'),
  embedding('embedding');

  const AiModelSlot(this.wireName);

  final String wireName;
}
