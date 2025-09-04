import 'package:flutter/material.dart';
import 'package:tkt/connector/ntust_connector.dart';
import 'package:tkt/models/ntust/ap_tree_json.dart';
import 'package:tkt/pages/webview_screen.dart';
import 'package:tkt/debug/log/log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NTUSTInfoSystemPage extends StatefulWidget {
  const NTUSTInfoSystemPage({super.key});

  @override
  State<NTUSTInfoSystemPage> createState() => _NTUSTInfoSystemPageState();
}

class _NTUSTInfoSystemPageState extends State<NTUSTInfoSystemPage> {
  bool _isLoading = false;
  List<APTreeJson> _subSystems = [];
  String _errorMessage = '';
  String? _username;
  String? _password;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadSubSystems();
    _loadCredentials();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    if (!_mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_mounted) return;
      setState(() {
        _username = prefs.getString('ntust_username');
        _password = prefs.getString('ntust_password');
      });
    } catch (e) {
      Log.e('載入登入資訊時發生錯誤：$e');
    }
  }

  Future<void> _loadSubSystems() async {
    if (!_mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final subSystems = await NTUSTConnector.getSubSystem();
      if (!_mounted) return;
      setState(() {
        _subSystems = subSystems;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('載入子系統時發生錯誤：$e');
      if (!_mounted) return;
      setState(() {
        _errorMessage = '載入失敗：$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openSystemUrl(String url, String title) async {
    if (!_mounted) return;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WebViewScreen(
            initialUrl: url,
            title: title,
            onLoginResult: (success) {
              if (!success && _mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('登入失敗，請重試'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      Log.e('開啟系統時發生錯誤：$e');
      if (!_mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('無法開啟系統：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSystemList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('載入中...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSubSystems,
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    if (_subSystems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48),
            const SizedBox(height: 16),
            const Text('沒有可用的系統'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSubSystems,
              child: const Text('重新載入'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _subSystems.length,
      itemBuilder: (context, index) {
        final system = _subSystems[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            title: Text(
              system.serviceId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: system.apList.map((ap) {
              return ListTile(
                leading: const Icon(Icons.link),
                title: Text(ap.name),
                subtitle: Text(ap.url),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _openSystemUrl(ap.url, ap.name),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('資訊系統'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadSubSystems,
            tooltip: '重新載入',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSubSystems,
        child: _buildSystemList(),
      ),
    );
  }
}