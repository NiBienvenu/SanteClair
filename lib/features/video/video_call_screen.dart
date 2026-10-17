import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

import '../../core/network/api_exception.dart';
import '../../data/providers.dart';
import 'video_platform.dart';
import 'video_repository.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.appointmentId,
    this.urgent = false,
  });
  final String appointmentId;
  final bool urgent;

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallState();
}

class _VideoCallState extends ConsumerState<VideoCallScreen>
    with WidgetsBindingObserver {
  static const _appSign = String.fromEnvironment('ZEGO_APP_SIGN');
  static const _localAppId = int.fromEnvironment('ZEGO_APP_ID');
  late final VideoRepository _repo;
  late Future<void> _startup;
  CallCredentials? _call;
  Widget? _localView, _remoteView;
  int? _localViewId, _remoteViewId;
  String? _remoteStream, _error;
  String _status = 'Préparation de l’appel…';
  bool _engine = false, _closing = false, _ready = false, _presenceBusy = false;
  bool _mic = true, _camera = true, _frontCamera = true, _speaker = true;
  bool _remoteCamera = true, _remotePlaying = false;
  Timer? _heartbeat, _expiry;
  Future<void> _streamWork = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repo = ref.read(videoRepositoryProvider);
    _startup = _start();
  }

  bool _failed = false;
  bool get _live => mounted && !_closing && !_failed;
  void _update(VoidCallback change) {
    if (mounted && !_closing) setState(change);
  }

  Future<void> _start() async {
    try {
      if (!kIsWeb &&
          defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS) {
        throw ApiException(
          'Utilisez Android, iOS ou un navigateur pour la téléconsultation.',
        );
      }
      if (!videoSecureContext) {
        throw ApiException(
          'Le navigateur exige une adresse HTTPS (ou localhost) pour autoriser la caméra et le microphone.',
        );
      }
      final access = await _repo.access(widget.appointmentId);
      if (!_live) return;
      if (!access.tokenAvailable && (kIsWeb || !access.appSignAllowed)) {
        throw ApiException(
          'La téléconsultation n’est pas encore activée sur cette plateforme. Contactez le cabinet.',
        );
      }
      if (!access.tokenAvailable &&
          (_appSign.length != 64 || _localAppId != access.appId)) {
        throw ApiException(
          'Le service vidéo n’est pas configuré sur cet appareil. Contactez le cabinet.',
        );
      }
      if (!kIsWeb) {
        final permissions = await [
          Permission.camera,
          Permission.microphone,
        ].request();
        if (permissions.values.any((p) => !p.isGranted)) {
          throw ApiException(
            'Autorisez la caméra et le microphone dans les réglages de l’application, puis réessayez.',
          );
        }
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Optional: denial does not prevent calls using speaker/earpiece.
        await Permission.bluetoothConnect.request();
      }
      if (!_live) return;
      final call = await _repo.join(
        widget.appointmentId,
        web: kIsWeb,
        urgent: widget.urgent,
      );
      _call = call;
      if (!_live) return;
      if (call.token == null && _localAppId != call.appId) {
        throw ApiException(
          'La configuration vidéo de l’application doit être mise à jour.',
        );
      }
      await ZegoExpressEngine.createEngineWithProfile(
        ZegoEngineProfile(
          call.appId,
          ZegoScenario.StandardVideoCall,
          appSign: call.token == null ? _appSign : null,
        ),
      );
      _engine = true;
      if (!_live) return;
      _installEvents(call);
      final config = ZegoRoomConfig.defaultConfig()..isUserStatusNotify = true;
      if (call.token != null) config.token = call.token!;
      final result = await ZegoExpressEngine.instance.loginRoom(
        call.roomId,
        ZegoUser(call.userId, call.userName),
        config: config,
      );
      if (result.errorCode != 0) {
        throw ApiException(
          'Connexion ZEGOCLOUD refusée (${result.errorCode}). Vérifiez les clés et l’accès Internet.',
        );
      }
      if (!_live) return;
      final view = await ZegoExpressEngine.instance.createCanvasView((viewId) {
        _localViewId = viewId;
        if (_live) {
          unawaited(
            ZegoExpressEngine.instance.startPreview(
              canvas: ZegoCanvas(viewId, viewMode: ZegoViewMode.AspectFill),
            ),
          );
        }
      });
      _update(() => _localView = view);
      if (!_live) return;
      if (!kIsWeb) {
        await ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);
      }
      await ZegoExpressEngine.instance.startPublishingStream(call.streamId);
      _update(() {
        _ready = true;
        _status = _remotePlaying
            ? 'En communication'
            : 'En attente de ${call.peerName}';
      });
      _heartbeat = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _presence(),
      );
      _expiry = Timer(
        Duration(seconds: call.validForSeconds),
        () => _fail('La période d’accès à cet appel est terminée.'),
      );
    } catch (e) {
      await _release();
      _update(
        () => _error = e is ApiException ? e.message : 'Impossible de démarrer la vidéo. Vérifiez les permissions et la connexion Internet.',
      );
    }
  }

  void _installEvents(CallCredentials call) {
    ZegoExpressEngine
        .onRoomStreamUpdate = (roomId, updateType, streams, extra) {
      if (!_live || roomId != call.roomId) return;
      for (final stream in streams.where(
        (s) => s.user.userID == call.peerUserId,
      )) {
        _streamWork = _streamWork
            .then((_) async {
              if (!_live) return;
              if (updateType == ZegoUpdateType.Add) {
                await _play(stream.streamID);
              } else if (_remoteStream == stream.streamID) {
                await _stopRemote();
                _update(
                  () => _status =
                      '${call.peerName} a quitté l’appel. Vous pouvez attendre sa reconnexion.',
                );
              }
            })
            .catchError((Object e) {
              _update(
                () => _status = 'Vidéo interrompue. Reconnexion en cours…',
              );
            });
      }
    };
    ZegoExpressEngine.onRoomStateUpdate = (roomId, state, errorCode, extra) {
      if (!_live || roomId != call.roomId) return;
      if (state == ZegoRoomState.Connecting) {
        _update(() => _status = 'Connexion au réseau vidéo…');
      }
      if (state == ZegoRoomState.Disconnected && errorCode != 0) {
        unawaited(
          _fail(
            'Connexion vidéo interrompue ($errorCode). Quittez puis rejoignez à nouveau.',
          ),
        );
      }
    };
    ZegoExpressEngine.onPublisherStateUpdate =
        (streamId, state, errorCode, extra) {
          if (_live && errorCode != 0) {
            unawaited(
              _fail('Transmission caméra/microphone interrompue ($errorCode).'),
            );
          }
        };
    ZegoExpressEngine.onPlayerStateUpdate =
        (streamId, state, errorCode, extra) {
          if (!_live || streamId != _remoteStream) return;
          _update(() {
            _remotePlaying = state == ZegoPlayerState.Playing;
            _status = errorCode != 0
                ? 'Réception interrompue ($errorCode). Reconnexion…'
                : _remotePlaying
                ? 'En communication'
                : 'Connexion avec ${call.peerName}…';
          });
        };
    ZegoExpressEngine.onRemoteCameraStateUpdate = (streamId, state) {
      if (streamId == _remoteStream) {
        _update(() => _remoteCamera = state == ZegoRemoteDeviceState.Open);
      }
    };
    ZegoExpressEngine.onRoomTokenWillExpire = (roomId, seconds) {
      unawaited(_renewToken());
    };
  }

  Future<void> _play(String streamId) async {
    await _stopRemote();
    if (!_live) return;
    _remoteStream = streamId;
    final view = await ZegoExpressEngine.instance.createCanvasView((viewId) {
      _remoteViewId = viewId;
      if (_live) {
        unawaited(
          ZegoExpressEngine.instance.startPlayingStream(
            streamId,
            canvas: ZegoCanvas(viewId, viewMode: ZegoViewMode.AspectFit),
          ),
        );
      }
    });
    _update(() {
      _remoteView = view;
      _remoteCamera = true;
    });
  }

  Future<void> _stopRemote() async {
    final stream = _remoteStream;
    _remoteStream = null;
    if (stream != null && _engine) {
      await ZegoExpressEngine.instance.stopPlayingStream(stream);
    }
    if (_remoteViewId != null && _engine) {
      await ZegoExpressEngine.instance.destroyCanvasView(_remoteViewId!);
    }
    _remoteViewId = null;
    _update(() {
      _remoteView = null;
      _remotePlaying = false;
    });
  }

  Future<void> _renewToken() async {
    try {
      final refreshed = await _repo.join(widget.appointmentId, web: kIsWeb);
      if (!_live || !_engine) return;
      if (refreshed.roomId != _call?.roomId) {
        await _fail(
          'Cette session a expiré. Rejoignez le rendez-vous à nouveau.',
        );
        return;
      }
      if (refreshed.token != null) {
        await ZegoExpressEngine.instance.renewToken(
          refreshed.roomId,
          refreshed.token!,
        );
      }
    } on ApiException catch (e) {
      await _fail(e.message);
    }
  }

  Future<void> _presence() async {
    if (_presenceBusy || !_live || _call == null) return;
    _presenceBusy = true;
    try {
      await _repo.presence(_call!);
    } on ApiException catch (e) {
      if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
        await _fail(e.message);
      } else {
        _update(
          () =>
              _status = 'Connexion au cabinet interrompue. Nouvelle tentative…',
        );
      }
    } finally {
      _presenceBusy = false;
    }
  }

  Future<void> _fail(String message) async {
    _failed = true;
    _update(() {
      _error = message;
      _ready = false;
    });
    await _startup;
    await _release();
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      /* Always release the remaining native resources. */
    }
  }

  Future<void>? _releasing;
  Future<void> _release() => _releasing ??= _releaseResources();

  Future<void> _releaseResources() async {
    _failed = true;
    _heartbeat?.cancel();
    _expiry?.cancel();
    if (_engine) {
      ZegoExpressEngine.onRoomStreamUpdate = null;
      ZegoExpressEngine.onRoomStateUpdate = null;
      ZegoExpressEngine.onPublisherStateUpdate = null;
      ZegoExpressEngine.onPlayerStateUpdate = null;
      ZegoExpressEngine.onRemoteCameraStateUpdate = null;
      ZegoExpressEngine.onRoomTokenWillExpire = null;
      await _streamWork;
      await _safe(_stopRemote);
      await _safe(() => ZegoExpressEngine.instance.stopPublishingStream());
      await _safe(() => ZegoExpressEngine.instance.stopPreview());
      if (_localViewId != null) {
        await _safe(() async {
          await ZegoExpressEngine.instance.destroyCanvasView(_localViewId!);
        });
      }
      if (_call != null) {
        await _safe(() async {
          await ZegoExpressEngine.instance.logoutRoom(_call!.roomId);
        });
      }
      await _safe(ZegoExpressEngine.destroyEngine);
      _engine = false;
    }
    if (_call != null) {
      await _safe(
        () => _repo
            .presence(_call!, leave: true)
            .timeout(const Duration(seconds: 3)),
      );
    }
    _update(() {
      _localView = null;
      _remoteView = null;
      _ready = false;
    });
  }

  Future<void> _leave() async {
    if (_closing) return;
    setState(() => _closing = true);
    await _startup;
    await _release();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready || !_engine || _closing) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.resumed) {
      unawaited(
        _safe(() async {
          await ZegoExpressEngine.instance.enableCamera(
            state == AppLifecycleState.resumed && _camera,
          );
          await ZegoExpressEngine.instance.muteMicrophone(
            state != AppLifecycleState.resumed || !_mic,
          );
        }),
      );
    }
  }

  @override
  void dispose() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_startup.then((_) => _release()));
    super.dispose();
  }

  Future<void> _toggle(
    Future<void> Function() action,
    VoidCallback update,
  ) async {
    try {
      await action();
      _update(update);
    } catch (_) {
      _update(() => _status = 'Impossible de modifier ce réglage. Réessayez.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.user?.id != previous?.user?.id) unawaited(_leave());
    });
    final call = _call;
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: const Color(0xff111d2d),
        appBar: AppBar(
          backgroundColor: const Color(0xff111d2d),
          foregroundColor: Colors.white,
          leading: IconButton(
            onPressed: _closing ? null : _leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(call?.peerName ?? 'Téléconsultation'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_error == null && _remoteView != null) _remoteView!,
                    if (_error != null || _remoteView == null || !_remoteCamera)
                      ColoredBox(
                        color: const Color(0xff111d2d),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _error != null
                                      ? Icons.error_outline
                                      : Icons.person_outline,
                                  size: 64,
                                  color: Colors.white70,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _error ??
                                      (call == null
                                          ? _status
                                          : _remoteView != null
                                          ? 'Caméra de ${call.peerName} désactivée'
                                          : 'En attente de ${call.peerName}'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                                if (_error != null && !kIsWeb)
                                  TextButton(
                                    onPressed: openAppSettings,
                                    child: const Text('Ouvrir les réglages'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_error == null && _localView != null)
                      Positioned(
                        right: 16,
                        top: 16,
                        child: SizedBox(
                          width: 110,
                          height: 155,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _camera
                                ? _localView!
                                : const ColoredBox(
                                    color: Colors.black54,
                                    child: Icon(
                                      Icons.videocam_off,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    if (_error == null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            backgroundColor: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    IconButton.filledTonal(
                      tooltip: _mic
                          ? 'Couper le microphone'
                          : 'Activer le microphone',
                      onPressed: !_ready
                          ? null
                          : () => _toggle(
                              () => ZegoExpressEngine.instance.muteMicrophone(
                                _mic,
                              ),
                              () => _mic = !_mic,
                            ),
                      icon: Icon(_mic ? Icons.mic : Icons.mic_off),
                    ),
                    IconButton.filledTonal(
                      tooltip: _camera
                          ? 'Couper la caméra'
                          : 'Activer la caméra',
                      onPressed: !_ready
                          ? null
                          : () => _toggle(
                              () => ZegoExpressEngine.instance.enableCamera(
                                !_camera,
                              ),
                              () => _camera = !_camera,
                            ),
                      icon: Icon(_camera ? Icons.videocam : Icons.videocam_off),
                    ),
                    if (!kIsWeb)
                      IconButton.filledTonal(
                        tooltip: 'Changer de caméra',
                        onPressed: !_ready
                            ? null
                            : () => _toggle(
                                () => ZegoExpressEngine.instance.useFrontCamera(
                                  !_frontCamera,
                                ),
                                () => _frontCamera = !_frontCamera,
                              ),
                        icon: const Icon(Icons.cameraswitch),
                      ),
                    if (!kIsWeb)
                      IconButton.filledTonal(
                        tooltip: 'Haut-parleur',
                        onPressed: !_ready
                            ? null
                            : () => _toggle(
                                () => ZegoExpressEngine.instance
                                    .setAudioRouteToSpeaker(!_speaker),
                                () => _speaker = !_speaker,
                              ),
                        icon: Icon(_speaker ? Icons.volume_up : Icons.hearing),
                      ),
                    IconButton.filled(
                      tooltip: 'Raccrocher',
                      style: IconButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _closing ? null : _leave,
                      icon: const Icon(Icons.call_end),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
