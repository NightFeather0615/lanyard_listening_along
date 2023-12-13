import 'package:flutter/material.dart';

import 'package:landart/landart.dart';
import 'package:lanyard_listening_along/widget/progress_bar.dart';


class SpotifyCard extends StatefulWidget {
  const SpotifyCard({
    super.key,
    required this.spotifyData
  });

  final SpotifyData spotifyData;

  @override
  State<StatefulWidget> createState() => _SpotifyCardState();
}

class _SpotifyCardState extends State<SpotifyCard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
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
              child: widget.spotifyData.albumArtUrl == null
                ? null
                : Image.network(
                  widget.spotifyData.albumArtUrl!
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
                      widget.spotifyData.song,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis
                      ),
                    ),
                    Text(
                      "by ${widget.spotifyData.artist}",
                      style: const TextStyle(
                        fontSize: 16,
                        overflow: TextOverflow.ellipsis
                      ),
                    ),
                    Text(
                      "on ${widget.spotifyData.album}",
                      style: const TextStyle(
                        fontSize: 16,
                        overflow: TextOverflow.ellipsis
                      ),
                    ),
                    Expanded(
                      child: ProgressBar(
                        timestamp: widget.spotifyData.timestamps!
                      ),
                    )
                  ],
                ),
              ),
            )
          )
        ],
      ),
    );
  }
}
