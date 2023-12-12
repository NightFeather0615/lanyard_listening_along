import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:landart/landart.dart';
import 'package:lanyard_listening_along/config.dart';
import 'package:lanyard_listening_along/service/spotify_playback.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';


class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.title,
    this.description,
    this.onAction
  });

  final String title;
  final InlineSpan ? description;
  final String actionName = "Refresh";
  final void Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16
            ),
          ),
          if (description != null) Text.rich(
            description!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14
            ),
          ),
          if (onAction != null) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(
                actionName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14
                ),
              )
            ),
          )
        ],
      ),
    );
  }
}

class SpotifyCard extends StatefulWidget {
  const SpotifyCard({super.key, required this.userId});

  final String userId;

  @override
  State<StatefulWidget> createState() => _SpotifyCardState();
}

class _SpotifyCardState extends State<SpotifyCard> {
  SpotifyData? _lastSpotifyData;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 130,
      child: StreamBuilder(
        stream: Lanyard.subscribe(widget.userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            WindowManager.instance.setTitle("${Config.appTitle} - Loading...");
            return const Center(child: CircularProgressIndicator(),);
          }

          if (!SpotifyPlayback.instance.isDiscordTokenVaild) {
            WindowManager.instance.setTitle("${Config.appTitle} - Invalid Discord token");
            return const _ErrorMessage(
              title: "Invalid Discord token"
            );
          }

          if (!SpotifyPlayback.instance.isSpotifyConnected) {
            WindowManager.instance.setTitle("${Config.appTitle} - Unable to get Spotify connection");
            return _ErrorMessage(
              title: "Unable to get Spotify connection",
              description: const TextSpan(
                text: "Please make sure you already connect Spotify in Discord"
              ),
              onAction: () => setState(() {
                SpotifyPlayback.instance.fetchSpotifyToken();
              }),
            );
          }

          if (!SpotifyPlayback.instance.isDeviceAvailable) {
            WindowManager.instance.setTitle("${Config.appTitle} - Unable to get Spotify device");
            return _ErrorMessage(
              title: "Unable to get Spotify device",
              description: const TextSpan(
                text: "Please make sure your have at least one active device"
              ),
              onAction: () => setState(() {
                SpotifyPlayback.instance.fetchDevice();
              }),
            );
          }

          if (snapshot.hasError) {
            WindowManager.instance.setTitle("${Config.appTitle} - Unable to fetch user data");
            return _ErrorMessage(
              title: "Unable to fetch user data",
              description: TextSpan(
                text: "Please make sure target user has joined the ",
                children: [
                  TextSpan(
                    text: 'Lanyard Discord server',
                    style: const TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        await launchUrl(
                          Uri.parse("https://discord.gg/UrXF2cfJ7F")
                        );
                      },
                  )
                ]
              ),
              onAction: () => setState(() {}),
            );
          }

          if (snapshot.hasData) {
            SpotifyData? spotifyData = snapshot.data!.spotify;
            
            if (spotifyData == null) {
              SpotifyPlayback.instance.pause();

              WindowManager.instance.setTitle(Config.appTitle);

              return const _ErrorMessage(
                title: "Target user is currently not listening to Spotify"
              );
            } else {
              int currentTime = DateTime.now().millisecondsSinceEpoch;

              if (spotifyData.trackId == null) {
                WindowManager.instance.setTitle("${Config.appTitle} - Unable to get song track ID");

                return _ErrorMessage(
                  title: "Unable to get song track ID",
                  onAction: () => setState(() {}),
                );
              } else {
                if (_lastSpotifyData != spotifyData) {
                  SpotifyPlayback.instance.play(
                    spotifyData.trackId!,
                    currentTime - spotifyData.timestamps!.start!
                  );

                  _lastSpotifyData = spotifyData;
                }

                WindowManager.instance.setTitle("${spotifyData.song} • ${spotifyData.artist}");
              }
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 130,
                    width: 130,
                    color: const Color.fromARGB(0, 18, 18, 18),
                    child: spotifyData.albumArtUrl == null
                      ? null
                      : Image.network(
                        spotifyData.albumArtUrl!
                      ),
                  ),
                ),
                
                Expanded(
                  child: SizedBox(
                    height: 130,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14, top: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            spotifyData.song,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              overflow: TextOverflow.ellipsis
                            ),
                          ),
                          Text(
                            "by ${spotifyData.artist}",
                            style: const TextStyle(
                              fontSize: 16,
                              overflow: TextOverflow.ellipsis
                            ),
                          ),
                          Text(
                            "on ${spotifyData.album}",
                            style: const TextStyle(
                              fontSize: 16,
                              overflow: TextOverflow.ellipsis
                            ),
                          ),
                          Expanded(
                            child: ProgressBar(timestamp: spotifyData.timestamps!),
                          )
                        ],
                      ),
                    ),
                  )
                )
              ],
            );
          }

          WindowManager.instance.setTitle(Config.appTitle);
          return const Center(child: CircularProgressIndicator(),);
        },
      ),
    );
  }
}

class ProgressBar extends StatefulWidget {
  const ProgressBar({super.key, required this.timestamp});

  final Timestamp timestamp;
  
  @override
  State<StatefulWidget> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  late int _songLength = widget.timestamp.end! - widget.timestamp.start!;
  int _songProgress = 0;
  late final Timer _updateTimer;


  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (t) {
        int currentTime = DateTime.now().millisecondsSinceEpoch;

        _songLength = widget.timestamp.end! - widget.timestamp.start!;
        _songProgress = currentTime - widget.timestamp.start!;

        if (currentTime >= widget.timestamp.end! || _songProgress >= _songLength) {
          return;
        }
        
        setState(() {});
      }
    );
  }

  @override
  void dispose() {
    super.dispose();
    _updateTimer.cancel();
  }

  String _formatDuration(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes;
    final seconds = (ms / 1000 % 60).round();

    final minutesString = '$minutes';
    final secondsString = '$seconds'.padLeft(2, '0');
    return '$minutesString:$secondsString';
  }

  int _safeProgress() {
    if (_songProgress > _songLength || _songProgress < 0) return 0;
    return _songProgress;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SliderTheme(
          data: SliderThemeData(
            overlayShape: SliderComponentShape.noOverlay,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 2.438,
              disabledThumbRadius: 2.438,
              elevation: 0
            ),
            trackHeight: 3,
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: Slider(
            value: _safeProgress().toDouble(),
            max: _songLength.toDouble(),
            min: 0,
            divisions: _songLength,
            onChanged: (_) {},
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 1, left: 1, top: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                _formatDuration(_songProgress),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              Text(
                _formatDuration(_songLength),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}
