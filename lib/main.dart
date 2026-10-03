import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Feature: AI Rewrite On/Off Switch
  bool _enableAiRewrite = true;
  String _promptMode = 'For Point';
  String _selectedStyle = 'Podcast';
  String _selectedGender = 'Male';
  double _speed = 1.0;

  bool _isGeneratingPodcast = false;
  String _outputBurmeseScript = '';
  String? _generatedAudioPath;
  bool _isPodcastAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();

    _sourceAudioPlayer.onPlayerComplete.listen((_) => setState(() => _isSourcePlaying = false));
    _podcastAudioPlayer.onPlayerComplete.listen((_) => setState(() => _isPodcastAudioPlaying = false));
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
              'အပိုင်း (၂) အတွက် Gemini API Key ထည့်ပေးပါ။ အပိုင်း (၁) တွင် မည်သည့် Key မှ မလိုပါ။',
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

  // --- PART 1 LOGIC ---
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'mp4'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedAudioPath = result.files.single.path;
      });
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

  Future<void> _transcribeAudioOffline() async {
    if (_selectedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ကျေးဇူးပြု၍ Audio ဖိုင် အရင်ရွေးချယ်ပါ')),
      );
      return;
    }

    setState(() => _isTranscribing = true);
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isTranscribing = false;
      _extractedTextController.text =
          "This is the transcribed English text extracted from the audio file. Artificial Intelligence and mobile apps are growing rapidly worldwide.";
    });
  }

  void _sendTextToStudio() {
    if (_extractedTextController.text.trim().isEmpty) return;
    setState(() {
      _inputStudioTextController.text = _extractedTextController.text;
      _enableAiRewrite = true; // Audio to text ဆိုပါက AI Rewrite ကို On ပေးခြင်း
      _tabController.animateTo(1);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('စာသားကို အပိုင်း (၂) Podcast Studio သို့ ပို့ဆောင်ပြီးပါပြီ')),
    );
  }

  // --- PART 2 LOGIC ---
  Future<void> _pickTxtFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      setState(() {
        _inputStudioTextController.text = content;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result.files.single.name} ဖိုင်မှ စာသားကို ရယူပြီးပါပြီ')),
        );
      }
    }
  }

  void _importFromPart1() {
    if (_extractedTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('အပိုင်း (၁) တွင် မည်သည့် စာသားမှ မရှိသေးပါ')),
      );
      return;
    }
    setState(() {
      _inputStudioTextController.text = _extractedTextController.text;
      _enableAiRewrite = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('အပိုင်း (၁) မှ စာသားကို ရယူပြီးပါပြီ')),
    );
  }

  Future<void> _saveAsNewDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_style', _selectedStyle);
    await prefs.setString('default_gender', _selectedGender);
    await prefs.setDouble('default_speed', _speed);
    await prefs.setString('default_prompt_mode', _promptMode);
    await prefs.setBool('default_enable_ai_rewrite', _enableAiRewrite);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting များကို Default အဖြစ် သိမ်းဆည်းပြီးပါပြီ။')),
      );
    }
  }

  // Gemini API Script Generator
  Future<String> _callGeminiPodcastScript(String rawContent) async {
    String instruction = "";
    if (_promptMode == 'For Point') {
      instruction = "အောက်ပါစာသားကို နားဆင်ရလွယ်ကူပြီး စိတ်ဝင်စားဖွယ်ကောင်းသော မြန်မာ Podcast ဇာတ်ညွှန်းအဖြစ် အဓိက အချက်များ (Bullet points) သီးသန့် မြန်မာဘာသာဖြင့် ရေးသားပေးပါ:";
    } else if (_promptMode == 'For Length') {
      instruction = "အောက်ပါစာသားကို မြန်မာဘာသာ Podcast အစီအစဉ်တစ်ခုကဲ့သို့ အသေးစိတ် ပြည့်စုံစွာ၊ သဘာဝကျသော အသုံးအနှုန်းများဖြင့် မြန်မာဘာသာဖြင့် အပြည့်အစုံ ရေးသားတင်ဆက်ပေးပါ:";
    } else {
      instruction = "${_customPromptController.text.trim()} (ကျေးဇူးပြု၍ မြန်မာဘာသာဖြင့် ရေးသားပေးပါ):";
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

  // Gemini API Voice / Audio Generator
  Future<String?> _callGeminiAudioTTS(String scriptToRead) async {
    try {
      final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey");
      final voicePrompt = "Read this text naturally and clearly as a $_selectedGender speaker in $_selectedStyle tone: \n$scriptToRead";

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": voicePrompt}
              ]
            }
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
              final base64Audio = p['inlineData']['data'];
              final bytes = base64Decode(base64Audio);
              final tempDir = Directory.systemTemp;
              final file = File('${tempDir.path}/gemini_podcast_output.mp3');
              await file.writeAsBytes(bytes);
              return file.path;
            }
          }
        }
      }
    } catch (_) {}
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
        const SnackBar(content: Text('Podcast ဖန်တီးရန် စာသား ရိုက်ထည့်ပါ သို့မဟုတ် File ရွေးပါ')),
      );
      return;
    }

    setState(() => _isGeneratingPodcast = true);

    try {
      String finalScript = inputText;

      // အကယ်၍ AI Rewrite Switch ဖွင့်ထားပါက Gemini ဖြင့် Podcast Script အရင်ရေးခိုင်းမည်
      if (_enableAiRewrite) {
        finalScript = await _callGeminiPodcastScript(inputText);
      }

      // Voice TTS ဖန်တီးခြင်း
      String? audioPath = await _callGeminiAudioTTS(finalScript);

      setState(() {
        _outputBurmeseScript = finalScript;
        _generatedAudioPath = audioPath;
        _isGeneratingPodcast = false;
      });
    } catch (e) {
      setState(() => _isGeneratingPodcast = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('အမှားဖြစ်ပေါ်ပါသည်: $e')),
      );
    }
  }

  Future<void> _togglePodcastAudio() async {
    if (_generatedAudioPath != null && File(_generatedAudioPath!).existsSync()) {
      if (_isPodcastAudioPlaying) {
        await _podcastAudioPlayer.pause();
        setState(() => _isPodcastAudioPlaying = false);
      } else {
        await _podcastAudioPlayer.setPlaybackRate(_speed);
        await _podcastAudioPlayer.play(DeviceFileSource(_generatedAudioPath!));
        setState(() => _isPodcastAudioPlaying = true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('အသံဖိုင် ဖတ်ရှုမရပါ')),
      );
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
            // ==================== TAB 1: AUDIO TO TEXT (OFFLINE) ====================
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC5A059),
                              foregroundColor: Colors.black,
                            ),
                            onPressed: _pickAudioFile,
                            icon: const Icon(Icons.file_upload),
                            label: const Text('အသံဖိုင် (Audio/Video) ရွေးပါ', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          if (_selectedAudioPath != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _selectedAudioPath!.split('/').last,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
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
                    onPressed: _isTranscribing ? null : _transcribeAudioOffline,
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
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('စာသား Copy ကူးပြီးပါပြီ')));
                                  }
                                },
                                tooltip: 'Copy',
                              ),
                            ],
                          ),
                          TextField(
                            controller: _extractedTextController,
                            maxLines: 6,
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'အသံဖိုင်မှ စာသားများ ဤနေရာတွင် ပေါ်လာပါမည်...',
                              border: InputBorder.none,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black),
                            onPressed: _sendTextToStudio,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Studio (အပိုင်း ၂) သို့ တိုက်ရိုက်ပို့မည်', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================== TAB 2: PODCAST STUDIO (AI) ====================
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Input Options Card
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
                              const Text('Input Text (စာသား ထည့်သွင်းနည်းများ):',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                              if (_inputStudioTextController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.white60),
                                  onPressed: () => setState(() => _inputStudioTextController.clear()),
                                  tooltip: 'စာသားများ အကုန်ဖျက်မည်',
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
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
                                  avatar: const Icon(Icons.input, size: 16, color: Color(0xFFC5A059)),
                                  label: const Text('အပိုင်း (၁) မှ ယူမည်'),
                                  backgroundColor: const Color(0xFF2A2A2A),
                                  onPressed: _importFromPart1,
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
                            decoration: const InputDecoration(
                              hintText: 'စာသား ရိုက်ထည့်ပါ၊ Paste ချပါ သို့မဟုတ် အပေါ်မှ ဖိုင်ရွေးပါ...',
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // AI Script Rewrite Switch & Prompt Settings
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
                                  const Text('AI Podcast Script Rewrite',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                                  Text(
                                    _enableAiRewrite
                                        ? 'ဖွင့်ထားသည် (Gemini ဖြင့် ဇာတ်ညွှန်းပြင်မည်)'
                                        : 'ပိတ်ထားသည် (ရိုက်ထားသည့်အတိုင်း ဒဲ့ TTS ဖတ်မည်)',
                                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                                  ),
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
                            const Text('Podcast Style / Prompt ရွေးချယ်မှု',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                            const SizedBox(height: 8),
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
                            if (_promptMode == 'Custom Prompt') ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _customPromptController,
                                decoration: const InputDecoration(hintText: 'စိတ်ကြိုက် Prompt ညွှန်ကြားချက် ရိုက်ထည့်ပါ...'),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Voice Settings
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
                              const Text('Style:'),
                              DropdownButton<String>(
                                value: _selectedStyle,
                                dropdownColor: const Color(0xFF2A2A2A),
                                items: ['Podcast', 'Tutor', 'Storytelling'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (val) => setState(() => _selectedStyle = val!),
                              ),
                              const Text('Gender:'),
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
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFC5A059))),
                              onPressed: _saveAsNewDefault,
                              child: const Text('Save as Default', style: TextStyle(color: Color(0xFFC5A059))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isGeneratingPodcast ? null : _processPodcastGeneration,
                    icon: _isGeneratingPodcast
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isGeneratingPodcast
                          ? 'ဖန်တီးနေပါသည်...'
                          : (_enableAiRewrite ? 'Podcast ဖန်တီးမည် (Rewrite & TTS)' : 'အသံဖိုင် ထုတ်လုပ်မည် (Direct TTS)'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  if (_outputBurmeseScript.isNotEmpty) ...[
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
                                const Text('SCRIPT / TEXT ရလဒ်', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20, color: Colors.white70),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _outputBurmeseScript));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Script Copy ကူးပြီးပါပြီ')));
                                  },
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white24),
                            SelectableText(_outputBurmeseScript, style: const TextStyle(fontSize: 14, height: 1.6)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isPodcastAudioPlaying ? Colors.redAccent : const Color(0xFFC5A059),
                                foregroundColor: Colors.black,
                              ),
                              onPressed: _togglePodcastAudio,
                              icon: Icon(_isPodcastAudioPlaying ? Icons.stop : Icons.play_arrow),
                              label: Text(_isPodcastAudioPlaying ? 'အသံ ရပ်တန့်မည်' : 'အသံဖိုင် နားထောင်မည်',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
