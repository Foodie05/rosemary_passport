#!/usr/bin/env python3
"""Verify the official Flutter release and the narrowly derived editor outline."""
import hashlib
from pathlib import Path
import tarfile

root = Path(__file__).resolve().parents[1]
vendor = root / 'packages/rosm_passport_flutter/vendor'
archive = vendor / 'rosemary-ui-0.5.0-source.tar.gz'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == 'b179c3f464f60a26a5a9d0c819b09ac68bf0f7c5ee570bd0a74e12c8eb9ffd38'
with tarfile.open(archive) as source:
    # Library resolver locks are retained in the verified original archive only.
    files = [entry for entry in source if entry.isfile() and not entry.name.endswith('/pubspec.lock')]
    for entry in files:
        assert (vendor / entry.name).read_bytes() == source.extractfile(entry).read(), entry.name

outline = (vendor / 'rosemary_ui/lib/src/field_outline.dart').read_text()
# Preserve upstream implementation exactly; replace only private imports and name.
outline = outline.replace("import 'theme.dart';", "import 'package:rosemary_ui/rosemary_ui.dart';")
outline = outline.replace("import 'generated/rosemary_tokens.dart';\n", '')
outline = outline.replace("import 'interaction_tokens.dart';\n", '')
outline = outline.replace('RosemaryFieldOutline', 'RosmFieldOutline')
adapter = (root / 'packages/rosm_passport_flutter/lib/src/forma_field_outline.dart').read_text()
assert adapter[adapter.index("import 'package:flutter/widgets.dart';"):] == outline, 'editor outline diverges from official geometry/timing'
print(f'Official Flutter release: {len(files)} files verified; editor outline unchanged')

with tarfile.open(root / 'web/vendor/rosemary/rosemary-ui-react-0.5.0.tgz') as source:
    overlay = source.extractfile('package/dist/overlays.js').read().decode().split('export function Dialog(props)')[0]
overlay = overlay.replace('import { cloneElement, useEffect, useId, useRef, useState } from "react";', 'import { useEffect, useId, useRef } from "react";')
overlay = overlay.replace('import { Button, IconButton } from "./primitives.js";\nimport { useRosemaryTheme, useRosemaryStrings } from "./theme.js";', 'import { IconButton, useRosemaryTheme, useRosemaryStrings } from "@rosemary-ui/react";')
overlay = overlay.replace('function Modal({', 'export function StartDrawer({').replace('drawer = false,', 'drawer = true,').replace('const sign = direction === "rtl" ? -1 : 1;', 'const sign = direction === "rtl" ? 1 : -1;')
adapter = (root / 'web/src/components/StartDrawer.js').read_text()
assert adapter[adapter.index('import { jsx as _jsx'):] == overlay, 'start drawer diverges from the verified modal implementation'
print('Start drawer preserves official lifecycle and uses the inline-start motion sign')
