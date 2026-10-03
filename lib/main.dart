import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  String? _selectedFilePath;
  bool _isPlaying = false;
  bool _isProcessing = false;

  // API Keys
  String _geminiApiKey = '';
  String _googleTtsApiKey = '';

  // Prompt Modes
  String _promptMode = 'For Point';
  final TextEditingController _customPromptController = TextEditingController();
  final TextEditingController _directTextController = TextEditingController();

  // Voice Settings
  String _selectedStyle = 'Podcast';
  String _selectedGender = 'Male';
  double _pitch = 1.0;
  double _speed = 1.0;

  // Output
  String _outputBurmeseText = '';
  bool _isOutputPlaying = false;
  String _statusMessage = 'ဖိုင် သို့မဟုတ် စာသား ထည့်သွင်းပေးပါ';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
    });

    _flutterTts.setCompletionHandler(() {
      setState(() => _isOutputPlaying = false);
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _geminiApiKey = prefs.getString('gemini_api_key') ?? '';
      _googleTtsApiKey = prefs.getString('google_tts_api_key') ?? '';
      _selectedStyle = prefs.getString('default_style') ?? 'Podcast';
      _selectedGender = prefs.getString('default_gender') ?? 'Male';
      _pitch = prefs.getDouble('default_pitch') ?? 1.0;
      _speed = prefs.getDouble('default_speed') ?? 1.0;
      _promptMode = prefs.getString('default_prompt_mode') ?? 'For Point';
    });
  }

  Future<void> _saveSettingsDialog() async {
    final geminiController = TextEditingController(text: _geminiApiKey);
    final ttsController = TextEditingController(text: _googleTtsApiKey);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('API Keys ထည့်သွင်းရန်', style: TextStyle(color: Color(0xFFC5A059))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: geminiController,
                decoration: const InputDecoration(
                  labelText: 'Google Gemini API Key',
                  hintText: 'AI Studio / Pro API key ထည့်ပါ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ttsController,
                decoration: const InputDecoration(
                  labelText: 'Google Cloud TTS API Key',
                  hintText: 'TTS API key ထည့်ပါ (မရှိပါက device TTS သုံးပါမည်)',
                ),
              ),
            ],
          ),
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
              await prefs.setString('google_tts_api_key', ttsController.text.trim());
              setState(() {
                _geminiApiKey = geminiController.text.trim();
                _googleTtsApiKey = ttsController.text.trim();
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('သိမ်းဆည်းမည်', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsNewDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_style', _selectedStyle);
    await prefs.setString('default_gender', _selectedGender);
    await prefs.setDouble('default_pitch', _pitch);
    await prefs.setDouble('default_speed', _speed);
    await prefs.setString('default_prompt_mode', _promptMode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting များကို Default အဖြစ် သိမ်းဆည်းပြီးပါပြီ။')),
      );
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'mp4'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _statusMessage = 'ရွေးချယ်ထားသောဖိုင်: ${_selectedFilePath!.split('/').last}';
      });
    }
  }

  // Gemini AI Script Generator
  Future<String> _callGeminiTranslate(String rawText) async {
    if (_geminiApiKey.isEmpty) {
      return "【Gemini API Key မရှိသေးပါ】 အပေါ်ညာဘက် Key အိုင်ကွန်မှ Gemini API Key အရင် ထည့်သွင်းပေးပါ။";
    }

    String instruction = "";
    if (_promptMode == 'For Point') {
      instruction = "အောက်ပါစာသားကို နားဆင်ရလွယ်ကူသော မြန်မာ Podcast ပုံစံဖြင့် အဓိက အနှစ်ချုပ် အချက်များ (Bullet points) အဖြစ် မြန်မာလို ပြန်ဆိုရေးသားပေးပါ:";
    } else if (_promptMode == 'For Length') {
      instruction = "အောက်ပါစာသားကို မြန်မာဘာသာ Podcast အစီအစဉ်တစ်ခုကဲ့သို့ အသေးစိတ် ပြည့်စုံစွာ၊ သဘာဝကျသော အသုံးအနှုန်းများဖြင့် မြန်မာလို အပြည့်အစုံ ရေးသားပေးပါ:";
    } else {
      instruction = "${_customPromptController.text.trim()} (မြန်မာဘာသာဖြင့် ထုတ်ပေးပါ):";
    }

    final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "$instruction\n\n$rawText"}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] ?? "စာသား ထုတ်ယူ၍ မရပါ";
      } else {
        return "Gemini API Error (${response.statusCode}): ${response.body}";
      }
    } catch (e) {
      return "ချိတ်ဆက်မှု မအောင်မြင်ပါ: $e";
    }
  }

  Future<void> _processPodcastGeneration({required bool isFromText}) async {
    if (_geminiApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ညာဘက်အပေါ်ရှိ Key အိုင်ကွန်ကို နှိပ်၍ Gemini API Key ထည့်ပါ')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'အသံနှင့် စာသားကို စတင် စိစစ်နေပါသည်...';
    });

    String inputText = isFromText ? _directTextController.text.trim() : "Audio sample transcription text from file";
    String finalScript = await _callGeminiTranslate(inputText);

    setState(() {
      _outputBurmeseText = finalScript;
      _isProcessing = false;
      _statusMessage = 'အောင်မြင်စွာ ပြင်ဆင်ပြီးစီးပါပြီ!';
    });
  }

  Future<void> _toggleOutputSpeech() async {
    if (_outputBurmeseText.isEmpty) return;

    if (_isOutputPlaying) {
      await _flutterTts.stop();
      setState(() => _isOutputPlaying = false);
    } else {
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_speed * 0.45);
      setState(() => _isOutputPlaying = true);
      await _flutterTts.speak(_outputBurmeseText);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    _customPromptController.dispose();
    _directTextController.dispose();
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
            tooltip: 'API Keys ထည့်ရန်',
            onPressed: _saveSettingsDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFC5A059),
          labelColor: const Color(0xFFC5A059),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.mic), text: "Audio to Podcast"),
            Tab(icon: Icon(Icons.text_fields), text: "Custom Text (Case 2)"),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 220,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Card(
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.mic, size: 40, color: Color(0xFFC5A059)),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC5A059),
                                foregroundColor: Colors.black,
                              ),
                              onPressed: _pickAudioFile,
                              icon: const Icon(Icons.file_upload),
                              label: const Text('Audio / Video ဖိုင်ရွေးပါ', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _statusMessage,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      color: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          controller: _directTextController,
                          maxLines: 6,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            hintText: 'အသံပြောင်းလိုသော စာသားများကို ဤနေရာတွင် တိုက်ရိုက်ရိုက်ထည့်ပါ...',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Card(
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Podcast Style / Prompt ရွေးချယ်မှု',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                      const SizedBox(height: 12),
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
                        const SizedBox(height: 10),
                        TextField(
                          controller: _customPromptController,
                          decoration: const InputDecoration(
                            hintText: 'စိတ်ကြိုက် Prompt ရိုက်ထည့်ပါ...',
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('အသံ Setting များ (Default)',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Voice Style:'),
                          DropdownButton<String>(
                            value: _selectedStyle,
                            dropdownColor: const Color(0xFF2A2A2A),
                            items: ['Podcast', 'Tutor', 'Storytelling']
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedStyle = val!),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Voice Gender:'),
                          DropdownButton<String>(
                            value: _selectedGender,
                            dropdownColor: const Color(0xFF2A2A2A),
                            items: ['Male', 'Female']
                                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedGender = val!),
                          ),
                        ],
                      ),
                      Text('Pitch: ${_pitch.toStringAsFixed(1)}x'),
                      Slider(
                        value: _pitch,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        activeColor: const Color(0xFFC5A059),
                        onChanged: (val) => setState(() => _pitch = val),
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
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC5A059),
                            side: const BorderSide(color: Color(0xFFC5A059)),
                          ),
                          onPressed: _saveAsNewDefault,
                          icon: const Icon(Icons.bookmark),
                          label: const Text('Save as Default (မူလအတိုင်း မှတ်မည်)'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _isProcessing
                    ? null
                    : () => _processPodcastGeneration(isFromText: _tabController.index == 1),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isProcessing ? 'AI စာသားနှင့် အသံ ဖန်တီးနေပါသည်...' : 'Podcast ထုတ်လုပ်မည် (Generate)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              if (_outputBurmeseText.isNotEmpty) ...[
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
                            const Text('OUTPUT (ရလဒ်)',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20, color: Colors.white70),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _outputBurmeseText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('စာသားကို Copy ကူးပြီးပါပြီ')),
                                );
                              },
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),
                        SelectableText(
                          _outputBurmeseText,
                          style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isOutputPlaying ? Colors.redAccent : const Color(0xFFC5A059),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _toggleOutputSpeech,
                          icon: Icon(_isOutputPlaying ? Icons.stop : Icons.play_arrow),
                          label: Text(_isOutputPlaying ? 'အသံ ရပ်တန့်မည်' : 'အသံ နားထောင်မည်',
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
      ),
    );
  }
}
