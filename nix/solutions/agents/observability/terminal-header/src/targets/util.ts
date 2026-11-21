import { accessSync, constants } from 'node:fs';
import { join } from 'node:path';

export function binaryOnPath(name: string): boolean {
  for (const dir of (process.env.PATH ?? '').split(':')) {
    if (!dir) continue;
    try {
      accessSync(join(dir, name), constants.X_OK);
      return true;
    } catch {
      continue;
    }
  }
  return false;
}
