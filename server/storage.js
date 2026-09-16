import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

export function fileStorage(path) {
  return {
    load() {
      try {
        const record = JSON.parse(readFileSync(path, 'utf8'));
        if (!record || typeof record !== 'object' || Array.isArray(record)) throw new Error('저장된 기보 형식이 올바르지 않습니다.');
        return record;
      }
      catch (error) { if (error.code === 'ENOENT') return null; throw error; }
    },
    save(record) {
      mkdirSync(dirname(path), { recursive: true });
      writeFileSync(`${path}.tmp`, JSON.stringify(record, null, 2), 'utf8');
      renameSync(`${path}.tmp`, path);
    },
  };
}
