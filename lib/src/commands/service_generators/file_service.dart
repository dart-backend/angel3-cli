import 'generator.dart';
import 'package:code_builder/code_builder.dart';
import 'package:inflection3/inflection3.dart';
import '../make/maker.dart';

class FileServiceGenerator extends ServiceGenerator {
  const FileServiceGenerator() : super('Persistent JSON File');

  @override
  List<MakerDependency> get dependencies =>
      const [MakerDependency('angel3_file_service', '^4.0.0')];

  @override
  bool get goesFirst => true;

  @override
  void applyToConfigureServer(
      LibraryBuilder library,
      MethodBuilder configureServer,
      BlockBuilder block,
      String? name,
      String lower) {
    configureServer.requiredParameters.add(Parameter((b) => b
      ..name = 'dbDirectory'
      ..type = refer('Directory')));
  }

  @override
  void applyToLibrary(LibraryBuilder library, String name, String lower) {
    library.directives.addAll([
      Directive.import('package:angel3_file_service/angel3_file_service.dart'),
    ]);
  }

  @override
  Expression createInstance(LibraryBuilder library, MethodBuilder methodBuilder,
      String name, String lower) {
    library.directives.addAll([
      Directive.import('package:file/file.dart'),
    ]);
    return refer('JsonFileService').newInstance([
      refer('dbDirectory')
          .property('childFile')
          .call([literal(pluralize(lower) + '_db.json')])
    ]);
  }
}
