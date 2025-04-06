import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'control_center_page.dart';
import 'login_page.dart';

class RobotIdPage extends StatefulWidget {
  const RobotIdPage({Key? key}) : super(key: key);

  @override
  State<RobotIdPage> createState() => _RobotIdPageState();
}

class _RobotIdPageState extends State<RobotIdPage> {
  final TextEditingController _robotIdController = TextEditingController();
  List<String> _robotIds = [];
  final _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _loadRobotIds();
  }

  @override
  void dispose() {
    _robotIdController.dispose();
    super.dispose();
  }

  Future<void> _loadRobotIds() async {
    final prefs = await _prefs;
    final savedIds = prefs.getStringList('robot_ids') ?? [];
    setState(() {
      _robotIds = savedIds;
    });
  }

  Future<void> _saveRobotId(String id) async {
    if (_robotIds.contains(id)) {
      return; // Don't save if ID already exists
    }
    final prefs = await _prefs;
    final updatedIds = [..._robotIds, id];
    await prefs.setStringList('robot_ids', updatedIds);
    setState(() {
      _robotIds = updatedIds;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Robot'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await _prefs;
              await prefs.remove('robot_ids');
              await prefs.remove('current_id');
              setState(() {
                _robotIds = [];
              });
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.android,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Enter Robot ID',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please enter your robot\'s unique ID to connect',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _robotIdController,
              decoration: InputDecoration(
                labelText: 'Robot ID',
                prefixIcon: const Icon(Icons.qr_code),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hintText: 'Enter your robot\'s ID',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_robotIdController.text.isNotEmpty) {
                    await _saveRobotId(_robotIdController.text);
                    final prefs = await _prefs;
                    await prefs.setString('current_id', _robotIdController.text);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ControlCenterPage(),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 100,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Connect',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_robotIds.isNotEmpty) ...[
              const Text(
                'Previously Connected Robots:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _robotIds.length,
                  itemBuilder: (context, index) {
                    final reversedIndex = _robotIds.length - 1 - index;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.android),
                        title: Text(_robotIds[reversedIndex]),
                        onTap: () {
                          _robotIdController.text = _robotIds[reversedIndex];
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final prefs = await _prefs;
                            final updatedIds = List<String>.from(_robotIds)
                              ..removeAt(reversedIndex);
                            await prefs.setStringList('robot_ids', updatedIds);
                            setState(() {
                              _robotIds = updatedIds;
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 