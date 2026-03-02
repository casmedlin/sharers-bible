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
    @Published var selectedVersion: String = "ESV"
    @Published var verses: [Verse] = []
    @Published var reference: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    @Published var selectedBook: BibleBook
    @Published var selectedChapter: Int = 1
    @Published var startVerse: Int = 1
    @Published var endVerse: Int = 0
    
    @Published var showCopiedToast: Bool = false
    @Published var toastMessage: String = ""
    
    @AppStorage("selectedTheme") var currentTheme: AppTheme = .system
    @AppStorage("fontSize") var fontSize: Double = 21.0
    
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
        self.selectedBook = books.first(where: { $0.id == 43 })!
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
                        // Strip ALL HTML tags using Regex for absolute sanitation
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
        savePanel.title = "Export to Markdown"
        savePanel.message = "Choose where to save your Bible passage"
        savePanel.nameFieldStringValue = "\(reference.replacingOccurrences(of: ":", with: "-")).md"
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try markdown.write(to: url, atomically: true, encoding: .utf8)
                    self.toastMessage = "Exported to Markdown!"
                    withAnimation { self.showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { self.showCopiedToast = false }
                    }
                } catch {
                    self.errorMessage = "Failed to save file: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel = BibleViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Top Bar
            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Translation")
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
                        Text("Book")
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
                        Text("Chapter")
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
                        Text("Verses (Optional)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 5) {
                            TextField("Start", value: $viewModel.startVerse, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                            Text("-")
                            TextField("End", value: $viewModel.endVerse, formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                        }
                    }
                    
                    Button(action: viewModel.fetchVerses) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 14)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: { showingSettings.toggle() }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.bordered)
                        .popover(isPresented: $showingSettings) {
                            SettingsView(viewModel: viewModel)
                                .frame(width: 250, height: 200)
                                .padding()
                        }
                        
                        if !viewModel.verses.isEmpty {
                            Menu {
                                Button(action: {
                                    let fullText = viewModel.verses.map { "\($0.verse). \($0.text)" }.joined(separator: "\n\n") + "\n\n\(viewModel.reference)"
                                    viewModel.copyToClipboard(fullText, message: "Entire passage copied!")
                                }) {
                                    Label("Copy All Text", systemImage: "doc.on.doc")
                                }
                                
                                Button(action: {
                                    viewModel.exportToMarkdown()
                                }) {
                                    Label("Export to Markdown", systemImage: "arrow.down.doc")
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow).ignoresSafeArea())
                
                Divider()
            }
            
            // Reading Area
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
                    }
                } else if viewModel.verses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.2))
                        Text("Select a passage to begin reading.")
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
                                    viewModel.copyToClipboard(viewModel.reference, message: "Reference copied!")
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
                                                    viewModel.copyToClipboard(verse.text, message: "Verse text copied!")
                                                }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        viewModel.copyToClipboard(verse.text, message: "Verse text copied!")
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
                                        viewModel.copyToClipboard("\(viewModel.reference) (\(viewModel.selectedVersion))", message: "Reference copied!")
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
    }
    
    private func backgroundColor(for theme: AppTheme) -> Color {
        switch theme {
        case .sepia: return Color(red: 0.96, green: 0.94, blue: 0.88)
        case .light: return Color.white
        case .dark: return Color(red: 0.1, green: 0.1, blue: 0.1)
        default: return Color(NSColor.textBackgroundColor)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $viewModel.currentTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(Int(viewModel.fontSize))pt")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                
                Slider(value: $viewModel.fontSize, in: 14...40, step: 1)
            }
            
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
