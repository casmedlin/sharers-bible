import type { BibleData, ManifestEntry } from './types';
import { getCachedBible, cacheBible } from './db';

const API_BASE = 'https://apibible.wbem.org/api';
const MANIFEST_PATH = '/bibles/manifest.json';

let manifestCache: Record<string, ManifestEntry> | null = null;

export async function loadManifest(): Promise<Record<string, ManifestEntry>> {
  if (manifestCache) return manifestCache;
  try {
    const res = await fetch(MANIFEST_PATH);
    manifestCache = await res.json();
    return manifestCache!;
  } catch {
    return {};
  }
}

export async function fetchBibleData(
  language: string,
  version: string
): Promise<{ data: BibleData; source: 'local' | 'api' }> {
  const fromDB = await getCachedBible(language, version);
  if (fromDB) {
    return { data: fromDB, source: 'local' };
  }

  const url = `${API_BASE}/download/${language}/${version}`;
  const res = await fetch(url, { credentials: 'omit' });
  if (!res.ok) throw new Error(`API returned ${res.status}`);

  const data: BibleData = await res.json();

  await cacheBible(language, version, data);

  return { data, source: 'api' };
}

export async function downloadAndCacheBible(language: string, version: string): Promise<void> {
  const url = `${API_BASE}/download/${language}/${version}`;
  const res = await fetch(url, { credentials: 'omit' });
  if (!res.ok) throw new Error(`API returned ${res.status}`);
  const data: BibleData = await res.json();
  await cacheBible(language, version, data);
}

export function manifestToVersions(
  manifest: Record<string, ManifestEntry>,
  language: string,
  englishNames?: Record<string, string>
): Record<string, string> {
  const entry = manifest[language];
  if (!entry) return {};
  const langLabel = entry.label;
  const result: Record<string, string> = {};
  for (const v of entry.versions) {
    const parts = v.code.split('/');
    const key = parts[1] ?? parts[0];
    if (language === 'en' && englishNames?.[key]) {
      result[key] = englishNames[key];
    } else {
      result[key] = v.label.replace(`${langLabel} — `, '');
    }
  }
  return result;
}
