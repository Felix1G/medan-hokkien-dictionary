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
const kEntriesAmount = 1689;

void main() {
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

  String progressText = "Initialising...";

  void getAllEntries() async {
    String dictionaryText = await loadDictionary();
    final dictionarySections = dictionaryText.split("\n");
    final sections = dictionarySections.length;

    List<String> buffer = List.empty(growable: true);

    var index = 0;
    while (index < sections) {
      final section = dictionarySections[index];
      if (section.isNotEmpty && charAtUni(section, 0) == '=') {
        Entry? entry = parseEntry(buffer);
        if (entry != null) kEntries.add(entry);

        setState(() {
          progress += 1.0 / (kEntriesAmount + 1);
        });
        
        buffer.clear();
      }

      buffer.add(section);
      
      index++;
    }
    
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

    progressText = "Finishing up...";

    var entryIndex = 0;
    for (final entry in kEntries) {
      if (entry.hanzi[0].characters.length == 1) {
        kEntriesCharacter[entry.hanzi[0]] = entryIndex;
      }
      entryIndex++;
    }

    progress += 1.0 / (kEntriesAmount + 1);
    
    await Future.delayed(const Duration(milliseconds: 750));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DictionaryPage(title: 'Dictionary Page')),
    );
  }

  @override
  void initState() {
    super.initState();

    GoogleFonts.getFont("Noto Sans SC");
    GoogleFonts.getFont("Noto Sans TC");
    
    progressText = "Loading dictionary...";
    initDictionary();
    
    progressText = "Compiling dictionary...";
    getAllEntries();
    
    progressText = "Loading fonts...";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
