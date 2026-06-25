import 'package:flutter/material.dart';



import 'app/startup/app_startup.dart';



Future<void> main() async {

  await AppStartup.initialize();

  runApp(AppStartup.createApp());

}

