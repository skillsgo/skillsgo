/*
 * [INPUT]: Depends on Unicode bidirectional detection from intl and Flutter text direction primitives.
 * [OUTPUT]: Provides text-direction detection for user-authored and Hub-authored content embedded in localized UI.
 * [POS]: Serves as the shared boundary between App presentation direction and independently authored dynamic content.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

TextDirection contentTextDirection(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;
