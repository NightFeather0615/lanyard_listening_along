import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lanyard_listening_along/service/spotify_playback.dart';
import 'package:lanyard_listening_along/widget/spotify_card.dart';
import 'package:window_manager/window_manager.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    Size windowSize = const Size(520, 396);
    await WindowManager.instance.setMinimumSize(windowSize);
    await WindowManager.instance.setMaximumSize(windowSize);
    await WindowManager.instance.setSize(windowSize);
    await WindowManager.instance.setTitle("Lanyard Listening Along");
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lanyard Listening Along',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(0, 43, 45, 49),
          brightness: Brightness.dark
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _secureStorage = const FlutterSecureStorage();
  bool rememberToken = false;

  final TextEditingController _discordTokenInput = TextEditingController();
  final TextEditingController _targetUserIdInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    SpotifyPlayback.instance.token(_discordTokenInput.text);
    _secureStorage.read(key: "discordToken").then((v) {
      _discordTokenInput.text = v ?? "";
      SpotifyPlayback.instance.token(_discordTokenInput.text);
      setState(() {
        rememberToken = v != null;
      });
    });
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
              controller: _discordTokenInput,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Discord Token",
                hintText: "Enter your Discord token",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)
                )
              ),
              onChanged: (_) {
                setState(() {
                  SpotifyPlayback.instance.token(_discordTokenInput.text);
                });
              },
              onSubmitted: (_) async {
                if (rememberToken) {
                  await _secureStorage.write(
                    key: "discordToken",
                    value: _discordTokenInput.text
                  );
                }
                setState(() {
                  SpotifyPlayback.instance.token(_discordTokenInput.text);
                });
              },
              onEditingComplete: () async {
                if (rememberToken) {
                  await _secureStorage.write(
                    key: "discordToken",
                    value: _discordTokenInput.text
                  );
                }
                setState(() {
                  SpotifyPlayback.instance.token(_discordTokenInput.text);
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: rememberToken,
                    onChanged: (value) async {
                      rememberToken = value ?? false;

                      if (rememberToken) {
                        await _secureStorage.write(
                          key: "discordToken",
                          value: _discordTokenInput.text
                        );
                      } else {
                        await _secureStorage.delete(key: "discordToken");
                      }

                      setState(() {});
                    },
                  ),
                  const Text(
                    "Remember token"
                  )
                ],
              ),
            ),
            TextField(
              controller: _targetUserIdInput,
              decoration: InputDecoration(
                labelText: "Target User ID",
                hintText: "Enter the user ID you want listening along",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)
                )
              ),
              onSubmitted: (_) => setState(() {}),
              onChanged: (_) => setState(() {}),
              onEditingComplete: () => setState(() {}),
            ),
            const Spacer(),
            SpotifyCard(userId: _targetUserIdInput.text)
          ],
        ),
      ),
    );
  }
}
