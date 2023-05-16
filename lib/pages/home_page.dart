
import 'dart:async';

import 'package:dialogflow_grpc/dialogflow_grpc.dart';
import 'package:dialogflow_grpc/generated/google/cloud/dialogflow/v2beta1/session.pb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dialogflow/widget/chat_bubble.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {


  // message text controller
  final TextEditingController _textController = TextEditingController();

  // list of message that will displayed on the screen
  final List<ChatMessage> _messages = <ChatMessage>[];

  // for changing recording icon
  bool _isRecording = false;

  late final SpeechToText speechToText;
  late StreamSubscription _recorderStatus;
  late StreamSubscription<List<int>> _audioStreamSubscription;
  late DialogflowGrpcV2Beta1 dialogFlow;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initPlugin();
  }

  Future<void> _initPlugin() async
  {
    // initialize speech to text plugin
    speechToText = SpeechToText();

    // required for setting up dialogflow.
    final serviceAccount = ServiceAccount.fromString(
      await rootBundle.loadString("assets/cred.json")
    );

    // dialogflow setup
    dialogFlow = DialogflowGrpcV2Beta1.viaServiceAccount(serviceAccount);
    setState(() {});

    // Initialize speech recognition services, returns true if successful, false if failed;
    await speechToText.initialize(
      options: [SpeechToText.androidIntentLookup]
    ); 

  }

  void stopStream() async{
    await _audioStreamSubscription.cancel();
  }

  void _handleSubmitted(String text) async{
    _textController.clear();

    ChatMessage message = ChatMessage(
      text: text,
      name: "You",
      type: true,
    );

    setState(() {
      _messages.insert(0,message);
    });

    // calling dialogflow api
    DetectIntentResponse data = await dialogFlow.detectIntent(text, 'en-US');

    // getting meaningful response text
    String fulfillmentText = data.queryResult.fulfillmentText;
    if(fulfillmentText.isNotEmpty)
    {
      ChatMessage botMessage = ChatMessage(
        text: fulfillmentText,
        name: 'Bot',
        type: false,
      );

      setState(() {
        _messages.insert(0, botMessage);
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) async
  {
    String lastWords = result.recognizedWords;

    // setting textediting controller to the speech value and cursor at the end
    _textController.text = lastWords;
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length
      );
    
    setState(() {
      _isRecording = false;
    });

    await Future.delayed(const Duration(seconds: 5));
    _stopListening();
  }

  void _handleStream() async
  {
    setState(() {
        _isRecording = true;
    });

    await speechToText.listen(
      onResult: _onSpeechResult
    );
  }

  void _stopListening() async
  {
    await speechToText.stop();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _recorderStatus.cancel();
    _audioStreamSubscription.cancel();
    speechToText.stop();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
 
  return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade400,
        title: const Text('Dialogflow Tutorial',
        style: TextStyle(
          color: Colors.white
        ),),
      ),
      body: Center(
        child: Column(
          children: [
            Flexible(child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: ((context, index) => _messages[index]))),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(10.0)
                ),
                margin: const EdgeInsets.symmetric(horizontal: 15,vertical: 15),
                child: Row(
                  children: [
                    Flexible(
                      child: TextField(
                        controller: _textController,
                        onSubmitted: _handleSubmitted,
                      )),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: IconButton(onPressed: (){
                          _handleSubmitted(_textController.text);
                        }, icon: const Icon(Icons.send))
                      ),
                      IconButton(onPressed: (){
                        _handleStream();
                      }, icon: Icon(_isRecording ? Icons.mic : Icons.mic_off ) )
                  ],
                ),
              )
          ],
        ),
      ),
       // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
