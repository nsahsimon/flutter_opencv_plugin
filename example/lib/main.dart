import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_opencv_plugin/flutter_opencv_plugin.dart';

void main() async{
  await Opencv().initialize();
  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  TextEditingController num1Controller = TextEditingController();
  TextEditingController num2Controller = TextEditingController();
  double? sum;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.red,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text("Flutter Opencv Example Application")
        ),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 10),
                Text("Enter num1: "),
                TextField(controller: num1Controller,),
                SizedBox(height: 10),
                Text("Enter num2: "),
                TextField(controller: num2Controller,),
                SizedBox(height: 10),
                Text("$sum"),
                SizedBox(height: 10),
                ElevatedButton(
                    onPressed: () async{
                      double? sumTemp = await Opencv().addNumbers(num1: double.parse(num1Controller.text), num2: double.parse(num2Controller.text));
                      setState(() {
                        sum = sumTemp;
                      });
                    },
                    child: Text("Add")
                )
              ],
            )
          ),
        )
      ),
    );
  }
}

