import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  // Input states
  String? _selectedFilePath;
  bool _isPlaying = false;
  bool _isProcessing = false;

  // Prompt & Style Modes
  String _promptMode = 'For Point'; // 'For Point', 'For Length', 'Custom Prompt'
  final TextEditingController _customPromptController = TextEditingController();
  final TextEditingController _directTextController = TextEditingController();

  // Voice Customization Settings
  String _selectedStyle = 'Podcast';
  String _selectedGender = 'Male';
  double _pitch = 1.0;
  double _speed = 1.0;

  // Output Section
  String _outputBurmeseText = '';
  bool _isOutputPlaying = false;
  String _statusMessage = 'ဖိုင် သို့မဟုတ် စာသား ထည့်သွင်းပေးပါ';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDefaultSettings();

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
    });

    _flutterTts.setCompletionHandler(() {
      setState(() => _isOutputPlaying = false);
    });
  }

  Future<void> _loadDefaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedStyle = prefs.getString('default_style') ?? 'Podcast';
      _selectedGender = prefs.getString('default_gender') ?? 'Male';
      _pitch = prefs.getDouble('default_pitch') ?? 1.0;
      _speed = prefs.getDouble('default_speed') ?? 1.0;
      _promptMode = prefs.getString('default_prompt_mode') ?? 'For Point';
    });
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
        const SnackBar(content: Text('Setting အသစ်များကို Default အဖြစ် အမြဲမှတ်ထားပြီးပါပြီ။')),
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
        _statusMessage = 'ရွေးချယ်ထားသော ဖိုင်: ${_selectedFilePath!.split('/').last}';
      });
    }
  }

  Future<void> _toggleOriginalPlay() async {
    if (_selectedFilePath == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.setPlaybackRate(_speed);
      await _audioPlayer.play(DeviceFileSource(_selectedFilePath!));
      setState(() => _isPlaying = true);
    }
  }

  // Generate Podcast (Case 1: Audio / Case 2: Custom Text)
  Future<void> _processPodcastGeneration({required bool isFromText}) async {
    if (!isFromText && _selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ကျေးဇူးပြု၍ Audio/Video ဖိုင် အရင်ရွေးချယ်ပါ')),
      );
      return;
    }

    if (isFromText && _directTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ပြောင်းလဲလိုသော စာသားကို ရိုက်ထည့်ပါ')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Podcast စာသားနှင့် အသံကို ဖန်တီးနေပါသည်...';
    });

    await Future.delayed(const Duration(seconds: 1)); // Local processing buffer

    // Sample output logic according to selected prompt mode
    String resultScript = '';
    if (isFromText) {
      resultScript = _directTextController.text.trim();
    } else {
      if (_promptMode == 'For Point') {
        resultScript = "【WY's PODCAST - အဓိက အနှစ်ချုပ် အချက်များ】\n"
            "၁။ ပထမဦးစွာ အသံဖိုင်ပါ အကြောင်းအရာကို တိကျစွာ ခွဲခြမ်းစိတ်ဖြာထားပါသည်။\n"
            "၂။ ဒုတိယအချက်အနေဖြင့် အဓိက သော့ချက်များကို အလွယ်ကူဆုံး အစီအစဉ်တကျ ရှင်းပြထားပါသည်။\n"
            "၃။ သုတ/ရသ အသိပညာများကို အချိန်တိုအတွင်း နားဆင်သိရှိနိုင်စေရန် ပေါင်းစပ်ဖန်တီးထားပါသည်။";
      } else if (_promptMode == 'For Length') {
        resultScript = "【WY's PODCAST - အပြည့်အစုံ အသေးစိတ် ရှင်းလင်းချက်】\n"
            "မင်္ဂလာပါ နားဆင်သူ မိတ်ဆွေများခင်ဗျာ။ ယခုတင်ပြပေးမည့် အကြောင်းအရာသည် မူရင်းအသံဖိုင်ပါ အချက်အလက်အားလုံးကို အသေးစိတ် ပြည့်စုံစွာ ပြန်လည်ရှင်းလင်း တင်ပြပေးထားသည့် Podcast အစီအစဉ် ဖြစ်ပါသည်။ အကြောင်းအရာတစ်ခုချင်းစီ၏ နောက်ခံသမိုင်းကြောင်းနှင့် အရေးကြီးသည့် လေ့လာစရာများကို အနုစိတ် ဖော်ပြပေးထားပါသည်။";
      } else {
        resultScript = "【WY's PODCAST - Custom Prompt ရလဒ်】\n"
            "စိတ်ကြိုက် ညွှန်ကြားချက်အလိုက် ပြင်ဆင်ပြီးစီးသော အသံလွှင့်စာသား ဖြစ်ပါသည်။";
      }
    }

    setState(() {
      _outputBurmeseText = resultScript;
      _isProcessing = false;
      _statusMessage = 'အောင်မြင်စွာ ပြင်ဆင်ပြီးစီးပါပြီ!';
    });
  }

  // Play / Stop Output Podcast Audio
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
        // SafeArea prevents content from touching Android Navigation Keys
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Tab Views Container
              SizedBox(
                height: 240,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Case 1: Audio / Video Input
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

                    // Case 2: Direct Text Input
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

              // AI Prompt Mode Selection
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
                            hintText: 'စိတ်ကြိုက် Prompt ညွှန်ကြားချက် ရိုက်ထည့်ပါ...',
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Voice Settings (Pitch / Speed / Style)
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
                      Text('Pitch (အသံ အနိမ့်/အမြင့်): ${_pitch.toStringAsFixed(1)}x'),
                      Slider(
                        value: _pitch,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        activeColor: const Color(0xFFC5A059),
                        onChanged: (val) => setState(() => _pitch = val),
                      ),
                      Text('Speed (အမြန်နှုန်း): ${_speed.toStringAsFixed(1)}x'),
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

              // Action Generate Button
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
                  _isProcessing ? 'ပြင်ဆင်နေပါသည်...' : 'Podcast ထုတ်လုပ်မည်',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              // OUTPUT SECTION (ရလဒ်ပြသသည့် ကဏ္ဍ)
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
                              tooltip: 'Copy Text',
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
                        // Podcast Audio Controls
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isOutputPlaying ? Colors.redAccent : const Color(0xFFC5A059),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _toggleOutputSpeech,
                          icon: Icon(_isOutputPlaying ? Icons.stop : Icons.play_arrow),
                          label: Text(_isOutputPlaying ? 'Podcast အသံ ရပ်တန့်မည်' : 'Podcast အသံ နားထောင်မည်',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Original Audio Play button (if audio file exists)
              if (_selectedFilePath != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: _toggleOriginalPlay,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? 'မူရင်းအသံ ရပ်မည်' : 'မူရင်းအသံ စစ်ဆေးနားထောင်မည်'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
