#!/usr/bin/env python3
"""Center the official button's contents when a task stretches it to full width."""
from pathlib import Path

def derive(source):
    section=source[source.index('class RosemaryButton extends StatelessWidget'):source.index('class RosemaryIconButton extends StatelessWidget')]
    section='class RosmEpassButton extends RosemaryButton {\n'+section[section.index('  const RosemaryButton('):]
    constructor_end=section.index('  @override')
    section=section[:constructor_end].replace('const RosemaryButton(', 'const RosmEpassButton(').replace('this.', 'super.')+section[constructor_end:]
    section=section.replace('return Semantics(', 'return LayoutBuilder(builder: (context, constraints) => Semantics(', 1)
    section=section.replace('mainAxisSize: MainAxisSize.min,', 'mainAxisSize: constraints.minWidth > 0 && constraints.hasBoundedWidth ? MainAxisSize.max : MainAxisSize.min,\n          mainAxisAlignment: MainAxisAlignment.center,',1)
    section=section.rsplit('    );',1)[0]+'    ));'+section.rsplit('    );',1)[1]
    return '''// Derived from pinned rosemary_ui 0.5.0 primitives.dart; MIT, see vendor license.
// Public subclass: only centre the stretched button's content row.
import 'package:flutter/material.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

'''+section

if __name__=='__main__':
    root=Path(__file__).resolve().parents[1]
    (root/'packages/rosm_passport_flutter/lib/src/centered_button.dart').write_text(derive((root/'packages/rosm_passport_flutter/vendor/rosemary_ui/lib/src/primitives.dart').read_text()))
