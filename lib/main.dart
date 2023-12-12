import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lanyard_listening_along/config.dart';
import 'package:lanyard_listening_along/page/discord_login.dart';
import 'package:lanyard_listening_along/page/listening_along.dart';
import 'package:lanyard_listening_along/service/spotify_playback.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    Size initWindowSize = const Size(250, 250);
    await WindowManager.instance.setTitle("Loading...");
    await WindowManager.instance.setMinimumSize(initWindowSize);
    await WindowManager.instance.setMaximumSize(initWindowSize);
    await WindowManager.instance.setSize(initWindowSize);
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Config.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(0, 43, 45, 49),
          brightness: Brightness.dark
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<StatefulWidget> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SystemTray _systemTray = SystemTray();
  final Menu _menuSimple = Menu();
  bool _isAppHide = false;

  String _getTrayImagePath(String imageName) {
    return Platform.isWindows ? 'assets/$imageName.ico' : 'assets/$imageName.png';
  }

  Future<void> _initSystemTray() async {
    await _systemTray.initSystemTray(
      title: Config.appTitle,
      toolTip: "Listening along on Spotify using Lanyard API",
      iconPath: _getTrayImagePath('app_icon')
    );

    _systemTray.registerSystemTrayEventHandler((eventName) async {
      if (eventName == kSystemTrayEventClick) {
        await WindowManager.instance.isVisible() ? WindowManager.instance.hide() : WindowManager.instance.show();
        _isAppHide = !_isAppHide;
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });

    _systemTray.setContextMenu(_menuSimple);
  }

  @override
  void initState() {
    super.initState();
    _initSystemTray();
    _secureStorage.read(key: Config.discordTokenKey).then((token) async {
      if (token == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DiscordLoginPage())
          );
        }
      } else {
        await SpotifyPlayback.instance.token(token);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ListeningAlongPage())
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(),)
    );
  }
}
