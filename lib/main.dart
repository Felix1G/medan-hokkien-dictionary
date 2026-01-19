import 'dart:collection';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medan_hokkien_dictionary/dictionary.dart';
import 'package:medan_hokkien_dictionary/page.dart';
import 'package:medan_hokkien_dictionary/style.dart';
import 'package:medan_hokkien_dictionary/util.dart';

List<Entry> kEntries = List.empty(growable: true);
HashMap<String, int> kEntriesCharacter = HashMap();
const kEntriesAmount = 1733;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    // Crash immediately in debug
    if (kDebugMode) {
      assert(false);
    }
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medan Hokkien Dictionary',
      theme: kAppTheme,
      home: const LoadingPage(title: 'Loading Page'),
    );
  }
}

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key, required this.title});

  final String title;

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  double progress = 0.0;
  String progressText = "Initialising..."; // shown under the progress percentage

  void getAllEntries() async {
    // split the dictionary text by lines
    setState(() => progressText = "Loading dictionary...");
    String dictionaryText = await loadDictionary();
    final dictionarySections = dictionaryText.split("\n");
    final sections = dictionarySections.length;

    // buffer to store individual entry info
    List<String> buffer = List.empty(growable: true);

    // loop through each line
    setState(() => progressText = "Compiling dictionary...");
    var index = 0;
    while (index < sections) {
      final section = dictionarySections[index];
      if (section.isNotEmpty && charAtUni(section, 0) == '=') { // entries always start with '='
        // parse and add the PREVIOUS entry
        Entry? entry = parseEntry(buffer);
        if (entry != null) kEntries.add(entry);

        // update progress bar
        setState(() {
          progress += 1.0 / (kEntriesAmount + 1);
        });
        
        buffer.clear();
      }

      buffer.add(section);
      
      index++;
    }
    
    // parse and add the last entry
    Entry? entry = parseEntry(buffer);
    if (entry != null) kEntries.add(entry);

    if (kDebugMode) {
      // final explainEntries = List<Entry>.empty(growable: true);
      // for (final entry in kEntries) {
      //   var ok = false;
      //   topLoop: for (final def in entry.definitions) {
      //     for (final cat in def.categories) {
      //       if (cat == Category.explanation) {
      //         ok = true;
      //         break topLoop;
      //       }
      //     }
      //   }

      //   if (ok) explainEntries.add(entry);
      // }
      // print(explainEntries.join("\n"));
      // print(kEntries.join('\n'));
    }

    setState(() => progressText = "Finishing up...");

    // mapping individual characters to entries
    var entryIndex = 0;
    for (final entry in kEntries) {
      if (entry.hanzi[0].characters.length == 1) { // size of 1 = individual character
        kEntriesCharacter[entry.hanzi[0]] = entryIndex;
      }
      entryIndex++;
    }

    progress += 1.0 / (kEntriesAmount + 1); //update progress bar
    
    // REDIRECT TO DICTIONARY PAGE
    setState(() => progressText = "Redirecting...");
    await Future.delayed(const Duration(milliseconds: 750));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DictionaryPage(title: 'Dictionary Page')),
    );
  }

  @override
  void initState() {
    super.initState();

    // load the first fonts
    GoogleFonts.getFont("Noto Sans SC");
    GoogleFonts.getFont("Noto Sans TC");
    
    setState(() => progressText = "Initialising dictionary...");
    initDictionary();
    
    getAllEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // PROGRESS BAR
            SizedBox(width: 0.6 * MediaQuery.of(context).size.width, child:
              LinearProgressIndicator(
                value: progress,
                minHeight: 50.0,
                borderRadius: BorderRadius.all(Radius.circular(20)),
                color: Colors.red,
                backgroundColor: const Color.fromARGB(255, 76, 18, 14),
              ),
            ),

            SizedBox(height: 50),

            // INFORMATION TEXTS
            Text(
              'Loading Dictionary: ${(progress * 100).toStringAsFixed(1)}%',
              style: kUITextStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
            ),
            SizedBox(height: 50),
            Text(
              progressText, style: kUITextStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      )
    );
  }
}
