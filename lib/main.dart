import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MaterialApp(
    home: AudioPodcastApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class AudioPodcastApp extends StatefulWidget {
  const AudioPodcastApp({super.key});

  @override
  State<AudioPodcastApp> createState() => _AudioPodcastAppState();
}

class _AudioPodcastAppState extends State<AudioPodcastApp> {
  // သင်၏ API Keys များကို ဤနေရာတွင် ထည့်ပါ (မထည့်ရသေးပါက နောက်မှ ပြန်ပြင်၍ ရပါသည်)
  final String groqApiKey = "YOUR_GROQ_API_KEY";
  final String geminiApiKey = "YOUR_GEMINI_API_KEY";
  final String googleTtsApiKey = "YOUR_GOOGLE_CLOUD_TTS_API_KEY";

  String statusText = "Audio ဖိုင်တစ်ခု ရွေးချယ်ပါ";
  bool isProcessing = false;
  String? generatedBurmeseText;
  String? finalAudioPath;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> pickAndProcessAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
    );

    if (result == null || result.files.single.path == null) return;

    File audioFile = File(result.files.single.path!);
    setState(() {
      isProcessing = true;
      statusText = "အသံဖိုင်မှ စာသားရယူနေပါသည် (Whisper)...";
    });

    try {
      String engText = await convertAudioToEnglishText(audioFile);

      setState(() {
        statusText = "မြန်မာ Podcast စတိုင်သို့ ပြောင်းလဲရေးဖွဲ့နေပါသည် (Gemini)...";
      });

      String mmPodcastText = await convertToBurmesePodcast(engText);
      setState(() {
        generatedBurmeseText = mmPodcastText;
        statusText = "မြန်မာအသံဖိုင် ထုတ်လုပ်နေပါသည် (Google TTS)...";
      });

      String outputPath = await generateCombinedBurmeseAudio(mmPodcastText);

      setState(() {
        finalAudioPath = outputPath;
        statusText = "Podcast အောင်မြင်စွာ ထုတ်လုပ်ပြီးပါပြီ။ နားဆင်နိုင်ပါပြီ။";
        isProcessing = false;
      });
    } catch (e) {
      setState(() {
        statusText = "ချို့ယွင်းချက်ဖြစ်ပေါ်ပါသည်- $e";
        isProcessing = false;
      });
    }
  }

  Future<String> convertAudioToEnglishText(File audioFile) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
    );
    request.headers['Authorization'] = 'Bearer $groqApiKey';
    request.fields['model'] = 'whisper-large-v3';
    request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var json = jsonDecode(responseData);

    if (response.statusCode == 200) {
      return json['text'];
    } else {
      throw Exception("Whisper Error: ${json['error']?['message'] ?? responseData}");
    }
  }

  Future<String> convertToBurmesePodcast(String englishText) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey',
    );

    final prompt = '''
You are a Burmese podcast creator.
Take the following English transcription and rewrite it into a smooth, natural, and engaging Burmese spoken podcast script (မြန်မာစကားပြော ပေါ့ကတ်စ် စတိုင်).
Do NOT translate it word-by-word like a book. Use conversational Burmese, friendly tone, natural phrasing, and smooth storytelling flow.
Only provide the Burmese script, no meta explanations.

English text:
$englishText
''';

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    final json = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return json['candidates'][0]['content']['parts'][0]['text'];
    } else {
      throw Exception("Gemini Error: ${json['error']?['message'] ?? response.body}");
    }
  }

  Future<String> generateCombinedBurmeseAudio(String script) async {
    List<String> chunks = splitText(script, 1000);
    List<Uint8List> audioBytesList = [];

    for (var chunk in chunks) {
      final url = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$googleTtsApiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "input": {"text": chunk},
          "voice": {
            "languageCode": "my-MM",
            "name": "my-MM-Standard-A"
          },
          "audioConfig": {
            "audioEncoding": "MP3",
            "speakingRate": 1.0
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Uint8List bytes = base64Decode(data['audioContent']);
        audioBytesList.add(bytes);
      } else {
        throw Exception("TTS Error: ${response.body}");
      }
    }

    final dir = await getTemporaryDirectory();
    final outputFile = File('${dir.path}/final_podcast_${DateTime.now().millisecondsSinceEpoch}.mp3');
    final sink = outputFile.openWrite();
    
    for (var chunkBytes in audioBytesList) {
      sink.add(chunkBytes);
    }
    await sink.flush();
    await sink.close();

    return outputFile.path;
  }

  List<String> splitText(String text, int maxLength) {
    List<String> chunks = [];
    int start = 0;
    while (start < text.length) {
      int end = (start + maxLength < text.length) ? start + maxLength : text.length;
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }

  void togglePlayPause() async {
    if (finalAudioPath == null) return;
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(finalAudioPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Audio to Burmese Podcast"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: isProcessing ? null : pickAndProcessAudio,
              icon: const Icon(Icons.upload_file),
              label: const Text("Audio ဖိုင်ရွေးပြီး စတင်ပါ"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            if (isProcessing) const CircularProgressIndicator(),
            const SizedBox(height: 10),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const Divider(height: 30),
            if (finalAudioPath != null) ...[
              Card(
                color: Colors.deepPurple.shade50,
                child: ListTile(
                  leading: IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                    iconSize: 40,
                    color: Colors.deepPurple,
                    onPressed: togglePlayPause,
                  ),
                  title: const Text("Final Burmese Podcast"),
                  subtitle: Text(isPlaying ? "Playing..." : "Paused"),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (generatedBurmeseText != null) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("ထွက်ရှိလာသော Podcast စာသား-", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      generatedBurmeseText!,
                      style: const TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
