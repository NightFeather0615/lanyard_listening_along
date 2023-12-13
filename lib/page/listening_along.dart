import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lanyard_listening_along/config.dart';
import 'package:lanyard_listening_along/page/discord_login.dart';
import 'package:lanyard_listening_along/service/spotify_playback.dart';
import 'package:lanyard_listening_along/utils.dart';
import 'package:lanyard_listening_along/widget/spotify_status.dart';
import 'package:window_manager/window_manager.dart';


class ListeningAlongPage extends StatefulWidget {
  const ListeningAlongPage({super.key});

  @override
  State<ListeningAlongPage> createState() => _ListeningAlongPageState();
}

class _ListeningAlongPageState extends State<ListeningAlongPage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final TextEditingController _targetUserIdInput = TextEditingController();
  final FocusNode _targetUserIdFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    if (Platform.isWindows) {
      Size listeningAlongWindowSize = const Size(500, 336);
      WindowManager.instance.setMinimumSize(listeningAlongWindowSize);
      WindowManager.instance.setMaximumSize(listeningAlongWindowSize);
      WindowManager.instance.setSize(listeningAlongWindowSize);
      Utils.setTitleSafe();
    }
    
    if (!SpotifyPlayback.instance.isDiscordTokenVaild) {
      _secureStorage.read(key: Config.discordTokenKey).then((token) async {
        if (token == null) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const DiscordLoginPage())
            );
          }
        } else {
          await SpotifyPlayback.instance.token(token);
          if (mounted) setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (Platform.isAndroid) const Spacer(flex: 4,),
              TextField(
                controller: _targetUserIdInput,
                focusNode: _targetUserIdFocusNode,
                decoration: InputDecoration(
                  labelText: "Target User ID",
                  hintText: "Enter the user ID you want listening along",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)
                  )
                ),
                onSubmitted: (_) => setState(() {}),
                onEditingComplete: () => setState(() {}),
                onTapOutside: (_) {
                  _targetUserIdFocusNode.unfocus();
                  setState(() {});
                },
              ),
              if (Platform.isAndroid) const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await _secureStorage.delete(key: Config.discordTokenKey);
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const DiscordLoginPage())
                        );
                      }
                    },
                    child: const Text("Logout"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await SpotifyPlayback.instance.fetchDevice();
                      await SpotifyPlayback.instance.fetchSpotifyToken();
                      if (mounted) setState(() {});
                    },
                    child: const Text("Refresh Session"),
                  ),
                  if (Platform.isWindows) ElevatedButton(
                    onPressed: () async {
                      await WindowManager.instance.hide();
                    },
                    child: const Text("Minimize to Tray"),
                  ),
                ],
              ),
              if (Platform.isAndroid) const Spacer(),
              RepaintBoundary(
                child: SpotifyStatus(userId: _targetUserIdInput.text),
              ),
              if (Platform.isAndroid) const Spacer(flex: 4,),
            ],
          ),
        ),
      ),
    );
  }
}
