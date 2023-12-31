import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:core';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';

int result = 0;

String randomId() {
  return DateTime.now().microsecondsSinceEpoch.toString();
}

Future<double?> _add(Map data, DynamicLibrary omrLib) async{
  ///unpacking data
  double num1 = data['num_1'];
  double num2 = data['num_2'];

  double Function(double num1, double num2) addDart = omrLib.lookup<NativeFunction<Float Function(Float, Float)>>("native_add").asFunction();

  double result = addDart(num1, num2);
  return result;
}

Future<List<List<double>>> _detectCorners(Map data, DynamicLibrary omrLib) async{
  ///unpacking data
  var frame = data['frame'];
  debugPrint("Retrieved frame in isolate. Dimensions: (${frame.width}, ${frame.height}) ");

  /// Allocate memory for the 3 planes of the image
  Pointer<Uint8> plane0Bytes = malloc.allocate(frame.planes[0].bytes.length);
  Pointer<Uint8> plane1Bytes = malloc.allocate(frame.planes[1].bytes.length);
  Pointer<Uint8> plane2Bytes = malloc.allocate(frame.planes[2].bytes.length);

  /// Assign the planes data to the pointers of the image
  Uint8List pointerList = plane0Bytes.asTypedList(
      frame.planes[0].bytes.length
  );
  Uint8List pointerList1 = plane1Bytes.asTypedList(
      frame.planes[1].bytes.length
  );
  Uint8List pointerList2 = plane2Bytes.asTypedList(
      frame.planes[2].bytes.length
  );
  pointerList.setRange(0, frame.planes[0].bytes.length,
      frame.planes[0].bytes);
  pointerList1.setRange(0, frame.planes[1].bytes.length,
      frame.planes[1].bytes);
  pointerList2.setRange(0, frame.planes[2].bytes.length,
      frame.planes[2].bytes);

  ///Extract relevant parameters from the image frame
  int width = frame.width;
  int height = frame.height;
  int bytesPerRow0 = frame.planes[0].bytesPerRow;
  int bytesPerPixel0 = frame.planes[0].bytesPerPixel;
  int bytesPerRow1 = frame.planes[1].bytesPerRow;
  int bytesPerPixel1 = frame.planes[1].bytesPerPixel;
  int bytesPerRow2 = frame.planes[2].bytesPerRow;
  int bytesPerPixel2 = frame.planes[2].bytesPerPixel;


  Pointer<Float> Function(
      Pointer<Uint8> plane0Bytes,Pointer<Uint8> plane1Bytes,Pointer<Uint8> plane2Bytes,
      int width, int height,
      int bytesPerRowPlane0, int bytesPerRowPlane1,int bytesPerRowPlane2,
      int bytesPerPixelPlane0, int bytesPerPixelPlane1, int bytesPerPixelPlane2) detectCornersDart
  = omrLib.lookup<NativeFunction<Pointer<Float> Function(
      Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>,
      Int32, Int32,
      Int32, Int32, Int32,
      Int32, Int32, Int32)>>("getFormCorners").asFunction();

  List<List<double>> results = [];

  int start = DateTime.now().microsecondsSinceEpoch;
  Pointer<Float> relativeCoordPtr = detectCornersDart(
      plane0Bytes, plane1Bytes, plane2Bytes,
      width, height,
      bytesPerRow0, bytesPerRow1, bytesPerRow2,
      bytesPerPixel0, bytesPerPixel1, bytesPerPixel2
  );

  int stop = DateTime.now().microsecondsSinceEpoch;
  int time = stop - start;
  debugPrint("***DETECTED CORNERS IN : ${time / 1000} SECONDS****");

  int coordListLength = relativeCoordPtr.asTypedList(1)[0].toInt();
  debugPrint("FOUND ${(coordListLength - 1)} CORNERS");
  List<double> relativeCoordList = []; //= relativeCoordPtr.asTypedList(coordListLength);
  try {
    relativeCoordList = relativeCoordPtr.asTypedList(2 * coordListLength - 1);
  }catch(e) {
    debugPrint("$e");

  }
  //List<double> relativeCoordList = [0];//relativeCoordPtr.asTypedList((double.parse(relativeCoordPtr.elementAt(0).toString())).toInt()).toList();
  debugPrint("Got the coordinates: ${relativeCoordList.length}");

  //Converting the relative coordinates to actual coordinates
  for(int i = 1; i < relativeCoordList.length; i = i + 2){

    results.add([relativeCoordList[i], relativeCoordList[i + 1]]);
    // results[i].add();
  }

  ///free memory
  malloc.free(plane0Bytes);
  malloc.free(plane1Bytes);
  malloc.free(plane2Bytes);

  return results;
}

Future<bool> _loadDescriptors(Map data, DynamicLibrary omrLib) async{
  try {
    ///unpacking data
    String imagesPath = data['images_path'];
    debugPrint("Retrieved images path in isolate: $imagesPath");
    String featuresFilePath = imagesPath + "/features.yml";
    List<String> imagesPathList = [];
    final files = await Directory(imagesPath).list().toList();

    // Store the path of each image in the imagesPathList
    for (final file in files) {
      if (file is File) {
        if(file.path.contains(".yml") == false) {
          imagesPathList.add(file.path);
        }
      }
    }
    debugPrint("Successfully loaded imagesPathList");

    // Allocate memory for an array of pointers to Utf8 strings
    final imagesPathListPtr = calloc<Pointer<Utf8>>(imagesPathList.length);

    // Allocate memory for each string and copy the data
    for (var i = 0; i < imagesPathList.length; i++) {
      final str = imagesPathList[i];
      final utf8Str = str.toNativeUtf8();
      imagesPathListPtr[i] = utf8Str;
    }

    debugPrint("Successfully loaded imagesPathListPtr");

    Pointer<Utf8> featuresFilePathPtr = featuresFilePath.toNativeUtf8();
    int pathCount = imagesPathList.length;

    int Function(
        Pointer<Pointer<Utf8>> imagesPathListPtr, Pointer<Utf8> featuresFilePathPtr, int pathCount)
    loadDescriptorsDart = omrLib.lookup<NativeFunction<
        Int32 Function(
            Pointer<Pointer<Utf8>>, Pointer<Utf8>, Int32)
    >>("loadDescriptors").asFunction();
    debugPrint("Successfully loaded \"LoadDescriptors function\"");

    int start = DateTime.now().microsecondsSinceEpoch;
    int result = loadDescriptorsDart(imagesPathListPtr, featuresFilePathPtr,pathCount);
    int stop = DateTime.now().microsecondsSinceEpoch;
    int time = stop - start;

    if(result == 0) {

    }else if (result == 1) {
      debugPrint("Features were re-computed for all images");
    }else if (result == 2) {
      debugPrint("Features were not re-computed for all features");
    }
    debugPrint("***LOADED DESCRIPTORS IN : ${time / 1000000} SECONDS****");
    return true;
  }catch(e) {
    debugPrint("$e");
    return false;
  }
}

Future<int> _findBestMatch(Map data, DynamicLibrary omrLib) async{
  ///unpacking data
  var frame = data['frame'];
  debugPrint("Retrieved frame in isolate. Dimensions: (${frame.width}, ${frame.height}) ");

  /// Allocate memory for the 3 planes of the image
  Pointer<Uint8> plane0Bytes = malloc.allocate(frame.planes[0].bytes.length);
  Pointer<Uint8> plane1Bytes = malloc.allocate(frame.planes[1].bytes.length);
  Pointer<Uint8> plane2Bytes = malloc.allocate(frame.planes[2].bytes.length);

  /// Assign the planes data to the pointers of the image
  Uint8List pointerList = plane0Bytes.asTypedList(
      frame.planes[0].bytes.length
  );
  Uint8List pointerList1 = plane1Bytes.asTypedList(
      frame.planes[1].bytes.length
  );
  Uint8List pointerList2 = plane2Bytes.asTypedList(
      frame.planes[2].bytes.length
  );
  pointerList.setRange(0, frame.planes[0].bytes.length,
      frame.planes[0].bytes);
  pointerList1.setRange(0, frame.planes[1].bytes.length,
      frame.planes[1].bytes);
  pointerList2.setRange(0, frame.planes[2].bytes.length,
      frame.planes[2].bytes);

  ///Extract relevant parameters from the image frame
  int width = frame.width;
  int height = frame.height;
  int bytesPerRow0 = frame.planes[0].bytesPerRow;
  int bytesPerPixel0 = frame.planes[0].bytesPerPixel;
  int bytesPerRow1 = frame.planes[1].bytesPerRow;
  int bytesPerPixel1 = frame.planes[1].bytesPerPixel;
  int bytesPerRow2 = frame.planes[2].bytesPerRow;
  int bytesPerPixel2 = frame.planes[2].bytesPerPixel;


  int Function(
      Pointer<Uint8> plane0Bytes,Pointer<Uint8> plane1Bytes,Pointer<Uint8> plane2Bytes,
      int width, int height,
      int bytesPerRowPlane0, int bytesPerRowPlane1,int bytesPerRowPlane2,
      int bytesPerPixelPlane0, int bytesPerPixelPlane1, int bytesPerPixelPlane2) findBestMatchDart
  = omrLib.lookup<NativeFunction<Int32 Function(
      Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>,
      Int32, Int32,
      Int32, Int32, Int32,
      Int32, Int32, Int32)>>("findBestMatch").asFunction();



  int start = DateTime.now().microsecondsSinceEpoch;
  int bestMatchId = findBestMatchDart(
      plane0Bytes, plane1Bytes, plane2Bytes,
      width, height,
      bytesPerRow0, bytesPerRow1, bytesPerRow2,
      bytesPerPixel0, bytesPerPixel1, bytesPerPixel2
  );

  int stop = DateTime.now().microsecondsSinceEpoch;
  int time = stop - start;
  debugPrint("***DETECTED CORNERS IN : ${time / 1000} SECONDS****");

  ///free memory
  malloc.free(plane0Bytes);
  malloc.free(plane1Bytes);
  malloc.free(plane2Bytes);

  return bestMatchId;
}

/// Add logic for other functions
/*
    <return type> _<process name>(<arguments>) async {
    //do stuff
    return <something>;
    }
 */

void createDirs(List<String> dirPaths){
  for(String dir in dirPaths) {
    debugPrint(">> Creating the directory for name characters");
    ///for creating the director for name characters
    try {
      if(!Directory(dir).existsSync()) {
        Directory(dir).createSync(recursive: true);
        debugPrint(">> Path to name chars has just been created");
      } else { //if the directory already exists
        debugPrint(">> Path to name chars already exists");
        Directory(dir).deleteSync(recursive: true);
        Directory(dir).createSync(recursive: true);
      }
    } catch (e) {
      debugPrint("$e");
      debugPrint(">> Could not create image directories for neural nets");
    }
  }
}

///Contains methods running on the other isolate
class OpencvIsolate {
  static late final DynamicLibrary omrLib;
  static late final ReceivePort openCVIsolateReceivePort;

  static void openCVIsolate(SendPort sendPort) {
    /// Load the omr dynamic libraries
    try {
      debugPrint(">>(Opencv Isolate) Trying to load the flutter opencv dynamic Library");
      omrLib = Platform.isAndroid
          ? DynamicLibrary.open("libflutter_opencv.so")
          : DynamicLibrary.process();
      debugPrint(">>(Opencv Isolate) SUCCESSFULLY loaded the flutter opencv dynamic library");
    }catch (e) {
      debugPrint("$e");
      debugPrint(">>(Opencv Isolate) FAILED to load the flutter opencv dynamic library");
    }

    /// Create a receiver port for this isolate
    openCVIsolateReceivePort = ReceivePort();

    ///Send the corresponding send port back to the main isolate
    sendPort.send(openCVIsolateReceivePort.sendPort);

    openCVIsolateReceivePort.listen(
            (message) async{
          debugPrint("ISOLATE RECEIVED A MESSAGE");
          if(message is Map<String, dynamic>) { //i.e if
            if(message['process'] == 'ADD_NUMBERS'){
              double? result = await _add(message, omrLib);
              sendPort.send(result);
            }else if (message['process'] == 'DETECT_CORNERS') {
              debugPrint("Isolate detected detectCorner message");
              List<List<double>> result = await _detectCorners(message, omrLib);
              sendPort.send(result);
            }else if (message['process'] == 'LOAD_DESCRIPTORS') {
              var result = await _loadDescriptors(message, omrLib);
              sendPort.send(result);
            }else if (message['process'] == 'FIND_BEST_MATCH') {
              int result = await _findBestMatch(message, omrLib);
              sendPort.send(result);
            }
            ///Add your own processes handlers
            /*
            else if (message['process'] == '<PROCESS_NAME>') {
              <return type> result = await <process function>(message, omrLib);
              sendPort.send(result);
            }
            */
            else {

            }
          }
        });
  }
}


/// Contains methods running on the main isolate
class Opencv {
  static late final ReceivePort mainReceivePort;
  static late final SendPort mainSendPort;
  static late final Isolate? opencvIsolate;
  static StreamController<dynamic>? resultStreamController;
  static String root = "";
  static late String appName;
  static List<String> imageNames = [];

  Future<void> initialize({String newAppName = "MatcherApp"}) async {
    await getStoragePermission();
    appName = newAppName;
    mainReceivePort = ReceivePort();

    /// Create opencv isolate
    opencvIsolate = await Isolate.spawn(OpencvIsolate.openCVIsolate , mainReceivePort.sendPort);
    /// Start Listing to the stream
    mainReceivePort.listen(
            (message) {
          debugPrint("Received a message from the opencv isolate. Content: ${message}");
          if(message is SendPort) {
            mainSendPort = message;
            debugPrint("(Opencv initialize) SUCCESSFULLY retrieved send port from opencv isolate");
          } else if (message is List<Map<String, dynamic>?>) {
            debugPrint("(Opencv initialize) SUCCESSFULLY retrieved a result from the opencv isolate");
            if(resultStreamController != null) {
              resultStreamController!.add(message);
            }
          }else {
            debugPrint("(Opencv initialize) SUCCESSFULLY retrieved a result from the opencv isolate");
            if(resultStreamController != null) {
              resultStreamController!.add(message);
            }
          }
        });

    debugPrint(">> Initializing the opencv library");
    debugPrint(">> Loading the dynamic libraries");
  }

  static Future<String> getRootDirectory() async {
    var dir;
    /// Try requesting for external storage permissions
    // bool result = await SuperEasyPermissions.isGranted(Permissions.storage);
    bool result = await Permission.storage.isGranted;
    if (!result) {
      bool status = await Permission.storage.request().isGranted;
      if (status) {
        try {
          dir = Directory("/storage/emulated/0/Documents");
        } catch (e) {
          dir = Directory("/storage/emulated/0/Documents");
        }
      } else {
        var dirs = await getExternalStorageDirectories();
        for (var dir in dirs!) {
          debugPrint("${dir.path}");
        }
        dir = dirs[0];
      }
    } else {
      if (Directory("/storage/emulated/0/Documents").existsSync()) {
        debugPrint("Device storage directory already exists");
      }
      try {
        dir = Directory("/storage/emulated/0/Documents");
      } catch (e) {
        dir = Directory("/storage/emulated/0/Documents");
      }
    }

    if (!Directory("${dir!.path}/$appName").existsSync()) {
      Directory("${dir!.path}/$appName").createSync(recursive: true);
      root = "${dir!.path}/$appName";
      debugPrint("The root directory: $root");
    } else {
      debugPrint("The root directory already exists");
      root = "${dir!.path}/$appName";
      debugPrint("The root directory: $root");
    }
    return root;
  }

  Future<Map<String, dynamic>> processImage({required String path, required List<String> correctAnswers}) async{
    // return await _processImage({"path": path, "correct_answers": correctAnswers});
    resultStreamController = StreamController();
    mainSendPort.send({"path": path, "correct_answers": correctAnswers});
    var result = resultStreamController!.stream.first;
    return await mainReceivePort.first;
  }

  Future<List<List<double>>> detectCorners({required var frame}) async{
    debugPrint("Detecting Corners in isolate");
    List<List<double>> result = [];
    try {
      resultStreamController = StreamController();
      mainSendPort.send({"frame": frame , 'process':'DETECT_CORNERS'});
      debugPrint("Running stream");
      result = await resultStreamController!.stream.first;// as Future<List<Map<String, dynamic>?>>;
      debugPrint("Trying to close stream");
      resultStreamController!.close();
      resultStreamController = null;
    } catch(e) {
      debugPrint("$e");
      debugPrint("Failed to close the stream");
    }

    debugPrint("(detected corners) Returning $result from detectCorners");
    return result;
  }

  Future<double?> addNumbers({required double num1, required double num2}) async{
    debugPrint("Detecting Corners in isolate");
    double? result;
    try {
      resultStreamController = StreamController();
      mainSendPort.send({"num_1": num1, "num_2": num2, 'process':'ADD_NUMBERS'});
      debugPrint("Running stream");
      result = await resultStreamController!.stream.first;// as Future<List<Map<String, dynamic>?>>;
      debugPrint("Trying to close stream");
      resultStreamController!.close();
      resultStreamController = null;
    } catch(e) {
      debugPrint("$e");
      debugPrint("Failed to close the stream");
    }
    debugPrint("(added numbers) Returning $result from detectCorners");
    return result;
  }

  /**
   * Image matching functions
   */

  /// load feature descriptors from images in a specified directory
  Future<dynamic> loadDescriptors({required String srcPath}) async {
    //todo: terminate function if images from srcPath have already been loaded

    String dstPath = await getRootDirectory();
    imageNames = await copyFilesBetweenDirectories(srcPath, dstPath);
    debugPrint("Loading descriptors in isolate");
    var result;
    try {
      resultStreamController = StreamController();
      mainSendPort.send({"images_path": dstPath , 'process':'LOAD_DESCRIPTORS'});
      debugPrint("Running stream");
      result = await resultStreamController!.stream.first;// as Future<List<Map<String, dynamic>?>>;
      debugPrint("Trying to close stream");
      resultStreamController!.close();
      resultStreamController = null;
    } catch(e) {
      debugPrint("$e");
      debugPrint("Failed to close the stream");
    }
    debugPrint("(Loaded descriptors) Returning $result from loadDescriptors");
    return result;
  }

  Future<dynamic> findBestMatch({required var frame}) async{
    debugPrint("Finding Best Match in isolate");
    int result = -1;
    try {
      resultStreamController = StreamController();
      mainSendPort.send({"frame": frame , 'process':'FIND_BEST_MATCH'});
      debugPrint("Running stream");
      result = await resultStreamController!.stream.first;
      debugPrint("Trying to close stream");
      resultStreamController!.close();
      resultStreamController = null;
    } catch(e) {
      debugPrint("$e");
      debugPrint("Failed to close the stream");
    }

    debugPrint("(Process complete) Returning $result from findBestMatch");

    if(result == -1 || imageNames.isEmpty) {
      if(imageNames.isEmpty) {
        debugPrint("***Image names are empty: Returning null");
      } else {
        debugPrint("***Result is -1: Returning null");
      }
      return null;
    }else {
      try{
        return imageNames[result];
      }catch(e) {
        debugPrint("$e");
        return null;
      }
    }

  }

  void close() {
    return;
    try{
      resultStreamController!.close();
      resultStreamController = null;
      debugPrint("Successfully closed result stream controller");
    }catch(e) {
      debugPrint("$e");
    }
  }
}

Future<List<String>> copyFilesBetweenDirectories(String sourceDir, String destinationDir) async {
  List<String> imageNames = [];
  try {
    final sourceDirectory = Directory(sourceDir);
    final destinationDirectory = Directory(destinationDir);

    // Ensure that the source directory exists
    if (!await sourceDirectory.exists()) {
      throw Exception('Source directory does not exist.');
    }

    // Ensure that the destination directory exists; create it if not.
    if (!await destinationDirectory.exists()) {
      await destinationDirectory.create(recursive: true);
    }

    // List all files in the source directory
    final files = await sourceDirectory.list().toList();
    if(files.isEmpty) {
      debugPrint("There are no files found in the source directory");
    }

    // Copy each file to the destination directory
    for (final file in files) {
      if (file is File) {
        final fileName = file.uri.pathSegments.last;
        final destinationFile = File('${destinationDirectory.path}/$fileName');
        await file.copy(destinationFile.path);
        imageNames.add(fileName.substring(0, fileName.indexOf(".")));
      }
    }

    debugPrint("Successfully copied ${imageNames.length} files");

  } catch (e) {
    debugPrint('Error: $e');
    return [];
  }

  return imageNames;
}


Future<void> getStoragePermission() async {
  DeviceInfoPlugin plugin = DeviceInfoPlugin();
  AndroidDeviceInfo android = await plugin.androidInfo;
  if (android.version.sdkInt < 33) {
    if (await Permission.storage.request().isGranted) {
      debugPrint("Permission granted");
    } else if (await Permission.storage.request().isPermanentlyDenied) {
      await openAppSettings();
    } else if (await Permission.photos.request().isDenied) {
      debugPrint("Permission is DENIED");
    }
  } else {
    if (await Permission.photos.request().isGranted) {
        debugPrint("Permission GRANTED");
    } else if (await Permission.photos.request().isPermanentlyDenied) {
      await openAppSettings();
    } else if (await Permission.photos.request().isDenied) {
      debugPrint("Permission is DENIED");
    }
  }
}




