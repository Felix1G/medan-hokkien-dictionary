// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:collection';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:medan_hokkien_dictionary/dictionary.dart';
import 'package:medan_hokkien_dictionary/main.dart';

String charAtUni(String text, int index) {
  return String.fromCharCode(text.runes.elementAt(index));
}

String charAtUniRunes(Runes runes, int index) {
  return String.fromCharCode(runes.elementAt(index));
}

double minDouble(double a, double b) {
  return a < b ? a : b;
}

int minInt(int a, int b) {
  return a < b ? a : b;
}

final _kHanziRegex = RegExp(
  r'[\u4E00-\u9FFF\u3400-\u4DBF\uF900-\uFAFF]|'
  r'[\u{20000}-\u{2EBEF}]',
  unicode: true,
);

bool isStrHanzi(String str) {
  return _kHanziRegex.hasMatch(str);
}

// Tone mark detection (POJ standard)
final Map<int, RegExp> toneMarks = {
  2: RegExp(r'[áéíóúńḿ]|[a-zA-Z]\u0301'),
  3: RegExp(r'[àèìòùǹm̀]|[a-zA-Z]\u0300'),
  5: RegExp(r'[âêîôûṋm̂]|[a-zA-Z]\u0302'),
  7: RegExp(r'[āēīōūn̄m̄]|[a-zA-Z]\u0304'),
  8: RegExp(r'[a-zA-Z]\u030D'), // vertical line above
};

final _kTonePatterns = {
  2: [
    'á','é','í','ó','ó͘','ú','ń','ḿ',  // precomposed
    '\u0301'                      // acute combining mark
  ],
  3: [
    'à','è','ì','ò','ò͘','ù','ǹ','m̀',  // precomposed
    '\u0300'                      // grave
  ],
  5: [
    'â','ê','î','ô','ô͘','û','n̂','m̂'   // precomposed
    '\u0302'                      // circumflex
  ],
  7: [
    'ā','ē','ī','ō','ō͘','ū','n̄','m̄'   // precomposed
    '\u0304'                      // macron
  ],
  8: [
    '\u030D'                      // vertical line above (combining mark)
  ]
};

int getTone(String poj) {
  for (final entry in _kTonePatterns.entries) {
    for (final mark in entry.value) {
      if (poj.contains(mark)) {
        return entry.key;
      }
    }
  }

  // ends with h/k/t/p
  if (RegExp(r'[hktp]$').hasMatch(poj)) return 4;

  return 1;
}

const Map<String, String> _kPOJReplacements = {
  'ó͘':'oo','ò͘':'oo','ō͘':'oo','o̍͘':'oo','ô͘':'oo','o͘':'oo',
  'á':'a','à':'a','â':'a','ā':'a',
  'é':'e','è':'e','ê':'e','ē':'e',
  'í':'i','ì':'i','î':'i','ī':'i',
  'ó':'o','ò':'o','ô':'o','ō':'o',
  'ú':'u','ù':'u','û':'u','ū':'u',
  'ń':'n','ǹ':'n','n̂':'n','n̄':'n',
  'ḿ':'m','m̀':'m','m̂':'m','m̄':'m',
  'ⁿ':'n','ʳ':'r',
  '\u030D':''
};

String removeDiacritics(String poj) {
  String result = poj;
  _kPOJReplacements.forEach((key, value) {
    result = result.replaceAll(key, value);
  });

  return result;
}

const List<Color> kToneColours = [
  Colors.pink, Colors.red, Colors.blue, Colors.orange,
  Colors.green, Colors.white, Colors.cyan, Colors.yellow
];

// Used for the entries in the search list
class EntryData {
  final int index;
  int score = 0;
  Entry get entry => kEntries[index];

  EntryData({required this.index});  
}

// Tokens for the Chinese/POJ search mode
class SearchToken {
  String content;
  bool isHanzi; // false = pinyin, true = hanzi

  SearchToken({required this.content, required this.isHanzi});

  @override
  String toString() {
    return "SearchToken(content: $content, isHanzi: $isHanzi)";
  }
}

class ColoredText extends StatelessWidget {
  final String text;
  final List<Color> colors;
  final TextStyle style;

  const ColoredText({super.key, required this.text, required this.colors, required this.style});

  @override
  Widget build(BuildContext context) {
    return RichText(text: TextSpan(children: List.generate(text.characters.length, (index) {
      return TextSpan(
        text: text.characters.elementAt(index),
        style: style.copyWith(color: colors[index % colors.length])
      );
    })));
  }
}