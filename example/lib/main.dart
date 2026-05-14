import 'package:flutter/material.dart';
import 'package:flutter_uplay/u_play_controller.dart';
import 'package:flutter_uplay/u_play_widget.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: const PlayPage(),
      ),
    );
  }
}

class PlayPage extends StatefulWidget {
  const PlayPage({super.key});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  final PlayController controller = PlayController();

  @override
  void initState() {
    // TODO: implement initState
    controller.playFile('http://vjs.zencdn.net/v/oceans.mp4');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return UPlayWidget(controller: controller);
  }
}

class PlayController with UPlayController {
  @override
  Future<dynamic> willPlay() async {
    // TODO: implement willPlay
    debugPrint('willPlay');
  }

  @override
  Future<dynamic> startPlay(VideoPlayerController ctr) async {
    // TODO: implement startPlay
    debugPrint('startPlay');
  }

  @override
  void abnormalPlay(Object error) {
    // TODO: implement abnormalPlay
    debugPrint('abnormalPlay');
  }

  @override
  void brightnessDragStart() {
    // TODO: implement brightnessDragStart
    debugPrint('brightnessDragStart');
  }

  @override
  void gestureDragEnd() {
    // TODO: implement gestureDragEnd
    debugPrint('gestureDragEnd');
  }

  @override
  void playerStateChange(VideoPlayerValue value) {
    // TODO: implement playerStateChange
    debugPrint('playerStateChange');
  }

  @override
  void playRewind() {
    // TODO: implement rewindVideo
    debugPrint('rewindVideo');
  }

  @override
  void playForward() {
    // TODO: implement fastForwardVideo
    debugPrint('fastForwardVideo');
  }

  @override
  void volumeDragStart() {
    // TODO: implement volumeDragStart
    debugPrint('volumeDragStart');
  }
}
