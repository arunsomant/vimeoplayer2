library vimeoplayer;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock/wakelock.dart';
import 'src/quality_links.dart';
import 'dart:async';
import 'src/fullscreen_player.dart';

///holds the viedo controller details
class ControllerDetails {
  int position;
  bool playingStatus;

  ControllerDetails({this.position, this.playingStatus});
}

// Video player class
class VimeoPlayer extends StatefulWidget {
  final String id;
  final bool autoPlay;
  final bool looping;
  final int position;

  ///[commnecingOverlay] decides whether to show overlay when video player loads video, NOTE - It will function only when autoplay is true
  final bool commencingOverlay;
  final Color fullScreenBackgroundColor;

  ///[overlayTimeOut] in seconds: decide after how much second overlay should vanishes, NOTE - minimum 5 seconds of timeout is stacked
  final int overlayTimeOut;

  final Color loadingIndicatorColor;
  final Color controlsColor;

  final String placeholder;

  VimeoPlayer({
    @required this.id,
    this.autoPlay = false,
    this.looping,
    this.position,
    this.commencingOverlay = true,
    this.fullScreenBackgroundColor,
    this.loadingIndicatorColor,
    this.controlsColor,
    this.placeholder,
    int overlayTimeOut = 0,
    Key key,
  })  : this.overlayTimeOut = max(overlayTimeOut, 5),
        super(key: key);

  @override
  _VimeoPlayerState createState() => _VimeoPlayerState(
      id, autoPlay, looping, position, autoPlay ? commencingOverlay : true);
}

class _VimeoPlayerState extends State<VimeoPlayer> {
  String _id;
  bool autoPlay = false;
  bool looping = false;
  bool _overlay = true;
  bool fullScreen = false;
  int position;

  _VimeoPlayerState(
      this._id, this.autoPlay, this.looping, this.position, this._overlay)
      : initialOverlay = _overlay;

  //Custom controller
  VideoPlayerController _controller;
  Future<void> initFuture;

  //Quality Class
  QualityLinks _quality;
  //Map _qualityValues;
  var _qualityValue;

  // Seek variable
  bool _seek = false;

  // Video variables
  double videoHeight;
  double videoWidth;
  double videoMargin;

  // Variables for double-tap zones
  double doubleTapRMargin = 36;
  double doubleTapRWidth = 400;
  double doubleTapRHeight = 160;
  double doubleTapLMargin = 10;
  double doubleTapLWidth = 400;
  double doubleTapLHeight = 160;

  //overlay timeout handler
  Timer overlayTimer;
  //indicate if overlay to be display on commencing video or not
  bool initialOverlay;

  //contains the resolution qualities of vimeo video
  List<MapEntry> _qualityValues = [];
  String _currentResolutionQualityKey;

  // ///Get Vimeo Specific Video Resoltion Quality in number
  // int _videoQualityComparer(String a, String b) {
  //   const pattern = "[0-9]+(?=p)";

  //   final exp = RegExp(pattern);
  //   final q1 = int.tryParse(exp.firstMatch(a)?.group(0)) ?? 0;
  //   final q2 = int.tryParse(exp.firstMatch(b)?.group(0)) ?? 0;

  //   return q1.compareTo(q2);
  // }

  ///Get Vimeo Specific Video Resoltion Quality in number
  int videoQualityComparer(MapEntry me1, MapEntry me2) {
    final k1 = me1.key as String ?? '';
    final k2 = me2.key as String ?? '';

    const pattern = "[0-9]+(?=p)";

    final exp = RegExp(pattern);
    final q1 = int.tryParse(exp.firstMatch(k1)?.group(0)) ?? 0;
    final q2 = int.tryParse(exp.firstMatch(k2)?.group(0)) ?? 0;

    return q1.compareTo(q2);
  }

  @override
  void initState() {
    //Create class
    _quality = QualityLinks(_id);

    // Initialization of video controllers when receiving data from Vimeo
    _quality.getQualitiesSync().then((value) {
      var qualities = value?.entries?.toList();

      if (qualities != null) {
        qualities.sort(videoQualityComparer);
        qualities = qualities?.reversed?.toList();
        _qualityValues = qualities;
      }

      _currentResolutionQualityKey = value.lastKey();
      _qualityValue = value[_currentResolutionQualityKey];
      _controller = VideoPlayerController.network(_qualityValue);
      _controller.setLooping(looping);
      if (autoPlay) _controller.play();
      initFuture = _controller.initialize();

      // Update application state and redraw
      setState(() {
        SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
      });
    });

    // Video page takes precedence over portrait orientation
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);

    //Keep screen active till video plays
    Wakelock.enable();

    super.initState();
  }

  ///display or vanishes the overlay i.e playing controls, etc.
  void _toogleOverlay() {
    //Inorder to avoid descrepancy in overlay popping up & vanishing out
    overlayTimer?.cancel();
    if (!_overlay) {
      overlayTimer = Timer(Duration(seconds: widget.overlayTimeOut), () {
        setState(() {
          _overlay = false;
          doubleTapRHeight = videoHeight + 36;
          doubleTapLHeight = videoHeight + 16;
          doubleTapRMargin = 0;
          doubleTapLMargin = 0;
        });
      });
    }
    // Edit the size of the double tap area when showing the overlay.
    // Made to open the "Full Screen" and "Quality" buttons
    setState(() {
      _overlay = !_overlay;
      if (_overlay) {
        doubleTapRHeight = videoHeight - 36;
        doubleTapLHeight = videoHeight - 10;
        doubleTapRMargin = 36;
        doubleTapLMargin = 10;
      } else if (!_overlay) {
        doubleTapRHeight = videoHeight + 36;
        doubleTapLHeight = videoHeight + 16;
        doubleTapRMargin = 0;
        doubleTapLMargin = 0;
      }
    });
  }

  // Draw the player elements
  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key("${_controller.hashCode}_key"),
      onVisibilityChanged: (VisibilityInfo info){
        if (info.visibleFraction == 0) {
          if(_controller!=null)
            if(_controller.value.isPlaying&&_controller.value.position.inSeconds>0)
              _controller?.pause();
        }
      },
      child: Center(
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: <Widget>[
            GestureDetector(
              child: FutureBuilder(
                future: initFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    // Control the width and height of the video
                    double delta = MediaQuery.of(context).size.width -
                        MediaQuery.of(context).size.height *
                            _controller.value.aspectRatio;

                    // Calculate the width and height of the video player relative to the sides and the orientation of the device
                    if (MediaQuery.of(context).orientation ==
                            Orientation.portrait ||
                        delta < 0) {
                      videoHeight = MediaQuery.of(context).size.width /
                          _controller.value.aspectRatio;
                      videoWidth = MediaQuery.of(context).size.width;
                      videoMargin = 0;
                    } else {
                      videoHeight = MediaQuery.of(context).size.height;
                      videoWidth = videoHeight * _controller.value.aspectRatio;
                      videoMargin =
                          (MediaQuery.of(context).size.width - videoWidth) / 2;
                    }

                    // Start where we left off when changing quality
                    if (_seek && _controller.value.duration.inSeconds > 2) {
                      _controller.seekTo(Duration(seconds: position));
                      _seek = false;
                    }

                    //vanish overlayer if so.
                    if (initialOverlay) {
                      overlayTimer =
                          Timer(Duration(seconds: widget.overlayTimeOut), () {
                        setState(() {
                          _overlay = false;
                          doubleTapRHeight = videoHeight + 36;
                          doubleTapLHeight = videoHeight + 16;
                          doubleTapRMargin = 0;
                          doubleTapLMargin = 0;
                        });
                      });
                      initialOverlay = false;
                    }

                    // Rendering player elements
                    return Stack(
                      children: <Widget>[
                        Container(
                          height: videoHeight,
                          width: videoWidth,
                          margin: EdgeInsets.only(left: videoMargin),
                          child: VideoPlayer(_controller),
                        ),
                        _videoOverlay(),
                      ],
                    );
                  } else {
                    return Stack(
                      children: [
                        widget.placeholder!=null ? Image.network(
                          widget.placeholder,
                          fit: BoxFit.fitHeight,
                        ) : Container(),
                        Center(
                          heightFactor: 6,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: widget.loadingIndicatorColor != null
                                ? AlwaysStoppedAnimation<Color>(
                                    widget.loadingIndicatorColor)
                                : null,
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              onTap: _toogleOverlay,
            ),
            GestureDetector(
                // ======= Rewind ======= //
                child: Container(
                  width: doubleTapLWidth / 2 - 30,
                  height: doubleTapLHeight - 46,
                  margin: EdgeInsets.fromLTRB(
                      0, 10, doubleTapLWidth / 2 + 30, doubleTapLMargin + 20),
                  decoration: BoxDecoration(
                      //color: Colors.red,
                      ),
                ),

                // Resize double tap blocks. Needed to open buttons
                // "Full screen" and "Quality" with overlay enabled
                onTap: _toogleOverlay,
                onDoubleTap: () {
                  setState(() {
                    _controller.seekTo(Duration(
                        seconds: _controller.value.position.inSeconds - 10));
                  });
                }),
            GestureDetector(
                child: Container(
                  // ======= Fast forward ======= //
                  width: doubleTapRWidth / 2 - 45,
                  height: doubleTapRHeight - 60,
                  margin: EdgeInsets.fromLTRB(doubleTapRWidth / 2 + 45,
                      doubleTapRMargin, 0, doubleTapRMargin + 20),
                  decoration: BoxDecoration(
                      //color: Colors.red,
                      ),
                ),
                // Resize double tap blocks. Needed to open buttons
                // "Full screen" and "Quality" with overlay enabled
                onTap: _toogleOverlay,
                onDoubleTap: () {
                  setState(() {
                    _controller.seekTo(Duration(
                        seconds: _controller.value.position.inSeconds + 10));
                  });
                }),
          ],
        ),
      ),
    );
  }

  //================================ Quality ================================//
  void _settingModalBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          // Forming the quality list
          final children = <Widget>[];
          _qualityValues.forEach((quality) => (children.add(new ListTile(
              title: new Text(" ${quality.key.toString()} fps",style: TextStyle(fontWeight: _currentResolutionQualityKey == quality.key ? FontWeight.bold : FontWeight.normal),),
              trailing: _currentResolutionQualityKey == quality.key
                  ? Icon(Icons.check)
                  : null,
              onTap: () => {
                    // Update application state and redraw
                    setState(() {
                      _controller.pause();
                      _currentResolutionQualityKey = quality.key;
                      _qualityValue = quality.value;
                      _controller =
                          VideoPlayerController.network(_qualityValue);
                      _controller.setLooping(looping);
                      _seek = true;
                      initFuture = _controller.initialize();
                      _controller.play();
                      Navigator.pop(context); //close sheet
                    }),
                  }))));
          // Output quality items as a list
          return Container(
            child: Wrap(
              children: children,
            ),
          );
        });
  }

  //================================ OVERLAY ================================//
  Widget _videoOverlay() {
    return _overlay
        ? Stack(
            children: <Widget>[
              GestureDetector(
                child: Center(
                  child: Container(
                    width: videoWidth,
                    height: videoHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          const Color(0x662F2C47),
                          const Color(0x662F2C47)
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                //child: ValueListenableBuilder(
                //  valueListenable: _controller,
                //  builder: (context, VideoPlayerValue value, child) =>
                child:  IconButton(
                    padding: EdgeInsets.only(
                        top: videoHeight / 2 - 30,
                        bottom: videoHeight / 2 - 30),
                    icon:
                    _controller.value.position == _controller.value.duration
                        ? Icon(
                      Icons.replay,
                      color: widget.controlsColor,
                      size: 60.0,
                    )
                        : _controller.value.isPlaying
                        ? Icon(Icons.pause,
                        size: 60.0, color: widget.controlsColor)
                        : Icon(Icons.play_arrow,
                        size: 60.0, color: widget.controlsColor),
                    onPressed: () {
                      setState(() {
                        //replay video
                        if (_controller.value.position ==
                            _controller.value.duration) {
                          setState(() {
                            _controller.seekTo(Duration());
                            _controller.play();
                          });
                        }
                        //vanish the overlay if play button is pressed
                        else if (!_controller.value.isPlaying) {
                          overlayTimer?.cancel();
                          _controller.play();
                          _overlay = !_overlay;
                        } else {
                          _controller.pause();
                        }
                      });
                    }),
              ),
              //),
              Container(
                margin: EdgeInsets.only(
                    top: videoHeight - 35, left: videoWidth + videoMargin - 45),
                child: IconButton(
                    alignment: AlignmentDirectional.center,
                    padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 2.0),
                    icon: Icon(
                      Icons.fullscreen,
                     // size: 30.0,
                      color: widget.controlsColor,
                    ),
                    onPressed: () async {
                      final playing = _controller.value.isPlaying;
                      setState(() {
                        _controller.pause();
                        overlayTimer?.cancel();
                      });
                      // Create a new page with a full screen player,
                      // transfer data to the player and return the position when
                      // return back. Until we returned from
                      // fullscreen - the program is pending
                      final controllerDetails =
                          await Navigator.push<ControllerDetails>(
                              context,
                              PageRouteBuilder(
                                  opaque: false,
                                  pageBuilder: (BuildContext context, _, __) =>
                                      FullscreenPlayer(
                                        id: _id,
                                        autoPlay: playing,
                                        controller: _controller,
                                        position: _controller
                                            .value.position.inSeconds,
                                        initFuture: initFuture,
                                        qualityValue: _qualityValue,
                                        backgroundColor:
                                            widget.fullScreenBackgroundColor,
                                        overlayTimeOut: widget.overlayTimeOut,
                                        controlsColor: widget.controlsColor,
                                        qualityValues: _qualityValues,
                                        placeholder: widget.placeholder,
                                        qualityKey:
                                            _currentResolutionQualityKey,
                                      ),
                                  transitionsBuilder: (___,
                                      Animation<double> animation,
                                      ____,
                                      Widget child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                          scale: animation, child: child),
                                    );
                                  }));
                      position = controllerDetails?.position;
                      if (controllerDetails?.playingStatus ?? false) {
                        setState(() {
                          _controller.play();
                          _seek = true;
                        });
                      }
                    }),
              ),
              Container(
                margin: EdgeInsets.only(left: videoWidth + videoMargin - 48),
                child: IconButton(
                    icon: Icon(
                      Icons.settings,
                      size: 26.0,
                      color: widget.controlsColor,
                    ),
                    onPressed: () {
                      position = _controller.value.position.inSeconds;
                      _seek = true;
                      _settingModalBottomSheet(context);
                      setState(() {});
                    }),
              ),
              Container(
                // ===== Slider ===== //
                margin: EdgeInsets.only(
                    top: videoHeight - 26, left: videoMargin,), //CHECK IT
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _videoOverlaySlider(),
                    _speedControl()
                  ],
                ),
              )
            ],
          )
        : Center(
            child: Container(
              height: 5,
              width: videoWidth,
              margin: EdgeInsets.only(top: videoHeight - 5),
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: Color(0xFF22A3D2),
                  backgroundColor: Color(0x5515162B),
                  bufferedColor: Color(0x5583D8F7),
                ),
                padding: EdgeInsets.only(top: 2),
              ),
            ),
          );
  }

  // ==================== SLIDER =================== //
  Widget _videoOverlaySlider() {
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, VideoPlayerValue value, child) {
        if (!value.hasError && value.isInitialized) {
          return Row(
            children: <Widget>[
              Container(
                width: 46,
                alignment: Alignment(0, 0),
                child: Text(
                  '${_twoDigits(value.position.inMinutes)}:${_twoDigits(value.position.inSeconds - value.position.inMinutes * 60)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Container(
                height: 20,
                width: videoWidth - 162, // speed icon size
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    backgroundColor: Colors.white30,
                    bufferedColor: Colors.white54,
                  ),
                  padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                ),
              ),
              Container(
                width: 46,
                alignment: Alignment(0, 0),
                child: Text(
                  '${_twoDigits(value.duration.inMinutes)}:${_twoDigits(value.duration.inSeconds - value.duration.inMinutes * 60)}',
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        } else {
          Wakelock
              .disable(); //Now screen can be inactive as per system defined configurations
          return Container();
        }
      },
    );
  }

  ///Convert the integer number in atleast 2 digit format (i.e appending 0 in front if any)
  String _twoDigits(int n) => n.toString().padLeft(2, '0');


  Widget _speedControl(){
    return PopupMenuButton<double>(
      onSelected: (rate){ _controller.setPlaybackSpeed(rate);},
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 2.0),
        child: Icon(Icons.speed,color: Colors.white,),
      ),
      tooltip: 'PlayBack Rate',
      itemBuilder: (context) => [
        _popUpItemSpeed('2.0x', 2.0),
        _popUpItemSpeed('1.75x', 1.75),
        _popUpItemSpeed('1.5x', 1.5),
        _popUpItemSpeed('1.25x', 1.25),
        _popUpItemSpeed('Normal', 1.0),
        _popUpItemSpeed('0.75x', 0.75),
        _popUpItemSpeed('0.5x', 0.5),
        _popUpItemSpeed('0.25x', 0.25),
      ],
    );


  }
  Widget _popUpItemSpeed(String text, double rate) {
    return CheckedPopupMenuItem(
      checked: _controller.value.playbackSpeed == rate,
      child: Text(text),
      value: rate,
    );
  }
  @override
  void dispose() {
    overlayTimer?.cancel();
    _controller.dispose();
    Wakelock.disable();
    super.dispose();
  }
}
