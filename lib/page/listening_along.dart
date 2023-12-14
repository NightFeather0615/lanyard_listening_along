import "dart:async";
import "dart:io";

import "package:flutter/material.dart";

import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:hive/hive.dart";
import "package:landart/landart.dart";
import "package:lanyard_listening_along/config.dart";
import "package:lanyard_listening_along/page/discord_login.dart";
import "package:lanyard_listening_along/service/spotify_playback.dart";
import "package:lanyard_listening_along/utils.dart";
import "package:lanyard_listening_along/widget/spotify_status.dart";
import "package:wakelock/wakelock.dart";
import "package:window_manager/window_manager.dart";


class ListeningAlongPage extends StatefulWidget {
  const ListeningAlongPage({super.key});

  @override
  State<ListeningAlongPage> createState() => _ListeningAlongPageState();
}

class _ListeningAlongPageState extends State<ListeningAlongPage> {
  final Box _prefs = Hive.box("sharedPrefs");
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  late final TextEditingController _targetUserIdInput;
  final FocusNode _targetUserIdFocusNode = FocusNode();
  String _lastTargetUserId = "";

  late StreamController<LanyardUser> _userDataStreamController = SpotifyPlayback.subscribeUser(
    _prefs.get("userId", defaultValue: "")
  );

  late OverlayEntry _dimScreenOverlayEntry;

  @override
  void initState() {
    _targetUserIdInput = TextEditingController(text: _prefs.get("userId", defaultValue: ""));

    _dimScreenOverlayEntry = OverlayEntry(
      builder: (context) {
        return Material(
          child: InkWell(
            onTap: () async {
              _dimScreenOverlayEntry.remove();
              await Wakelock.disable();
            },
            child: Container(
              color: Colors.black,
            ),
          ),
        );
      },
    );
    
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

    super.initState();
  }

  @override
  void dispose() {
    _dimScreenOverlayEntry.dispose();
    _targetUserIdInput.dispose();
    _targetUserIdFocusNode.dispose();

    super.dispose();
  }

  List<Widget> _contolButtonList() => [
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

        LanyardUser userData = (
          await Lanyard.fetchUser(_targetUserIdInput.text)
        );

        _userDataStreamController.sink.add(userData);

        if (userData.spotify != null) {
          SpotifyPlayback.instance.play(userData.spotify!);
        } else {
          SpotifyPlayback.instance.pause();
        }
      },
      child: const Text("Refresh Session"),
    ),
    if (Platform.isWindows) ElevatedButton(
      onPressed: () async {
        await WindowManager.instance.hide();
      },
      child: const Text("Minimize to Tray"),
    ),
    if (Platform.isIOS) ElevatedButton(
      onPressed: () async {
        Overlay.of(context).insert(_dimScreenOverlayEntry);
        await Wakelock.enable();
      },
      child: const Text("Dim Screen"),
    )
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (Platform.isIOS || Platform.isAndroid) const Spacer(flex: 6,),

              TextField(
                controller: _targetUserIdInput,
                focusNode: _targetUserIdFocusNode,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Target User ID",
                  hintText: "Enter the user ID you want listening along",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)
                  )
                ),
                onSubmitted: (_) {
                  if (_lastTargetUserId != _targetUserIdInput.text) {
                    _prefs.put("userId", _targetUserIdInput.text);
                    _userDataStreamController = SpotifyPlayback.subscribeUser(_targetUserIdInput.text);
                    _lastTargetUserId = _targetUserIdInput.text;
                    setState(() {});
                  }
                },
                onEditingComplete: () {
                  if (_lastTargetUserId != _targetUserIdInput.text) {
                    _prefs.put("userId", _targetUserIdInput.text);
                    _userDataStreamController = SpotifyPlayback.subscribeUser(_targetUserIdInput.text);
                    _lastTargetUserId = _targetUserIdInput.text;
                    setState(() {});
                  }
                },
                onTapOutside: (_) {
                  if (_lastTargetUserId != _targetUserIdInput.text) {
                    _prefs.put("userId", _targetUserIdInput.text);
                    _userDataStreamController = SpotifyPlayback.subscribeUser(_targetUserIdInput.text);
                    _lastTargetUserId = _targetUserIdInput.text;
                    setState(() {});
                  }
                },
              ),

              if (Platform.isIOS || Platform.isAndroid) const Spacer(),

              if (Platform.isWindows) Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _contolButtonList(),
              ),
              if (Platform.isIOS || Platform.isAndroid) Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _contolButtonList(),
              ),

              if (Platform.isIOS || Platform.isAndroid) const Spacer(),

              RepaintBoundary(
                child: SpotifyStatus(
                  eventStream: _userDataStreamController.stream,
                ),
              ),

              if (Platform.isIOS || Platform.isAndroid) const Spacer(flex: 6,),
            ],
          ),
        ),
      ),
    );
  }
}
