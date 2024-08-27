import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:hive_flutter/adapters.dart";
import "package:http/http.dart";
import "package:lanyard_listening_along/config.dart";
import "package:lanyard_listening_along/page/discord_login.dart";
import "package:lanyard_listening_along/page/listening_along.dart";
import "package:lanyard_listening_along/service/spotify_playback.dart";
import "package:lanyard_listening_along/service/system_tray_handler.dart";
import "package:lanyard_listening_along/utils.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path_provider/path_provider.dart";
import "package:system_tray/system_tray.dart";
import "package:window_manager/window_manager.dart";


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox("sharedPrefs");

  if (Platform.isIOS || Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await SystemTrayHandler.instance.initSystemTray();

    Size initWindowSize = const Size(475, 475);
    await Utils.setTitleSafe("Loading...");
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
  final Box _prefs = Hive.box("sharedPrefs");
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<bool?> _showUpdateFailedDialog() => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text("Failed to check update"),
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text("Skip"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text("Retry"),
          ),
        ],
      );
    },
  );

  Future<bool?> _showUpdateConfirmDialog(String latestVerion, int sizeBytes) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Text("Found new version: v$latestVerion"),
        content: Text("Download and install update now? (${(sizeBytes / 1000000).toStringAsFixed(1)} MB)"),
        actions: [
          OutlinedButton(
            onPressed: () async {
              await _prefs.put("checkUpdate", false);

              MenuItemCheckbox? checkUpdateCheckbox =
                SystemTrayHandler.instance.contextMenu.findItemByName<MenuItemCheckbox>("checkUpdate");
              await checkUpdateCheckbox?.setCheck(!checkUpdateCheckbox.checked);

              if (mounted) Navigator.of(context).pop(false);
            },
            child: const Text("Don't ask again"),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text("OK"),
          ),
        ],
      );
    },
  );

  Future<bool?> _checkUpdate() async {
    Client httpClient = Client();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    Response res = await httpClient.get(Uri.parse(Config.githubApiReleaseUrl));

    if (res.statusCode == 200 || res.statusCode == 304) {
      dynamic jsonBody = jsonDecode(res.body);
      String? latestVerion = jsonBody["tag_name"];
      dynamic windowsInstaller = (jsonBody["assets"] as List<dynamic>? ?? []).firstWhere(
        (e) => e["name"] == "Lanyard-Listening-Along-Setup.exe",
        orElse: () => null
      );
      int? exeSize = windowsInstaller["size"];
      String? downloadUrl = windowsInstaller["browser_download_url"];

      if (
        jsonBody == null ||
        latestVerion == null ||
        windowsInstaller == null ||
        exeSize == null ||
        downloadUrl == null
      ) {
        if (mounted) return await _showUpdateFailedDialog();
      }

      if (packageInfo.version != latestVerion) {
        if (mounted) {
          bool confirmDownload = await _showUpdateConfirmDialog(latestVerion!, exeSize!) ?? false;
          if (!confirmDownload) return false;

          Directory cacheDir = await getApplicationCacheDirectory();
          File setupFile = File("${cacheDir.path}\\Lanyard-Listening-Along-Setup.exe.exe");
          Response res = await httpClient.get(Uri.parse(downloadUrl!));
          await setupFile.writeAsBytes(res.bodyBytes);
          await Process.run(setupFile.path, []);
          await setupFile.delete();
          return false;
        }
      } else {
        return false;
      }
    }

    if (mounted) return await _showUpdateFailedDialog();
    return false;
  }

  Future<void> _initApp() async {
    if (Platform.isWindows && !kDebugMode) {
      if (_prefs.get("checkUpdate", defaultValue: true)) {
        await Utils.setTitleSafe("Checking for updates...");

        bool retryUpdate = true;

        while (retryUpdate) {
          retryUpdate = await _checkUpdate() ?? true;
        }
      }
    }

    String? token = await _secureStorage.read(key: "discordToken");

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
  }

  @override
  void initState() {
    _initApp();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(),)
    );
  }
}
