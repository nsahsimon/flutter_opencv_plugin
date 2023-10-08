import 'package:flutter/material.dart';
import 'package:flutter_opencv_plugin/flutter_opencv_plugin.dart';
import 'package:flutter_opencv_plugin_example/matcher_app/matcher_app.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Opencv().initialize(newAppName: "MatcherApp");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.red,
      ),
      title: "Artifact Matcher App",
      home: MatcherApp()
    );
  }
}
