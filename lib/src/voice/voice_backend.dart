export 'speech_adapter.dart'
    show
        FakeSpeechAdapter,
        PluginSpeechRecognitionEngine,
        SpeechAdapter,
        SpeechErrorEvent,
        SpeechEvent,
        SpeechRecognitionEngine,
        SpeechResultEvent,
        SpeechStatusEvent,
        SpeechToTextAdapter;

typedef VoiceBackend = SpeechAdapter;
typedef VoiceBackendEvent = SpeechEvent;
