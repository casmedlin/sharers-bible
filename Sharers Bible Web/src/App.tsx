import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import './App.css';
import type { BibleBook, AppTheme, BibleData, ManifestEntry } from './types';
import { loadManifest, fetchBibleData, manifestToVersions } from './api';
import localizedBooks from './localizedBooks';
import SiteFooter from './components/SiteFooter';
import { defaultBooks } from './bibleConstants';
import { englishVersionNames, englishCopyrights } from './versionData';

interface Verse {
  verse: number;
  text: string;
}

function App() {
  const { lang, version, book: bookSlug, chapter: chapterParam } = useParams();
  const navigate = useNavigate();

  const [manifest, setManifest] = useState<Record<string, ManifestEntry>>({});
  const [languages, setLanguages] = useState<Record<string, string>>({});
  
  const [selectedLanguage, setSelectedLanguage] = useState(() => lang || localStorage.getItem('selectedLanguage') || 'en');
  const [selectedVersion, setSelectedVersion] = useState(() => version || localStorage.getItem('selectedVersion') || 'esv');
  
  const [selectedBook, setSelectedBook] = useState<BibleBook>(() => {
    if (bookSlug) {
      const match = defaultBooks.find(b => b.name.toLowerCase().replace(/\s+/g, '-') === bookSlug.toLowerCase());
      if (match) return match;
    }
    const savedId = localStorage.getItem('selectedBookId');
    return (savedId ? defaultBooks.find(b => b.id === Number(savedId)) : null) || defaultBooks[42];
  });

  const [selectedChapter, setSelectedChapter] = useState(() => {
    if (chapterParam) return Number(chapterParam);
    return Number(localStorage.getItem('selectedChapter')) || 1;
  });

  const [startVerse, setStartVerse] = useState<number | ''>(() => {
    const saved = localStorage.getItem('startVerse');
    return saved ? Number(saved) : '';
  });
  const [endVerse, setEndVerse] = useState<number | ''>(() => {
    const saved = localStorage.getItem('endVerse');
    return saved ? Number(saved) : '';
  });

  const [bibleData, setBibleData] = useState<BibleData | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const [currentTheme, setCurrentTheme] = useState<AppTheme>(() => (localStorage.getItem('selectedTheme') as AppTheme) || 'System');
  const [fontSize, setFontSize] = useState(() => Number(localStorage.getItem('fontSize')) || 21);

  const [showSettings, setShowSettings] = useState(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Sync state with URL params if they exist
  useEffect(() => {
    if (lang && lang !== selectedLanguage) setSelectedLanguage(lang);
    if (version && version !== selectedVersion) setSelectedVersion(version);
    if (bookSlug) {
      const match = defaultBooks.find(b => b.name.toLowerCase().replace(/\s+/g, '-') === bookSlug.toLowerCase());
      if (match && match.id !== selectedBook.id) setSelectedBook(match);
    }
    if (chapterParam && Number(chapterParam) !== selectedChapter) setSelectedChapter(Number(chapterParam));
  }, [lang, version, bookSlug, chapterParam]);

  // Update URL when selection changes
  const updateUrl = (l: string, v: string, b: BibleBook, c: number) => {
    const slug = b.name.toLowerCase().replace(/\s+/g, '-');
    navigate(`/read/${l}/${v}/${slug}/${c}`, { replace: true });
  };

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', currentTheme.toLowerCase());
  }, [currentTheme]);

  useEffect(() => {
    loadManifest().then(m => {
      setManifest(m);
      const langs: Record<string, string> = {};
      for (const [code, info] of Object.entries(m)) {
        langs[code] = info.label;
      }
      setLanguages(langs);
    });
  }, []);

  const versions = useMemo(() => manifestToVersions(manifest, selectedLanguage, englishVersionNames), [manifest, selectedLanguage]);

  const copyrights = useMemo(() => {
    const result: Record<string, string> = {};
    for (const key of Object.keys(versions)) {
      result[key] = englishCopyrights[key] ?? versions[key] ?? key;
    }
    return result;
  }, [versions]);

  useEffect(() => {
    if (Object.keys(versions).length > 0 && !versions[selectedVersion]) {
      const first = Object.keys(versions).sort()[0];
      if (first) setSelectedVersion(first);
    }
  }, [versions, selectedVersion]);

  const handleFetchData = useCallback(() => {
    if (!selectedVersion || !selectedLanguage) return;
    setIsLoading(true);
    setErrorMessage(null);

    fetchBibleData(selectedLanguage, selectedVersion)
      .then(({ data }) => {
        setBibleData(data);
        setIsLoading(false);
      })
      .catch(err => {
        setErrorMessage(err instanceof Error ? err.message : 'Failed to load bible data');
        setIsLoading(false);
      });
  }, [selectedLanguage, selectedVersion]);

  useEffect(() => {
    if (!selectedVersion || !selectedLanguage) return;
    handleFetchData();
  }, [handleFetchData, selectedLanguage, selectedVersion]);

  const chapterVerses = bibleData?.verses[String(selectedBook.id)]?.[String(selectedChapter)] ?? null;

  const maxVersesInChapter = chapterVerses?.length ?? 0;

  const verses = useMemo((): Verse[] => {
    if (!chapterVerses) return [];
    const s = Number(startVerse) || 1;
    const e = Number(endVerse) || chapterVerses.length;
    const adjustedStart = Math.max(1, s);
    const adjustedEnd = Math.min(chapterVerses.length, e < adjustedStart ? chapterVerses.length : e);
    const result: Verse[] = [];
    for (let i = adjustedStart - 1; i < adjustedEnd && i < chapterVerses.length; i++) {
      result.push({ verse: i + 1, text: chapterVerses[i].trim() });
    }
    return result;
  }, [chapterVerses, startVerse, endVerse]);

  const reference = useMemo(() => {
    if (verses.length > 0) {
      const first = verses[0].verse;
      const last = verses[verses.length - 1].verse;
      return first === last
        ? `${selectedBook.name} ${selectedChapter}:${first}`
        : `${selectedBook.name} ${selectedChapter}:${first}-${last}`;
    }
    return `${selectedBook.name} ${selectedChapter}`;
  }, [verses, selectedBook.name, selectedChapter]);

  // SEO: Update Title and Description
  useEffect(() => {
    if (verses.length > 0) {
      document.title = `${reference} | ${versions[selectedVersion] || selectedVersion} | Sharer's Bible`;
      const firstVerseText = verses[0].text.substring(0, 150);
      const metaDescription = document.querySelector('meta[name="description"]');
      if (metaDescription) {
        metaDescription.setAttribute('content', `Read ${reference}: "${firstVerseText}..." in the ${versions[selectedVersion]}. Share God's Word with Sharer's Bible.`);
      }
    } else {
      document.title = "Sharer's Bible — Read and Share God's Word";
    }
  }, [reference, selectedVersion, versions, verses]);

  useEffect(() => { localStorage.setItem('selectedLanguage', selectedLanguage); }, [selectedLanguage]);
  useEffect(() => { localStorage.setItem('selectedVersion', selectedVersion); }, [selectedVersion]);
  useEffect(() => { localStorage.setItem('selectedBookId', selectedBook.id.toString()); }, [selectedBook]);
  useEffect(() => { localStorage.setItem('selectedChapter', selectedChapter.toString()); }, [selectedChapter]);
  useEffect(() => { localStorage.setItem('startVerse', startVerse.toString()); }, [startVerse]);
  useEffect(() => { localStorage.setItem('endVerse', endVerse.toString()); }, [endVerse]);
  useEffect(() => { localStorage.setItem('selectedTheme', currentTheme); }, [currentTheme]);
  useEffect(() => { localStorage.setItem('fontSize', fontSize.toString()); }, [fontSize]);

  const handleLanguageChange = (lang: string) => {
    setSelectedLanguage(lang);
    setBibleData(null);
    const firstBook = defaultBooks[0];
    setSelectedBook(firstBook);
    setSelectedChapter(1);
    setStartVerse('');
    setEndVerse('');
    updateUrl(lang, selectedVersion, firstBook, 1);
  };

  const handleVersionChange = (ver: string) => {
    setSelectedVersion(ver);
    setBibleData(null);
    setSelectedBook(selectedBook);
    setSelectedChapter(1);
    setStartVerse('');
    setEndVerse('');
    updateUrl(selectedLanguage, ver, selectedBook, 1);
  };

  const handleBookChange = (bookId: number) => {
    const book = books.find(b => b.id === bookId);
    if (book) {
      setSelectedBook(book);
      setSelectedChapter(1);
      setStartVerse('');
      setEndVerse('');
      updateUrl(selectedLanguage, selectedVersion, book, 1);
    }
  };

  const handleChapterChange = (ch: number) => {
    setSelectedChapter(ch);
    setStartVerse('');
    setEndVerse('');
    updateUrl(selectedLanguage, selectedVersion, selectedBook, ch);
  };

  const copyToClipboard = (text: string, message: string) => {
    navigator.clipboard.writeText(text).then(() => {
      setToastMessage(message);
      setTimeout(() => setToastMessage(null), 2000);
    });
  };

  const exportToMarkdown = () => {
    const markdown = `# ${reference}\n\n` +
      verses.map(v => `### Verse ${v.verse}\n${v.text}`).join('\n\n') +
      `\n\n---\n*Source: ${versions[selectedVersion] || selectedVersion}*\n\n*${copyrights[selectedVersion] || ''}*`;
    const blob = new Blob([markdown], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${reference.replace(/:/g, '-')}.md`;
    a.click();
    URL.revokeObjectURL(url);
    setToastMessage('Exported to Markdown!');
    setTimeout(() => setToastMessage(null), 2000);
  };

  const exportToHtml = () => {
    const isDark = currentTheme === 'Dark' || (currentTheme === 'System' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    const isSepia = currentTheme === 'Sepia';
    let bgColor = '#ffffff';
    let textColor = '#000000';
    if (isDark) { bgColor = '#1a1a1a'; textColor = '#f5f5f7'; }
    else if (isSepia) { bgColor = '#f5f0e0'; textColor = '#433422'; }

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${reference}</title>
<style>
  body { background: ${bgColor}; color: ${textColor}; font-family: 'Iowan Old Style', 'Palatino', 'Georgia', serif; max-width: 700px; margin: 40px auto; padding: 0 20px; line-height: 1.7; }
  h1 { font-size: 42px; font-weight: 800; margin-bottom: 48px; }
  .verse { margin-bottom: 8px; }
  .vnum { font-weight: 700; font-size: 13px; color: #007aff; margin-right: 8px; }
  .footer { margin-top: 80px; padding-top: 40px; border-top: 1px solid ${isDark ? 'rgba(255,255,255,0.15)' : 'rgba(0,0,0,0.1)'}; font-style: italic; font-size: 14px; }
</style>
</head>
<body>
<h1>${reference}</h1>
${verses.map(v => `<div class="verse"><span class="vnum">${v.verse}</span>${v.text}</div>`).join('\n')}
<div class="footer">
  <p><strong>${reference} (${selectedVersion})</strong></p>
  <p>${copyrights[selectedVersion] || ''}</p>
  <p>Generated by Sharer's Bible</p>
</div>
</body>
</html>`;

    const blob = new Blob([html], { type: 'text/html' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${reference.replace(/:/g, '-')}.html`;
    a.click();
    URL.revokeObjectURL(url);
    setToastMessage('Exported to HTML!');
    setTimeout(() => setToastMessage(null), 2000);
  };

  const books = useMemo(() => {
    if (bibleData?.books && bibleData.books.length > 0) {
      const localizedNames = localizedBooks[selectedLanguage];
      return bibleData.books.map((entry, index) => ({
        id: index + 1,
        name: localizedNames?.[index] ?? (Array.isArray(entry) ? String(entry[0]) : ''),
        chapters: Array.isArray(entry) ? Number(entry[1]) : 0
      }));
    }
    const localizedNames = localizedBooks[selectedLanguage];
    if (localizedNames && localizedNames.length === defaultBooks.length) {
      return defaultBooks.map((b, i) => ({ ...b, name: localizedNames[i] }));
    }
    return defaultBooks;
  }, [bibleData, selectedLanguage]);

  useEffect(() => {
    const match = books.find(b => b.id === selectedBook.id);
    if (match) {
      if (match.name !== selectedBook.name) {
        setSelectedBook(match);
      }
    } else if (books.length > 0) {
      setSelectedBook(books[0]);
    }
  }, [books, selectedBook.id, selectedBook.name]);

  return (
    <div className="app-container" style={{ '--reading-font-size': `${fontSize}px` } as React.CSSProperties}>
      <header className="top-bar">
        <div className="header-content">
          <div className="top-bar-scroll-area">
            <div className="control-group language-picker">
              <span className="control-label">Language</span>
              <select value={selectedLanguage} onChange={(e) => handleLanguageChange(e.target.value)}>
                {Object.entries(languages).sort((a, b) => a[1].localeCompare(b[1])).map(([code, label]) => (
                  <option key={code} value={code}>{label}</option>
                ))}
              </select>
            </div>

            <div className="divider" />

            <div className="control-group">
              <span className="control-label">Translation</span>
              <select value={selectedVersion} onChange={(e) => handleVersionChange(e.target.value)}>
                {Object.entries(versions).sort((a, b) => a[1].localeCompare(b[1])).map(([key, label]) => (
                  <option key={key} value={key}>{label}</option>
                ))}
              </select>
            </div>

            <div className="divider" />

            <div className="control-group">
              <span className="control-label">Book</span>
              <select value={selectedBook.id} onChange={(e) => handleBookChange(Number(e.target.value))}>
                {books.map(b => (
                  <option key={b.id} value={b.id}>{b.name}</option>
                ))}
              </select>
            </div>

            <div className="control-group">
              <span className="control-label">Chapter</span>
              <select value={selectedChapter} onChange={(e) => handleChapterChange(Number(e.target.value))}>
                {Array.from({ length: selectedBook.chapters }, (_, i) => i + 1).map(c => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>

            <div className="divider" />

            <div className="control-group">
              <span className="control-label">Verses</span>
              <div style={{ display: 'flex', gap: '5px', alignItems: 'center' }}>
                <input
                  type="number"
                  placeholder="1"
                  style={{ width: '48px' }}
                  value={startVerse}
                  onChange={(e) => setStartVerse(e.target.value ? Number(e.target.value) : '')}
                  min={1}
                  max={maxVersesInChapter || undefined}
                />
                <span style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>-</span>
                <input
                  type="number"
                  placeholder="All"
                  style={{ width: '48px' }}
                  value={endVerse}
                  onChange={(e) => setEndVerse(e.target.value ? Number(e.target.value) : '')}
                  min={1}
                  max={maxVersesInChapter || undefined}
                />
              </div>
            </div>

            <button className="btn" onClick={handleFetchData} title="Refresh Passage">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                <path d="M23 4v6h-6M1 20v-6h6M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
              </svg>
              <span>Refresh</span>
            </button>
          </div>

          <div className="actions-group">
            {verses.length > 0 && (
              <>
                <button className="btn btn-primary" onClick={() => {
                  const fullText = verses.map(v => `${v.verse}. ${v.text}`).join('\n\n') + `\n\n${reference}`;
                  copyToClipboard(fullText, 'Passage copied!');
                }}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                  </svg>
                  <span>Copy</span>
                </button>
                <button className="btn" onClick={exportToMarkdown}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3" />
                  </svg>
                  <span>Export MD</span>
                </button>
                <button className="btn" onClick={exportToHtml}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3" />
                  </svg>
                  <span>Export HTML</span>
                </button>
              </>
            )}

            <button className="btn" onClick={() => setShowSettings(!showSettings)}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="12" cy="12" r="3" />
                <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />
              </svg>
              <span>Settings</span>
            </button>
          </div>
        </div>

        {showSettings && (
          <div className="settings-overlay">
            <h3 style={{ margin: '0 0 24px 0', fontSize: '24px', fontWeight: 800 }}>Settings</h3>

            <div className="control-group" style={{ marginBottom: '24px' }}>
              <span className="control-label">Appearance</span>
              <div className="theme-selector" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginTop: '10px' }}>
                {['System', 'Light', 'Dark', 'Sepia'].map(t => (
                  <button
                    key={t}
                    className={`btn ${currentTheme === t ? 'btn-primary' : ''}`}
                    onClick={() => setCurrentTheme(t as AppTheme)}
                    style={{ height: '44px', justifyContent: 'center' }}
                  >
                    {t}
                  </button>
                ))}
              </div>
            </div>

            <div className="control-group" style={{ marginBottom: '24px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span className="control-label">Font Size</span>
                <span style={{ fontSize: '16px', fontWeight: 'bold' }}>{fontSize}px</span>
              </div>
              <input type="range" min="14" max="40" value={fontSize} onChange={(e) => setFontSize(Number(e.target.value))} />
            </div>

            <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '24px', marginBottom: '24px', fontSize: '13px', color: 'var(--text-secondary)' }}>
            </div>

            <button
              className="btn btn-primary"
              style={{ width: '100%', height: '48px', fontSize: '16px' }}
              onClick={() => setShowSettings(false)}
            >
              Done
            </button>
          </div>
        )}
      </header>

      <main className="reading-area">
        {isLoading ? (
          <div style={{ textAlign: 'center', marginTop: '160px', fontWeight: 600, opacity: 0.5, fontSize: '24px' }}>
            Fetching God's Word...
          </div>
        ) : errorMessage ? (
          <div style={{ textAlign: 'center', marginTop: '120px', color: '#ff9500' }}>
            <svg width="72" height="72" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" style={{ marginBottom: '24px' }}>
              <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0zM12 9v4M12 17h.01" />
            </svg>
            <div style={{ fontSize: '28px', fontWeight: 800 }}>Unable to load passage</div>
            <div style={{ opacity: 0.7, marginTop: '12px', maxWidth: '450px', marginInline: 'auto', fontSize: '18px' }}>{errorMessage}</div>
            <button className="btn btn-primary" style={{ marginTop: '40px', padding: '0 32px', height: '48px', fontSize: '16px' }} onClick={handleFetchData}>Retry</button>
          </div>
        ) : verses.length === 0 && bibleData ? (
          <div style={{ textAlign: 'center', marginTop: '200px', opacity: 0.1 }}>
            <svg width="140" height="140" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1">
              <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
            </svg>
            <div style={{ marginTop: '32px', fontSize: '28px', fontWeight: 800 }}>Chapter not found in this version.</div>
          </div>
        ) : !bibleData && !isLoading ? (
          <div style={{ textAlign: 'center', marginTop: '200px', opacity: 0.1 }}>
            <svg width="140" height="140" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1">
              <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
            </svg>
            <div style={{ marginTop: '32px', fontSize: '28px', fontWeight: 800 }}>Choose a passage to begin.</div>
          </div>
            ) : (
          <article className="reading-content" itemScope itemType="https://schema.org/Article">
            <script type="application/ld+json">
              {JSON.stringify({
                "@context": "https://schema.org",
                "@type": "Article",
                "headline": reference,
                "description": `Read ${reference} in the ${versions[selectedVersion] || selectedVersion}.`,
                "author": {
                  "@type": "Organization",
                  "name": "Sharer's Bible"
                },
                "publisher": {
                  "@type": "Organization",
                  "name": "Sharer's Bible",
                  "logo": {
                    "@type": "ImageObject",
                    "url": "https://bible.wbem.org/bible.svg"
                  }
                },
                "mainEntityOfPage": {
                  "@type": "WebPage",
                  "@id": window.location.href
                }
              })}
            </script>
            <h1 className="reference-title" itemProp="headline" onClick={() => copyToClipboard(reference, 'Reference copied!')}>
              {reference}
            </h1>

            <div itemProp="articleBody">
              {verses.map(v => (
                <div key={v.verse} className="verse-row">
                  <span className="verse-number">{v.verse}</span>
                  <p className="verse-text" onClick={() => copyToClipboard(v.text, 'Verse copied!')}>
                    {v.text}
                  </p>
                </div>
              ))}
            </div>

            <footer className="footer">
              <div style={{ fontSize: '28px', fontWeight: 800, fontStyle: 'italic', marginBottom: '16px', color: 'var(--accent-color)' }}>
                {reference} ({selectedVersion})
              </div>
              <p className="copyright">{copyrights[selectedVersion]}</p>
            </footer>
          </article>
        )}
      </main>

      {toastMessage && (
        <div className="toast">{toastMessage}</div>
      )}
      <SiteFooter />
    </div>
  );
}

export default App;
