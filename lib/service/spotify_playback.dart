import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';


enum RepeatState {
  track("track"),
  context("context"),
  off("off");

  final String state;

  const RepeatState(this.state);
}

class SpotifyPlayback {
  SpotifyPlayback._();

  static SpotifyPlayback? _instance;

  static final Client _httpClient = Client();

  String _discordToken = "";
  bool isDiscordTokenVaild = false;

  String spotifyConnectionId = "";
  bool isSpotifyConnected = false;

  String _spotifyToken = "";

  String _deviceId = "";
  bool isDeviceAvailable = false;

  Timer? _refreshTimer;

  static final _tokenRegExp = RegExp(r'[^A-Za-z0-9._-]');

  static SpotifyPlayback get instance {
    _instance ??= SpotifyPlayback._();
    return _instance!;
  }

  Future<void> token(String token) async {
    _discordToken = token.replaceAll(_tokenRegExp, '');
    await _setup();
  }

  Future<void> _setup() async {
    if (_refreshTimer != null) {
      _refreshTimer!.cancel();
    }

    await fetchSpotifyToken();
    await fetchDevice();

    _refreshTimer = Timer.periodic(
      const Duration(minutes: 15),
      (t) async {
        await fetchSpotifyToken();

        if (spotifyConnectionId.isEmpty) {
          t.cancel();
          return;
        }
      }
    );
  }

  Future<void> fetchSpotifyToken() async {
    Uri connectionsUri = Uri.parse(
      "https://discord.com/api/v9/users/@me/connections"
    );

    Response connectionsRes = await _httpClient.get(
      connectionsUri,
      headers: {
        "Authorization": _discordToken
      }
    );

    isDiscordTokenVaild = connectionsRes.statusCode == 200;
    if (!isDiscordTokenVaild) return;

    spotifyConnectionId = (jsonDecode(connectionsRes.body) as List<dynamic>)
      .firstWhere(
        (e) => e["type"] == "spotify",
        orElse: () =>  {"id": ""}
      )["id"];

    isSpotifyConnected = spotifyConnectionId.isNotEmpty;
    if (!isSpotifyConnected) return;
    
    Uri accessTokenUri = Uri.parse(
      "https://discord.com/api/v9/users/@me/connections/spotify/$spotifyConnectionId/access-token"
    );

    Response accessTokenRes = await _httpClient.get(
      accessTokenUri,
      headers: {
        "Authorization": _discordToken
      }
    );

    if (accessTokenRes.statusCode != 200) {
      return;
    }

    _spotifyToken = (jsonDecode(accessTokenRes.body)["access_token"] ?? "");
  }

  Future<void> fetchDevice() async {
    Uri uri = Uri.parse(
      "https://api.spotify.com/v1/me/player/devices"
    );

    Response res = await _httpClient.get(
      uri,
      headers: {
        "Authorization": "Bearer $_spotifyToken"
      }
    );

    _deviceId = (jsonDecode(res.body)["devices"] ?? [])
      .firstWhere(
        (e) => !e["is_restricted"] && e["id"] != null,
        orElse: () => {"id": ""}
      )["id"];

    isDeviceAvailable = _deviceId.isNotEmpty;
  }

  Future<void> play(String trackId, [int position = 0, bool retry = true]) async {
    Uri uri = Uri.parse(
      "https://api.spotify.com/v1/me/player/play?device_id=$_deviceId"
    );

    Response res = await _httpClient.put(
      uri,
      headers: {
        "Authorization": "Bearer $_spotifyToken"
      },
      body: jsonEncode({
        "uris": [
          "spotify:track:$trackId"
        ],
        "position_ms": position
      })
    );

    if (res.statusCode == 404 && retry) {
      await fetchDevice();
      await play(trackId, position, false);
    } 
  }

  Future<void> pause([bool retry = true]) async {
    Uri uri = Uri.parse(
      "https://api.spotify.com/v1/me/player/pause?device_id=$_deviceId"
    );

    Response res = await _httpClient.put(
      uri,
      headers: {
        "Authorization": "Bearer $_spotifyToken"
      }
    );

    if (res.statusCode == 404 && retry) {
      await fetchDevice();
      await pause(false);
    }
  }

  Future<void> repeat([RepeatState state = RepeatState.off, bool retry = true]) async {
    Uri uri = Uri.parse(
      "https://api.spotify.com/v1/me/player/repeat?device_id=$_deviceId&state=${state.state}"
    );

    Response res = await _httpClient.put(
      uri,
      headers: {
        "Authorization": "Bearer $_spotifyToken"
      }
    );

    if (res.statusCode == 404 && retry) {
      await fetchDevice();
      await repeat(state, false);
    }
  }
}
