import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BurmesePodcastApp());
}

// Gold color accent for dark theme
const Color goldAccent = Color(0xFFC09961);

class BurmesePodcastApp extends StatelessWidget {
  const BurmesePodcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Burmese Podcast Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
        primaryColor: goldAccent,
        colorScheme: const ColorScheme.dark(
          primary: goldAccent,
          secondary: goldAccent,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          outline: goldAccent,
        ),
        useMaterial3: true,
        // Match standard button design
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButtonStyleFrom(
            foregroundColor: goldAccent,
            side: const BorderSide(color: goldAccent, width: 1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButtonStyleFrom(
            backgroundColor: goldAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: goldAccent, fontSize: 13),
          hintStyle: TextStyle(color: Colors.white60, fontSize: 12),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: goldAccent),
          ),
          filled: true,
          fillColor: Color(0xFF2C2C2E),
        ),
        textTheme: const TextTheme(
          bodySmall: TextStyle(fontSize: 11, color: Colors.white60),
          titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          labelSmall: TextStyle(fontSize: 12, color: Colors.white),
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
  // Navigation
  int _selectedTab = 1; // Base 0, so 1 is Tab 2

  // States
  bool _isProcessingSTT = false;
  String _selectedSource = 'ရွေးချယ်ထားခြင်း မရှိသေးပါ';
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _editedTextController = TextEditingController();
  final List<DialogueLine> _dialogueList = [
    DialogueLine(speaker: 'Speaker 1', text: 'မင်္ဂလာပါ၊ ဒီနေ့ ပေါ့ဒ်ကတ်စ် အစီအစဉ်ကနေ ကြိုဆိုပါတယ်။'),
    DialogueLine(speaker: 'Speaker 2', text: 'ဟုတ်ကဲ့ မင်္ဂလာပါခင်ဗျာ၊ ဒီနေ့ ဆွေးနွေးမယ့် အကြောင်းအရာကတော့ စိတ်ဝင်စားဖို့ ကောင်းပါတယ်။'),
  ];
  final List<Map<String, String>> _savedEpisodes = [];

  // Podcast Studio State
  String _selectedSpeakerForEdit = 'Speaker 1';
  double _speed = 1.0;
  String _style = 'Podcast';
  String _gender = 'Male';
  String _selectedPromptStyle = 'For Point';

  void _selectMedia(String type) {
    setState(() {
      _selectedSource = '$type ဖိုင် ရွေးချယ်ထားပြီး (sample_media.mp4)';
    });
  }

  Future<void> _runWhisperSTT() async {
    setState(() {
      _isProcessingSTT = true;
    });
    // Simulate STT run
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isProcessingSTT = false;
      _promptController.text =
          'Whisper Offline AI မှ အသံဖိုင်ကို မြန်မာစာသားအဖြစ် ပြောင်းလဲပြီးပါပြီ။';
    });
  }

  void _addDialogueLine() {
    final text = _editedTextController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _dialogueList.add(
          DialogueLine(speaker: _selectedSpeakerForEdit, text: text));
      _editedTextController.clear();
      // Auto-toggle speaker
      _selectedSpeakerForEdit =
          _selectedSpeakerForEdit == 'Speaker 1' ? 'Speaker 2' : 'Speaker 1';
    });
  }

  void _exportPodcast() {
    if (_dialogueList.isEmpty) return;
    setState(() {
      _savedEpisodes.insert(0, {
        'title': 'Podcast Episode #${_savedEpisodes.length + 1}',
        'lines': '${_dialogueList.length} ကြောင်း (Speaker 1 & 2)',
        'time': TimeOfDay.now().format(context),
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Podcast အပိုင်းသစ် ထုတ်ယူသိမ်းဆည်းပြီးပါပြီ!'),
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _editedTextController.dispose();
    super.dispose();
  }

  // --- UI Build Methods ---

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
                color: isSelected ? goldAccent : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? goldAccent : Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, color: isSelected ? goldAccent : Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButtonWithIcon(IconData icon, String label, VoidCallback onPressed) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _buildActionChip(String label, {bool isSelected = false, IconData? icon}) {
    return InkWell(
      onTap: () => setState(() => _selectedPromptStyle = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? goldAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white30,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (icon != null) Icon(icon, size: 14, color: isSelected ? Colors.white : goldAccent),
            if (icon != null) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFormField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Expanded(
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
        style: const TextStyle(fontSize: 12),
        items: items.map((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(val),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offlineCheckStatusText = 'Whisper Offline Model အသင့်ရှိသည် (74.1 MB)'; // Simulated
    
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('WY\'s PODCAST',
                style: TextStyle(
                    fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.key, color: goldAccent, size: 16),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab Navigation Bar
          Row(
            children: [
              _buildTab(0, '1. Audio to Text (Offline)', Icons.mic),
              _buildTab(1, '2. Podcast Studio (AI)', Icons.auto_awesome),
            ],
          ),
          
          // Expanded Content Area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Display Offline Status above main content
                if (_selectedTab == 1) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.greenAccent),
                      title: const Text('Offline Whisper AI Engine',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(offlineCheckStatusText,
                          style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- TAB 1 Content: Offline STT ---
                if (_selectedTab == 0) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('အဆင့် (၁) ဗီဒီယို / အသံဖိုင် ရွေးချယ်ရန်',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildOutlinedButtonWithIcon(
                                  Icons.video_library, 'ဗီဒီယို ရွေးမည်', () => _selectMedia('ဗီဒီယို')),
                              const SizedBox(width: 8),
                              _buildOutlinedButtonWithIcon(
                                  Icons.audiotrack, 'အသံဖိုင် ရွေးမည်', () => _selectMedia('အသံ')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(_selectedSource,
                              style: const TextStyle(fontSize: 11, color: Colors.white60)),
                          const SizedBox(height: 16),
                          const Text('အဆင့် (၂) Whisper STT ပြုလုပ်ရန်',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _isProcessingSTT ? null : _runWhisperSTT,
                            icon: _isProcessingSTT
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.bolt, size: 16),
                            label: Text(
                                _isProcessingSTT ? 'Whisper AI ဖြင့် ပြောင်းနေသည်...' : 'စာသားထုတ်မည် (Run Whisper STT)',
                                style: const TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // --- TAB 2 Content: Podcast Studio (AI) ---
                if (_selectedTab == 1) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Input Text (စာသား ထည့်သွင်းနည်းများ):',
                              style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildOutlinedButtonWithIcon(Icons.document_scanner, '.txt ဖိုင် ရွေးပါ', () {}),
                              const SizedBox(width: 8),
                              _buildOutlinedButtonWithIcon(Icons.exit_to_app, 'အပိုင်း (၁) မှ ယူမည်', () {}),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _promptController,
                            maxLines: null,
                            minLines: 8,
                            decoration: const InputDecoration(
                              hintText: 'စာသား ရိုက်ထည့်ပါ၊ Paste ချပါ သို့မဟုတ် အပေါ် မှ ဖိုင်ရွေးပါ...',
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          
                          const Text('Podcast Style / Prompt ရွေးချယ်မှု:', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildActionChip('For Point', isSelected: _selectedPromptStyle == 'For Point', icon: Icons.check_circle_outline),
                                _buildActionChip('For Length', isSelected: _selectedPromptStyle == 'For Length'),
                                _buildActionChip('Custom', isSelected: _selectedPromptStyle == 'Custom'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text('Voice Settings:', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildDropdownFormField('Style:', _style, ['Podcast', 'Conversation'], (val) => setState(() => _style = val!)),
                              const SizedBox(width: 8),
                              _buildDropdownFormField('Gender:', _gender, ['Male', 'Female'], (val) => setState(() => _gender = val!)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Speed: ${_speed.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 10),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: goldAccent,
                              inactiveTrackColor: Colors.white10,
                              thumbColor: goldAccent,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                              trackHeight: 1,
                            ),
                            child: Slider(
                              value: _speed,
                              min: 0.5,
                              max: 1.5,
                              divisions: 10,
                              onChanged: (double val) => setState(() => _speed = val),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {}, // Save as Default simulation
                            child: const Text('Save as Default'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Refined Dialogue Editor (Preserve Step 3 logic)
                  const SizedBox(height: 16),
                  const Text('အဆင့် (၃) Speaker 1 & Speaker 2 စကားပြော တည်းဖြတ်ရန်',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildActionChip('Speaker 1 (Host)', isSelected: _selectedSpeakerForEdit == 'Speaker 1'),
                                    _buildActionChip('Speaker 2 (Guest)', isSelected: _selectedSpeakerForEdit == 'Speaker 2'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _editedTextController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: '$_selectedSpeakerForEdit ပြောမည့် စာသား',
                              hintText: 'စာသားရိုက်ထည့်ပါ သို့မဟုတ် STT စာသားကို ပြင်ဆင်ပါ...',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _addDialogueLine,
                            icon: const Icon(Icons.add_comment, size: 16),
                            label: Text('$_selectedSpeakerForEdit စာသား ထည့်သွင်းမည်', style: const TextStyle(fontSize: 11)),
                          ),
                          const Divider(height: 20),
                          ..._dialogueList.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final line = entry.value;
                            final isSpk1 = line.speaker == 'Speaker 1';
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: isSpk1 ? Colors.deepPurple : Colors.teal,
                                child: Text(isSpk1 ? 'S1' : 'S2', style: const TextStyle(fontSize: 10)),
                              ),
                              title: Text(line.speaker, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              subtitle: Text(line.text, style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () {
                                  setState(() => _dialogueList.removeAt(idx));
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // STEP 4: Export (Simulated on Tab 2)
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('အဆင့် (၄) Podcast ထုတ်ယူရန်', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _exportPodcast,
                            icon: const Icon(Icons.save_alt, size: 16),
                            label: const Text('Podcast အပိုင်းသစ် ထုတ်ယူသိမ်းဆည်းမည်', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Saved Episodes List (Unified)
                const SizedBox(height: 16),
                const Text('သိမ်းဆည်းပြီးသော Episodes များ:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                const SizedBox(height: 10),
                if (_savedEpisodes.isEmpty) ...[
                  const Text('သိမ်းဆည်းထားသော အပိုင်းများ မရှိသေးပါ', style: TextStyle(fontSize: 11, color: Colors.white60)),
                ] else ...[
                  ..._savedEpisodes.map((ep) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.podcasts, color: Colors.greenAccent, size: 18),
                          title: Text(ep['title'] ?? '', style: const TextStyle(fontSize: 12)),
                          subtitle: Text(ep['lines'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                          trailing: Text(ep['time'] ?? '', style: const TextStyle(fontSize: 10)),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
