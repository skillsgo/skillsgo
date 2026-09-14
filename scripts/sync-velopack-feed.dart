/*
 * [INPUT]: Depends on a public HTTPS Velopack channel directory, its releases manifest, Dart HTTP/JSON support, and an output directory.
 * [OUTPUT]: Downloads the prior releases manifest and every referenced safe package filename, treating a missing manifest as an initial release.
 * [POS]: Serves as the credential-free historical-feed hydration step before protected App release packaging.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    stderr.writeln(
      'Usage: dart scripts/sync-velopack-feed.dart '
      '<https-directory> <channel> <output-directory>',
    );
    exitCode = 64;
    return;
  }

  final source = Uri.tryParse(arguments[0]);
  final channel = arguments[1];
  final output = Directory(arguments[2]);
  if (source == null ||
      source.scheme != 'https' ||
      source.host.isEmpty ||
      source.userInfo.isNotEmpty ||
      source.hasQuery ||
      source.hasFragment ||
      !source.path.endsWith('/') ||
      !RegExp(r'^[a-z0-9-]+$').hasMatch(channel)) {
    throw FormatException('The Velopack source or channel is invalid.');
  }

  final client = HttpClient();
  try {
    final manifestName = 'releases.$channel.json';
    final manifestUri = source.resolve(manifestName);
    final manifestResponse = await (await client.getUrl(manifestUri)).close();
    if (manifestResponse.statusCode == HttpStatus.notFound) {
      stdout.writeln(
        'No prior $channel feed exists; preparing initial release.',
      );
      return;
    }
    if (manifestResponse.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Unable to download prior feed (${manifestResponse.statusCode}).',
        uri: manifestUri,
      );
    }

    final manifestBytes = await manifestResponse.fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final manifest = jsonDecode(utf8.decode(manifestBytes));
    if (manifest is! Map<String, Object?> || manifest['Assets'] is! List) {
      throw const FormatException('Velopack release manifest is malformed.');
    }

    await output.create(recursive: true);
    await File.fromUri(
      output.uri.resolve(manifestName),
    ).writeAsBytes(manifestBytes, flush: true);
    final filenames = <String>{};
    for (final rawAsset in manifest['Assets']! as List) {
      if (rawAsset is! Map<String, Object?> ||
          rawAsset['FileName'] is! String) {
        throw const FormatException('Velopack release asset is malformed.');
      }
      final filename = rawAsset['FileName']! as String;
      final segments = Uri(path: filename).pathSegments;
      if (filename.isEmpty ||
          segments.length != 1 ||
          filename != segments.single ||
          filename.contains('\\')) {
        throw FormatException('Unsafe Velopack package filename: $filename');
      }
      filenames.add(filename);
    }

    for (final filename in filenames) {
      final packageUri = source.resolve(Uri.encodeComponent(filename));
      final response = await (await client.getUrl(packageUri)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Unable to download $filename (${response.statusCode}).',
          uri: packageUri,
        );
      }
      final file = File.fromUri(output.uri.resolve(filename));
      final sink = file.openWrite();
      await response.pipe(sink);
      stdout.writeln('Downloaded prior Velopack asset: $filename');
    }
  } finally {
    client.close(force: true);
  }
}
