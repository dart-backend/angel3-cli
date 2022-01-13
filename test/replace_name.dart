import 'dart:io';

import 'package:dart_style/dart_style.dart';

void main() async {
  String updateImport(String content, String oldName, String newName) {
    if (!content.startsWith('import')) {
      return content;
    }

    if (content.contains('package:$oldName/$oldName.dart')) {
      return content.replaceFirst(
          'package:$oldName/$oldName.dart', 'package:$newName/$newName.dart');
    }

    if (content.contains('package:$oldName/')) {
      return content.replaceFirst('package:$oldName/', 'package:$newName/');
    }

    return content;
  }

  String updateMustacheBinding(String content, String oldName, String newName) {
    if (content.contains('{{$oldName}}')) {
      return content.replaceAll('{{$oldName}}', newName);
    }

    return content;
  }

  var fmt = DartFormatter();
  var dir = Directory('graph');
  await for (FileSystemEntity file in dir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var lineList = await file.readAsLines();

      var oldName = 'angel';
      var newName = 'graph';
      var replace = {oldName: newName};

      if (replace.isNotEmpty) {
        var contents = lineList.fold<String>('', (prev, cur) {
          var updatedCur = updateImport(cur, oldName, newName);
          updatedCur = updateMustacheBinding(updatedCur, oldName, newName);
          return prev + '\n' + updatedCur;
        });
        await file.writeAsString(fmt.format(contents));

        print('Updated file `${file.absolute.path}`.');
      }
    }
  }
}
