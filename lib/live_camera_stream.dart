import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dio/dio.dart';

class LiveCameraStream extends StatefulWidget {
  const LiveCameraStream({super.key});

  @override
  State<LiveCameraStream> createState() => _LiveCameraStreamState();
}

class _LiveCameraStreamState extends State<LiveCameraStream> {
  final _localRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  bool _isStreaming = false;
  final Dio _dio = Dio();

  final String backendUrl =
      "https://webhook.site/18509965-c5e2-4dca-a4ea-12cbc7f5c4b2";

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  Future<void> _startCameraStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {'facingMode': 'user'},
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;

    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(config);

    for (var track in _localStream!.getTracks()) {
      _peerConnection?.addTrack(track, _localStream!);
    }

    _peerConnection?.onIceCandidate = (candidate) async {
      print('ICE candidate: ${candidate.toMap()}');

      try {
        await _dio.post(
          backendUrl,
          data: {
            "type": "candidate",
            "candidate": candidate.toMap(),
          },
        );
      } catch (e) {
        print("Error sending ICE candidate: $e");
      }
    };

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    print('Local SDP offer: ${offer.sdp}');

    try {
      await _dio.post(
        backendUrl,
        data: {
          "type": "offer",
          "sdp": offer.sdp,
          "sdpType": offer.type,
        },
      );
    } catch (e) {
      print("Error sending offer: $e");
    }

    setState(() => _isStreaming = true);
  }

  Future<void> _stopCameraStream() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    _localRenderer.srcObject = null;

    setState(() {
      _isStreaming = false;
      _localStream = null;
      _peerConnection = null;
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Personal Trainer'),
        centerTitle: true,
      ),
      body: Center(
        child: _isStreaming
            ? Stack(
          children: [
            Positioned.fill(
              child: RTCVideoView(_localRenderer, mirror: true),
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _stopCameraStream,
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: const Text("Stop Camera",
                      style:
                      TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            )
          ],
        )
            : ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _startCameraStream,
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          label: const Text("Start Camera",
              style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
      ),
    );
  }
}
