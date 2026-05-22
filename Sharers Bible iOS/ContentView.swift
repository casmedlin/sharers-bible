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
        default: return nil
        }
    }
}

// MARK: - ViewModel
class BibleViewModel: ObservableObject {
    @AppStorage("selectedVersion") var selectedVersion: String = "ESV"
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
    
    @Published var showCopiedToast: Bool = false
    @Published var toastMessage: String = ""
    
    @AppStorage("selectedTheme") var currentTheme: AppTheme = .system
    @AppStorage("fontSize") var fontSize: Double = 18.0
    
    let versions = [
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
    ]
    
    let copyrights = [
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
    ]
    
    let books: [BibleBook] = [
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
    
    init() {
        let savedBookId = UserDefaults.standard.integer(forKey: "selectedBookId")
        let bookId = savedBookId == 0 ? 43 : savedBookId
        
        let bookList: [BibleBook] = [
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
        
        self.selectedBook = bookList.first(where: { $0.id == bookId }) ?? BibleBook(id: 43, name: "John", chapters: 21)
    }
    
    func fetchVerses() {
        isLoading = true
        errorMessage = nil
        
        let urlString = "https://bolls.life/get-text/\(selectedVersion)/\(selectedBook.id)/\(selectedChapter)/"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                do {
                    var decodedVerses = try JSONDecoder().decode([Verse].self, from: data)
                    
                    if let start = self?.startVerse, start > 1 {
                        decodedVerses = decodedVerses.filter { $0.verse >= start }
                    }
                    if let end = self?.endVerse, end > 0 && end >= (self?.startVerse ?? 1) {
                        decodedVerses = decodedVerses.filter { $0.verse <= end }
                    }
                    
                    self?.verses = decodedVerses.map { verse in
                        let cleanedText = verse.text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                                                 .replacingOccurrences(of: "&nbsp;", with: " ")
                                                 .trimmingCharacters(in: .whitespacesAndNewlines)
                        return Verse(verse: verse.verse, text: cleanedText)
                    }
                    
                    if let book = self?.selectedBook, 
                       let chapter = self?.selectedChapter,
                       let firstVerse = self?.verses.first?.verse,
                       let lastVerse = self?.verses.last?.verse {
                        
                        if firstVerse == lastVerse {
                            self?.reference = "\(book.name) \(chapter):\(firstVerse)"
                        } else {
                            self?.reference = "\(book.name) \(chapter):\(firstVerse)-\(lastVerse)"
                        }
                    }
                } catch {
                    self?.errorMessage = "Passage not found or error decoding data"
                }
            }
        }.resume()
    }
    
    func copyToClipboard(_ text: String, message: String) {
        UIPasteboard.general.string = text
        
        self.toastMessage = message
        withAnimation { self.showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.showCopiedToast = false }
        }
    }
    
    func getMarkdown() -> String {
        return "# \(reference)

" + 
            verses.map { "### Verse \($0.verse)
\($0.text)" }.joined(separator: "

") + 
            "

---
*Source: \(versions[selectedVersion] ?? selectedVersion)*

*\(copyrights[selectedVersion] ?? "")*"
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = BibleViewModel()
    @State private var showingSettings = false
    @State private var showingSearch = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor(for: viewModel.currentTheme)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Fetching God's Word...")
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.headline)
                        Button("Retry") { viewModel.fetchVerses() }
                            .buttonStyle(.bordered)
                    }
                } else if viewModel.verses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.2))
                        Text("Select a passage to begin reading.")
                            .foregroundColor(.secondary)
                        Button("Choose Passage") { showingSearch = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(viewModel.reference)
                                .font(.system(size: viewModel.fontSize * 1.6, weight: .bold, design: .serif))
                                .padding(.bottom, 8)
                                .foregroundColor(textColor(for: viewModel.currentTheme))
                                .onTapGesture {
                                    viewModel.copyToClipboard(viewModel.reference, message: "Reference copied!")
                                }
                            
                            ForEach(viewModel.verses) { verse in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                                        Text("\(verse.verse)")
                                            .font(.system(.caption, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                            .padding(4)
                                            .background(Color.blue.opacity(0.08))
                                            .cornerRadius(4)
                                        
                                        Text(verse.text)
                                            .font(.system(size: viewModel.fontSize, weight: .regular, design: .serif))
                                            .lineSpacing(6)
                                            .foregroundColor(textColor(for: viewModel.currentTheme))
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    viewModel.copyToClipboard(verse.text, message: "Verse text copied!")
                                }
                            }
                            
                            Divider().padding(.vertical, 20)
                            
                            VStack(alignment: .center, spacing: 12) {
                                Text("\(viewModel.reference) (\(viewModel.selectedVersion))")
                                    .font(.system(size: viewModel.fontSize, weight: .semibold, design: .serif))
                                    .italic()
                                    .foregroundColor(.secondary)
                                
                                Text(viewModel.copyrights[viewModel.selectedVersion] ?? "")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 40)
                        }
                        .padding(24)
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
                            .padding(.bottom, 100)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("Sharer's Bible")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingSettings.toggle() } label: {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { showingSearch.toggle() } label: {
                            Image(systemName: "book.fill")
                        }
                        
                        if !viewModel.verses.isEmpty {
                            let markdown = viewModel.getMarkdown()
                            ShareLink(item: markdown, subject: Text(viewModel.reference), message: Text("Shared from Sharer's Bible")) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(viewModel: viewModel)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingSearch) {
                PassagePickerView(viewModel: viewModel)
            }
        }
        .preferredColorScheme(viewModel.currentTheme.colorScheme)
        .onAppear { viewModel.fetchVerses() }
    }
    
    private func backgroundColor(for theme: AppTheme) -> Color {
        switch theme {
        case .sepia: return Color(red: 0.96, green: 0.94, blue: 0.88)
        case .light: return Color.white
        case .dark: return Color(red: 0.1, green: 0.1, blue: 0.1)
        default: return Color(uiColor: .systemBackground)
        }
    }
    
    private func textColor(for theme: AppTheme) -> Color {
        switch theme {
        case .sepia: return Color(red: 0.2, green: 0.15, blue: 0.05)
        case .dark: return Color.white
        case .light: return Color.black
        default: return Color.primary
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: BibleViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $viewModel.currentTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Font Size")
                            Spacer()
                            Text("\(Int(viewModel.fontSize))pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $viewModel.fontSize, in: 14...32, step: 1)
                    }
                }
                
                Section("About") {
                    Text("Sharer's Bible App is designed for quick reading and sharing of God's Word.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct PassagePickerView: View {
    @ObservedObject var viewModel: BibleViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Translation") {
                    Picker("Version", selection: $viewModel.selectedVersion) {
                        ForEach(viewModel.versions.keys.sorted(), id: \.self) { key in
                            Text(viewModel.versions[key] ?? key).tag(key)
                        }
                    }
                }
                
                Section("Book & Chapter") {
                    Picker("Book", selection: $viewModel.selectedBook) {
                        ForEach(viewModel.books) { book in
                            Text(book.name).tag(book)
                        }
                    }
                    
                    Picker("Chapter", selection: $viewModel.selectedChapter) {
                        ForEach(1...viewModel.selectedBook.chapters, id: \.self) { chapter in
                            Text("\(chapter)").tag(chapter)
                        }
                    }
                }
                
                Section("Verses (Optional)") {
                    HStack {
                        Text("Start")
                        Spacer()
                        TextField("1", value: $viewModel.startVerse, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        TextField("All", value: $viewModel.endVerse, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Select Passage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Read") {
                        viewModel.fetchVerses()
                        dismiss()
                    }
                }
            }
        }
    }
}

@main
struct SharersBibleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
