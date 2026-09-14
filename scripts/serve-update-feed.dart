/*
 * [INPUT]: Depends on a Velopack release directory, a loopback port, and Dart's HTTP/filesystem libraries.
 * [OUTPUT]: Serves exact regular files from one release directory over loopback HTTP with traversal-safe path resolution.
 * [POS]: Serves as the zero-cost local update origin used only by packaged App update rehearsals in CI.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    stderr.writeln('Usage: dart serve-update-feed.dart <directory> <port>');
    exitCode = 64;
    return;
  }

  final root = Directory(arguments.first).absolute;
  final port = int.tryParse(arguments.last);
  if (!root.existsSync() || port == null || port < 1 || port > 65535) {
    stderr.writeln('Update feed directory or port is invalid.');
    exitCode = 64;
    return;
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Serving ${root.path} at http://127.0.0.1:$port/');
  await for (final request in server) {
    final segments = request.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty || segments.any((segment) => segment == '..')) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    final file = File([root.path, ...segments].join(Platform.pathSeparator));
    final resolved = file.absolute.path;
    final rootPrefix = '${root.path}${Platform.pathSeparator}';
    if (!resolved.startsWith(rootPrefix) || !await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      continue;
    }

    request.response.contentLength = await file.length();
    await request.response.addStream(file.openRead());
    await request.response.close();
  }
}
