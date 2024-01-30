#! /usr/bin/env dcli

import 'dart:convert';
import 'dart:io';
import 'package:dcli/dcli.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';
import 'package:process_run/process_run.dart' as process;

const List<String> releaseTypes = ["major", "minor", "patch"];

void main(List<String> args) async {
  // ignore: avoid_print
  print("🚀 Let's release a new version !\n");

  try {
    final String currentVersion = await getCurrentPackageVersion();

    String? releaseType;
    if (args.isEmpty || !releaseTypes.contains(args[0])) {
      releaseType = getReleaseType(currentVersion);
    } else {
      releaseType = args[0];
    }

    final String newVersion = getNewVersion(currentVersion, releaseType);
    // ignore: avoid_print
    print("New ${releaseType.toUpperCase()} release : $newVersion");
    await updateVersion(newVersion);
    await commitNewVersion(releaseType, newVersion);
  } catch (e) {
    printerr(e.toString());
  }
}

String getReleaseType(String currentVersion) {
  return menu<String>(
    'Please select a release type:',
    options: releaseTypes,
    format: (String item) =>
        "$item (${getNewVersion(currentVersion, item)})".toUpperCase(),
    defaultOption: releaseTypes[2],
  );
}

Future<String> getCurrentPackageVersion() async {
  File configFile = File('config/cloudsmith_config.json');
  if (!await configFile.exists()) {
    throw Exception("Configuration file not found.");
  }

  String configString = await configFile.readAsString();
  Map<String, dynamic> config = jsonDecode(configString);

  final String owner = config['OWNER']!;
  final String repo = config['REPO']!;
  final String packageFormat = config['PACKAGE_FORMAT']!;
  final String packageName = config['PACKAGE_NAME']!;
  final String apiKey = config['CLOUDSMITH_API_KEY']!;

  final response = await http.get(
    Uri.https("api.cloudsmith.io",
        "/v1/badges/version/$owner/$repo/$packageFormat/$packageName/package_version/package_identifiers"),
    headers: {"X-Api-Key": apiKey},
  );
  if (response.statusCode != 200) {
    throw Exception("Error when getting the current version of $owner/$repo");
  }

  final String version = json.decode(response.body)["version"];
  // ignore: avoid_print
  print("Current version: $version");

  return version;
}

String getNewVersion(String currentVersion, String releaseType) {
  List<int?> versionNumbers =
      currentVersion.split('.').map<int?>((e) => int.tryParse(e)).toList();

  // update version number by release type
  switch (releaseType) {
    case 'major':
      versionNumbers[0] = versionNumbers[0]! + 1;
      versionNumbers[1] = 0;
      versionNumbers[2] = 0;
      break;
    case 'minor':
      versionNumbers[1] = versionNumbers[1]! + 1;
      versionNumbers[2] = 0;
      break;
    default: // patch
      versionNumbers[2] = versionNumbers[2]! + 1;
      break;
  }

  return versionNumbers.join(".");
}

Future<void> updateVersion(String newVersion) async {
  final File changeLog = File('CHANGELOG.md');
  final File pubspec = File("pubspec.yaml");

  // get files content as string
  String changeLogContent = await changeLog.readAsString();
  String pubspecContent = await pubspec.readAsString();

  // update package version in pubspec.yaml
  Map map = Map<String, dynamic>.from(loadYaml(pubspecContent));
  map["version"] = newVersion;

  // update package version in CHANGELOG.MD
  List<String> changeLogContentList = changeLogContent.split('\n');
  changeLogContentList[0] = "## $newVersion";

  // write update
  await pubspec.writeAsString(YAMLWriter().write(map));
  await changeLog.writeAsString(changeLogContentList.join("\n"));
}

Future<void> commitNewVersion(String releaseType, String newVersion) async {
  // Commit the changes
  bool commit = confirm("Do you want to commit the changes ?");
  if (commit) {
    await process.run("git add .");
    await process.run("git commit -m \"$releaseType release: $newVersion\"");
    // Add tag version
    await process.run("git tag v$newVersion");
  }

  // Push the changes
  if (commit && confirm("Do you want to push the changes as well ?")) {
    await process.run("git push");
    await process.run("git push --tags");
  }
}
