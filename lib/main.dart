import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
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

class _PodcastHomeScreenState extends State<PodcastHomeScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _selectedFilePath;
  bool _isPlaying = false;

  // Custom Voice Settings
  String _selectedStyle = 'Podcast';
  String _selectedGender = 'Male';
  double _pitch = 1.0;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _loadDefaultSettings();
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
    });
  }

  // Load Saved Defaults
  Future<void> _loadDefaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedStyle = prefs.getString('default_style') ?? 'Podcast';
      _selectedGender = prefs.getString('default_gender') ?? 'Male';
      _pitch = prefs.getDouble('default_pitch') ?? 1.0;
      _speed = prefs.getDouble('default_speed') ?? 1.0;
    });
  }

  // Save Settings as New Default
  Future<void> _saveAsNewDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_style', _selectedStyle);
    await prefs.setString('default_gender', _selectedGender);
    await prefs.setDouble('default_pitch', _pitch);
    await prefs.setDouble('default_speed', _speed);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting အသစ်ကို Default အဖြစ် မှတ်ထားပြီးပါပြီ။')),
      );
    }
  }

  // Pick Media File
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'mp4'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  // Play / Pause Audio
  Future<void> _togglePlayPause() async {
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WY's PODCAST", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload Container
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.mic, size: 48, color: Color(0xFFC5A059)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC5A059),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _pickAudioFile,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Audio / Video ဖိုင်ရွေးပါ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFilePath != null
                          ? _selectedFilePath!.split('/').last
                          : 'ဖိုင်ရွေးချယ်ထားခြင်း မရှိသေးပါ',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Voice Customization Settings
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('အသံ Setting များ ချိန်ညှိရန်', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Voice Style:'),
                        DropdownButton<String>(
                          value: _selectedStyle,
                          dropdownColor: const Color(0xFF2A2A2A),
                          items: ['Podcast', 'Tutor', 'Storytelling'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
                          items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (val) => setState(() => _selectedGender = val!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC5A059),
                          side: const solidBorderSide(color: Color(0xFFC5A059)),
                        ),
                        onPressed: _saveAsNewDefault,
                        icon: const Icon(Icons.bookmark),
                        label: const Text('Save as Default (မူလအတိုင်း အမြဲထားမည်)'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Playback controls
            if (_selectedFilePath != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _togglePlayPause,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(_isPlaying ? 'ရပ်တန့်မည်' : 'ဖွင့်မည်', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

class solidBorderSide extends BorderSide {
  const solidBorderSide({required super.color}) : super(width: 1.5);
}
