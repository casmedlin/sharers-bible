import { useState, useEffect, useCallback } from 'react';
import './App.css';

interface Verse {
  verse: number;
  text: string;
}

interface BibleBook {
  id: number;
  name: string;
  chapters: number;
}

type AppTheme = 'System' | 'Light' | 'Dark' | 'Sepia';

const versions: Record<string, string> = {
  "ESV": "English Standard Version",
  "NIV": "New International Version",
  "KJV": "King James Version",
  "ASV": "American Standard Version",
  "NASB": "New Am. Standard Bible",
  "NRSV": "New Revised Standard",
  "WEB": "World English Bible",
  "BBE": "Basic English",
  "YLT": "Young's Literal",
  "MSG": "The Message"
};

const copyrights: Record<string, string> = {
  "ESV": "Scripture quotations are from The ESV® Bible (The Holy Bible, English Standard Version®), copyright © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. All rights reserved.",
  "NIV": "Holy Bible, New International Version®, NIV® Copyright ©1973, 1978, 1984, 2011 by Biblica, Inc.® Used by permission. All rights reserved worldwide.",
  "KJV": "King James Version (KJV) is in the public domain.",
  "ASV": "American Standard Version (ASV) is in the public domain.",
  "NASB": "Scripture taken from the NEW AMERICAN STANDARD BIBLE®, Copyright © 1960, 1962, 1963, 1968, 1971, 1972, 1973, 1975, 1977, 1995 by The Lockman Foundation. Used by permission.",
  "NRSV": "New Revised Standard Version Bible, copyright © 1989 the Division of Christian Education of the National Council of the Churches of Christ in the United States of America. Used by permission. All rights reserved.",
  "WEB": "World English Bible (WEB) is in the public domain.",
  "BBE": "Bible in Basic English (BBE) is in the public domain.",
  "YLT": "Young's Literal Translation (YLT) is in the public domain.",
  "MSG": "The Message (MSG) Copyright © 1993, 1994, 1995, 1996, 2000, 2001, 2002. Used by permission of NavPress Publishing Group."
};

const books: BibleBook[] = [
  { id: 1, name: "Genesis", chapters: 50 }, { id: 2, name: "Exodus", chapters: 40 },
  { id: 3, name: "Leviticus", chapters: 27 }, { id: 4, name: "Numbers", chapters: 36 },
  { id: 5, name: "Deuteronomy", chapters: 34 }, { id: 6, name: "Joshua", chapters: 24 },
  { id: 7, name: "Judges", chapters: 21 }, { id: 8, name: "Ruth", chapters: 4 },
  { id: 9, name: "1 Samuel", chapters: 31 }, { id: 10, name: "2 Samuel", chapters: 24 },
  { id: 11, name: "1 Kings", chapters: 22 }, { id: 12, name: "2 Kings", chapters: 25 },
  { id: 13, name: "1 Chronicles", chapters: 29 }, { id: 14, name: "2 Chronicles", chapters: 36 },
  { id: 15, name: "Ezra", chapters: 10 }, { id: 16, name: "Nehemiah", chapters: 13 },
  { id: 17, name: "Esther", chapters: 10 }, { id: 18, name: "Job", chapters: 42 },
  { id: 19, name: "Psalms", chapters: 150 }, { id: 20, name: "Proverbs", chapters: 31 },
  { id: 21, name: "Ecclesiastes", chapters: 12 }, { id: 22, name: "Song of Solomon", chapters: 8 },
  { id: 23, name: "Isaiah", chapters: 66 }, { id: 24, name: "Jeremiah", chapters: 52 },
  { id: 25, name: "Lamentations", chapters: 5 }, { id: 26, name: "Ezekiel", chapters: 48 },
  { id: 27, name: "Daniel", chapters: 12 }, { id: 28, name: "Hosea", chapters: 14 },
  { id: 29, name: "Joel", chapters: 3 }, { id: 30, name: "Amos", chapters: 9 },
  { id: 31, name: "Obadiah", chapters: 1 }, { id: 32, name: "Jonah", chapters: 4 },
  { id: 33, name: "Micah", chapters: 7 }, { id: 34, name: "Nahum", chapters: 3 },
  { id: 35, name: "Habakkuk", chapters: 3 }, { id: 36, name: "Zephaniah", chapters: 3 },
  { id: 37, name: "Haggai", chapters: 2 }, { id: 38, name: "Zechariah", chapters: 14 },
  { id: 39, name: "Malachi", chapters: 4 }, { id: 40, name: "Matthew", chapters: 28 },
  { id: 41, name: "Mark", chapters: 16 }, { id: 42, name: "Luke", chapters: 24 },
  { id: 43, name: "John", chapters: 21 }, { id: 44, name: "Acts", chapters: 28 },
  { id: 45, name: "Romans", chapters: 16 }, { id: 46, name: "1 Corinthians", chapters: 16 },
  { id: 47, name: "2 Corinthians", chapters: 13 }, { id: 48, name: "Galatians", chapters: 6 },
  { id: 49, name: "Ephesians", chapters: 6 }, { id: 50, name: "Philippians", chapters: 4 },
  { id: 51, name: "Colossians", chapters: 4 }, { id: 52, name: "1 Thessalonians", chapters: 5 },
  { id: 53, name: "2 Thessalonians", chapters: 3 }, { id: 54, name: "1 Timothy", chapters: 6 },
  { id: 55, name: "2 Timothy", chapters: 4 }, { id: 56, name: "Titus", chapters: 3 },
  { id: 57, name: "Philemon", chapters: 1 }, { id: 58, name: "Hebrews", chapters: 13 },
  { id: 59, name: "James", chapters: 5 }, { id: 60, name: "1 Peter", chapters: 5 },
  { id: 61, name: "2 Peter", chapters: 3 }, { id: 62, name: "1 John", chapters: 5 },
  { id: 63, name: "2 John", chapters: 1 }, { id: 64, name: "3 John", chapters: 1 },
  { id: 65, name: "Jude", chapters: 1 }, { id: 66, name: "Revelation", chapters: 22 }
];

function App() {
  const [selectedVersion, setSelectedVersion] = useState('ESV');
  const [selectedBook, setSelectedBook] = useState<BibleBook>(books.find(b => b.id === 43)!);
  const [selectedChapter, setSelectedChapter] = useState(1);
  const [startVerse, setStartVerse] = useState<number | ''>('');
  const [endVerse, setEndVerse] = useState<number | ''>('');
  
  const [verses, setVerses] = useState<Verse[]>([]);
  const [reference, setReference] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  
  const [currentTheme, setCurrentTheme] = useState<AppTheme>(() => (localStorage.getItem('selectedTheme') as AppTheme) || 'System');
  const [fontSize, setFontSize] = useState(() => Number(localStorage.getItem('fontSize')) || 21);
  
  const [showSettings, setShowSettings] = useState(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', currentTheme.toLowerCase());
  }, [currentTheme]);

  const fetchVerses = useCallback(async () => {
    setIsLoading(true);
    setErrorMessage(null);
    
    try {
      const url = `https://bolls.life/get-text/${selectedVersion}/${selectedBook.id}/${selectedChapter}/`;
      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to fetch passage');
      
      let data: Verse[] = await response.json();
      
      const start = Number(startVerse);
      const end = Number(endVerse);
      
      if (start > 1) {
        data = data.filter(v => v.verse >= start);
      }
      if (end > 0 && end >= (start || 1)) {
        data = data.filter(v => v.verse <= end);
      }
      
      const cleanedVerses = data.map(v => ({
        ...v,
        text: v.text.replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').trim()
      }));
      
      setVerses(cleanedVerses);
      
      if (cleanedVerses.length > 0) {
        const first = cleanedVerses[0].verse;
        const last = cleanedVerses[cleanedVerses.length - 1].verse;
        const ref = first === last 
          ? `${selectedBook.name} ${selectedChapter}:${first}`
          : `${selectedBook.name} ${selectedChapter}:${first}-${last}`;
        setReference(ref);
      } else {
        setReference(`${selectedBook.name} ${selectedChapter}`);
      }
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  }, [selectedVersion, selectedBook, selectedChapter, startVerse, endVerse]);

  useEffect(() => {
    fetchVerses();
  }, [fetchVerses]);

  useEffect(() => {
    localStorage.setItem('selectedTheme', currentTheme);
  }, [currentTheme]);

  useEffect(() => {
    localStorage.setItem('fontSize', fontSize.toString());
  }, [fontSize]);

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

  return (
    <div className="app-container" style={{ '--reading-font-size': `${fontSize}px` } as any}>
      <header className="top-bar">
        <div className="header-content">
          <div className="top-bar-scroll-area">
            <div className="control-group version-picker">
              <span className="control-label">Translation</span>
              <select value={selectedVersion} onChange={(e) => setSelectedVersion(e.target.value)}>
                {Object.keys(versions).sort().map(v => (
                  <option key={v} value={v}>{versions[v]}</option>
                ))}
              </select>
            </div>

            <div className="divider" />

            <div className="control-group">
              <span className="control-label">Book</span>
              <select 
                value={selectedBook.id} 
                onChange={(e) => {
                  const book = books.find(b => b.id === Number(e.target.value))!;
                  setSelectedBook(book);
                  setSelectedChapter(1);
                  setStartVerse('');
                  setEndVerse('');
                }}
              >
                {books.map(b => (
                  <option key={b.id} value={b.id}>{b.name}</option>
                ))}
              </select>
            </div>

            <div className="control-group">
              <span className="control-label">Chapter</span>
              <select 
                value={selectedChapter} 
                onChange={(e) => {
                  setSelectedChapter(Number(e.target.value));
                  setStartVerse('');
                  setEndVerse('');
                }}
              >
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
                />
                <span style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>-</span>
                <input 
                  type="number" 
                  placeholder="All" 
                  style={{ width: '48px' }}
                  value={endVerse}
                  onChange={(e) => setEndVerse(e.target.value ? Number(e.target.value) : '')}
                />
              </div>
            </div>

            <button className="btn" onClick={fetchVerses} title="Refresh Passage">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                <path d="M23 4v6h-6M1 20v-6h6M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
              </svg>
              <span>Refresh</span>
            </button>
          </div>

          <div className="actions-group">
            {verses.length > 0 && (
              <>
                <button 
                  className="btn btn-primary" 
                  onClick={() => {
                    const fullText = verses.map(v => `${v.verse}. ${v.text}`).join('\n\n') + `\n\n${reference}`;
                    copyToClipboard(fullText, 'Passage copied!');
                  }}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                  </svg>
                  <span>Copy</span>
                </button>
                <button className="btn" onClick={exportToMarkdown}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
                  </svg>
                  <span>Export</span>
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
            <div className="control-group" style={{ marginBottom: '32px' }}>
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
            <div className="control-group">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span className="control-label">Font Size</span>
                <span style={{ fontSize: '16px', fontWeight: 'bold' }}>{fontSize}px</span>
              </div>
              <input 
                type="range" 
                min="14" 
                max="40" 
                value={fontSize} 
                onChange={(e) => setFontSize(Number(e.target.value))} 
              />
            </div>
            <button 
              className="btn btn-primary" 
              style={{ width: '100%', marginTop: '32px', height: '48px', fontSize: '16px' }}
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
            <button className="btn btn-primary" style={{ marginTop: '40px', padding: '0 32px', height: '48px', fontSize: '16px' }} onClick={fetchVerses}>Retry</button>
          </div>
        ) : verses.length === 0 ? (
          <div style={{ textAlign: 'center', marginTop: '200px', opacity: 0.1 }}>
            <svg width="140" height="140" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1">
              <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
            </svg>
            <div style={{ marginTop: '32px', fontSize: '28px', fontWeight: 800 }}>Choose a passage to begin.</div>
          </div>
        ) : (
          <>
            <h1 
              className="reference-title" 
              onClick={() => copyToClipboard(reference, 'Reference copied!')}
            >
              {reference}
            </h1>

            {verses.map(v => (
              <div key={v.verse} className="verse-row">
                <span className="verse-number">{v.verse}</span>
                <p 
                  className="verse-text" 
                  onClick={() => copyToClipboard(v.text, 'Verse copied!')}
                >
                  {v.text}
                </p>
              </div>
            ))}

            <footer className="footer">
              <div style={{ fontSize: '28px', fontWeight: 800, fontStyle: 'italic', marginBottom: '16px', color: 'var(--accent-color)' }}>
                {reference} ({selectedVersion})
              </div>
              <p className="copyright">{copyrights[selectedVersion]}</p>
            </footer>
          </>
        )}
      </main>

      {toastMessage && (
        <div className="toast">{toastMessage}</div>
      )}
    </div>
  );
}

export default App;
