import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';

mixin UPlayController {
  BuildContext? playContext;
  UPlayConfig? playConfig;
  Timer? _makeTimer;
  bool isGesOperating = false; //是否正在手势操作
  ValueNotifier<bool> isLoading = ValueNotifier(false); //是否加载
  ValueNotifier<bool> isPlaying = ValueNotifier(false); //是否播放
  ValueNotifier<bool> showMake = ValueNotifier(false); //是否显示工具
  ValueNotifier<double> playSpeed = ValueNotifier(1.0); //播放速度
  ValueNotifier<double> playVolume = ValueNotifier(1.0); //视频声音
  ValueNotifier<double> playBrightness = ValueNotifier(1.0); //视频亮度
  VideoPlayerController? playerController; //控制器

  //播放配置
  UPlayConfig get _cf => playConfig ?? UPlayConfig();

  /*将要播放*/
  Future<dynamic> willPlay();

  /*开始播放*/
  Future<dynamic> startPlay(VideoPlayerController ctr);

  /*异常播放*/
  void abnormalPlay(Object error);

  /*播放状态变化*/
  void playerStateChange(VideoPlayerValue value);

  /*快退视频*/
  void playRewind();

  /*快进视频*/
  void playForward();

  /*声音滑动开始*/
  void volumeDragStart();

  /*亮度滑动开始*/
  void brightnessDragStart();

  /*手势滑动结束*/
  void gestureDragEnd();

  /// 资源释放 页面销毁需要调用
  Future dispose({bool isExit = true}) async {
    playerController?.removeListener(_playerControllerListener);
    await playerController?.dispose();
    playerController = null;
    if (isExit == false) return;
    await SystemChrome.setPreferredOrientations([.portraitUp]);
    _makeTimer?.cancel();
    _makeTimer == null;
    isLoading.dispose();
    isPlaying.dispose();
    showMake.dispose();
    playSpeed.dispose();
    playVolume.dispose();
    playBrightness.dispose();
  }

  /// 播放文件
  Future<dynamic> playFile(String path, {int? position}) async {
    try {
      await willPlay();
      await dispose(isExit: false);
      showMake.value = true;
      isLoading.value = true;
      if (path.startsWith('http')) {
        playerController = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        playerController = VideoPlayerController.file(File(path));
      }
      await playerController?.initialize();
      final duration = playerController!.value.position.inSeconds;
      playerController?.setPlaybackSpeed(playSpeed.value);
      if (position != null && position + 2 < duration) {
        playerController?.seekTo(Duration(seconds: position));
      }
      playerController?.play();
      startPlay(playerController!);
    } catch (e) {
      abnormalPlay(e);
    } finally {
      showMake.value = false;
      isLoading.value = false;
    }
  }

  /// 播放暂停
  void filePlayPause() {
    if (playerController?.value.isInitialized == false) return;
    if (playerController?.value.isPlaying == true) {
      playerController?.pause();
      isPlaying.value = false;
    } else {
      playerController?.play();
      isPlaying.value = true;
      // 播放时5秒后隐藏控制条
      _hideToolbar();
    }
  }

  /// 全屏点击
  void fullScreenOnTap() {
    if (playContext == null) return;
    final orientation = MediaQuery.orientationOf(playContext!);
    if (orientation == .portrait) {
      SystemChrome.setPreferredOrientations([.landscapeRight]);
    } else {
      SystemChrome.setPreferredOrientations([.portraitUp]);
    }
  }

  /// 更新播放速度
  void updatePlaySpeed(double value) {
    playSpeed.value = value;
    playerController?.setPlaybackSpeed(value);
  }

  /// 单击显示隐藏操作组建
  void playOnTap() {
    showMake.value = !showMake.value;
    if (showMake.value) _hideToolbar();
  }

  /// 处理屏幕双击事件
  void playDoubleTapDown(TapDownDetails details) {
    if (playerController?.value.isInitialized == false) return;
    final width = MediaQuery.sizeOf(playContext!).width;
    final dx = details.localPosition.dx;
    if (dx < width * _cf.leftSpacing) {
      playRewind();
    } else if (dx > width * _cf.rightSpacing) {
      playForward();
    } else {
      filePlayPause();
    }
  }

  /// 垂直滑动开始
  void playPanStart(DragStartDetails details) async {
    isGesOperating = true;
    final dx = details.localPosition.dx;
    final width = MediaQuery.sizeOf(playContext!).width;
    if (dx < width * _cf.leftSpacing) {
      playVolume.value = await VolumeController.instance.getVolume();
      volumeDragStart();
    } else if (dx > width * _cf.rightSpacing) {
      playBrightness.value = await ScreenBrightness.instance.application;
      brightnessDragStart();
    }
  }

  /// 滑动更新
  void playPanUpdate(DragUpdateDetails details) {
    final dx = details.localPosition.dx;
    final width = MediaQuery.sizeOf(playContext!).width;
    if (dx < width * _cf.leftSpacing) {
      _updatePlayVolume(details.delta.dy);
    } else if (dx > width * _cf.rightSpacing) {
      _updatePlayBrightness(details.delta.dy);
    }
  }

  /// 滑动结束
  void playPanEnd(DragEndDetails details) {
    isGesOperating = false;
    gestureDragEnd();
  }

  /// 长按开始（快速播放）
  void playLongPressStart(LongPressStartDetails details) {
    if (playerController?.value.isInitialized == false) return;
    if (playSpeed.value == _cf.speedMax) return;
    final width = MediaQuery.sizeOf(playContext!).width;
    final dx = details.localPosition.dx;
    final canForward =
        dx < width * _cf.leftSpacing || dx > width * _cf.rightSpacing;
    if (canForward) {
      playSpeed.value = _cf.speedMax;
      playerController?.setPlaybackSpeed(_cf.speedMax);
    }
  }

  /// 播放监听
  void _playerControllerListener() {
    if (playerController?.value.isInitialized == false) return;
    isPlaying.value = playerController?.value.isPlaying ?? false;
    playerStateChange(playerController!.value);
  }

  /// 调整屏幕亮度
  void _updatePlayBrightness(double dy) {
    double brightness = playBrightness.value;
    brightness = (brightness - dy * _cf.brightnessRatio).clamp(0.0, 1.0);
    playBrightness.value = brightness;
    ScreenBrightness.instance.setApplicationScreenBrightness(brightness);
  }

  /// 调整音量
  void _updatePlayVolume(double dy) {
    double volume = playVolume.value;
    volume = (volume - dy * _cf.volumeRatio).clamp(0.0, 1.0);
    playVolume.value = volume;
    VolumeController.instance.setVolume(volume);
  }

  /// 隐藏工具栏
  void _hideToolbar() {
    if (showMake.value == false) return;
    _makeTimer?.cancel();
    _makeTimer = null;
    _makeTimer = Timer(Duration(seconds: _cf.makTime), () {
      if (isGesOperating == true) {
        _hideToolbar();
      } else {
        showMake.value = false;
      }
    });
  }
}

class UPlayConfig {
  double leftSpacing = 0.3; //左边界限
  double rightSpacing = 0.7; //右边界限
  double brightnessRatio = 0.005; //亮度滑动比例
  double volumeRatio = 0.005; //声音滑动比例
  double speedMax = 2.0; //播放速度最大值
  int makTime = 5; //遮罩时间
}
