/*
 * [INPUT]: Depends on one candidate production App update directory URL.
 * [OUTPUT]: Prints its normalized public HTTPS directory or exits with a format error.
 * [POS]: Serves as release CI's direct reuse of the App's production update-source policy.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import '../app/lib/infrastructure/app_update_source.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    throw const FormatException('Expected exactly one App update URL.');
  }
  final source = appUpdateProductionSource(arguments.single);
  if (source == null) {
    throw const FormatException('The App update URL must not be empty.');
  }
  print(source);
}
