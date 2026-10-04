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
import 'package:whisper_ggml/whisper_ggml.dart';

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

class _အလွန်ကောင်းပါပြီခင်ဗျာ။ အခုဆိုရင် CI/CD build ပေါ်မှာ model ဖိုင်ကို auto ဆွဲယူထည့်သွင်းမယ့် setup ပြီးသွားပါပြီ။

ယခု နောက်ဆုံးအဆင့်အနေနဲ့ **`lib/main.dart`** ထဲကို အောက်ပါ code အပြည့်အစုံနဲ့ အကုန် replace လုပ်ပေးရပါမယ်။ 

ဒီ code မှာ-
1. **အပိုင်း (၁):** `whisper_ggml` library သုံးပြီး asset ထဲက `ggml-tiny.bin` model ကို load လုပ်ကာ offline transcribe အစစ်အမှန် လုပ်ဆောင်ပေးပါတယ်။
2. **အပိုင်း (၂):** Gemini Speech Engine ဆီ သွားတဲ့အခါ Robot fallback တွေကို လုံးဝမသုံးဘဲ AI Studio voice characters (Puck, Charon, Kore, Aoede, etc.) နဲ့ ရွေးချယ်ထားတဲ့ presentation styles တွေကို အခြေခံပြီး တိုက်ရိုက် output ထုတ်ပေးပါတယ်။

---

### `lib/main.dart` (အကုန်အစားထိုးရန် Code)

```dart
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
import 'package:whisper_ggml/whisper_ggml.dart';

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
  String _selectedVoice = 'Puck';
  String _selectedStyle = 'Podcast Host';
  double _speed = 1.0;

  final Map<String, String> _voiceDescriptions = {
    'Puck': 'Male - ပေါ့ပါးသွက်လက်၊ လူငယ်ဆန်သောအသံ',
    'Charon': 'Male - တည်ငြိမ်ရင့်ကျက်၊ နက်ရှိုင်းသောအသံ',
    'Fenrir': 'Male - အားမာန်ပါပြီး ပြတ်သားသောအသံ',
    'Kore': 'Female - အေးချမ်းကြည်လင်၊ သိမ်မွေ့သောအသံ',
    'Aoede': 'Female - နွေးထွေးဖော်ရွေ၊ အသံချိုချို',
  };

  final List<String> _styles = [
    'Podcast Host',
    'Tutor / Educational',
    'Professional / News',
    'Storyteller / Audio Book',
    'Casual Conversation',
    'Motivational',
  ];

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
      _selectedVoice = prefs.getString('default_voice') ?? 'Puck';
      _selectedStyle = prefs.getString('default_style') ?? 'Podcast Host';
      _speed = prefs.getDouble('default_speed') ?? 1.0;
      _promptMode = prefs.getString('default_prompt_mode') ?? 'For Point';
      _enableAiRewrite = prefs.getBool('default_enable_ai_rewrite') ?? true;
    });
  }

  // --- DIALOGS ---
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Color(0xFFC5A059)),
            SizedBox(width: 8),
            Text('Gemini API ရယူနည်း', style: TextStyle(color: Color(0xFFC5A059), fontSize: 18)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gemini API Key ရယူရန် အဆင့်များ-', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 10),
              Text(
                '⚠️ အရေးကြီးသည်: AI Studio သို့ ဝင်ရောက်စဉ် ဖုန်းတွင် VPN ဖွင့်ထားရန် လိုအပ်ပါသည်။',
                style: TextStyle(fontSize: 12, color: Color(0xFFDFBA73), fontWeight: FontWeight.w600, height: 1.4),
              ),
              SizedBox(height: 10),
              Text('၁။ [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey) သို့ သွားရောက်ပါ။', style: TextStyle(fontSize: 13, height: 1.4)),
              SizedBox(height: 6),
              Text('၂။ "Create API key in new project" ကို နှိပ်ပါ။', style: TextStyle(fontSize: 13, height: 1.4)),
              SizedBox(height: 6),
              Text('၃။ ရရှိလာသော AIzaSy... key ကို Copy ကူးပြီး App ထဲတွင် ထည့်ပါ။', style: TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059)),
            onPressed: () => Navigator.pop(context),
            child: const Text('နားလည်ပါပြီ', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("WY's PODCAST", style: TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.bold)),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ဗားရှင်း: 1.0.0', style: TextStyle(fontSize: 12, color: Colors.white54)),
            SizedBox(height: 12),
            Text('Developer: @seniorwaiyan', style: TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059)),
            onPressed: () => Navigator.pop(context),
            child: const Text('ပိတ်မည်', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettingsDialog() async {
    final geminiController = TextEditingController(text: _geminiApiKey);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Gemini API Key', style: TextStyle(color: Color(0xFFC5A059))),
        content: TextField(
          controller: geminiController,
          decoration: const InputDecoration(
            labelText: 'Gemini API Key',
            hintText: 'AIzaSy... key ထည့်ပါ',
            border: OutlineInputBorder(),
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
              setState(() => _geminiApiKey = geminiController.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('သိမ်းဆည်းမည်', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // --- PART 1: NATIVE OFFLINE WHISPER STT ---
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac'],
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

  Future<String> _getOfflineModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${appDir.path}/ggml-tiny.bin');
    if (!await modelFile.exists()) {
      final byteData = await rootBundle.load('assets/models/ggml-tiny.bin');
      await modelFile.writeAsBytes(byteData.buffer.asUint8List());
    }
    return modelFile.path;
  }

  Future<void> _transcribeAudioOffline() async {
    if (_selectedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('အသံဖိုင် အရင်ရွေးချယ်ပေးပါ')));
      return;
    }

    setState(() => _isTranscribing = true);

    try {
      final modelPath = await _getOfflineModelPath();
      final whisper = Whisper(model: modelPath);
      final res = await whisper.transcribe(
        audio: _selectedAudioPath!,
        language: 'auto',
      );

      setState(() {
        _isTranscribing = false;
        _extractedTextController.text = res.text.trim();
      });
    } catch (e) {
      setState(() => _isTranscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Offline STT အမှား: $e')));
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

  List<String> _splitTextIntoChunks(String text, int maxLength) {
    List<String> chunks = [];
    List<String> sentences = text.split(RegExp(r'(?<=[။\n\.!\?])'));
    String current = "";

    for (var s in sentences) {
      if ((current + s).length <= maxLength) {
        current += s;
      } else {
        if (current.trim().isNotEmpty) chunks.add(current.trim());
        current = s;
      }
    }
    if (current.trim().isNotEmpty) chunks.add(current.trim());
    return chunks.isEmpty ? [text] : chunks;
  }

  Future<String> _callGeminiPodcastScript(String rawContent) async {
    String styleInstruction = "";
    switch (_selectedStyle) {
      case 'Tutor / Educational':
        styleInstruction = "ဆရာတစ်ဦးက တပည့်များအား စိတ်ရှည်စွာ ရှင်းပြသင်ကြားပေးနေသည့် ပုံစံဖြင့်";
        break;
      case 'Professional / News':
        styleInstruction = "သတင်းနှင့် စီးပွားရေး တင်ဆက်မှုများကဲ့သို့ တည်ကြည်လေးနက်သော ပုံစံဖြင့်";
        break;
      case 'Storyteller / Audio Book':
        styleInstruction = "ဇာတ်လမ်းတစ်ပုဒ်ကို ရသမြောက်စွာ ပြောပြနေသည့် Audio Book ပုံစံဖြင့်";
        break;
      case 'Casual Conversation':
        styleInstruction = "သူငယ်ချင်းအချင်းချင်း ပေါ့ပေါ့ပါးပါး ဗဟုသုတ ဝေမျှနေသည့် စကားပြော ပုံစံဖြင့်";
        break;
      case 'Motivational':
        styleInstruction = "နားဆင်သူများအား အားတက်ကြွစေပြီး စိတ်ခွန်အားဖြစ်စေမည့် တင်ဆက်မှု ပုံစံဖြင့်";
        break;
      default:
        styleInstruction = "နားဆင်ရလွယ်ကူပြီး စိတ်ဝင်စားဖွယ်ကောင်းသော သဘာဝ Podcast Host ပုံစံဖြင့်";
    }

    String instruction = "";
    if (_promptMode == 'For Point') {
      instruction = "အောက်ပါစာသားကို $styleInstruction အဓိက အချက်များ (Bullet points) သီးသန့် မြန်မာလို ရေးပေးပါ:";
    } else if (_promptMode == 'For Length') {
      instruction = "အောက်ပါစာသားကို $styleInstruction အသေးစိတ် ပြည့်စုံစွာ၊ သဘာဝကျသော အသုံးအနှုန်းများဖြင့် မြန်မာလို အပြည့်အစုံ ရေးပေးပါ:";
    } else {
      instruction = "${_customPromptController.text.trim()} ($styleInstruction မြန်မာဘာသာဖြင့် ရေးသားပေးပါ):";
    }

    final url = Uri.parse("[https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiApiKey](https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiApiKey)");
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
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? rawContent;
    } else {
      throw Exception("Script Generation Error (${response.statusCode}): ${response.body}");
    }
  }

  Future<Uint8List?> _fetchGeminiStudioVoice(String textChunk) async {
    final url = Uri.parse("[https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiApiKey](https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_geminiApiKey)");
    
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": "Read the following Burmese text aloud with a natural $_selectedStyle tone using the specified voice:\n$textChunk"
              }
            ]
          }
        ],
        "generationConfig": {
          "responseModalities": ["AUDIO"],
          "speechConfig": {
            "voiceConfig": {
              "prebuiltVoiceConfig": {
                "voiceName": _selectedVoice
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
          if (p is Map && p.containsKey('inlineData')) {
            return base64Decode(p['inlineData']['data']);
          }
        }
      }
      throw Exception("Audio inlineData missing in response");
    } else {
      throw Exception("Gemini TTS Error (${response.statusCode}): ${response.body}");
    }
  }

  Uint8List _addWavHeader(Uint8List pcmBytes, int sampleRate) {
    int totalDataLen = pcmBytes.length;
    int totalAudioLen = totalDataLen + 36;
    int byteRate = sampleRate * 1 * 2;

    final header = ByteData(44);
    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, totalAudioLen, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, totalDataLen, Endian.little);

    final wavBytes = BytesBuilder();
    wavBytes.add(header.buffer.asUint8List());
    wavBytes.add(pcmBytes);
    return wavBytes.toBytes();
  }

  Future<void> _processPodcastGeneration() async {
    if (_geminiApiKey.isEmpty) {
      _saveSettingsDialog();
      return;
    }

    final inputText = _inputStudioTextController.text.trim();
    if (inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('စာသား ထည့်သွင်းပေးပါ')));
      return;
    }

    setState(() {
      _isGeneratingPodcast = true;
      _generationStatus = 'ဇာတ်ညွှန်း ရေးသားနေပါသည်...';
    });

    try {
      String finalScript = inputText;
      if (_enableAiRewrite) {
        finalScript = await _callGeminiPodcastScript(inputText);
      }
      setState(() => _outputBurmeseScript = finalScript);

      List<String> chunks = _splitTextIntoChunks(finalScript, 120);
      List<int> combinedPcmBytes = [];

      for (int i = 0; i < chunks.length; i++) {
        setState(() {
          _generationStatus = 'AI Voice (${i + 1}/${chunks.length}) ထုတ်လုပ်နေပါသည်...';
        });

        Uint8List? audioChunk = await _fetchGeminiStudioVoice(chunks[i]);
        if (audioChunk != null && audioChunk.isNotEmpty) {
          combinedPcmBytes.addAll(audioChunk);
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (combinedPcmBytes.isNotEmpty) {
        final wavBytes = _addWavHeader(Uint8List.fromList(combinedPcmBytes), 24000);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/wy_studio_podcast.wav');
        await file.writeAsBytes(wavBytes);

        setState(() {
          _fullAudioPath = file.path;
          _isGeneratingPodcast = false;
          _generationStatus = 'AI Studio အသံ ဖန်တီးပြီးပါပြီ!';
        });
      } else {
        throw Exception("Audio bytes synthesis failed.");
      }
    } catch (e) {
      setState(() {
        _isGeneratingPodcast = false;
        _generationStatus = 'အမှားဖြစ်ပေါ်ပါသည်';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('အမှား: $e'), duration: const Duration(seconds: 5)));
    }
  }

  Future<void> _saveAudioToDevice() async {
    if (_fullAudioPath == null || !File(_fullAudioPath!).existsSync()) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${appDir.path}/WY_Podcast_${DateTime.now().millisecondsSinceEpoch}.wav');
      await File(_fullAudioPath!).copy(targetFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('အသံဖိုင် သိမ်းဆည်းပြီးပါပြီ: ${targetFile.path.split('/').last}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save မအောင်မြင်ပါ: $e')));
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
            icon: const Icon(Icons.help_outline, color: Color(0xFFC5A059)),
            tooltip: 'Gemini API ယူနည်း',
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFFC5A059)),
            tooltip: 'About Us',
            onPressed: _showAboutDialog,
          ),
          IconButton(
            icon: const Icon(Icons.vpn_key, color: Color(0xFFC5A059)),
            tooltip: 'API Key',
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
            // PART 1: OFFLINE WHISPER
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
                            label: const Text('အသံဖိုင် (Audio) ရွေးပါ', style: TextStyle(fontWeight: FontWeight.bold)),
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
                              const Text('ရရှိလာသော စာသား:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
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

            // PART 2: STUDIO
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
                          const Text('Voice Studio Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059), fontSize: 16)),
                          const SizedBox(height: 12),
                          const Text('AI Studio Voice Character:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedVoice,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF2A2A2A),
                                items: _voiceDescriptions.entries.map((entry) {
                                  return DropdownMenuItem(
                                    value: entry.key,
                                    child: Text('${entry.key} (${entry.value})', style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedVoice = val!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Podcast Style / Tone:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedStyle,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF2A2A2A),
                                items: _styles.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(s, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedStyle = val!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Speed: ${_speed.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                  
                  // Script Box
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
                                const Text('SCRIPT ရလဒ်', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
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
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Audio Player Box
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
                                  label: const Text('Save Audio'),
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
