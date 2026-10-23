import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:fleather/fleather.dart';

class MathEmbed extends BlockEmbed {
  MathEmbed(String latex) : super('math:$latex');

  static MathEmbed fromJson(String data) {
    return MathEmbed(data);
  }

  String get latex => type.substring(5); // Remove 'math:' prefix
}
