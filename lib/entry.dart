import 'dart:collection';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medan_hokkien_dictionary/dictionary.dart';
import 'package:medan_hokkien_dictionary/main.dart';
import 'package:medan_hokkien_dictionary/style.dart';
import 'package:medan_hokkien_dictionary/util.dart';
import 'package:sliver_tools/sliver_tools.dart';

TextSpan definitionText(String word, {double normalSize = 16, double tagSizeScale = 0.7}) {
  final isTag = word.startsWith('#');
  return TextSpan(
        text: isTag ? '${word.substring(1)} ' : '$word ',
        style: (isTag ? kCategoryTextStyle : kCJKTextStyle).copyWith(
          fontSize: isTag ? tagSizeScale * normalSize : normalSize,
          fontWeight: isTag ? FontWeight.w900 : FontWeight.w200,
          letterSpacing: isTag ? 1.5 : null,
          color: isTag ? Colors.white : const Color.fromARGB(255, 217, 217, 217)
        ),
      );
}

Widget definitionDisplayText(String text, {double normalSize = 16, double tagSizeScale = 0.7}) {
  final words = text.split(' ');

  return RichText(text: TextSpan(
    children: words.map((word) => definitionText(word, normalSize: normalSize, tagSizeScale: tagSizeScale)).toList(),
  ));
}

void redirectToEntryPage(BuildContext context, EntryData entryData) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EntryPage(entryData: entryData),
    ),
  );
}

Widget condensedEntryWidget(BuildContext context, Entry entry) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 7.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap( // wraps the hanzi and poj text when they exceed the width of screen
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: entry.hanziDisplay.isEmpty ? 0 : 10,
          children: [
            // HANZI
            if (entry.hanziDisplay.isNotEmpty)
              ColoredText(
                text: entry.hanziDisplay,
                colours: entry.pojToneColours,
                style: kCJKTextStyle.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(30.0))
              ),

            // POJ
            Text(entry.pojDisplay, style: kCJKTextStyle.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(20.0)))
          ]
        ),

        const SizedBox(height: 10.0),

        // DEFINITION
        definitionDisplayText(entry.definitionsDisplay, normalSize: MediaQuery.textScalerOf(context).scale(17.5))
      ]
    )
  );
}

Widget respondingCondenseEntryWidget(BuildContext context, EntryData entryData) {
  return InkWell(
    // redirect to entry page
    onTap: () {
      redirectToEntryPage(context, entryData);
    },
    splashColor: Colors.transparent, // Ink Well allows these two effects below easily, but splash is too distracting
    hoverColor: const Color.fromARGB(20, 239, 239, 239),
    mouseCursor: SystemMouseCursors.click,
    child: condensedEntryWidget(context, entryData.entry)
  );
}

Widget entryPageButton(String text, bool selected, VoidCallback onPressed) {
  final underlineColor = selected ? const Color.fromARGB(255, 255, 162, 55) : const Color.fromARGB(255, 78, 49, 16);

  return Expanded(
    child: TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor:
          WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color.fromARGB(20, 156, 156, 156); // brighter background on hover
              }
              return Colors.transparent; // default
            },
          ),
        overlayColor: WidgetStateProperty.all(Colors.transparent), // no splash
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(const RoundedRectangleBorder(borderRadius: BorderRadius.zero)), 
        // 8 is a magic number that works, > 8 and the hover overlay goes below the bottom underline
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // MAIN TEXT
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              text,
              style: kUITextStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: underlineColor,
              ),
            ),
          ),

          // BOTTOM UNDERLINE
          Container(
            height: 2,
            color: underlineColor,
          ),
        ],
      ),
    ),
  );
}

class EntryPage extends StatefulWidget {
  const EntryPage({super.key, required this.entryData});

  final EntryData entryData;

  @override
  // ignore: no_logic_in_create_state
  State<EntryPage> createState() => _EntryPageState(entryData: entryData);
}

class _EntryPageState extends State<EntryPage> {
  final EntryData entryData;

  int selectedPage = 0; // 0 = DICT, 1 = CHARS, 2 = WORDS
  
  final pageScrollController = ScrollController(initialScrollOffset: 0.0);

  _EntryPageState({ required this.entryData });

  @override
  Widget build(BuildContext context) {
    final hanziStyle = kCJKTextStyle.copyWith(
      fontSize: MediaQuery.textScalerOf(context).scale(40.0)
    );
    final pojStyle = kCJKTextStyle.copyWith(
      fontSize: MediaQuery.textScalerOf(context).scale(20.0)
    );

    // get all hanzi widgets (which are at the top of the page)
    List<Widget> hanziWidgets = List.empty(growable: true);
    for (int i = 0;i < entryData.entry.hanzi.length;i++) {
      hanziWidgets.add(EntryCopyableText(text: entryData.entry.hanzi[i], style: hanziStyle, toneColours: entryData.entry.pojToneColours));

      if (i != entryData.entry.hanzi.length - 1) {
        hanziWidgets.add(Text(" / ", style: hanziStyle));
      }
    }
    
    // get all poj widgets (which are at the top of the page)
    List<Widget> pojWidgets = List.empty(growable: true);
    for (int i = 0;i < entryData.entry.poj.length;i++) {
      pojWidgets.add(EntryCopyableText(text: entryData.entry.poj[i], style: pojStyle, toneColours: null));

      if (i != entryData.entry.poj.length - 1) {
        pojWidgets.add(Text(" / ", style: pojStyle));
      }
    }
    
    // DICT subpage
    List<Widget> dictWidgets = List.empty(growable: true);
    Category? parentCategory;
    int defNumber = 1;
    final dictFontSize = MediaQuery.textScalerOf(context).scale(20.0);
    final definitions = entryData.entry.definitions;
    for (int idx = 0; idx < definitions.length; idx++) {
      // check for the change of the main category
      final firstCategory = definitions[idx].categories.first;
      if (firstCategory.redirect) {
        if (parentCategory != null) {
          dictWidgets.add(const SizedBox(height: 20));
        }

        final redirectContent = definitions[idx].content;

        dictWidgets.add(Row(children: [
          Text.rich(definitionText(firstCategory.name, normalSize: dictFontSize, tagSizeScale: 1.0)),

          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                final entryIdx = kEntries.indexWhere(
                  (entry) => entry.hanzi.any((hanzi) => hanzi == redirectContent)
                );

                if (entryIdx == -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entry does not exist.')),
                  );
                } else {
                  redirectToEntryPage(context, EntryData(index: entryIdx));
                }
              },
              child: Text(
                redirectContent,
                style: kCJKTextStyle.copyWith(
                  fontSize: 1.2 * dictFontSize,
                  color: Colors.cyan
                ),
              ),
            ),
          )
        ]));

        parentCategory = firstCategory;
        continue;
      }

      if (firstCategory != parentCategory || firstCategory.redirect) {
        // only apply top padding for subsequent categories
        if (parentCategory != null) {
          dictWidgets.add(const SizedBox(height: 20));
        }

        dictWidgets.add(Text.rich(definitionText(firstCategory.name, normalSize: dictFontSize, tagSizeScale: 1.0))); // main category name

        parentCategory = firstCategory;
        defNumber = 1;
      }
      
      final textWidgets = <Widget>[]; // texts separated by line under the same definition number

      // check for extra semantic categories
      if (!firstCategory.redirect) {
        final catIterator = definitions[idx].categories.iterator;
        catIterator.moveNext(); // iterator starts at index -1, this skips the first element
        while (catIterator.moveNext()) {
          // semantic category
          textWidgets.add(Text.rich(definitionText("${catIterator.current.name} ", normalSize: dictFontSize, tagSizeScale: 1.0)));
        }
      }

      // main definition content
      textWidgets.add(Text.rich(definitionText(definitions[idx].content, normalSize: dictFontSize, tagSizeScale: 1.0)));

      // add the widget on this definition number
      dictWidgets.add(Padding(
        padding: const EdgeInsetsGeometry.symmetric(horizontal: 5),
        child: Row(
          spacing: 5.0,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DEFINITION NUMBER
            Text("$defNumber ", style: kUITextStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: dictFontSize,
              color: Colors.white
            )),

            // CONTENT INCLUDING SEMANTIC CATEGORY
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: textWidgets
              ),
            ),
          ],
        )
      ));
      
      defNumber++;
    }

    // CHARS subpage
    final charWidgets = List<Widget>.empty(growable: true);
    if (entryData.entry.hanzi.isNotEmpty) {
      final chars = <String>{}; // get all unique individual characters
      for (final hanzi in entryData.entry.hanzi) {
        for (final char in hanzi.characters) {
          chars.add(char);
        }
      }

      // compute the widgets for all characters
      for (final char in chars) {
        final entries = kEntriesCharacter[char];

        if (entries == null) continue;

        for (final entryIdx in entries) {
          if (entryIdx != entryData.index && entryIdx != null) {
            charWidgets.add(respondingCondenseEntryWidget(context, EntryData(index: entryIdx)));
          }
        }
      }
    }

    // WORDS subpage
    final wordWidgets = List<Pair<int, Widget>>.empty(growable: true);
    if (entryData.entry.hanzi.isNotEmpty) {
      var entryIdx = 0;
      for (final checkEntry in kEntries) {
        // check if any new entry contains characters of this entry
        if (entryIdx != entryData.index && checkEntry.hanzi.any((str) => entryData.entry.hanzi.any((strThis) => stringContainsByRunes(str, strThis)))) {
          wordWidgets.add(Pair(checkEntry.hanzi.first.length, respondingCondenseEntryWidget(context, EntryData(index: entryIdx))));
        }
        entryIdx++;
      }
    }
    wordWidgets.sort((a, b) => a.first.compareTo(b.first));

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
                    Navigator.of(context).pop();
                  },
                ),

                const SizedBox(width: 8),

                // ENTRY NUMBER
                Expanded(child: Text(
                  'Entry #${entryData.index + 1}',
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

          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(5),
              topRight: Radius.circular(5),
              bottomLeft: Radius.zero,
              bottomRight: Radius.zero),
            child: NestedScrollView(
              physics: selectedPage == 1 ? (charWidgets.isEmpty ? NeverScrollableScrollPhysics() : null) :
                (selectedPage == 2 && wordWidgets.isEmpty ? NeverScrollableScrollPhysics() : null),
              controller: pageScrollController,
              floatHeaderSlivers: false,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    sliver: MultiSliver(
                      children: [
                        SliverToBoxAdapter(
                          child: Container(
                            width: double.infinity,
                            color: Color.fromRGBO(30, 30, 30, 1.0),
                            child: Column(
                              children: [
                                // HANZI
                                if (hanziWidgets.isNotEmpty) const SizedBox(height: 30),
                                if (hanziWidgets.isNotEmpty)
                                  Center(child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: hanziWidgets,
                                    ),
                                  )),

                                const SizedBox(height: 20),

                                // POJ
                                Center(child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: pojWidgets,
                                  ),
                                )),

                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),

                        // NAVIGATION BUTTONS
                        SliverPersistentHeader(
                          pinned: true,
                          floating: false,
                          delegate: _EntryNavHeader(
                            selectedPage: selectedPage,
                            onSelect: (i) => setState(() {
                              if (selectedPage != i) {
                                pageScrollController.jumpTo(0.0); // always reset scroll after a button press
                              }
                              
                              selectedPage = i;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              },
              body: Builder(
                builder: (context) {
                  return CustomScrollView(
                    slivers: [
                      // allows the scrolling to go below the pinned nav buttons (instead of going underneath it)
                      SliverOverlapInjector(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                      ),

                      // SUBPAGES
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (selectedPage == 0) return dictWidgets[index];

                              final item = selectedPage == 1 ? charWidgets[index] : wordWidgets[index].second;
                              final separator = index < (selectedPage == 1 ? charWidgets : wordWidgets).length - 1 ? // ignore divider for last elem
                                Divider(
                                  color: const Color.fromARGB(255, 57, 72, 80),
                                  thickness: 1,
                                  height: 0,
                                ) : const SizedBox();
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  SizedBox(width: double.infinity, child: item), // sized box to force the width of the widget to maximum
                                  separator
                                ],
                              );
                            },
                            childCount: selectedPage == 0 ? dictWidgets.length : (selectedPage == 1 ? charWidgets.length : wordWidgets.length),
                          )
                        ),
                      ),
                    ],
                  );
                },
              ),
            ))
          ),
        ],
      ),
    );
  }
}

class _EntryNavHeader extends SliverPersistentHeaderDelegate {
  final int selectedPage;
  final ValueChanged<int> onSelect;

  _EntryNavHeader({required this.selectedPage, required this.onSelect});

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: const Color.fromRGBO(30, 30, 30, 1.0),
      child: Row(
        children: [
          entryPageButton('DICT', selectedPage == 0, () => onSelect(0)),
          entryPageButton('CHARS', selectedPage == 1, () => onSelect(1)),
          entryPageButton('WORDS', selectedPage == 2, () => onSelect(2)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _EntryNavHeader old) => old.selectedPage != selectedPage;
}

class EntryCopyableText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final List<Color>? toneColours;

  const EntryCopyableText({super.key, required this.text, required this.style, required this.toneColours});

  @override
  Widget build(BuildContext context) {
    final colours = toneColours;
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MAIN TEXT
            Flexible(child: colours != null ?
              ColoredText(text: text, colours: colours!, style: style) :
              Text(text, style: style, softWrap: true, overflow: TextOverflow.visible)
            ),

            const SizedBox(width: 2.0),

            // COPY PASTE ICON
            Padding(
              padding: const EdgeInsets.only(top: 8), // adjust this value
              child: const Icon(
                Icons.copy,
                size: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
    );
  }
}