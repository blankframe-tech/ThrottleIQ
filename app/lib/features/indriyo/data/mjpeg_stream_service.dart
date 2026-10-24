import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Reads raw multipart/x-mixed-replace MJPEG byte stream from ESP32-CAM
/// using built-in dart:io HttpClient (zero external dependencies).
class MjpegStreamService {
  final String streamUrl;
  HttpClient? _httpClient;
  StreamSubscription? _subscription;
  final StreamController<Uint8List> _frameController =
      StreamController<Uint8List>.broadcast();

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  Stream<Uint8List> get frameStream => _frameController.stream;

  MjpegStreamService({this.streamUrl = 'http://192.168.4.1:81/stream'});

  void start() async {
    _httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 4);

    try {
      final request = await _httpClient!.getUrl(Uri.parse(streamUrl));
      request.headers.set('User-Agent', 'ThrottleIQ-Indriyo-Client');
      final response = await request.close();

      if (response.statusCode == 200) {
        _isConnected = true;
        final List<int> buffer = [];

        _subscription = response.listen(
          (List<int> chunk) {
            buffer.addAll(chunk);

            while (true) {
              int soi = -1;
              for (int i = 0; i < buffer.length - 1; i++) {
                if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
                  soi = i;
                  break;
                }
              }

              if (soi == -1) {
                if (buffer.length > 500000) buffer.clear();
                break;
              }

              int eoi = -1;
              for (int i = soi + 2; i < buffer.length - 1; i++) {
                if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
                  eoi = i + 2;
                  break;
                }
              }

              if (eoi != -1) {
                final frameBytes = Uint8List.fromList(buffer.sublist(soi, eoi));
                if (!_frameController.isClosed) {
                  _frameController.add(frameBytes);
                }
                buffer.removeRange(0, eoi);
              } else {
                break;
              }
            }
          },
          onError: (err) {
            _isConnected = false;
            if (!_frameController.isClosed) {
              _frameController.addError(err);
            }
          },
          onDone: () {
            _isConnected = false;
          },
          cancelOnError: false,
        );
      } else {
        _isConnected = false;
      }
    } catch (e) {
      _isConnected = false;
      if (!_frameController.isClosed) {
        _frameController.addError(e);
      }
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
    _isConnected = false;
  }

  void dispose() {
    stop();
    if (!_frameController.isClosed) {
      _frameController.close();
    }
  }
}
