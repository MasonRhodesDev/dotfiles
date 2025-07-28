import { readdirSync, stat } from 'fs';
import * as nodeDir from 'node-dir'

interface Dir {
    files?: string[];
    dirs?: Map<string, Dir>;
}
type DirTree = Map<string, Dir>;

class DirStructure {
    tree: Dir = {};

    addFile(parts: string[], filename: string) {
        const dir = this.addDir(parts);
        if (!dir.files) {
            dir.files = [];
        }
        dir.files.push(filename);
    }

    addDir(parts: string[]) {
        let current: Dir | undefined = this.tree;
        for (const part of parts) {
            if (!current) {
                current = {};
            }
            if (!current.dirs) {
                current.dirs = new Map();
            }
            if (!current.dirs.has(part)) {
                current.dirs.set(part, {});
            }
            current = current.dirs.get(part);
        }
        return current ?? {};
    }

    lookup(...parts: string[]): Dir | null {
        let current: Dir = this.tree;
        for (const part of parts) {
            const next = current?.dirs?.get(part);
            if (!next) {
                // returns closest match
                return current;
            }
            current = next;
        }
        return current ?? null;
    }
}

/**
 * 
 * @param dir The starting Dir
 * @param daySections 
 * @param leafHandler 
 */
export function readSourceDir(dir: string): DirStructure {
    const dirStructure = new DirStructure();
    const files = nodeDir.files(dir, { sync: true });

    for (const file of files) {
        const parts = file.replace(dir, '').split('/');
        if (parts[0] === '') {
            parts.shift();
        }
        const fileName = parts.pop();
        if (!fileName) {
            throw new Error('Internal error. Unable to get filename.');
        }

        dirStructure.addFile(parts, file);

    }

    return dirStructure;
}