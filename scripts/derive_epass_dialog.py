#!/usr/bin/env python3
"""Narrow viewport adapter for the pinned official Flutter overlay implementation."""
from pathlib import Path

def derive(source):
    section = source[source.index('class RosemaryDialog extends StatefulWidget'):source.index('class RosemaryPopover extends StatefulWidget')]
    section = section.replace('RosemaryDialog', 'RosmInsetDialog').replace('RosemaryDrawer', 'RosmInsetDrawer')
    section = section.replace('final size = MediaQuery.sizeOf(context);', '''final media = MediaQuery.of(context);
        final size = media.size;
        final gutters = EdgeInsets.fromLTRB(
          20 + media.padding.left, 24 + media.padding.top,
          20 + media.padding.right,
          24 + (media.viewInsets.bottom > media.padding.bottom
              ? media.viewInsets.bottom : media.padding.bottom),
        );''')
    section = section.replace('size.width.clamp(0.0, 560.0)', '(size.width - gutters.horizontal).clamp(0.0, 520.0)')
    section = section.replace('BoxConstraints(maxHeight: size.height)', 'BoxConstraints(maxHeight: drawer ? size.height : ((size.height - gutters.vertical) * .9).clamp(0.0, 680.0))')
    section = section.replace('child: SafeArea(', '''child: MediaQuery.removePadding(
              context: context, removeTop: true, removeBottom: true,
              removeLeft: true, removeRight: true,''')
    section = section.replace("RosemaryText(widget.title, role: 'heading')", "Text(widget.title, style: rosemaryTextStyle(context, 'body').copyWith(fontSize: 20, height: 1.5, fontWeight: FontWeight.w500))")
    section = section.replace('else\n                    Center(', '''else
                    Padding(
                      padding: gutters,
                      child: Center(''')
    section = section.replace('child: panel,\n                        ),\n                      ),\n                    ),', 'child: panel,\n                        ),\n                      ),\n                    ),\n                    ),')
    return '''// Derived from pinned rosemary_ui 0.5.0 overlays.dart; MIT, see vendor license.
// Only panel bounds, safe/keyboard gutters and UI heading metrics differ.
// Lifecycle, theme snapshot, focus restoration/trapping and dismissal stay upstream.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

''' + section

if __name__ == '__main__':
    root=Path(__file__).resolve().parents[1]
    src=root/'packages/rosm_passport_flutter/vendor/rosemary_ui/lib/src/overlays.dart'
    (root/'packages/rosm_passport_flutter/lib/src/inset_dialog.dart').write_text(derive(src.read_text()))
