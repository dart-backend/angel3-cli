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
      ..addFlag(
        'refresh',
        help: 'Download the latest templates, even if the cached ones are recent.',
        negatable: false,
      )
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
    if (await _hasTemplateName(projectDir)) {
      if (name != templatePackageName) {
        print('Renaming project from "$templatePackageName" to "$name"...');
        await renamePubspec(projectDir, templatePackageName, name);
        await renameDartFiles(projectDir, templatePackageName, name);
      }
    } else {
      print(
        yellow.wrap(
          'Warning: The template\'s package is not named "$templatePackageName", '
          'so the project was not renamed. Run `angel3 rename` to rename it.',
        ),
      );
    }

    var pubGetSucceeded = false;
    if (argResults!['pub-get'] != false && argResults!['offline'] == false) {
      print('Now running dart pub get...');
      pubGetSucceeded = await _runDart(projectDir, ['pub', 'get']);
      if (!pubGetSucceeded) {
        print(
          yellow.wrap(
            'Warning: `dart pub get` failed. Run it in the project to retry.',
          ),
        );
      }
    }

    if (boilerplate.needsPrebuild) {
      if (pubGetSucceeded) {
        if (!await _runDart(projectDir, ['run', 'build_runner', 'build'])) {
          print(
            yellow.wrap(
              'Warning: Code generation failed. Run '
              '`dart run build_runner build` in the project to retry.',
            ),
          );
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
      var overwrite = false;
      if (await projectDir.exists()) {
        overwrite = dcli.confirm(
          "Directory '${projectDir.absolute.path}' already exists. Overwrite it?",
        );
        if (!overwrite) {
          throw 'Chose not to overwrite existing directory.';
        }
      }

      var boilerplate = dcli.menu(
        'Choose a project type before continuing:',
        options: boilerplates,
        defaultOption: basicBoilerplate,
      );

      // Find the template before deleting anything, so that the existing
      // directory is kept when no template is available.
      var boilerplateDir = await _fetchTemplate(boilerplate);

      if (overwrite) {
        if (projectDir.absolute.uri.normalizePath().toFilePath() !=
            Directory.current.absolute.uri.normalizePath().toFilePath()) {
          await projectDir.delete(recursive: true);
        } else {
          await _deleteRecursive(projectDir, false);
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

  /// The cached directory of [boilerplate], downloading the templates first
  /// unless the cache is recent, or `--offline` is given.
  ///
  /// All the templates are downloaded together, as they come in one archive of
  /// the repository, and cached in `~/.angel3/boilerplates/templates`.
  Future<Directory> _fetchTemplate(BoilerplateInfo boilerplate) async {
    var boilerplateRootDir = Directory(p.join(angelDir.path, 'boilerplates'));
    var templatesSubfolder = p.posix.dirname(boilerplate.subfolderPath);
    var templatesDir = Directory(
      p.join(boilerplateRootDir.path, templatesSubfolder),
    );
    var boilerplateDir = Directory(
      p.join(boilerplateRootDir.path, boilerplate.subfolderPath),
    );

    await recoverInterruptedSwap(templatesDir);
    var isCached = await boilerplateDir.exists();
    var isRecent = false;
    if (isCached) {
      // A time in the future, as after the clock was set back, is not recent.
      var age = DateTime.now().difference((await templatesDir.stat()).modified);
      isRecent = !age.isNegative && age < templateCacheMaxAge;
    }

    if (argResults!['offline'] as bool ||
        (isRecent && !(argResults!['refresh'] as bool))) {
      if (!isCached) {
        throw Exception(
          '--offline was selected, but the "${boilerplate.name}" template has not yet been downloaded.',
        );
      }
      print(
        'Using cached "${boilerplate.name}" template from "${boilerplateDir.path}". '
        'Run with --refresh to download the latest version.',
      );
      return boilerplateDir;
    }

    // Fetch the latest templates, falling back to the cached copy if the
    // download fails.
    print('Downloading templates from "${boilerplate.url}"...');
    try {
      await downloadAndExtractSubfolder(
        repoUrl: boilerplate.url,
        subfolder: templatesSubfolder,
        outputDir: templatesDir,
        ref: boilerplate.ref,
      );
      if (!await boilerplateDir.exists()) {
        throw Exception(
          '"${boilerplate.subfolderPath}" was not found in ${boilerplate.url}.',
        );
      }
    } catch (e) {
      if (!isCached || !await boilerplateDir.exists()) rethrow;
      print(
        yellow.wrap(
          'Warning: $e\nUsing cached "${boilerplate.name}" template from "${boilerplateDir.path}".',
        ),
      );
    }
    return boilerplateDir;
  }

  /// Whether the copied template's package still has its expected name.
  ///
  /// Read from the text, as `renamePubspec` replaces it, rather than parsed, so
  /// that a pubspec `pubspec_parse` rejects is still renamed. An error reading
  /// it is thrown rather than taken as another name.
  Future<bool> _hasTemplateName(Directory projectDir) async {
    var pubspecFile = File(p.join(projectDir.path, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) return false;
    return RegExp(
      '^name:\\s*${RegExp.escape(templatePackageName)}\\s*\$',
      multiLine: true,
    ).hasMatch(await pubspecFile.readAsString());
  }

  /// Runs `dart [args]` in [projectDir], returning whether it succeeded.
  Future<bool> _runDart(Directory projectDir, List<String> args) async {
    print(darkGray.wrap('\$ dart ${args.join(' ')}'));
    var dart = await Process.start(
      'dart',
      args,
      workingDirectory: projectDir.absolute.path,
      mode: ProcessStartMode.inheritStdio,
    );
    return await dart.exitCode == 0;
  }
}

/// The package name of every boilerplate template, replaced by `init`.
const templatePackageName = 'starter_app';

/// How long a downloaded template is reused before `init` downloads it again.
const templateCacheMaxAge = Duration(days: 1);

const repoLocation =
    'https://api.github.com/repos/dart-backend/boilerplates/zipball';

const BoilerplateInfo graphQLBoilerplate = BoilerplateInfo(
  'GraphQL',
  'A starter application with GraphQL support.',
  repoLocation,
  'templates/basic_graphql',
  needsPrebuild: true,
);

const BoilerplateInfo ormBoilerplate = BoilerplateInfo(
  'ORM for PostgreSQL',
  'A starter application with ORM support for PostgreSQL.',
  repoLocation,
  'templates/basic_postgres_orm',
  needsPrebuild: true,
);

const BoilerplateInfo ormMySqlBoilerplate = BoilerplateInfo(
  'ORM for MySQL/MariaDB',
  'A starter application with ORM support for MySQL/MariaDB.',
  repoLocation,
  'templates/basic_mysql_orm',
  needsPrebuild: true,
);

const BoilerplateInfo mongoBoilerplate = BoilerplateInfo(
  'MongoDB',
  'A starter application with a REST API of a MongoDB collection.',
  repoLocation,
  'templates/basic_mongo',
);

const BoilerplateInfo rethinkDbBoilerplate = BoilerplateInfo(
  'RethinkDB',
  'A starter application with a REST and WebSocket API of a RethinkDB table.',
  repoLocation,
  'templates/basic_rethinkdb',
);

const BoilerplateInfo sembastBoilerplate = BoilerplateInfo(
  'Sembast',
  'A starter application with a REST API of a Sembast store, in one file.',
  repoLocation,
  'templates/basic_sembast',
);

const BoilerplateInfo kelicapBoilerplate = BoilerplateInfo(
  'Kelicap',
  'A full-stack starter application, with a Kelicap web client.',
  repoLocation,
  'templates/basic_kelicap',
);

const BoilerplateInfo basicBoilerplate = BoilerplateInfo(
  'Basic',
  'A basic starter application.',
  repoLocation,
  'templates/basic',
);

const List<BoilerplateInfo> boilerplates = [
  basicBoilerplate,
  ormBoilerplate,
  ormMySqlBoilerplate,
  graphQLBoilerplate,
  mongoBoilerplate,
  rethinkDbBoilerplate,
  sembastBoilerplate,
  kelicapBoilerplate,
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
