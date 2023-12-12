import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lanyard_listening_along/config.dart';
import 'package:lanyard_listening_along/page/discord_login.dart';
import 'package:lanyard_listening_along/service/spotify_playback.dart';
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

  @override
  void initState() {
    super.initState();
    
    if (Platform.isWindows || Platform.isMacOS) {
      Size listeningAlongWindowSize = const Size(500, 336);
      WindowManager.instance.setMinimumSize(listeningAlongWindowSize);
      WindowManager.instance.setMaximumSize(listeningAlongWindowSize);
      WindowManager.instance.setSize(listeningAlongWindowSize);
      WindowManager.instance.setTitle(Config.appTitle);
    }
    
    if (!SpotifyPlayback.instance.isDiscordTokenVaild) {
      _secureStorage.read(key: "discordToken").then((token) async {
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextField(
              controller: _targetUserIdInput,
              decoration: InputDecoration(
                labelText: "Target User ID",
                hintText: "Enter the user ID you want listening along",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)
                )
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => setState(() {}),
              onEditingComplete: () => setState(() {}),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _secureStorage.delete(key: "discordToken");
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
                ElevatedButton(
                  onPressed: () async {
                    await WindowManager.instance.hide();
                  },
                  child: const Text("Minimize to Tray"),
                ),
              ],
            ),
            RepaintBoundary(
              child: SpotifyCard(userId: _targetUserIdInput.text),
            )
          ],
        ),
      ),
    );
  }
}
