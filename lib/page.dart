import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medan_hokkien_dictionary/entry.dart';
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
  bool inputEmpty = true;
  final searchController = TextEditingController();
  String prevInput = "";

  List<EntryData> dictEntries = List.empty(growable: true);
  Timer? _debounce;

  bool _isAdvancedOpen = false;
  
  final _entryNumTextController = TextEditingController();

  void onChangedLang() {
    String input = searchController.text;
    prevInput = "";
    onChangedText(input, 10); // instantly recompute list
  }

  // score depends on how exact the keyword is to the input
  // e.g. input is "rack", then in ascending score: 
  // rack, crack, uncrackable (since rack is most exact)
  // => the higher the score, the less prioritised is the entry
  // => unmatched prefixes carry more penalty than suffixes
  // => if the match is a tag, the penalty is fatal
  int getScoreEnglishInput(String keyword, String input) {
    final regex = RegExp(RegExp.escape(input));
    final allIndices = regex.allMatches(keyword).map((m) => m.start).toList();
    if (allIndices.isEmpty || allIndices.last == -1) return -1;

    int score = 1000000000000;

    for (final strIdx in allIndices) {
      int newScore = 0;
      int bef = strIdx - 1; // characters BEFore the input (index is less than strIdx)
      int aft = strIdx + input.length; // characters AFTer the input (index is more than strIdx)

      // penalty on unnecessary prefixes
      while (bef >= 0 && !" ()[]{}".contains(keyword[bef])) {
        if (keyword[bef] == "#") newScore += 100000;
        newScore += 500;
        bef--;
      }

      bef--;
      
      // penalty on extra words before
      while (bef >= 0 && !"()[]{}".contains(keyword[bef])) {
        // ignore tags
        var idx = bef;
        while (idx >= 0 && !"# ".contains(keyword[idx])) {
          idx--;
        }
        if (idx >= 0 && keyword[idx] == "#") break;

        newScore += 40;
        bef--;
      }

      // penalty on unnecessary suffixes
      while (aft < keyword.length && !" ()[]{}".contains(keyword[aft])) {
        if (keyword[aft] == "#") newScore += 100000;
        newScore += 200;
        aft++;
      }
      
      aft++;
      
      // penalty on extra words after
      while (aft < keyword.length && !"()[]{}".contains(keyword[aft])) {
        // ignore tags
        var idx = aft;
        while (idx < keyword.length && !"# ".contains(keyword[idx])) {
          idx++;
        }
        if (idx < keyword.length && keyword[idx] == "#") break;

        newScore += 20;
        aft++;
      }

      score = minInt(score, newScore);
    }

    return score;
  }

  void onChangedText(String text, [int debounceTime = 300]) {
    // debouncing (prevents processing for every single input)
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // check if text is empty, which instantly clears the search list
    if (text.isEmpty) {
      dictEntries.clear();

      setState(() {
        inputEmpty = true;
      });

      prevInput = "";
      return;
    }

    _debounce = Timer(Duration(milliseconds: debounceTime), () {
      String input = text.toLowerCase().trim(); // search is not case-sensitive
      
      dictEntries.clear();

      if (input.isNotEmpty) {
        if (isEnglish) {
          // loop through all available entries
          var index = 0;
          while (index < kEntries.length) {
            final entry = kEntries[index];

            // check for matched entries and assign a score
            int score = 1000000000000;
            for (final keyword in entry.defSearchUp) {
              int newScore = getScoreEnglishInput(keyword, input);
              if (newScore == -1) continue;
              newScore += entry.definitionsDisplay.length;
              score = minInt(newScore, score);
            }

            // entry has match (since score must change because of it)
            if (score != 1000000000000) {
              final data = EntryData(index: index);
              data.score = score;
              dictEntries.add(data);
            }

            index++;
          }
        } else {
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
            // search through the tokens in a 2-index window (index and index - 1)
            var index = 1;
            while (index < tokens.length) {
              if (!tokens[index].isHanzi && tokens[index - 1].isHanzi) { // check for [hanzi, POJ] arrangement
                final entries = kEntriesCharacter[tokens[index-1].content];
                if (entries != null) { // entry for character exists
                  final poj = tokens[index].content;
                  // check for POJ match
                  if (entries.any(
                      (entryIndex) => kEntries[entryIndex].chineseSearchUp.any(
                        (wordList) => wordList.any((word) => poj == word)
                      )
                    )) {
                    tokens.removeAt(index); // remove the unnecessary POJ
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

            // search begins at searchUpIndex to (searchUpIndex + token.length)
            // if there is a match with the possible hanzis or pojs, the entry is added
            var searchUpIndex = 0;
            var fail = true;
            var totalScore = 0; // total score for individual words
            chineseSearchUpLoop:
            while (searchUpIndex <= entryLength - tokenLength) {
              var tokenIdx = 0;
              for (final token in tokens) {
                // check for match
                final wordList = entry.chineseSearchUp[searchUpIndex + tokenIdx];
                var wordFail = true;
                var wordScore = 10000000;
                for (final word in wordList) { // go through each hanzi/poj
                  // POJ with tone ending are handled differently (e.g. a3 may miss pai3)
                  bool containNumber = !isStrHanzi(word) && !isStrHanzi(token.content) &&
                    word.contains(kAnyNumberRegex) && token.content.contains(kAnyNumberRegex);
                  var allowByNum = false;
                  if (containNumber) {
                    final wordList = splitAlphabetNumber(word);
                    final contentList = splitAlphabetNumber(token.content);
                    if (wordList.length >= 2 && contentList.length >= 2) {
                      final wordPOJ = wordList.first;
                      final wordTone = wordList[1];
                      final contentPOJ = contentList.first;
                      final contentTone = contentList[1];
                      
                      allowByNum = contentTone == wordTone && wordPOJ.contains(contentPOJ); // should only contain ASCII chars, no need runes
                    }
                  }

                  if (allowByNum || (!containNumber && stringContainsByRunes(word, token.content))) { // check for match
                    wordFail = false;

                    // calculate score for each word
                    if (token.isHanzi) {
                      wordScore = 0; // hanzi is always a score of 0
                    } else {
                      // similar to the english rule for scoring
                      final beginIdx = word.indexOf(token.content);
                      wordScore = minInt(wordScore, beginIdx - 1 + (word.length - (token.content.length + beginIdx)));
                    }
                  }
                }

                if (wordFail) break; // no match

                totalScore += wordScore; // add up the score

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

            // add the entry
            // scoring is similar to english rule
            final entryData = EntryData(index: entryIndex);
            entryData.score = totalScore + 4 * searchUpIndex + 2 * (entryLength - (searchUpIndex + tokenLength));
            dictEntries.add(entryData);

            entryIndex++;
          }
        }
      }
      
      dictEntries.sort((a, b) => a.score.compareTo(b.score));

      setState(() {
        inputEmpty = input.isEmpty;
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
      backgroundColor: kBackgroundColor,
      body: Column(
        children: [
          // TOP THIN DARKER RED LINE
          Container(
            height: 3.5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red.shade900
            ),
          ),

          // TOP BAR
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  // SEARCH BAR
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 100,
                    height: 40.0,
                    child: TopSearchBanner(
                      isEnglish: isEnglish,
                      searchController: searchController,
                      onChangedText: onChangedText
                    )
                  ),
                  
                  const Padding(padding: EdgeInsetsGeometry.all(10)),

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
                ]),

                // ADVANCED SEARCH DROPDOWN TEXT
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAdvancedOpen = !_isAdvancedOpen;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsetsGeometry.symmetric(horizontal: 30, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Advanced Search',
                            style: kUITextStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold
                            )
                          ),
                          const SizedBox(width: 4),
                          Icon(_isAdvancedOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down)
                        ],
                      )
                    ),
                  ),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.ease,
                  child: _isAdvancedOpen ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text("Open Entry #", style: kDefaultTextStyle.copyWith(color: Colors.white)),

                            // SEARCH BAR
                            SizedBox(
                              width: 100.0,
                              height: 30.0,
                              child: TextField(
                                controller: _entryNumTextController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly, // allow only numbers
                                  LengthLimitingTextInputFormatter(4), //up to 4 digit numbers
                                ],
                                decoration: InputDecoration(
                                  hintText: 'Entry ID',
                                  hintStyle: kUITextStyle.copyWith(fontSize: 13.0),
                                  border: const OutlineInputBorder(),
                                ),
                              )
                            ),

                            const SizedBox(width: 12),

                            // SEARCH BUTTON
                            TextButton(
                              onPressed: () {
                                int? entryIndex = int.tryParse(_entryNumTextController.text);
                                if (entryIndex != null) {
                                  entryIndex--; // entry number index shown in the app is 1-indexed
                                  if (entryIndex < kEntries.length && entryIndex >= 0) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => EntryPage(entryData: EntryData(index: entryIndex!)),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Sorry, no entry was found.')),
                                    );
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                shadowColor: Colors.transparent,
                                backgroundColor: const Color.fromARGB(255, 153, 41, 33)
                              ),
                              child: Text('Search', style: kUITextStyle.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold
                              )),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10.0),

                        // ALL ENTRIES PAGE
                        TextButton(
                          onPressed: () {
                            setState(() {
                              kPageIndexNotif.value = 1; // go to full list page
                            });
                          },
                          style: TextButton.styleFrom(
                            shadowColor: Colors.transparent,
                            backgroundColor: const Color.fromARGB(255, 153, 41, 33)
                          ),
                          child: Text('View All Entries', style: kUITextStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold
                          )),
                        ),
                      ]
                    )
                  ) : const SizedBox.shrink()
                )
              ],
            )
          ),

          if (dictEntries.isEmpty)
            Expanded(child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: 
                  // CENTER TEXT
                  Text(inputEmpty ?
                    'Welcome to the Medan Hokkien dictionary.\nCurrently, there are ${kEntries.length} entries.\n\nTap the icon on the top right to toggle between English and Chinese/POJ search.' :
                    'Sorry, no entry was found.',
                    style: kDefaultTextStyle.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.0
                    ),
                    textAlign: TextAlign.center,
                  )
              ),
            ))
          else
            // LIST OF ENTRIES
            Expanded(child: ListView.separated(
              itemCount: dictEntries.length,
              itemBuilder: (context, index) {
                final entryData = dictEntries[index];
                return respondingCondenseEntryWidget(context, entryData);
              },
              separatorBuilder: (context, index) => Divider(
                color: const Color.fromARGB(255, 57, 72, 80), // customize color
                thickness: 1,       // customize thickness
                height: 0,          // spacing handled by padding
              ),
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
            style: kCJKTextStyle.copyWith(
              color: Colors.white,
              fontFamily: 'DefaultFont',
              fontWeight: FontWeight.bold,
              fontSize: minDouble(0.1 * MediaQuery.of(context).size.width, 13) // Search bar text font size
            ),
            onChanged: onChangedText,
            decoration: InputDecoration(
              hintText: isEnglish ? "Search in English..." : "Search in Chinese or POJ...",
              hintStyle: kDefaultTextStyle.copyWith(color: Colors.white),
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
              suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.clear, color: Colors.white),
                    onPressed: () {
                      searchController.clear();
                      onChangedText("");
                    },
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
            style: kDefaultTextStyle.copyWith(
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

class FullListPage extends StatefulWidget {
  const FullListPage({super.key});

  @override
  // ignore: no_logic_in_create_state
  State<FullListPage> createState() => _FullListPageState();
}

class _FullListPageState extends State<FullListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Column(
        children: [
          // TOP THIN DARKER RED LINE
          Container(
            height: 3.5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.red.shade900,
            ),
          ),

          // TOP BAR
          Container(
            height: 60.0,
            width: double.infinity,
            color: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              children: [
                // BACK BUTTON
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      kPageIndexNotif.value = 0; // back to dictionary page
                    });
                  },
                ),

                const SizedBox(width: 8),

                // ENTRY NUMBER
                Expanded(child: Text(
                  'Entries List',
                  style: kUITextStyle.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                )),

                const SizedBox(width: 48),
              ],
            ),
          ),
          
          // LIST OF ENTRIES
          Expanded(child: ListView.builder(
            key: const PageStorageKey('full_entries_list'),
            //controller: _scrollController,
            physics: ClampingScrollPhysics(),
            itemCount: kEntries.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) {
              final entryData = EntryData(index: index);
              return RepaintBoundary(child: Row(
                children: [
                  SizedBox(
                    width: 70.0,
                    child: Text(
                      "#$index",
                      style: kUITextStyle,
                      textAlign: TextAlign.center
                    )
                  ),

                  const SizedBox(width: 10.0),

                  Expanded(child: respondingCondenseEntryWidget(context, entryData))
                ]
              ));
            },
          ))
        ])
    );
  }
}