import 'dart:io';
import 'dart:math';

import 'package:aj_traslator/Models/Recognition.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class VisionScreen extends StatefulWidget {
  ImageSource imageSource;
  OnDeviceTranslator onDeviceTranslator;

  VisionScreen(this.imageSource, this.onDeviceTranslator, {super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  final ImagePicker picker = ImagePicker();
  File? selectedImage;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  var resultText = "Result Text";
  List<Recognition> recognitions = [];
  final modelManager = OnDeviceTranslatorModelManager();
  bool isTranslatorReady = false;
  TranslateLanguage sourceLanguage = TranslateLanguage.english;
  TranslateLanguage targetLanguage = TranslateLanguage.french;
  var currentSelection = "Translated";
  double fontSize = 14.0;
  var image;
  late RecognizedText recognizedText;

  @override
  void initState() {
    super.initState();
    chooseImage();
  }

  chooseImage() async {
    final XFile? image = await picker.pickImage(source: widget.imageSource);
    if (image != null) {
      selectedImage = File(image.path);
      showEditedImage();
      performTextRecognition();
      setState(() {});
    }
  }

  showEditedImage() async {
    var bytes = await selectedImage!.readAsBytes();
    image = await decodeImageFromList(bytes);
    setState(() {
      image;
    });
  }

  performTextRecognition() async {
    InputImage inputImage = InputImage.fromFilePath(selectedImage! as String);
    recognizedText = await textRecognizer.processImage(inputImage);

    String text = recognizedText.text;
    setState(() {
      resultText = text;
    });
    performTranslation(text);
    performTranslationLineByLine();
  }

  performTranslationLineByLine() async {
    for (TextBlock block in recognizedText.blocks) {
      final Rect rect = block.boundingBox;
      final List<Point<int>> cornerPoints = block.cornerPoints;
      final String text = block.text;
      final List<String> languages = block.recognizedLanguages;

      for (TextLine line in block.lines) {
        // Same getters as TextBlock
        recognitions.add(
            Recognition(await performTranslation(line.text), line.boundingBox));
        setState(() {
          recognitions;
        });
        for (TextElement element in line.elements) {
          // Same getters as TextBlock
        }
      }
    }
  }

  performTranslation(String text) async {
    return await widget.onDeviceTranslator.translateText(text);
  }

  isModelDownloaded() async {
    bool isSourceDownloaded =
        await modelManager.isModelDownloaded(sourceLanguage.bcpCode);
    bool isTargetDownloaded =
        await modelManager.isModelDownloaded(targetLanguage.bcpCode);

    if (isSourceDownloaded && isTargetDownloaded) {
      isTranslatorReady = true;
    } else {
      if (!isSourceDownloaded) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Downloading ${sourceLanguage.name}"),
        ));
        isSourceDownloaded =
            await modelManager.downloadModel(sourceLanguage.bcpCode);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Downloaded ${sourceLanguage.name}"),
        ));
      }
      if (!isTargetDownloaded) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Downloading ${targetLanguage.name}"),
        ));
        isTargetDownloaded =
            await modelManager.downloadModel(targetLanguage.bcpCode);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Downloaded ${targetLanguage.name}"),
        ));
      }

      if (isSourceDownloaded && isTargetDownloaded) {
        isTranslatorReady = true;
      }
    }

    if (isTranslatorReady) {
      widget.onDeviceTranslator = OnDeviceTranslator(
          sourceLanguage: sourceLanguage, targetLanguage: targetLanguage);
      performTranslationLineByLine();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: Column(children: [
          Container(
            margin: EdgeInsets.only(top: 25),
            child: AnimatedToggleSwitch<String>.size(
              textDirection: TextDirection.rtl,
              current: currentSelection,
              values: const ["Original", "Translated"],
              indicatorSize: const Size.fromWidth(140),
              iconBuilder: (value) {
                return Text(
                  value,
                  style: TextStyle(
                      color: value == currentSelection
                          ? Colors.white
                          : Colors.black),
                );
              },
              borderWidth: 0.0,
              iconAnimationType: AnimationType.onHover,
              style: ToggleStyle(
                borderColor: Colors.transparent,
                backgroundColor: Colors.white,
                borderRadius: BorderRadius.circular(15.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              styleBuilder: (i) =>
                  ToggleStyle(indicatorColor: Colors.blue.shade900),
              onChanged: (i) => setState(() => currentSelection = i),
            ),
          ),
          Expanded(
            child: Card(
              margin: EdgeInsets.only(left: 15, right: 15, top: 20, bottom: 20),
              child: Container(
                color: Colors.white,
                width: MediaQuery.of(context).size.width,
                child: image != null
                    ?
                    SizedBox(
                        width: image.width.toDouble(),
                        height: image.height.toDouble(),
                        child: CustomPaint(
                            painter: CustomImagePainter(
                                image: image,
                                recognitions: recognitions,
                                showOriginal: currentSelection == "Original",
                                fontSize: fontSize)))
                    : Icon(
                        Icons.image,
                        size: 200,
                      ),
              ),
            ),
          ),
          Slider(
              label: fontSize.toString(),
              activeColor: Colors.blue.shade900,
              value: fontSize,
              min: 10,
              max: 50,
              divisions: 39,
              onChanged: (value) {
                setState(() {
                  fontSize = value;
                });
              }),
          Container(
            margin: EdgeInsets.only(left: 15, right: 15, top: 0, bottom: 20),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Card(
                      color: Colors.blue.shade900,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton(
                            dropdownColor: Colors.black,
                            alignment: Alignment.center,
                            iconSize: 0,
                            items: TranslateLanguage.values.map((item) {
                              return DropdownMenuItem(
                                value: item,
                                child: Text(item.name,
                                    style: TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (item) {
                              setState(() {
                                sourceLanguage = item!;
                              });
                            },
                            value: sourceLanguage,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Card(
                      color: Colors.blue.shade900,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton(
                              dropdownColor: Colors.black,
                              alignment: Alignment.center,
                              iconSize: 0,
                              items: TranslateLanguage.values.map((item) {
                                return DropdownMenuItem(
                                    value: item,
                                    child: Text(
                                      item.name,
                                      style: TextStyle(color: Colors.white),
                                    ));
                              }).toList(),
                              onChanged: (item) {
                                setState(() {
                                  targetLanguage = item!;
                                });
                              },
                              value: targetLanguage,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
          ),
        ]),
      ),
    );
  }
}

class CustomImagePainter extends CustomPainter {
  dynamic image;
  List<Recognition> recognitions;
  bool showOriginal;
  double fontSize;

  CustomImagePainter(
      {this.image,
      required this.recognitions,
      required this.showOriginal,
      required this.fontSize});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());

    Paint paint = Paint();
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;

    if (showOriginal == false) {
      recognitions.forEach((item) {
        canvas.drawRect(item.boundingBox, paint);
        TextSpan span = TextSpan(
            text: item.translation,
            style: TextStyle(color: Colors.black, fontSize: fontSize));
        TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.left,
            textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(item.boundingBox.left, item.boundingBox.top));
      });
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
