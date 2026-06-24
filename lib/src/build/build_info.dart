class BuildInfo {
  const BuildInfo._();

  static const sha = String.fromEnvironment('DJINN_BUILD_SHA');
  static const ref = String.fromEnvironment('DJINN_BUILD_REF');
  static const runId = String.fromEnvironment('DJINN_BUILD_RUN_ID');

  static String get shortSha {
    if (sha.length <= 7) {
      return sha;
    }
    return sha.substring(0, 7);
  }

  static String get debugSummary {
    final displaySha = shortSha.isEmpty ? 'unknown' : shortSha;
    final displayRef = ref.isEmpty ? 'local' : ref;
    final displayRun = runId.isEmpty ? 'local' : runId;
    return 'sha=$displaySha ref=$displayRef run=$displayRun';
  }
}
