import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  vulgarity("\$vulgar", true),
  surname("\$surname", true),

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

  final String hanziDisplay;
  final String pojDisplay;
  final String definitionsDisplay;

  final List<String> searchUp;

  factory Entry(List<String> hanzi, List<String> poj, List<Definition> definitions) {
    final definitionsDisplay = definitions
      .where((e) => !e.categories.any((cat) => _nondescriptiveCategories.contains(cat)))
      .map((e) => e.content.replaceAll(",", ";"))
      .join(", ");

    return Entry._internal(
      hanziDisplay: hanzi.join(" / "),
      pojDisplay: poj.join(" / "),
      definitionsDisplay: definitionsDisplay,
      searchUp: definitionsDisplay
          .replaceAll(";", ",") //remove non-alphanumeric characters but leave the whitespace
          .toLowerCase()
          .split(",")
          .map((s) => s.trim())
          .toList(), //split any whitespace, including instances of multiple whitespaces e.g. "a    a"
      hanzi: hanzi,
      poj: poj,
      definitions: definitions
    );
  }

  const Entry._internal({
    required this.hanziDisplay,
    required this.pojDisplay,
    required this.definitionsDisplay,
    required this.searchUp, required this.hanzi, required this.poj, required this.definitions,
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

  var index = 0;
  while (index < textLines.length) {
    var characters = textLines[index].characters;
    if (characters.first == "=") break;

    index++;
  }

  List<String> names = textLines[index].substring(1).trimRight().split(":");
  if (names.length != 2) {
    if (kDebugMode) debugPrint("The entry '${textLines[index]}' could not be parsed. (There can only be one semicolon ':')");
    return null;
  }
  
  final nameIndex = index;
  List<String> hanzi = names[0].split("/");
  List<String> poj = names[1].split("/");
  List<Definition> definitions = List.empty(growable: true);

  bool isExplain = false;
  StringBuffer explainBuffer = StringBuffer();
  index++;
  while (index < textLines.length) {
    String description = "${textLines[index].trim()} ";
    final chars = description.characters;

    StringBuffer buffer = StringBuffer();
    List<Category> categories = List.empty(growable: true);
    int count = 0;
    for (final char in chars) {
      count++;
      if (char == ' ') {
        String word = buffer.toString();
        if (word.startsWith("\$")) {
          Category? category = _categories[word];
          if (category == null) {
            if (kDebugMode) debugPrint("The entry '${textLines[nameIndex]}' could not be parsed. Unknown category '$word'.");
            return null;
          }

          categories.add(category);

          buffer.clear();

          isExplain = category == Category.explanation;
          if (isExplain) break;

          continue;
        } else {
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
      if (explainBuffer.isNotEmpty) {
        definitions.add(Definition(categories: [Category.explanation], content: explainBuffer.toString().trim()));
        explainBuffer.clear();
      }

      if (categories.isNotEmpty) {
        buffer.write(chars.skip(count).toString());
        definitions.add(Definition(categories: categories, content: buffer.toString().trim()));
      }
    }

    index++;
  }

  if (explainBuffer.isNotEmpty) {
    definitions.add(Definition(categories: [Category.explanation], content: explainBuffer.toString().trim()));
  }

  return Entry(hanzi, poj, definitions);
}

Future<String> loadDictionary() async {
  return await rootBundle.loadString('assets/entries/dictionary.txt');
}