import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';

const String kSiteUrl = 'https://inotires.uz';
const String kAppName = 'INO TIRES';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InoTiresApp());
}

class InoTiresApp extends StatelessWidget {
  const InoTiresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.black,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  double _loadProgress = 0;
  bool _hasError = false;
  bool _firstLoadDone = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() => _loadProgress = progress / 100);
          },
          onPageStarted: (url) {
            setState(() => _hasError = false);
          },
          onPageFinished: (url) {
            setState(() {
              _loadProgress = 1;
              _firstLoadDone = true;
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() => _hasError = true);
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.navigate;

            const externalSchemes = ['tel', 'sms', 'mailto', 'whatsapp', 'tg'];
            if (externalSchemes.contains(uri.scheme)) {
              _launchExternally(uri);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(kSiteUrl));

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      androidController.setOnShowFileSelector(_androidFilePicker);
    }

    _controller = controller;
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      FileType type = FileType.any;
      List<String>? allowedExtensions;

      final accepts = params.acceptTypes.join(',').toLowerCase();
      if (accepts.contains('image')) {
        type = FileType.image;
      } else if (accepts.contains('sheet') ||
          accepts.contains('excel') ||
          accepts.contains('csv') ||
          accepts.contains('xls')) {
        type = FileType.custom;
        allowedExtensions = ['xlsx', 'xls', 'csv'];
      }

      final result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
      );

      if (result == null) return [];
      return result.files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return [];
    }
  }
  Future<void> _launchExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No app available to handle this link type; ignore.
    }
  }

  Future<void> _retry() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.contains(ConnectivityResult.none);
    if (!offline) {
      setState(() => _hasError = false);
      _controller.reload();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Internet aloqasi yo\'q')),
      );
    }
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBack();
        if (shouldPop && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            if (!_hasError) WebViewWidget(controller: _controller),
            if (!_firstLoadDone && !_hasError) _buildSplash(),
            if (_loadProgress < 1 && _firstLoadDone && !_hasError)
              Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  value: _loadProgress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation(Colors.black),
                ),
              ),
            if (_hasError) _buildErrorView(),
          ],
        ),
      ),
    );
  }

  Widget _buildSplash() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            kAppName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 52, color: Colors.black54),
          const SizedBox(height: 16),
          const Text(
            'Saytga ulanib bo\'lmadi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Internet aloqasini tekshirib, qayta urinib ko\'ring.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _retry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Qayta urinish'),
          ),
        ],
      ),
    );
  }
}
