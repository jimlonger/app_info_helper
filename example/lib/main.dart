import 'package:app_info_helper/app_info_helper.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfoHelper().init();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final info = AppInfoHelper();
    final rows = <String, String>{
      'App name': info.appName,
      'Package': info.packageName,
      'Version': info.version,
      'Build': info.buildNumber,
      'Device model': info.deviceModel,
      'Platform': info.platform,
      'OS version': info.osVersion,
      'Locale': info.locale,
      'Country': info.countryCode,
      'Time zone': info.timeZone,
      'Device ID': info.deviceId,
      'Advertising ID': info.advertisingId,
    };

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('app_info_helper')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: rows.entries
              .map(
                (entry) => ListTile(
                  title: Text(entry.key),
                  subtitle: Text(entry.value.isEmpty ? '-' : entry.value),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
