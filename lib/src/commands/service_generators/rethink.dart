import 'generator.dart';
import 'package:code_builder/code_builder.dart';
import 'package:inflection3/inflection3.dart';
import '../make/maker.dart';

class RethinkServiceGenerator extends ServiceGenerator {
  const RethinkServiceGenerator() : super('RethinkDB');

  @override
  List<MakerDependency> get dependencies =>
      const [MakerDependency('angel3_rethink', '^4.0.0')];

  bool get createsModel => false;

  @override
  void applyToConfigureServer(
      LibraryBuilder library,
      MethodBuilder configureServer,
      BlockBuilder block,
      String? name,
      String lower) {
    configureServer.requiredParameters.addAll([
      Parameter((b) => b
        ..name = 'connection'
        ..type = refer('Connection')),
      Parameter((b) => b
        ..name = 'r'
        ..type = refer('Rethinkdb')),
    ]);
  }

  @override
  void applyToLibrary(LibraryBuilder library, String name, String lower) {
    library.directives.addAll([
      'package:angel3_rethink/angel3_rethink.dart',
      'package:rethinkdb_dart/rethinkdb_dart.dart'
    ].map((str) => Directive.import(str)));
  }

  @override
  Expression createInstance(LibraryBuilder library, MethodBuilder methodBuilder,
      String name, String lower) {
    return refer('RethinkService').newInstance([
      refer('connection'),
      refer('r').property('table').call([literal(pluralize(lower))])
    ]);
  }
}
