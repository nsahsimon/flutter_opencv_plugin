import 'package:flutter/material.dart';
import 'package:flutter_opencv_plugin/flutter_opencv_plugin.dart';

class AddApp extends StatefulWidget {
  const AddApp({Key? key}) : super(key: key);

  @override
  State<AddApp> createState() => _AddAppState();
}

class _AddAppState extends State<AddApp> {

  TextEditingController num1Controller = TextEditingController();
  TextEditingController num2Controller = TextEditingController();
  double? sum;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}

