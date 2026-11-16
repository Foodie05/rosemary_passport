// Optional local visual evidence; CI still runs all geometry assertions without fonts.
import 'dart:io';
import 'package:flutter/services.dart';

Future<void> loadVisualFonts() async {
  for (final entry in {
    '-apple-system': 'ROSM_VISUAL_FONT',
    'Georgia': 'ROSM_VISUAL_SERIF_FONT',
  }.entries) {
    final path = Platform.environment[entry.value];
    if (path != null) {
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(ByteData.sublistView(await File(path).readAsBytes())),
        );
      await loader.load();
    }
  }
}
