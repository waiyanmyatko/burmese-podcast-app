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

const String kPointSystemPrompt =
    'Transform the provided transcript into a natural Burmese single-presenter podcast script. '
    'Preserve all key facts, explanations, examples, and cause-and-effect relationships while combining repetitive ideas naturally. '
    'Do not use speaker labels or stage directions. If splitting is needed, use [PART X] and [MORE], continue on Next, and finish with [END OF SCRIPT].';

const String kLengthSystemPrompt =
    'Transform the provided transcript into a comprehensive, detailed Burmese single-presenter documentary podcast script. '
    'Preserve full information density, chronological scenes, supporting details, and reasoning without summarizing. '
    'Do not use speaker labels or stage directions. If splitting is needed, use [PART X] and [MORE], continue on Next, and finish with [END OF SCRIPT].';

class WysPodcastApp extends StatelessWidget {
  const WysPodcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "WY's PODCAST",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: darkBg,
        colorScheme: const ColorScheme.dark(
          primary: goldAccent,
          secondary: goldAccent,
          surface: cardBg,
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
  int _tab = 1;
  String _apiKey = '';
  String _modelPath = '';
  String _modelStatus = 'Offline Whisper Model ပြင်ဆင်နေသည်...';
  bool _busySTT = false;
  String _mediaPath = 'ဖိုင် ရွေးချယ်ထားခြင်း မရှိသေးပါ';

  final TextEditingController _sttCtrl = TextEditingController();
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _scriptCtrl = TextEditingController();

  bool _useGem = false;
  String _gemMode = 'For Point';
  String _style = 'Podcast (သဘာဝကျသော ဆွေးနွေးခန်းဟန်)';
  String _voice = 'Male - Puck (သွက်လက်ဖော်ရွေသော အမျိုးသားသံ)';
  double _speed = 1.0;
  bool _busyTTS = false;
  String _status = '';
  String _audioPath = '';
  bool _playing = false;

  final List<String> _styles = [
    'Podcast (သဘာဝကျသော ဆွေးနွေးခန်းဟန်)',
    'Storytelling (ဇာတ်လမ်း/ဝတ္ထု ပြောပြဟန်)',
    'News / Broadcast (သတင်းကြေညာဟန်)',
    'Documentary (မှတ်တမ်းရုပ်ရှင် နောက်ခံပြောဟန်)',
    'Educational / Explainer (ပညာပေး ရှင်းပြဟန်)',
  ];

  final List<String> _voices = [
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
    _initData();
  }

  Future<void> _initData() async {
    try {
      final prefs = await _channel.invokeMethod('loadPrefs');
      if (prefs is Map && mounted) {
        setState(() {
          _apiKey = (prefs['apiKey'] ?? '').toString().trim();
          if (_styles.contains(prefs['style'])) _style = prefs['style'];
          if (_voices.contains(prefs['voice'])) _voice = prefs['voice'];
          if (prefs['speed'] is num) _speed = (prefs['speed'] as num).toDouble().clamp(0.5, 2.0);
          if (prefs['useGem'] is bool) _useGem = prefs['useGem'];
          if (prefs['gemMode'] == 'For Point' || prefs['gemMode'] == 'For Length') {
            _gemMode = prefs['gemMode'];
          }
        });
      }
      final mp = await _channel.invokeMethod('prepareModel');
      if (mounted && mp != null) {
        setState(() {
          _modelPath = mp.toString();
          _modelStatus = '✓ Offline Whisper Model အသင့်ရှိသည် (75 MB)';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _modelStatus = 'Model Error: $e');
    }
  }

  Future<void> _saveCfg({String? key}) async {
    if (key != null) {
      setState(() => _apiKey = key.trim());
    }
    await _channel.invokeMethod('savePrefs', {
      'apiKey': _apiKey,
      'style': _style,
      'voice': _voice,
      'speed': _speed,
      'useGem': _useGem,
      'gemMode': _gemMode,
    });
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _apiDialog() {
    final c = TextEditingController(text: _apiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: const Text('Gemini API Key သိမ်းဆည်းရန်', style: TextStyle(color: goldAccent, fontSize: 18)),
        content: TextField(
          controller: c,
          decoration: InputDecoration(
            hintText: 'AIzaSy...',
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste, color: goldAccent),
              onPressed: () async {
                final d = await Clipboard.getData('text/plain');
                if (d?.text != null) c.text = d!.text!.trim();
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ပိတ်မည်')),
          FilledButton(
            onPressed: () async {
              await _saveCfg(key: c.text);
              if (mounted) Navigator.pop(ctx);
              _snack('API Key ကို အမြဲတမ်း သိမ်းဆည်းပြီးပါပြီ');
            },
            child: const Text('Save သိမ်းမည်'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia(String mime) async {
    final res = await _channel.invokeMethod('pickFile', {'mode': 'media', 'mimeType': mime});
    if (res is Map && res['path'] != null) {
      setState(() => _mediaPath = res['path'].toString());
      _snack('ရွေးချယ်ပြီးပါပြီ: ${res['name']}');
    }
  }

  Future<void> _pickTxtFile() async {
    try {
      final res = await _channel.invokeMethod('pickFile', {'mode': 'txt', 'mimeType': '*/*'});
      if (res is Map && res['content'] != null) {
        setState(() => _inputCtrl.text = res['content'].toString());
        _snack('.txt ဖိုင် (${res['name']}) မှ စာသားများ ထည့်သွင်းပြီးပါပြီ');
      }
    } catch (e) {
      _snack('ဖိုင်ဖတ်ရာတွင် အမှားရှိနေပါသည်: $e');
    }
  }

  Future<void> _runWhisper() async {
    if (_mediaPath.contains('မရှိသေးပါ')) {
      _snack('အသံဖိုင် သို့မဟုတ် MP4 ဗီဒီယို အရင်ရွေးပေးပါ');
      return;
    }
    setState(() => _busySTT = true);
    try {
      final res = await _channel.invokeMethod('transcribeOffline', {
        'path': _mediaPath,
        'modelPath': _modelPath,
      });
      setState(() {
        _busySTT = false;
        _sttCtrl.text = (res ?? '').toString().trim();
      });
      _snack('Offline Whisper စာသားထုတ်ယူခြင်း ပြီးမြောက်ပါပြီ');
    } catch (e) {
      setState(() => _busySTT = false);
      _snack('STT Error: $e');
    }
  }

  List<String> _chunkText(String txt, int limit) {
    final List<String> out = [];
    final sentences = txt.split(RegExp(r'(?<=[။.!?])\s+|\n+'));
    final sb = StringBuffer();
    for (final s in sentences) {
      if (sb.length + s.length + 1 > limit) {
        if (sb.isNotEmpty) {
          out.add(sb.toString().trim());
          sb.clear();
        }
        if (s.length > limit) {
          for (int i = 0; i < s.length; i += limit) {
            out.add(s.substring(i, i + limit > s.length ? s.length : i + limit));
          }
        } else {
          sb.write('$s ');
        }
      } else {
        sb.write('$s ');
      }
    }
    if (sb.toString().trim().isNotEmpty) out.add(sb.toString().trim());
    return out.isEmpty ? [txt] : out;
  }

  Future<String> _transformScript(String src) async {
    final sys = _gemMode == 'For Point' ? kPointSystemPrompt : kLengthSystemPrompt;
    final parts = _chunkText(src, 12000);
    final sb = StringBuffer();
    final client = HttpClient();

    for (int p = 0; p < parts.length; p++) {
      final List<Map<String, dynamic>> history = [
        {'role': 'user', 'parts': [{'text': '[PART ${p + 1}]\n${parts[p]}'}]}
      ];
      for (int step = 0; step < 10; step++) {
        setState(() => _status = 'Gem Prompt ဖြင့် မြန်မာ Script ရေးနေသည် (Part ${p + 1}/${parts.length})...');
        final req = await client.postUrl(Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
        ));
        req.headers.set('Content-Type', 'application/json; charset=utf-8');
        req.add(utf8.encode(jsonEncode({
          'systemInstruction': {'parts': [{'text': sys}]},
          'contents': history,
        })));
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        if (resp.statusCode != 200) throw Exception('Gemini Error (${resp.statusCode}): $body');
        final chunk = (jsonDecode(body)['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '').toString();
        sb.writeln(chunk);
        if (chunk.contains('[MORE]') && !chunk.contains('[END OF SCRIPT]')) {
          history.add({'role': 'model', 'parts': [{'text': chunk}]});
          history.add({'role': 'user', 'parts': [{'text': 'Next'}]});
        } else {
          break;
        }
      }
    }
    client.close();
    return sb.toString().replaceAll(RegExp(r'\[PART\s*\d+\]|\[MORE\]|\[END OF SCRIPT\]'), '').trim();
  }

  Uint8List _wrapWav(Uint8List pcm, int rate) {
    final h = ByteData(44);
    final len = pcm.length;
    for (int i = 0; i < 4; i++) {
      h.setUint8(i, 'RIFF'.codeUnitAt(i));
      h.setUint8(8 + i, 'WAVE'.codeUnitAt(i));
      h.setUint8(12 + i, 'fmt '.codeUnitAt(i));
      h.setUint8(36 + i, 'data'.codeUnitAt(i));
    }
    h.setUint32(4, 36 + len, Endian.little);
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);
    h.setUint16(22, 1, Endian.little);
    h.setUint32(24, rate, Endian.little);
    h.setUint32(28, rate * 2, Endian.little);
    h.setUint16(32, 2, Endian.little);
    h.setUint16(34, 16, Endian.little);
    h.setUint32(40, len, Endian.little);
    final b = BytesBuilder(copy: false);
    b.add(h.buffer.asUint8List());
    b.add(pcm);
    return b.toBytes();
  }

  Future<Uint8List> _geminiAiStudioTtsMerged(String script) async {
    String vName = 'Puck';
    for (final n in ['Puck', 'Charon', 'Fenrir', 'Orus', 'Kore', 'Aoede', 'Zephyr', 'Leda']) {
      if (_voice.contains(n)) vName = n;
    }
    final chunks = _chunkText(script, 2500);
    final pcmBuilder = BytesBuilder(copy: false);
    final client = HttpClient();

    for (int i = 0; i < chunks.length; i++) {
      setState(() => _status = 'Gemini Voice ($vName) ဖြင့် အသံထုတ်နေသည် (အပိုင်း ${i + 1}/${chunks.length})...');
      int retries = 0;
      while (true) {
        final req = await client.postUrl(Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$_apiKey',
        ));
        req.headers.set('Content-Type', 'application/json; charset=utf-8');
        req.add(utf8.encode(jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Read the following podcast script aloud naturally in a $_style tone:\n\n${chunks[i]}'}
              ]
            }
          ],
          'generationConfig': {
            'responseModalities': ['AUDIO'],
            'speechConfig': {
              'voiceConfig': {
                'prebuiltVoiceConfig': {'voiceName': vName}
              }
            }
          }
        })));
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        if (resp.statusCode == 429 && retries < 3) {
          retries++;
          setState(() => _status = 'API Rate Limit ခေတ္တစောင့်နေသည် (15s)...');
          await Future.delayed(const Duration(seconds: 15));
          continue;
        }
        if (resp.statusCode != 200) {
          client.close();
          throw Exception('Gemini TTS Error (${resp.statusCode}): VPN ဖွင့်ထားရန် နှင့် API Key မှန်ကန်ကြောင်း စစ်ဆေးပါ။\n$body');
        }
        final b64 = (jsonDecode(body)['candidates']?[0]?['content']?['parts']?[0]?['inlineData']?['data'] ?? '').toString();
        if (b64.isEmpty) {
          client.close();
          throw Exception('Gemini TTS မှ အသံဒေတာ မရရှိပါ။');
        }
        pcmBuilder.add(base64Decode(b64));
        break;
      }
    }
    client.close();
    return _wrapWav(pcmBuilder.toBytes(), 24000);
  }

  Future<void> _generateAudio() async {
    final raw = _inputCtrl.text.trim();
    if (raw.isEmpty) {
      _snack('စာသား အရင်ထည့်ပေးပါ');
      return;
    }
    if (_apiKey.isEmpty) {
      _snack('Gemini AI Voice ထုတ်ရန် API Key အရင်ထည့်ပေးပါ');
      _apiDialog();
      return;
    }
    setState(() {
      _busyTTS = true;
      _status = 'စတင် ထုတ်လုပ်နေသည်...';
    });
    try {
      final script = _useGem ? await _transformScript(raw) : raw;
      setState(() => _scriptCtrl.text = script);

      final wavBytes = await _geminiAiStudioTtsMerged(script);
      setState(() => _status = 'အသံဖိုင် တစ်ပုဒ်တည်းအဖြစ် သိမ်းဆည်းနေသည်...');

      final res = await _channel.invokeMethod('saveAudio', {
        'bytes': wavBytes,
        'ext': 'wav',
      });

      final local = (res is Map ? res['local'] : res).toString();
      final pub = (res is Map ? res['public'] : res).toString();

      setState(() {
        _busyTTS = false;
        _audioPath = local;
        _status = '✓ သိမ်းဆည်းပြီးပါပြီ: $pub';
      });
      await _playOrStop();
    } catch (e) {
      setState(() {
        _busyTTS = false;
        _status = '$e';
      });
    }
  }

  Future<void> _playOrStop() async {
    if (_audioPath.isEmpty) return;
    if (_playing) {
      await _channel.invokeMethod('stopAudio');
      setState(() => _playing = false);
    } else {
      await _channel.invokeMethod('playAudio', {'path': _audioPath});
      setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WY's PODCAST", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
        backgroundColor: darkBg,
        actions: [
          IconButton(
            icon: Icon(Icons.vpn_key, color: _apiKey.isNotEmpty ? goldAccent : Colors.white70),
            onPressed: _apiDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _tab = 0),
                    icon: Icon(Icons.mic, color: _tab == 0 ? goldAccent : Colors.white54),
                    label: Text('1. Offline STT', style: TextStyle(color: _tab == 0 ? goldAccent : Colors.white54)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _tab = 1),
                    icon: Icon(Icons.auto_awesome, color: _tab == 1 ? goldAccent : Colors.white54),
                    label: Text('2. Podcast TTS', style: TextStyle(color: _tab == 1 ? goldAccent : Colors.white54)),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _tab == 0 ? _buildTab1() : _buildTab2(),
              ),
            ),
            if (_tab == 1)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _busyTTS ? null : _generateAudio,
                    icon: const Icon(Icons.auto_awesome, color: Colors.black),
                    label: Text(
                      _busyTTS ? 'ထုတ်လုပ်နေသည်...' : 'Podcast ထုတ်လုပ်မည် (Generate Full Audio)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTab1() {
    return [
      Text(_modelStatus, style: const TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickMedia('audio/*'),
              child: const Text('အသံဖိုင် ရွေးမည်'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickMedia('video/*'),
              child: const Text('MP4 ရွေးမည်'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(_mediaPath, style: const TextStyle(fontSize: 12, color: Colors.white60)),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _busySTT ? null : _runWhisper,
        child: Text(
          _busySTT ? 'Offline Whisper ပြောင်းနေသည်...' : 'Offline Whisper ဖြင့် စာသားထုတ်မည်',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 16),
      TextField(controller: _sttCtrl, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder())),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () => setState(() {
          _inputCtrl.text = _sttCtrl.text;
          _tab = 1;
        }),
        child: const Text('အပိုင်း (၂) သို့ ပို့မည်', style: TextStyle(color: Colors.black)),
      ),
    ];
  }

  List<Widget> _buildTab2() {
    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _pickTxtFile,
              child: const Text('.txt ဖိုင် ရွေးပါ'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _inputCtrl.text = _sttCtrl.text),
              child: const Text('အပိုင်း (၁) မှ ယူမည်'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _inputCtrl,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'စာသား ရိုက်ထည့်ပါ သို့မဟုတ် Paste ချပါ...',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          for (final m in ['For Point', 'For Length'])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: (_useGem && _gemMode == m) ? goldAccent : Colors.transparent,
                    foregroundColor: (_useGem && _gemMode == m) ? Colors.black : Colors.white,
                  ),
                  onPressed: _useGem
                      ? () {
                          setState(() => _gemMode = m);
                          _saveCfg();
                        }
                      : null,
                  child: Text(m),
                ),
              ),
            ),
          Switch(
            value: _useGem,
            activeColor: goldAccent,
            onChanged: (v) {
              setState(() => _useGem = v);
              _saveCfg();
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButton<String>(
        value: _style,
        isExpanded: true,
        items: _styles.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (v) {
          setState(() => _style = v!);
          _saveCfg();
        },
      ),
      DropdownButton<String>(
        value: _voice,
        isExpanded: true,
        items: _voices.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (v) {
          setState(() => _voice = v!);
          _saveCfg();
        },
      ),
      Slider(
        value: _speed,
        min: 0.5,
        max: 2.0,
        divisions: 15,
        activeColor: goldAccent,
        label: '${_speed.toStringAsFixed(1)}x',
        onChanged: (v) => setState(() => _speed = v),
        onChangeEnd: (_) => _saveCfg(),
      ),
      if (_status.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(_status, style: const TextStyle(color: goldAccent)),
        ),
      if (_audioPath.isNotEmpty)
        FilledButton.icon(
          onPressed: _playOrStop,
          icon: Icon(_playing ? Icons.stop : Icons.play_arrow, color: Colors.black),
          label: Text(
            _playing ? 'Stop Audio' : 'Play Generated Audio',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      if (_scriptCtrl.text.isNotEmpty) ...[
        const SizedBox(height: 10),
        TextField(controller: _scriptCtrl, maxLines: 6, decoration: const InputDecoration(border: OutlineInputBorder())),
      ],
    ];
  }
}
// === END OF FILE ===
