import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_scripts/src/commands/commands.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';

const executableName = 'flutter_scripts';
const packageName = 'flutter_scripts';
const description = 'Run flutter scripts from pubspec.yaml';

class FlutterScriptsCommandRunner extends CommandRunner<int> {
  FlutterScriptsCommandRunner({
    Logger? logger,
    PubUpdater? pubUpdater,
  })  : _logger = logger ?? Logger(),
        _pubUpdater = pubUpdater ?? PubUpdater(),
        super(executableName, description) {
    argParser.addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Print the current version.',
    );

    addCommand(ScriptCommand(logger: _logger));
    addCommand(UpdateCommand(logger: _logger, pubUpdater: _pubUpdater));
  }

  final Logger _logger;
  final PubUpdater _pubUpdater;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final topLevelResults = parse(args);
      return await runCommand(topLevelResults) ?? ExitCode.success.code;
    } on FormatException catch (e, stackTrace) {
      _logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    final int? exitCode;
    if (topLevelResults['version'] == true) {
      final packageVersion = await getPackageCurrentVersion();
      _logger.info(packageVersion);
      exitCode = ExitCode.success.code;
    } else {
      exitCode = await super.runCommand(topLevelResults);
    }
    await _checkForUpdates();
    return exitCode;
  }

  Future<void> _checkForUpdates() async {
    try {
      final packageVersion = await getPackageCurrentVersion();
      final latestVersion = await _pubUpdater.getLatestVersion(packageName);
      final isUpToDate = packageVersion == latestVersion;
      if (!isUpToDate) {
        _logger
          ..info('')
          ..info(
            '''
${lightYellow.wrap('Update available!')} ${lightCyan.wrap(packageVersion)} \u2192 ${lightCyan.wrap(latestVersion)}
Run ${lightCyan.wrap('dart pub global activate flutter_scripts')} to update''',
          );
      }
    } catch (_) {}
  }
}

Future<String?> getPackageCurrentVersion() async {
  const command = 'dart';
  final args = <String>['pub', 'global', 'list'];

  final result = await Process.run(command, args);

  if (result.exitCode != 0) {
    Logger()
      ..err('Command error:\n${result.stderr}')
      ..err('Command failed with exit code ${result.exitCode}.');
    return null;
  }

  final output = result.stdout.toString();

  final error = result.stderr.toString();
  if (error.isNotEmpty) {
    Logger().err('Command error:\n$error');
    return null;
  }

  final regex = RegExp(r'flutter_scripts (\d+\.\d+\.\d+)');
  final match = regex.firstMatch(output);
  return match?.group(1) ?? '';
}
