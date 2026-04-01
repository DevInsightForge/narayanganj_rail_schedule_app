class AttemptIdFactory {
  AttemptIdFactory({DateTime Function()? nowProvider})
    : _nowProvider = nowProvider ?? DateTime.now;

  final DateTime Function() _nowProvider;
  int _sequence = 0;

  String next() {
    _sequence += 1;
    return '${_nowProvider().microsecondsSinceEpoch.toRadixString(16)}-${_sequence.toRadixString(16)}';
  }
}
