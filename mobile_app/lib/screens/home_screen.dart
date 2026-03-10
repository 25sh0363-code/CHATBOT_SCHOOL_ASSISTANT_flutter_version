import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/local_store_service.dart';
import '../services/vector_bootstrap_service.dart';
import 'calendar_screen.dart';
import 'chat_screen.dart';
import 'tests_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _bootstrapping = false;
  String _vectorStatus = 'Vector cache not checked';

  final LocalStoreService _storeService = LocalStoreService();
  final VectorBootstrapService _vectorService = VectorBootstrapService();

  Future<void> _bootstrapVectors() async {
    setState(() {
      _bootstrapping = true;
      _vectorStatus = 'Checking local vector cache...';
    });

    try {
      final path = await _vectorService.bootstrapIfNeeded(AppConfig.vectorZipUrl);
      setState(() {
        _vectorStatus = path == null
            ? 'Set VECTOR_ZIP_URL dart-define to enable vector download'
            : 'Vector cache ready: $path';
      });
    } catch (e) {
      setState(() {
        _vectorStatus = 'Vector setup failed: $e';
      });
    } finally {
      setState(() {
        _bootstrapping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ChatScreen(),
      TestsScreen(storeService: _storeService),
      CalendarScreen(storeService: _storeService),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome ${widget.authService.displayName}'),
        actions: [
          IconButton(
            onPressed: _bootstrapping ? null : _bootstrapVectors,
            tooltip: 'Bootstrap vector DB',
            icon: _bootstrapping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_for_offline_outlined),
          ),
          IconButton(
            onPressed: widget.authService.signOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F0F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC5D8E7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.memory_outlined, color: Color(0xFF13678A)),
                const SizedBox(width: 8),
                Expanded(child: Text(_vectorStatus, style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
          Expanded(child: pages[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (idx) => setState(() => _index = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Tests'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
        ],
      ),
    );
  }
}
