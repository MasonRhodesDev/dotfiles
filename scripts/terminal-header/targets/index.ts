// Terminal target registry — the input-side twin of the section registry.
// To support a new terminal: add a file here exporting a TerminalTarget
// (enumeration → PaneSnapshots), register it below, and pair it with a
// renderer under renderers/<name>/ that draws the daemon's output file.

import type { TerminalTarget } from '../types.ts';
import { kittyTarget } from './kitty.ts';
import { weztermTarget } from './wezterm.ts';

export const TARGETS: TerminalTarget[] = [
  kittyTarget,
  weztermTarget,
];
