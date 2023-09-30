import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, required this.url});
  final String url;
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? controller;
  @override
  void initState() {
    initVideoPlayer();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            heroTag: 2,
            onPressed: () {
              controller?.pause();
            },
            child: Icon(Icons.pause),
          ),
          FloatingActionButton(
            heroTag: 1,
            onPressed: () async{
              await controller?.play();
              setState(() {
                
              });
            },
            child: Icon(Icons.play_arrow),
          ),
          FloatingActionButton(
            heroTag: 15,
            onPressed: () {
              getInfo();
            },
            child: Icon(Icons.info),
          ),
        ],
      ),
      body: Center(
        child: controller?.value.isInitialized??false
            ? 
            VideoPlayer(controller!)
            : const Center(
                child: CircularProgressIndicator(),
              ),
      ),
    );
  }

  getInfo() async {
    await FFprobeKit.getMediaInformation(
            '/data/user/0/com.example.file_merger/cache/big_buck_bunny_240p_10mb.mp4')
        .then((session) async {
      final information = session.getMediaInformation();

      if (information == null) {
        // CHECK THE FOLLOWING ATTRIBUTES ON ERROR
        final state =
            FFmpegKitConfig.sessionStateToString(await session.getState());
        final returnCode = await session.getReturnCode();
        final failStackTrace = await session.getFailStackTrace();
        final duration = await session.getDuration();
        final output = await session.getOutput();
        debugPrint('''
state:$state
returnCode:$returnCode
failStackTrace:$failStackTrace
duration:$duration
output:$output
''');
      }
    });
  }

  initVideoPlayer() async {
    File file = File(
        '/data/user/0/com.example.file_merger/cache/big_buck_bunny_240p_10mb.mp4');
    // controller = VideoPlayerController.asset(
    //     '/data/user/0/com.example.file_merger/cache/big_buck_bunny_240p_10mb.mp4')
      // ..initialize();
    controller = VideoPlayerController.file(file)..initialize();
    setState(() {});
  }
}
