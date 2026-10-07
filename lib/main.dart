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
    'You are a professional Burmese educational and documentary podcast script writer. '
    'Transform the provided English transcript into a natural Burmese podcast script for ONE presenter. '
    'Preserve all important ideas, explanations, examples, events, and cause-and-effect relationships while combining repetitive sentences naturally. '
    'Do NOT output a short summary. Do NOT use speaker labels or stage directions. '
    'Output in ONE response if possible; if splitting is required, use [PART X] and [MORE], continue on Next, and end with [END OF SCRIPT].';

const String kLengthSystemPrompt =
    'You are a professional Burmese educational and documentary podcast script writer. '
    'Transform the provided English transcript into a FULL, complete, natural Burmese podcast script for ONE presenter preserving the full information density of the source. '
    'Do NOT summarize or compress away details. Always prefer the fuller version that preserves all explanations, chronological scenes, events, cause-and-effect, and conclusions. '
    'Do NOT use speaker labels or stage directions. '
    'Output in ONE response if possible; if splitting is required, use [PART X] and [MORE], continue on Next, and end with [END OF SCRIPT].';

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
  
  // Google AI Studio Original Categories & Voices
  String _style = 'Tutor';
  String _voice = 'Bodi';
  double _speed = 1.0;

  bool _busyScript = false;
  bool _busyTTS = false;
  String _status = '';

  String _audioPath = '';
  String _publicAudioPath = '';
  bool _playing = false;
  int _posMs = 0;
  int _durMs = 0;
  Timer? _playerTimer;

  // Exact Google AI Studio Voice Mapping
  final Map<String, List<String>> _voiceCategories = {
    'Tutor': ['Bodi', 'Lumi', 'Sola', 'Varo', 'Sadaltager', 'Sulafat', 'Zephyr', 'Fola'],
    'Podcast': ['Puck', 'Charon', 'Kore', 'Fenrir', 'Aoede'],
    'Storyteller': ['Leda', 'Orus'],
    'Professional': ['Charon', 'Kore', 'Aoede'],
    'News / Broadcast': ['Fenrir', 'Puck', 'Orus'],
  };

  @override
  void initState() {
    super.initState();
    _initData();
    _playerTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _pollAudioState());
  }

  @override
  void dispose() {
    _playerTimer?.cancel();
    _sttCtrl.dispose();
    _inputCtrl.dispose();
    _scriptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pollAudioState() async {
    if (_audioPath.isEmpty || !mounted) return;
    try {
      final st = await _channel.invokeMethod('audioState');
      if (st is Map && mounted) {
        final p = st['playing'] == true;
        final pos = (st['pos'] as int?) ?? 0;
        final dur = (st['dur'] as int?) ?? 0;
        if (p != _playing || pos != _posMs || dur != _durMs) {
          setState(() {
            _playing = p;
            _posMs = pos;
            _durMs = dur;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _initData() async {
    try {
      final prefs = await _channel.invokeMethod('loadPrefs');
      if (prefs is Map && mounted) {
        setState(() {
          _apiKey = (prefs['apiKey'] ?? '').toString().trim();
          
          if (_voiceCategories.containsKey(prefs['style'])) {
            _style = prefs['style'];
          }
          if (_voiceCategories[_style]!.contains(prefs['voice'])) {
            _voice = prefs['voice'];
          } else {
            _voice = _voiceCategories[_style]!.first;
          }
          
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
          _modelStatus = '✓ Fast Offline Whisper အသင့်ရှိသည်';
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Row(
          children: const [
            Icon(Icons.help_outline, color: goldAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gemini API ရယူနည်း',
                style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            '⚠ အရေးကြီးသည်: မြန်မာနိုင်ငံမှ Google AI Studio သို့ ဝင်ရောက်စဉ် ဖုန်း၌ VPN ဖွင့်ထားပေးရန် လိုအပ်ပါသည်။\n\n'
            '၁။ ဖုန်းတွင် VPN ဖွင့်ပြီး Browser ဖြင့် aistudio.google.com/app/apikey သို့ သွားပါ။\n\n'
            '၂။ Google Account (Gmail) ဖြင့် Sign In ဝင်ပါ။\n\n'
            '၃။ "Create API key" ကို နှိပ်ပြီး ရရှိလာသော AIzaSy... Key ကို Copy ကူးပါ။\n\n'
            '၄။ App အပေါ်ညာဘက်ရှိ သော့ပုံ (Key Icon) ကို နှိပ်ပြီး Paste ချကာ Save နှိပ်ပါ။',
            style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'https://aistudio.google.com/app/apikey'));
              _snack('Link ကို Copy ကူးပြီးပါပြီ');
            },
            child: const Text('Link ကူးမည်', style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('နားလည်ပါပြီ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          "WY's PODCAST (v1.0.0)",
          style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 19),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ရည်ရွယ်ချက် (Vision):',
                style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              const SizedBox(height: 8),
              const Text(
                'ဘာသာစကား အခက်အခဲကြောင့် ခေတ်မီနည်းပညာများနှင့် အသိပညာဗဟုသုတများ ရယူရာတွင် အဟန့်အတား မဖြစ်စေရန် မည်သူမဆို AI နည်းပညာကို လက်တွေ့အသုံးချပြီး နိုင်ငံတကာမှ အကြောင်းအရာများကို မြန်မာဘာသာဖြင့် လေ့လာဖန်တီးနိုင်သော Podcast စနစ်အဖြစ် တည်ဆောက်ထားပါသည်။',
                style: TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: '@seniorwaiyan'));
                  _snack('Telegram @seniorwaiyan ကို Copy ကူးပြီးပါပြီ');
                },
                child: Row(
                  children: const [
                    Icon(Icons.send, color: goldAccent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Telegram: @seniorwaiyan',
                      style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ပိတ်မည်', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
          if (_apiKey.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _saveCfg(key: '');
                if (mounted) Navigator.pop(ctx);
                _snack('API Key ဖျက်ပြီးပါပြီ');
              },
              child: const Text('ဖျက်မည်', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ပိတ်မည်')),
          FilledButton(
            onPressed: () async {
              await _saveCfg(key: c.text);
              if (mounted) Navigator.pop(ctx);
              _snack('API Key ကို အမြဲတမ်း သိမ်းဆည်းပြီးပါပြီ');
            },
            child: const Text('Save သိမ်းမည်', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia(String mime) async {
    final res = await _channel.invokeMethod('pickFile', {'mimeType': mime});
    if (res is Map && res['path'] != null) {
      setState(() => _mediaPath = res['path'].toString());
      _snack('ရွေးချယ်ပြီးပါပြီ: ${res['name']}');
    }
  }

  String? _tryExtractDocxOrZipXml(Uint8List bytes) {
    try {
      int i = 0;
      final texts = <String>[];
      while (i + 30 < bytes.length) {
        if (bytes[i] == 0x50 && bytes[i + 1] == 0x4B && bytes[i + 2] == 0x03 && bytes[i + 3] == 0x04) {
          final method = bytes[i + 8] | (bytes[i + 9] << 8);
          final compSize = bytes[i + 18] | (bytes[i + 19] << 8) | (bytes[i + 20] << 16) | (bytes[i + 21] << 24);
          final nameLen = bytes[i + 26] | (bytes[i + 27] << 8);
          final extraLen = bytes[i + 28] | (bytes[i + 29] << 8);
          final nameStart = i + 30;
          final dataStart = nameStart + nameLen + extraLen;
          if (dataStart > bytes.length) break;
          final entryName = utf8.decode(bytes.sublist(nameStart, nameStart + nameLen), allowMalformed: true);
          if (compSize > 0 && dataStart + compSize <= bytes.length) {
            if (entryName.endsWith('.xml') || entryName.endsWith('.txt') || entryName.endsWith('.html')) {
              final compData = bytes.sublist(dataStart, dataStart + compSize);
              List<int> rawEntry;
              if (method == 0) {
                rawEntry = compData;
              } else {
                rawEntry = ZLibDecoder(raw: true).convert(compData);
              }
              if (entryName.contains('document.xml') || !entryName.endsWith('.xml')) {
                final xmlStr = utf8.decode(rawEntry, allowMalformed: true);
                final cleaned = xmlStr
                    .replaceAll('</w:p>', '\n')
                    .replaceAll('<w:br/>', '\n')
                    .replaceAll(RegExp(r'<[^>]+>'), '');
                if (cleaned.trim().isNotEmpty) texts.add(cleaned.trim());
              }
            }
            i = dataStart + compSize;
            continue;
          }
        }
        i++;
      }
      if (texts.isNotEmpty) return texts.join('\n\n');
    } catch (_) {}
    return null;
  }

  String _cleanTextFormatting(String raw) {
    var s = raw;
    if (s.contains(r'\u10') || s.contains(r'\u00')) {
      s = s.replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'), (m) {
        return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
      });
    }
    if (s.contains('&#')) {
      s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        return String.fromCharCode(int.parse(m.group(1)!));
      });
      s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
        return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
      });
    }
    if (s.contains('<html') || s.contains('<!DOCTYPE') || s.contains('<body') || s.contains('<div') || s.contains('<p>')) {
      s = s
          .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
          .replaceAll(RegExp(r'</(p|div|br|li|tr|h[1-6])>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"');
    }
    return s.trim();
  }

  String _decodeBytesSmart(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
      final docxText = _tryExtractDocxOrZipXml(bytes);
      if (docxText != null && docxText.isNotEmpty) return _cleanTextFormatting(docxText);
    }
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return _cleanTextFormatting(utf8.decode(bytes.sublist(3), allowMalformed: true));
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final codes = <int>[];
      for (int i = 2; i + 1 < bytes.length; i += 2) {
        codes.add(bytes[i] | (bytes[i + 1] << 8));
      }
      return _cleanTextFormatting(String.fromCharCodes(codes));
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final codes = <int>[];
      for (int i = 2; i + 1 < bytes.length; i += 2) {
        codes.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return _cleanTextFormatting(String.fromCharCodes(codes));
    }

    int samplePairs = (bytes.length ~/ 2).clamp(0, 200);
    if (samplePairs > 4) {
      int oddHigh = 0;
      int evenHigh = 0;
      for (int i = 0; i < samplePairs * 2; i += 2) {
        if (bytes[i + 1] == 0x10 || bytes[i + 1] == 0x00) oddHigh++;
        if (bytes[i] == 0x10 || bytes[i] == 0x00) evenHigh++;
      }
      if (oddHigh > samplePairs * 0.35) {
        final codes = <int>[];
        for (int i = 0; i + 1 < bytes.length; i += 2) {
          codes.add(bytes[i] | (bytes[i + 1] << 8));
        }
        return _cleanTextFormatting(String.fromCharCodes(codes));
      }
      if (evenHigh > samplePairs * 0.35) {
        final codes = <int>[];
        for (int i = 0; i + 1 < bytes.length; i += 2) {
          codes.add((bytes[i] << 8) | bytes[i + 1]);
        }
        return _cleanTextFormatting(String.fromCharCodes(codes));
      }
    }

    return _cleanTextFormatting(utf8.decode(bytes, allowMalformed: true));
  }

  Future<void> _pickTxtFile() async {
    try {
      final res = await _channel.invokeMethod('pickFile', {'mimeType': '*/*'});
      if (res is Map && res['path'] != null) {
        final f = File(res['path'].toString());
        final rawBytes = await f.readAsBytes();
        final textContent = _decodeBytesSmart(rawBytes);
        setState(() => _inputCtrl.text = textContent);
        _snack('ဖိုင် (${res['name']}) မှ စာသားများ ထည့်သွင်းပြီးပါပြီ');
      }
    } catch (e) {
      _snack('.txt ဖိုင်ဖတ်ရာတွင် အမှားရှိနေပါသည်: $e');
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

  Future<String> _callGeminiModelWithFallback(
    HttpClient client,
    String sysPrompt,
    List<Map<String, dynamic>> history,
  ) async {
    final models = <String>['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-flash-latest'];
    String firstRealErr = '';

    for (final m in models) {
      try {
        final req = await client.postUrl(Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$_apiKey',
        ));
        req.headers.set('Content-Type', 'application/json; charset=utf-8');
        req.add(utf8.encode(jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': sysPrompt}
            ]
          },
          'contents': history,
          'safetySettings': [
            {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
            {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
            {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
            {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
          ],
          'generationConfig': {'temperature': 0.4},
        })));
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        if (resp.statusCode == 200) {
          final j = jsonDecode(body);
          final candidates = j['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final sb = StringBuffer();
              for (final pt in parts) {
                if (pt['text'] != null) sb.write(pt['text']);
              }
              final txt = sb.toString().trim();
              if (txt.isNotEmpty) return txt;
            }
            final reason = candidates[0]['finishReason'] ?? 'UNKNOWN';
            if (firstRealErr.isEmpty) firstRealErr = 'Model ($m) blocked response: $reason';
          }
        } else if (resp.statusCode != 404) {
          if (firstRealErr.isEmpty) firstRealErr = '($m HTTP ${resp.statusCode}): $body';
        }
      } catch (e) {
        if (firstRealErr.isEmpty) firstRealErr = e.toString();
      }
    }
    throw Exception(firstRealErr.isNotEmpty ? firstRealErr : 'Gemini API ချိတ်ဆက်၍ မရပါ။ VPN နှင့် API Key ကို စစ်ဆေးပါ။');
  }

  Future<String> _transformScript(String src) async {
    final sys = _gemMode == 'For Point' ? kPointSystemPrompt : kLengthSystemPrompt;
    final parts = _chunkText(src, 12000);
    final sb = StringBuffer();
    final client = HttpClient();

    try {
      for (int p = 0; p < parts.length; p++) {
        final prefix = parts.length > 1 ? '[PART ${p + 1}]\n' : '';
        final List<Map<String, dynamic>> history = [
          {
            'role': 'user',
            'parts': [
              {'text': '$prefix${parts[p]}'}
            ]
          }
        ];
        for (int step = 0; step < 10; step++) {
          if (mounted) {
            setState(() => _status = 'Gem ($_gemMode) ဖြင့် မြန်မာ Script ရေးသားနေသည် (အပိုင်း ${p + 1}/${parts.length})...');
          }
          final chunk = await _callGeminiModelWithFallback(client, sys, history);
          sb.writeln(chunk);
          if (chunk.contains('[MORE]') && !chunk.contains('[END OF SCRIPT]')) {
            history.add({
              'role': 'model',
              'parts': [
                {'text': chunk}
              ]
            });
            history.add({
              'role': 'user',
              'parts': [
                {'text': 'Next'}
              ]
            });
          } else {
            break;
          }
        }
      }
    } finally {
      client.close();
    }
    return sb.toString().replaceAll(RegExp(r'\[PART\s*\d+\]|\[MORE\]|\[END OF SCRIPT\]'), '').trim();
  }

  Future<void> _convertScriptOnly() async {
    final raw = _inputCtrl.text.trim();
    if (raw.isEmpty) {
      _snack('Input Box ထဲတွင် စာသား အရင်ထည့်ပေးပါ');
      return;
    }
    if (_apiKey.isEmpty) {
      _apiDialog();
      return;
    }
    setState(() {
      _busyScript = true;
      _status = 'မြန်မာ Podcast Script သို့ ပြောင်းလဲနေသည်...';
    });
    try {
      final script = await _transformScript(raw);
      setState(() {
        _busyScript = false;
        _scriptCtrl.text = script;
        _status = '✓ မြန်မာ Podcast Script ပြောင်းလဲပြီးပါပြီ။ အောက်တွင် စစ်ဆေးပြီး အသံထုတ်နိုင်ပါပြီ။';
      });
    } catch (e) {
      setState(() {
        _busyScript = false;
        _status = 'Script Error: $e';
      });
    }
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

  Future<Uint8List> _geminiTtsMerged(String script) async {
    // API သို့ တိုက်ရိုက်ပေးပို့မည့် အသံနာမည် (Bodi, Puck စသည်)
    String vName = _voice;
    final chunks = _chunkText(script, 3200);
    final pcmBuilder = BytesBuilder(copy: false);
    final client = HttpClient();

    try {
      for (int i = 0; i < chunks.length; i++) {
        if (mounted) {
          setState(() => _status = 'Gemini Voice ($vName) ဖြင့် အသံထုတ်နေသည် (အပိုင်း ${i + 1}/${chunks.length})...');
        }
        int retries = 0;
        while (true) {
          final req = await client.postUrl(Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$_apiKey',
          ));
          req.headers.set('Content-Type', 'application/json; charset=utf-8');
          req.add(utf8.encode(jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': chunks[i]}
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
            if (mounted) setState(() => _status = 'Rate Limit ခေတ္တစောင့်နေသည် (15s)...');
            await Future.delayed(const Duration(seconds: 15));
            continue;
          }
          if (resp.statusCode != 200 && vName != 'Puck' && retries == 0) {
            retries++;
            vName = 'Charon';
            continue;
          }
          if (resp.statusCode != 200) {
            throw Exception('TTS HTTP ${resp.statusCode}: $body');
          }
          final b64 = (jsonDecode(body)['candidates']?[0]?['content']?['parts']?[0]?['inlineData']?['data'] ?? '').toString();
          if (b64.isEmpty) {
            throw Exception('TTS မှ အသံဒေတာ မရရှိပါ: $body');
          }
          pcmBuilder.add(base64Decode(b64));
          break;
        }
      }
    } finally {
      client.close();
    }
    return _wrapWav(pcmBuilder.toBytes(), 24000);
  }

  Future<void> _generateAudio() async {
    final raw = _inputCtrl.text.trim();
    if (raw.isEmpty && _scriptCtrl.text.trim().isEmpty) {
      _snack('စာသား အရင်ထည့်ပေးပါ');
      return;
    }
    if (_apiKey.isEmpty) {
      _snack('Gemini API Key အရင်ထည့်ပေးပါ');
      _apiDialog();
      return;
    }
    setState(() {
      _busyTTS = true;
      _status = 'စတင် ထုတ်လုပ်နေသည်...';
    });
    try {
      String scriptToRead = _scriptCtrl.text.trim();
      if (_useGem) {
        if (scriptToRead.isEmpty) {
          scriptToRead = await _transformScript(raw);
          setState(() => _scriptCtrl.text = scriptToRead);
        }
      } else {
        scriptToRead = raw;
        setState(() => _scriptCtrl.text = scriptToRead);
      }

      final wavBytes = await _geminiTtsMerged(scriptToRead);
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
        _publicAudioPath = pub;
        _status = '✓ သိမ်းဆည်းပြီးပါပြီ: $pub';
      });
      await _playAudio();
    } catch (e) {
      setState(() {
        _busyTTS = false;
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _playAudio() async {
    if (_audioPath.isEmpty) return;
    final res = await _channel.invokeMethod('playAudio', {'path': _audioPath});
    if (res is Map && mounted) {
      setState(() {
        _playing = true;
        _durMs = (res['dur'] as int?) ?? 0;
        _posMs = (res['pos'] as int?) ?? 0;
      });
    }
  }

  Future<void> _pauseAudio() async {
    await _channel.invokeMethod('pauseAudio');
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _stopAudio() async {
    await _channel.invokeMethod('stopAudio');
    if (mounted) {
      setState(() {
        _playing = false;
        _posMs = 0;
      });
    }
  }

  String _fmtMs(int ms) {
    final totalSec = (ms ~/ 1000).clamp(0, 86400);
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WY's PODCAST", style: TextStyle(color: goldAccent, fontWeight: FontWeight.bold)),
        backgroundColor: darkBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: goldAccent),
            tooltip: 'Gemini API ရယူနည်း',
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: goldAccent),
            tooltip: 'About WY\'s PODCAST',
            onPressed: _showAboutDialog,
          ),
          IconButton(
            icon: Icon(Icons.vpn_key, color: _apiKey.isNotEmpty ? goldAccent : Colors.white70),
            tooltip: 'API Key သိမ်းဆည်းရန်',
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
                    label: Text('2. Podcast Studio', style: TextStyle(color: _tab == 1 ? goldAccent : Colors.white54)),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: (_busyTTS || _busyScript) ? null : _generateAudio,
                    icon: _busyTTS
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.auto_awesome, color: Colors.black),
                    label: Text(
                      _busyTTS ? 'Generating Audio...' : 'Generate Podcast Audio',
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
            child: OutlinedButton.icon(
              onPressed: () => _pickMedia('audio/*'),
              icon: const Icon(Icons.audiotrack, color: goldAccent, size: 18),
              label: const Text('အသံဖိုင် ရွေးမည်'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickMedia('video/*'),
              icon: const Icon(Icons.movie, color: goldAccent, size: 18),
              label: const Text('MP4 ရွေးမည်'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(_mediaPath, style: const TextStyle(fontSize: 12, color: Colors.white60)),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busySTT ? null : _runWhisper,
        icon: _busySTT
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.graphic_eq, color: Colors.black),
        label: Text(
          _busySTT ? 'Offline Whisper ပြောင်းနေသည်...' : 'Offline Whisper ဖြင့် စာသားထုတ်မည်',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _sttCtrl,
        maxLines: 8,
        decoration: const InputDecoration(
          labelText: 'Whisper Output Transcript',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _sttCtrl.text));
                _snack('Copy ကူးပြီးပါပြီ');
              },
              icon: const Icon(Icons.copy, color: goldAccent, size: 16),
              label: const Text('Copy'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => setState(() {
                _inputCtrl.text = _sttCtrl.text;
                _scriptCtrl.clear();
                _tab = 1;
              }),
              icon: const Icon(Icons.arrow_forward, color: Colors.black, size: 16),
              label: const Text('အပိုင်း (၂) သို့ ပို့မည်', style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildTab2() {
    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickTxtFile,
              icon: const Icon(Icons.description, color: goldAccent, size: 18),
              label: const Text('.txt ဖိုင် ရွေးပါ'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _inputCtrl.text = _sttCtrl.text;
                _scriptCtrl.clear();
              }),
              icon: const Icon(Icons.input, color: goldAccent, size: 18),
              label: const Text('အပိုင်း (၁) မှ ယူမည်'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _inputCtrl,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Input Text / Source Transcript',
          hintText: 'စာသား ရိုက်ထည့်ပါ၊ Paste ချပါ သို့မဟုတ် .txt ဖိုင်ရွေးပါ...',
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
                  child: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          Column(
            children: [
              Switch(
                value: _useGem,
                activeColor: goldAccent,
                onChanged: (v) {
                  setState(() => _useGem = v);
                  _saveCfg();
                },
              ),
              Text(_useGem ? 'Gem ON' : 'Custom TTS', style: const TextStyle(fontSize: 11, color: goldAccent)),
            ],
          ),
        ],
      ),
      if (_useGem) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: (_busyScript || _busyTTS) ? null : _convertScriptOnly,
          icon: _busyScript
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: goldAccent))
              : const Icon(Icons.translate, color: goldAccent),
          label: Text(
            _busyScript ? 'Translating to Burmese Script...' : 'Preview Burmese Script',
            style: const TextStyle(color: goldAccent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
      const SizedBox(height: 16),
      
      // Original English Categories and Voices Dropdowns
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Voice Style', style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _style,
                      isExpanded: true,
                      items: _voiceCategories.keys.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _style = v!;
                          _voice = _voiceCategories[v]!.first;
                        });
                        _saveCfg();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Voice Name', style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _voice,
                      isExpanded: true,
                      items: _voiceCategories[_style]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) {
                        setState(() => _voice = v!);
                        _saveCfg();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      
      if (_status.isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: goldAccent.withOpacity(0.5)),
          ),
          child: Text(_status, style: const TextStyle(color: goldAccent, fontSize: 13)),
        ),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.headphones, color: goldAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _audioPath.isEmpty
                        ? 'In-App Audio Preview Player'
                        : 'Playing: ${_publicAudioPath.split('/').last}',
                    style: const TextStyle(color: goldAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            Slider(
              value: _posMs.toDouble().clamp(0, _durMs > 0 ? _durMs.toDouble() : 1.0),
              min: 0,
              max: _durMs > 0 ? _durMs.toDouble() : 1.0,
              activeColor: goldAccent,
              onChanged: _audioPath.isEmpty
                  ? null
                  : (v) async {
                      setState(() => _posMs = v.toInt());
                      await _channel.invokeMethod('seekAudio', {'pos': v.toInt()});
                    },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_fmtMs(_posMs)} / ${_fmtMs(_durMs)}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                Row(
                  children: [
                    IconButton(
                      onPressed: _audioPath.isEmpty ? null : (_playing ? _pauseAudio : _playAudio),
                      icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: goldAccent, size: 34),
                    ),
                    IconButton(
                      onPressed: _audioPath.isEmpty ? null : _stopAudio,
                      icon: const Icon(Icons.stop_circle_outlined, color: Colors.white70, size: 30),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _scriptCtrl,
        maxLines: 6,
        decoration: InputDecoration(
          labelText: 'Preview / Output Podcast Script (ပြင်ဆင်နိုင်သည်)',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.copy, color: goldAccent),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _scriptCtrl.text));
              _snack('Script Copy ကူးပြီးပါပြီ');
            },
          ),
        ),
      ),
    ];
  }
}
// === END OF FILE ===
