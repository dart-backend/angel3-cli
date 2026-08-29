import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:args/command_runner.dart';
import 'package:dcli/dcli.dart' as dcli;
import 'package:http/http.dart' as http;
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'package:prompts/prompts.dart' as prompts;

import '../util.dart';
import 'key.dart';

class InitCommand extends Command {
  final KeyCommand _key = KeyCommand();

  @override
  String get name => 'init';

  @override
  String get description =>
      'Initializes a new Angel3 project in the current directory.';

  InitCommand() {
    argParser
      ..addFlag(
        'offline',
        help:
            'Disable online fetching of boilerplates. Also disables `pub-get`.',
        negatable: false,
      )
      ..addFlag('pub-get', defaultsTo: true)
      ..addOption(
        'project-name',
        abbr: 'n',
        help: 'The name for this project.',
      );
  }

  @override
  void run() async {
    if (argResults == null) {
      print('Invalid arguements');
      return;
    }

    var projectDir = Directory(
      argResults!.rest.isEmpty ? '.' : argResults!.rest[0],
    );
    print('Creating new Angel3 project in ${projectDir.absolute.path}...');
    await _cloneRepo(projectDir);

    /*
    // await preBuild(projectDir);
    var secret = rs.randomAlphaNumeric(32);
    print('Generated new development JWT secret: $secret');
    await _key.changeSecret(
      File.fromUri(projectDir.uri.resolve('config/default.yaml')),
      secret,
    );

    secret = rs.randomAlphaNumeric(32);
    print('Generated new production JWT secret: $secret');
    await _key.changeSecret(
      File.fromUri(projectDir.uri.resolve('config/production.yaml')),
      secret,
    );

    var name = argResults!.wasParsed('project-name')
        ? (argResults!['project-name'] as String)
        : p.basenameWithoutExtension(
            projectDir.absolute.uri.normalizePath().toFilePath(),
          );

    name = ReCase(name).snakeCase;
    print('Renaming project from "starter_app" to "$name"...');
    await renamePubspec(projectDir, 'starter_app', name);
    await renameDartFiles(projectDir, 'starter_app', name);
    // Renaming executable files

    if (argResults!['pub-get'] != false && argResults!['offline'] == false) {
      print('Now running dart pub get...');
      await _pubGet(projectDir);
    }

    print(green.wrap('$checkmark Successfully initialized Angel3 project.'));
 */
    stdout
      ..writeln()
      ..writeln(
        'Congratulations! You are ready to start developing with Angel3!',
      )
      ..write('To start the server (with ')
      ..write(cyan.wrap('hot-reloading'))
      ..write('), run ')
      ..write(magenta.wrap('`dart --observe bin/dev.dart`'))
      ..writeln(' in your terminal.')
      ..writeln()
      ..writeln('Find more documentation about Angel3:')
      ..writeln('  * https://angel3-framework.web.app')
      ..writeln('  * https://angel3-docs.dukefirehawk.com')
      //      ..writeln(
      //          '  * https://www.youtube.com/playlist?list=PLl3P3tmiT-frEV50VdH_cIrA2YqIyHkkY')
      //      ..writeln('  * https://medium.com/the-angel-framework')
      //      ..writeln('  * https://dart.academy/tag/angel')
      ..writeln()
      ..writeln('Happy coding!');
  }

  Future _deleteRecursive(FileSystemEntity entity, [bool self = true]) async {
    if (entity is Directory) {
      await for (var entity in entity.list(recursive: true)) {
        try {
          await _deleteRecursive(entity);
        } catch (e) {
          print(e);
        }
      }

      try {
        if (self != false) await entity.delete(recursive: true);
      } catch (e) {
        print(e);
      }
    } else if (entity is File) {
      try {
        await entity.delete(recursive: true);
      } catch (e) {
        print(e);
      }
    } else if (entity is Link) {
      var path = await entity.resolveSymbolicLinks();
      var stat = await FileStat.stat(path);

      switch (stat.type) {
        case FileSystemEntityType.directory:
          return await _deleteRecursive(Directory(path));
        case FileSystemEntityType.file:
          return await _deleteRecursive(File(path));
        default:
          break;
      }
    }
  }

  Future _cloneRepo(Directory projectDir) async {
    //Directory boilerplateDir = Directory("./empty");
    try {
      if (await projectDir.exists()) {
        bool shouldDelete = dcli.confirm(
          "Directory '${projectDir.absolute.path}' already exists. Overwrite it?",
        );

        if (!shouldDelete) {
          throw 'Chose not to overwrite existing directory.';
        } else if (projectDir.absolute.uri.normalizePath().toFilePath() !=
            Directory.current.absolute.uri.normalizePath().toFilePath()) {
          await projectDir.delete(recursive: true);
        } else {
          await _deleteRecursive(projectDir, false);
        }
      }

      var boilerplate = dcli.menu(
        'Choose a project type before continuing:',
        options: boilerplates,
        defaultOption: basicBoilerplate,
      );

      // Ultimately, we want a clone of every boilerplate locally on the system.
      var boilerplateRootDir = Directory(p.join(angelDir.path, 'boilerplates'));
      //var boilerplateBasename = p.basenameWithoutExtension(boilerplate.url);
      //if (boilerplate.ref != '') {
      //  boilerplateBasename += '.${boilerplate.ref}';
      //}

      await boilerplateRootDir.create(recursive: true);

      var boilerplateDir = Directory(
        p.join(boilerplateRootDir.path, boilerplate.subfolderPath),
      );
      if (!await boilerplateDir.exists()) {
        if (argResults!['offline'] as bool) {
          throw Exception(
            '--offline was selected, but the "${boilerplate.name}" boilerplate has not yet been downloaded.',
          );
        }

        print(
          'Downloading "${boilerplate.name}" boilerplate from "${boilerplate.url}"...',
        );

        await downloadAndExtractSubfolder(
          repoUrl: boilerplate.url,
          outputDir: boilerplateRootDir,
          ref: boilerplate.ref,
        );
      } else {
        print(
          'Using cached "${boilerplate.name}" boilerplate from "${boilerplateRootDir.path}".',
        );
      }
    } catch (e) {
      //if (await boilerplateDir.exists()) {
      //  await boilerplateDir.delete(recursive: true);
      //}

      if (e is! String) {
        print(dcli.red('$ballot Could not initialize Angel3 project.'));
      }
      rethrow;
    }
  }

  Future _cloneRepoOri(Directory projectDir) async {
    Directory boilerplateDir = Directory("./empty");

    try {
      if (await projectDir.exists()) {
        var shouldDelete = prompts.getBool(
          "Directory '${projectDir.absolute.path}' already exists. Overwrite it?",
        );

        if (!shouldDelete) {
          throw 'Chose not to overwrite existing directory.';
        } else if (projectDir.absolute.uri.normalizePath().toFilePath() !=
            Directory.current.absolute.uri.normalizePath().toFilePath()) {
          await projectDir.delete(recursive: true);
        } else {
          await _deleteRecursive(projectDir, false);
        }
      }

      // var boilerplate = basicBoilerplate;
      print('Choose a project type before continuing:');

      var boilerplate =
          prompts.choose(
            'Choose a project type before continuing',
            boilerplates,
          ) ??
          basicBoilerplate;

      // Ultimately, we want a clone of every boilerplate locally on the system.
      var boilerplateRootDir = Directory(p.join(angelDir.path, 'boilerplates'));
      var boilerplateBasename = p.basenameWithoutExtension(boilerplate.url);
      if (boilerplate.ref != '') {
        boilerplateBasename += '.${boilerplate.ref}';
      }
      boilerplateDir = Directory(
        p.join(boilerplateRootDir.path, boilerplateBasename),
      );
      await boilerplateRootDir.create(recursive: true);

      var branch = boilerplate.ref;
      if (branch == '') {
        branch = 'master';
      }

      // If there is no clone existing, clone it.
      if (!await boilerplateDir.exists()) {
        if (argResults!['offline'] as bool) {
          throw Exception(
            '--offline was selected, but the "${boilerplate.name}" boilerplate has not yet been downloaded.',
          );
        }

        print(
          'Cloning "${boilerplate.name}" boilerplate from "${boilerplate.url}"...',
        );
        Process git;

        if (boilerplate.ref == '') {
          print(
            darkGray.wrap(
              '\$ git clone --depth 1 ${boilerplate.url} ${boilerplateDir.absolute.path}',
            ),
          );
          git = await Process.start('git', [
            'clone',
            '--depth',
            '1',
            boilerplate.url,
            boilerplateDir.absolute.path,
          ], mode: ProcessStartMode.inheritStdio);
        } else {
          // git clone --single-branch -b branch host:/dir.git
          print(
            darkGray.wrap(
              '\$ git clone --depth 1 --single-branch -b ${boilerplate.ref} ${boilerplate.url} ${boilerplateDir.absolute.path}',
            ),
          );
          git = await Process.start('git', [
            'clone',
            '--depth',
            '1',
            '--single-branch',
            '-b',
            boilerplate.ref,
            boilerplate.url,
            boilerplateDir.absolute.path,
          ], mode: ProcessStartMode.inheritStdio);
        }

        if (await git.exitCode != 0) {
          throw Exception('Could not clone repo.');
        }
      }
      // Otherwise, pull from git.
      else if (!(argResults!['offline'] as bool)) {
        print(darkGray.wrap('\$ git pull origin $branch'));
        var git = await Process.start(
          'git',
          ['pull', 'origin', branch],
          mode: ProcessStartMode.inheritStdio,
          workingDirectory: boilerplateDir.absolute.path,
        );
        if (await git.exitCode != 0) {
          print(
            yellow.wrap(
              'Update of $branch failed. Attempting to continue with existing contents.',
            ),
          );
        }
      } else {
        print(
          darkGray.wrap(
            'Using existing contents of "${boilerplate.name}" boilerplate.',
          ),
        );
      }

      // Next, just copy everything into the given directory.
      await copyDirectory(boilerplateDir, projectDir);

      if (boilerplate.needsPrebuild) {
        await preBuild(projectDir).catchError((_) => null);
      }

      var gitDir = Directory.fromUri(projectDir.uri.resolve('.git'));
      if (await gitDir.exists()) await gitDir.delete(recursive: true);
    } catch (e) {
      await boilerplateDir.delete(recursive: true);
      //await boilerplateDir.delete(recursive: true).catchError((e) {
      //  print('Got error: ${e.error}');
      //});

      if (e is! String) {
        print(red.wrap('$ballot Could not initialize Angel3 project.'));
      }
      rethrow;
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

  Future _pubGet(Directory projectDir) async {
    var dartPath = "dart";
    print(darkGray.wrap('Running "$dartPath"...'));
    print(darkGray.wrap('\$ $dartPath pub get'));
    var dart = await Process.start(
      dartPath,
      ['pub', 'get'],
      workingDirectory: projectDir.absolute.path,
      mode: ProcessStartMode.inheritStdio,
    );
    var code = await dart.exitCode;
    print('Dart process exited with code $code');
  }
}

Future preBuild(Directory projectDir) async {
  // Run build
  // print('Running `dart run build_runner build`...');
  print(darkGray.wrap('\$ dart run build_runner build'));

  var build = await Process.start(
    "dart",
    ['run', 'build_runner', 'build'],
    workingDirectory: projectDir.absolute.path,
    mode: ProcessStartMode.inheritStdio,
  );

  var buildCode = await build.exitCode;

  if (buildCode != 0) throw Exception('Failed to pre-build resources.');
}

const repoLocation =
    'https://api.github.com/repos/dart-backend/boilerplates/zipball';

const BoilerplateInfo graphQLBoilerplate = BoilerplateInfo(
  'GraphQL',
  'A starter application with GraphQL support.',
  repoLocation,
  'templates/basic_graphql',
  ref: 'master',
);

const BoilerplateInfo ormBoilerplate = BoilerplateInfo(
  'ORM for PostgreSQL',
  'A starter application with ORM support for PostgreSQL.',
  repoLocation,
  'templates/basic_postgres_orm',
  ref: 'master',
);

const BoilerplateInfo ormMySqlBoilerplate = BoilerplateInfo(
  'ORM for MySQL/MariaDB',
  'A starter application with ORM support for MySQL/MariaDB.',
  repoLocation,
  'templates/basic_mysql_orm',
  ref: 'master',
);

const BoilerplateInfo basicBoilerplate = BoilerplateInfo(
  'Basic',
  'A basic starter application.',
  repoLocation,
  'templates/basic',
  ref: 'master',
);

const List<BoilerplateInfo> boilerplates = [
  basicBoilerplate,
  ormBoilerplate,
  ormMySqlBoilerplate,
  graphQLBoilerplate,
];

class BoilerplateInfo {
  final String name, description, url;
  final String ref;
  final bool needsPrebuild;
  final String subfolderPath;

  const BoilerplateInfo(
    this.name,
    this.description,
    this.url,
    this.subfolderPath, {
    this.ref = '',
    this.needsPrebuild = false,
  });

  @override
  String toString() => '$name ($description)';
}
