import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dcli/dcli.dart' as dcli;
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';

import '../random_string.dart' as rs;
import '../util.dart';
import 'commands.dart';

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
    var boilerplate = await _cloneRepo(projectDir);

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
    var oldName = (await loadPubspec(projectDir)).name;
    if (oldName != name) {
      print('Renaming project from "$oldName" to "$name"...');
      await renamePubspec(projectDir, oldName, name);
      await renameDartFiles(projectDir, oldName, name);
    }

    var pubGetSucceeded = false;
    if (argResults!['pub-get'] != false && argResults!['offline'] == false) {
      print('Now running dart pub get...');
      pubGetSucceeded = await _pubGet(projectDir);
    }

    if (boilerplate.needsPrebuild) {
      if (pubGetSucceeded) {
        try {
          await preBuild(projectDir);
        } catch (e) {
          print(yellow.wrap('Warning: $e Run `dart run build_runner build`.'));
        }
      } else {
        print(
          yellow.wrap(
            'Skipped code generation. Run `dart pub get` and then '
            '`dart run build_runner build`.',
          ),
        );
      }
    }

    print(green.wrap('$checkmark Successfully initialized Angel3 project.'));

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

  Future<BoilerplateInfo> _cloneRepo(Directory projectDir) async {
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

      // Save the templates locally on the system.
      var boilerplateRootDir = Directory(p.join(angelDir.path, 'boilerplates'));
      var boilerplateDir = Directory(
        p.join(boilerplateRootDir.path, boilerplate.subfolderPath),
      );
      var isCached = await boilerplateDir.exists();

      if (argResults!['offline'] as bool) {
        if (!isCached) {
          throw Exception(
            '--offline was selected, but the "${boilerplate.name}" template has not yet been downloaded.',
          );
        }
        print(
          'Using cached "${boilerplate.name}" template from "${boilerplateDir.path}".',
        );
      } else {
        // Always fetch the latest template when online, falling back to the
        // cached copy if the download fails.
        print(
          'Downloading "${boilerplate.name}" template from "${boilerplate.url}"...',
        );
        try {
          await downloadAndExtractSubfolder(
            repoUrl: boilerplate.url,
            subfolder: boilerplate.subfolderPath,
            outputDir: boilerplateDir,
            ref: boilerplate.ref,
          );
        } catch (e) {
          if (!isCached) rethrow;
          print(
            yellow.wrap(
              'Warning: $e\nUsing cached "${boilerplate.name}" template from "${boilerplateDir.path}".',
            ),
          );
        }
      }

      // Copy the required template into the given directory.
      await copyDirectory(boilerplateDir, projectDir);
      return boilerplate;
    } catch (e) {
      if (e is! String) {
        print(dcli.red('$ballot Could not initialize Angel3 project.'));
      }
      rethrow;
    }
  }

  Future<bool> _pubGet(Directory projectDir) async {
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
    return code == 0;
  }
}

Future<void> preBuild(Directory projectDir) async {
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
  needsPrebuild: true,
);

const BoilerplateInfo ormBoilerplate = BoilerplateInfo(
  'ORM for PostgreSQL',
  'A starter application with ORM support for PostgreSQL.',
  repoLocation,
  'templates/basic_postgres_orm',
  ref: 'master',
  needsPrebuild: true,
);

const BoilerplateInfo ormMySqlBoilerplate = BoilerplateInfo(
  'ORM for MySQL/MariaDB',
  'A starter application with ORM support for MySQL/MariaDB.',
  repoLocation,
  'templates/basic_mysql_orm',
  ref: 'master',
  needsPrebuild: true,
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
    this.ref = 'master',
    this.needsPrebuild = false,
  });

  @override
  String toString() => '$name ($description)';
}
