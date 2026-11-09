// Computes line coverage of domain + BLoC layers from coverage/lcov.info.
// Usage: dart run tool/coverage.dart [minPercent]
import 'dart:io';

void main(List<String> args) {
  final min = args.isEmpty ? 70.0 : double.parse(args.first);
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('coverage/lcov.info not found. Run: flutter test --coverage');
    exit(2);
  }
  bool inScope(String path) {
    final p = path.replaceAll(r'\', '/');
    if (p.endsWith('.g.dart') || p.endsWith('.freezed.dart')) return false;
    return p.contains('/domain/') || p.contains('/presentation/bloc/');
  }

  var found = 0;
  var hit = 0;
  String? current;
  final perFile = <String, List<int>>{};
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) current = line.substring(3);
    if (current == null || !inScope(current)) continue;
    if (line.startsWith('DA:')) {
      final count = int.parse(line.split(',')[1]);
      found++;
      if (count > 0) hit++;
      final stats = perFile.putIfAbsent(current, () => [0, 0]);
      stats[0]++;
      if (count > 0) stats[1]++;
    }
  }
  final pct = found == 0 ? 0 : hit * 100 / found;
  final sorted = perFile.entries.toList()
    ..sort((a, b) => (a.value[1] / a.value[0]).compareTo(b.value[1] / b.value[0]));
  for (final e in sorted.take(8)) {
    final p = e.value[1] * 100 / e.value[0];
    stdout.writeln(
      '${p.toStringAsFixed(1).padLeft(6)}%  ${e.key.replaceAll(r'\', '/').split('lib/').last}',
    );
  }
  stdout.writeln('Domain + BLoC coverage: ${pct.toStringAsFixed(1)}% ($hit/$found lines)');
  if (pct < min) {
    stderr.writeln('Coverage is below $min%');
    exit(1);
  }
}
