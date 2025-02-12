import 'package:aj_traslator/Screens/vision_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../Constants.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  late OnDeviceTranslator onDeviceTranslator;
  final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
  final modelManager = OnDeviceTranslatorModelManager();
  bool isTranslatorReady = false;
  TextEditingController inputController = TextEditingController();
  var resultText = "Translated Text";
  TranslateLanguage sourceLanguage = TranslateLanguage.english;
  TranslateLanguage targetLanguage = TranslateLanguage.french;
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  FlutterTts flutterTts = FlutterTts();
  String selectedLocaleId = "en_US";

  @override
  void initState() {
    super.initState();
    isModelDownloaded();
    onDeviceTranslator = OnDeviceTranslator(
        sourceLanguage: sourceLanguage, targetLanguage: targetLanguage);
    _initSpeech();
    getLanguages();
  }

  List<LocaleName> locales = [];
  getLanguages() async {
    locales = await _speechToText.locales();
    for (var item in locales) {
      print("Language = ${item.name} ${item.localeId}");
    }

    List<dynamic> languages = await flutterTts.getLanguages;
    for (var item in languages) {
      print("tts language ${item.toString()}");
    }

    await flutterTts.setVoice({"name": "Thomas", "locale": "fr-FR"});

    List<dynamic> voices = await flutterTts.getVoices;
    for (var item in voices) {
      print("voice ${item.toString()}");
    }
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(
        onResult: _onSpeechResult, localeId: selectedLocaleId);
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  /// This is the callback that the SpeechToText plugin calls when
  /// the platform returns recognized words.
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      inputController.text = result.recognizedWords;
      performTranslation();
    });
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
      onDeviceTranslator = OnDeviceTranslator(
          sourceLanguage: sourceLanguage, targetLanguage: targetLanguage);
      if (Constants.languagesMap.containsKey(sourceLanguage.name) &&
          isRecognitionSupported(
              Constants.languagesMap[sourceLanguage.name]!)) {
        selectedLocaleId = Constants.languagesMap[sourceLanguage.name]!;
      } else {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: Text("Speech Recognition"),
                  content: Text(
                      "Speech Recognition is not available for ${sourceLanguage.name}. Kindly download this language in your device to use speech recognition"),
                ));
      }
      flutterTts.setLanguage(Constants.languagesMapTTS[targetLanguage.name]!);
    }
  }

  isRecognitionSupported(String localeId) {
    return locales.any((item) => item.localeId == localeId);
  }

  performTranslation() async {
    if (!isTranslatorReady) {
      return;
    }

    resultText = await onDeviceTranslator.translateText(inputController.text);
    setState(() {
      resultText;
    });
  }

  detectLanguage(String text) async {
    String lang = await languageIdentifier.identifyLanguage(text);
    sourceLanguage = TranslateLanguage.values.firstWhere((item) {
      return item.bcpCode == lang;
    }, orElse: () => TranslateLanguage.english);
    await isModelDownloaded();
    performTranslation();
    print("Language detected $lang");
  }

  bool isDetection = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          "Translator",
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        actions: [
          Switch(
            value: isDetection,
            onChanged: (value) {
              setState(() {
                isDetection = value;
              });
            },
            activeColor: Colors.green,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Expanded(
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      maxLines: 10,
                      style: TextStyle(fontSize: 20),
                      decoration: InputDecoration(
                          hintText: "Enter your text",
                          border: InputBorder.none,
                          hintStyle: TextStyle(fontSize: 20)),
                      controller: inputController,
                      onChanged: (text) {
                        if (isDetection) {
                          detectLanguage(text);
                        } else {
                          performTranslation();
                        }
                      },
                    ),
                  ),
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(
                  child: Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton(
                          items: TranslateLanguage.values.map((item) {
                            return DropdownMenuItem(
                                value: item, child: Text(item.name));
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
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton(
                          items: TranslateLanguage.values.map((item) {
                            return DropdownMenuItem(
                                value: item, child: Text(item.name));
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
              ]),
              Expanded(
                  child: Card(
                color: Colors.white,
                child: Stack(children: [
                  SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SingleChildScrollView(
                          child: Text(
                            resultText,
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      )),
                  Align(
                    alignment: Alignment.topRight,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50)),
                              color: Colors.blue.shade900,
                              child: InkWell(
                                onTap: () {
                                  if (resultText.isNotEmpty) {
                                    Clipboard.setData(
                                        ClipboardData(text: resultText));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Copied!"),
                                        ));
                                  }
                                },
                                child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Icon(
                                      Icons.copy,
                                      size: 20,
                                      color: Colors.white,
                                    )),
                              )),
                          Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50)),
                              color: Colors.blue.shade900,
                              child: InkWell(
                                onTap: () {
                                  flutterTts.speak(resultText);
                                },
                                child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Icon(
                                      Icons.record_voice_over,
                                      size: 20,
                                      color: Colors.white,
                                    )),
                              )),
                        ]),
                  ),
                ]),
              )),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                    color: Colors.blue.shade900,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => VisionScreen(ImageSource.gallery, onDeviceTranslator)));
                      },
                      child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.image,
                            size: 20,
                            color: Colors.white,
                          )),
                    )),
                Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                    color: Colors.blue.shade900,
                    child: InkWell(
                      onTap: () {
                        _startListening();
                      },
                      child: SizedBox(
                          width: 60,
                          height: 60,
                          child: Icon(
                            Icons.mic,
                            size: 30,
                            color: Colors.white,
                          )),
                    )),
                Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50)),
                    color: Colors.blue.shade900,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => VisionScreen(ImageSource.camera, onDeviceTranslator)));
                      },
                      child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 20,
                            color: Colors.white,
                          )),
                    )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
