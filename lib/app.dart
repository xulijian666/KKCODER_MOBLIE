import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'screens/pairing_screen.dart';
import 'screens/sessions_screen.dart';

class KkCoderApp extends StatefulWidget {
  const KkCoderApp({super.key});

  @override
  State<KkCoderApp> createState() => _KkCoderAppState();
}

class _KkCoderAppState extends State<KkCoderApp> {
  final _api = ApiService();
  final _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KKCODER',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.orange,
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade800),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      routes: {
        '/': (_) => _buildHome(),
        '/pairing': (ctx) => PairingScreen(
              api: _api,
              storage: _storage,
              onPaired: () => Navigator.of(ctx).pushReplacementNamed('/sessions'),
            ),
        '/sessions': (_) => SessionsScreen(api: _api, storage: _storage),
      },
    );
  }

  Widget _buildHome() {
    return FutureBuilder<String?>(
      future: _storage.getToken(),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data != null) {
          _loadConnection();
          return SessionsScreen(api: _api, storage: _storage);
        }
        // 使用 Builder 包裹以获取正确的 Navigator 子 context
        return Builder(
          builder: (navigatorContext) => PairingScreen(
            api: _api,
            storage: _storage,
            onPaired: () => Navigator.of(navigatorContext).pushReplacementNamed('/sessions'),
          ),
        );
      },
    );
  }

  Future<void> _loadConnection() async {
    final host = await _storage.getServerHost();
    final port = await _storage.getServerPort();
    if (host.isNotEmpty && port != null) {
      _api.configure(host, port);
    }
  }
}
