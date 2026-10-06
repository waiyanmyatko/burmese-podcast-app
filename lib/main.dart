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
const MethodChannel _channel = MethodChannel('com.waiyan.burmesepodcast/file_picker');

const String kForPointPrompt = '''You are a professional Burmese educational and documentary podcast script writer.
Transform the transcript into a natural Burmese podcast script for ONE presenter.
Target: COMPLETE IMPORTANT INFORMATION + NATURAL BURMESE + EFFICIENT LENGTH.
1. Understand the source and rewrite as continuous Burmese narration by one presenter.
2. Keep main ideas, supporting details, explanations, examples, events, cause-and-effect, reasoning, evidence, and conclusions.
3. Do NOT turn it into a short summary. Combine repetitive sentences naturally.
4. Keep useful English technical terms and explain naturally in Burmese. Remove YouTube promotions/greetings.
5. Output in ONE response if possible. If splitting is needed, use [PART X] and [MORE], continue on "Next", and end with [END OF SCRIPT]. Narration only, no stage directions.''';

const String kForLengthPrompt = '''You are a professional Burmese educational and documentary podcast script writer.
Transform the transcript into a FULL, natural Burmese podcast script for ONE presenter preserving the full information density of the source.
1. Do NOT summarize or compress away details. Always prefer the fuller version that preserves all explanations, scenes, events, cause-and-effect, examples, and conclusions.
2. Maintain chronological progression and logical structure in fluent, spoken Burmese suitable for TTS.
3. One presenter only, no speaker labels or stage directions. Remove YouTube promotions.
4. Output in ONE response if it fits; otherwise split sequentially with [PART X] and [MORE], continue on "Next", and end with [END OF SCRIPT].''';

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
            side: const BorderSide(color: Colors.white38),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: goldAccent,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
  String _modelFilePath = '';
  String _modelStatus = 'Offline Whisper Model ပြင်ဆင်နေသည်...';
  bool _isProcessingSTT = false;
  String _selectedMediaPath = 'ဖိုင် ရွေးချယ်ထားခြင်း မရှိသေးပါ (.mp3 / .m4a / .wav / .mp4)';
  final TextEditingController _sttOutputController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _generatedScriptController = TextEditingController();

  bool _useGemPrompt = false;
  String _selectedGemOption = 'For Point';
  String _voiceStyle = 'Podcast (သဘာဝကျသော ဆွေးနွေးခန်းဟန်)';
  String _voiceGender = 'Male - Puck (သွက်လက်ဖော်ရွေသော အမျိုးသားသံ)';
  double _speed = 1.0;
  bool _isGeneratingPodcast = false;
  String _generationStatus = '';
  String _lastLocalAudioPath = '';
  String _lastPublicAudioPath = '';
  bool _isPlayingAudio = false;

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
    _loadSettings();
    _prepareOfflineModel();
  }

  Future<Directory> _getAppDir() async {
    for (final p in ['/data/user/0/com.waiyan.burmesepodcast/files', Directory.systemTemp.path]) {
      try {
        final d = Directory(p);
        if (!await d.exists()) await d.create(recursive: true);
        return d;
      } catch (_) {}
    }
    return Directory.systemTemp;
  }

  Future<void> _prepareOfflineModel() async {
    try {
      final dir = await _getAppDir();
      final modelFile = File('${dir.path}/ggml-tiny.bin');
      if (!await modelFile.exists() || await modelFile.length() < 1000000) {
        final data = await rootBundle.load('assets/models/ggml-tiny.bin');
        await modelFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      final mb = (await modelFile.length() / (1024 * 1024)).toStringAsFixed(1);
      if (!mounted) return;
      setState(() {
        _modelFilePath = modelFile.path;
        _modelStatus = 'Fully Offline Whisper Model အသင့်ရှိသည် ($mb MB)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _modelStatus = 'Offline Model Error: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final dir = await _getAppDir();
      final f = File('${dir.path}/wy_podcast_settings.json');
      if (await f.exists()) {
        final d = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _apiKey = (d['apiKey'] ?? '').toString();
          if (_styleOptions.contains(d['voiceStyle'])) _voiceStyle = d['voiceStyle'];
          if (_voiceOptions.contains(d['voiceGender'])) _voiceGender = d['voiceGender'];
          if (d['speed'] is num) _speed = (d['speed'] as num).toDouble().clamp(0.5, 2.0);
          if (d['useGemPrompt'] is bool) _useGemPrompt = d['useGemPrompt'];
          if (d['selectedGemOption'] == 'For Point' || d['selectedGemOption'] == 'For Length') {
            _selectedGemOption = d['selectedGemOption'];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSettings({String? newKey}) async {
    try {
      if (newKey != null) setState(() => _apiKey = newKey.trim());
      final dir = await _getAppDir();
      final f = File('${dir.path}/wy_podcast_settings.json');
      await f.writeAsString(jsonEncode({
        'apiKey': _apiKey,
        'voiceStyle': _voiceStyle,
        'voiceGender': _voiceGender,
        'speed': _speed,
        'useGemPrompt': _useGemPrompt,
        'selectedGemOption': _selectedGemOption,
      }));
    } catch (_) {}
  }

  void _msg(String txt) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Gemini API ရယူနည်း', style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            '⚠ မြန်မာနိုင်ငံမှ ဝင်ရောက်စဉ် VPN ဖွင့်ထားရန် လိုအပ်ပါသည်။\n\n'
            '၁။ aistudio.google.com/app/apikey သို့ သွားပါ။\n'
            '၂။ Google Account ဖြင့် Sign In ဝင်ပါ။\n'
            '၃။ "Create API key" ကို နှိပ်ပြီး ရလာသော Key ကို Copy ကူးပါ။\n'
            '၄။ App ပေါ်ရှိ သော့ပုံ (Key Icon) တွင် Paste ချပြီး Save နှိပ်ပါ။',
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'https://aistudio.google.com/app/apikey'));
              _msg('Link Copy ကူးပြီးပါပြီ');
            },
            child: const Text('Link ကူးမည်', style: TextStyle(color: goldAccent)),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('နားလည်ပါပြီ')),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("WY's PODCAST (v1.0.0)", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
        content: const Text(
          'ဘာသာစကား အခက်အခဲမရှိဘဲ နိုင်ငံတကာမှ အသိပညာများကို AI နည်းပညာဖြင့် မြန်မာဘာသာ Podcast အဖြစ် လွယ်ကူစွာ ဖန်တီးနိုင်ရန် ရည်ရွယ်တည်ဆောက်ထားပါသည်။\n\nTelegram: @seniorwaiyan',
          style: TextStyle(color: Colors.white, height: 1.5),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('ပိတ်မည်'))],
      ),
    );
  }

  void _showApiKeyDialog() {
    final ctrl = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Gemini API Key သိမ်းဆည်းရန်', style: TextStyle(color: goldAccent, fontSize: 18)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'AIzaSy...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste, color: goldAccent),
              onPressed: () async {
                final d = await Clipboard.getData('text/plain');
                if (d?.text != null) ctrl.text = d!.text!.trim();
              },
            ),
          ),
        ),
        actions: [
          if (_apiKey.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _saveSettings(newKey: '');
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('ဖျက်မည်', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ပိတ်မည်')),
          FilledButton(
            onPressed: () async {
              await _saveSettings(newKey: ctrl.text);
              if (mounted) Navigator.pop(ctx);
              _msg('API Key သိမ်းဆည်းပြီးပါပြီ!');
            },
            child: const Text('Save သိမ်းမည်'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia(String type) async {
    try {
      final res = await _channel.invokeMethod('pickFile', {'mimeType': type == 'MP4' ? 'video/*' : 'audio/*'});
      if (res is Map && res['path'] != null) {
        setState(() => _selectedMediaPath = res['path'].toString());
        _msg('ရွေးချယ်ပြီးပါပြီ: ${res['name']}');
      }
    } catch (e) {
      _msg('ဖိုင်ရွေးရာတွင် အမှားရှိနေပါသည်: $e');
    }
  }

  Future<void> _runSTT() async {
    if (_selectedMediaPath.contains('မရှိသေးပါ')) {
      _msg('အသံဖိုင် သို့မဟုတ် ဗီဒီယိုဖိုင် အရင်ရွေးပေးပါ');
      return;
    }
    if (_modelFilePath.isEmpty) {
      await _prepareOfflineModel();
    }
    setState(() => _isProcessingSTT = true);
    try {
      final res = await _channel.invokeMethod('transcribeOffline', {
        'path': _selectedMediaPath,
        'modelPath': _modelFilePath,
      });
      if (!mounted) return;
      setState(() {
        _isProcessingSTT = false;
        _sttOutputController.text = (res ?? '').toString().trim();
      });
      _msg('Offline Whisper စာသားပြောင်းလဲခြင်း ပြီးမြောက်ပါပြီ!');
    } catch (e) {
      if (mounted) setState(() => _isProcessingSTT = false);
      _msg('STT Error: $e');
    }
  }

  Future<void> _saveTxt(String txt, String prefix) async {
    if (txt.trim().isEmpty) return;
    final fn = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.txt';
    for (final p in ['/storage/emulated/0/Download', (await _getAppDir()).path]) {
      try {
        final d = Directory(p);
        if (await d.exists()) {
          final f = File('${d.path}/$fn');
          await f.writeAsString(txt);
          _msg('သိမ်းဆည်းပြီးပါပြီ: ${f.path}');
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _pickTxtForTab2() async {
    try {
      final res = await _channel.invokeMethod('pickFile', {'mimeType': 'text/*'});
      if (res is Map && res['path'] != null) {
        final txt = await File(res['path'].toString()).readAsString();
        setState(() => _promptController.text = txt);
      }
    } catch (_) {}
  }

  Future<String> _runGeminiScript(String src, String sys) async {
    final c = HttpClient();
    final List<Map<String, dynamic>> contents = [
      {'role': 'user', 'parts': [{'text': src}]}
    ];
    final sb = StringBuffer();
    for (int i = 0; i < 10; i++) {
      final req = await c.postUrl(Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
      ));
      req.headers.set('Content-Type', 'application/json; charset=utf-8');
      req.add(utf8.encode(jsonEncode({
        'systemInstruction': {'parts': [{'text': sys}]},
        'contents': contents,
        'generationConfig': {'temperature': 0.4},
      })));
      final resp = await req.close();
      final rTxt = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) throw Exception('API Error: $rTxt');
      final j = jsonDecode(rTxt);
      final chunk = (j['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '').toString();
      sb.writeln(chunk);
      if (chunk.contains('[MORE]') && !chunk.contains('[END OF SCRIPT]')) {
        contents.add({'role': 'model', 'parts': [{'text': chunk}]});
        contents.add({'role': 'user', 'parts': [{'text': 'Next'}]});
      } else {
        break;
      }
    }
    c.close();
    return sb.toString().replaceAll('[MORE]', '').replaceAll('[END OF SCRIPT]', '').trim();
  }

  Uint8List _pcmToWav(Uint8List pcm, int rate) {
    final h = ByteData(44);
    final sz = pcm.length;
    for (int i = 0; i < 4; i++) {
      h.setUint8(i, 'RIFF'.codeUnitAt(i));
      h.setUint8(8 + i, 'WAVE'.codeUnitAt(i));
      h.setUint8(12 + i, 'fmt '.codeUnitAt(i));
      h.setUint8(36 + i, 'data'.codeUnitAt(i));
    }
    h.setUint32(4, 36 + sz, Endian.little);
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);
    h.setUint16(22, 1, Endian.little);
    h.setUint32(24, rate, Endian.little);
    h.setUint32(28, rate * 2, Endian.little);
    h.setUint16(32, 2, Endian.little);
    h.setUint16(34, 16, Endian.little);
    h.setUint32(40, sz, Endian.little);
    final b = BytesBuilder(copy: false);
    b.add(h.buffer.asUint8List());
    b.add(pcm);
    return b.toBytes();
  }

  Future<Uint8List?> _tryCloudTTS(String txt) async {
    if (_apiKey.isEmpty) return null;
    try {
      String vName = _voiceGender.startsWith('Female') ? 'Kore' : 'Puck';
      for (final n in ['Puck', 'Charon', 'Fenrir', 'Orus', 'Kore', 'Aoede', 'Zephyr', 'Leda']) {
        if (_voiceGender.contains(n)) vName = n;
      }
      final c = HttpClient();
      final req = await c.postUrl(Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$_apiKey',
      ));
      req.headers.set('Content-Type', 'application/json; charset=utf-8');
      req.add(utf8.encode(jsonEncode({
        'contents': [{'role': 'user', 'parts': [{'text': txt}]}],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {'voiceConfig': {'prebuiltVoiceConfig': {'voiceName': vName}}}
        }
      })));
      final resp = await req.close();
      final rTxt = await resp.transform(utf8.decoder).join();
      c.close();
      if (resp.statusCode != 200) return null;
      final b64 = (jsonDecode(rTxt)['candidates']?[0]?['content']?['parts']?[0]?['inlineData']?['data'] ?? '').toString();
      if (b64.isEmpty) return null;
      return _pcmToWav(base64Decode(b64), 24000);
    } catch (_) {
      return null;
    }
  }

  Future<void> _generatePodcast() async {
    final input = _promptController.text.trim();
    if (input.isEmpty) {
      _msg('ကျေးဇူးပြု၍ စာသား အရင်ထည့်သွင်းပေးပါ');
      return;
    }
    if (_useGemPrompt && _apiKey.isEmpty) {
      _showApiKeyDialog();
      return;
    }
    setState(() {
      _isGeneratingPodcast = true;
      _generationStatus = _useGemPrompt
          ? 'Gem ($_selectedGemOption) ဖြင့် မြန်မာ Script ပြောင်းလဲနေသည်...'
          : 'စာသားကို အသံဖိုင်အဖြစ် ထုတ်လုပ်နေသည်...';
    });
    try {
      String script = input;
      if (_useGemPrompt && _apiKey.isNotEmpty) {
        script = await _runGeminiScript(
          input,
          _selectedGemOption == 'For Point' ? kForPointPrompt : kForLengthPrompt,
        );
      }
      if (!mounted) return;
      setState(() {
        _generatedScriptController.text = script;
        _generationStatus = 'Voice ($_voiceGender) ဖြင့် အသံဖိုင် ထုတ်ယူသိမ်းဆည်းနေသည်...';
      });

      final Uint8List? cloudWav = await _tryCloudTTS(script);
      final dynamic res = await _channel.invokeMethod('generateTTS', {
        'text': script,
        'speed': _speed,
        'cloudBytes': cloudWav,
      });

      final String localPath = (res is Map ? res['local'] : res).toString();
      final String publicPath = (res is Map ? res['public'] : res).toString();

      if (!mounted) return;
      setState(() {
        _isGeneratingPodcast = false;
        _lastLocalAudioPath = localPath;
        _lastPublicAudioPath = publicPath;
        _generationStatus = '✓ အသံဖိုင် သိမ်းဆည်းပြီးပါပြီ: $publicPath';
      });
      await _togglePlayAudio();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingPodcast = false;
        _generationStatus = 'Error: $e';
      });
    }
  }

  Future<void> _togglePlayAudio() async {
    if (_lastLocalAudioPath.isEmpty) return;
    try {
      if (_isPlayingAudio) {
        await _channel.invokeMethod('stopAudio');
        setState(() => _isPlayingAudio = false);
      } else {
        await _channel.invokeMethod('playAudio', {'path': _lastLocalAudioPath});
        setState(() => _isPlayingAudio = true);
      }
    } catch (e) {
      _msg('Play Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WY's PODCAST", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
        backgroundColor: darkBg,
        actions: [
          IconButton(icon: const Icon(Icons.help_outline, color: goldAccent), onPressed: _showHelpDialog),
          IconButton(icon: const Icon(Icons.info_outline, color: goldAccent), onPressed: _showAboutDialog),
          IconButton(
            icon: Icon(Icons.vpn_key, color: _apiKey.isNotEmpty ? goldAccent : Colors.white70),
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                for (final t in [(0, '1. Audio to Text (Offline)', Icons.mic_none), (1, '2. Podcast Studio (AI)', Icons.auto_awesome)])
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = t.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedTab == t.$1 ? goldAccent : Colors.white12,
                              width: _selectedTab == t.$1 ? 2.5 : 1,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(t.$3, size: 20, color: _selectedTab == t.$1 ? goldAccent : Colors.white54),
                            const SizedBox(height: 6),
                            Text(
                              t.$2,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedTab == t.$1 ? FontWeight.bold : FontWeight.normal,
                                color: _selectedTab == t.$1 ? goldAccent : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_selectedTab == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _modelStatus,
                                  style: const TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickMedia('Audio'),
                                  icon: const Icon(Icons.audiotrack, color: goldAccent, size: 18),
                                  label: const Text('အသံဖိုင် ရွေးမည်'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickMedia('MP4'),
                                  icon: const Icon(Icons.movie_creation_outlined, color: goldAccent, size: 18),
                                  label: const Text('.mp4 ဗီဒီယို ရွေးမည်'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(_selectedMediaPath, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isProcessingSTT ? null : _runSTT,
                            icon: _isProcessingSTT
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.graphic_eq, size: 18),
                            label: Text(_isProcessingSTT ? 'Offline Whisper ပြောင်းနေသည်...' : 'Offline Whisper ဖြင့် စာသားထုတ်မည်'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Text Output:', style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          TextField(controller: _sttOutputController, maxLines: 8),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _sttOutputController.text));
                                    _msg('Copy ကူးပြီးပါပြီ');
                                  },
                                  icon: const Icon(Icons.copy, color: goldAccent, size: 17),
                                  label: const Text('Copy ကူးမည်'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _saveTxt(_sttOutputController.text, 'Transcript'),
                                  icon: const Icon(Icons.save_alt, color: goldAccent, size: 17),
                                  label: const Text('.txt သိမ်းမည်'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _promptController.text = _sttOutputController.text;
                                _selectedTab = 1;
                              });
                            },
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('အပိုင်း (၂) Podcast Studio သို့ ပို့မည်'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_selectedTab == 1) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Input Text:', style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickTxtForTab2,
                                  icon: const Icon(Icons.description, color: goldAccent, size: 18),
                                  label: const Text('.txt ဖိုင် ရွေးပါ'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _promptController.text = _sttOutputController.text),
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
                            decoration: const InputDecoration(hintText: 'စာသား ရိုက်ထည့်ပါ သို့မဟုတ် ဖိုင်ရွေးပါ...'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          for (final opt in ['For Point', 'For Length'])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: (_selectedGemOption == opt && _useGemPrompt) ? goldAccent : Colors.transparent,
                                    foregroundColor: (_selectedGemOption == opt && _useGemPrompt) ? Colors.black : Colors.white,
                                  ),
                                  onPressed: _useGemPrompt
                                      ? () {
                                          setState(() => _selectedGemOption = opt);
                                          _saveSettings();
                                        }
                                      : null,
                                  child: Text(opt, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          Column(
                            children: [
                              Switch(
                                value: _useGemPrompt,
                                activeColor: goldAccent,
                                onChanged: (v) {
                                  setState(() => _useGemPrompt = v);
                                  _saveSettings();
                                },
                              ),
                              Text(
                                _useGemPrompt ? 'Gem ON' : 'Direct TTS',
                                style: const TextStyle(fontSize: 11, color: goldAccent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Voice Settings:', style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: _voiceStyle,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            items: _styleOptions.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _voiceStyle = v!),
                          ),
                          DropdownButton<String>(
                            value: _voiceGender,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            items: _voiceOptions.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setState(() => _voiceGender = v!),
                          ),
                          Text('Speed: ${_speed.toStringAsFixed(1)}x'),
                          Slider(
                            value: _speed,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            activeColor: goldAccent,
                            onChanged: (v) => setState(() => _speed = v),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              _saveSettings();
                              _msg('Default သိမ်းဆည်းပြီးပါပြီ');
                            },
                            child: const Text('Save as Default', style: TextStyle(color: goldAccent)),
                          ),
                        ],
                      ),
                    ),
                    if (_generationStatus.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_generationStatus, style: const TextStyle(color: goldAccent, fontSize: 13)),
                    ],
                    if (_lastLocalAudioPath.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _togglePlayAudio,
                        icon: Icon(_isPlayingAudio ? Icons.stop : Icons.play_arrow, color: Colors.black),
                        label: Text(
                          _isPlayingAudio ? 'အသံရပ်မည် (Stop Audio)' : 'ထွက်လာသော အသံဖိုင် နားထောင်မည် (Play Audio)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    if (_generatedScriptController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextField(controller: _generatedScriptController, maxLines: 6),
                    ],
                  ],
                ],
              ),
            ),
            if (_selectedTab == 1)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isGeneratingPodcast ? null : _generatePodcast,
                    icon: const Icon(Icons.auto_awesome, color: Colors.black),
                    label: Text(
                      _isGeneratingPodcast ? 'ထုတ်လုပ်နေသည်...' : 'Podcast ထုတ်လုပ်မည် (Generate Full Audio)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
