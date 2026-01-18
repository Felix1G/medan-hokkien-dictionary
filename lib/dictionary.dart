import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:medan_hokkien_dictionary/util.dart';

enum Category {
  noun("\$noun"),
  verb("\$verb"),
  adjective("\$adj"),
  adverb("\$advb"),
  pronoun("\$pron"),
  auxiliary("\$auxi"),
  preposition("\$prepo"),
  conjunction("\$conj"),
  classifier("\$class"),
  number("\$num"),
  phrase("\$phrase"),
  expression("\$express"),
  idiom("\$idiom"),

  food("\$food", true),
  fruit("\$fruit", true),
  drink("\$drink", true),
  animal("\$animal", true),
  colour("\$colour", true),
  family("\$family", true),
  location("\$loc", true),
  language("\$lang", true),
  body("\$body", true),
  time("\$time", true),
  event("\$event", true),
  vulgarity("\$vulgar", true),
  surname("\$surname", true),
  figurative("\$figur", true),

  explanation("\$explain"),

  etymology("\$etymology"),
  etyIDN("\$etyIDN"), // Indonesian
  etyMSA("\$etyMSA"), // Malay
  etyIMA("\$etyIMA"), // Indo/Malay
  etyENG("\$etyENG"), // English
  etyFRA("\$etyFRA"), // France
  etyVNM("\$etyVNM"), // Vietnamese
  etyYUE("\$etyYUE"), // Cantonese
  etyTEO("\$etyTEO"), // Teochew
  etyHAK("\$etyHAK"), // Hakka
  etyCMN("\$etyCMN"), // Mandarin
  etyJPN("\$etyJPN"), // Japanese
  etySAN("\$etySAN"), // Sanskirt

  see("\$see"),
  opposite("\$opp");

  final String code;
  final bool semantic;
  const Category(this.code, [this.semantic = false]);
}

class Definition {
  final List<Category> categories;
  final String content;

  Definition({required this.categories, required this.content});

  @override
  String toString() {
    return 'Definition(categories: '
        '${categories.map((c) => c.name).toList()}, '
        'content: "$content")';
  }
}

List<Category> _nondescriptiveCategories = [
  Category.explanation, Category.etymology, Category.etyIDN, Category.etyMSA, Category.etyIMA,
  Category.etyENG, Category.etyFRA, Category.etyVNM, Category.etyYUE, Category.etyTEO,
  Category.etyHAK, Category.etyCMN, Category.etyJPN, Category.etySAN, Category.see,
  Category.opposite,
];

class Entry {
  final List<String> hanzi;
  final List<String> poj;
  final List<Definition> definitions;

  final String hanziDisplay; // hanzi display in the search list
  final String pojDisplay; // poj display in the search list
  final String definitionsDisplay; // definition display in the search list

  final List<String> defSearchUp; // a list of the definition split by ';' or ',' for English search up
  final List<Set<String>> chineseSearchUp; // for chinese/POJ search up
  
  final List<Color> pojToneColours; // colour of hanzi from poj tone

  factory Entry(List<String> hanzi, List<String> poj, List<Definition> definitions) {
    final definitionsDisplay = definitions
      .where((e) => !e.categories.any((cat) => _nondescriptiveCategories.contains(cat)))
      .map((e) => e.content.replaceAll(",", ";"))
      .join(", ");

    final pojWordListIterable = poj
      .map((words) => words // [kōe-lō͘]
        .split(RegExp(r'[-\s]+')) // [kōe, lō͘]
      );

    final pojSearchUp = pojWordListIterable
      .map((words) => words // [kōe-lō͘]
        .map((poj) => "${removeDiacritics(poj)}${getTone(poj)}").toList() // [koe7, loo7]
      ).toList(); // [[koe7, loo7]]

    final pojSearchUpToneless = pojSearchUp
      .map((words) => words
        .map((word) => word
          .replaceAll(RegExp(r'[0-9]'), '')
        ).toList()
      ).toList();

    final hanziSearchUp = hanzi.map((word) => word.split('').toList()).toList();

    // putting into list to avoid code repetition at the loop below
    final allLists = [pojSearchUp, pojSearchUpToneless, hanziSearchUp, pojWordListIterable.toList()];

    final chineseSearchUp = List.generate(
      maxInt(hanzi[0].length, pojWordListIterable.first.length), // either hanzi or poj is longer
      (int index) {
        final set = <String>{};

        for (var listGroup in allLists) {
          for (var list in listGroup) {
            if (index < list.length) {
              set.add(list[index]);
            }
          }
        }

        return set;
      }
    );

    final pojToneColours = poj[0] // "kōe-lō͘"
      .split(RegExp(r'[-\s]+')) // [kōe, lō͘]
      .map((poj) => kToneColours[getTone(poj) - 1]) // [7, 7] => [colour of 7, colour of 7]
      .toList();

    return Entry._internal(
      hanziDisplay: hanzi.join(" / "),
      pojDisplay: poj.join(" / "),
      definitionsDisplay: definitionsDisplay,
      defSearchUp: definitionsDisplay
          .replaceAll(";", ",")
          .toLowerCase()
          .split(",")
          .map((s) => s.trim())
          .toList(),
      chineseSearchUp: chineseSearchUp,
      pojToneColours: pojToneColours,
      hanzi: hanzi,
      poj: poj,
      definitions: definitions
    );
  }

  const Entry._internal({
    required this.hanziDisplay,
    required this.pojDisplay,
    required this.definitionsDisplay,
    required this.defSearchUp,
    required this.chineseSearchUp,
    required this.pojToneColours,
    required this.hanzi, required this.poj, required this.definitions,
  });
  
  @override
  String toString() {
    return '''
Entry(
  hanzi: $hanzi,
  poj: $poj,
  definitions:
${definitions.map((d) => '    $d').join('\n')}
)
''';
  }
}

HashMap<String, Category> _categories = HashMap();

void initDictionary() {
  for (final cat in Category.values) {
    _categories[cat.code] = cat;
  }
}

Entry? parseEntry(List<String> textLines) {
  if (textLines.isEmpty) return null;

  // skip through the textLines until '=' is found
  var index = 0;
  while (index < textLines.length) {
    var characters = textLines[index].characters;
    if (characters.first == "=") break;

    index++;
  }

  if (index >= textLines.length) return null; // the input contains no valid entry ('=' does not exist)

  // acquire info on hanzi and poj
  List<String> names = textLines[index].substring(1).trimRight().split(":");
  if (names.length != 2) { // split by ':' should only have one, so 2 groups of strings
    if (kDebugMode) debugPrint("The entry '${textLines[index]}' could not be parsed. (There can only be one semicolon ':')");
    return null;
  }
  
  // slash ('/') divides hanzi or poj varieties
  final nameIndex = index; // saving this for debug info
  List<String> hanzi = names[0].split("/");
  List<String> poj = names[1].split("/");

  // acquire definition info
  List<Definition> definitions = List.empty(growable: true);

  // handling explanations which are multi-line
  bool isExplain = false;
  StringBuffer explainBuffer = StringBuffer();

  index++; // step into the next line
  while (index < textLines.length) {
    final description = "${textLines[index].trim()} "; // extra leading whitespace to ease processing below
    final chars = description.characters;

    final buffer = StringBuffer(); // store the actual definition string
    List<Category> categories = List.empty(growable: true); // storing category
    int count = 0; // amount of characters processed below, used to skip chars to the actual definition string
    for (final char in chars) {
      count++;
      if (char == ' ') { // whitespaces split words
        String word = buffer.toString();
        if (word.startsWith("\$")) { // category detected
          Category? category = _categories[word];
          if (category == null) {
            if (kDebugMode) debugPrint("The entry '${textLines[nameIndex]}' could not be parsed. Unknown category '$word'.");
            return null;
          }

          categories.add(category);
          buffer.clear();

          isExplain = category == Category.explanation;
          if (isExplain) break; // explanation BEGINS on the next line

          continue;
        } else { // category detection has ended, the rest is definition
          buffer.write(char);
          break;
        }
      }

      buffer.write(char);
    }

    if (isExplain) {
      explainBuffer.write(buffer);
      explainBuffer.write(chars.skip(count).toString());
      explainBuffer.write("\n");
    } else {
      if (explainBuffer.isNotEmpty) { // add remaining explanation
        definitions.add(Definition(categories: [Category.explanation], content: explainBuffer.toString().trim()));
        explainBuffer.clear();
      }

      if (categories.isNotEmpty) { // add new definition
        buffer.write(chars.skip(count).toString());
        definitions.add(Definition(categories: categories, content: buffer.toString().trim()));
      }
    }

    index++; //textLines index
  }

  if (explainBuffer.isNotEmpty) { // add remaining explanation
    definitions.add(Definition(categories: [Category.explanation], content: explainBuffer.toString().trim()));
  }

  return Entry(hanzi, poj, definitions);
}

// path must start with "assets/"
Future<String> loadDictionary() async {
  return await rootBundle.loadString('assets/entries/dictionary.txt');
}