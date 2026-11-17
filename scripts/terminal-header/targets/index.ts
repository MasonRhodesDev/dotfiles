import type { TerminalTarget } from '../types.ts';
import { kittyTarget } from './kitty.ts';
import { weztermTarget } from './wezterm.ts';

export const TARGETS: TerminalTarget[] = [
  kittyTarget,
  weztermTarget,
];
