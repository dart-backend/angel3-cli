import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:inflection3/inflection3.dart';
import 'package:io/ansi.dart';
import 'package:prompts/prompts.dart' as prompts;
import 'package:recase/recase.dart';
import '../../util.dart';
import 'maker.dart';

class MigrationCommand extends Command {
  @override
  String get name => 'migration';

  @override
  String get description => 'Generates a migration class.';

  MigrationCommand() {
    argParser
      ..addOption('name',
          abbr: 'n', help: 'Specifies a name for the model class.')
      ..addOption('output-dir',
          help: 'Specifies a directory to create the migration class in.',
          defaultsTo: 'tool/migrations');
  }

  @override
  FutureOr run() async {
    String? name;
    if (argResults?.wasParsed('name') == true) {
      name = argResults?['name'] as String?;
    }

    if (name?.isNotEmpty != true) {
      name = prompts.get('Name of model class');
    }

    var deps = [const MakerDependency('angel3_migration', '^7.0.0')];
    var rc = ReCase(name!);

    var migrationLib = Library((migrationLib) {
      migrationLib
        ..directives.add(Directive.import(
            'package:angel3_migration.dart/angel3_migration.dart'))
        ..body.add(Class((migrationClazz) {
          migrationClazz
            ..name = '${rc.pascalCase}Migration'
            ..extend = refer('Migration');

          var tableName = pluralize(rc.snakeCase);

          // up()
          migrationClazz.methods.add(Method((up) {
            up
              ..name = 'up'
              ..returns = refer('void')
              ..annotations.add(refer('override'))
              ..requiredParameters.add(Parameter((b) => b
                ..name = 'schema'
                ..type = refer('Schema')))
              ..body = Block((block) {
                // (table) { ... }
                var callback = Method((callback) {
                  callback
                    ..requiredParameters
                        .add(Parameter((b) => b..name = 'table'))
                    ..body = Block((block) {
                      var table = refer('table');

                      block.addExpression(
                        (table.property('serial').call([literal('id')]))
                            .property('primaryKey')
                            .call([]),
                      );

                      block.addExpression(
                        table.property('date').call([
                          literal('created_at'),
                        ]),
                      );

                      block.addExpression(
                        table.property('date').call([
                          literal('updated_at'),
                        ]),
                      );
                    });
                });

                block.addExpression(refer('schema').property('create').call([
                  literal(tableName),
                  callback.closure,
                ]));
              });
          }));

          // down()
          migrationClazz.methods.add(Method((down) {
            down
              ..name = 'down'
              ..returns = refer('void')
              ..annotations.add(refer('override'))
              ..requiredParameters.add(Parameter((b) => b
                ..name = 'schema'
                ..type = refer('Schema')))
              ..body = Block((block) {
                block.addExpression(
                  refer('schema').property('drop').call([
                    literal(tableName),
                  ]),
                );
              });
          }));
        }));
    });

    // Save migration file
    var migrationDir = Directory.fromUri(
        Directory.current.uri.resolve(argResults!['output-dir'] as String));
    var migrationFile =
        File.fromUri(migrationDir.uri.resolve('${rc.snakeCase}.dart'));
    if (!await migrationFile.exists()) {
      await migrationFile.create(recursive: true);
    }

    await migrationFile.writeAsString(
        DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
            .format(migrationLib.accept(DartEmitter()).toString()));

    print(green.wrap(
        '$checkmark Created migration file "${migrationFile.absolute.path}".'));

    await depend(deps);
  }
}
