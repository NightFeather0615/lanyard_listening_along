import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:landart/landart.dart';
import 'package:lanyard_listening_along/config.dart';
import 'package:lanyard_listening_along/service/spotify_playback.dart';
import 'package:lanyard_listening_along/utils.dart';
import 'package:lanyard_listening_along/widget/error_message.dart';
import 'package:lanyard_listening_along/widget/spotify_card.dart';
import 'package:url_launcher/url_launcher.dart';


class SpotifyStatus extends StatefulWidget {
  const SpotifyStatus({
    super.key,
    required this.eventStream
  });

  final Stream<LanyardUser> eventStream;

  @override
  State<StatefulWidget> createState() => _SpotifyStatusState();
}

class _SpotifyStatusState extends State<SpotifyStatus> {
  SpotifyData? _lastSpotifyData;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 130,
      child: StreamBuilder(
        stream: widget.eventStream,
        builder: (context, snapshot) {
          if ((!snapshot.hasData && !snapshot.hasError) || snapshot.hasError) {
            Utils.setTitleSafe("Unable to fetch user data");
            return ErrorMessage(
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
                          Uri.parse(Config.lanyardDiscordServerInvite)
                        );
                      },
                  )
                ]
              ),
              onAction: () => setState(() {}),
            );
          }

          if (!SpotifyPlayback.instance.isDiscordTokenVaild) {
            Utils.setTitleSafe("Invalid Discord token");
            return const ErrorMessage(
              title: "Invalid Discord token"
            );
          }

          if (!SpotifyPlayback.instance.isSpotifyConnected) {
            Utils.setTitleSafe("Unable to get Spotify connection");
            return ErrorMessage(
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
            Utils.setTitleSafe("Unable to get Spotify device");
            return ErrorMessage(
              title: "Unable to get Spotify device",
              description: const TextSpan(
                text: "Please make sure your have at least one active device"
              ),
              onAction: () => setState(() {
                SpotifyPlayback.instance.fetchDevice();
              }),
            );
          }

          if (snapshot.hasData) {
            SpotifyData? spotifyData = snapshot.data!.spotify;
            
            if (spotifyData == null) {
              SpotifyPlayback.instance.pause();

              Utils.setTitleSafe();

              return const ErrorMessage(
                title: "Target user is currently not listening to Spotify"
              );
            } else {
              if (spotifyData.trackId == null) {
                Utils.setTitleSafe("Unable to get song track ID");

                return ErrorMessage(
                  title: "Unable to get song track ID",
                  onAction: () => setState(() {}),
                );
              } else {
                if (_lastSpotifyData != spotifyData) {
                  SpotifyPlayback.instance.play(spotifyData);

                  _lastSpotifyData = spotifyData;
                }

                Utils.setTitleSafe(
                  "${spotifyData.song} • ${spotifyData.artist}"
                );
              }
            }

            return SpotifyCard(
              spotifyData: spotifyData
            );
          }

          Utils.setTitleSafe();
          return const Center(child: CircularProgressIndicator(),);
        },
      ),
    );
  }
}
