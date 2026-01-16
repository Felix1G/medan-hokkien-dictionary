import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medan_hokkien_dictionary/dictionary.dart';
import 'package:medan_hokkien_dictionary/main.dart';
import 'package:medan_hokkien_dictionary/style.dart';
import 'package:medan_hokkien_dictionary/util.dart';

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key, required this.title});

  final String title;

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class EntryData {
  final int index;
  int score = 0;
  Entry get entry => kEntries[index];

  EntryData({required this.index});

  
}

class _DictionaryPageState extends State<DictionaryPage> {
  bool isEnglish = true;
  bool showCenterText = true;
  final TextEditingController searchController = TextEditingController();
  String prevInput = "";

  List<EntryData> dictEntries = List.empty(growable: true);
  Timer? _debounce;

  void onChangedLang() {
    String input = prevInput;
    prevInput = "";
    onChangedText(input, 10);
  }

  void onChangedText(String text, [int debounceTime = 300]) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: debounceTime), () {
      String input = text.toLowerCase().trim();

      if (input.isEmpty) {
        dictEntries.clear();
      } else {
        if (prevInput.isNotEmpty && input.contains(prevInput)) {
          if (isEnglish) {
            var idx = 0;
            while (idx < dictEntries.length) {
              final entry = dictEntries[idx];

              int score = 1000000000;
              for (final keyword in entry.entry.searchUp) {
                int strIdx = keyword.indexOf(input);
                if (strIdx == -1) continue;

                int newScore = 0;
                int bef = strIdx;
                int aft = strIdx + input.length;

                while (bef - 1 >= 0 && !" ()".contains(keyword[bef - 1])) {
                  newScore += 50;
                  bef--;
                }

                while (aft < keyword.length && !" ()".contains(keyword[aft])) {
                  newScore += 20;
                  aft++;
                }

                newScore += (bef + (keyword.length - aft)) * 2;
                score = minInt(newScore, score);
              }

              if (score == 1000000000) {
                dictEntries.removeAt(idx);
                continue;
              } else {
                dictEntries[idx].score = score;
              }

              idx++;
            }
          } else {
            
          }
        } else {
          dictEntries.clear();
          
          if (isEnglish) {
            var index = 0;
            while (index < kEntries.length) {
              final entry = kEntries[index];
              int score = 1000000000;
              for (final keyword in entry.searchUp) {
                int strIdx = keyword.indexOf(input);
                if (strIdx == -1) continue;

                int newScore = 0;
                int bef = strIdx;
                int aft = strIdx + input.length;

                while (bef - 1 >= 0 && !" ()".contains(keyword[bef - 1])) {
                  newScore += 50;
                  bef--;
                }

                while (aft < keyword.length && !" ()".contains(keyword[aft])) {
                  newScore += 20;
                  aft++;
                }

                newScore += (bef + (keyword.length - aft)) * 2;
                score = minInt(newScore, score);
              }

              if (score != 1000000000) {
                final data = EntryData(index: index);
                data.score = score;
                dictEntries.add(data);
              }

              index++;
            }

          } else {

          }
        }
      }
      
      dictEntries.sort((a, b) => a.score.compareTo(b.score));

      setState(() {
        showCenterText = input.isEmpty;
      });

      prevInput = input;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 3.5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red.shade900
            ),
          ),

          // TOP BAR
          Container(
            height: 60.0,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // SEARCH BAR
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 100,
                    height: 40.0,
                    child: TopSearchBanner(isEnglish: isEnglish, searchController: searchController, onChangedText: onChangedText)
                  ),
                  Padding(padding: EdgeInsetsGeometry.all(10)),
                  // CHINESE/ENGLISH TOGGLE BUTTON
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: ToggleLangIcon(
                      isEnglish: isEnglish,
                      onToggle: () {
                        setState(() {
                          isEnglish = !isEnglish;
                          onChangedLang();
                        });
                      },
                    )
                  )
                ])
              ],
            )
          ),
          showCenterText ? Expanded(
            child: Center(
              child: Container(
                padding: EdgeInsets.all(20.0),
                child: Text('Welcome to the Medan Hokkien dictionary.\nCurrently, there are ${kEntries.length} entries.\n\nTap the icon on the top right to toggle between English and Chinese/POJ search.',
                  style: GoogleFonts.notoSans().copyWith(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ) : Expanded(child: ListView.builder(
            itemCount: dictEntries.length,
            itemBuilder: (context, index) {
              final entry = dictEntries[index].entry;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 7.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      entry.hanziDisplay.isEmpty ? SizedBox() : Text(entry.hanziDisplay,
                        style: kCJKTextStyle.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(30.0))),
                      entry.hanziDisplay.isEmpty ? SizedBox() : SizedBox(width: 10),
                      Text(entry.pojDisplay, style: kCJKTextStyle.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(20.0)))
                    ]),
                    Text(entry.definitionsDisplay, style: kCJKTextStyle.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(20.0)))
                  ]
                )
              );
            }
          ))
        ],
      )
    );
  }
}

class TopSearchBanner extends StatelessWidget {
  final TextEditingController searchController;
  final bool isEnglish;
  final void Function(String) onChangedText;
  
  const TopSearchBanner({
    super.key,
    required this.isEnglish,
    required this.searchController,
    required this.onChangedText
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
          ),
        ),

        Material(
          color: Colors.transparent,
          elevation: 0,
          borderRadius: BorderRadius.circular(16),
          child: TextField(
            key: ValueKey(isEnglish),
            controller: searchController,
            style: TextStyle(
              color: Colors.white,
              fontFamily: GoogleFonts.notoSans().fontFamily!,
              fontWeight: FontWeight.bold,
              fontSize: minDouble(0.1 * MediaQuery.of(context).size.width, 13) // Search bar text font size
            ),
            onChanged: onChangedText,
            decoration: InputDecoration(
              hintText: isEnglish ? "Search in English..." : "Search in Chinese or POJ...",
              hintStyle: const TextStyle(
                color: Colors.white,
              ),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.cyan),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ToggleLangIcon extends StatelessWidget {
  final bool isEnglish;
  final VoidCallback onToggle;

  const ToggleLangIcon({
    super.key,
    required this.isEnglish,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(5))
          ),
          child: Text(
            isEnglish ? 'E' : 'C',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      )
    );
  }
}