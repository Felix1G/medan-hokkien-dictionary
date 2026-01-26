import 'dart:collection';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:medan_hokkien_dictionary/dictionary.dart';
import 'package:medan_hokkien_dictionary/style.dart';
import 'package:medan_hokkien_dictionary/util.dart';
import 'package:medan_hokkien_dictionary/page.dart' deferred as heavy;

List<Entry> kEntries = List.empty(growable: true);
List<EntryWidgets> kEntriesWidget = List.empty(growable: true);
HashMap<String, List<int>> kEntriesCharacter = HashMap();
const kEntriesAmount = 2140;
final ValueNotifier<int> kPageIndexNotif = ValueNotifier<int>(0);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      builder: (context, child) {
        return Container(
          color: kBackgroundColor,
          child: child,
        );
      },
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
  bool changePage = false;

  double progress = 0.0;
  String progressText = "Initialising..."; // shown under the progress percentage

  late final StatefulWidget dictPage;
  late final StatefulWidget fullListPage;

  void getAllEntries() async {
    // split the dictionary text by lines
    setState(() => progressText = "Loading dictionary...");
    String dictionaryText = await loadDictionary();
    final dictionarySections = dictionaryText.split("\n");
    dictionarySections.add("="); // allows the last entry to be added in the while loop 
    final sections = dictionarySections.length;

    // buffer to store individual entry info
    List<String> buffer = List.empty(growable: true);

    // loop through each line
    setState(() => progressText = "Compiling dictionary...");
    var index = 0;
    final entryHashList = HashSet<int>(); // call out double entries
    while (index < sections) {
      final section = dictionarySections[index];
      if (section.isNotEmpty && charAtUni(section, 0) == '=') { // entries always start with '='
        // parse and add the PREVIOUS entry
        Entry? entry = parseEntry(buffer);
        if (entry != null) {
          int entryHash = obtainHanziPOJHash(entry);
          if (entryHashList.contains(entryHash)) {
            if (kDebugMode) {
              debugPrint("WARNING: the entry '${entry.hanzi.join("/")}:${entry.poj.join("/")}' has a duplicate.");
            }
          } else {    
            // update progress bar
            setState(() {
              progress += 1.0 / (kEntriesAmount + 1);
            });

            kEntries.add(entry);
            entryHashList.add(entryHash);
          }
        }
        
        buffer.clear();
      }

      buffer.add(section);
      
      index++;
    }

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
      if (entry.hanzi.isNotEmpty) {
        for (final hanzi in entry.hanzi) {
          if (hanzi.characters.length == 1) { // size of 1 = individual character
            if (kEntriesCharacter.containsKey(hanzi)) {
              kEntriesCharacter[hanzi]?.add(entryIndex);
            } else {
              kEntriesCharacter[hanzi] = [entryIndex];
            }
          }
        }
      }
      entryIndex++;
    }

    if (kDebugMode) {
      final polyphonics = "一倒分吹彎種曾葉變開黃霧臭下莫才發落相插空膽膏教"; // these characters are allowed to have their polyphonics (多音字) e.g. surname
      final polyphonicsList = List.empty(growable: true);
      for (final char in polyphonics.characters) {
        polyphonicsList.add(char);
      }

      for (final entryL in kEntriesCharacter.entries) {
        if (!polyphonicsList.contains(entryL.key) && entryL.value.length > 1) {
          debugPrint("More than one entries for the character '${entryL.key}'.");
        }
      }
    }

    progress += 1.0 / (kEntriesAmount + 1); //update progress bar
    
    // REDIRECT TO DICTIONARY PAGE
    setState(() => progressText = "Redirecting...");
    await Future.delayed(const Duration(milliseconds: 750));

    await heavy.loadLibrary();

    if (!mounted) return;

    setState(() {
      for (int idx = 0; idx < kEntries.length; idx++) {
        kEntriesWidget.add(EntryWidgets(context, EntryData(index: idx)));
      }

      dictPage = heavy.DictionaryPage(title: 'Dictionary Page');
      fullListPage = heavy.FullListPage();
      
      changePage = true;
    });
  }

  @override
  void initState() {
    super.initState();
    
    setState(() => progressText = "Initialising dictionary...");
    initDictionary();
    
    getAllEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: changePage ?
        ValueListenableBuilder<int>(
          valueListenable: kPageIndexNotif,
            builder: (context, index, _) {
              return IndexedStack(
                index: index,
                children: [
                  dictPage,
                  fullListPage
                ]
              );
            }
         ) :
        Center(
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

              const SizedBox(height: 50),

              // INFORMATION TEXTS
              Text(
                'Loading Dictionary: ${(progress * 100).toStringAsFixed(1)}%',
                style: kUITextStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 50),
              Text(
                progressText, style: kUITextStyle.copyWith(color: Colors.white, fontWeight: FontWeight.bold)
              ),
            ],
          ),
        )
    );
  }
}
