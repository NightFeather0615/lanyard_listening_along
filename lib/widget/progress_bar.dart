import 'dart:async';

import 'package:flutter/material.dart';

import 'package:landart/landart.dart';


class ProgressBar extends StatefulWidget {
  const ProgressBar({
    super.key,
    required this.timestamp
  });

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
    return Scaffold(
        body: Column(
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
      ),
    );
  }
}
