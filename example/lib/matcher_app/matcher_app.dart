import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_opencv_plugin/flutter_opencv_plugin.dart';
import 'package:flutter_opencv_plugin_example/matcher_app/camera_screen.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
String? srcPath;

class MatcherApp extends StatefulWidget {
  const MatcherApp({Key? key}) : super(key: key);

  @override
  State<MatcherApp> createState() => _MatcherAppState();
}

class _MatcherAppState extends State<MatcherApp> {

  bool isLoading = false;

  void startLoading() {
    setState(() {
      isLoading = true;
    });
  }

  void stopLoading() {
    setState(() {
      isLoading = false;
    });
  }

  Future<String?> pickDirectory() async {
    try {
      final String? result = await FilePicker.platform.getDirectoryPath();
      return result;
    } catch (e) {
      debugPrint('Error picking directory: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModalProgressHUD(
      inAsyncCall: isLoading,
      child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Visibility(
                  visible: srcPath != null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("Selected Image Directory:", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                        Text("${srcPath}", textAlign: TextAlign.center,),
                      ],
                    )),
                GestureDetector(
                  child: ElevatedButton(
                    onPressed: () async{
                      String? tempSrcPath = await pickDirectory();
                      setState(() {
                        srcPath = tempSrcPath;
                      });
                      if(srcPath != null) {
                        startLoading();
                        var result = await Opencv().loadDescriptors(srcPath: srcPath!);
                        stopLoading();
                        if(result == true) {
                          debugPrint("Successfully loaded descriptors");
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text("Successfully loaded images"))
                          );
                        }else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text("Failed to load images"))
                          );
                        }
                      }else {
                        debugPrint("No directory selected");
                      }
                    },
                    child: Text(
                      "Select Images"
                    )
                  ),
                ),
                SizedBox(height: 40),
                GestureDetector(
                  child: ElevatedButton(
                      onPressed: () async{
                        if(srcPath == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.black,
                                content: Text("You must select a directory containing only reference images."))
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CameraScreen()
                          )
                        );
                      },
                      child: Text(
                          "Scan Images"
                      )
                  ),
                ),
              ],
            )
          )
        )
    );
  }
}
