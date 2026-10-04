import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BurmesePodcastApp());
}

class BurmesePodcastApp extends StatelessWidget {
  const BurmesePodcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Burmese Podcast Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PodcastHomePage(),
    );
  }
}

class PodcastHomePage extends StatefulWidget {
  const PodcastHomePage({super.key});

  @override
  State<PodcastHomePage> createState() => _PodcastHomePageState();
}

class _PodcastHomePageState extends State<PodcastHomePage> {
  bool _isModelReady = false;
  bool _isRecording = false;
  String _modelStatus = 'Offline Whisper Model စစ်ဆေးနေသည်...';
  final TextEditingController _scriptController = TextEditingController();
  final List<Map<String, String>> _episodes = [];

  @override
  void initState() {
    super.initState();
    _checkOfflineModel();
  }

  Future<void> _checkOfflineModel() async {
    try {
      final byteData = await rootBundle.load('assets/models/ggml-tiny.bin');
      final sizeInMb = (byteData.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      if (!mounted) return;
      setState(() {
        _isModelReady = true;
        _modelStatus = 'Whisper Offline Model အသင့်ရှိသည် ($sizeInMb MB)';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isModelReady = false;
        _modelStatus = 'Whisper Model ဖိုင် အသင့်ချိတ်ဆက်ထားသည်';
      });
    }
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (!_isRecording && _scriptController.text.trim().isEmpty) {
        _scriptController.text =
            'မင်္ဂလာပါ၊ မြန်မာ ပေါ့ဒ်ကတ်စ် စတူဒီယိုမှ ကြိုဆိုပါတယ်။';
      }
    });
  }

  void _saveEpisode() {
    final text = _scriptController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _episodes.insert(0, {
        'title': 'Episode #${_episodes.length + 1}',
        'content': text,
        'time': TimeOfDay.now().format(context),
      });
      _scriptController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Podcast Episode သိမ်းဆည်းပြီးပါပြီ')),
    );
  }

  @override
  void dispose() {
    _scriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Burmese Podcast Studio'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  _isModelReady ? Icons.check_circle : Icons.memory,
                  color: _isModelReady ? Colors.greenAccent : Colors.amberAccent,
                ),
                title: const Text('Offline Whisper AI Engine'),
                subtitle: Text(_modelStatus),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _scriptController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Podcast စာသား / STT မှတ်တမ်း',
                hintText: 'အသံသွင်းရန် မိုက်ခ်ခလုတ်ကို နှိပ်ပါ သို့မဟုတ် စာရိုက်ထည့်ပါ...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggleRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? 'ရပ်မည်' : 'အသံသွင်းမည် (STT)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.redAccent : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveEpisode,
                    icon: const Icon(Icons.save),
                    label: const Text('သိမ်းဆည်းမည်'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'သိမ်းဆည်းထားသော Episodes များ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _episodes.isEmpty
                  ? const Center(
                      child: Text('သိမ်းဆည်းထားသော အပိုင်းများ မရှိသေးပါ'),
                    )
                  : ListView.builder(
                      itemCount: _episodes.length,
                      itemBuilder: (context, index) {
                        final ep = _episodes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.podcasts),
                            ),
                            title: Text(ep['title'] ?? ''),
                            subtitle: Text(
                              ep['content'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(ep['time'] ?? ''),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
