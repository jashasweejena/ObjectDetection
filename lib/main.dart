import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

void main() => runApp(MyApp());

const String ssd = "SSD Mobile Net";
const String yolo = "Tiny YOLOv2";

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TfLiteHome(),
    );
  }
}

class TfLiteHome extends StatefulWidget {
  @override
  _TfLiteHomeState createState() => _TfLiteHomeState();
}

class _TfLiteHomeState extends State<TfLiteHome> {
  String _model = yolo;
  File _image;

  double _imageWidth;
  double _imageHeight;
  bool _busy = false;
  var _recognitions;

  @override
  void initState() {
    super.initState();
    _busy = true;
    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try {
      String response;
      switch (_model) {
        case yolo:
          response = await Tflite.loadModel(
              model: 'assets/tflite/yolov2_tiny.tflite',
              labels: 'assets/tflite/yolov2_tiny.txt');
          break;
        case ssd:
          response = await Tflite.loadModel(
              model: 'assets/tflite/ssd_mobilenet.tflite',
              labels: 'assets/tflite/ssd_mobilenet.txt');
      }
      print(response);
    } on PlatformException {
      print("Failed to load the model.");
    }
  }

  selectFromImagePicker() async {
    var image = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _busy = true;
    });
    predictImage(image);
  }

  predictImage(File image) async {
    if (image == null) return;
    switch (_model) {
      case yolo:
        await yolov2Tiny(image);
        break;
      case ssd:
        await ssdMobileNet(image);
    }

    FileImage(image)
        .resolve(ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool _) {
      setState(() {
        _imageWidth = info.image.width.toDouble();
        _imageHeight = info.image.height.toDouble();
      });
    }));

    setState(() {
      _image = image;
      _busy = false;
    });
  }

  yolov2Tiny(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      model: yolo,
      threshold: 0.5,
      imageMean: 0.0,
      imageStd: 255.0,
      numResultsPerClass: 1,
    );
    setState(() {
      _recognitions = recognitions;
    });
  }

  ssdMobileNet(File image) async {
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1,
      threshold: 0.5,
    );
    setState(() {
      _recognitions = recognitions;
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = screen.width;
    double factorY = _imageHeight / _imageWidth * screen.width;

    Color blue = Colors.blue;
    Color red = Colors.red;

    return _recognitions.map<Widget>((recognition) {
      return Positioned(
        left: recognition["rect"]["x"] * factorX,
        top: recognition["rect"]["y"] * factorY,
        width: recognition["rect"]["w"] * factorX,
        height: recognition["rect"]["h"] * factorY,
        child: Container(
            decoration:
                BoxDecoration(border: Border.all(color: blue, width: 3.0)),
            child: Text(
              "${recognition["detectedClass"]} ${(recognition["confidenceInClass"] * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                background: Paint()..color = blue,
                color: Colors.white,
                fontSize: 15.0,
              ),
            )),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];

    stackChildren.add(Positioned(
      top: 0.0,
      left: 0.0,
      width: size.width,
      child: _image == null ? Text("No image selected") : Image.file(_image),
    ));

    stackChildren.addAll(renderBoxes(size));

    if (_busy) {
      stackChildren.add(Center(
        child: CircularProgressIndicator(),
      ));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("TfLite Demo"),
        actions: <Widget>[
          FlatButton(
              onPressed: () {
                _busy = true;
                Tflite.close();
                setState(() {
                  _model = yolo;
                });
                loadModel().then((val) {
                  setState(() {
                    _busy = false;
                  });
                });
              },
              child: Text("YOLO")),
          FlatButton(
            onPressed: () {
              _busy = true;
              Tflite.close();
              setState(() {
                _model = ssd;
              });
              loadModel().then((val) {
                setState(() {
                  _busy = false;
                });
              });
            },
            child: Text("SSD"),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.image),
          tooltip: "Pick image from gallery!",
          onPressed: selectFromImagePicker),
      body: Stack(
        children: stackChildren,
      ),
    );
  }
}
