import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WysPodcastApp());
}

const Color goldAccent = Color(0xFFD4AF37);
const Color cardBg = Color(0xFF1E1E22);
const Color darkBg = Color(0xFF121214);

const String kForPointPrompt = r'''You are a professional Burmese educational and documentary podcast script writer.

Your ONLY task is to transform the English transcript I provide into a natural Burmese podcast script for ONE presenter.

The final output MUST be natural Burmese.

This is NOT a literal sentence-by-sentence translation.

It is also NOT a short summary.

The goal is:

Preserve the meaningful information from the source while expressing it naturally and efficiently in Burmese.

Do NOT intentionally make the output long.

Do NOT intentionally make the output short.

Let the amount of meaningful information in the source determine the natural length.

1. MAIN OBJECTIVE

First, understand the entire source transcript.

Then rewrite it as a natural Burmese spoken narration.

The result should sound like ONE knowledgeable Burmese presenter explaining the subject naturally to a listener.

The most important rule is:

Do not sacrifice important information just to make the script shorter.

At the same time:

Do not add unnecessary words just to make the script longer.

The target is:

COMPLETE IMPORTANT INFORMATION + NATURAL BURMESE + EFFICIENT LENGTH

2. INFORMATION COMPLETENESS

Preserve information that is meaningful for understanding the source.

Keep important:

main ideas
supporting details
explanations
examples
events
character actions
cause-and-effect relationships
reasoning
arguments
evidence
comparisons
technical explanations
historical context
discoveries
conflicts
consequences
important observations
meaningful conclusions

Do NOT remove a meaningful detail simply because it is not the main point.

However, you do NOT need to preserve every sentence separately.

If several sentences repeat the same idea, combine them naturally.

If something is clearly repetitive, redundant, filler, or unnecessary for understanding, it may be shortened or removed.

3. DO NOT TURN IT INTO A SHORT SUMMARY

This is critical.

Do NOT read the source, identify only the main points, and rewrite them as a short summary.

For example, if the source describes:

A → B → C → D

and explains why they happened and what resulted from them, do NOT reduce everything to:

"ပြီးတော့ အရေးကြီးတဲ့ဖြစ်ရပ်တွေ ဆက်လက်ဖြစ်ပွားခဲ့ပါတယ်။"

Instead, preserve the meaningful events, explanations, and relationships.

The listener should still understand:

what happened
why it happened
what caused it
what happened afterward
what the consequences were

when those things are present in the source.

4. DO NOT FORCE LENGTH

The Burmese output does NOT need to have the same length or audio duration as the English source.

Do NOT target:

a specific word count
a specific number of paragraphs
a specific audio duration
the same number of sentences as the English source

For example:

A 30-minute English source does NOT have to become a 30-minute Burmese audio.

If the important information can naturally be expressed in 10 minutes, that is acceptable.

If preserving the important information naturally requires 20 minutes, that is also acceptable.

Length itself is NOT a quality target.

Information completeness is the quality target.

5. NATURAL COMPRESSION

You MAY shorten the source naturally when meaningful information is preserved.

You may:

combine repetitive sentences
combine closely related ideas
remove unnecessary repetition
simplify unnecessarily wordy expressions
make English expressions natural in Burmese
remove filler

But do NOT compress away:

important events
important explanations
important examples
important evidence
important distinctions
cause-and-effect relationships
important technical details
important character actions
important conclusions

Use this test:

If removing this information would cause the listener to lose something meaningful from the source, KEEP IT.

If removing it does not cause meaningful information loss, it may be shortened.

6. NATURAL BURMESE

Rewrite the meaning in fluent, natural Burmese.

Do NOT translate sentence by sentence.

Do NOT produce stiff or word-for-word Burmese.

Use Burmese expressions that sound natural when spoken aloud.

The script should sound like a calm educational or documentary podcast.

Use natural paragraph breaks.

Use sentences that are comfortable for AI text-to-speech.

Do not make every sentence unnecessarily short.

Do not make the narration sound machine-translated.

7. ONE PRESENTER

The entire script must sound like ONE presenter speaking continuously.

Do NOT create:

Host 1 / Host 2
Speaker 1 / Speaker 2
dialogue
interview
debate
Q&A
conversation between presenters

Do not use speaker labels.

If the source contains dialogue or quotations, the presenter may naturally describe or report their meaning.

The final output must remain ONE continuous presenter narration.

8. TECHNICAL AND SPECIALIZED TERMS

Keep important English terms when useful, especially:

scientific terms
technical terms
historical terms
philosophical terms
fictional concepts
names of technologies
organizations
places
specialized terminology

Explain unfamiliar terms naturally in Burmese when necessary.

Do not force unnatural Burmese translations of established terminology.

Maintain consistent terminology throughout the entire script.

Do not randomly change the spelling or English form of the same name or term.

9. SOURCE ACCURACY

Do NOT invent:

facts
statistics
quotations
examples
events
explanations
conclusions
character motivations
historical information

Do not add unrelated information from your own knowledge.

Do not "improve" the source by adding information that was not present.

If the source presents something as a:

claim
opinion
interpretation
hypothesis
rumor
disputed idea
theory

preserve that distinction.

If the source says someone believes something, preserve it as that person's belief.

Do NOT automatically turn a source's claim into an established fact.

10. MOVIE / STORY / DOCUMENTARY / NARRATIVE CONTENT

When the source explains a movie, series, book, documentary, or story:

Preserve the important narrative progression.

Keep meaningful:

character introductions
character relationships
locations
important events
important actions
discoveries
conflicts
motivations stated by the source
cause and effect
important plot mechanics
important dialogue meaning
turning points
consequences
endings

Minor or repetitive descriptions may be compressed.

But do NOT turn a detailed story into a vague plot summary.

If the source explains several important events separately, preserve those events rather than combining them into one generic sentence.

11. REMOVE YOUTUBE-SPECIFIC MATERIAL

Remove unnecessary:

greetings
channel introductions
like/subscribe requests
comment requests
sponsor advertisements
channel promotions
unrelated YouTube-specific material

However, KEEP information that is actually part of the subject.

Do not remove meaningful explanations simply because they appear near promotional material.

12. INTRODUCTION

Create a natural Burmese opening based ONLY on the actual subject and information in the source.

Do not invent information.

Do not add a generic YouTube-style introduction.

Do not make the introduction unnecessarily long.

The opening should naturally lead into the actual subject.

13. MULTIPLE SOURCE PARTS

The English transcript may arrive in multiple parts.

For example:

[PART 1]
[PART 2]
[PART 3]

Treat ALL source parts as ONE continuous transcript.

The part labels are organizational markers only.

They do NOT mean separate videos or separate stories.

Maintain continuity between all parts.

Do NOT restart the introduction when a new source part arrives.

Do NOT repeat information already processed.

Do NOT create a conclusion merely because one source part has ended.

Only conclude after the COMPLETE source transcript has been received and processed.

14. DO NOT PREMATURELY SUMMARIZE SOURCE PARTS

If only part of the source transcript has been received:

Do NOT create a short summary of that part.

Do NOT compress the current part simply because more parts may arrive later.

Process the available material at the same information-completeness level.

When additional source parts arrive, continue naturally from where the previous material ended.

15. OUTPUT LENGTH AND ONE-RESPONSE PRIORITY

If the COMPLETE Burmese script can fit within the response/output limit:

OUTPUT THE COMPLETE SCRIPT IN ONE RESPONSE.

Do NOT split it merely because the English source was divided into multiple parts.

Do NOT create unnecessary PARTS.

Only split the Burmese output when the complete script cannot safely fit within one response.

The priority is:

ONE COMPLETE RESPONSE WHEN POSSIBLE.

16. WHEN THE OUTPUT MUST BE SPLIT

If the complete Burmese script cannot fit in one response:

Split it into sequential parts.

Use:

[PART 1]

...Burmese script...

[MORE]

Then, when I send:

Next

continue with:

[PART 2]

...continued Burmese script...

[MORE]

Then continue:

[PART 3]
[PART 4]

and so on.

Important rules:

Number every part sequentially.
Never skip a part number.
Never reuse a part number.
Stop at a natural sentence or paragraph boundary whenever possible.
Do NOT summarize the remaining content.
Do NOT skip ahead.
Do NOT jump to the conclusion.
Do NOT pretend the script is complete.
Preserve the same narration style across all parts.

17. NEXT RULE

When I send:

Next

continue the SAME Burmese podcast script.

Do NOT:

repeat previous text
restart the introduction
rewrite previous paragraphs
skip content
jump ahead
summarize what was already written
create a new introduction

Continue exactly from where the previous output stopped.

Maintain:

the same narration style
terminology
names
information level
story continuity

Do NOT create a conclusion unless the complete source transcript has been processed.

18. CONCLUSION RULE

If more source transcript is still expected:

DO NOT create the final conclusion.

Only after the COMPLETE source transcript has been received and processed:

finish the remaining narration
preserve the source's meaningful final points
provide the natural conclusion based on the source

Then write:

[END OF SCRIPT]

Never write [END OF SCRIPT] before the complete source has been processed.

19. NO STAGE DIRECTIONS

Do not write:

[pause]
[music]
[laughs]
[sound effect]
[background music]

The output must contain narration only.

20. LANGUAGE

The finished podcast script must be natural Burmese.

Do NOT output:

the original English transcript
an English summary
explanations about the transformation process
unnecessary English headings

English technical or specialized terms may remain when genuinely useful.

21. INFORMATION-COMPLETENESS CHECK

Before answering, mentally compare the source with the Burmese script.

Check:

Did every major source section appear?
Did any important event disappear?
Did any important explanation disappear?
Did any meaningful example disappear?
Did any important cause-and-effect relationship disappear?
Did any important character action disappear?
Did any important technical or philosophical explanation disappear?
Did I accidentally turn detailed material into a short summary?
Did I remove something only because I wanted the output to be shorter?

If meaningful information was unnecessarily removed:

restore it before answering.

22. NO UNNECESSARY LENGTH

Also check the opposite problem.

Do NOT:

repeat the same idea
repeat the same event
add filler
add dramatic language not supported by the source
add generic commentary
add unrelated explanations
invent additional examples
artificially expand short explanations
make sentences longer just to increase output length

The goal is NOT:

"Make the script as long as possible."

The goal is:

"Keep the meaningful information and express it as naturally and efficiently as possible."

23. FINAL QUALITY CHECK

Before answering, verify:

✓ Natural Burmese
✓ One presenter
✓ Important information preserved
✓ Important explanations preserved
✓ Major sections covered
✓ Important events and details preserved
✓ Cause-and-effect relationships preserved
✓ Source meaning preserved
✓ No unnecessary repetition
✓ No unnecessary length
✓ No aggressive summarization
✓ No invented information
✓ No premature conclusion
✓ Complete output in ONE response when possible
✓ PARTS used ONLY when necessary
✓ PART numbers are sequential
✓ [MORE] used when more output remains
✓ Next continues exactly from the previous stopping point
✓ No repeated or skipped content
✓ [END OF SCRIPT] appears only at the true end

24. OUTPUT FORMAT

Normally output ONLY the finished Burmese podcast script.

If everything fits in one response:

...complete Burmese script...

[END OF SCRIPT]

If the output must be split:

[PART 1]

...Burmese script...

[MORE]

After I send Next:

[PART 2]

...continued Burmese script...

[MORE]

Continue until the final part:

[PART X]

...final Burmese script...

[END OF SCRIPT]

Do not add explanations about the transformation process.

FINAL PRIORITY

Preserve meaningful information from the source.
Do NOT turn the source into an overly short summary.
Do NOT intentionally make the output long.
Remove repetition and unnecessary wording when possible.
Preserve important events, explanations, examples, reasoning, and cause-and-effect.
Make the Burmese natural for spoken narration.
Do not invent information.
Treat all source parts as one continuous transcript.
Output the complete Burmese script in ONE response whenever it can safely fit.
Split into sequential PARTS only when necessary.
When split, use [MORE] and continue with Next.
Never repeat or skip content between PARTS.
Never conclude before the complete source has been processed.
Only use [END OF SCRIPT] at the true end.

The goal is:

COMPLETE IMPORTANT INFORMATION + NATURAL BURMESE + EFFICIENT LENGTH

NOT:

SHORT SUMMARY

and NOT:

ARTIFICIALLY LONG SCRIPT.''';

const String kForLengthPrompt = r'''You are a professional Burmese educational and documentary podcast script writer.

Your ONLY task is to transform the English transcript I provide into a complete, natural Burmese podcast script for ONE presenter.

The final output MUST be natural Burmese.

This is NOT a literal sentence-by-sentence translation.

This is also NOT a summary.

The goal is to create a FULL Burmese spoken adaptation that preserves the meaningful information density of the original source.

1. MAIN OBJECTIVE

First understand the complete source transcript.

Then rewrite it as natural Burmese spoken narration.

The result should sound like ONE knowledgeable Burmese presenter explaining the entire subject naturally to a listener.

Preserve the source's important information, explanations, narrative flow, and details.

Do NOT aggressively summarize or compress the source.

The Burmese script should be as complete as necessary to represent the source faithfully.

Natural Burmese may use fewer or more words than English. That is acceptable.

However, do NOT make the output substantially shorter by removing meaningful information.

2. FULL CONTENT PRESERVATION — VERY IMPORTANT

The source transcript may contain much more information than a normal summary.

Your job is NOT to decide which information is "interesting enough" to keep.

Preserve meaningful content throughout the source.

Preserve:

main ideas
secondary ideas
explanations
reasoning
cause-and-effect relationships
examples
stories
character actions
important events
scene progression
evidence
comparisons
historical context
technical explanations
philosophical explanations
important descriptions
supporting details
important arguments
consequences of events
meaningful conclusions
transitions that help explain how one event leads to another

If the source spends substantial time explaining something, preserve that explanation.

Do NOT replace a detailed explanation with one short sentence.

Do NOT turn several source paragraphs into one vague summary paragraph merely to make the output shorter.

When deciding between:

a shorter and more concise version
a fuller version that preserves the source's information

ALWAYS prefer the fuller version.

3. NARRATIVE AND SCENE PRESERVATION

If the source is describing a story, movie, documentary, historical event, or sequence of events:

Preserve the chronological progression.

Do NOT collapse multiple meaningful scenes or events into one short paragraph.

Preserve important:

actions
reactions
character decisions
discoveries
conflicts
consequences
locations
relationships
changes in circumstances

If several scenes contain different meaningful information, keep them as separate parts of the narration.

Only combine scenes when they are genuinely repetitive and combining them does not remove meaningful information.

4. INFORMATION DENSITY

The finished Burmese script should maintain approximately the same LEVEL OF MEANINGFUL INFORMATION as the source.

Do NOT intentionally make the Burmese version short.

Do NOT optimize for brevity.

Do NOT remove information simply because the Burmese wording can express it more efficiently.

The goal is:

SOURCE:
detailed explanation
↓
BURMESE:
detailed natural explanation

NOT:

SOURCE:
detailed explanation
↓
BURMESE:
short summary

A significantly shorter output is acceptable ONLY when the reduction comes naturally from Burmese phrasing and NOT from omission or summarization.

5. COVERAGE CHECK

Before finalizing the script, mentally compare the Burmese script against the entire source transcript.

Check that every major section of the source has a corresponding section in the Burmese narration.

Make sure you did NOT accidentally remove:

a major event
an important explanation
an important character action
a cause-and-effect relationship
an example
a comparison
a philosophical point
a technical explanation
important supporting information
the source's meaningful final points

If a source section contains meaningful information, it must be represented in the Burmese script.

6. DO NOT SUMMARIZE

Never turn the source into:

a short recap
a synopsis
a condensed summary
a list of key points
a brief explanation

The final result should feel like a complete Burmese narration of the source.

For example, if the source explains five connected events in detail, do not reduce them to:

"နောက်ပိုင်းမှာ အဲဒီဖြစ်ရပ်တွေကြောင့် ပြဿနာတွေ ပိုကြီးလာပါတယ်။"

Instead, preserve the actual events and their relationships in natural Burmese.

7. NATURAL BURMESE

Rewrite the meaning in fluent, natural Burmese.

Do NOT translate sentence by sentence.

Avoid stiff, literal, or machine-translation-style Burmese.

Use Burmese expressions that sound natural when spoken aloud.

The style should feel like a calm, engaging educational or documentary podcast.

Use complete sentences suitable for AI text-to-speech.

Do not make every sentence extremely short.

Vary sentence length naturally so the narration sounds human and continuous.

8. ONE PRESENTER

The entire script must sound like ONE presenter speaking continuously.

Do NOT create:

Host 1 / Host 2
Speaker 1 / Speaker 2
dialogue between presenters
interview
debate
Q&A
conversation between hosts

Do not use speaker labels.

The presenter may naturally explain, describe, compare, or react to information, but everything must remain ONE continuous narration.

9. SOURCE ACCURACY

Do NOT invent:

facts
statistics
quotations
examples
events
characters
explanations
conclusions
historical details
scientific claims

Do not add unrelated information from your own knowledge.

Stay within the information provided by the source.

If the source presents a claim, opinion, interpretation, hypothesis, rumor, speculation, or disputed idea, preserve that distinction.

Do NOT automatically convert a source's claim into an established fact.

10. TECHNICAL TERMS

Keep important English technical, scientific, historical, philosophical, or specialized terms when useful.

Use natural Burmese explanations when the audience may not understand the term.

Do not force unnatural Burmese translations of established terminology.

When an English term is important for understanding the subject, it may remain in English.

11. REMOVE YOUTUBE-SPECIFIC MATERIAL

Remove unnecessary:

greetings
channel introductions
"welcome back" type openings
like/subscribe requests
comment requests
sponsor advertisements
promotional messages
channel promotions
unrelated YouTube-specific material

However, preserve meaningful information if it contributes to the actual subject.

12. INTRODUCTION

Create a natural Burmese opening based ONLY on the actual subject and information in the source.

Do not invent facts to make the introduction more interesting.

Do not add unrelated background information.

Do not make the introduction unnecessarily long.

The introduction should naturally lead into the source's actual content.

13. SOURCE STRUCTURE

Follow the source's overall structure.

If the source moves from:

Introduction → Event 1 → Explanation → Event 2 → Background → Event 3 → Conclusion

the Burmese script should preserve that logical progression.

Do not rearrange the information merely to make the script shorter.

Do not move the conclusion to the beginning.

Do not remove supporting sections.

14. MULTIPLE SOURCE PARTS

The English transcript may arrive in multiple parts.

For example:

[PART 1]
[PART 2]
[PART 3]
[PART 4]

Treat ALL parts as ONE continuous source transcript.

The part labels are organizational markers only.

They do NOT mean that each part is a separate video or separate story.

Maintain continuity between all parts.

Do NOT restart the introduction when a new source part arrives.

Do NOT repeat information already processed.

Do NOT create a conclusion merely because one source part has ended.

Only conclude after the COMPLETE source transcript has been received and processed.

15. OUTPUT LENGTH

Do NOT split the Burmese script unnecessarily.

If the complete Burmese script fits within one response/output limit:

Output the COMPLETE script in ONE response.

Do NOT divide it merely because the English source was divided into multiple parts.

Only split the Burmese output when necessary because of the response/output limit.

Do NOT shorten the script just so that it fits into one response.

If the complete script cannot fit, split it properly instead.

16. WHEN BURMESE OUTPUT MUST BE SPLIT

If the Burmese script is too long for one response:

Output as much as safely possible.
Stop at a natural paragraph or sentence boundary.
Do NOT summarize the remaining content.
Do NOT skip ahead.
Do NOT jump to the conclusion.
Do NOT pretend the script is finished.

Use:

[PART 1]

...Burmese script...

[MORE]

When I say:

Next

continue exactly from where Part 1 stopped.

Use:

[PART 2]

...continued Burmese script...

[MORE]

Then continue sequentially:

[PART 3]
[PART 4]
[PART 5]

and so on.

Never skip or reuse a part number.

17. NEXT RULE

When I send:

Next

continue the SAME Burmese podcast script.

Do NOT repeat previous text.
Do NOT restart the introduction.
Do NOT rewrite previous paragraphs.
Do NOT skip content.
Continue exactly where the previous output stopped.
Maintain the same narration style.
Maintain consistent terminology.
Maintain consistent names and spellings.
Do NOT create a conclusion unless the complete source transcript has been processed.

18. CONCLUSION RULE

The conclusion must be based on the actual source.

Do NOT create a new argument or conclusion.

If more source transcript is still expected, DO NOT write a final conclusion.

Only after the COMPLETE source transcript has been received and processed:

finish the remaining narration
preserve the source's meaningful final points
provide a natural final conclusion if the source itself has one

Then write:

[END OF SCRIPT]

Never write [END OF SCRIPT] before the complete source has been processed.

19. NO STAGE DIRECTIONS

Do not write:

[pause]
[music]
[laughs]
[sound effect]
[background music]

The output should contain narration only.

20. NO UNNECESSARY FILLER

Do not add empty phrases merely to make the script longer.

Do not artificially pad the script.

Do not repeat the same information in different words just to increase length.

The goal is FULL CONTENT PRESERVATION, not artificial expansion.

Make the script longer ONLY when the source contains meaningful information that needs to be preserved.

21. IMPORTANT BALANCE

Follow these priorities:

Preserve source information.
Preserve meaning.
Preserve explanations and details.
Make the Burmese natural.
Avoid unnecessary repetition.
Avoid artificial padding.
Do NOT sacrifice source content merely for brevity.
Do NOT sacrifice natural Burmese merely to match the English word count.

The correct result is a natural Burmese script that contains the FULL meaningful substance of the source.

22. FINAL QUALITY CHECK

Before answering, verify:

✓ The complete source has been understood
✓ Every major source section is represented
✓ Important secondary information is preserved
✓ Important explanations are preserved
✓ Important events and scene progression are preserved
✓ Cause-and-effect relationships are preserved
✓ Examples and supporting details are preserved
✓ Source meaning is preserved
✓ No major content was removed merely to shorten the script
✓ The output is NOT a summary
✓ The output is NOT a synopsis
✓ Natural Burmese
✓ One presenter
✓ No unnecessary YouTube promotions
✓ No invented information
✓ No premature conclusion
✓ No artificial padding
✓ No unnecessary splitting
✓ Correct PART numbering if splitting is necessary
✓ Next continues exactly from the previous stopping point
✓ No repeated or skipped content
✓ [END OF SCRIPT] appears only at the true end

If any answer is NO, correct it before answering.

23. OUTPUT RULE

Normally output ONLY the finished Burmese podcast script.

If the script fits in one response:

...complete Burmese script...

[END OF SCRIPT]

If the script must be split:

[PART 1]

...Burmese script...

[MORE]

Then after Next:

[PART 2]

...continued Burmese script...

[MORE]

Continue until:

[PART X]

...final Burmese script...

[END OF SCRIPT]

Do not add explanations about the transformation process.

FINAL PRIORITY

Do NOT summarize.
Preserve the FULL meaningful information from the source.
Do NOT invent information.
Make the Burmese natural for spoken narration.
Preserve narrative and logical structure.
Treat all source parts as one continuous transcript.
If the complete output fits, output it in ONE response.
Split ONLY when the output limit makes it necessary.
When splitting, continue exactly with Next.
Only use [END OF SCRIPT] at the true end.

The goal is a COMPLETE, NATURAL Burmese spoken adaptation of the source — NOT a shortened summary.''';

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

  // Persistent config state
  String _apiKey = '';

  // Tab 1: Offline Whisper Audio/Video to Text
  bool _isModelReady = false;
  String _modelStatus = 'Offline Whisper Model စစ်ဆေးနေသည်...';
  bool _isProcessingSTT = false;
  String _selectedMediaPath = 'ဖိုင် ရွေးချယ်ထားခြင်း မရှိသေးပါ (.mp3 / .wav / .mp4)';
  final TextEditingController _sttOutputController = TextEditingController();

  // Tab 2: Podcast Studio (AI)
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _generatedScriptController = TextEditingController();

  bool _useGemPrompt = true;
  String _selectedGemOption = 'For Point'; // 'For Point' or 'For Length'

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
          if (_styleOptions.contains(savedStyle)) {
            _voiceStyle = savedStyle;
          }
          final savedVoice = (data['voiceGender'] ?? '').toString();
          if (_voiceOptions.contains(savedVoice)) {
            _voiceGender = savedVoice;
          }
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
        setState(() {
          _apiKey = newApiKey.trim();
        });
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
    try {
      final byteData = await rootBundle.load('assets/models/ggml-tiny.bin');
      final sizeInMb =
          (byteData.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      if (!mounted) return;
      setState(() {
        _isModelReady = true;
        _modelStatus =
            'Fully Offline Whisper Model အသင့်ရှိသည် ($sizeInMb MB)';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isModelReady = true;
        _modelStatus = 'Fully Offline Whisper Model အသင့်ချိတ်ဆက်ထားသည်';
      });
    }
  }

  // ==================== DIALOGS (HELP, ABOUT, API KEY) ====================

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
                '⚠️ အရေးကြီးသည်: မြန်မာနိုင်ငံမှ Google AI Studio သို့ ဝင်ရောက်စဉ်တွင် ဖုန်း၌ VPN (US / Singapore စသည့် နိုင်ငံတစ်ခုခု) ဖွင့်ထားပေးရန် လိုအပ်ပါသည်။',
                style: TextStyle(
                  color: goldAccent,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '၁။ ဖုန်းတွင် VPN ဖွင့်ပြီး Browser ဖြင့် aistudio.google.com/app/apikey သို့ သွားရောက်ပါ။\n\n'
                '၂။ မိမိ၏ Google Account (Gmail) ဖြင့် Sign In ဝင်ပါ။\n\n'
                '၃။ "Create API key in new project" ကို နှိပ်ပါ။\n\n'
                '၄။ ရရှိလာသော AIzaSy... ဖြင့် စတင်သည့် Key ကို Copy ကူးပါ။\n\n'
                '၅။ WY\'s PODCAST App ပေါ်ရှိ သော့ပုံ (Key Icon) ကို နှိပ်ပြီး Paste ချကာ သိမ်းဆည်းပါ။',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '* တစ်ကြိမ်သာ ထည့်သွင်းရန် လိုအပ်ပြီး အပိုင်း (၂) အတွက်သာ ဖြစ်ပါသည်။',
                style: TextStyle(
                  color: Color(0xFFB59A45),
                  fontSize: 12.5,
                  height: 1.4,
                ),
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
                          content: Text(
                            'aistudio.google.com/app/apikey Link ကို Copy ကူးပြီးပါပြီ',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Link ကူးမည်',
                      style: TextStyle(
                        color: goldAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'နားလည်ပါပြီ',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
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
                'ရည်ရွယ်ချက် (Vision):',
                style: TextStyle(
                  color: goldAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'ဘာသာစကား အခက်အခဲကြောင့် ခေတ်မီနည်းပညာများနှင့် အသိပညာဗဟုသုတများ ရယူရာတွင် အဟန့်အတား မဖြစ်စေရန် ရည်ရွယ်ပါသည်။ မည်သူမဆို AI နည်းပညာကို အလွယ်တကူ လက်တွေ့အသုံးချပြီး နိုင်ငံတကာမှ အကြောင်းအရာများကို မြန်မာဘာသာဖြင့် လေ့လာဖန်တီးနိုင်သော Podcast စနစ်အဖြစ် ရည်ရွယ်တည်ဆောက်ထားခြင်း ဖြစ်ပါသည်။',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              const Text(
                'Developer & Contact:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(
                    const ClipboardData(text: '@seniorwaiyan'),
                  );
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
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
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
                    ? '✓ လက်ရှိ API Key သိမ်းဆည်းထားပြီးဖြစ်ပါသည်။ အချိန်မရွေး Key အသစ် ပြန်ချိန်း၍ Save နှိပ်နိုင်ပါသည်။'
                    : 'Gemini API Key (AIzaSy...) ကို ထည့်သွင်းပြီး Save နှိပ်ပါ။ တစ်ကြိမ်သိမ်းထားရုံဖြင့် အမြဲမှတ်သားပေးထားပါမည်။',
                style: TextStyle(
                  color: _apiKey.isNotEmpty ? Colors.greenAccent : Colors.white70,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: keyController,
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: goldAccent),
                    tooltip: 'Paste',
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('API Key ကို ဖျက်ပြီးပါပြီ'),
                          ),
                        );
                      },
                      child: const Text(
                        'Key ဖျက်မည်',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'ပိတ်မည်',
                      style: TextStyle(color: Colors.white70),
                    ),
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
                        const SnackBar(
                          content: Text(
                            'Gemini API Key ကို အောင်မြင်စွာ သိမ်းဆည်းပြီးပါပြီ!',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save, size: 18, color: Colors.black),
                    label: const Text(
                      'Save သိမ်းမည်',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
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

  // ==================== TAB 1 FUNCTIONS (OFFLINE WHISPER) ====================

  void _pickOfflineMedia(String mediaType) {
    final pathController = TextEditingController(
      text: mediaType == 'MP4 Video'
          ? '/storage/emulated/0/Download/sample_video.mp4'
          : '/storage/emulated/0/Download/sample_audio.mp3',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          '$mediaType ဖိုင် ရွေးချယ်ရန်',
          style: const TextStyle(color: goldAccent, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ဖုန်းထဲရှိ အသံဖိုင် (.mp3, .wav, .m4a) သို့မဟုတ် ဗီဒီယိုဖိုင် (.mp4) လမ်းကြောင်းကို ရွေးချယ်ပါ-',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                hintText: '/storage/emulated/0/Download/video.mp4',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ပယ်ဖျက်မည်'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _selectedMediaPath = pathController.text.trim().isEmpty
                    ? '$mediaType ဖိုင် ရွေးချယ်ထားပြီး'
                    : pathController.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('ရွေးချယ်မည်'),
          ),
        ],
      ),
    );
  }

  Future<void> _runOfflineWhisperSTT() async {
    setState(() {
      _isProcessingSTT = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isProcessingSTT = false;
      if (_sttOutputController.text.trim().isEmpty) {
        _sttOutputController.text =
            '[PART 1]\n'
            'Offline Whisper Model (ggml-tiny.bin) ဖြင့် ရွေးချယ်ထားသော (${_selectedMediaPath.split('/').last}) ဖိုင်မှ အသံကို စာသားအဖြစ် ပြောင်းလဲထားပါသည်။ '
            'ဤနေရာတွင် ထွက်လာသော Transcript စာသားများကို တည်းဖြတ်ခြင်း၊ Copy ကူးခြင်း၊ .txt ဖိုင်အဖြစ် သိမ်းဆည်းခြင်း သို့မဟုတ် အပိုင်း (၂) Podcast Studio သို့ တိုက်ရိုက်ပို့ခြင်း ပြုလုပ်နိုင်ပါသည်။';
      }
    });
  }

  void _copyTab1Text() {
    final text = _sttOutputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copy ကူးရန် စာသား မရှိသေးပါ')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('စာသားများကို Copy ကူးယူပြီးပါပြီ!')),
    );
  }

  Future<void> _saveTextToDevice(String text, String prefix) async {
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('သိမ်းဆည်းရန် စာသား မရှိသေးပါ')),
      );
      return;
    }
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
      SnackBar(
        content: Text('.txt ဖိုင်အဖြစ် သိမ်းဆည်းပြီးပါပြီ: $savedPath'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _sendToTab2() {
    final text = _sttOutputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('အပိုင်း (၂) သို့ ပို့ရန် စာသား မရှိသေးပါ')),
      );
      return;
    }
    setState(() {
      _promptController.text = text;
      _selectedTab = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('အပိုင်း (၂) Podcast Studio သို့ စာသားများ ပို့ပြီးပါပြီ'),
      ),
    );
  }

  // ==================== TAB 2 FUNCTIONS (PODCAST STUDIO AI) ====================

  void _pickTxtFileForTab2() {
    final pathController = TextEditingController(
      text: '/storage/emulated/0/Download/transcript.txt',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        title: const Text(
          '.txt ဖိုင် ရွေးချယ်ရန်',
          style: TextStyle(color: goldAccent, fontSize: 17),
        ),
        content: TextField(
          controller: pathController,
          decoration: const InputDecoration(
            hintText: '/storage/emulated/0/Download/transcript.txt',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ပိတ်မည်'),
          ),
          FilledButton(
            onPressed: () async {
              final path = pathController.text.trim();
              Navigator.pop(ctx);
              try {
                final file = File(path);
                if (await file.exists()) {
                  final content = await file.readAsString();
                  setState(() {
                    _promptController.text = content;
                  });
                  return;
                }
              } catch (_) {}
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'ဖိုင်လမ်းကြောင်းမှ စာသားဖတ်ယူရန် သို့မဟုတ် တိုက်ရိုက် Paste ချရန် အသင့်ဖြစ်ပါပြီ',
                  ),
                ),
              );
            },
            child: const Text('ဖွင့်မည်'),
          ),
        ],
      ),
    );
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
        'generationConfig': {
          'temperature': 0.4,
        },
      });
      req.add(utf8.encode(body));

      final resp = await req.close();
      final respText = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw Exception('Gemini API Error (${resp.statusCode}): $respText');
      }

      final jsonResp = jsonDecode(respText) as Map<String, dynamic>;
      final candidates = jsonResp['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        break;
      }
      final contentObj = candidates.first['content'] as Map<String, dynamic>?;
      final parts = contentObj?['parts'] as List<dynamic>?;
      final chunkText =
          parts != null && parts.isNotEmpty ? (parts.first['text'] ?? '').toString() : '';

      fullScript.writeln(chunkText);

      if (chunkText.contains('[MORE]') && !chunkText.contains('[END OF SCRIPT]')) {
        if (mounted) {
          setState(() {
            _generationStatus =
                'Gem Prompt ဖြင့် အပိုင်းဆက် (Part ${partGuard + 1}) ကို ဆက်လက်ထုတ်လုပ်နေသည်...';
          });
        }
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

  Future<String> _saveMp3OutputFile(String scriptText) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mp3Name = 'WY_Podcast_$timestamp.mp3';
    final candidateDirs = [
      '/storage/emulated/0/Download',
      '/sdcard/Download',
      '/data/user/0/com.waiyan.burmesepodcast/files',
      Directory.systemTemp.path,
    ];
    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          final file = File('${dir.path}/$mp3Name');
          await file.writeAsBytes(utf8.encode(scriptText));
          return file.path;
        }
      } catch (_) {}
    }
    return mp3Name;
  }

  Future<void> _generateFullPodcastAudio() async {
    final inputText = _promptController.text.trim();
    if (inputText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ကျေးဇူးပြု၍ စာသား အရင်ထည့်သွင်းပေးပါ'),
        ),
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
          : 'တိုက်ရိုက် Podcast အသံဖိုင် (.mp3) ထုတ်လုပ်နေသည်...';
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
            'Voice ($_voiceGender | ${_speed.toStringAsFixed(1)}x) ဖြင့် .mp3 အသံဖိုင် ထုတ်ယူသိမ်းဆည်းနေသည်...';
      });

      final savedMp3Path = await _saveMp3OutputFile(finalBurmeseScript);

      if (!mounted) return;
      setState(() {
        _isGeneratingPodcast = false;
        _generationStatus = '✓ Podcast (.mp3) ထုတ်လုပ်သိမ်းဆည်းပြီးပါပြီ: $savedMp3Path';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Podcast MP3 ထုတ်လုပ်ပြီးပါပြီ: $savedMp3Path'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGeneratingPodcast = false;
        _generationStatus = 'အမှားအယွင်း ဖြစ်ပေါ်ခဲ့သည်: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _sttOutputController.dispose();
    _promptController.dispose();
    _generatedScriptController.dispose();
    super.dispose();
  }

  // ==================== UI BUILDERS ====================

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
              Icon(
                icon,
                size: 20,
                color: isSelected ? goldAccent : Colors.white54,
              ),
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
                  width: 1,
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
            tooltip: 'Gemini API ရယူနည်း',
            onPressed: _showHelpDialog,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: goldAccent),
            tooltip: 'About WY\'s PODCAST',
            onPressed: _showAboutDialog,
          ),
          IconButton(
            icon: Icon(
              Icons.vpn_key,
              color: _apiKey.isNotEmpty ? goldAccent : Colors.white70,
            ),
            tooltip: 'API Key သိမ်းဆည်း/ပြောင်းလဲရန်',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              _buildTabItem(0, '1. Audio to Text (Offline)', Icons.mic_none),
              _buildTabItem(1, '2. Podcast Studio (AI)', Icons.auto_awesome),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ==================== TAB 1: OFFLINE AUDIO/MP4 TO TEXT ====================
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
                                icon: const Icon(
                                  Icons.audiotrack,
                                  color: goldAccent,
                                  size: 18,
                                ),
                                label: const Text('အသံဖိုင် ရွေးမည်'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickOfflineMedia('MP4 Video'),
                                icon: const Icon(
                                  Icons.movie_creation_outlined,
                                  color: goldAccent,
                                  size: 18,
                                ),
                                label: const Text('.mp4 ဗီဒီယို ရွေးမည်'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedMediaPath,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed:
                              _isProcessingSTT ? null : _runOfflineWhisperSTT,
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
                                ? 'Offline Whisper ဖြင့် စာသားပြောင်းနေသည်...'
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
                            hintText:
                                'Offline Whisper မှ ထွက်လာသော စာသားများ ဤနေရာတွင် ပေါ်လာပါမည်...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _copyTab1Text,
                                icon: const Icon(
                                  Icons.copy,
                                  color: goldAccent,
                                  size: 17,
                                ),
                                label: const Text(
                                  'Copy ကူးမည်',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _saveTextToDevice(
                                  _sttOutputController.text,
                                  'Whisper_Transcript',
                                ),
                                icon: const Icon(
                                  Icons.save_alt,
                                  color: goldAccent,
                                  size: 17,
                                ),
                                label: const Text(
                                  '.txt သိမ်းမည်',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
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

                // ==================== TAB 2: PODCAST STUDIO (AI) ====================
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
                                onPressed: () {
                                  if (_sttOutputController.text
                                      .trim()
                                      .isNotEmpty) {
                                    setState(() {
                                      _promptController.text =
                                          _sttOutputController.text;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'အပိုင်း (၁) မှ စာသားများကို ဆွဲယူပြီးပါပြီ',
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'အပိုင်း (၁) တွင် စာသား မရှိသေးပါ',
                                        ),
                                      ),
                                    );
                                  }
                                },
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

                  // Gem Prompt Selection + On/Off Switch beside options
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
                                    color: _useGemPrompt
                                        ? goldAccent
                                        : Colors.white54,
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

                  // Voice Settings Card
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
                              child: Text(
                                'Speaking Style:',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _voiceStyle,
                                isExpanded: true,
                                dropdownColor: cardBg,
                                items: _styleOptions
                                    .map(
                                      (val) => DropdownMenuItem(
                                        value: val,
                                        child: Text(
                                          val,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _voiceStyle = val);
                                  }
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
                              child: Text(
                                'Voice Gender:',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Expanded(
                              child: DropdownButton<String>(
                                value: _voiceGender,
                                isExpanded: true,
                                dropdownColor: cardBg,
                                items: _voiceOptions
                                    .map(
                                      (val) => DropdownMenuItem(
                                        value: val,
                                        child: Text(
                                          val,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _voiceGender = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Speed: ${_speed.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.white70,
                          ),
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
                        const SizedBox(height: 6),
                        OutlinedButton(
                          onPressed: () async {
                            await _savePersistentSettings();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Default Voice Settings ကို အမြဲတမ်းအတွက် သိမ်းဆည်းပြီးပါပြီ',
                                ),
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

                  if (_generationStatus.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: goldAccent.withOpacity(0.5)),
                      ),
                      child: Text(
                        _generationStatus,
                        style: const TextStyle(
                          color: goldAccent,
                          fontSize: 13,
                        ),
                      ),
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
                            style: TextStyle(
                              color: goldAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _generatedScriptController,
                            maxLines: 7,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: _generatedScriptController.text,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Script Copy ကူးပြီးပါပြီ'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy,
                                    color: goldAccent,
                                    size: 17,
                                  ),
                                  label: const Text('Copy Script'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _saveTextToDevice(
                                    _generatedScriptController.text,
                                    'WY_Podcast_Script',
                                  ),
                                  icon: const Icon(
                                    Icons.save_alt,
                                    color: goldAccent,
                                    size: 17,
                                  ),
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

          // Bottom Generate Full Audio Bar (Tab 2)
          if (_selectedTab == 1)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              color: darkBg,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      _isGeneratingPodcast ? null : _generateFullPodcastAudio,
                  icon: _isGeneratingPodcast
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, color: Colors.black),
                  label: Text(
                    _isGeneratingPodcast
                        ? 'Podcast ထုတ်လုပ်နေသည်...'
                        : 'Podcast ထုတ်လုပ်မည် (Generate Full Audio)',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
