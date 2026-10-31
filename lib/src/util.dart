import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';

//import 'package:yamlicious/yamlicious.dart';

final String checkmark = ansiOutputEnabled ? '\u2714' : '[Success]';

final String ballot = ansiOutputEnabled ? '\u2717' : '[Failure]';

String get homeDirPath =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';

Directory get homeDir => Directory(homeDirPath);

Directory get angelDir => Directory(p.join(homeDir.path, '.angel3'));

Future<Pubspec> loadPubspec([Directory? directory]) {
  directory ??= Directory.current;
  var file = File.fromUri(directory.uri.resolve('pubspec.yaml'));
  return file.readAsString().then(
    (yaml) => Pubspec.parse(yaml, sourceUrl: file.uri),
  );
}

Future<void> copyDirectory(Directory source, Directory destination) async {
  // if (!topLevel) stdout.write('\r');
  // print(darkGray
  //     .wrap('Copying dir "${source.path}" -> "${destination.path}..."'));

  await for (var entity in source.list(recursive: false)) {
    if (p.basename(entity.path) == '.git') continue;
    if (entity is Directory) {
      var newDirectory = Directory(
        p.join(destination.absolute.path, p.basename(entity.path)),
      );
      await newDirectory.create(recursive: true);
      await copyDirectory(entity.absolute, newDirectory);
    } else if (entity is File) {
      var newPath = p.join(destination.path, p.basename(entity.path));
      // print(darkGray.wrap('\rCopying file "${entity.path}" -> "$newPath"'));
      await File(newPath).create(recursive: true);
      await entity.copy(newPath);
    }
  }

  // print('\rCopied "${source.path}" -> "${destination.path}.');
}

Future savePubspec(Pubspec pubspec) async {
  // TODO: Save pubspec for real?
  //var text = toYamlString(pubspec);
}

Future<bool> runCommand(String exec, List<String> args) async {
  var s = '$exec ${args.join(' ')}'.trim();
  stdout.write(darkGray.wrap('Running `$s`... '));

  try {
    var p = await Process.start(exec, args);
    var code = await p.exitCode;

    if (code == 0) {
      print(green.wrap(checkmark));
      return true;
    } else {
      print(red.wrap(ballot));
      await stdout.addStream(p.stdout);
      await stderr.addStream(p.stderr);
      return false;
    }
  } catch (e) {
    print(red.wrap('$ballot Failed to run process.'));
    return false;
  }
}

/// Downloads [subfolder] of a GitHub repository and extracts it into [outputDir].
///
/// [repoUrl] - Repository zipball Url
/// [subfolder] - Path inside the repository to extract, e.g. `templates/basic`
/// [outputDir] - Local directory the subfolder's contents are extracted into
/// [ref] - Branch, tag, or commit hash (defaults to 'main')
///
/// Files are extracted into a staging directory next to [outputDir], which
/// only replaces [outputDir] once extraction succeeds. A failed or interrupted
/// download therefore never leaves a partial template behind.
Future<void> downloadAndExtractSubfolder({
  required String repoUrl,
  required String subfolder,
  required Directory outputDir,
  String ref = 'main',
}) async {
  if (ref.isEmpty) ref = 'main';

  // 1. Construct GitHub zipball download URL
  final zipUrl = Uri.parse('$repoUrl/$ref');
  final prefix = p.posix.split(p.posix.normalize(subfolder));

  final tempDir = await Directory.systemTemp.createTemp('angel3_');
  await outputDir.parent.create(recursive: true);
  final stagingDir = await outputDir.parent.createTemp(
    '.${p.basename(outputDir.path)}_',
  );

  try {
    // 2. Stream the archive to disk instead of buffering it in memory
    print('Downloading repository archive...');
    final zipFile = File(p.join(tempDir.path, 'repo.zip'));
    final client = http.Client();
    try {
      final request = http.Request('GET', zipUrl)
        ..headers['Accept'] = 'application/vnd.github+json';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download archive: ${response.statusCode} - ${response.reasonPhrase}',
        );
      }
      await response.stream.pipe(zipFile.openWrite());
    } finally {
      client.close();
    }

    // 3. Extract only the entries under the requested subfolder
    print('Extracting files...');
    final input = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      var found = false;

      for (final file in archive) {
        // Skip the root folder segment GitHub adds, e.g. `owner-repo-sha/`
        final parts = p.posix.split(file.name).skip(1).toList();
        if (parts.length <= prefix.length ||
            parts.take(prefix.length).join('/') != prefix.join('/')) {
          continue;
        }
        if (file.isSymbolicLink) continue;

        final fullPath = p.normalize(
          p.joinAll([stagingDir.path, ...parts.skip(prefix.length)]),
        );
        if (!p.isWithin(stagingDir.path, fullPath)) {
          throw Exception(
            'Refusing to extract "${file.name}" outside of ${outputDir.path}.',
          );
        }

        found = true;
        if (file.isFile) {
          final outFile = File(fullPath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content);
        } else {
          await Directory(fullPath).create(recursive: true);
        }
      }
      await archive.clear();

      if (!found) {
        throw Exception('"$subfolder" was not found in $zipUrl.');
      }
    } finally {
      await input.close();
    }

    // 4. Swap the finished extraction into place
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
    await stagingDir.rename(outputDir.path);
    print('Extraction complete!');
  } finally {
    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
    }
    await tempDir.delete(recursive: true);
  }
}
