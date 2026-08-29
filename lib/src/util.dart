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

/// Downloads a specific subfolder from a GitHub repository and extracts it locally.
///
/// [repoUrl] - Repository Url
/// [outputDir] - Local directory where files should be extracted
/// [ref] - Branch, tag, or commit hash (defaults to 'main')
Future<void> downloadAndExtractSubfolder({
  required String repoUrl,
  required Directory outputDir,
  String ref = 'main',
}) async {
  // 1. Construct GitHub zipball download URL
  final zipUrl = Uri.parse('$repoUrl/$ref');

  print('Downloading repository archive...');
  final response = await http.get(
    zipUrl,
    headers: {'Accept': 'application/vnd.github.v3+json'},
  );

  if (response.statusCode != 200) {
    throw Exception(
      'Failed to download archive: ${response.statusCode} - ${response.reasonPhrase}',
    );
  }

  // Decode the ZIP archive in memory
  final archive = ZipDecoder().decodeBytes(response.bodyBytes);
  //final extractDir = Directory(outputDir.path);

  // Extract files individually
  print('Extracting files...');
  for (final file in archive) {
    // Split relative path segments
    final parts = file.name.split('/');

    // Skip root folder segment
    if (parts.length > 1) {
      final relativePath = parts.sublist(1).join('/');
      if (relativePath.isEmpty) continue;

      final fullPath = '${outputDir.path}/$relativePath';

      if (file.isFile) {
        final outFile = File(fullPath);
        outFile.createSync(recursive: true);
        outFile.writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(fullPath).createSync(recursive: true);
      }
    }
  }
  print('Extraction complete!');
}
