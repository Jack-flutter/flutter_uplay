import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'u_play_controller.dart';

class UPlayWidget extends StatelessWidget {
  final UPlayController controller;

  const UPlayWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    controller.playContext = context;
    return GestureDetector(
      behavior: .opaque,
      onTap: controller.playOnTap,
      onDoubleTapDown: controller.playDoubleTapDown,
      onPanStart: controller.playPanStart,
      onPanEnd: controller.playPanEnd,
      onPanUpdate: controller.playPanUpdate,
      onLongPressStart: controller.playLongPressStart,
      child: Container(
        width: .maxFinite,
        height: .maxFinite,
        color: Colors.black,
        alignment: .center,
        child: controller.playerController == null
            ? const SizedBox.shrink()
            : _buildAspectRatio(),
      ),
    );
  }

  AspectRatio _buildAspectRatio() {
    final play = controller.playerController!.controller;
    return AspectRatio(
      aspectRatio: play.value.aspectRatio,
      child: VideoPlayer(play),
    );
  }
}
