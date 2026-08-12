import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:video_player/video_player.dart';

mixin UPlayController {
  BuildContext? playContext;
  UPlayConfig? playConfig;
  Timer? _makeTimer;
  bool isInitialize = false; //是否正初始化
  bool isGesOperating = false; //是否正在手势操作
  ValueNotifier<bool> isPlaying = ValueNotifier(false); //是否播放
  ValueNotifier<bool> showMake = ValueNotifier(false); //是否显示工具
  ValueNotifier<double> playSpeed = ValueNotifier(1.0); //播放速度
  ValueNotifier<double> playVolume = ValueNotifier(1.0); //视频声音
  ValueNotifier<double> playBrightness = ValueNotifier(1.0); //视频亮度
  CachedVideoPlayerPlus? playerController; //控制器

  //播放配置
  UPlayConfig get _cf => playConfig ?? UPlayConfig();

  /*将要播放*/
  Future<String> willPlayFile();

  /*开始播放*/
  void startPlayFile(VideoPlayerController ctr);

  /*异常播放*/
  void abnormalPlayFile(Object error);

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
    playerController?.controller.removeListener(_playerControllerListener);
    await playerController?.dispose();
    playerController = null;
    if (isExit == false) return;
    await SystemChrome.setPreferredOrientations([.portraitUp]);
    _makeTimer?.cancel();
    _makeTimer == null;
    isPlaying.dispose();
    showMake.dispose();
    playSpeed.dispose();
    playVolume.dispose();
    playBrightness.dispose();
  }

  /// 播放文件
  Future<dynamic> playFile({int? position}) async {
    try {
      isInitialize = true;
      await dispose(isExit: false);
      final path = await willPlayFile();
      if (path.startsWith('http')) {
        playerController = CachedVideoPlayerPlus.networkUrl(Uri.parse(path));
      } else {
        playerController = CachedVideoPlayerPlus.file(File(path));
      }
      await playerController?.initialize();
      playerController?.controller.addListener(_playerControllerListener);
      final duration = playerController!.controller.value.position.inSeconds;
      playerController?.controller.setPlaybackSpeed(playSpeed.value);
      if (position != null && position + 2 < duration) {
        playerController?.controller.seekTo(Duration(seconds: position));
      }
      playerController?.controller.play();
      startPlayFile(playerController!.controller);
    } catch (e) {
      abnormalPlayFile(e);
    } finally {
      _hideToolbar();
      isInitialize = false;
    }
  }

  /// 播放暂停
  void filePlayPause() {
    if (playerController?.controller.value.isInitialized == false) return;
    if (playerController?.controller.value.isPlaying == true) {
      playerController?.controller.pause();
      isPlaying.value = false;
    } else {
      playerController?.controller.play();
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
    playerController?.controller.setPlaybackSpeed(value);
  }

  /// 单击显示隐藏操作组建
  void playOnTap() {
    showMake.value = !showMake.value;
    if (showMake.value) _hideToolbar();
  }

  /// 处理屏幕双击事件
  void playDoubleTapDown(TapDownDetails details) {
    if (playerController?.controller.value.isInitialized == false) return;
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
      playBrightness.value = await ScreenBrightness.instance.application;
      brightnessDragStart();
    } else if (dx > width * _cf.rightSpacing) {
      playVolume.value = await VolumeController.instance.getVolume();
      volumeDragStart();
    }
  }

  /// 滑动更新
  void playPanUpdate(DragUpdateDetails details) {
    final dx = details.localPosition.dx;
    final width = MediaQuery.sizeOf(playContext!).width;
    if (dx < width * _cf.leftSpacing) {
      _updatePlayBrightness(details.delta.dy);
    } else if (dx > width * _cf.rightSpacing) {
      VolumeController.instance.showSystemUI = false;
      _updatePlayVolume(details.delta.dy);
    }
  }

  /// 滑动结束
  void playPanEnd(DragEndDetails details) {
    isGesOperating = false;
    gestureDragEnd();
  }

  /// 长按开始（快速播放）
  void playLongPressStart(LongPressStartDetails details) {
    if (playerController?.controller.value.isInitialized == false) return;
    if (playSpeed.value == _cf.speedMax) return;
    final width = MediaQuery.sizeOf(playContext!).width;
    final dx = details.localPosition.dx;
    final canForward =
        dx < width * _cf.leftSpacing || dx > width * _cf.rightSpacing;
    if (canForward) {
      playSpeed.value = _cf.speedMax;
      playerController?.controller.setPlaybackSpeed(_cf.speedMax);
    }
  }

  /// 播放监听
  void _playerControllerListener() {
    if (isInitialize == true) return;
    isPlaying.value = playerController?.controller.value.isPlaying ?? false;
    playerStateChange(playerController!.controller.value);
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
