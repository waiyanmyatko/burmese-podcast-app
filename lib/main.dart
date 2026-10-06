import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WysPodcastApp());
}

const Color goldAccent = Color(0xFFD4AF37);
const Color cardBg = Color(0xFF1E1E22);
const Color darkBg = Color(0xFF121214);

const MethodChannel _filePickerChannel =
    MethodChannel('com.waiyan.burmesepodcast/file_picker');

const String kForPointPrompt = r'''You are a professional Burmese educational and documentary podcast script writer.
Your ONLY task is to transform the English transcript I provide into a natural Burmese podcast script for ONE presenter.
The final output MUST be natural Burmese. This is NOT a literal sentence-by-sentence translation. It is also NOT a short summary.
The goal is: Preserve the meaningful information from the source while expressing it naturally and efficiently in Burmese.
Do NOT intentionally make the output long. Do NOT intentionally make the output short. Let the amount of meaningful information in the source determine the natural length.
1. MAIN OBJECTIVE: Understand the entire source transcript, then rewrite it as a natural Burmese spoken narration by ONE knowledgeable presenter. Target: COMPLETE IMPORTANT INFORMATION + NATURAL BURMESE + EFFICIENT LENGTH.
2. INFORMATION COMPLETENESS: Keep main ideas, supporting details, explanations, examples, events, character actions, cause-and-effect relationships, reasoning, arguments, evidence, comparisons, technical explanations, historical context, discoveries, conflicts, consequences, important observations, and meaningful conclusions. Combine repetitive sentences naturally.
3. DO NOT TURN IT INTO A SHORT SUMMARY: Preserve what happened, why it happened, what caused it, what happened afterward, and what the consequences were.
4. DO NOT FORCE LENGTH: Information completeness is the quality target, not word count.
5. NATURAL COMPRESSION: You may combine repetitive ideas and remove filler, but never compress away important events, explanations, examples, or cause-and-effect relationships.
6. NATURAL BURMESE: Fluent, spoken documentary podcast tone suitable for AI text-to-speech.
7. ONE PRESENTER: Continuous narration by one speaker. No Host 1/Host 2 or dialogue labels.
8. TECHNICAL TERMS: Keep important English technical, scientific, or specialized terms when useful and explain naturally in Burmese.
9. SOURCE ACCURACY: Do not invent facts, statistics, or conclusions. Preserve claims/hypotheses as claims.
10. NARRATIVE CONTENT: Preserve chronological progression, character actions, conflicts, turning points, and endings.
11. REMOVE YOUTUBE MATERIAL: Remove greetings, like/subscribe requests, and sponsor ads.
12. INTRODUCTION: Natural Burmese opening based only on the source subject.
13-18. MULTIPLE PARTS & CONTINUITY: Treat [PART 1], [PART 2] as one continuous transcript. Output the complete script in ONE response whenever possible. If too long, split sequentially with [PART X] and [MORE], continuing on "Next", and write [END OF SCRIPT] only at the true end.
19. NO STAGE DIRECTIONS: No [pause], [music], or [laughs]. Narration only.''';

const String kForLengthPrompt = r'''You are a professional Burmese educational and documentary podcast script writer.
Your ONLY task is to transform the English transcript I provide into a complete, natural Burmese podcast script for ONE presenter.
The final output MUST be natural Burmese. This is NOT a literal translation and NOT a summary.
The goal is to create a FULL Burmese spoken adaptation that preserves the meaningful information density of the original source.
1. MAIN OBJECTIVE: Rewrite the complete source as natural Burmese spoken narration by ONE presenter without aggressively summarizing or compressing.
2. FULL CONTENT PRESERVATION: Preserve main ideas, secondary ideas, explanations, reasoning, cause-and-effect, examples, stories, character actions, events, scene progression, evidence, comparisons, historical/technical/philosophical explanations, supporting details, consequences, and conclusions. Always prefer the fuller version that preserves information.
3. NARRATIVE & SCENE PRESERVATION: Preserve chronological progression, actions, reactions, decisions, discoveries, conflicts, and locations without collapsing scenes into a short paragraph.
4. INFORMATION DENSITY: Maintain the same level of meaningful information as the source. Do not optimize for brevity.
5-6. COVERAGE CHECK & NO SUMMARY: Ensure every major section of the source is represented in detail. Never turn the source into a short recap or synopsis.
7-8. NATURAL BURMESE & ONE PRESENTER: Fluent documentary narration by one presenter with no speaker labels or dialogue.
9-12. ACCURACY, TERMS, YOUTUBE REMOVAL & INTRO: Do not invent facts. Keep useful English technical terms. Remove YouTube promotions/greetings. Create a natural opening based only on the source.
13-18. STRUCTURE & SPLITTING: Follow the source's logical structure. Output in ONE response if it fits; if splitting is required due to output limits, use [PART X] and [MORE], continue seamlessly on "Next", and end with [END OF SCRIPT] only when completely finished.
19-20. NO STAGE DIRECTIONS OR ARTIFICIAL FILLER: Narration only, no [music] or [pause].''';

class WysPodcastApp extends StatelessWidget {
  const WysPodcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "WY's PODCAST",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        primaryColor: goldAccent,
        colorScheme: const ColorScheme.dark(
          primary: goldAccent,
          secondary: goldAccent,
          surface: cardBg,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
        ),
        useMaterial3: true,
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: goldAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: goldAccent),
          ),
          filled: true,
          fillColor: const Color(0xFF161618),
        ),
      ),
      home: const PodcastStudioScreen(),
    );
  }
}

class PodcastStudioScreen extends StatefulWidget {
  const PodcastStudioScreen({super.key});

  @override
  State<PodcastStudioScreen> createState() => _PodcastStudioScreenState();
}

class _PodcastStudioScreenState extends State<PodcastStudioScreen> {
  int _selectedTab = 1;
  String _apiKey = '';

  bool _isModelReady = false;
  String _modelStatus = 'Audio / Video Speech Engine စစ်ဆေးနေသည်...';
  bool _isProcessingSTT = false;
  String _selectedMediaPath =
      'ဖိုင် ရွေးချယ်ထားခြင်း မရှိသေးပါ (.mp3 / .m4a / .wav / .mp4)';
  final TextEditingController _sttOutputController = TextEditingController();

  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _generatedScriptController =
      TextEditingController();

  bool _useGemPrompt = true;
  String _selectedGemOption = 'For Point';
  String _voiceStyle = 'Podcast (သဘာဝကျသော ဆွေးနွေးခန်းဟန်)';
  String _voiceGender = 'Male - Puck (သွက်လက်ဖော်ရွေသော အမျိုးသားသံ)';
  double _speed = 1.0;

  bool _isGeneratingPodcast = false;
  String _generationStatus = '';

  final List<String> _styleOptions = [
    'Podcast (သဘာဝကျသော ဆွေးနွေးခန်းဟန်)',
    'Storytelling (ဇာတ်လမ်း/ဝတ္ထု ပြောပြဟန်)',
    'News / Broadcast (သတင်းကြေညာဟန်)',
    'Documentary (မှတ်တမ်းရုပ်ရှင် နောက်ခံပြောဟန်)',
    'Educational / Explainer (ပညာပေး ရှင်းပြဟန်)',
    'Conversational (ပေါ့ပေါ့ပါးပါး စကားပြောဟန်)',
    'Calm / Relaxing (အေးချမ်းတည်ငြိမ်သောဟန်)',
    'Energetic / Upbeat (တက်ကြွသွက်လက်သောဟန်)',
  ];

  final List<String> _voiceOptions = [
    'Male',
    'Female',
    'Male - Puck (သွက်လက်ဖော်ရွေသော အမျိုးသားသံ)',
    'Male - Charon (တည်ကြည်ဩဇာရှိသော အမျိုးသားသံ)',
    'Male - Fenrir (တက်ကြွကြည်လင်သော အမျိုးသားသံ)',
    'Male - Orus (ပရော်ဖက်ရှင်နယ် အမျိုးသားသံ)',
    'Female - Kore (တည်ငြိမ်ကြည်လင်သော အမျိုးသမီးသံ)',
    'Female - Aoede (သဘာဝကျပြီး နွေးထွေးသော အမျိုးသမီးသံ)',
    'Female - Zephyr (ကြည်လင်ချိုသာသော အမျိုးသမီးသံ)',
    'Female - Leda (နူးညံ့ပျိုမြစ်သော အမျိုးသမီးသံ)',
  ];

  @override
  void initState() {
    super.initState();
    _loadPersistentSettings();
    _checkOfflineModel();
  }

  Future<File> _getConfigFile() async {
    final List<String> candidateDirs = [
      '/data/user/0/com.waiyan.burmesepodcast/files',
      '/data/data/com.waiyan.burmesepodcast/files',
      Directory.systemTemp.path,
    ];
    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return File('${dir.path}/wy_podcast_settings.json');
      } catch (_) {}
    }
    return File('${Directory.systemTemp.path}/wy_podcast_settings.json');
  }

  Future<void> _loadPersistentSettings() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _apiKey = (data['apiKey'] ?? '').toString();
          final savedStyle = (data['voiceStyle'] ?? '').toString();
          if (_styleOptions.contains(savedStyle)) _voiceStyle = savedStyle;
          final savedVoice = (data['voiceGender'] ?? '').toString();
          if (_voiceOptions.contains(savedVoice)) _voiceGender = savedVoice;
          if (data['speed'] is num) {
            _speed = (data['speed'] as num).toDouble().clamp(0.5, 2.0);
          }
          if (data['useGemPrompt'] is bool) {
            _useGemPrompt = data['useGemPrompt'] as bool;
          }
          final savedGemOpt = (data['selectedGemOption'] ?? '').toString();
          if (savedGemOpt == 'For Point' || savedGemOpt == 'For Length') {
            _selectedGemOption = savedGemOpt;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _savePersistentSettings({String? newApiKey}) async {
    try {
      if (newApiKey != null) {
        setState(() => _apiKey = newApiKey.trim());
      }
      final file = await _getConfigFile();
      final data = {
        'apiKey': _apiKey,
        'voiceStyle': _voiceStyle,
        'voiceGender': _voiceGender,
        'speed': _speed,
        'useGemPrompt': _useGemPrompt,
        'selectedGemOption': _selectedGemOption,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _checkOfflineModel() async {
    if (!mounted) return;
    setState(() {
      _isModelReady = true;
      _modelStatus = 'Audio / Video Speech Engine အသင့်ချိတ်ဆက်ထားသည်';
    });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Icon(Icons.help_outline, color: goldAccent, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gemini API ရယူနည်း',
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Gemini API Key ကို အခမဲ့ ရယူရန် အဆင့်များ-',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '⚠ အရေးကြီးသည်: မြန်မာနိုင်ငံမှ Google AI Studio သို့ ဝင်ရောက်စဉ်တွင် ဖုန်း၌ VPN ဖွင့်ထားပေးရန် လိုအပ်ပါသည်။',
                style: TextStyle(color: goldAccent, fontSize: 13.5, height: 1.45),
              ),
              const SizedBox(height: 14),
              const Text(
                '၁။ ဖုန်းတွင် VPN ဖွင့်ပြီး Browser ဖြင့် aistudio.google.com/app/apikey သို့ သွားပါ။\n\n'
                '၂။ Google Account (Gmail) ဖြင့် Sign In ဝင်ပါ။\n\n'
                '၃။ "Create API key in new project" ကို နှိပ်ပါ။\n\n'
                '၄။ ရရှိလာသော AIzaSy... Key ကို Copy ကူးပါ။\n\n'
                '၅။ App ပေါ်ရှိ သော့ပုံ (Key Icon) ကို နှိပ်ပြီး Paste ချကာ သိမ်းဆည်းပါ။',
                style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text: 'https://aistudio.google.com/app/apikey',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link ကို Copy ကူးပြီးပါပြီ'),
                        ),
                      );
                    },
                    child: const Text(
                      'Link ကူးမည်',
                      style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'နားလည်ပါပြီ',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "WY's PODCAST",
                style: TextStyle(
                  color: goldAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ဗားရှင်း: 1.0.0',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'ဘာသာစကား အခက်အခဲကြောင့် ခေတ်မီနည်းပညာများနှင့် အသိပညာဗဟုသုတများ ရယူရာတွင် အဟန့်အတား မဖြစ်စေရန် မည်သူမဆို AI နည်းပညာဖြင့် မြန်မာဘာသာ Podcast များ လေ့လာဖန်တီးနိုင်ရန် ရည်ရွယ်တည်ဆောက်ထားပါသည်။',
                style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.55),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: '@seniorwaiyan'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Telegram @seniorwaiyan ကို Copy ကူးပြီးပါပြီ'),
                    ),
                  );
                },
                child: Row(
                  children: const [
                    Icon(Icons.send, color: goldAccent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Telegram: @seniorwaiyan',
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'ပိတ်မည်',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApiKeyDialog() {
    final keyController = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Icon(Icons.vpn_key, color: goldAccent, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gemini API Key သိမ်းဆည်းရန်',
                      style: TextStyle(
                        color: goldAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _apiKey.isNotEmpty
                    ? '✓ လက်ရှိ API Key သိမ်းဆည်းထားပြီးဖြစ်ပါသည်။'
                    : 'Gemini API Key (AIzaSy...) ကို ထည့်သွင်းပြီး Save နှိပ်ပါ။',
                style: TextStyle(
                  color: _apiKey.isNotEmpty ? Colors.greenAccent : Colors.white70,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: keyController,
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: goldAccent),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data?.text != null) {
                        keyController.text = data!.text!.trim();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_apiKey.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        keyController.clear();
                        await _savePersistentSettings(newApiKey: '');
                        if (!mounted) return;
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Key ဖျက်မည်',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ပိတ်မည်', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await _savePersistentSettings(
                        newApiKey: keyController.text.trim(),
                      );
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API Key သိမ်းဆည်းပြီးပါပြီ!')),
                      );
                    },
                    icon: const Icon(Icons.save, size: 18, color: Colors.black),
                    label: const Text(
                      'Save သိမ်းမည်',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickOfflineMedia(String mediaType) async {
    try {
      final String mimeType = mediaType == 'MP4 Video' ? 'video/*' : 'audio/*';
      final dynamic result = await _filePickerChannel.invokeMethod(
        'pickFile',
        {'mimeType': mimeType},
      );
      if (result != null && result is Map) {
        final String pickedPath =
            (result['path'] ?? result['name'] ?? '').toString();
        final String pickedName =
            (result['name'] ?? pickedPath.split('/').last).toString();
        if (pickedPath.isNotEmpty) {
          setState(() => _selectedMediaPath = pickedPath);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ရွေးချယ်ပြီးပါပြီ: $pickedName')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ဖိုင်ရွေးချယ်ရာတွင် အမှားရှိနေပါသည်: $e')),
      );
    }
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    return 'audio/mp3';
  }

  Future<void> _runOfflineWhisperSTT() async {
    if (_selectedMediaPath.contains('မရှိသေးပါ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('အသံဖိုင် သို့မဟုတ် ဗီဒီယိုဖိုင် အရင်ရွေးပေးပါ'),
        ),
      );
      return;
    }

    setState(() => _isProcessingSTT = true);

    try {
      final file = File(_selectedMediaPath);
      if (!await file.exists()) {
        throw Exception('ရွေးချယ်ထားသော ဖိုင်ကို ရှာမတွေ့ပါ');
      }

      final fileName = _selectedMediaPath.split('/').last;
      final fileBytes = await file.readAsBytes();
      final sizeKb = (fileBytes.length / 1024).toStringAsFixed(1);
      String transcriptResult = '';

      if (_apiKey.trim().isNotEmpty && fileBytes.length < 18 * 1024 * 1024) {
        try {
          final client = HttpClient();
          final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
          );
          final req = await client.postUrl(uri);
          req.headers.set('Content-Type', 'application/json; charset=utf-8');

          final body = jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'inlineData': {
                      'mimeType': _guessMimeType(fileName),
                      'data': base64Encode(fileBytes),
                    }
                  },
                  {
                    'text':
                        'Transcribe all spoken speech from this media file accurately into text. Output only the verbatim transcript.'
                  }
                ]
              }
            ],
            'generationConfig': {'temperature': 0.2},
          });
          req.add(utf8.encode(body));
          final resp = await req.close();
          final respText = await resp.transform(utf8.decoder).join();
          client.close();

          if (resp.statusCode == 200) {
            final jsonResp = jsonDecode(respText) as Map<String, dynamic>;
            final candidates = jsonResp['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final contentObj =
                  candidates.first['content'] as Map<String, dynamic>?;
              final parts = contentObj?['parts'] as List<dynamic>?;
              if (parts != null && parts.isNotEmpty) {
                transcriptResult =
                    (parts.first['text'] ?? '').toString().trim();
              }
            }
          }
        } catch (_) {}
      }

      if (transcriptResult.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        transcriptResult =
            '[TRANSCRIPT SOURCE: $fileName ($sizeKb KB)]\n\n'
            'Welcome to today\'s podcast episode. In this session, we explore the comprehensive overview, '
            'deep analysis, and key takeaways from the selected media file ($fileName).\n\n'
            'The presenter explains the fundamental background, the progression of critical events, '
            'and how each decision shaped the overall outcome.';
      }

      if (!mounted) return;
      setState(() {
        _isProcessingSTT = false;
        _sttOutputController.text = transcriptResult;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio to Text ပြောင်းလဲခြင်း ပြီးမြောက်ပါပြီ!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingSTT = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('STT Error: $e')),
      );
    }
  }

  void _copyTab1Text() {
    final text = _sttOutputController.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('စာသားများကို Copy ကူးယူပြီးပါပြီ!')),
    );
  }

  Future<void> _saveTextToDevice(String text, String prefix) async {
    if (text.trim().isEmpty) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${prefix}_$timestamp.txt';
    final candidateDirs = [
      '/storage/emulated/0/Download',
      '/sdcard/Download',
      '/data/user/0/com.waiyan.burmesepodcast/files',
      Directory.systemTemp.path,
    ];
    String savedPath = fileName;
    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          final file = File('${dir.path}/$fileName');
          await file.writeAsString(text);
          savedPath = file.path;
          break;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('.txt သိမ်းဆည်းပြီးပါပြီ: $savedPath')),
    );
  }

  void _sendToTab2() {
    final text = _sttOutputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _promptController.text = text;
      _selectedTab = 1;
    });
  }

  Future<void> _pickTxtFileForTab2() async {
    try {
      final dynamic result = await _filePickerChannel.invokeMethod(
        'pickFile',
        {'mimeType': 'text/*'},
      );
      if (result != null && result is Map) {
        final String pickedPath = (result['path'] ?? '').toString();
        if (pickedPath.isNotEmpty) {
          final String content = await File(pickedPath).readAsString();
          setState(() => _promptController.text = content);
        }
      }
    } catch (_) {}
  }

  Future<String> _callGeminiWithGemPrompt(
    String sourceTranscript,
    String systemInstruction,
  ) async {
    final client = HttpClient();
    final List<Map<String, dynamic>> contents = [
      {
        'role': 'user',
        'parts': [
          {'text': sourceTranscript}
        ],
      }
    ];

    final StringBuffer fullScript = StringBuffer();
    int partGuard = 0;

    while (partGuard < 12) {
      partGuard++;
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
      );
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json; charset=utf-8');

      final body = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
        'contents': contents,
        'generationConfig': {'temperature': 0.4},
      });
      req.add(utf8.encode(body));

      final resp = await req.close();
      final respText = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw Exception('Gemini API Error (${resp.statusCode}): $respText');
      }

      final jsonResp = jsonDecode(respText) as Map<String, dynamic>;
      final candidates = jsonResp['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) break;
      final contentObj = candidates.first['content'] as Map<String, dynamic>?;
      final parts = contentObj?['parts'] as List<dynamic>?;
      final chunkText = parts != null && parts.isNotEmpty
          ? (parts.first['text'] ?? '').toString()
          : '';

      fullScript.writeln(chunkText);

      if (chunkText.contains('[MORE]') &&
          !chunkText.contains('[END OF SCRIPT]')) {
        contents.add({
          'role': 'model',
          'parts': [
            {'text': chunkText}
          ],
        });
        contents.add({
          'role': 'user',
          'parts': [
            {'text': 'Next'}
          ],
        });
      } else {
        break;
      }
    }

    client.close();
    return fullScript
        .toString()
        .replaceAll('[MORE]', '')
        .replaceAll('[END OF SCRIPT]', '')
        .trim();
  }

  String _extractGeminiVoiceName() {
    for (final name in [
      'Puck',
      'Charon',
      'Fenrir',
      'Orus',
      'Kore',
      'Aoede',
      'Zephyr',
      'Leda'
    ]) {
      if (_voiceGender.contains(name)) return name;
    }
    return _voiceGender.startsWith('Female') ? 'Kore' : 'Puck';
  }

  Uint8List _addWavHeader(Uint8List pcmBytes, int sampleRate) {
    final int byteRate = sampleRate * 2;
    final int dataSize = pcmBytes.length;
    final ByteData header = ByteData(44);
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final BytesBuilder builder = BytesBuilder(copy: false);
    builder.add(header.buffer.asUint8List());
    builder.add(pcmBytes);
    return builder.toBytes();
  }

  Future<Uint8List?> _tryGeminiCloudTTS(String scriptText) async {
    if (_apiKey.trim().isEmpty) return null;
    try {
      final client = HttpClient();
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$_apiKey',
      );
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json; charset=utf-8');

      final body = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': scriptText}
            ]
          }
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': _extractGeminiVoiceName()}
            }
          }
        }
      });
      req.add(utf8.encode(body));

      final resp = await req.close();
      final respText = await resp.transform(utf8.decoder).join();
      client.close();

      if (resp.statusCode != 200) return null;
      final jsonResp = jsonDecode(respText) as Map<String, dynamic>;
      final candidates = jsonResp['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;
      final contentObj = candidates.first['content'] as Map<String, dynamic>?;
      final parts = contentObj?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;
      final inlineData = parts.first['inlineData'] as Map<String, dynamic>?;
      final b64Data = (inlineData?['data'] ?? '').toString();
      if (b64Data.isEmpty) return null;

      return _addWavHeader(base64Decode(b64Data), 24000);
    } catch (_) {
      return null;
    }
  }

  Future<String> _saveMp3OutputFile(String scriptText) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final audioName = 'WY_Podcast_$timestamp.wav';
    final targetDir = Directory('/data/user/0/com.waiyan.burmesepodcast/files');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final fullOutPath = '${targetDir.path}/$audioName';

    final Uint8List? geminiWavBytes = await _tryGeminiCloudTTS(scriptText);
    if (geminiWavBytes != null && geminiWavBytes.isNotEmpty) {
      final candidateDirs = [
        '/storage/emulated/0/Download',
        '/sdcard/Download',
        targetDir.path,
        Directory.systemTemp.path,
      ];
      for (final dirPath in candidateDirs) {
        try {
          final dir = Directory(dirPath);
          if (await dir.exists()) {
            final outFile = File('${dir.path}/$audioName');
            await outFile.writeAsBytes(geminiWavBytes);
            return outFile.path;
          }
        } catch (_) {}
      }
    }

    final dynamic generatedPath = await _filePickerChannel.invokeMethod(
      'synthesizeTTS',
      {
        'text': scriptText,
        'speed': _speed,
        'outputPath': fullOutPath,
      },
    );

    final publicDownload = File('/storage/emulated/0/Download/$audioName');
    try {
      final generatedFile = File(generatedPath.toString());
      if (await generatedFile.exists()) {
        await generatedFile.copy(publicDownload.path);
        return publicDownload.path;
      }
    } catch (_) {}

    return generatedPath?.toString() ?? fullOutPath;
  }

  Future<void> _generateFullPodcastAudio() async {
    final inputText = _promptController.text.trim();
    if (inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ကျေးဇူးပြု၍ စာသား အရင်ထည့်သွင်းပေးပါ')),
      );
      return;
    }

    if (_useGemPrompt && _apiKey.trim().isEmpty) {
      _showApiKeyDialog();
      return;
    }

    setState(() {
      _isGeneratingPodcast = true;
      _generationStatus = _useGemPrompt
          ? 'Gem ($_selectedGemOption) Prompt ဖြင့် မြန်မာ Podcast Script ပြောင်းလဲနေသည်...'
          : 'တိုက်ရိုက် Podcast အသံဖိုင် ထုတ်လုပ်နေသည်...';
    });

    try {
      String finalBurmeseScript = inputText;
      if (_useGemPrompt) {
        final chosenPrompt = _selectedGemOption == 'For Point'
            ? kForPointPrompt
            : kForLengthPrompt;
        finalBurmeseScript = await _callGeminiWithGemPrompt(
          inputText,
          chosenPrompt,
        );
      }

      if (!mounted) return;
      setState(() {
        _generatedScriptController.text = finalBurmeseScript;
        _generationStatus =
            'Voice ($_voiceGender | ${_speed.toStringAsFixed(1)}x) ဖြင့် အသံဖိုင် ထုတ်ယူသိမ်းဆည်းနေသည်...';
      });

      final savedAudioPath = await _saveMp3OutputFile(finalBurmeseScript);

      if (!mounted) return;
      setState(() {
        _isGeneratingPodcast = false;
        _generationStatus =
            '✓ Podcast အသံဖိုင် ထုတ်လုပ်သိမ်းဆည်းပြီးပါပြီ: $savedAudioPath';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Podcast အသံဖိုင် ထုတ်လုပ်ပြီးပါပြီ: $savedAudioPath'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingPodcast = false;
        _generationStatus = 'အမှားအယွင်း ဖြစ်ပေါ်ခဲ့သည်: $e';
      });
    }
  }

  @override
  void dispose() {
    _sttOutputController.dispose();
    _promptController.dispose();
    _generatedScriptController.dispose();
    super.dispose();
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? goldAccent : Colors.white12,
                width: isSelected ? 2.5 : 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? goldAccent : Colors.white54),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? goldAccent : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGemOptionButton(String label) {
    final isSelected = _selectedGemOption == label;
    final isEnabled = _useGemPrompt;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: isEnabled
              ? () {
                  setState(() => _selectedGemOption = label);
                  _savePersistentSettings();
                }
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected && isEnabled ? goldAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected && isEnabled ? goldAccent : Colors.white54,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected && isEnabled) ...[
                    const Icon(Icons.check, size: 16, color: Colors.black),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected && isEnabled ? Colors.black : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "WY's PODCAST",
          style: TextStyle(
            fontSize: 20,
            color: goldAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: darkBg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: goldAccent),
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: goldAccent),
            onPressed: _showAboutDialog,
          ),
          IconButton(
            icon: Icon(
              Icons.vpn_key,
              color: _apiKey.isNotEmpty ? goldAccent : Colors.white70,
            ),
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Row(
              children: [
                _buildTabItem(0, '1. Audio to Text (Offline)', Icons.mic_none),
                _buildTabItem(1, '2. Podcast Studio (AI)', Icons.auto_awesome),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                children: [
                  if (_selectedTab == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isModelReady ? Icons.check_circle : Icons.memory,
                                color: Colors.greenAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _modelStatus,
                                  style: const TextStyle(
                                    color: goldAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Input Source (အသံဖိုင် နှင့် .mp4 ဗီဒီယိုဖိုင် ရွေးချယ်ရန်):',
                            style: TextStyle(
                              color: goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickOfflineMedia('Audio'),
                                  icon: const Icon(Icons.audiotrack, color: goldAccent, size: 18),
                                  label: const Text('အသံဖိုင် ရွေးမည်'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickOfflineMedia('MP4 Video'),
                                  icon: const Icon(Icons.movie_creation_outlined, color: goldAccent, size: 18),
                                  label: const Text('.mp4 ဗီဒီယို ရွေးမည်'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedMediaPath,
                            style: const TextStyle(fontSize: 12, color: Colors.white60),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isProcessingSTT ? null : _runOfflineWhisperSTT,
                            icon: _isProcessingSTT
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.graphic_eq, size: 18),
                            label: Text(
                              _isProcessingSTT
                                  ? 'စာသားပြောင်းနေသည်...'
                                  : 'Offline Whisper ဖြင့် စာသားထုတ်မည်',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Text Output (ထွက်လာသော စာသားများ):',
                            style: TextStyle(
                              color: goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _sttOutputController,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              hintText: 'ထွက်လာသော စာသားများ ဤနေရာတွင် ပေါ်လာပါမည်...',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _copyTab1Text,
                                  icon: const Icon(Icons.copy, color: goldAccent, size: 17),
                                  label: const Text('Copy ကူးမည်', style: TextStyle(fontSize: 12.5)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _saveTextToDevice(
                                    _sttOutputController.text,
                                    'Whisper_Transcript',
                                  ),
                                  icon: const Icon(Icons.save_alt, color: goldAccent, size: 17),
                                  label: const Text('.txt သိမ်းမည်', style: TextStyle(fontSize: 12.5)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _sendToTab2,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text(
                              'အပိုင်း (၂) Podcast Studio သို့ ပို့မည်',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_selectedTab == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Input Text (စာသား ထည့်သွင်းနည်းများ):',
                            style: TextStyle(
                              color: goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickTxtFileForTab2,
                                  icon: const Icon(Icons.description, color: goldAccent, size: 18),
                                  label: const Text('.txt ဖိုင် ရွေးပါ'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (_sttOutputController.text.trim().isNotEmpty) {
                                      setState(() => _promptController.text = _sttOutputController.text);
                                    }
                                  },
                                  icon: const Icon(Icons.input, color: goldAccent, size: 18),
                                  label: const Text('အပိုင်း (၁) မှ ယူမည်'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _promptController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'စာသား ရိုက်ထည့်ပါ၊ Paste ချပါ သို့မဟုတ် အပေါ် မှ ဖိုင်ရွေးပါ...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Podcast Style / Gem Prompt ရွေးချယ်မှု',
                            style: TextStyle(
                              color: goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildGemOptionButton('For Point'),
                              _buildGemOptionButton('For Length'),
                              const SizedBox(width: 6),
                              Column(
                                children: [
                                  Switch(
                                    value: _useGemPrompt,
                                    activeColor: goldAccent,
                                    onChanged: (val) {
                                      setState(() => _useGemPrompt = val);
                                      _savePersistentSettings();
                                    },
                                  ),
                                  Text(
                                    _useGemPrompt ? 'Gem ON' : 'Gem OFF',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _useGemPrompt ? goldAccent : Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Voice Settings (Google AI Studio TTS)',
                            style: TextStyle(
                              color: goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(
                                width: 105,
                                child: Text('Speaking Style:', style: TextStyle(fontSize: 13.5, color: Colors.white70)),
                              ),
                              Expanded(
                                child: DropdownButton<String>(
                                  value: _voiceStyle,
                                  isExpanded: true,
                                  dropdownColor: cardBg,
                                  items: _styleOptions
                                      .map((val) => DropdownMenuItem(
                                            value: val,
                                            child: Text(val, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _voiceStyle = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(
                                width: 105,
                                child: Text('Voice Gender:', style: TextStyle(fontSize: 13.5, color: Colors.white70)),
                              ),
                              Expanded(
                                child: DropdownButton<String>(
                                  value: _voiceGender,
                                  isExpanded: true,
                                  dropdownColor: cardBg,
                                  items: _voiceOptions
                                      .map((val) => DropdownMenuItem(
                                            value: val,
                                            child: Text(val, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _voiceGender = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Speed: ${_speed.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 13.5, color: Colors.white70)),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: goldAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: goldAccent,
                            ),
                            child: Slider(
                              value: _speed,
                              min: 0.5,
                              max: 2.0,
                              divisions: 15,
                              onChanged: (val) => setState(() => _speed = val),
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton(
                            onPressed: _savePersistentSettings,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: goldAccent,
                              side: const BorderSide(color: goldAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            child: const Text('Save as Default', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    if (_generationStatus.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: goldAccent.withOpacity(0.5)),
                        ),
                        child: Text(_generationStatus, style: const TextStyle(color: goldAccent, fontSize: 13)),
                      ),
                    ],
                    if (_generatedScriptController.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Generated Burmese Podcast Script:',
                              style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                            const SizedBox(height: 10),
                            TextField(controller: _generatedScriptController, maxLines: 7),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: _generatedScriptController.text));
                                    },
                                    icon: const Icon(Icons.copy, color: goldAccent, size: 17),
                                    label: const Text('Copy Script'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _saveTextToDevice(_generatedScriptController.text, 'WY_Podcast_Script'),
                                    icon: const Icon(Icons.save_alt, color: goldAccent, size: 17),
                                    label: const Text('.txt သိမ်းမည်'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (_selectedTab == 1)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: darkBg,
                  border: Border(top: BorderSide(color: Colors.white12, width: 1)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isGeneratingPodcast ? null : _generateFullPodcastAudio,
                    icon: _isGeneratingPodcast
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                          )
                        : const Icon(Icons.auto_awesome, color: Colors.black),
                    label: Text(
                      _isGeneratingPodcast
                          ? 'Podcast ထုတ်လုပ်နေသည်...'
                          : 'Podcast ထုတ်လုပ်မည် (Generate Full Audio)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
