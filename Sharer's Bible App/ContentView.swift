import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models
struct Verse: Codable, Identifiable {
    var id: String { "\(verse)" }
    let verse: Int
    let text: String
}

struct BibleBook: Identifiable, Hashable {
    let id: Int
    let name: String
    let chapters: Int
}

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case sepia = "Sepia"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .sepia: return .light
        default: return nil
        }
    }
}

private class SessionDelegate: NSObject, URLSessionDownloadDelegate {
    var callbacks: [Int: (progress: (Double) -> Void, completion: (Result<Data, Error>) -> Void)] = [:]
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let cb = callbacks[downloadTask.taskIdentifier] else { return }
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        DispatchQueue.main.async { cb.progress(progress) }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let cb = callbacks[downloadTask.taskIdentifier] else { return }
        do {
            let data = try Data(contentsOf: location)
            DispatchQueue.main.async { cb.completion(.success(data)) }
        } catch {
            DispatchQueue.main.async { cb.completion(.failure(error)) }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let cb = callbacks.removeValue(forKey: task.taskIdentifier) else { return }
        if let error = error {
            DispatchQueue.main.async { cb.completion(.failure(error)) }
        }
    }
}

// MARK: - ViewModel
class BibleViewModel: ObservableObject {
    @AppStorage("selectedVersion") var selectedVersion: String = "esv"
    @Published var verses: [Verse] = []
    @Published var reference: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var selectedBook: BibleBook {
        didSet {
            selectedBookId = selectedBook.id
        }
    }
    @AppStorage("selectedBookId") var selectedBookId: Int = 43
    @AppStorage("selectedChapter") var selectedChapter: Int = 1
    @AppStorage("startVerse") var startVerse: Int = 1
    @AppStorage("endVerse") var endVerse: Int = 0
    @Published var maxVersesInChapter: Int = 0
    @Published var isLoadedFromApi = false
    
    @Published var showCopiedToast: Bool = false
    @Published var toastMessage: String = ""
    
    @AppStorage("selectedTheme") var currentTheme: AppTheme = .system
    @AppStorage("fontSize") var fontSize: Double = 21.0
    @AppStorage("selectedLanguage") var selectedLanguage: String = "en"
    @Published var languages: [String: String] = ["en": "English"]
    
    @Published var versions: [String: String] = BibleViewModel.englishVersionNames
    
    static let englishVersionNames: [String: String] = [
        "akjv": "American King James Version",
        "amp": "Amplified Bible",
        "ampc": "Amplified Bible (Classic)",
        "asv": "American Standard Version",
        "brg": "BRG Bible",
        "ceb": "Common English Bible",
        "cev": "Contemporary English Version",
        "cevd": "CEV (Deuterocanon)",
        "cjb": "Complete Jewish Bible",
        "csb": "Christian Standard Bible",
        "darby": "Darby Translation",
        "dlnt": "Disciples' Literal New Testament",
        "dra": "Douay-Rheims 1899 American",
        "ehv": "EHV",
        "erv": "Easy-to-Read Version",
        "esv": "English Standard Version",
        "exb": "Expanded Bible",
        "gnt": "Good News Translation",
        "gnv": "1599 Geneva Bible",
        "gw": "God's Word Translation",
        "hcsb": "Holman Christian Standard Bible",
        "icb": "International Children's Bible",
        "isv": "International Standard Version",
        "jub": "Jubilee Bible 2000",
        "kj21": "21st Century King James Version",
        "kjv": "King James Version",
        "leb": "Lexham English Bible",
        "mev": "Modern English Version",
        "mounce": "Mounce Reverse-Interlinear NT",
        "msg": "The Message",
        "nabre": "New American Bible (Revised)",
        "nasb": "New American Standard Bible",
        "ncv": "New Century Version",
        "net": "NET Bible",
        "nirv": "New International Reader's Version",
        "niv1984": "New International Version (1984)",
        "niv2011": "New International Version (2011)",
        "nivuk": "New International Version (UK)",
        "nkjv": "New King James Version",
        "nlt": "New Living Translation",
        "nlt2013": "New Living Translation (2013)",
        "nlv": "New Life Version",
        "nog": "Names of God Bible",
        "nrsv": "New Revised Standard Version",
        "nrsva": "New Revised Standard Version (Ang)",
        "ojb": "Orthodox Jewish Bible",
        "phillips": "Phillips Translation",
        "rsv": "Revised Standard Version",
        "rsvce": "Revised Standard Version (CE)",
        "tlb": "The Living Bible",
        "tlv": "Tree of Life Version",
        "voice": "The Voice",
        "web": "World English Bible",
        "webbe": "World English Bible (British)",
        "wyc": "Wycliffe Bible",
        "ylt": "Young's Literal Translation"
    ]
    
    @Published var copyrights: [String: String] = BibleViewModel.englishCopyrights
    @Published var activeDownloads: [String: Double] = [:]
    @Published var downloadedVersions: Set<String> = []
    var isDownloading: Bool { !activeDownloads.isEmpty }
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    
    private lazy var sessionDelegate = SessionDelegate()
    private lazy var downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
    }()
    
    static let apiBaseURL = "https://apibible.wbem.org/api"
    
    static var applicationSupportBiblesPath: String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        return (paths.first ?? NSTemporaryDirectory()) + "/Sharer's Bible/bibles"
    }
    
    static let defaultBooks: [BibleBook] = [
        BibleBook(id: 1, name: "Genesis", chapters: 50), BibleBook(id: 2, name: "Exodus", chapters: 40),
        BibleBook(id: 3, name: "Leviticus", chapters: 27), BibleBook(id: 4, name: "Numbers", chapters: 36),
        BibleBook(id: 5, name: "Deuteronomy", chapters: 34), BibleBook(id: 6, name: "Joshua", chapters: 24),
        BibleBook(id: 7, name: "Judges", chapters: 21), BibleBook(id: 8, name: "Ruth", chapters: 4),
        BibleBook(id: 9, name: "1 Samuel", chapters: 31), BibleBook(id: 10, name: "2 Samuel", chapters: 24),
        BibleBook(id: 11, name: "1 Kings", chapters: 22), BibleBook(id: 12, name: "2 Kings", chapters: 25),
        BibleBook(id: 13, name: "1 Chronicles", chapters: 29), BibleBook(id: 14, name: "2 Chronicles", chapters: 36),
        BibleBook(id: 15, name: "Ezra", chapters: 10), BibleBook(id: 16, name: "Nehemiah", chapters: 13),
        BibleBook(id: 17, name: "Esther", chapters: 10), BibleBook(id: 18, name: "Job", chapters: 42),
        BibleBook(id: 19, name: "Psalms", chapters: 150), BibleBook(id: 20, name: "Proverbs", chapters: 31),
        BibleBook(id: 21, name: "Ecclesiastes", chapters: 12), BibleBook(id: 22, name: "Song of Solomon", chapters: 8),
        BibleBook(id: 23, name: "Isaiah", chapters: 66), BibleBook(id: 24, name: "Jeremiah", chapters: 52),
        BibleBook(id: 25, name: "Lamentations", chapters: 5), BibleBook(id: 26, name: "Ezekiel", chapters: 48),
        BibleBook(id: 27, name: "Daniel", chapters: 12), BibleBook(id: 28, name: "Hosea", chapters: 14),
        BibleBook(id: 29, name: "Joel", chapters: 3), BibleBook(id: 30, name: "Amos", chapters: 9),
        BibleBook(id: 31, name: "Obadiah", chapters: 1), BibleBook(id: 32, name: "Jonah", chapters: 4),
        BibleBook(id: 33, name: "Micah", chapters: 7), BibleBook(id: 34, name: "Nahum", chapters: 3),
        BibleBook(id: 35, name: "Habakkuk", chapters: 3), BibleBook(id: 36, name: "Zephaniah", chapters: 3),
        BibleBook(id: 37, name: "Haggai", chapters: 2), BibleBook(id: 38, name: "Zechariah", chapters: 14),
        BibleBook(id: 39, name: "Malachi", chapters: 4), BibleBook(id: 40, name: "Matthew", chapters: 28),
        BibleBook(id: 41, name: "Mark", chapters: 16), BibleBook(id: 42, name: "Luke", chapters: 24),
        BibleBook(id: 43, name: "John", chapters: 21), BibleBook(id: 44, name: "Acts", chapters: 28),
        BibleBook(id: 45, name: "Romans", chapters: 16), BibleBook(id: 46, name: "1 Corinthians", chapters: 16),
        BibleBook(id: 47, name: "2 Corinthians", chapters: 13), BibleBook(id: 48, name: "Galatians", chapters: 6),
        BibleBook(id: 49, name: "Ephesians", chapters: 6), BibleBook(id: 50, name: "Philippians", chapters: 4),
        BibleBook(id: 51, name: "Colossians", chapters: 4), BibleBook(id: 52, name: "1 Thessalonians", chapters: 5),
        BibleBook(id: 53, name: "2 Thessalonians", chapters: 3), BibleBook(id: 54, name: "1 Timothy", chapters: 6),
        BibleBook(id: 55, name: "2 Timothy", chapters: 4), BibleBook(id: 56, name: "Titus", chapters: 3),
        BibleBook(id: 57, name: "Philemon", chapters: 1), BibleBook(id: 58, name: "Hebrews", chapters: 13),
        BibleBook(id: 59, name: "James", chapters: 5), BibleBook(id: 60, name: "1 Peter", chapters: 5),
        BibleBook(id: 61, name: "2 Peter", chapters: 3), BibleBook(id: 62, name: "1 John", chapters: 5),
        BibleBook(id: 63, name: "2 John", chapters: 1), BibleBook(id: 64, name: "3 John", chapters: 1),
        BibleBook(id: 65, name: "Jude", chapters: 1), BibleBook(id: 66, name: "Revelation", chapters: 22)
    ]
    
    @Published var books: [BibleBook] = BibleViewModel.defaultBooks
    private var bibleCache: [String: [String: [String: [String]]]] = [:]
    
    static let englishCopyrights: [String: String] = [
        "akjv": "American King James Version (AKJV) is in the public domain.",
        "amp": "Scripture quotations taken from the Amplified® Bible, Copyright © 2015 by The Lockman Foundation. Used by permission.",
        "ampc": "Scripture quotations taken from the Amplified® Bible (Classic), Copyright © 1954, 1958, 1962, 1964, 1965, 1987 by The Lockman Foundation. Used by permission.",
        "asv": "American Standard Version (ASV) is in the public domain.",
        "brg": "BRG Bible is in the public domain.",
        "ceb": "Scripture quotations from the Common English Bible, Copyright © 2011 Common English Bible. Used by permission.",
        "cev": "Scripture quotations from the Contemporary English Version, Copyright © 1995 American Bible Society. Used by permission.",
        "cevd": "Scripture quotations from the Contemporary English Version, Copyright © 1995 American Bible Society. Used by permission.",
        "cjb": "Scripture quotations from the Complete Jewish Bible, Copyright © 1998 by David H. Stern. Used by permission.",
        "csb": "Scripture quotations from the Christian Standard Bible®, Copyright © 2017 by Holman Bible Publishers. Used by permission.",
        "darby": "Darby Translation (DARBY) is in the public domain.",
        "dlnt": "Disciples' Literal New Testament, Copyright © 2011 by Michael J. Magill. Used by permission.",
        "dra": "Douay-Rheims 1899 American Edition (DRA) is in the public domain.",
        "ehv": "Scripture quotations from the Evangelical Heritage Version, Copyright © 2019 Warburg Project. Used by permission.",
        "erv": "Scripture quotations from the Easy-to-Read Version, Copyright © 2006 by Bible League International. Used by permission.",
        "esv": "Scripture quotations are from The ESV® Bible (The Holy Bible, English Standard Version®), copyright © 2001 by Crossway, a publishing ministry of Good News Publishers. Used by permission. All rights reserved.",
        "exb": "Scripture quotations from The Expanded Bible, Copyright © 2011 by Thomas Nelson. Used by permission.",
        "gnt": "Scripture quotations from the Good News Translation, Copyright © 1992 by American Bible Society. Used by permission.",
        "gnv": "1599 Geneva Bible (GNV) is in the public domain.",
        "gw": "Scripture quotations from GOD'S WORD® Translation, Copyright © 1995 by God's Word to the Nations. Used by permission.",
        "hcsb": "Scripture quotations from the Holman Christian Standard Bible®, Copyright © 1999, 2000, 2002, 2003, 2009 by Holman Bible Publishers. Used by permission.",
        "icb": "Scripture quotations from the International Children's Bible®, Copyright © 1986, 1988, 1999 by Thomas Nelson. Used by permission.",
        "isv": "Scripture quotations from the International Standard Version, Copyright © 1995-2014 by ISV Foundation. Used by permission.",
        "jub": "Jubilee Bible 2000 (JUB) is in the public domain.",
        "kj21": "21st Century King James Version (KJ21), Copyright © 1994 by Deuel Enterprises. Used by permission.",
        "kjv": "King James Version (KJV) is in the public domain.",
        "leb": "Scripture quotations from the Lexham English Bible, Copyright © 2012 Logos Bible Software. Used by permission.",
        "mev": "Scripture quotations from the Modern English Version, Copyright © 2014 by Military Bible Association. Used by permission.",
        "mounce": "Scripture quotations from Mounce Reverse-Interlinear NT, Copyright © 2011 by William D. Mounce. Used by permission.",
        "msg": "The Message (MSG) Copyright © 1993, 1994, 1995, 1996, 2000, 2001, 2002. Used by permission of NavPress Publishing Group.",
        "nabre": "Scripture quotations from the New American Bible (Revised Edition), © 2010, 1991, 1986, 1970 Confraternity of Christian Doctrine. Used by permission.",
        "nasb": "Scripture taken from the NEW AMERICAN STANDARD BIBLE®, Copyright © 1960, 1962, 1963, 1968, 1971, 1972, 1973, 1975, 1977, 1995 by The Lockman Foundation. Used by permission.",
        "ncv": "Scripture quotations from the New Century Version®, Copyright © 2005 by Thomas Nelson. Used by permission.",
        "net": "Scripture quotations from the NET Bible®, Copyright © 1996-2016 by Biblical Studies Press. Used by permission.",
        "nirv": "Scripture quotations from the New International Reader's Version®, Copyright © 1995, 1996, 1998, 2014 by Biblica, Inc. Used by permission.",
        "niv1984": "Holy Bible, New International Version®, NIV® Copyright © 1973, 1978, 1984 by Biblica, Inc.® Used by permission. All rights reserved worldwide.",
        "niv2011": "Holy Bible, New International Version®, NIV® Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.® Used by permission. All rights reserved worldwide.",
        "nivuk": "Holy Bible, New International Version®, NIV® Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.® Used by permission. All rights reserved worldwide.",
        "nkjv": "Scripture quotations from the New King James Version®, Copyright © 1982 by Thomas Nelson. Used by permission.",
        "nlt": "Scripture quotations from the Holy Bible, New Living Translation®, Copyright © 1996, 2004, 2015 by Tyndale House Foundation. Used by permission.",
        "nlt2013": "Scripture quotations from the Holy Bible, New Living Translation®, Copyright © 1996, 2004, 2013 by Tyndale House Foundation. Used by permission.",
        "nlv": "Scripture quotations from the New Life Version, Copyright © 1969 by Christian Literature International. Used by permission.",
        "nog": "Scripture quotations from The Names of God Bible, Copyright © 2011 by Baker Publishing Group. Used by permission.",
        "nrsv": "New Revised Standard Version Bible, copyright © 1989 the Division of Christian Education of the National Council of the Churches of Christ in the United States of America. Used by permission. All rights reserved.",
        "nrsva": "New Revised Standard Version Bible, copyright © 1989 the Division of Christian Education of the National Council of the Churches of Christ in the United States of America. Used by permission. All rights reserved.",
        "ojb": "Orthodox Jewish Bible, Copyright © 2002, 2003, 2008, 2010, 2011 by Artists for Israel International. Used by permission.",
        "phillips": "Scripture quotations from the Phillips Translation, Copyright © 1960, 1986 by J.B. Phillips. Used by permission.",
        "rsv": "Revised Standard Version (RSV) is in the public domain.",
        "rsvce": "Revised Standard Version Catholic Edition (RSVCE), Copyright © 1965, 1966 by Division of Christian Education of the National Council of the Churches of Christ. Used by permission.",
        "tlb": "Scripture quotations from The Living Bible, Copyright © 1971 by Tyndale House Foundation. Used by permission.",
        "tlv": "Scripture quotations from the Tree of Life Version, Copyright © 2015 by the Messianic Jewish Family Bible Society. Used by permission.",
        "voice": "Scripture quotations from The Voice™, Copyright © 2012 by Ecclesia Bible Society. Used by permission.",
        "web": "World English Bible (WEB) is in the public domain.",
        "webbe": "World English Bible British Edition (WEBBE) is in the public domain.",
        "wyc": "Wycliffe Bible (WYC) is in the public domain.",
        "ylt": "Young's Literal Translation (YLT) is in the public domain."
    ]
    
    static let localizedLabels: [String: [String: String]] = [
        "af": [
            "addToDesign": "Voeg by ontwerp",
            "bible": "Bybel",
            "book": "Boek",
            "chapter": "Hoofstuk",
            "chapterNotFound": "Hoofstuk nie gevind in hierdie weergawe nie",
            "chapterPrefix": "Hoofstuk ",
            "chapterSuffix": "",
            "copyAllText": "Kopieer Alle Teks",
            "copyAsCsv": "Kopieer as CSV",
            "copyAsJson": "Kopieer as JSON",
            "csvCopied": "CSV gekopieer!",
            "exHtml": "Geëksporteer na HTML!",
            "exMarkdown": "Eksporteer na Markdown!",
            "exPlainText": "Geëksporteer na Plain Text!",
            "exportHtml": "Eksporteer na HTML",
            "exportMarkdown": "Eksporteer na Markdown",
            "exportPlainText": "Eksporteer na Plain Text",
            "failedToLoad": "Kon nie verse laai nie",
            "failedToSave": "Kon nie lêer stoor nie: %@",
            "fetchingWord": "Laai God se Woord...",
            "fontSize": "Lettergrootte",
            "fontSizePt": "%dpt",
            "from": "Vanaf",
            "invalidData": "Ongeldige dataformaat",
            "jsonCopied": "JSON gekopieer!",
            "language": "Taal",
            "loading": "Laai tans...",
            "passageCopied": "Hele gedeelte gekopieer!",
            "passageNotFound": "Gedeelte nie gevind nie",
            "referenceCopied": "Verwysing gekopieer!",
            "savePanelMessage": "Kies waar om jou Bybelgedeelte te stoor",
            "selectPassage": "Kies 'n boek en hoofstuk om te begin lees",
            "selectPrompt": "Kies 'n boek en hoofstuk om verse te sien",
            "settings": "Instellings",
            "share": "Deel",
            "theme": "Tema",
            "themeDark": "Donker",
            "themeLight": "Lig",
            "themeSepia": "Sepia",
            "themeSystem": "Stelsel",
            "to": "Tot",
            "verse": "Vers",
            "verseCopied": "Teks gekopieer!",
            "versePrefix": "Vers ",
            "verseSuffix": "",
            "versesOptional": "Verse (Opsioneel)",
            "version": "Weergawe"
        ],
        "ar": [
            "addToDesign": "إضافة إلى التصميم",
            "bible": "الكتاب المقدس",
            "book": "السفر",
            "chapter": "الأصحاح",
            "chapterNotFound": "لم يتم العثور على الأصحاح في هذا الإصدار",
            "chapterPrefix": "الأصحاح ",
            "chapterSuffix": "",
            "copyAllText": "نسخ كل النص",
            "copyAsCsv": "نسخ كـ CSV",
            "copyAsJson": "نسخ كـ JSON",
            "csvCopied": "تم نسخ CSV!",
            "exHtml": "تم التصدير إلى HTML!",
            "exMarkdown": "تم التصدير إلى Markdown!",
            "exPlainText": "تم التصدير إلى Plain Text!",
            "exportHtml": "تصدير إلى HTML",
            "exportMarkdown": "تصدير إلى Markdown",
            "exportPlainText": "تصدير إلى Plain Text",
            "failedToLoad": "فشل تحميل الآيات",
            "failedToSave": "فشل حفظ الملف: %@",
            "fetchingWord": "جارٍ تحميل كلمة الله...",
            "fontSize": "حجم الخط",
            "fontSizePt": "%dpt",
            "from": "من",
            "invalidData": "تنسيق بيانات غير صالح",
            "jsonCopied": "تم نسخ JSON!",
            "language": "اللغة",
            "loading": "جارٍ التحميل...",
            "passageCopied": "تم نسخ المقطع بالكامل!",
            "passageNotFound": "لم يتم العثور على المقطع",
            "referenceCopied": "تم نسخ المرجع!",
            "savePanelMessage": "اختر مكان حفظ مقطع الكتاب المقدس",
            "selectPassage": "اختر سفرًا وأصحاحًا لبدء القراءة",
            "selectPrompt": "اختر سفرًا وأصحاحًا لعرض الآيات",
            "settings": "الإعدادات",
            "share": "مشاركة",
            "theme": "المظهر",
            "themeDark": "داكن",
            "themeLight": "فاتح",
            "themeSepia": "سيبيا",
            "themeSystem": "النظام",
            "to": "إلى",
            "verse": "الآية",
            "verseCopied": "تم نسخ نص الآية!",
            "versePrefix": "الآية ",
            "verseSuffix": "",
            "versesOptional": "الآيات (اختياري)",
            "version": "الإصدار"
        ],
        "de": [
            "addToDesign": "Zum Design hinzufügen",
            "bible": "Bibel",
            "book": "Buch",
            "chapter": "Kapitel",
            "chapterNotFound": "Kapitel in dieser Übersetzung nicht gefunden",
            "chapterPrefix": "Kapitel ",
            "chapterSuffix": "",
            "copyAllText": "Gesamten Text kopieren",
            "copyAsCsv": "Als CSV kopieren",
            "copyAsJson": "Als JSON kopieren",
            "csvCopied": "CSV kopiert!",
            "exHtml": "Als HTML exportiert!",
            "exMarkdown": "Als Markdown exportiert!",
            "exPlainText": "Als Plain Text exportiert!",
            "exportHtml": "Als HTML exportieren",
            "exportMarkdown": "Als Markdown exportieren",
            "exportPlainText": "Als Plain Text exportieren",
            "failedToLoad": "Verse konnten nicht geladen werden",
            "failedToSave": "Datei konnte nicht gespeichert werden: %@",
            "fetchingWord": "Lade Gottes Wort...",
            "fontSize": "Schriftgröße",
            "fontSizePt": "%dpt",
            "from": "Von",
            "invalidData": "Ungültiges Datenformat",
            "jsonCopied": "JSON kopiert!",
            "language": "Sprache",
            "loading": "Lädt...",
            "passageCopied": "Ganze Passage kopiert!",
            "passageNotFound": "Passage nicht gefunden",
            "referenceCopied": "Referenz kopiert!",
            "savePanelMessage": "Wähle, wo die Bibelstelle gespeichert werden soll",
            "selectPassage": "Wähle ein Buch und Kapitel zum Lesen",
            "selectPrompt": "Wähle ein Buch und Kapitel, um Verse anzuzeigen",
            "settings": "Einstellungen",
            "share": "Teilen",
            "theme": "Design",
            "themeDark": "Dunkel",
            "themeLight": "Hell",
            "themeSepia": "Sepia",
            "themeSystem": "System",
            "to": "Bis",
            "verse": "Vers",
            "verseCopied": "Vers kopiert!",
            "versePrefix": "Vers ",
            "verseSuffix": "",
            "versesOptional": "Verse (optional)",
            "version": "Übersetzung"
        ],
        "en": [
            "addToDesign": "Add to design",
            "bible": "Bible",
            "book": "Book",
            "chapter": "Chapter",
            "chapterNotFound": "Chapter not found in this version",
            "chapterPrefix": "Chapter ",
            "chapterSuffix": "",
            "copyAllText": "Copy All Text",
            "copyAsCsv": "Copy as CSV",
            "copyAsJson": "Copy as JSON",
            "csvCopied": "CSV copied!",
            "exHtml": "Exported to HTML!",
            "exMarkdown": "Exported to Markdown!",
            "exPlainText": "Exported to Plain Text!",
            "exportHtml": "Export to HTML",
            "exportMarkdown": "Export to Markdown",
            "exportPlainText": "Export to Plain Text",
            "failedToLoad": "Failed to load verses",
            "failedToSave": "Failed to save file: %@",
            "fetchingWord": "Fetching God's Word...",
            "fontSize": "Font Size",
            "fontSizePt": "%dpt",
            "from": "From",
            "invalidData": "Invalid data format",
            "jsonCopied": "JSON copied!",
            "language": "Language",
            "loading": "Loading...",
            "passageCopied": "Entire passage copied!",
            "passageNotFound": "Passage not found",
            "referenceCopied": "Reference copied!",
            "savePanelMessage": "Choose where to save your Bible passage",
            "selectPassage": "Select a passage to begin reading.",
            "selectPrompt": "Select a book and chapter to view verses",
            "settings": "Settings",
            "share": "Share",
            "theme": "Theme",
            "themeDark": "Dark",
            "themeLight": "Light",
            "themeSepia": "Sepia",
            "themeSystem": "System",
            "to": "To",
            "verse": "Verse",
            "verseCopied": "Verse text copied!",
            "versePrefix": "Verse ",
            "verseSuffix": "",
            "versesOptional": "Verses (Optional)",
            "version": "Version",
            "bibleVersions": "Bible Versions",
            "download": "Download",
            "downloadComplete": "Download Complete!",
            "downloadLanguage": "Download All Versions",
            "downloadManager": "Download Manager",
            "downloadVersion": "Download Version",
            "downloaded": "Downloaded",
            "downloading": "Downloading...",
            "deleteDownload": "Delete Download",
            "deleteAllDownloads": "Delete All",
            "notAvailableOffline": "Not available offline. Download this version in Settings."
        ],
        "es": [
            "addToDesign": "Agregar al diseño",
            "bible": "Biblia",
            "book": "Libro",
            "chapter": "Capítulo",
            "chapterNotFound": "Capítulo no encontrado en esta versión",
            "chapterPrefix": "Capítulo ",
            "chapterSuffix": "",
            "copyAllText": "Copiar todo el texto",
            "copyAsCsv": "Copiar como CSV",
            "copyAsJson": "Copiar como JSON",
            "csvCopied": "¡CSV copiado!",
            "exHtml": "¡Exportado a HTML!",
            "exMarkdown": "¡Exportado a Markdown!",
            "exPlainText": "¡Exportado a texto plano!",
            "exportHtml": "Exportar a HTML",
            "exportMarkdown": "Exportar a Markdown",
            "exportPlainText": "Exportar a texto plano",
            "failedToLoad": "Error al cargar los versículos",
            "failedToSave": "Error al guardar el archivo: %@",
            "fetchingWord": "Cargando la Palabra de Dios...",
            "fontSize": "Tamaño de fuente",
            "fontSizePt": "%dpt",
            "from": "Desde",
            "invalidData": "Formato de datos inválido",
            "jsonCopied": "¡JSON copiado!",
            "language": "Idioma",
            "loading": "Cargando...",
            "passageCopied": "¡Pasaje completo copiado!",
            "passageNotFound": "Pasaje no encontrado",
            "referenceCopied": "¡Referencia copiada!",
            "savePanelMessage": "Elige dónde guardar tu pasaje bíblico",
            "selectPassage": "Selecciona un libro y capítulo para empezar a leer",
            "selectPrompt": "Selecciona un libro y capítulo para ver los versículos",
            "settings": "Configuración",
            "share": "Compartir",
            "theme": "Tema",
            "themeDark": "Oscuro",
            "themeLight": "Claro",
            "themeSepia": "Sepia",
            "themeSystem": "Sistema",
            "to": "Hasta",
            "verse": "Versículo",
            "verseCopied": "¡Texto del versículo copiado!",
            "versePrefix": "Versículo ",
            "verseSuffix": "",
            "versesOptional": "Versículos (Opcional)",
            "version": "Versión"
        ],
        "fi": [
            "addToDesign": "Lisää suunnitteluun",
            "bible": "Raamattu",
            "book": "Kirja",
            "chapter": "Luku",
            "chapterNotFound": "Lukua ei löydy tästä käännöksestä",
            "chapterPrefix": "Luku ",
            "chapterSuffix": "",
            "copyAllText": "Kopioi koko teksti",
            "copyAsCsv": "Kopioi CSV-muodossa",
            "copyAsJson": "Kopioi JSON-muodossa",
            "csvCopied": "CSV kopioitu!",
            "exHtml": "Viety HTML-muotoon!",
            "exMarkdown": "Viety Markdown-muotoon!",
            "exPlainText": "Viety tekstimuotoon!",
            "exportHtml": "Vie HTML-muotoon",
            "exportMarkdown": "Vie Markdown-muotoon",
            "exportPlainText": "Vie tekstimuotoon",
            "failedToLoad": "Jakeiden lataus epäonnistui",
            "failedToSave": "Tiedoston tallennus epäonnistui: %@",
            "fetchingWord": "Ladataan Jumalan sanaa...",
            "fontSize": "Fonttikoko",
            "fontSizePt": "%dpt",
            "from": "Alkaen",
            "invalidData": "Virheellinen tietomuoto",
            "jsonCopied": "JSON kopioitu!",
            "language": "Kieli",
            "loading": "Ladataan...",
            "passageCopied": "Koko kohta kopioitu!",
            "passageNotFound": "Kohtaa ei löytynyt",
            "referenceCopied": "Viite kopioitu!",
            "savePanelMessage": "Valitse minne haluat tallentaa raamatunkohtasi",
            "selectPassage": "Valitse kirja ja luku aloittaaksesi lukemisen",
            "selectPrompt": "Valitse kirja ja luku nähdäksesi jakeet",
            "settings": "Asetukset",
            "share": "Jaa",
            "theme": "Teema",
            "themeDark": "Tumma",
            "themeLight": "Vaalea",
            "themeSepia": "Seepia",
            "themeSystem": "Järjestelmä",
            "to": "Saakka",
            "verse": "Jae",
            "verseCopied": "Jae kopioitu!",
            "versePrefix": "Jae ",
            "verseSuffix": "",
            "versesOptional": "Jakeet (Valinnainen)",
            "version": "Käännös"
        ],
        "fr": [
            "addToDesign": "Ajouter au design",
            "bible": "Bible",
            "book": "Livre",
            "chapter": "Chapitre",
            "chapterNotFound": "Chapitre introuvable dans cette version",
            "chapterPrefix": "Chapitre ",
            "chapterSuffix": "",
            "copyAllText": "Copier tout le texte",
            "copyAsCsv": "Copier en CSV",
            "copyAsJson": "Copier en JSON",
            "csvCopied": "CSV copié !",
            "exHtml": "Exporté en HTML !",
            "exMarkdown": "Exporté en Markdown !",
            "exPlainText": "Exporté en texte brut !",
            "exportHtml": "Exporter en HTML",
            "exportMarkdown": "Exporter en Markdown",
            "exportPlainText": "Exporter en texte brut",
            "failedToLoad": "Échec du chargement des versets",
            "failedToSave": "Échec de l'enregistrement du fichier : %@",
            "fetchingWord": "Chargement de la Parole de Dieu...",
            "fontSize": "Taille de police",
            "fontSizePt": "%dpt",
            "from": "De",
            "invalidData": "Format de données invalide",
            "jsonCopied": "JSON copié !",
            "language": "Langue",
            "loading": "Chargement...",
            "passageCopied": "Passage entier copié !",
            "passageNotFound": "Passage introuvable",
            "referenceCopied": "Référence copiée !",
            "savePanelMessage": "Choisissez où enregistrer votre passage biblique",
            "selectPassage": "Sélectionnez un livre et un chapitre pour commencer à lire",
            "selectPrompt": "Sélectionnez un livre et un chapitre pour voir les versets",
            "settings": "Paramètres",
            "share": "Partager",
            "theme": "Thème",
            "themeDark": "Sombre",
            "themeLight": "Clair",
            "themeSepia": "Sépia",
            "themeSystem": "Système",
            "to": "À",
            "verse": "Vers",
            "verseCopied": "Texte du verset copié !",
            "versePrefix": "Vers ",
            "verseSuffix": "",
            "versesOptional": "Versets (Facultatif)",
            "version": "Version"
        ],
        "he": [
            "addToDesign": "הוסף לעיצוב",
            "bible": "תנ\"ך",
            "book": "ספר",
            "chapter": "פרק",
            "chapterNotFound": "הפרק לא נמצא בגרסה זו",
            "chapterPrefix": "פרק ",
            "chapterSuffix": "",
            "copyAllText": "העתק את כל הטקסט",
            "copyAsCsv": "העתק כ-CSV",
            "copyAsJson": "העתק כ-JSON",
            "csvCopied": "CSV הועתק!",
            "exHtml": "יוצא ל-HTML!",
            "exMarkdown": "יוצא ל-Markdown!",
            "exPlainText": "יוצא לטקסט פשוט!",
            "exportHtml": "ייצא ל-HTML",
            "exportMarkdown": "ייצא ל-Markdown",
            "exportPlainText": "ייצא לטקסט פשוט",
            "failedToLoad": "טעינת הפסוקים נכשלה",
            "failedToSave": "שמירת הקובץ נכשלה: %@",
            "fetchingWord": "טוען את דבר אלוהים...",
            "fontSize": "גודל גופן",
            "fontSizePt": "%dpt",
            "from": "מ-",
            "invalidData": "פורמט נתונים לא חוקי",
            "jsonCopied": "JSON הועתק!",
            "language": "שפה",
            "loading": "טוען...",
            "passageCopied": "הקטע כולו הועתק!",
            "passageNotFound": "הקטע לא נמצא",
            "referenceCopied": "ההפניה הועתקה!",
            "savePanelMessage": "בחר היכן לשמור את קטע התנ\"ך שלך",
            "selectPassage": "בחר ספר ופרק כדי להתחיל לקרוא",
            "selectPrompt": "בחר ספר ופרק לצפייה בפסוקים",
            "settings": "הגדרות",
            "share": "שתף",
            "theme": "ערכת נושא",
            "themeDark": "כהה",
            "themeLight": "בהיר",
            "themeSepia": "ספיה",
            "themeSystem": "מערכת",
            "to": "עד",
            "verse": "פסוק",
            "verseCopied": "טקסט הפסוק הועתק!",
            "versePrefix": "פסוק ",
            "verseSuffix": "",
            "versesOptional": "פסוקים (אופציונלי)",
            "version": "גרסה"
        ],
        "hi": [
            "addToDesign": "डिज़ाइन में जोड़ें",
            "bible": "बाइबल",
            "book": "पुस्तक",
            "chapter": "अध्याय",
            "chapterNotFound": "इस संस्करण में अध्याय नहीं मिला",
            "chapterPrefix": "अध्याय ",
            "chapterSuffix": "",
            "copyAllText": "सभी टेक्स्ट कॉपी करें",
            "copyAsCsv": "CSV के रूप में कॉपी करें",
            "copyAsJson": "JSON के रूप में कॉपी करें",
            "csvCopied": "CSV कॉपी हुआ!",
            "exHtml": "HTML में निर्यात हुआ!",
            "exMarkdown": "Markdown में निर्यात किया गया!",
            "exPlainText": "Plain Text में निर्यात हुआ!",
            "exportHtml": "HTML में निर्यात करें",
            "exportMarkdown": "Markdown में निर्यात करें",
            "exportPlainText": "Plain Text में निर्यात करें",
            "failedToLoad": "पद्य लोड करने में विफल",
            "failedToSave": "फ़ाइल सहेजने में विफल: %@",
            "fetchingWord": "परमेश्वर का वचन लोड हो रहा है...",
            "fontSize": "फ़ॉन्ट आकार",
            "fontSizePt": "%dpt",
            "from": "से",
            "invalidData": "अमान्य डेटा प्रारूप",
            "jsonCopied": "JSON कॉपी हुआ!",
            "language": "भाषा",
            "loading": "लोड हो रहा है...",
            "passageCopied": "पूरा अंश कॉपी हो गया!",
            "passageNotFound": "अंश नहीं मिला",
            "referenceCopied": "संदर्भ कॉपी हो गया!",
            "savePanelMessage": "अपना बाइबल अंश सहेजने के लिए स्थान चुनें",
            "selectPassage": "पढ़ना शुरू करने के लिए कोई पुस्तक और अध्याय चुनें",
            "selectPrompt": "पद्य देखने के लिए कोई पुस्तक और अध्याय चुनें",
            "settings": "सेटिंग्स",
            "share": "शेयर करें",
            "theme": "थीम",
            "themeDark": "गहरा",
            "themeLight": "हल्का",
            "themeSepia": "सेपिया",
            "themeSystem": "सिस्टम",
            "to": "तक",
            "verse": "पद",
            "verseCopied": "पद्य टेक्स्ट कॉपी हो गया!",
            "versePrefix": "पद ",
            "verseSuffix": "",
            "versesOptional": "पद्य (वैकल्पिक)",
            "version": "संस्करण"
        ],
        "id": [
            "addToDesign": "Tambahkan ke desain",
            "bible": "Alkitab",
            "book": "Kitab",
            "chapter": "Pasal",
            "chapterNotFound": "Pasal tidak ditemukan dalam versi ini",
            "chapterPrefix": "Pasal ",
            "chapterSuffix": "",
            "copyAllText": "Salin Semua Teks",
            "copyAsCsv": "Salin sebagai CSV",
            "copyAsJson": "Salin sebagai JSON",
            "csvCopied": "CSV disalin!",
            "exHtml": "Diekspor ke HTML!",
            "exMarkdown": "Diekspor ke Markdown!",
            "exPlainText": "Diekspor ke Teks Biasa!",
            "exportHtml": "Ekspor ke HTML",
            "exportMarkdown": "Ekspor ke Markdown",
            "exportPlainText": "Ekspor ke Teks Biasa",
            "failedToLoad": "Gagal memuat ayat",
            "failedToSave": "Gagal menyimpan file: %@",
            "fetchingWord": "Memuat Firman Tuhan...",
            "fontSize": "Ukuran Huruf",
            "fontSizePt": "%dpt",
            "from": "Dari",
            "invalidData": "Format data tidak valid",
            "jsonCopied": "JSON disalin!",
            "language": "Bahasa",
            "loading": "Memuat...",
            "passageCopied": "Seluruh bagian disalin!",
            "passageNotFound": "Bagian tidak ditemukan",
            "referenceCopied": "Referensi disalin!",
            "savePanelMessage": "Pilih di mana menyimpan bagian Alkitab Anda",
            "selectPassage": "Pilih kitab dan pasal untuk mulai membaca",
            "selectPrompt": "Pilih kitab dan pasal untuk melihat ayat",
            "settings": "Pengaturan",
            "share": "Bagikan",
            "theme": "Tema",
            "themeDark": "Gelap",
            "themeLight": "Terang",
            "themeSepia": "Sepia",
            "themeSystem": "Sistem",
            "to": "Sampai",
            "verse": "Ayat",
            "verseCopied": "Teks ayat disalin!",
            "versePrefix": "Ayat ",
            "verseSuffix": "",
            "versesOptional": "Ayat (Opsional)",
            "version": "Versi"
        ],
        "it": [
            "addToDesign": "Aggiungi al progetto",
            "bible": "Bibbia",
            "book": "Libro",
            "chapter": "Capitolo",
            "chapterNotFound": "Capitolo non trovato in questa versione",
            "chapterPrefix": "Capitolo ",
            "chapterSuffix": "",
            "copyAllText": "Copia tutto il testo",
            "copyAsCsv": "Copia come CSV",
            "copyAsJson": "Copia come JSON",
            "csvCopied": "CSV copiato!",
            "exHtml": "Esportato come HTML!",
            "exMarkdown": "Esportato in Markdown!",
            "exPlainText": "Esportato come testo semplice!",
            "exportHtml": "Esporta come HTML",
            "exportMarkdown": "Esporta in Markdown",
            "exportPlainText": "Esporta come testo semplice",
            "failedToLoad": "Impossibile caricare i versetti",
            "failedToSave": "Impossibile salvare il file: %@",
            "fetchingWord": "Caricamento della Parola di Dio...",
            "fontSize": "Dimensione carattere",
            "fontSizePt": "%dpt",
            "from": "Da",
            "invalidData": "Formato dati non valido",
            "jsonCopied": "JSON copiato!",
            "language": "Lingua",
            "loading": "Caricamento...",
            "passageCopied": "Intero passo copiato!",
            "passageNotFound": "Passo non trovato",
            "referenceCopied": "Riferimento copiato!",
            "savePanelMessage": "Scegli dove salvare il tuo passo biblico",
            "selectPassage": "Seleziona un libro e un capitolo per iniziare a leggere",
            "selectPrompt": "Seleziona un libro e un capitolo per vedere i versetti",
            "settings": "Impostazioni",
            "share": "Condividi",
            "theme": "Tema",
            "themeDark": "Scuro",
            "themeLight": "Chiaro",
            "themeSepia": "Seppia",
            "themeSystem": "Sistema",
            "to": "A",
            "verse": "Versetto",
            "verseCopied": "Testo del versetto copiato!",
            "versePrefix": "Versetto ",
            "verseSuffix": "",
            "versesOptional": "Versetti (Opzionale)",
            "version": "Versione"
        ],
        "ja": [
            "addToDesign": "デザインに追加",
            "bible": "聖書",
            "book": "書名",
            "chapter": "章",
            "chapterNotFound": "この翻訳では章が見つかりません",
            "chapterPrefix": "第",
            "chapterSuffix": "章",
            "copyAllText": "すべてのテキストをコピー",
            "copyAsCsv": "CSVとしてコピー",
            "copyAsJson": "JSONとしてコピー",
            "csvCopied": "CSVをコピーしました！",
            "exHtml": "HTMLにエクスポートしました！",
            "exMarkdown": "Markdownにエクスポートしました！",
            "exPlainText": "プレーンテキストにエクスポートしました！",
            "exportHtml": "HTMLにエクスポート",
            "exportMarkdown": "Markdownにエクスポート",
            "exportPlainText": "プレーンテキストにエクスポート",
            "failedToLoad": "聖句の読み込みに失敗しました",
            "failedToSave": "ファイルの保存に失敗しました: %@",
            "fetchingWord": "神の言葉を読み込み中...",
            "fontSize": "フォントサイズ",
            "fontSizePt": "%dpt",
            "from": "から",
            "invalidData": "無効なデータ形式です",
            "jsonCopied": "JSONをコピーしました！",
            "language": "言語",
            "loading": "読み込み中...",
            "passageCopied": "全文をコピーしました！",
            "passageNotFound": "箇所が見つかりません",
            "referenceCopied": "参照をコピーしました！",
            "savePanelMessage": "聖句の保存場所を選択してください",
            "selectPassage": "書と章を選択して読書を開始",
            "selectPrompt": "書と章を選択して聖句を表示",
            "settings": "設定",
            "share": "共有",
            "theme": "テーマ",
            "themeDark": "ダーク",
            "themeLight": "ライト",
            "themeSepia": "セピア",
            "themeSystem": "システム",
            "to": "まで",
            "verse": "節",
            "verseCopied": "聖句テキストをコピーしました！",
            "versePrefix": "",
            "verseSuffix": "節",
            "versesOptional": "聖句（任意）",
            "version": "翻訳"
        ],
        "nl": [
            "addToDesign": "Toevoegen aan ontwerp",
            "bible": "Bijbel",
            "book": "Boek",
            "chapter": "Hoofdstuk",
            "chapterNotFound": "Hoofdstuk niet gevonden in deze vertaling",
            "chapterPrefix": "Hoofdstuk ",
            "chapterSuffix": "",
            "copyAllText": "Kopieer volledige tekst",
            "copyAsCsv": "Kopieer als CSV",
            "copyAsJson": "Kopieer als JSON",
            "csvCopied": "CSV gekopieerd!",
            "exHtml": "Geëxporteerd naar HTML!",
            "exMarkdown": "Geëxporteerd naar Markdown!",
            "exPlainText": "Geëxporteerd naar tekst!",
            "exportHtml": "Exporteren naar HTML",
            "exportMarkdown": "Exporteren naar Markdown",
            "exportPlainText": "Exporteren naar tekst",
            "failedToLoad": "Kon verzen niet laden",
            "failedToSave": "Kon bestand niet opslaan: %@",
            "fetchingWord": "Gods Woord laden...",
            "fontSize": "Lettergrootte",
            "fontSizePt": "%dpt",
            "from": "Van",
            "invalidData": "Ongeldig gegevensformaat",
            "jsonCopied": "JSON gekopieerd!",
            "language": "Taal",
            "loading": "Laden...",
            "passageCopied": "Hele passage gekopieerd!",
            "passageNotFound": "Passage niet gevonden",
            "referenceCopied": "Referentie gekopieerd!",
            "savePanelMessage": "Kies waar je je Bijbelpassage wilt opslaan",
            "selectPassage": "Selecteer een boek en hoofdstuk om te beginnen lezen",
            "selectPrompt": "Selecteer een boek en hoofdstuk om verzen te bekijken",
            "settings": "Instellingen",
            "share": "Delen",
            "theme": "Thema",
            "themeDark": "Donker",
            "themeLight": "Licht",
            "themeSepia": "Sepia",
            "themeSystem": "Systeem",
            "to": "Tot",
            "verse": "Vers",
            "verseCopied": "Vers tekst gekopieerd!",
            "versePrefix": "Vers ",
            "verseSuffix": "",
            "versesOptional": "Verzen (Optioneel)",
            "version": "Vertaling"
        ],
        "pl": [
            "addToDesign": "Dodaj do projektu",
            "bible": "Biblia",
            "book": "Księga",
            "chapter": "Rozdział",
            "chapterNotFound": "Nie znaleziono rozdziału w tym przekładzie",
            "chapterPrefix": "Rozdział ",
            "chapterSuffix": "",
            "copyAllText": "Skopiuj cały tekst",
            "copyAsCsv": "Kopiuj jako CSV",
            "copyAsJson": "Kopiuj jako JSON",
            "csvCopied": "CSV skopiowany!",
            "exHtml": "Wyeksportowano do HTML!",
            "exMarkdown": "Wyeksportowano do Markdown!",
            "exPlainText": "Wyeksportowano do tekstu!",
            "exportHtml": "Eksportuj do HTML",
            "exportMarkdown": "Eksportuj do Markdown",
            "exportPlainText": "Eksportuj do tekstu",
            "failedToLoad": "Nie udało się załadować wersetów",
            "failedToSave": "Nie udało się zapisać pliku: %@",
            "fetchingWord": "Ładowanie Słowa Bożego...",
            "fontSize": "Rozmiar czcionki",
            "fontSizePt": "%dpt",
            "from": "Od",
            "invalidData": "Nieprawidłowy format danych",
            "jsonCopied": "JSON skopiowany!",
            "language": "Język",
            "loading": "Ładowanie...",
            "passageCopied": "Cały fragment skopiowany!",
            "passageNotFound": "Nie znaleziono fragmentu",
            "referenceCopied": "Referencja skopiowana!",
            "savePanelMessage": "Wybierz, gdzie zapisać fragment Biblii",
            "selectPassage": "Wybierz księgę i rozdział, aby rozpocząć czytanie",
            "selectPrompt": "Wybierz księgę i rozdział, aby zobaczyć wersety",
            "settings": "Ustawienia",
            "share": "Udostępnij",
            "theme": "Motyw",
            "themeDark": "Ciemny",
            "themeLight": "Jasny",
            "themeSepia": "Sepia",
            "themeSystem": "Systemowy",
            "to": "Do",
            "verse": "Werset",
            "verseCopied": "Tekst wersetu skopiowany!",
            "versePrefix": "Werset ",
            "verseSuffix": "",
            "versesOptional": "Wersety (Opcjonalnie)",
            "version": "Przekład"
        ],
        "pt": [
            "addToDesign": "Adicionar ao design",
            "bible": "Bíblia",
            "book": "Livro",
            "chapter": "Capítulo",
            "chapterNotFound": "Capítulo não encontrado nesta versão",
            "chapterPrefix": "Capítulo ",
            "chapterSuffix": "",
            "copyAllText": "Copiar todo o texto",
            "copyAsCsv": "Copiar como CSV",
            "copyAsJson": "Copiar como JSON",
            "csvCopied": "CSV copiado!",
            "exHtml": "Exportado para HTML!",
            "exMarkdown": "Exportado para Markdown!",
            "exPlainText": "Exportado para texto simples!",
            "exportHtml": "Exportar para HTML",
            "exportMarkdown": "Exportar para Markdown",
            "exportPlainText": "Exportar para texto simples",
            "failedToLoad": "Falha ao carregar versículos",
            "failedToSave": "Falha ao salvar arquivo: %@",
            "fetchingWord": "Carregando a Palavra de Deus...",
            "fontSize": "Tamanho da fonte",
            "fontSizePt": "%dpt",
            "from": "De",
            "invalidData": "Formato de dados inválido",
            "jsonCopied": "JSON copiado!",
            "language": "Idioma",
            "loading": "Carregando...",
            "passageCopied": "Passagem inteira copiada!",
            "passageNotFound": "Passagem não encontrada",
            "referenceCopied": "Referência copiada!",
            "savePanelMessage": "Escolha onde salvar sua passagem bíblica",
            "selectPassage": "Selecione um livro e capítulo para começar a ler",
            "selectPrompt": "Selecione um livro e capítulo para ver os versículos",
            "settings": "Configurações",
            "share": "Compartilhar",
            "theme": "Tema",
            "themeDark": "Escuro",
            "themeLight": "Claro",
            "themeSepia": "Sépia",
            "themeSystem": "Sistema",
            "to": "Até",
            "verse": "Versículo",
            "verseCopied": "Texto do versículo copiado!",
            "versePrefix": "Versículo ",
            "verseSuffix": "",
            "versesOptional": "Versículos (Opcional)",
            "version": "Versão"
        ],
        "ro": [
            "addToDesign": "Adaugă la design",
            "bible": "Biblia",
            "book": "Cartea",
            "chapter": "Capitolul",
            "chapterNotFound": "Capitolul nu a fost găsit în această versiune",
            "chapterPrefix": "Capitolul ",
            "chapterSuffix": "",
            "copyAllText": "Copiază tot textul",
            "copyAsCsv": "Copiază ca CSV",
            "copyAsJson": "Copiază ca JSON",
            "csvCopied": "CSV copiat!",
            "exHtml": "Exportat ca HTML!",
            "exMarkdown": "Exportat în Markdown!",
            "exPlainText": "Exportat ca text simplu!",
            "exportHtml": "Exportă ca HTML",
            "exportMarkdown": "Exportă în Markdown",
            "exportPlainText": "Exportă ca text simplu",
            "failedToLoad": "Nu s-au putut încărca versetele",
            "failedToSave": "Nu s-a putut salva fișierul: %@",
            "fetchingWord": "Se încarcă Cuvântul lui Dumnezeu...",
            "fontSize": "Mărime font",
            "fontSizePt": "%dpt",
            "from": "De la",
            "invalidData": "Format de date invalid",
            "jsonCopied": "JSON copiat!",
            "language": "Limba",
            "loading": "Se încarcă...",
            "passageCopied": "Întregul pasaj copiat!",
            "passageNotFound": "Pasajul nu a fost găsit",
            "referenceCopied": "Referință copiată!",
            "savePanelMessage": "Alege unde să salvezi pasajul biblic",
            "selectPassage": "Selectează o carte și un capitol pentru a începe citirea",
            "selectPrompt": "Selectează o carte și un capitol pentru a vedea versetele",
            "settings": "Setări",
            "share": "Distribuie",
            "theme": "Temă",
            "themeDark": "Întunecat",
            "themeLight": "Deschis",
            "themeSepia": "Sepia",
            "themeSystem": "Sistem",
            "to": "Până la",
            "verse": "Vers",
            "verseCopied": "Textul versetului copiat!",
            "versePrefix": "Vers ",
            "verseSuffix": "",
            "versesOptional": "Versete (Opțional)",
            "version": "Versiunea"
        ],
        "ru": [
            "addToDesign": "Добавить в дизайн",
            "bible": "Библия",
            "book": "Книга",
            "chapter": "Глава",
            "chapterNotFound": "Глава не найдена в этом переводе",
            "chapterPrefix": "Глава ",
            "chapterSuffix": "",
            "copyAllText": "Копировать весь текст",
            "copyAsCsv": "Копировать как CSV",
            "copyAsJson": "Копировать как JSON",
            "csvCopied": "CSV скопирован!",
            "exHtml": "Экспортировано в HTML!",
            "exMarkdown": "Экспортировано в Markdown!",
            "exPlainText": "Экспортировано в текст!",
            "exportHtml": "Экспорт в HTML",
            "exportMarkdown": "Экспорт в Markdown",
            "exportPlainText": "Экспорт в текстовый файл",
            "failedToLoad": "Не удалось загрузить стихи",
            "failedToSave": "Не удалось сохранить файл: %@",
            "fetchingWord": "Загрузка Слова Божьего...",
            "fontSize": "Размер шрифта",
            "fontSizePt": "%dpt",
            "from": "От",
            "invalidData": "Неверный формат данных",
            "jsonCopied": "JSON скопирован!",
            "language": "Язык",
            "loading": "Загрузка...",
            "passageCopied": "Весь отрывок скопирован!",
            "passageNotFound": "Отрывок не найден",
            "referenceCopied": "Ссылка скопирована!",
            "savePanelMessage": "Выберите, куда сохранить библейский отрывок",
            "selectPassage": "Выберите книгу и главу, чтобы начать чтение",
            "selectPrompt": "Выберите книгу и главу для просмотра стихов",
            "settings": "Настройки",
            "share": "Поделиться",
            "theme": "Тема",
            "themeDark": "Тёмная",
            "themeLight": "Светлая",
            "themeSepia": "Сепия",
            "themeSystem": "Системная",
            "to": "До",
            "verse": "Стих",
            "verseCopied": "Текст стиха скопирован!",
            "versePrefix": "Стих ",
            "verseSuffix": "",
            "versesOptional": "Стихи (необязательно)",
            "version": "Перевод"
        ],
        "sw": [
            "addToDesign": "Ongeza kwenye muundo",
            "bible": "Biblia",
            "book": "Kitabu",
            "chapter": "Sura",
            "chapterNotFound": "Sura haijapatikana katika tafsiri hii",
            "chapterPrefix": "Sura ",
            "chapterSuffix": "",
            "copyAllText": "Nakili Maandishi Yote",
            "copyAsCsv": "Nakili kama CSV",
            "copyAsJson": "Nakili kama JSON",
            "csvCopied": "CSV imenakiliwa!",
            "exHtml": "Imehamishwa kwa HTML!",
            "exMarkdown": "Imehamishwa kwa Markdown!",
            "exPlainText": "Imehamishwa kwa Maandishi!",
            "exportHtml": "Hamisha kwa HTML",
            "exportMarkdown": "Hamisha kwa Markdown",
            "exportPlainText": "Hamisha kwa Maandishi",
            "failedToLoad": "Imeshindwa kupakia aya",
            "failedToSave": "Imeshindwa kuhifadhi faili: %@",
            "fetchingWord": "Inapakia Neno la Mungu...",
            "fontSize": "Ukubwa wa Herufi",
            "fontSizePt": "%dpt",
            "from": "Kutoka",
            "invalidData": "Muundo wa data si sahihi",
            "jsonCopied": "JSON imenakiliwa!",
            "language": "Lugha",
            "loading": "Inapakia...",
            "passageCopied": "Kifungu kizima kimenakiliwa!",
            "passageNotFound": "Kifungu hakijapatikana",
            "referenceCopied": "Rejea imenakiliwa!",
            "savePanelMessage": "Chagua mahali pa kuhifadhi kifungu chako cha Biblia",
            "selectPassage": "Chagua kitabu na sura kuanza kusoma",
            "selectPrompt": "Chagua kitabu na sura ili kuona aya",
            "settings": "Mipangilio",
            "share": "Shiriki",
            "theme": "Mandhari",
            "themeDark": "Giza",
            "themeLight": "Mwanga",
            "themeSepia": "Sepia",
            "themeSystem": "Mfumo",
            "to": "Hadi",
            "verse": "Aya",
            "verseCopied": "Maandishi ya aya yamenakiliwa!",
            "versePrefix": "Aya ",
            "verseSuffix": "",
            "versesOptional": "Aya (Hiari)",
            "version": "Tafsiri"
        ],
        "tl": [
            "addToDesign": "Idagdag sa disenyo",
            "bible": "Bibliya",
            "book": "Aklat",
            "chapter": "Kabanata",
            "chapterNotFound": "Hindi natagpuan ang kabanata sa bersyong ito",
            "chapterPrefix": "Kabanata ",
            "chapterSuffix": "",
            "copyAllText": "Kopyahin Lahat ng Teksto",
            "copyAsCsv": "Kopyahin bilang CSV",
            "copyAsJson": "Kopyahin bilang JSON",
            "csvCopied": "CSV ay nakopya!",
            "exHtml": "Na-export sa HTML!",
            "exMarkdown": "Na-export sa Markdown!",
            "exPlainText": "Na-export sa Plain Text!",
            "exportHtml": "I-export sa HTML",
            "exportMarkdown": "I-export sa Markdown",
            "exportPlainText": "I-export sa Plain Text",
            "failedToLoad": "Hindi na-load ang mga talata",
            "failedToSave": "Hindi na-save ang file: %@",
            "fetchingWord": "Naglo-load ng Salita ng Diyos...",
            "fontSize": "Laki ng Font",
            "fontSizePt": "%dpt",
            "from": "Mula",
            "invalidData": "Hindi wastong format ng data",
            "jsonCopied": "JSON ay nakopya!",
            "language": "Wika",
            "loading": "Naglo-load...",
            "passageCopied": "Ang buong talata ay nakopya!",
            "passageNotFound": "Hindi natagpuan ang talata",
            "referenceCopied": "Ang reference ay nakopya!",
            "savePanelMessage": "Pumili kung saan ise-save ang iyong talata sa Bibliya",
            "selectPassage": "Pumili ng aklat at kabanata upang magsimulang magbasa",
            "selectPrompt": "Pumili ng aklat at kabanata upang makita ang mga talata",
            "settings": "Mga Setting",
            "share": "Ibahagi",
            "theme": "Tema",
            "themeDark": "Madilim",
            "themeLight": "Maliwanag",
            "themeSepia": "Sepia",
            "themeSystem": "Sistema",
            "to": "Hanggang",
            "verse": "Talata",
            "verseCopied": "Ang teksto ng talata ay nakopya!",
            "versePrefix": "Talata ",
            "verseSuffix": "",
            "versesOptional": "Mga Talata (Opsyonal)",
            "version": "Bersyon"
        ],
        "vi": [
            "addToDesign": "Thêm vào thiết kế",
            "bible": "Kinh Thánh",
            "book": "Sách",
            "chapter": "Chương",
            "chapterNotFound": "Không tìm thấy chương trong phiên bản này",
            "chapterPrefix": "Chương ",
            "chapterSuffix": "",
            "copyAllText": "Sao chép toàn bộ văn bản",
            "copyAsCsv": "Sao chép dạng CSV",
            "copyAsJson": "Sao chép dạng JSON",
            "csvCopied": "Đã sao chép CSV!",
            "exHtml": "Đã xuất ra HTML!",
            "exMarkdown": "Đã xuất sang Markdown!",
            "exPlainText": "Đã xuất ra văn bản thuần!",
            "exportHtml": "Xuất ra HTML",
            "exportMarkdown": "Xuất sang Markdown",
            "exportPlainText": "Xuất ra văn bản thuần",
            "failedToLoad": "Không thể tải câu",
            "failedToSave": "Không thể lưu tệp: %@",
            "fetchingWord": "Đang tải Lời Chúa...",
            "fontSize": "Cỡ chữ",
            "fontSizePt": "%dpt",
            "from": "Từ",
            "invalidData": "Định dạng dữ liệu không hợp lệ",
            "jsonCopied": "Đã sao chép JSON!",
            "language": "Ngôn ngữ",
            "loading": "Đang tải...",
            "passageCopied": "Đã sao chép toàn bộ đoạn!",
            "passageNotFound": "Không tìm thấy đoạn",
            "referenceCopied": "Đã sao chép tham chiếu!",
            "savePanelMessage": "Chọn nơi lưu đoạn Kinh Thánh của bạn",
            "selectPassage": "Chọn sách và chương để bắt đầu đọc",
            "selectPrompt": "Chọn sách và chương để xem câu",
            "settings": "Cài đặt",
            "share": "Chia sẻ",
            "theme": "Chủ đề",
            "themeDark": "Tối",
            "themeLight": "Sáng",
            "themeSepia": "Nâu đỏ",
            "themeSystem": "Hệ thống",
            "to": "Đến",
            "verse": "Câu",
            "verseCopied": "Đã sao chép nội dung câu!",
            "versePrefix": "Câu ",
            "verseSuffix": "",
            "versesOptional": "Câu (Tùy chọn)",
            "version": "Phiên bản"
        ],
        "zh": [
            "addToDesign": "添加到设计",
            "bible": "圣经",
            "book": "书卷",
            "chapter": "章",
            "chapterNotFound": "此版本中未找到该章节",
            "chapterPrefix": "第",
            "chapterSuffix": "章",
            "copyAllText": "复制全部文本",
            "copyAsCsv": "复制为CSV",
            "copyAsJson": "复制为JSON",
            "csvCopied": "CSV已复制！",
            "exHtml": "已导出为HTML！",
            "exMarkdown": "已导出为Markdown！",
            "exPlainText": "已导出为纯文本！",
            "exportHtml": "导出为HTML",
            "exportMarkdown": "导出为Markdown",
            "exportPlainText": "导出为纯文本",
            "failedToLoad": "加载经文失败",
            "failedToSave": "保存文件失败：%@",
            "fetchingWord": "正在加载神的话语...",
            "fontSize": "字号",
            "fontSizePt": "%dpt",
            "from": "从",
            "invalidData": "无效的数据格式",
            "jsonCopied": "JSON已复制！",
            "language": "语言",
            "loading": "加载中...",
            "passageCopied": "整段已复制！",
            "passageNotFound": "未找到该段落",
            "referenceCopied": "引用已复制！",
            "savePanelMessage": "选择保存圣经段落的位置",
            "selectPassage": "选择书卷和章节开始阅读",
            "selectPrompt": "选择书卷和章节以查看经文",
            "settings": "设置",
            "share": "分享",
            "theme": "主题",
            "themeDark": "深色",
            "themeLight": "浅色",
            "themeSepia": "棕褐色",
            "themeSystem": "系统",
            "to": "至",
            "verse": "节",
            "verseCopied": "经文文本已复制！",
            "versePrefix": "",
            "verseSuffix": "节",
            "versesOptional": "经文（可选）",
            "version": "版本"
        ]
    ]
    
    static let localizedBooks: [String: [String]] = [
        "en": [
            "Genesis",
            "Exodus",
            "Leviticus",
            "Numbers",
            "Deuteronomy",
            "Joshua",
            "Judges",
            "Ruth",
            "1 Samuel",
            "2 Samuel",
            "1 Kings",
            "2 Kings",
            "1 Chronicles",
            "2 Chronicles",
            "Ezra",
            "Nehemiah",
            "Esther",
            "Job",
            "Psalms",
            "Proverbs",
            "Ecclesiastes",
            "Song of Solomon",
            "Isaiah",
            "Jeremiah",
            "Lamentations",
            "Ezekiel",
            "Daniel",
            "Hosea",
            "Joel",
            "Amos",
            "Obadiah",
            "Jonah",
            "Micah",
            "Nahum",
            "Habakkuk",
            "Zephaniah",
            "Haggai",
            "Zechariah",
            "Malachi",
            "Matthew",
            "Mark",
            "Luke",
            "John",
            "Acts",
            "Romans",
            "1 Corinthians",
            "2 Corinthians",
            "Galatians",
            "Ephesians",
            "Philippians",
            "Colossians",
            "1 Thessalonians",
            "2 Thessalonians",
            "1 Timothy",
            "2 Timothy",
            "Titus",
            "Philemon",
            "Hebrews",
            "James",
            "1 Peter",
            "2 Peter",
            "1 John",
            "2 John",
            "3 John",
            "Jude",
            "Revelation"
        ],
        "af": [
            "Genesis",
            "Eksodus",
            "Levitikus",
            "Numeri",
            "Deuteronomium",
            "Josua",
            "Rigters",
            "Rut",
            "1 Samuel",
            "2 Samuel",
            "1 Konings",
            "2 Konings",
            "1 Kronieke",
            "2 Kronieke",
            "Esra",
            "Nehemia",
            "Ester",
            "Job",
            "Psalms",
            "Spreuke",
            "Prediker",
            "Hooglied",
            "Jesaja",
            "Jeremia",
            "Klaagliedere",
            "Esegiël",
            "Daniël",
            "Hosea",
            "Joël",
            "Amos",
            "Obadja",
            "Jona",
            "Miga",
            "Nahum",
            "Habakuk",
            "Sefanja",
            "Haggai",
            "Sagaria",
            "Maleagi",
            "Matteus",
            "Markus",
            "Lukas",
            "Johannes",
            "Handelinge",
            "Romeine",
            "1 Korintiërs",
            "2 Korintiërs",
            "Galasiërs",
            "Efesiërs",
            "Filippense",
            "Kolossense",
            "1 Tessalonisense",
            "2 Tessalonisense",
            "1 Timoteus",
            "2 Timoteus",
            "Titus",
            "Filemon",
            "Hebreërs",
            "Jakobus",
            "1 Petrus",
            "2 Petrus",
            "1 Johannes",
            "2 Johannes",
            "3 Johannes",
            "Judas",
            "Openbaring"
        ],
        "ar": [
            "تكوين",
            "خروج",
            "لاويين",
            "عدد",
            "تثنية",
            "يشوع",
            "قضاة",
            "راعوث",
            "1 صموئيل",
            "2 صموئيل",
            "1 ملوك",
            "2 ملوك",
            "1 أخبار",
            "2 أخبار",
            "عزرا",
            "نحميا",
            "أستير",
            "أيوب",
            "مزامير",
            "أمثال",
            "جامعة",
            "نشيد الأنشاد",
            "إشعياء",
            "إرميا",
            "مراثي إرميا",
            "حزقيال",
            "دانيال",
            "هوشع",
            "يوئيل",
            "عاموس",
            "عوبديا",
            "يونان",
            "ميخا",
            "ناحوم",
            "حبقوق",
            "صفنيا",
            "حجي",
            "زكريا",
            "ملاخي",
            "متى",
            "مرقس",
            "لوقا",
            "يوحنا",
            "أعمال",
            "رومية",
            "1 كورنثوس",
            "2 كورنثوس",
            "غلاطية",
            "أفسس",
            "فيلبي",
            "كولوسي",
            "1 تسالونيكي",
            "2 تسالونيكي",
            "1 تيموثاوس",
            "2 تيموثاوس",
            "تيتوس",
            "فليمون",
            "عبرانيين",
            "يعقوب",
            "1 بطرس",
            "2 بطرس",
            "1 يوحنا",
            "2 يوحنا",
            "3 يوحنا",
            "يهوذا",
            "رؤيا"
        ],
        "de": [
            "1. Mose",
            "2. Mose",
            "3. Mose",
            "4. Mose",
            "5. Mose",
            "Josua",
            "Richter",
            "Rut",
            "1. Samuel",
            "2. Samuel",
            "1. Könige",
            "2. Könige",
            "1. Chronik",
            "2. Chronik",
            "Esra",
            "Nehemia",
            "Esther",
            "Hiob",
            "Psalmen",
            "Sprüche",
            "Prediger",
            "Hohelied",
            "Jesaja",
            "Jeremia",
            "Klagelieder",
            "Hesekiel",
            "Daniel",
            "Hosea",
            "Joel",
            "Amos",
            "Obadja",
            "Jona",
            "Micha",
            "Nahum",
            "Habakuk",
            "Zephanja",
            "Haggai",
            "Sacharja",
            "Maleachi",
            "Matthäus",
            "Markus",
            "Lukas",
            "Johannes",
            "Apostelgeschichte",
            "Römer",
            "1. Korinther",
            "2. Korinther",
            "Galater",
            "Epheser",
            "Philipper",
            "Kolosser",
            "1. Thessalonicher",
            "2. Thessalonicher",
            "1. Timotheus",
            "2. Timotheus",
            "Titus",
            "Philemon",
            "Hebräer",
            "Jakobus",
            "1. Petrus",
            "2. Petrus",
            "1. Johannes",
            "2. Johannes",
            "3. Johannes",
            "Judas",
            "Offenbarung"
        ],
        "es": [
            "Génesis",
            "Éxodo",
            "Levítico",
            "Números",
            "Deuteronomio",
            "Josué",
            "Jueces",
            "Rut",
            "1 Samuel",
            "2 Samuel",
            "1 Reyes",
            "2 Reyes",
            "1 Crónicas",
            "2 Crónicas",
            "Esdras",
            "Nehemías",
            "Ester",
            "Job",
            "Salmos",
            "Proverbios",
            "Eclesiastés",
            "Cantares",
            "Isaías",
            "Jeremías",
            "Lamentaciones",
            "Ezequiel",
            "Daniel",
            "Oseas",
            "Joel",
            "Amós",
            "Abdías",
            "Jonás",
            "Miqueas",
            "Nahum",
            "Habacuc",
            "Sofonías",
            "Hageo",
            "Zacarías",
            "Malaquías",
            "Mateo",
            "Marcos",
            "Lucas",
            "Juan",
            "Hechos",
            "Romanos",
            "1 Corintios",
            "2 Corintios",
            "Gálatas",
            "Efesios",
            "Filipenses",
            "Colosenses",
            "1 Tesalonicenses",
            "2 Tesalonicenses",
            "1 Timoteo",
            "2 Timoteo",
            "Tito",
            "Filemón",
            "Hebreos",
            "Santiago",
            "1 Pedro",
            "2 Pedro",
            "1 Juan",
            "2 Juan",
            "3 Juan",
            "Judas",
            "Apocalipsis"
        ],
        "fi": [
            "1. Mooseksen kirja",
            "2. Mooseksen kirja",
            "3. Mooseksen kirja",
            "4. Mooseksen kirja",
            "5. Mooseksen kirja",
            "Joosua",
            "Tuomarien kirja",
            "Ruutin kirja",
            "1. Samuelin kirja",
            "2. Samuelin kirja",
            "1. Kuninkaiden kirja",
            "2. Kuninkaiden kirja",
            "1. Aikakirja",
            "2. Aikakirja",
            "Esran kirja",
            "Nehemian kirja",
            "Esterin kirja",
            "Jobin kirja",
            "Psalmit",
            "Sananlaskut",
            "Saarnaaja",
            "Laulujen laulu",
            "Jesajan kirja",
            "Jeremian kirja",
            "Valitusvirret",
            "Hesekielin kirja",
            "Danielin kirja",
            "Hoosean kirja",
            "Joelin kirja",
            "Aamoksen kirja",
            "Obadjan kirja",
            "Joonan kirja",
            "Miikan kirja",
            "Nahumin kirja",
            "Habakukin kirja",
            "Sefanjan kirja",
            "Haggain kirja",
            "Sakarjan kirja",
            "Malakian kirja",
            "Matteuksen evankeliumi",
            "Markuksen evankeliumi",
            "Luukkaan evankeliumi",
            "Johanneksen evankeliumi",
            "Apostolien teot",
            "Roomalaiskirje",
            "1. Korinttolaiskirje",
            "2. Korinttolaiskirje",
            "Galatalaiskirje",
            "Efesolaiskirje",
            "Filippiläiskirje",
            "Kolossalaiskirje",
            "1. Tessalonikalaiskirje",
            "2. Tessalonikalaiskirje",
            "1. Timoteuskirje",
            "2. Timoteuskirje",
            "Tiituksen kirje",
            "Filemonin kirje",
            "Heprealaiskirje",
            "Jaakobin kirje",
            "1. Pietarin kirje",
            "2. Pietarin kirje",
            "1. Johanneksen kirje",
            "2. Johanneksen kirje",
            "3. Johanneksen kirje",
            "Juudaksen kirje",
            "Johanneksen ilmestys"
        ],
        "fr": [
            "Genèse",
            "Exode",
            "Lévitique",
            "Nombres",
            "Deutéronome",
            "Josué",
            "Juges",
            "Ruth",
            "1 Samuel",
            "2 Samuel",
            "1 Rois",
            "2 Rois",
            "1 Chroniques",
            "2 Chroniques",
            "Esdras",
            "Néhémie",
            "Esther",
            "Job",
            "Psaumes",
            "Proverbes",
            "Ecclésiaste",
            "Cantique des Cantiques",
            "Ésaïe",
            "Jérémie",
            "Lamentations",
            "Ézéchiel",
            "Daniel",
            "Osée",
            "Joël",
            "Amos",
            "Abdias",
            "Jonas",
            "Michée",
            "Nahum",
            "Habacuc",
            "Sophonie",
            "Aggée",
            "Zacharie",
            "Malachie",
            "Matthieu",
            "Marc",
            "Luc",
            "Jean",
            "Actes",
            "Romains",
            "1 Corinthiens",
            "2 Corinthiens",
            "Galates",
            "Éphésiens",
            "Philippiens",
            "Colossiens",
            "1 Thessaloniciens",
            "2 Thessaloniciens",
            "1 Timothée",
            "2 Timothée",
            "Tite",
            "Philémon",
            "Hébreux",
            "Jacques",
            "1 Pierre",
            "2 Pierre",
            "1 Jean",
            "2 Jean",
            "3 Jean",
            "Jude",
            "Apocalypse"
        ],
        "he": [
            "בראשית",
            "שמות",
            "ויקרא",
            "במדבר",
            "דברים",
            "יהושע",
            "שופטים",
            "רות",
            "שמואל א",
            "שמואל ב",
            "מלכים א",
            "מלכים ב",
            "דברי הימים א",
            "דברי הימים ב",
            "עזרא",
            "נחמיה",
            "אסתר",
            "איוב",
            "תהלים",
            "משלי",
            "קהלת",
            "שיר השירים",
            "ישעיהו",
            "ירמיהו",
            "איכה",
            "יחזקאל",
            "דניאל",
            "הושע",
            "יואל",
            "עמוס",
            "עובדיה",
            "יונה",
            "מיכה",
            "נחום",
            "חבקוק",
            "צפניה",
            "חגי",
            "זכריה",
            "מלאכי",
            "מתי",
            "מרקוס",
            "לוקס",
            "יוחנן",
            "מעשי השליחים",
            "אל הרומים",
            "1 אל הקורינתים",
            "2 אל הקורינתים",
            "אל הגלטים",
            "אל האפסים",
            "אל הפיליפים",
            "אל הקולוסים",
            "1 אל התסלוניקים",
            "2 אל התסלוניקים",
            "1 אל טימותיוס",
            "2 אל טימותיוס",
            "אל טיטוס",
            "אל פילימון",
            "אל העברים",
            "אגרת יעקב",
            "1 כיפא",
            "2 כיפא",
            "1 יוחנן",
            "2 יוחנן",
            "3 יוחנן",
            "אגרת יהודה",
            "חזון יוחנן"
        ],
        "hi": [
            "उत्पत्ति",
            "निर्गमन",
            "लैव्यव्यवस्था",
            "गिनती",
            "व्यवस्थाविवरण",
            "यहोशू",
            "न्यायियों",
            "रूत",
            "1 शमूएल",
            "2 शमूएल",
            "1 राजा",
            "2 राजा",
            "1 इतिहास",
            "2 इतिहास",
            "एज्रा",
            "नहेम्याह",
            "एस्तेर",
            "अय्यूब",
            "भजन संहिता",
            "नीतिवचन",
            "सभोपदेशक",
            "श्रेष्ठगीत",
            "यशायाह",
            "यिर्मयाह",
            "विलापगीत",
            "यहेजकेल",
            "दानिय्येल",
            "होशे",
            "योएल",
            "आमोस",
            "ओबद्याह",
            "योना",
            "मीका",
            "नहूम",
            "हबक्कूक",
            "सपन्याह",
            "हाग्गै",
            "जकर्याह",
            "मलाकी",
            "मत्ती",
            "मरकुस",
            "लूका",
            "यूहन्ना",
            "प्रेरितों के काम",
            "रोमियों",
            "1 कुरिन्थियों",
            "2 कुरिन्थियों",
            "गलातियों",
            "इफिसियों",
            "फिलिप्पियों",
            "कुलुस्सियों",
            "1 थिस्सलुनीकियों",
            "2 थिस्सलुनीकियों",
            "1 तीमुथियुस",
            "2 तीमुथियुस",
            "तीतुस",
            "फिलेमोन",
            "इब्रानियों",
            "याकूब",
            "1 पतरस",
            "2 पतरस",
            "1 यूहन्ना",
            "2 यूहन्ना",
            "3 यूहन्ना",
            "यहूदा",
            "प्रकाशितवाक्य"
        ],
        "id": [
            "Kejadian",
            "Keluaran",
            "Imamat",
            "Bilangan",
            "Ulangan",
            "Yosua",
            "Hakim-hakim",
            "Rut",
            "1 Samuel",
            "2 Samuel",
            "1 Raja-raja",
            "2 Raja-raja",
            "1 Tawarikh",
            "2 Tawarikh",
            "Ezra",
            "Nehemia",
            "Ester",
            "Ayub",
            "Mazmur",
            "Amsal",
            "Pengkhotbah",
            "Kidung Agung",
            "Yesaya",
            "Yeremia",
            "Ratapan",
            "Yehezkiel",
            "Daniel",
            "Hosea",
            "Yoel",
            "Amos",
            "Obaja",
            "Yunus",
            "Mikha",
            "Nahum",
            "Habakuk",
            "Zefanya",
            "Hagai",
            "Zakharia",
            "Maleakhi",
            "Matius",
            "Markus",
            "Lukas",
            "Yohanes",
            "Kisah Para Rasul",
            "Roma",
            "1 Korintus",
            "2 Korintus",
            "Galatia",
            "Efesus",
            "Filipi",
            "Kolose",
            "1 Tesalonika",
            "2 Tesalonika",
            "1 Timotius",
            "2 Timotius",
            "Titus",
            "Filemon",
            "Ibrani",
            "Yakobus",
            "1 Petrus",
            "2 Petrus",
            "1 Yohanes",
            "2 Yohanes",
            "3 Yohanes",
            "Yudas",
            "Wahyu"
        ],
        "it": [
            "Genesi",
            "Esodo",
            "Levitico",
            "Numeri",
            "Deuteronomio",
            "Giosuè",
            "Giudici",
            "Rut",
            "1 Samuele",
            "2 Samuele",
            "1 Re",
            "2 Re",
            "1 Cronache",
            "2 Cronache",
            "Esdra",
            "Neemia",
            "Ester",
            "Giobbe",
            "Salmi",
            "Proverbi",
            "Ecclesiaste",
            "Cantico dei Cantici",
            "Isaia",
            "Geremia",
            "Lamentazioni",
            "Ezechiele",
            "Daniele",
            "Osea",
            "Gioele",
            "Amos",
            "Abdia",
            "Giona",
            "Michea",
            "Naum",
            "Abacuc",
            "Sofonia",
            "Aggeo",
            "Zaccaria",
            "Malachia",
            "Matteo",
            "Marco",
            "Luca",
            "Giovanni",
            "Atti",
            "Romani",
            "1 Corinzi",
            "2 Corinzi",
            "Galati",
            "Efesini",
            "Filippesi",
            "Colossesi",
            "1 Tessalonicesi",
            "2 Tessalonicesi",
            "1 Timoteo",
            "2 Timoteo",
            "Tito",
            "Filemone",
            "Ebrei",
            "Giacomo",
            "1 Pietro",
            "2 Pietro",
            "1 Giovanni",
            "2 Giovanni",
            "3 Giovanni",
            "Giuda",
            "Apocalisse"
        ],
        "ja": [
            "創世記",
            "出エジプト記",
            "レビ記",
            "民数記",
            "申命記",
            "ヨシュア記",
            "士師記",
            "ルツ記",
            "サムエル記上",
            "サムエル記下",
            "列王記上",
            "列王記下",
            "歴代志上",
            "歴代志下",
            "エズラ記",
            "ネヘミヤ記",
            "エステル記",
            "ヨブ記",
            "詩篇",
            "箴言",
            "伝道者の書",
            "雅歌",
            "イザヤ書",
            "エレミヤ書",
            "哀歌",
            "エゼキエル書",
            "ダニエル書",
            "ホセア書",
            "ヨエル書",
            "アモス書",
            "オバデヤ書",
            "ヨナ書",
            "ミカ書",
            "ナホム書",
            "ハバクク書",
            "ゼパニヤ書",
            "ハガイ書",
            "ゼカリヤ書",
            "マラキ書",
            "マタイの福音書",
            "マルコの福音書",
            "ルカの福音書",
            "ヨハネの福音書",
            "使徒の働き",
            "ローマ人への手紙",
            "コリント人への手紙第一",
            "コリント人への手紙第二",
            "ガラテヤ人への手紙",
            "エペソ人への手紙",
            "ピリピ人への手紙",
            "コロサイ人への手紙",
            "テサロニケ人への手紙第一",
            "テサロニケ人への手紙第二",
            "テモテへの手紙第一",
            "テモテへの手紙第二",
            "テトスへの手紙",
            "ピレモンへの手紙",
            "ヘブル人への手紙",
            "ヤコブの手紙",
            "ペテロの手紙第一",
            "ペテロの手紙第二",
            "ヨハネの手紙第一",
            "ヨハネの手紙第二",
            "ヨハネの手紙第三",
            "ユダの手紙",
            "ヨハネの黙示録"
        ],
        "nl": [
            "Genesis",
            "Exodus",
            "Leviticus",
            "Numeri",
            "Deuteronomium",
            "Jozua",
            "Rechters",
            "Ruth",
            "1 Samuel",
            "2 Samuel",
            "1 Koningen",
            "2 Koningen",
            "1 Kronieken",
            "2 Kronieken",
            "Ezra",
            "Nehemia",
            "Esther",
            "Job",
            "Psalmen",
            "Spreuken",
            "Prediker",
            "Hooglied",
            "Jesaja",
            "Jeremia",
            "Klaagliederen",
            "Ezechiël",
            "Daniël",
            "Hosea",
            "Joël",
            "Amos",
            "Obadja",
            "Jona",
            "Micha",
            "Nahum",
            "Habakuk",
            "Zefanja",
            "Haggai",
            "Zacharia",
            "Maleachi",
            "Matteüs",
            "Marcus",
            "Lucas",
            "Johannes",
            "Handelingen",
            "Romeinen",
            "1 Korintiërs",
            "2 Korintiërs",
            "Galaten",
            "Efeziërs",
            "Filippenzen",
            "Kolossenzen",
            "1 Tessalonicenzen",
            "2 Tessalonicenzen",
            "1 Timoteüs",
            "2 Timoteüs",
            "Titus",
            "Filemon",
            "Hebreeën",
            "Jakobus",
            "1 Petrus",
            "2 Petrus",
            "1 Johannes",
            "2 Johannes",
            "3 Johannes",
            "Judas",
            "Openbaring"
        ],
        "pl": [
            "Księga Rodzaju",
            "Księga Wyjścia",
            "Księga Kapłańska",
            "Księga Liczb",
            "Księga Powtórzonego Prawa",
            "Księga Jozuego",
            "Księga Sędziów",
            "Księga Rut",
            "1 Księga Samuela",
            "2 Księga Samuela",
            "1 Księga Królewska",
            "2 Księga Królewska",
            "1 Księga Kronik",
            "2 Księga Kronik",
            "Księga Ezdrasza",
            "Księga Nehemiasza",
            "Księga Estery",
            "Księga Hioba",
            "Księga Psalmów",
            "Księga Przysłów",
            "Księga Koheleta",
            "Pieśń nad Pieśniami",
            "Księga Izajasza",
            "Księga Jeremiasza",
            "Lamentacje",
            "Księga Ezechiela",
            "Księga Daniela",
            "Księga Ozeasza",
            "Księga Joela",
            "Księga Amosa",
            "Księga Abdiasza",
            "Księga Jonasza",
            "Księga Micheasza",
            "Księga Nahuma",
            "Księga Habakuka",
            "Księga Sofoniasza",
            "Księga Aggeusza",
            "Księga Zachariasza",
            "Księga Malachiasza",
            "Ewangelia Mateusza",
            "Ewangelia Marka",
            "Ewangelia Łukasza",
            "Ewangelia Jana",
            "Dzieje Apostolskie",
            "List do Rzymian",
            "1 List do Koryntian",
            "2 List do Koryntian",
            "List do Galatów",
            "List do Efezjan",
            "List do Filipian",
            "List do Kolosan",
            "1 List do Tesaloniczan",
            "2 List do Tesaloniczan",
            "1 List do Tymoteusza",
            "2 List do Tymoteusza",
            "List do Tytusa",
            "List do Filemona",
            "List do Hebrajczyków",
            "List Jakuba",
            "1 List Piotra",
            "2 List Piotra",
            "1 List Jana",
            "2 List Jana",
            "3 List Jana",
            "List Judy",
            "Apokalipsa św. Jana"
        ],
        "pt": [
            "Gênesis",
            "Êxodo",
            "Levítico",
            "Números",
            "Deuteronômio",
            "Josué",
            "Juízes",
            "Rute",
            "1 Samuel",
            "2 Samuel",
            "1 Reis",
            "2 Reis",
            "1 Crônicas",
            "2 Crônicas",
            "Esdras",
            "Neemias",
            "Ester",
            "Jó",
            "Salmos",
            "Provérbios",
            "Eclesiastes",
            "Cânticos",
            "Isaías",
            "Jeremias",
            "Lamentações",
            "Ezequiel",
            "Daniel",
            "Oseias",
            "Joel",
            "Amós",
            "Obadias",
            "Jonas",
            "Miqueias",
            "Naum",
            "Habacuque",
            "Sofonias",
            "Ageu",
            "Zacarias",
            "Malaquias",
            "Mateus",
            "Marcos",
            "Lucas",
            "João",
            "Atos",
            "Romanos",
            "1 Coríntios",
            "2 Coríntios",
            "Gálatas",
            "Efésios",
            "Filipenses",
            "Colossenses",
            "1 Tessalonicenses",
            "2 Tessalonicenses",
            "1 Timóteo",
            "2 Timóteo",
            "Tito",
            "Filemom",
            "Hebreus",
            "Tiago",
            "1 Pedro",
            "2 Pedro",
            "1 João",
            "2 João",
            "3 João",
            "Judas",
            "Apocalipse"
        ],
        "ro": [
            "Geneza",
            "Exodul",
            "Leviticul",
            "Numerii",
            "Deuteronomul",
            "Iosua",
            "Judecătorii",
            "Rut",
            "1 Samuel",
            "2 Samuel",
            "1 Regi",
            "2 Regi",
            "1 Cronici",
            "2 Cronici",
            "Ezra",
            "Neemia",
            "Estera",
            "Iov",
            "Psalmii",
            "Proverbe",
            "Eclesiastul",
            "Cântarea Cântărilor",
            "Isaia",
            "Ieremia",
            "Plângerile",
            "Ezechiel",
            "Daniel",
            "Osea",
            "Ioel",
            "Amos",
            "Obadia",
            "Iona",
            "Mica",
            "Naum",
            "Habacuc",
            "Țefania",
            "Hagai",
            "Zaharia",
            "Maleahi",
            "Matei",
            "Marcu",
            "Luca",
            "Ioan",
            "Faptele Apostolilor",
            "Romani",
            "1 Corinteni",
            "2 Corinteni",
            "Galateni",
            "Efeseni",
            "Filipeni",
            "Coloseni",
            "1 Tesaloniceni",
            "2 Tesaloniceni",
            "1 Timotei",
            "2 Timotei",
            "Tit",
            "Filimon",
            "Evrei",
            "Iacov",
            "1 Petru",
            "2 Petru",
            "1 Ioan",
            "2 Ioan",
            "3 Ioan",
            "Iuda",
            "Apocalipsa"
        ],
        "ru": [
            "Бытие",
            "Исход",
            "Левит",
            "Числа",
            "Второзаконие",
            "Иисус Навин",
            "Книга Судей",
            "Книга Руфь",
            "1-я Царств",
            "2-я Царств",
            "3-я Царств",
            "4-я Царств",
            "1-я Паралипоменон",
            "2-я Паралипоменон",
            "Книга Ездры",
            "Книга Неемии",
            "Книга Есфири",
            "Книга Иова",
            "Псалтирь",
            "Книга Притчей",
            "Книга Екклесиаста",
            "Песнь Песней",
            "Книга Исаии",
            "Книга Иеремии",
            "Плач Иеремии",
            "Книга Иезекииля",
            "Книга Даниила",
            "Книга Осии",
            "Книга Иоиля",
            "Книга Амоса",
            "Книга Авдия",
            "Книга Ионы",
            "Книга Михея",
            "Книга Наума",
            "Книга Аввакума",
            "Книга Софонии",
            "Книга Аггея",
            "Книга Захарии",
            "Книга Малахии",
            "Евангелие от Матфея",
            "Евангелие от Марка",
            "Евангелие от Луки",
            "Евангелие от Иоанна",
            "Деяния апостолов",
            "Послание к Римлянам",
            "1-е послание к Коринфянам",
            "2-е послание к Коринфянам",
            "Послание к Галатам",
            "Послание к Ефесянам",
            "Послание к Филиппийцам",
            "Послание к Колоссянам",
            "1-е послание к Фессалоникийцам",
            "2-е послание к Фессалоникийцам",
            "1-е послание к Тимофею",
            "2-е послание к Тимофею",
            "Послание к Титу",
            "Послание к Филимону",
            "Послание к Евреям",
            "Послание Иакова",
            "1-е послание Петра",
            "2-е послание Петра",
            "1-е послание Иоанна",
            "2-е послание Иоанна",
            "3-е послание Иоанна",
            "Послание Иуды",
            "Откровение Иоанна Богослова"
        ],
        "sw": [
            "Mwanzo",
            "Kutoka",
            "Mambo ya Walawi",
            "Hesabu",
            "Kumbukumbu la Torati",
            "Yoshua",
            "Waamuzi",
            "Ruthu",
            "1 Samweli",
            "2 Samweli",
            "1 Wafalme",
            "2 Wafalme",
            "1 Mambo ya Nyakati",
            "2 Mambo ya Nyakati",
            "Ezra",
            "Nehemia",
            "Esta",
            "Ayubu",
            "Zaburi",
            "Mithali",
            "Mhubiri",
            "Wimbo Ulio Bora",
            "Isaya",
            "Yeremia",
            "Maombolezo",
            "Ezekieli",
            "Danieli",
            "Hosea",
            "Yoeli",
            "Amosi",
            "Obadia",
            "Yona",
            "Mika",
            "Nahumu",
            "Habakuki",
            "Sefania",
            "Hagai",
            "Zekaria",
            "Malaki",
            "Mathayo",
            "Marko",
            "Luka",
            "Yohana",
            "Matendo",
            "Waroma",
            "1 Wakorintho",
            "2 Wakorintho",
            "Wagalatia",
            "Waefeso",
            "Wafilipi",
            "Wakolosai",
            "1 Wathesalonike",
            "2 Wathesalonike",
            "1 Timotheo",
            "2 Timotheo",
            "Tito",
            "Filemon",
            "Waebrania",
            "Yakobo",
            "1 Petro",
            "2 Petro",
            "1 Yohana",
            "2 Yohana",
            "3 Yohana",
            "Yuda",
            "Ufunuo"
        ],
        "tl": [
            "Genesis",
            "Exodo",
            "Levitico",
            "Mga Bilang",
            "Deuteronomio",
            "Josue",
            "Mga Hukom",
            "Ruth",
            "1 Samuel",
            "2 Samuel",
            "1 Mga Hari",
            "2 Mga Hari",
            "1 Mga Kronika",
            "2 Mga Kronika",
            "Ezra",
            "Nehemias",
            "Ester",
            "Job",
            "Mga Awit",
            "Mga Kawikaan",
            "Ang Mangangaral",
            "Awit ni Solomon",
            "Isaias",
            "Jeremias",
            "Mga Panaghoy",
            "Ezekiel",
            "Daniel",
            "Oseas",
            "Joel",
            "Amos",
            "Obadias",
            "Jonas",
            "Mikas",
            "Nahum",
            "Habacuc",
            "Sofonias",
            "Ageo",
            "Zacarias",
            "Malakias",
            "Mateo",
            "Marcos",
            "Lucas",
            "Juan",
            "Mga Gawa",
            "Mga Taga-Roma",
            "1 Mga Taga-Corinto",
            "2 Mga Taga-Corinto",
            "Mga Taga-Galacia",
            "Mga Taga-Efeso",
            "Mga Taga-Filipos",
            "Mga Taga-Colosas",
            "1 Mga Taga-Tesalonica",
            "2 Mga Taga-Tesalonica",
            "1 Timoteo",
            "2 Timoteo",
            "Tito",
            "Filemon",
            "Mga Hebreo",
            "Santiago",
            "1 Pedro",
            "2 Pedro",
            "1 Juan",
            "2 Juan",
            "3 Juan",
            "Judas",
            "Pahayag"
        ],
        "vi": [
            "Sáng Thế Ký",
            "Xuất Ê-díp-tô Ký",
            "Lê-vi Ký",
            "Dân Số Ký",
            "Phục Truyền Luật Lệ Ký",
            "Giô-suê",
            "Các Quan Xét",
            "Ru-tơ",
            "1 Sa-mu-ên",
            "2 Sa-mu-ên",
            "1 Các Vua",
            "2 Các Vua",
            "1 Sử Ký",
            "2 Sử Ký",
            "E-xơ-ra",
            "Nê-hê-mi",
            "Ê-xơ-tê",
            "Gióp",
            "Thánh Thi",
            "Châm Ngôn",
            "Truyền Đạo",
            "Nhã Ca",
            "Ê-sai",
            "Giê-rê-mi",
            "Ca Thương",
            "Ê-xê-chi-ên",
            "Đa-ni-ên",
            "Ô-sê",
            "Giô-ên",
            "A-mốt",
            "Áp-đia",
            "Giô-na",
            "Mi-chê",
            "Na-hum",
            "Ha-ba-cúc",
            "Sô-phô-ni",
            "Ha-gai",
            "Xa-cha-ri",
            "Ma-la-chi",
            "Ma-thi-ơ",
            "Mác",
            "Lu-ca",
            "Giăng",
            "Công Vụ Các Sứ Đồ",
            "Rô-ma",
            "1 Cô-rinh-tô",
            "2 Cô-rinh-tô",
            "Ga-la-ti",
            "Ê-phê-sô",
            "Phi-líp",
            "Cô-lô-se",
            "1 Tê-sa-lô-ni-ca",
            "2 Tê-sa-lô-ni-ca",
            "1 Ti-mô-thê",
            "2 Ti-mô-thê",
            "Tít",
            "Phi-lê-môn",
            "Hê-bơ-rơ",
            "Gia-cơ",
            "1 Phi-e-rơ",
            "2 Phi-e-rơ",
            "1 Giăng",
            "2 Giăng",
            "3 Giăng",
            "Giu-đe",
            "Khải Huyền"
        ],
        "zh": [
            "创世记",
            "出埃及记",
            "利未记",
            "民数记",
            "申命记",
            "约书亚记",
            "士师记",
            "路得记",
            "撒母耳记上",
            "撒母耳记下",
            "列王纪上",
            "列王纪下",
            "历代志上",
            "历代志下",
            "以斯拉记",
            "尼希米记",
            "以斯帖记",
            "约伯记",
            "诗篇",
            "箴言",
            "传道书",
            "雅歌",
            "以赛亚书",
            "耶利米书",
            "耶利米哀歌",
            "以西结书",
            "但以理书",
            "何西阿书",
            "约珥书",
            "阿摩司书",
            "俄巴底亚书",
            "约拿书",
            "弥迦书",
            "那鸿书",
            "哈巴谷书",
            "西番雅书",
            "哈该书",
            "撒迦利亚书",
            "玛拉基书",
            "马太福音",
            "马可福音",
            "路加福音",
            "约翰福音",
            "使徒行传",
            "罗马书",
            "哥林多前书",
            "哥林多后书",
            "加拉太书",
            "以弗所书",
            "腓立比书",
            "歌罗西书",
            "帖撒罗尼迦前书",
            "帖撒罗尼迦后书",
            "提摩太前书",
            "提摩太后书",
            "提多书",
            "腓利门书",
            "希伯来书",
            "雅各书",
            "彼得前书",
            "彼得后书",
            "约翰一书",
            "约翰二书",
            "约翰三书",
            "犹大书",
            "启示录"
        ]
    ]
    
    static let localizedLanguageNames: [String: [String: String]] = [
        "af": [
            "native": "Afrikaans",
            "english": "Afrikaans"
        ],
        "akp": [
            "native": "Akposso",
            "english": "Akposso"
        ],
        "ar": [
            "native": "العربية",
            "english": "Arabic"
        ],
        "bc": [
            "native": "Bacama",
            "english": "Bacama"
        ],
        "btx": [
            "native": "Batak Karo",
            "english": "Batak Karo"
        ],
        "cb": [
            "native": "Cebuano",
            "english": "Cebuano"
        ],
        "cnh": [
            "native": "Chin (Hakha)",
            "english": "Hakha Chin"
        ],
        "cy": [
            "native": "Cheyenne",
            "english": "Cheyenne"
        ],
        "de": [
            "native": "Deutsch",
            "english": "German"
        ],
        "dt": [
            "native": "Ditammari",
            "english": "Ditammari"
        ],
        "en": [
            "native": "English",
            "english": "English"
        ],
        "es": [
            "native": "Español",
            "english": "Spanish"
        ],
        "fi": [
            "native": "Suomi",
            "english": "Finnish"
        ],
        "fr": [
            "native": "Français",
            "english": "French"
        ],
        "grc": [
            "native": "Ελληνικά",
            "english": "Greek"
        ],
        "ha": [
            "native": "Hausa",
            "english": "Hausa"
        ],
        "he": [
            "native": "עברית",
            "english": "Hebrew"
        ],
        "hi": [
            "native": "हिन्दी",
            "english": "Hindi"
        ],
        "hl": [
            "native": "Halyi",
            "english": "Halyi"
        ],
        "hr": [
            "native": "Hrvatski",
            "english": "Croatian"
        ],
        "ht": [
            "native": "Kreyòl Ayisyen",
            "english": "Haitian Creole"
        ],
        "ib": [
            "native": "Iban",
            "english": "Iban"
        ],
        "id": [
            "native": "Bahasa Indonesia",
            "english": "Indonesian"
        ],
        "ig": [
            "native": "Igbo",
            "english": "Igbo"
        ],
        "il": [
            "native": "Ilonggo",
            "english": "Hiligaynon"
        ],
        "it": [
            "native": "Italiano",
            "english": "Italian"
        ],
        "ja": [
            "native": "日本語",
            "english": "Japanese"
        ],
        "jr": [
            "native": "Jarai",
            "english": "Jarai"
        ],
        "kj": [
            "native": "Kuanyama",
            "english": "Kwanyama"
        ],
        "kp": [
            "native": "Kplɔ",
            "english": "Kplɔ"
        ],
        "kr": [
            "native": "Kanuri",
            "english": "Kanuri"
        ],
        "la": [
            "native": "Latina",
            "english": "Latin"
        ],
        "lg": [
            "native": "Luganda",
            "english": "Luganda"
        ],
        "mi": [
            "native": "Māori",
            "english": "Māori"
        ],
        "ml": [
            "native": "മലയാളം",
            "english": "Malayalam"
        ],
        "mr": [
            "native": "मराठी",
            "english": "Marathi"
        ],
        "ms": [
            "native": "Bahasa Melayu",
            "english": "Malay"
        ],
        "my": [
            "native": "မြန်မာဘာသာ",
            "english": "Burmese"
        ],
        "nb": [
            "native": "Norsk Bokmål",
            "english": "Norwegian Bokmål"
        ],
        "ne": [
            "native": "नेपाली",
            "english": "Nepali"
        ],
        "ng": [
            "native": "Ndonga",
            "english": "Ndonga"
        ],
        "nl": [
            "native": "Nederlands",
            "english": "Dutch"
        ],
        "no": [
            "native": "Norsk",
            "english": "Norwegian"
        ],
        "ns": [
            "native": "Nsenga",
            "english": "Nsenga"
        ],
        "ny": [
            "native": "Chichewa",
            "english": "Chichewa"
        ],
        "nyn": [
            "native": "Runyankore",
            "english": "Runyankore"
        ],
        "nz": [
            "native": "Nzima",
            "english": "Nzima"
        ],
        "or": [
            "native": "ଓଡ଼ିଆ",
            "english": "Odia"
        ],
        "pa": [
            "native": "ਪੰਜਾਬੀ",
            "english": "Punjabi"
        ],
        "pg": [
            "native": "Pangu",
            "english": "Pangu"
        ],
        "pl": [
            "native": "Polski",
            "english": "Polish"
        ],
        "pm": [
            "native": "Pam",
            "english": "Pam"
        ],
        "pt": [
            "native": "Português",
            "english": "Portuguese"
        ],
        "ro": [
            "native": "Română",
            "english": "Romanian"
        ],
        "ru": [
            "native": "Русский",
            "english": "Russian"
        ],
        "rw": [
            "native": "Kinyarwanda",
            "english": "Kinyarwanda"
        ],
        "sk": [
            "native": "Slovenčina",
            "english": "Slovak"
        ],
        "smk": [
            "native": "Samoan",
            "english": "Samoan"
        ],
        "sn": [
            "native": "chiShona",
            "english": "Shona"
        ],
        "so": [
            "native": "Soomaali",
            "english": "Somali"
        ],
        "sp": [
            "native": "Sango",
            "english": "Sango"
        ],
        "ss": [
            "native": "SiSwati",
            "english": "Swati"
        ],
        "sw": [
            "native": "Kiswahili",
            "english": "Swahili"
        ],
        "ta": [
            "native": "தமிழ்",
            "english": "Tamil"
        ],
        "te": [
            "native": "తెలుగు",
            "english": "Telugu"
        ],
        "th": [
            "native": "ไทย",
            "english": "Thai"
        ],
        "tl": [
            "native": "Tagalog",
            "english": "Tagalog"
        ],
        "tn": [
            "native": "Setswana",
            "english": "Tswana"
        ],
        "to": [
            "native": "Tonga",
            "english": "Tonga"
        ],
        "tr": [
            "native": "Türkçe",
            "english": "Turkish"
        ],
        "ts": [
            "native": "Xitsonga",
            "english": "Tsonga"
        ],
        "tw": [
            "native": "Twi",
            "english": "Twi"
        ],
        "ur": [
            "native": "اردو",
            "english": "Urdu"
        ],
        "ve": [
            "native": "Tshivenḓa",
            "english": "Venda"
        ],
        "vi": [
            "native": "Tiếng Việt",
            "english": "Vietnamese"
        ],
        "xh": [
            "native": "isiXhosa",
            "english": "Xhosa"
        ],
        "yo": [
            "native": "Yorùbá",
            "english": "Yoruba"
        ],
        "zh": [
            "native": "中文",
            "english": "Chinese"
        ],
        "zo": [
            "native": "Zou",
            "english": "Zou"
        ],
        "zu": [
            "native": "isiZulu",
            "english": "Zulu"
        ]
    ]
    
    func localizedString(_ key: String) -> String {
        Self.localizedLabels[selectedLanguage]?[key]
            ?? Self.localizedLabels["en"]?[key]
            ?? key
    }

    init() {
        let savedBookId = UserDefaults.standard.integer(forKey: "selectedBookId")
        let bookId = savedBookId == 0 ? 43 : savedBookId
        self.selectedBook = Self.defaultBooks.first(where: { $0.id == bookId }) ?? BibleBook(id: 43, name: "John", chapters: 21)
        if !versions.keys.contains(selectedVersion) {
            selectedVersion = "esv"
        }
        if !languages.keys.contains(selectedLanguage) {
            selectedLanguage = "en"
        }
        loadManifest()
        refreshDownloadedVersions()
    }
    
    private var localBiblesPath: String {
        "\(Self.applicationSupportBiblesPath)/\(selectedLanguage)"
    }
    
    private var bundleBiblesPath: String {
        Bundle.main.resourceURL!.appendingPathComponent("bibles/\(selectedLanguage)").path
    }
    
    func loadManifest() {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("bibles/manifest.json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var langDict: [String: String] = [:]
        for (code, info) in json {
            if let info = info as? [String: Any], let label = info["label"] as? String {
                langDict[code] = label
            }
        }
        languages = langDict
        updateVersionsForLanguage()
    }
    
    func updateVersionsForLanguage() {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("bibles/manifest.json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let langInfo = json[selectedLanguage] as? [String: Any],
              let versionList = langInfo["versions"] as? [[String: Any]] else { return }
        
        var newVersions: [String: String] = [:]
        var newCopyrights: [String: String] = [:]
        let langLabel = langInfo["label"] as? String ?? ""
        for v in versionList {
            if let code = v["code"] as? String,
               let label = v["label"] as? String {
                let parts = code.split(separator: "/").map(String.init)
                guard parts.count == 2 else { continue }
                let key = parts[1]
                if selectedLanguage == "en", let properName = Self.englishVersionNames[key] {
                    newVersions[key] = properName
                } else {
                    let cleanLabel = label.replacingOccurrences(of: "\(langLabel) — ", with: "")
                    newVersions[key] = cleanLabel
                }
                if selectedLanguage == "en", let existingCopyright = Self.englishCopyrights[key] {
                    newCopyrights[key] = existingCopyright
                } else {
                    newCopyrights[key] = newVersions[key] ?? label
                }
            }
        }
        versions = newVersions
        copyrights = newCopyrights
        
        if !newVersions.keys.contains(selectedVersion), let first = newVersions.keys.sorted().first {
            selectedVersion = first
        }
        bibleCache.removeAll()
        fetchVerses()
    }
    
    func fetchVerses() {
        if let cached = bibleCache[selectedVersion], !cached.isEmpty, cached[String(selectedBook.id)] != nil {
            extractVerses()
            return
        }
        
        isLoading = true
        errorMessage = nil
        maxVersesInChapter = 0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Try Application Support
            let localPath = "\(Self.applicationSupportBiblesPath)/\(self.selectedLanguage)/\(self.selectedVersion).json"
            if FileManager.default.fileExists(atPath: localPath),
               let data = try? Data(contentsOf: URL(fileURLWithPath: localPath)),
               self.parseAndCacheBibleData(data, version: self.selectedVersion) {
                return
            }
            
            // Try Bundle
            let bundlePath = "\(self.bundleBiblesPath)/\(self.selectedVersion).json"
            if FileManager.default.fileExists(atPath: bundlePath),
               let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
               self.parseAndCacheBibleData(data, version: self.selectedVersion) {
                return
            }
            
            // Try API
            do {
                let apiUrl = "\(Self.apiBaseURL)/download/\(self.selectedLanguage)/\(self.selectedVersion)"
                let data = try Data(contentsOf: URL(string: apiUrl)!, options: .mappedIfSafe)
                if self.parseAndCacheBibleData(data, version: self.selectedVersion, sourceIsApi: true) {
                    return
                }
                DispatchQueue.main.async {
                    self.errorMessage = self.localizedString("invalidData")
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = String(format: self.localizedString("failedToLoad"), error.localizedDescription)
                    self.isLoading = false
                }
            }
        }
    }
    
    @discardableResult
    private func parseAndCacheBibleData(_ data: Data, version: String, sourceIsApi: Bool = false) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let versesData = json["verses"] as? [String: [String: [String]]] else {
            return false
        }
        
        var bookList: [BibleBook] = []
        if let booksArray = json["books"] as? [Any] {
            for (index, entry) in booksArray.enumerated() {
                if let bookEntry = entry as? [Any], bookEntry.count == 2,
                   let name = bookEntry[0] as? String,
                   let chapters = bookEntry[1] as? Int {
                    bookList.append(BibleBook(id: index + 1, name: name, chapters: chapters))
                }
            }
        }
        
        DispatchQueue.main.async {
            self.bibleCache[version] = versesData
            if !bookList.isEmpty {
                self.books = bookList
                if let localizedNames = Self.localizedBooks[self.selectedLanguage] {
                    for i in 0..<min(self.books.count, localizedNames.count) {
                        self.books[i] = BibleBook(id: self.books[i].id, name: localizedNames[i], chapters: self.books[i].chapters)
                    }
                }
                if !bookList.contains(where: { $0.id == self.selectedBookId }),
                   let first = bookList.first {
                    self.selectedBook = first
                }
            } else if let localizedNames = Self.localizedBooks[self.selectedLanguage], localizedNames.count == Self.defaultBooks.count {
                self.books = zip(localizedNames, Self.defaultBooks).map { BibleBook(id: $1.id, name: $0, chapters: $1.chapters) }
            }
            self.isLoadedFromApi = sourceIsApi
            self.isLoading = false
            self.extractVerses()
        }
        return true
    }
    
    func downloadVersion(language: String, version: String) {
        let key = "\(language)/\(version)"
        guard activeDownloads[key] == nil else { return }
        activeDownloads[key] = 0
        
        let apiUrl = "\(Self.apiBaseURL)/download/\(language)/\(version)"
        guard let url = URL(string: apiUrl) else {
            activeDownloads.removeValue(forKey: key)
            return
        }
        
        let task = downloadSession.downloadTask(with: url)
        sessionDelegate.callbacks[task.taskIdentifier] = (
            progress: { [weak self] p in
                self?.activeDownloads[key] = p
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                self.activeDownloads.removeValue(forKey: key)
                self.sessionDelegate.callbacks.removeValue(forKey: task.taskIdentifier)
                self.downloadTasks.removeValue(forKey: key)
                switch result {
                case .success(let data):
                    let dirPath = "\(Self.applicationSupportBiblesPath)/\(language)"
                    try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
                    let filePath = "\(dirPath)/\(version).json"
                    do {
                        try data.write(to: URL(fileURLWithPath: filePath))
                        self.downloadedVersions.insert(key)
                        if language == self.selectedLanguage && version == self.selectedVersion {
                            self.bibleCache.removeValue(forKey: version)
                            self.fetchVerses()
                        }
                    } catch {
                        self.errorMessage = String(format: self.localizedString("failedToSave"), error.localizedDescription)
                    }
                case .failure(let error):
                    self.errorMessage = String(format: self.localizedString("failedToSave"), error.localizedDescription)
                }
            }
        )
        downloadTasks[key] = task
        task.resume()
    }
    
    func downloadAllVersions(for language: String) {
        let names = versionNames(for: language)
        for code in names.keys {
            guard !isVersionBundled(language, code),
                  !isVersionDownloaded(language, code) else { continue }
            downloadVersion(language: language, version: code)
        }
    }
    
    func cancelDownload(language: String, version: String) {
        let key = "\(language)/\(version)"
        if let task = downloadTasks[key] {
            sessionDelegate.callbacks.removeValue(forKey: task.taskIdentifier)
            task.cancel()
        }
        downloadTasks.removeValue(forKey: key)
        activeDownloads.removeValue(forKey: key)
    }
    
    func deleteDownload(language: String, version: String) {
        if activeDownloads["\(language)/\(version)"] != nil {
            cancelDownload(language: language, version: version)
        }
        let filePath = "\(Self.applicationSupportBiblesPath)/\(language)/\(version).json"
        try? FileManager.default.removeItem(atPath: filePath)
        downloadedVersions.remove("\(language)/\(version)")
        if selectedLanguage == language && selectedVersion == version {
            bibleCache.removeValue(forKey: version)
            fetchVerses()
        }
    }
    
    func deleteAllDownloads() {
        let base = Self.applicationSupportBiblesPath
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: base) else { return }
        for lang in files {
            let langPath = "\(base)/\(lang)"
            guard let versionFiles = try? FileManager.default.contentsOfDirectory(atPath: langPath) else { continue }
            for vf in versionFiles {
                try? FileManager.default.removeItem(atPath: "\(langPath)/\(vf)")
            }
        }
        downloadedVersions.removeAll()
        bibleCache.removeAll()
        fetchVerses()
    }
    
    func refreshDownloadedVersions() {
        var downloaded: Set<String> = []
        let base = Self.applicationSupportBiblesPath
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: base) else {
            downloadedVersions = downloaded
            return
        }
        for lang in files {
            let langPath = "\(base)/\(lang)"
            guard let versionFiles = try? FileManager.default.contentsOfDirectory(atPath: langPath) else { continue }
            for vf in versionFiles where vf.hasSuffix(".json") {
                downloaded.insert("\(lang)/\(vf.dropLast(5))")
            }
        }
        downloadedVersions = downloaded
    }
    
    func isVersionBundled(_ language: String, _ version: String) -> Bool {
        let path = "\(Bundle.main.resourceURL!.appendingPathComponent("bibles/\(language)").path)/\(version).json"
        return FileManager.default.fileExists(atPath: path)
    }
    
    func isVersionDownloaded(_ language: String, _ version: String) -> Bool {
        let path = "\(Self.applicationSupportBiblesPath)/\(language)/\(version).json"
        return FileManager.default.fileExists(atPath: path)
    }
    
    func versionNames(for language: String) -> [String: String] {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("bibles/manifest.json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let langInfo = json[language] as? [String: Any],
              let versionList = langInfo["versions"] as? [[String: Any]] else { return [:] }
        var result: [String: String] = [:]
        let langLabel = langInfo["label"] as? String ?? ""
        for v in versionList {
            if let code = v["code"] as? String,
               let label = v["label"] as? String {
                let parts = code.split(separator: "/").map(String.init)
                guard parts.count == 2 else { continue }
                let key = parts[1]
                if language == "en", let properName = Self.englishVersionNames[key] {
                    result[key] = properName
                } else {
                    result[key] = label.replacingOccurrences(of: "\(langLabel) — ", with: "")
                }
            }
        }
        return result
    }
    
    var currentSourceLabel: String {
        let name = versions[selectedVersion] ?? selectedVersion
        if !isLoadedFromApi { return "\(name) — Local" }
        return "\(name) — Online"
    }
    
    private func extractVerses() {
        guard let cached = bibleCache[selectedVersion],
              let chapterVerses = cached[String(selectedBook.id)]?[String(selectedChapter)] else {
            maxVersesInChapter = 0
            errorMessage = localizedString("passageNotFound")
            return
        }
        
        maxVersesInChapter = chapterVerses.count
        if startVerse > maxVersesInChapter { startVerse = 1 }
        if endVerse > maxVersesInChapter { endVerse = maxVersesInChapter }
        
        var result = chapterVerses.enumerated().map { (i, text) in
            Verse(verse: i + 1, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        if startVerse > 1 {
            result = result.filter { $0.verse >= startVerse }
        }
        if endVerse > 0 && endVerse >= startVerse {
            result = result.filter { $0.verse <= endVerse }
        }
        
        verses = result
        
        if let first = verses.first?.verse, let last = verses.last?.verse {
            if first == last {
                reference = "\(selectedBook.name) \(selectedChapter):\(first)"
            } else {
                reference = "\(selectedBook.name) \(selectedChapter):\(first)-\(last)"
            }
        }
    }
    
    func copyAsJson() {
        let json: [String: Any] = [
            "reference": reference,
            "version": selectedVersion,
            "verses": verses.map { ["verse": $0.verse, "text": $0.text] }
        ]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .withoutEscapingSlashes]),
           let jsonString = String(data: data, encoding: .utf8) {
            copyToClipboard(jsonString, message: localizedString("jsonCopied"))
        }
    }
    
    func copyAsCsv() {
        var csv = "Verse,Text\n"
        for v in verses {
            let escaped = v.text.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(v.verse),\"\(escaped)\"\n"
        }
        copyToClipboard(csv, message: localizedString("csvCopied"))
    }
    
    func exportToPlainText() {
        let text = verses.map { "\($0.verse). \($0.text)" }.joined(separator: "\n\n") + "\n\n\(reference)"
        let savePanel = NSSavePanel()
        let txtType = UTType(tag: "txt", tagClass: .filenameExtension, conformingTo: .content) ?? .plainText
        savePanel.allowedContentTypes = [txtType, .plainText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = localizedString("exportPlainText")
        savePanel.message = localizedString("savePanelMessage")
        savePanel.nameFieldStringValue = "\(reference.replacingOccurrences(of: ":", with: "-")).txt"
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try text.write(to: url, atomically: true, encoding: .utf8)
                    self.toastMessage = self.localizedString("exPlainText")
                    withAnimation { self.showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { self.showCopiedToast = false }
                    }
                } catch {
                    self.errorMessage = String(format: self.localizedString("failedToSave"), error.localizedDescription)
                }
            }
        }
    }
    
    func exportToHtml() {
        let bg: String, fg: String
        switch currentTheme {
        case .sepia: bg = "#f5f0e0"; fg = "#33260d"
        case .dark: bg = "#1a1a1a"; fg = "#ffffff"
        default: bg = "#ffffff"; fg = "#000000"
        }
        let html = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"><title>\(reference)</title>
        <style>
        body { background: \(bg); color: \(fg); font-family: Georgia, serif; max-width: 700px; margin: 0 auto; padding: 2em; }
        h1 { font-size: 1.8em; }
        p { font-size: 1.1em; line-height: 1.6; }
        sup { color: #888; font-size: 0.8em; }
        footer { margin-top: 2em; font-size: 0.9em; color: #888; }
        </style>
        </head>
        <body>
        <h1>\(reference)</h1>
        """ + verses.map { """
        <p><sup>\($0.verse)</sup> \($0.text)</p>
        """ }.joined(separator: "\n") + """
        <hr>
        <footer><em>\(versions[selectedVersion] ?? selectedVersion)</em><br><small>\(copyrights[selectedVersion] ?? "")</small></footer>
        </body>
        </html>
        """
        let savePanel = NSSavePanel()
        let htmlType = UTType(tag: "html", tagClass: .filenameExtension, conformingTo: .content) ?? .plainText
        savePanel.allowedContentTypes = [htmlType, .plainText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = localizedString("exportHtml")
        savePanel.message = localizedString("savePanelMessage")
        savePanel.nameFieldStringValue = "\(reference.replacingOccurrences(of: ":", with: "-")).html"
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try html.write(to: url, atomically: true, encoding: .utf8)
                    self.toastMessage = self.localizedString("exHtml")
                    withAnimation { self.showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { self.showCopiedToast = false }
                    }
                } catch {
                    self.errorMessage = String(format: self.localizedString("failedToSave"), error.localizedDescription)
                }
            }
        }
    }
    
    func copyToClipboard(_ text: String, message: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        self.toastMessage = message
        withAnimation { self.showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showCopiedToast = false }
        }
    }
    
    func exportToMarkdown() {
        let markdown = "# \(reference)\n\n" + 
            verses.map { "### Verse \($0.verse)\n\($0.text)" }.joined(separator: "\n\n") + 
            "\n\n---\n*Source: \(versions[selectedVersion] ?? selectedVersion)*\n\n*\(copyrights[selectedVersion] ?? "")*"
        
        let savePanel = NSSavePanel()
        let mdType = UTType(tag: "md", tagClass: .filenameExtension, conformingTo: .content) ?? .plainText
        savePanel.allowedContentTypes = [mdType, .plainText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = localizedString("exportMarkdown")
        savePanel.message = localizedString("savePanelMessage")
        savePanel.nameFieldStringValue = "\(reference.replacingOccurrences(of: ":", with: "-")).md"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try markdown.write(to: url, atomically: true, encoding: .utf8)
                    self.toastMessage = self.localizedString("exMarkdown")
                    withAnimation { self.showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { self.showCopiedToast = false }
                    }
                } catch {
                    self.errorMessage = String(format: self.localizedString("failedToSave"), error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = BibleViewModel()
    @State private var showingSettings = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Top Bar
            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.localizedString("version"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.selectedVersion) {
                            ForEach(viewModel.versions.keys.sorted(), id: \.self) { key in
                                Text(viewModel.versions[key] ?? key).tag(key)
                            }
                        }
                        .frame(width: 220)
                        .labelsHidden()
                        .onChange(of: viewModel.selectedVersion) { viewModel.fetchVerses() }
                    }
                    
                    Divider().frame(height: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.localizedString("book"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.selectedBook) {
                            ForEach(viewModel.books) { book in
                                Text(book.name).tag(book)
                            }
                        }
                        .frame(width: 150)
                        .labelsHidden()
                        .onChange(of: viewModel.selectedBook) { 
                            viewModel.selectedChapter = 1
                            viewModel.startVerse = 1
                            viewModel.endVerse = 0
                            viewModel.fetchVerses() 
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.localizedString("chapter"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Picker("", selection: $viewModel.selectedChapter) {
                            ForEach(1...viewModel.selectedBook.chapters, id: \.self) { chapter in
                                Text("\(chapter)").tag(chapter)
                            }
                        }
                        .frame(width: 70)
                        .labelsHidden()
                        .onChange(of: viewModel.selectedChapter) { 
                            viewModel.startVerse = 1
                            viewModel.endVerse = 0
                            viewModel.fetchVerses() 
                        }
                    }
                    
                    Divider().frame(height: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.localizedString("versesOptional"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 5) {
                            Picker("", selection: Binding(get: {
                                viewModel.startVerse
                            }, set: { newVal in
                                viewModel.startVerse = newVal
                                if viewModel.endVerse > 0 && viewModel.endVerse < newVal {
                                    viewModel.endVerse = 0
                                }
                            })) {
                                ForEach(1...max(viewModel.maxVersesInChapter, 1), id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .frame(width: 50)
                            .labelsHidden()
                            Text("-")
                            Picker("", selection: $viewModel.endVerse) {
                                Text("-").tag(0)
                                if viewModel.maxVersesInChapter > 0 {
                                    ForEach(viewModel.startVerse...viewModel.maxVersesInChapter, id: \.self) { v in
                                        Text("\(v)").tag(v)
                                    }
                                }
                            }
                            .frame(width: 50)
                            .labelsHidden()
                            .disabled(viewModel.maxVersesInChapter == 0)
                        }
                    }
                    
                    Button(action: viewModel.fetchVerses) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 14)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.isLoadedFromApi ? Color.orange : Color.green)
                            .frame(width: 6, height: 6)
                        Text(viewModel.isLoadedFromApi ? "Online" : "Local")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: { showingSettings.toggle() }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.bordered)
                        .popover(isPresented: $showingSettings) {
                            SettingsView(viewModel: viewModel)
                                .frame(width: 280, height: 280)
                                .padding()
                        }
                        
                        if !viewModel.verses.isEmpty {
                            Menu {
                                Button(action: {
                                    let fullText = viewModel.verses.map { "\($0.verse). \($0.text)" }.joined(separator: "\n\n") + "\n\n\(viewModel.reference)"
                                    viewModel.copyToClipboard(fullText, message: viewModel.localizedString("passageCopied"))
                                }) {
                                    Label(viewModel.localizedString("copyAllText"), systemImage: "doc.on.doc")
                                }
                                
                                Divider()
                                
                                Button(action: {
                                    viewModel.copyAsJson()
                                }) {
                                    Label(viewModel.localizedString("copyAsJson"), systemImage: "curlybraces")
                                }
                                
                                Button(action: {
                                    viewModel.copyAsCsv()
                                }) {
                                    Label(viewModel.localizedString("copyAsCsv"), systemImage: "tablecells")
                                }
                                
                                Divider()
                                
                                Button(action: {
                                    viewModel.exportToMarkdown()
                                }) {
                                    Label(viewModel.localizedString("exportMarkdown"), systemImage: "arrow.down.doc")
                                }
                                
                                Button(action: {
                                    viewModel.exportToPlainText()
                                }) {
                                    Label(viewModel.localizedString("exportPlainText"), systemImage: "doc.text")
                                }
                                
                                Button(action: {
                                    viewModel.exportToHtml()
                                }) {
                                    Label(viewModel.localizedString("exportHtml"), systemImage: "globe")
                                }
                            } label: {
                                Label(viewModel.localizedString("share"), systemImage: "square.and.arrow.up")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if viewModel.currentTheme == .sepia {
                            Color(red: 0.96, green: 0.94, blue: 0.88)
                        } else {
                            VisualEffectView(material: .titlebar, blendingMode: .withinWindow)
                        }
                    }.ignoresSafeArea()
                )
                
                Divider()
            }
            
            // Reading Area
            ZStack {
                backgroundColor(for: viewModel.currentTheme)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView(viewModel.localizedString("fetchingWord"))
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.headline)
                    }
                } else if viewModel.verses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.2))
                        Text(viewModel.localizedString("selectPassage"))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            Text(viewModel.reference)
                                .font(.system(size: viewModel.fontSize * 1.8, weight: .bold, design: .serif))
                                .padding(.bottom, 10)
                                .foregroundColor(textColor(for: viewModel.currentTheme))
                                .onTapGesture {
                                    viewModel.copyToClipboard(viewModel.reference, message: viewModel.localizedString("referenceCopied"))
                                }
                                .onHover { inside in
                                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            
                            ForEach(viewModel.verses) { verse in
                                HStack(alignment: .top, spacing: 15) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Text("\(verse.verse)")
                                                .font(.system(.subheadline, design: .monospaced))
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                                .padding(6)
                                                .background(Color.blue.opacity(0.08))
                                                .cornerRadius(6)
                                            
                                            Text(verse.text)
                                                .font(.system(size: viewModel.fontSize, weight: .regular, design: .serif))
                                                .lineSpacing(10)
                                                .foregroundColor(textColor(for: viewModel.currentTheme))
                                                .textSelection(.enabled)
                                                .onTapGesture {
                                                    viewModel.copyToClipboard(verse.text, message: viewModel.localizedString("verseCopied"))
                                                }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        viewModel.copyToClipboard(verse.text, message: viewModel.localizedString("verseCopied"))
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.secondary.opacity(0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Divider().padding(.vertical, 40)
                            
                            VStack(alignment: .trailing, spacing: 10) {
                                Text("\(viewModel.reference) (\(viewModel.selectedVersion))")
                                    .font(.system(size: viewModel.fontSize * 1.2, weight: .semibold, design: .serif))
                                    .italic()
                                    .foregroundColor(.secondary)
                                    .onTapGesture {
                                        viewModel.copyToClipboard("\(viewModel.reference) (\(viewModel.selectedVersion))", message: viewModel.localizedString("referenceCopied"))
                                    }
                                
                                Text(viewModel.copyrights[viewModel.selectedVersion] ?? "")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 500, alignment: .trailing)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.bottom, 100)
                        }
                        .padding(EdgeInsets(top: 60, leading: 80, bottom: 60, trailing: 80))
                        .frame(maxWidth: 850)
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Toast Message
                if viewModel.showCopiedToast {
                    VStack {
                        Spacer()
                        Text(viewModel.toastMessage)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.black.opacity(0.85)))
                            .foregroundColor(.white)
                            .padding(.bottom, 50)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .preferredColorScheme(viewModel.currentTheme.colorScheme)
        .onAppear { viewModel.fetchVerses() }
        .onChange(of: viewModel.selectedLanguage) { viewModel.updateVersionsForLanguage() }
    }
    
    private func backgroundColor(for theme: AppTheme) -> Color {
        switch theme {
        case .sepia: return Color(red: 0.96, green: 0.94, blue: 0.88)
        case .light: return Color.white
        case .dark: return Color(red: 0.1, green: 0.1, blue: 0.1)
        case .system: return colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.white
        }
    }
    
    private func textColor(for theme: AppTheme) -> Color {
        switch theme {
        case .sepia: return Color(red: 0.2, green: 0.15, blue: 0.05)
        case .dark: return Color.white
        case .light: return Color.black
        case .system: return colorScheme == .dark ? Color.white : Color.black
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: BibleViewModel
    @State private var downloadLanguage = "en"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.localizedString("settings"))
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.localizedString("language"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $viewModel.selectedLanguage) {
                    ForEach(viewModel.languages.keys.sorted(), id: \.self) { code in
                        Text(viewModel.languages[code] ?? code).tag(code)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.localizedString("theme"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $viewModel.currentTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(viewModel.localizedString("theme\(theme.rawValue)")).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(viewModel.localizedString("fontSize"))
                    Spacer()
                    Text(String(format: viewModel.localizedString("fontSizePt"), Int(viewModel.fontSize)))
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                
                Slider(value: $viewModel.fontSize, in: 14...40, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.localizedString("downloadManager"))
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Picker("", selection: $downloadLanguage) {
                        ForEach(viewModel.languages.keys.sorted(), id: \.self) { code in
                            Text(viewModel.languages[code] ?? code).tag(code)
                        }
                    }
                    Button(viewModel.localizedString("download")) {
                        viewModel.downloadAllVersions(for: downloadLanguage)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(viewModel.isDownloading)
                    Button(viewModel.localizedString("deleteAllDownloads")) {
                        viewModel.deleteAllDownloads()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .controlSize(.small)
                }
                
                let names = viewModel.versionNames(for: downloadLanguage)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(names.keys.sorted(by: { (a, b) -> Bool in
                            (names[a] ?? a) < (names[b] ?? b)
                        }), id: \.self) { code in
                            let dlKey = "\(downloadLanguage)/\(code)"
                            HStack {
                                Text(names[code] ?? code)
                                    .lineLimit(1)
                                Spacer()
                                if let progress = viewModel.activeDownloads[dlKey] {
                                    VStack(alignment: .trailing, spacing: 2) {
                                        ProgressView(value: progress)
                                            .frame(width: 100)
                                        Text("\(Int(progress * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Button("Cancel") {
                                        viewModel.cancelDownload(language: downloadLanguage, version: code)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                } else if viewModel.isVersionBundled(downloadLanguage, code) {
                                    Text("Bundled")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                } else if viewModel.isVersionDownloaded(downloadLanguage, code) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Text(viewModel.localizedString("downloaded"))
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        Button(viewModel.localizedString("deleteDownload")) {
                                            viewModel.deleteDownload(language: downloadLanguage, version: code)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    }
                                } else {
                                    Text("Online")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 200)
                
                HStack {
                    Circle()
                        .fill(viewModel.isLoadedFromApi ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(viewModel.currentSourceLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            
            Link("Report a bug: bug@wbem.org", destination: URL(string: "mailto:bug@wbem.org")!)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

@main
struct SharersBibleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
    }
}
