import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:io/ansi.dart';
import 'package:prompts/prompts.dart' as prompts;
import 'package:recase/recase.dart';
import '../../util.dart';
import 'maker.dart';

class ControllerCommand extends Command {
  @override
  String get name => 'controller';

  @override
  String get description => 'Generates a controller class.';

  ControllerCommand() {
    argParser
      ..addFlag('websocket',
          abbr: 'w',
          help:
              'Generates a WebSocketController, instead of an HTTP controller.',
          negatable: false)
      ..addOption('name',
          abbr: 'n', help: 'Specifies a name for the model class.')
      ..addOption('output-dir',
          help: 'Specifies a directory to create the controller class in.',
          defaultsTo: 'lib/src/routes/controllers');
  }

  @override
  Future run() async {
    String? name;
    if (argResults?.wasParsed('name') == true) {
      name = argResults!['name'] as String?;
    }

    if (name?.isNotEmpty != true) {
      name = prompts.get('Name of controller class');
    }

    var deps = <MakerDependency>[
      const MakerDependency('angel3_framework', '^7.0.0')
    ];

    //${pubspec.name}.src.models.${rc.snakeCase}

    var rc = ReCase(name!);
    var controllerLib = Library((controllerLib) {
      if (argResults?['websocket'] as bool) {
        deps.add(const MakerDependency('angel3_websocket', '^7.0.0'));
        controllerLib.directives
            .add(Directive.import('package:angel3_websocket/server.dart'));
      } else {
        controllerLib.directives.add(
            Directive.import('package:angel3_framework/angel3_framework.dart'));
      }

      controllerLib.body.add(Class((clazz) {
        clazz
          ..name = '${rc.pascalCase}Controller'
          ..extend = refer(argResults?['websocket'] as bool
              ? 'WebSocketController'
              : 'Controller');

        if (argResults!['websocket'] as bool) {
          // XController(AngelWebSocket ws) : super(ws);
          clazz.constructors.add(Constructor((b) {
            b
              ..requiredParameters.add(Parameter((b) => b
                ..name = 'ws'
                ..type = refer('AngelWebSocket')))
              ..initializers.add(Code('super(ws)'));
          }));

          clazz.methods.add(Method((meth) {
            meth
              ..name = 'hello'
              ..returns = refer('void')
              ..annotations
                  .add(refer('ExposeWs').call([literal('get_${rc.snakeCase}')]))
              ..requiredParameters.add(Parameter((b) => b
                ..name = 'socket'
                ..type = refer('WebSocketContext')))
              ..body = Block((block) {
                block.addExpression(refer('socket').property('send').call([
                  literal('got_${rc.snakeCase}'),
                  literalMap({'message': literal('Hello, world!')}),
                ]));
              });
          }));
        } else {
          clazz
            ..annotations
                .add(refer('Expose').call([literal('/${rc.snakeCase}')]))
            ..methods.add(Method((meth) {
              meth
                ..name = 'hello'
                ..returns = refer('String')
                ..body = literal('Hello, world').returned.statement
                ..annotations.add(refer('Expose').call([
                  literal('/'),
                ]));
            }));
        }
      }));
    });

    var outputDir = Directory.fromUri(
        Directory.current.uri.resolve(argResults?['output-dir'] as String));
    var controllerFile =
        File.fromUri(outputDir.uri.resolve('${rc.snakeCase}.dart'));
    if (!await controllerFile.exists()) {
      await controllerFile.create(recursive: true);
    }
    await controllerFile.writeAsString(
        DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
            .format(controllerLib.accept(DartEmitter()).toString()));

    print(green.wrap(
        '$checkmark Created controller file "${controllerFile.absolute.path}"'));

    if (deps.isNotEmpty) await depend(deps);
  }
}
