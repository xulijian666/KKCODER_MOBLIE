import 'package:flutter/material.dart';
import '../widgets/pin_input.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class PairingScreen extends StatefulWidget {
  final ApiService api;
  final StorageService storage;
  final VoidCallback onPaired;

  const PairingScreen({
    super.key,
    required this.api,
    required this.storage,
    required this.onPaired,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _showPinInput = false;
  bool _useHttps = false;

  @override
  void initState() {
    super.initState();
    _loadSavedConnection();
  }

  Future<void> _loadSavedConnection() async {
    final host = await widget.storage.getServerHost();
    final port = await widget.storage.getServerPort();
    final https = await widget.storage.getUseHttps();
    if (host.isNotEmpty) _hostController.text = host;
    if (port != null) _portController.text = port.toString();
    _useHttps = https;
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    if (host.isEmpty || portStr.isEmpty) {
      setState(() => _error = '请输入服务器地址和端口');
      return;
    }
    final port = int.tryParse(portStr);
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = '端口格式错误');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      widget.api.configure(host, port, https: _useHttps);
      await widget.api.getStatus();
      await widget.storage.saveServerHost(host);
      await widget.storage.saveServerPort(port);
      await widget.storage.saveUseHttps(_useHttps);
      setState(() {
        _showPinInput = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '无法连接到 $host:$port';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyPin(String pin) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final deviceName = await widget.storage.getDeviceName();
      final token = await widget.api.verifyPin(pin, deviceName);
      await widget.storage.saveToken(token);
      widget.onPaired();
    } catch (e) {
      setState(() {
        _error = 'PIN 码错误或配对失败';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _showPinInput ? _buildPinView() : _buildConnectView(),
        ),
      ),
    );
  }

  Widget _buildConnectView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.computer, size: 64, color: Colors.orange.shade400),
        const SizedBox(height: 16),
        Text(
          '连接到 KKCODER',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '输入桌面端服务器地址',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _hostController,
          decoration: InputDecoration(
            labelText: '服务器 IP / 地址',
            hintText: 'IP 或域名',
            prefixIcon: const Icon(Icons.wifi),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _portController,
                decoration: InputDecoration(
                  labelText: '端口',
                  hintText: '桌面端显示的端口号',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                const Text('HTTPS', style: TextStyle(fontSize: 12)),
                Switch(
                  value: _useHttps,
                  onChanged: (v) => setState(() => _useHttps = v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _isLoading ? null : _connect,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('连接'),
          ),
        ),
      ],
    );
  }

  Widget _buildPinView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.pin, size: 64, color: Colors.orange.shade400),
        const SizedBox(height: 16),
        Text(
          '输入配对 PIN 码',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '请输入桌面端显示的 6 位 PIN 码',
          style: TextStyle(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 32),
        PinInput(
          onCompleted: _verifyPin,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 24),
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _showPinInput = false;
            _error = null;
          }),
          child: const Text('更换服务器'),
        ),
      ],
    );
  }
}
