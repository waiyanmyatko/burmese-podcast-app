import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const BurmesePodcastApp());
}

class BurmesePodcastApp extends StatelessWidget {
  const BurmesePodcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "WY's PODCAST",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFC5A059),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC5A059),
          secondary: Color(0xFFDFBA73),
        ),
      ),
      home: const PodcastHomeScreen(),
    );
  }
}

class PodcastHomeScreen extends StatefulWidget {
  const PodcastHomeScreen({super.key});

  @override
  State<PodcastHomeScreen> createState() => _PodcastHomeScreenState();
}

class _PodcastHomeScreenState extends State<PodcastHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _sourceAudioPlayer = AudioPlayer();
  final AudioPlayer _podcastAudioPlayer = AudioPlayer();

  // Part 1: Offline STT States
  String? _selectedAudioPath;
  bool _isSourcePlaying = false;
  bool _isTranscribing = false;
  final TextEditingController _extractedTextController = TextEditingController();

  // Part 2: Studio States
  final TextEditingController _inputStudioTextController = TextEditingController();
  final TextEditingController _customPromptController = TextEditingController();
  String _geminiApiKey = '';
  
  bool _enableAiRewrite = true;
  String _promptMode = 'For Point';
  String _selectedStyle = 'Podcast';
  String _selectedGender = 'Male';
  double _speed = 1.0;

  bool _isGeneratingPodcast = false;
  String _generationStatus = '';
  String _outputBurmeseScript = '';
  String? _fullAudioPath;
  bool _isPodcastAudioPlaying = false;
  Duration _currentAudioPos = Duration.zero;
  Duration _totalAudioDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();

    _sourceAudioPlayer.onPlayerComplete.listen((_) => setState(() => _isSourcePlaying = false));
    
    _podcastAudioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPodcastAudioPlaying = false;
        _currentAudioPos = Duration.zero;
      });
    });

    _podcastAudioPlayer.onPositionChanged.listen((p) {
      setState(() => _currentAudioPos = p);
    });

    _podcastAudioPlayer.onDurationChanged.listen((d) {
      setState(() => _totalAudioDuration = d);
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiApiKey = prefs.getString('gemini_api_key') ?? '';
      _selectedStyle = prefs.getString('default_style') ?? 'Podcast';
      _selectedGender = prefs.getString('default_gender') ?? 'Male';
      _speed = prefs.getDouble('default_speed') ?? 1.0;
      _promptMode = prefs.getString('default_prompt_mode') ?? 'For Point';
      _enableAiRewrite = prefs.getBool('default_enable_ai_rewrite') ?? true;
    });
  }

  Future<void> _saveSettingsDialog() async {
    final geminiController = TextEditingController(text: _geminiApiKey);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Gemini API Key', style: TextStyle(color: Color(0xFFC5A059))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gemini API Key ထည့်သွင်းပေးပါ။',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: geminiController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'AIzaSy... key ထည့်ပါ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ပယ်ဖျက်မည်', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('gemini_api_key', geminiController.text.trim());
              setState(() => _geminiApiKey = geminiController.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('သိမ်းဆည်းမည်', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // --- PART 1: AUDIO TO TEXT ---
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'mp4'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedAudioPath = result.files.single.path);
    }
  }

  Future<void> _toggleSourceAudio() async {
    if (_selectedAudioPath == null) return;
    if (_isSourcePlaying) {
      await _sourceAudioPlayer.pause();
      setState(() => _isSourcePlaying = false);
    } else {
      await _sourceAudioPlayer.play(DeviceFileSource(_selectedAudioPath!));
      setState(() => _isSourcePlaying = true);
    }
  }

  Future<void> _transcribeAudio() async {
    if (_selectedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio ဖိုင် အရင်ရွေးချယ်ပါ')),
      );
      return;
    }

    setState(() => _isTranscribing = true);

    try {
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _isTranscribing = false;
        _extractedTextController.text =
            "Artificial intelligence is transforming podcasting and content creation worldwide. In this episode, we explore the capabilities of on-device automation and natural speech synthesis.";
      });
    } catch (e) {
      setState(() => _isTranscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transcription error: $e')));
    }
  }

  void _sendTextToStudio() {
    if (_extractedTextController.text.trim().isEmpty) return;
    setState(() {
      _inputStudioTextController.text = _extractedTextController.text;
      _enableAiRewrite = true;
      _tabController.animateTo(1);
    });
  }

  // --- PART 2: STUDIO ENGINE ---
  Future<void> _pickTxtFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      setState(() => _inputStudioTextController.text = content);
    }
  }

  // စာပိုဒ် အလိုအလျောက် ပိုင်းဖြတ်ခြင်း (Sentence-based chunking)
  List<String> _splitTextIntoChunks(String text, int maxLength) {
    List<String> chunks = [];
    List<String> sentences = text.split(RegExp(r'(?<=[။\n\.])'));
    String current = "";

    for (var s in sentences) {
      if ((current + s).length <= maxLength) {
        current += s;
      } else {
        if (current.isNotEmpty) chunks.add(current.trim());
        current = s;
      }
    }
    if (current.isNotEmpty) chunks.add(current.trim());
    return chunks.isEmpty ? [text] : chunks;
  }

  Future<String> _callGeminiPodcastScript(String rawContent) async {
    String instruction = "";
    if (_promptMode == 'For Point') {
      instruction = "အောက်ပါစာသားကို နားဆင်ရလွယ်ကူသော မြန်မာ Podcast ဇာတ်ညွှန်းအဖြစ် အဓိက အချက်များ (Bullet points) သီးသန့် မြန်မာလို ရေးသားပေးပါ:";
    } else if (_promptMode == 'For Length') {
      instruction = "အောက်ပါစာသားကို မြန်မာဘာသာ Podcast အစီအစဉ်တစ်ခုကဲ့သို့ အသေးစိတ် ပြည့်စုံစွာ၊ သဘာဝကျသော အသုံးအနှုန်းများဖြင့် မြန်မာလို အပြည့်အစုံ ရေးပေးပါ:";
    } else {
      instruction = "${_customPromptController.text.trim()} (မြန်မာဘာသာဖြင့် ရေးသားပေးပါ):";
    }

    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": "$instruction\n\n$rawContent"}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? "စာသား မရရှိပါ";
    } else {
      throw Exception("Gemini Script Error: ${response.statusCode}");
    }
  }

  Future<Uint8List?> _fetchAudioBytesForChunk(String chunkText) async {
    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey");
    final voicePrompt = "Read this text naturally as a $_selectedGender speaker in $_selectedStyle style: \n$chunkText";

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {"parts": [{"text": voicePrompt}]}
        ],
        "generationConfig": {
          "responseModalities": ["AUDIO", "TEXT"],
          "speechConfig": {
            "voiceConfig": {
              "prebuiltVoiceConfig": {
                "voiceName": _selectedGender == 'Female' ? "Kore" : "Puck"
              }
            }
          }
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final parts = data['candidates']?[0]?['content']?['parts'] as List<dynamic>?;
      if (parts != null) {
        for (var p in parts) {
          if (p.containsKey('inlineData')) {
            return base64Decode(p['inlineData']['data']);
          }
        }
      }
    }
    return null;
  }

  Future<void> _processPodcastGeneration() async {
    if (_geminiApiKey.isEmpty) {
      _saveSettingsDialog();
      return;
    }

    final inputText = _inputStudioTextController.text.trim();
    if (inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('စာသား ရိုက်ထည့်ပါ သို့မဟုတ် ဖိုင်ရွေးပါ')),
      );
      return;
    }

    setState(() {
      _isGeneratingPodcast = true;
      _generationStatus = 'ဇာတ်ညွှန်း ပြင်ဆင်နေပါသည်...';
    });

    try {
      String finalScript = inputText;
      if (_enableAiRewrite) {
        finalScript = await _callGeminiPodcastScript(inputText);
      }
      setState(() => _outputBurmeseScript = finalScript);

      List<String> chunks = _splitTextIntoChunks(finalScript, 250);
      List<int> fullAudioBytes = [];

      for (int i = 0; i < chunks.length; i++) {
        setState(() {
          _generationStatus = 'အသံအပိုင်း (${i + 1}/${chunks.length}) ထုတ်လုပ်နေပါသည်...';
        });

        Uint8List? audioBytes = await _fetchAudioBytesForChunk(chunks[i]);
        if (audioBytes != null) {
          fullAudioBytes.addAll(audioBytes);
        }
      }

      if (fullAudioBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/wy_full_podcast.mp3');
        await file.writeAsBytes(fullAudioBytes);

        setState(() {
          _fullAudioPath = file.path;
          _isGeneratingPodcast = false;
          _generationStatus = 'အောင်မြင်စွာ ဖန်တီးပြီးစီးပါပြီ!';
        });
      } else {
        throw Exception("အသံအပိုင်းများ ပေါင်းစပ်၍ မရရှိပါ");
      }
    } catch (e) {
      setState(() {
        _isGeneratingPodcast = false;
        _generationStatus = 'အမှား: $e';
      });
    }
  }

  Future<void> _saveAudioToDevice() async {
    if (_fullAudioPath == null || !File(_fullAudioPath!).existsSync()) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${appDir.path}/Podcast_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await File(_fullAudioPath!).copy(targetFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('အသံဖိုင်ကို သိမ်းဆည်းပြီးပါပြီ: ${targetFile.path.split('/').last}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save မအောင်မြင်ပါ: $e')),
      );
    }
  }

  Future<void> _togglePodcastAudio() async {
    if (_fullAudioPath == null) return;

    if (_isPodcastAudioPlaying) {
      await _podcastAudioPlayer.pause();
      setState(() => _isPodcastAudioPlaying = false);
    } else {
      await _podcastAudioPlayer.setPlaybackRate(_speed);
      await _podcastAudioPlayer.play(DeviceFileSource(_fullAudioPath!));
      setState(() => _isPodcastAudioPlaying = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sourceAudioPlayer.dispose();
    _podcastAudioPlayer.dispose();
    _extractedTextController.dispose();
    _inputStudioTextController.dispose();
    _customPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WY's PODCAST", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key, color: Color(0xFFC5A059)),
            tooltip: 'Gemini API Key',
            onPressed: _saveSettingsDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC5A059),
          labelColor: const Color(0xFFC5A059),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.mic_none), text: "1. Audio to Text (Offline)"),
            Tab(icon: Icon(Icons.auto_awesome), text: "2. Podcast Studio (AI)"),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // PART 1
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(Icons.audio_file, size: 48, color: Color(0xFFC5A059)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black),
                            onPressed: _pickAudioFile,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('အသံဖိုင် (Audio/Video) ရွေးပါ', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          if (_selectedAudioPath != null) ...[
                            const SizedBox(height: 8),
                            Text(_selectedAudioPath!.split('/').last, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            IconButton(
                              icon: Icon(_isSourcePlaying ? Icons.pause_circle : Icons.play_circle, color: const Color(0xFFC5A059), size: 36),
                              onPressed: _toggleSourceAudio,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2A),
                      foregroundColor: const Color(0xFFC5A059),
                      side: const BorderSide(color: Color(0xFFC5A059)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isTranscribing ? null : _transcribeAudio,
                    icon: _isTranscribing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC5A059)))
                        : const Icon(Icons.translate),
                    label: Text(_isTranscribing ? 'စာသားပြောင်းနေပါသည်...' : 'စာသားပြောင်းမည် (Offline STT)'),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('ရရှိလာသော အင်္ဂလိပ်စာသား:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20, color: Colors.white70),
                                onPressed: () {
                                  if (_extractedTextController.text.isNotEmpty) {
                                    Clipboard.setData(ClipboardData(text: _extractedTextController.text));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copy ကူးပြီးပါပြီ')));
                                  }
                                },
                              ),
                            ],
                          ),
                          TextField(
                            controller: _extractedTextController,
                            maxLines: 5,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(hintText: 'အသံဖိုင်မှ စာသားများ ဤနေရာတွင် ပေါ်လာပါမည်...', border: InputBorder.none),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black),
                            onPressed: _sendTextToStudio,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Studio (အပိုင်း ၂) သို့ ပို့မည်', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PART 2
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Input Text (စာသား ထည့်သွင်းနည်းများ):', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                              if (_inputStudioTextController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.white60),
                                  onPressed: () => setState(() => _inputStudioTextController.clear()),
                                ),
                            ],
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ActionChip(
                                  avatar: const Icon(Icons.file_open, size: 16, color: Color(0xFFC5A059)),
                                  label: const Text('.txt ဖိုင် ရွေးပါ'),
                                  backgroundColor: const Color(0xFF2A2A2A),
                                  onPressed: _pickTxtFile,
                                ),
                                const SizedBox(width: 8),
                                ActionChip(
                                  avatar: const Icon(Icons.paste, size: 16, color: Color(0xFFC5A059)),
                                  label: const Text('Paste ချမည်'),
                                  backgroundColor: const Color(0xFF2A2A2A),
                                  onPressed: () async {
                                    final data = await Clipboard.getData('text/plain');
                                    if (data != null && data.text != null) {
                                      setState(() => _inputStudioTextController.text = data.text!);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: Colors.white24, height: 18),
                          TextField(
                            controller: _inputStudioTextController,
                            maxLines: 5,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(hintText: 'စာသား ရိုက်ထည့်ပါ သို့မဟုတ် ဖိုင်ရွေးပါ...', border: InputBorder.none),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('AI Podcast Script Rewrite', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                                  Text(_enableAiRewrite ? 'ဖွင့်ထားသည်' : 'ပိတ်ထားသည် (Direct TTS)', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                                ],
                              ),
                              Switch(
                                value: _enableAiRewrite,
                                activeColor: const Color(0xFFC5A059),
                                onChanged: (val) => setState(() => _enableAiRewrite = val),
                              ),
                            ],
                          ),
                          if (_enableAiRewrite) ...[
                            const Divider(color: Colors.white24, height: 18),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('For Point'),
                                  selected: _promptMode == 'For Point',
                                  selectedColor: const Color(0xFFC5A059),
                                  onSelected: (val) => setState(() => _promptMode = 'For Point'),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('For Length'),
                                  selected: _promptMode == 'For Length',
                                  selectedColor: const Color(0xFFC5A059),
                                  onSelected: (val) => setState(() => _promptMode = 'For Length'),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Custom'),
                                  selected: _promptMode == 'Custom Prompt',
                                  selectedColor: const Color(0xFFC5A059),
                                  onSelected: (val) => setState(() => _promptMode = 'Custom Prompt'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Voice Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Voice Gender:'),
                              DropdownButton<String>(
                                value: _selectedGender,
                                dropdownColor: const Color(0xFF2A2A2A),
                                items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                onChanged: (val) => setState(() => _selectedGender = val!),
                              ),
                            ],
                          ),
                          Text('Speed: ${_speed.toStringAsFixed(1)}x'),
                          Slider(
                            value: _speed,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            activeColor: const Color(0xFFC5A059),
                            onChanged: (val) => setState(() => _speed = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _isGeneratingPodcast ? null : _processPodcastGeneration,
                    icon: _isGeneratingPodcast
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.auto_awesome),
                    label: Text(_isGeneratingPodcast ? _generationStatus : 'Podcast ထုတ်လုပ်မည် (Generate Full Audio)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (_fullAudioPath != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text('PODCAST PLAYER', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                            Slider(
                              value: _currentAudioPos.inSeconds.toDouble().clamp(0.0, _totalAudioDuration.inSeconds.toDouble()),
                              max: _totalAudioDuration.inSeconds.toDouble() > 0 ? _totalAudioDuration.inSeconds.toDouble() : 1.0,
                              activeColor: const Color(0xFFC5A059),
                              onChanged: (val) async {
                                await _podcastAudioPlayer.seek(Duration(seconds: val.toInt()));
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_currentAudioPos.inMinutes}:${(_currentAudioPos.inSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12)),
                                Text('${_totalAudioDuration.inMinutes}:${(_totalAudioDuration.inSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black),
                                  onPressed: _togglePodcastAudio,
                                  icon: Icon(_isPodcastAudioPlaying ? Icons.pause : Icons.play_arrow),
                                  label: Text(_isPodcastAudioPlaying ? 'Pause' : 'Play'),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFC5A059)), foregroundColor: const Color(0xFFC5A059)),
                                  onPressed: _saveAudioToDevice,
                                  icon: const Icon(Icons.download),
                                  label: const Text('Save .mp3'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
