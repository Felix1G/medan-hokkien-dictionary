import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medan_hokkien_dictionary/main.dart';
import 'package:medan_hokkien_dictionary/style.dart';
import 'package:medan_hokkien_dictionary/util.dart';

class DictionaryPage extends StatefulWidget {
  const DictionaryPage({super.key, required this.title});

  final String title;

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
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
        if (isEnglish) {
          if (prevInput.isNotEmpty && input.contains(prevInput)) {
            var idx = 0;
            while (idx < dictEntries.length) {
              final entry = dictEntries[idx];

              int score = 1000000000;
              for (final keyword in entry.entry.defSearchUp) {
                int strIdx = keyword.indexOf(input);
                if (strIdx == -1) continue;

                int newScore = 0;
                int bef = strIdx;
                int aft = strIdx + input.length;

                while (bef - 1 >= 0 && !" ()[]{}".contains(keyword[bef - 1])) {
                  newScore += 200;
                  bef--;
                }

                if (bef - 1 >= 0 && "()[]{}".contains(keyword[bef - 1])) bef = 0;

                while (aft < keyword.length && !" ()".contains(keyword[aft])) {
                  newScore += 80;
                  aft++;
                }
                
                if (aft < keyword.length && "()[]{}".contains(keyword[aft])) aft = 0;

                newScore += (bef + (keyword.length - aft)) * 4 + entry.entry.definitionsDisplay.length;
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
            dictEntries.clear();

            var index = 0;
            while (index < kEntries.length) {
              final entry = kEntries[index];
              int score = 1000000000;
              for (final keyword in entry.defSearchUp) {
                int strIdx = keyword.indexOf(input);
                if (strIdx == -1) continue;

                int newScore = 0;
                int bef = strIdx;
                int aft = strIdx + input.length;

                while (bef - 1 >= 0 && !" ()[]{}".contains(keyword[bef - 1])) {
                  newScore += 200;
                  bef--;
                }

                if (bef - 1 >= 0 && "()[]{}".contains(keyword[bef - 1])) bef = 0;

                while (aft < keyword.length && !" ()".contains(keyword[aft])) {
                  newScore += 80;
                  aft++;
                }
                
                if (aft < keyword.length && "()[]{}".contains(keyword[aft])) aft = 0;

                newScore += (bef + (keyword.length - aft)) * 4 + entry.definitionsDisplay.length;
                score = minInt(newScore, score);
              }

              if (score != 1000000000) {
                final data = EntryData(index: index);
                data.score = score;
                dictEntries.add(data);
              }

              index++;
            }
          }
        } else {
          dictEntries.clear();

          input = input.replaceAll('-', ' '); // ignore the dashes for searching

          List<SearchToken> tokens = List.empty(growable: true);

          // compute tokens
          final buffer = StringBuffer();
          for (final char in input.characters) {
            // whitespace separates POJ words
            if (char == ' ' && buffer.isNotEmpty) {
              tokens.add(SearchToken(content: buffer.toString(), isHanzi: false));
              buffer.clear();
              continue;
            }

            if (isStrHanzi(char)) {
              // there is a POJ word
              if (buffer.isNotEmpty) {
                tokens.add(SearchToken(content: buffer.toString(), isHanzi: false));
                buffer.clear();
              }

              // every hanzi token is only one i.e. the hanzi itself
              tokens.add(SearchToken(content: char, isHanzi: true));
            } else if (char != ' ') {
              buffer.write(char); // write POJ
            }
          }

          if (buffer.isNotEmpty) { //remaining POJ word in the end of the search input
            tokens.add(SearchToken(content: buffer.toString(), isHanzi: false));
          }
          
          // remove unnecessary POJ (...[hanzi] [POJ]... | if POJ == hanzi then remove POJ)
          if (tokens.length > 1) {
            var index = 1; // 2-index window
            while (index < tokens.length) {
              if (!tokens[index].isHanzi && tokens[index - 1].isHanzi) { // check for hanzi POJ arrangement
                int? entryIndex = kEntriesCharacter[tokens[index-1].content];
                if (entryIndex != null) { // entry for character exists
                  final poj = tokens[index].content;
                  if (kEntries[entryIndex].chineseSearchUp.any((wordList) => wordList.any((word) => poj == word))) { // check for POJ match
                    tokens.removeAt(index);
                    continue;
                  }
                }
              }
              index++;
            }
          }
          
          // search for relevant entries (since words are short, brute force method is used)
          var entryIndex = 0;
          final tokenLength = tokens.length;
          while (entryIndex < kEntries.length) {
            final entry = kEntries[entryIndex];
            final entryLength = entry.chineseSearchUp.length;

            // amount of tokens is more than the length of the word
            if (tokenLength > entryLength) {
              entryIndex++;
              continue;
            }

            var searchUpIndex = 0;
            var fail = true;
            chineseSearchUpLoop:
            while (searchUpIndex <= entryLength - tokenLength) {
              var tokenIdx = 0;
              for (final token in tokens) {
                // token does not match
                if (!entry.chineseSearchUp.any((wordList) => wordList.any((word) => word.contains(token.content)))) break;

                tokenIdx++;
                if (tokenIdx == tokenLength) { // the entire token list is exhausted, match found
                  fail = false;
                  break chineseSearchUpLoop;
                }
              }
              searchUpIndex++;
            }

            // no match
            if (fail) {
              entryIndex++;
              continue;
            }

            final entryData = EntryData(index: entryIndex);
            entryData.score = 2 * searchUpIndex + (entryLength - (searchUpIndex + tokenLength));
            dictEntries.add(entryData);

            entryIndex++;
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
                      entry.hanziDisplay.isEmpty ? SizedBox() : ColoredText(
                        text: entry.hanziDisplay,
                        colors: entry.pojToneColours,
                        style: kCJKTextStyle.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(30.0))
                      ),
                      entry.hanziDisplay.isEmpty ? SizedBox() : SizedBox(width: 10),
                      Text(entry.pojDisplay, style: kCJKTextStyle.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(20.0)))
                    ]),
                    SizedBox(height: 10.0),
                    Text(entry.definitionsDisplay, style: kCJKTextStyle.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(17.5)))
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