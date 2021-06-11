#!/usr/bin/env dart

library angel3_cli.tool;

import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:angel3_cli/angel3_cli.dart';
import 'package:io/ansi.dart';

final String DOCTOR = 'doctor';

void main(List<String> args) async {
  var runner = CommandRunner(
      'angel',
      asciiArt.trim() +
          '\n\n' +
          'Command-line tools for the Angel framework.' +
          '\n\n' +
          'https://angel-dart.github.io');

  runner.argParser
      .addFlag('verbose', help: 'Print verbose output.', negatable: false);

  runner
    ..addCommand(DeployCommand())
    ..addCommand(DoctorCommand())
    ..addCommand(KeyCommand())
    ..addCommand(InitCommand())
    ..addCommand(InstallCommand())
    ..addCommand(RenameCommand())
    ..addCommand(MakeCommand());

  return await runner.run(args).catchError((exc, st) {
    if (exc is String) {
      stdout.writeln(exc);
    } else {
      stderr.writeln('Oops, something went wrong: $exc');
      if (args.contains('--verbose')) {
        stderr.writeln(st);
      }
    }

    exitCode = 1;
  }).whenComplete(() {
    stdout.write(resetAll.wrap(''));
  });
}

const String asciiArt = '''
____________   ________________________ 
___    |__  | / /_  ____/__  ____/__  / 
__  /| |_   |/ /_  / __ __  __/  __  /  
_  ___ |  /|  / / /_/ / _  /___  _  /___
/_/  |_/_/ |_/  \____/  /_____/  /_____/
                                        
''';
