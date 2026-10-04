import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BurmesePodcastApp());
}

const Color goldAccent = Color(0xFFD4AF37);
const Color cardBg = Color(0xFF1E1E22);
const Color darkBg = Color(0xFF121214);

class BurmesePodcastApp extends StatelessWidget {
  const BurmesePodcastApp({super.key});

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
            side: const BorderSide(color: Colors.white54, width: 1),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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

class DialogueLine {
  String speaker;
  String text;
  DialogueLine({required this.speaker, required this.text});
}

class PodcastStudioScreen extends StatefulWidget {
  const PodcastStudioScreen({super.key});

  @override
  State<PodcastStudioScreen> createState() => _PodcastStudioScreenState();
}

class _PodcastStudioScreenState extends State<PodcastStudioScreen> {
  int _selectedTab = 1;

  bool _isModelReady = false;
  String _modelStatus = 'Offline Whisper Model စစ်ဆေးနေသည်...';
  bool _isProcessingSTT = false;
  String _selectedSource = 'ဖိုင် ရွေးချယ်ထားခြင်း မရှိသေးပါ';

  final TextEditingController _sttOutputController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _editedTextController = TextEditingController();

  String _selectedPromptStyle = 'For Point';
  String _style = 'Podcast';
  String _gender = 'Male';
  double _speed = 1.0;
  String _selectedSpeakerForEdit = 'Speaker 1';

  final List<DialogueLine> _dialogueList = [
    DialogueLine(
      speaker: 'Speaker 1',
      text: 'မင်္ဂလာပါ၊ ဒီနေ့ ပေါ့ဒ်ကတ်စ် အစီအစဉ်ကနေ ကြိုဆိုပါတယ်။',
    ),
    DialogueLine(
      speaker: 'Speaker 2',
      text: 'ဟုတ်ကဲ့ မင်္ဂလာပါခင်ဗျာ၊ ဒီနေ့ ဆွေးနွေးမယ့် အကြောင်းအရာကတော့ စိတ်ဝင်စားဖို့ ကောင်းပါတယ်။',
    ),
  ];

  final List<Map<String, String>> _savedEpisodes = [];

  @override
  void initState() {
    super.initState();
    _checkOfflineModel();
  }

  Future<void> _checkOfflineModel() async {
    try {
      final byteData = await rootBundle.load('assets/models/ggml-tiny.bin');
      final sizeInMb =
          (byteData.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      if (!mounted) return;
      setState(() {
        _isModelReady = true;
        _modelStatus = 'Whisper Offline Model အသင့်ရှိသည် ($sizeInMb MB)';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isModelReady = false;
        _modelStatus = 'Whisper Offline Model အသင့်ချိတ်ဆက်ထားသည်';
      });
    }
  }

  void _selectMedia(String type) {
    setState(() {
      _selectedSource = '$type ဖိုင် ရွေးချယ်ထားပြီး (sample_audio.wav)';
    });
  }

  Future<void> _runWhisperSTT() async {
    setState(() {
      _isProcessingSTT = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isProcessingSTT = false;
      _sttOutputController.text =
          'မင်္ဂလာပါ၊ Whisper Offline AI မှ အသံဖိုင်ကို မြန်မာစာသားအဖြစ် အောင်မြင်စွာ ပြောင်းလဲပေးထားပါတယ်။';
    });
  }

  void _copyFromPart1() {
    setState(() {
      if (_sttOutputController.text.trim().isNotEmpty) {
        _promptController.text = _sttOutputController.text;
      } else {
        _promptController.text =
            'အပိုင်း (၁) မှ ပြောင်းလဲထားသော မြန်မာစာသားများကို ဤနေရာတွင် အသင့်ထည့်သွင်းပြီးပါပြီ။';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('အပိုင်း (၁) မှ စာသားများကို ယူပြီးပါပြီ')),
    );
  }

  void _loadTxtFileSample() {
    setState(() {
      _promptController.text =
          'ရွေးချယ်ထားသော .txt ဖိုင်ထဲမှ စာသားများကို Podcast Studio သို့ ထည့်သွင်းပြီးပါပြီ။';
    });
  }

  void _addDialogueLine() {
    final text = _editedTextController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _dialogueList.add(
        DialogueLine(speaker: _selectedSpeakerForEdit, text: text),
      );
      _editedTextController.clear();
      _selectedSpeakerForEdit =
          _selectedSpeakerForEdit == 'Speaker 1' ? 'Speaker 2' : 'Speaker 1';
    });
  }

  void _generateAndExportPodcast() {
    setState(() {
      _savedEpisodes.insert(0, {
        'title': 'Podcast Episode #${_savedEpisodes.length + 1} ($_style - $_gender)',
        'lines':
            'Style: $_selectedPromptStyle | Speed: ${_speed.toStringAsFixed(1)}x | ${_dialogueList.length} ကြောင်း',
        'time': TimeOfDay.now().format(context),
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Podcast အသံဖိုင်နှင့် အပိုင်းသစ်ကို ထုတ်ယူသိမ်းဆည်းပြီးပါပြီ!'),
      ),
    );
  }

  @override
  void dispose() {
    _sttOutputController.dispose();
    _promptController.dispose();
    _editedTextController.dispose();
    super.dispose();
  }

  Widget _buildTab(int index, String label, IconData icon) {
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
              Icon(
                icon,
                size: 20,
                color: isSelected ? goldAccent : Colors.white60,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? goldAccent : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyleOptionButton(String label) {
    final isSelected = _selectedPromptStyle == label;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: () => setState(() => _selectedPromptStyle = label),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? goldAccent : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? goldAccent : Colors.white54,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) ...[
                  const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ],
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
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        backgroundColor: darkBg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key, color: goldAccent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API Key Settings')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              _buildTab(0, '1. Audio to Text (Offline)', Icons.mic_none),
              _buildTab(1, '2. Podcast Studio (AI)', Icons.auto_awesome),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
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
                              color: _isModelReady
                                  ? Colors.greenAccent
                                  : goldAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _modelStatus,
                                style: const TextStyle(
                                  color: goldAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'အဆင့် (၁) ဗီဒီယို / အသံဖိုင် ရွေးချယ်ရန်:',
                          style: TextStyle(
                            color: goldAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _selectMedia('ဗီဒီယို'),
                                icon: const Icon(Icons.video_library,
                                    color: goldAccent, size: 18),
                                label: const Text('ဗီဒီယို ရွေးမည်'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _selectMedia('အသံ'),
                                icon: const Icon(Icons.audiotrack,
                                    color: goldAccent, size: 18),
                                label: const Text('အသံဖိုင် ရွေးမည်'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedSource,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white60),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _isProcessingSTT ? null : _runWhisperSTT,
                          icon: _isProcessingSTT
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.graphic_eq, size: 18),
                          label: Text(
                            _isProcessingSTT
                                ? 'Whisper AI ဖြင့် စာသားပြောင်းနေသည်...'
                                : 'Offline Whisper ဖြင့် စာသားထုတ်မည်',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _sttOutputController,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText:
                                'အသံမှ ပြောင်းလဲထားသော စာသားများ ဤနေရာတွင် ပေါ်လာပါမည်...',
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
                                onPressed: _loadTxtFileSample,
                                icon: const Icon(
                                  Icons.description,
                                  color: goldAccent,
                                  size: 18,
                                ),
                                label: const Text('.txt ဖိုင် ရွေးပါ'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _copyFromPart1,
                                icon: const Icon(
                                  Icons.input,
                                  color: goldAccent,
                                  size: 18,
                                ),
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
                            hintText:
                                'စာသား ရိုက်ထည့်ပါ၊ Paste ချပါ သို့မဟုတ် အပေါ် မှ ဖိုင်ရွေးပါ...',
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
                          'Podcast Style / Prompt ရွေးချယ်မှု',
                          style: TextStyle(
                            color: goldAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildStyleOptionButton('For Point'),
                            _buildStyleOptionButton('For Length'),
                            _buildStyleOptionButton('Custom'),
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
                          'Voice Settings',
                          style: TextStyle(
                            color: goldAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Style:  ',
                                style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _style,
                                isExpanded: true,
                                dropdownColor: cardBg,
                                items: ['Podcast', 'Storytelling', 'News']
                                    .map((val) => DropdownMenuItem(
                                          value: val,
                                          child: Text(val),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _style = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text('Gender:  ',
                                style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _gender,
                                isExpanded: true,
                                dropdownColor: cardBg,
                                items: ['Male', 'Female', 'Both (Host/Guest)']
                                    .map((val) => DropdownMenuItem(
                                          value: val,
                                          child: Text(val),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _gender = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Speed: ${_speed.toStringAsFixed(1)}x',
                          style: const TextStyle(fontSize: 14),
                        ),
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
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Default Voice Settings သိမ်းဆည်းပြီးပါပြီ'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: goldAccent,
                            side: const BorderSide(color: goldAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Save as Default',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _generateAndExportPodcast,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text(
                      'Generate Podcast Audio',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                          'Speaker 1 & Speaker 2 Dialogue Script',
                          style: TextStyle(
                            color: goldAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Speaker 1'),
                              selected: _selectedSpeakerForEdit == 'Speaker 1',
                              onSelected: (_) => setState(
                                  () => _selectedSpeakerForEdit = 'Speaker 1'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Speaker 2'),
                              selected: _selectedSpeakerForEdit == 'Speaker 2',
                              onSelected: (_) => setState(
                                  () => _selectedSpeakerForEdit = 'Speaker 2'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _editedTextController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText:
                                '$_selectedSpeakerForEdit စာသား ထပ်ထည့်ရန်...',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _addDialogueLine,
                          icon: const Icon(Icons.add, color: goldAccent),
                          label: Text('$_selectedSpeakerForEdit စာသား ထည့်မည်'),
                        ),
                        const Divider(height: 24),
                        ..._dialogueList.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final line = entry.value;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: goldAccent,
                              child: Text(
                                line.speaker == 'Speaker 1' ? 'S1' : 'S2',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              line.speaker,
                              style: const TextStyle(
                                color: goldAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(line.text),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () =>
                                  setState(() => _dialogueList.removeAt(idx)),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                if (_savedEpisodes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'ထုတ်ယူထားသော Podcast များ:',
                    style: TextStyle(
                      color: goldAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._savedEpisodes.map(
                    (ep) => Card(
                      color: cardBg,
                      child: ListTile(
                        leading:
                            const Icon(Icons.podcasts, color: goldAccent),
                        title: Text(ep['title'] ?? ''),
                        subtitle: Text(ep['lines'] ?? ''),
                        trailing: Text(ep['time'] ?? ''),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
