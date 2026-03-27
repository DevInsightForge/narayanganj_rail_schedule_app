Uri? resolveScheduleUriFromManifest({
  required Uri manifestUri,
  required String latestPath,
}) {
  final candidate = latestPath.trim();
  if (candidate.isEmpty) {
    return null;
  }

  final parsed = Uri.tryParse(candidate);
  if (parsed != null && parsed.hasScheme) {
    if (parsed.scheme == 'http' || parsed.scheme == 'https') {
      return parsed;
    }
    return null;
  }

  if (candidate.startsWith('/')) {
    return manifestUri.resolveUri(Uri(path: candidate));
  }

  return manifestUri.resolve(candidate);
}
