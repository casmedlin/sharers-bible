export interface Verse {
  verse: number;
  text: string;
}

export interface BibleBook {
  id: number;
  name: string;
  chapters: number;
}

export type AppTheme = 'System' | 'Light' | 'Dark' | 'Sepia';

export type SourceType = 'bundle' | 'local' | 'api';

export interface ManifestVersion {
  code: string;
  label: string;
}

export interface ManifestEntry {
  label: string;
  versions: ManifestVersion[];
}

export interface BibleData {
  books: [string, number][];
  verses: Record<string, Record<string, string[]>>;
}

export interface DBCache {
  language: string;
  version: string;
  data: BibleData;
  timestamp: number;
}
