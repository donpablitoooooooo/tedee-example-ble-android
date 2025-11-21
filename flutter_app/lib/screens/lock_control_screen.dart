import 'package:flutter/material.dart';
import '../services/tedee_lock_service.dart';

class LockControlScreen extends StatefulWidget {
  const LockControlScreen({super.key});

  @override
  State<LockControlScreen> createState() => _LockControlScreenState();
}

class _LockControlScreenState extends State<LockControlScreen> {
  final TedeeLockService _lockService = TedeeLockService();

  bool _isConnected = false;
  bool _isConnecting = false;
  final List<String> _messages = [];

  // Preset values from Constants.kt
  final String _serialNumber = '10530206-030484';
  final String _deviceId = '273450';
  final String _name = 'Lock-40C5';

  @override
  void initState() {
    super.initState();
    _lockService.setNotificationListener((message) {
      setState(() {
        _messages.insert(0, message);
      });
    });
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final success = await _lockService.connect(
        serialNumber: _serialNumber,
        deviceId: _deviceId,
        name: _name,
        keepConnection: true,
      );

      setState(() {
        _isConnected = success;
        _isConnecting = false;
        if (success) {
          _messages.insert(0, '✅ Connected to lock');
        }
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _messages.insert(0, '❌ Connection failed: $e');
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _lockService.disconnect();
      setState(() {
        _isConnected = false;
        _messages.insert(0, '🔌 Disconnected from lock');
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, '❌ Disconnect failed: $e');
      });
    }
  }

  Future<void> _openLock() async {
    try {
      final result = await _lockService.openLock();
      setState(() {
        _messages.insert(0, '🔓 Open: $result');
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, '❌ Open failed: $e');
      });
    }
  }

  Future<void> _closeLock() async {
    try {
      final result = await _lockService.closeLock();
      setState(() {
        _messages.insert(0, '🔒 Close: $result');
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, '❌ Close failed: $e');
      });
    }
  }

  Future<void> _pullSpring() async {
    try {
      final result = await _lockService.pullSpring();
      setState(() {
        _messages.insert(0, '🔧 Pull Spring: $result');
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, '❌ Pull spring failed: $e');
      });
    }
  }

  Future<void> _getLockState() async {
    try {
      final result = await _lockService.getLockState();
      setState(() {
        _messages.insert(0, '📊 Lock State: $result');
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, '❌ Get state failed: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tedee Lock Control'),
        backgroundColor: const Color(0xFF22345a), // midnight_blue
      ),
      body: Column(
        children: [
          // Connection Section
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[100],
            child: Column(
              children: [
                Text(
                  _isConnecting
                      ? 'Connecting...'
                      : _isConnected
                          ? '✅ Connected'
                          : '⚫ Disconnected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isConnected ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_name ($_serialNumber)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isConnecting || _isConnected ? null : _connect,
                      child: const Text('Connect'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isConnected ? _disconnect : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Control Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isConnected ? _openLock : null,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Open'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isConnected ? _closeLock : null,
                        icon: const Icon(Icons.lock),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isConnected ? _pullSpring : null,
                        icon: const Icon(Icons.settings_input_component),
                        label: const Text('Pull Spring'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isConnected ? _getLockState : null,
                        icon: const Icon(Icons.info),
                        label: const Text('Get State'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: Container(
              color: Colors.black87,
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[800]!),
                            ),
                          ),
                          child: Text(
                            _messages[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
