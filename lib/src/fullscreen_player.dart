library vimeoplayer;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock/wakelock.dart';
import 'dart:async';

import '../vimeoplayer.dart';

/// Full screen video player class
class FullscreenPlayer extends StatefulWidget {
  final String id;
  final bool autoPlay;
  final bool looping;
  final VideoPlayerController controller;
  final position;
  final Future<void> initFuture;
  final String qualityValue;
  final Color backgroundColor;

  ///[overlayTimeOut] in seconds: decide after how much second overlay should vanishes
  ///minimum 3 seconds of timeout is stacked
  final int overlayTimeOut;

  final Color loadingIndicatorColor;
  final Color controlsColor;

  //contains the resolution qualities of vimeo video
  final List<MapEntry> qualityValues;
  final String qualityKey;
  final String placeholder;

  FullscreenPlayer({
    @required this.id,
    @required this.overlayTimeOut,
    @required this.qualityValues,
    @required this.qualityKey,
    this.autoPlay = false,
    this.looping,
    this.controller,
    this.position,
    this.initFuture,
    this.qualityValue,
    this.backgroundColor,
    this.loadingIndicatorColor,
    this.controlsColor,
    this.placeholder,
    Key key,
  }) : super(key: key);

  @override
  _FullscreenPlayerState createState() => _FullscreenPlayerState(
        id,
        autoPlay,
        looping,
        controller,
        position,
        initFuture,
        qualityValue,
        qualityKey,
      );
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  String _id;
  bool autoPlay = false;
  bool looping = false;
  bool _overlay = true;
  bool fullScreen = true;

  VideoPlayerController controller;
  VideoPlayerController _controller;

  int position;

  Future<void> initFuture;
  var qualityValue;
  String currentResolutionQualityKey;

  _FullscreenPlayerState(
    this._id,
    this.autoPlay,
    this.looping,
    this.controller,
    this.position,
    this.initFuture,
    this.qualityValue,
    this.currentResolutionQualityKey,
  );

  // Quality Class
  //QualityLinks _quality;
  //Map _qualityValues;

  // Rewind variable
  bool _seek = true;

  // Video variables
  double videoHeight;
  double videoWidth;
  double videoMargin;

  // Variables for double-tap zones
  double doubleTapRMarginFS = 36;
  double doubleTapRWidthFS = 700;
  double doubleTapRHeightFS = 300;
  double doubleTapLMarginFS = 10;
  double doubleTapLWidthFS = 700;
  double doubleTapLHeightFS = 400;

  //overlay timeout handler
  Timer overlayTimer;
  //indicate if overlay to be display on commencing video or not
  bool initialOverlay = true;

  @override
  void initState() {
    // Initialize video controllers when receiving data from Vimeo
    _controller = controller;
    if (autoPlay) _controller.play();

    // // Load the list of video qualities
    // _quality = QualityLinks(_id); //Create class
    // _quality.getQualitiesSync().then((value) {
    //   _qualityValues = value;
    // });

    setState(() {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    });

    //Keep screen active till video plays
    Wakelock.enable();

    super.initState();
  }

  // Track the user's click back and translate
  // the screen with the player is not in fullscreen mode, return the orientation
  Future<bool> _onWillPop() {
    final playing = _controller.value.isPlaying;
    overlayTimer?.cancel();
    setState(() {
      _controller.pause();
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIOverlays(
          [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    });
    Navigator.pop(
      context,
      ControllerDetails(
        playingStatus: playing,
        position: _controller.value.position.inSeconds,
      ),
    );
    return Future.value(true);
  }

  ///display or vanishes the overlay i.e playing controls, etc.
  void _toogleOverlay() {
    //Inorder to avoid descrepancy in overlay popping up & vanishing out
    overlayTimer?.cancel();
    if (!_overlay) {
      overlayTimer = Timer(Duration(seconds: widget.overlayTimeOut), () {
        setState(() {
          _overlay = false;
          doubleTapRHeightFS = videoHeight + 36;
          doubleTapLHeightFS = videoHeight;
          doubleTapRMarginFS = 0;
          doubleTapLMarginFS = 0;
        });
      });
    }
    // Edit the size of the double tap area when showing the overlay.
    // Made to open the "Full Screen" and "Quality" buttons
    setState(() {
      _overlay = !_overlay;
      if (_overlay) {
        doubleTapRHeightFS = videoHeight - 36;
        doubleTapLHeightFS = videoHeight - 10;
        doubleTapRMarginFS = 36;
        doubleTapLMarginFS = 10;
      } else if (!_overlay) {
        doubleTapRHeightFS = videoHeight + 36;
        doubleTapLHeightFS = videoHeight;
        doubleTapRMarginFS = 0;
        doubleTapLMarginFS = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
            backgroundColor: widget.backgroundColor,
            body: VisibilityDetector(
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
                            if (MediaQuery.of(context).orientation ==
                                    Orientation.portrait ||
                                delta < 0) {
                              videoHeight = MediaQuery.of(context).size.width /
                                  _controller.value.aspectRatio;
                              videoWidth = MediaQuery.of(context).size.width;
                              videoMargin = 0;
                            } else {
                              videoHeight = MediaQuery.of(context).size.height;
                              videoWidth =
                                  videoHeight * _controller.value.aspectRatio;
                              videoMargin = (MediaQuery.of(context).size.width -
                                      videoWidth) /
                                  2;
                            }
                            // Variables double tap, depending on the size of the video
                            doubleTapRWidthFS = videoWidth;
                            doubleTapRHeightFS = videoHeight - 36;
                            doubleTapLWidthFS = videoWidth;
                            doubleTapLHeightFS = videoHeight;

                            // Immediately upon entering the fullscreen mode, rewind
                            // to the right place
                            if (_seek && fullScreen) {
                              _controller.seekTo(Duration(seconds: position));
                              _seek = false;
                            }

                            // Go to the right place when changing quality
                            if (_seek &&
                                _controller.value.duration.inSeconds > 2) {
                              _controller.seekTo(Duration(seconds: position));
                              _seek = false;
                            }
                            SystemChrome.setEnabledSystemUIOverlays(
                                [SystemUiOverlay.bottom]);

                            //vanish overlayer if so.
                            if (initialOverlay) {
                              overlayTimer = Timer(
                                  Duration(seconds: widget.overlayTimeOut), () {
                                setState(() {
                                  _overlay = false;
                                  doubleTapRHeightFS = videoHeight + 36;
                                  doubleTapLHeightFS = videoHeight;
                                  doubleTapRMarginFS = 0;
                                  doubleTapLMarginFS = 0;
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
                                    )),
                              ],
                            );
                          }
                        }),
                    // Edit the size of the double tap area when showing the overlay.
                    // Made to open the "Full Screen" and "Quality" buttons
                    onTap: _toogleOverlay,
                  ),
                  GestureDetector(
                      child: Container(
                        width: doubleTapLWidthFS / 2 - 30,
                        height: doubleTapLHeightFS - 44,
                        margin: EdgeInsets.fromLTRB(
                            0, 0, doubleTapLWidthFS / 2 + 30, 40),
                        decoration: BoxDecoration(
                            //color: Colors.red,
                            ),
                      ),
                      // Edit the size of the double tap area when showing the overlay.
                      // Made to open the "Full Screen" and "Quality" buttons
                      onTap: _toogleOverlay,
                      onDoubleTap: () {
                        setState(() {
                          _controller.seekTo(Duration(
                              seconds:
                                  _controller.value.position.inSeconds - 10));
                        });
                      }),
                  GestureDetector(
                      child: Container(
                        width: doubleTapRWidthFS / 2 - 45,
                        height: doubleTapRHeightFS - 80,
                        margin: EdgeInsets.fromLTRB(doubleTapRWidthFS / 2 + 45, 0,
                            0, doubleTapLMarginFS + 20),
                        decoration: BoxDecoration(
                            //color: Colors.red,
                            ),
                      ),
                      // Edit the size of the double tap area when showing the overlay.
                      // Made to open the "Full Screen" and "Quality" buttons
                      onTap: _toogleOverlay,
                      onDoubleTap: () {
                        setState(() {
                          _controller.seekTo(Duration(
                              seconds:
                                  _controller.value.position.inSeconds + 10));
                        });
                      }),
                ],
              )),
            )));
  }

  //================================ Quality ================================//
  void _settingModalBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          final children = <Widget>[];
          widget.qualityValues.forEach((quality) => (children.add(new ListTile(
              title: new Text(" ${quality.key.toString()} fps",style: TextStyle(fontWeight: currentResolutionQualityKey == quality.key ? FontWeight.bold : FontWeight.normal),),
              trailing: currentResolutionQualityKey == quality.key
                  ? Icon(Icons.check)
                  : null,
              onTap: () => {
                    // Update application state and redraw
                    setState(() {
                      _controller.pause();
                      currentResolutionQualityKey = quality.key;
                      _controller =
                          VideoPlayerController.network(quality.value);
                      _controller.setLooping(looping);
                      _seek = true;
                      initFuture = _controller.initialize();
                      _controller.play();
                      Navigator.pop(context); //close sheets
                    }),
                  }))));

          return Container(
            height: videoHeight,
            child: ListView(
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
                child: IconButton(
                    padding: EdgeInsets.only(
                      top: videoHeight / 2 - 50,
                      bottom: videoHeight / 2 - 30,
                    ),
                    icon:
                    _controller.value.duration == _controller.value.position
                        ? Icon(
                      Icons.replay,
                      size: 60.0,
                      color: widget.controlsColor,
                    )
                        : _controller.value.isPlaying
                        ? Icon(
                      Icons.pause,
                      size: 60.0,
                      color: widget.controlsColor,
                    )
                        : Icon(
                      Icons.play_arrow,
                      size: 60.0,
                      color: widget.controlsColor,
                    ),
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
              Container(

                margin: EdgeInsets.only(
                    top: videoHeight - 35, left: videoWidth + videoMargin - 45),
                child: IconButton(
                    padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 2.0),
                    alignment: AlignmentDirectional.center,
                    icon: Icon(Icons.fullscreen,
                       /* size: 30.0,*/ color: widget.controlsColor),
                    onPressed: () {
                      final playing = _controller.value.isPlaying;
                      overlayTimer?.cancel();
                      setState(() {
                        _controller.pause();
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitDown,
                          DeviceOrientation.portraitUp
                        ]);
                        SystemChrome.setEnabledSystemUIOverlays(
                            [SystemUiOverlay.top, SystemUiOverlay.bottom]);
                      });
                      Navigator.pop(
                        context,
                        ControllerDetails(
                          playingStatus: playing,
                          position: _controller.value.position.inSeconds,
                        ),
                      );
                      // Navigator.pop(context, {
                      //   'position': _controller.value.position.inSeconds,
                      //   'status': playing
                      // });
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
                    top: videoHeight - 40, left: videoMargin), //CHECK IT
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
        : Center();
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
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Container(
                height: 20,
                width: videoWidth - 172,
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
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        } else {
          //Screen can resume it's active status from System Configurations
          Wakelock.disable();
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
    Wakelock.disable();
    super.dispose();
  }
}
