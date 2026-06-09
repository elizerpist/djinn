import 'ai_client.dart';
import 'ai_provider.dart';

typedef AiClientForProvider = AiClient Function(AiProvider provider);
typedef HasApiKeyForProvider = Future<bool> Function(AiProvider provider);
