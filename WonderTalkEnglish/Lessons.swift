import Foundation
import Combine

struct LessonLine: Identifiable, Codable, Equatable {
    var id: Int
    var english: String
    var chinese: String
    var start: Double? = nil
    var end: Double? = nil

    var isAligned: Bool {
        guard let start, let end else { return false }
        return start >= 0 && end > start
    }
}

struct StudyGuide: Codable, Equatable {
    var goal: String
    var steps: [String]
    var comprehensionPrompts: [String]
    var transcriptStatus: String
    var audioStatus: String
}

struct Lesson: Identifiable, Codable, Equatable {
    var id: String
    var category: String
    var title: String
    var subtitle: String
    var sourceName: String
    var sourceURL: String
    var rightsNote: String
    var audioFilename: String? = nil
    var bundledAudioStem: String? = nil
    var lines: [LessonLine]
    var level: String? = nil
    var topic: String? = nil
    var studyMode: String? = nil
    var materialStatus: String? = nil
    var studyGuide: StudyGuide? = nil
    var licensePolicy: String? = nil
    var catalogVersion: Int? = nil

    var isImported: Bool { bundledAudioStem == nil }
    var fullAudioStem: String? { bundledAudioStem.map { "\($0)_full" } }
    func sentenceStem(_ index: Int) -> String? {
        bundledAudioStem.map { "\($0)_\(String(format: "%02d", index + 1))" }
    }
}

/// Import format for private, user-owned learning resources.
/// Media is embedded as base64 so the learner only has to select one JSON file.
struct LocalStudyBundle: Decodable {
    let formatVersion: Int
    let items: [LocalStudyBundleItem]
}

struct LocalStudyBundleItem: Decodable {
    let id: String
    let sourceURL: String
    let lines: [String]?
    let audioFilename: String?
    let audioBase64: String?
}

struct LocalStudyImportSummary {
    var lessonsUpdated = 0
    var transcriptsImported = 0
    var audioImported = 0
    var skipped = 0
    var notes: [String] = []

    var message: String {
        let header = "已处理 \(lessonsUpdated) 门课程：导入 \(transcriptsImported) 份文字稿、\(audioImported) 份音频；跳过 \(skipped) 项。"
        return notes.isEmpty ? header : header + "\n" + notes.prefix(5).joined(separator: "\n")
    }
}

@MainActor
final class CourseStore: ObservableObject {
    @Published private(set) var lessons: [Lesson] = []
    @Published var errorMessage: String?

    private let manager = FileManager.default

    private var appSupport: URL {
        let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("WonderTalk", isDirectory: true)
        try? manager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var mediaDirectory: URL {
        let dir = appSupport.appendingPathComponent("Media", isDirectory: true)
        try? manager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var catalogURL: URL { appSupport.appendingPathComponent("catalog.json") }

    init() {
        let saved: [Lesson] = {
            guard let data = try? Data(contentsOf: catalogURL) else { return [] }
            return (try? JSONDecoder().decode([Lesson].self, from: data)) ?? []
        }()
        let bundled = bundledLessons()
        // Preserve existing user-imported audio, aligned sentences and translations.
        // Add new catalog entries without wiping progress or editable courses.
        var byID = Dictionary(uniqueKeysWithValues: bundled.map { ($0.id, $0) })
        for item in saved {
            if let original = byID[item.id] {
                var merged = original
                if item.audioFilename != nil { merged.audioFilename = item.audioFilename }
                if !item.lines.isEmpty { merged.lines = item.lines }
                byID[item.id] = merged
            } else {
                byID[item.id] = item
            }
        }
        lessons = byID.values.sorted { $0.id < $1.id }
        if lessons.isEmpty {
            errorMessage = "没有找到课程 JSON。请确认 Lessons 文件夹已加入 App Target。"
        }
        save()
    }

    private func bundledLessons() -> [Lesson] {
        var urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Lessons") ?? []
        if urls.isEmpty {
            for name in ["rates", "renaissance", "learning_catalog_v1"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "json") {
                    urls.append(url)
                }
            }
        }
        var all: [Lesson] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let list = try? JSONDecoder().decode([Lesson].self, from: data) {
                all.append(contentsOf: list)
            } else if let item = try? JSONDecoder().decode(Lesson.self, from: data) {
                all.append(item)
            }
        }
        return all.sorted { $0.id < $1.id }
    }

    func lesson(_ id: String) -> Lesson? {
        lessons.first(where: { $0.id == id })
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(lessons).write(to: catalogURL, options: .atomic)
        } catch {
            errorMessage = "保存课程失败：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func addLesson(title: String, category: String, sourceName: String,
                   sourceURL: String, rightsNote: String, transcript: String) -> String? {
        let sentences = transcript.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty,
              !sentences.isEmpty else {
            errorMessage = "请填写课程标题，并至少输入一行英文句子。"
            return nil
        }
        let id = UUID().uuidString.lowercased()
        let lesson = Lesson(id: id, category: category, title: title,
                            subtitle: "真人音频课程 · \(sentences.count) 句",
                            sourceName: sourceName, sourceURL: sourceURL,
                            rightsNote: rightsNote, audioFilename: nil,
                            bundledAudioStem: nil,
                            lines: sentences.enumerated().map { index, sentence in
                                LessonLine(id: index, english: sentence, chinese: "")
                            })
        lessons.append(lesson)
        save()
        return id
    }

    func importAudio(from url: URL, for lessonID: String) {
        guard let index = lessons.firstIndex(where: { $0.id == lessonID }) else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard ["mp3", "m4a", "wav", "aiff", "aif", "caf"].contains(ext) else {
            errorMessage = "请导入 MP3、M4A、WAV、AIFF 或 CAF 音频。"
            return
        }
        let filename = "lesson_\(lessonID).\(ext)"
        let destination = mediaDirectory.appendingPathComponent(filename)
        do {
            if manager.fileExists(atPath: destination.path) {
                try manager.removeItem(at: destination)
            }
            try manager.copyItem(at: url, to: destination)
            lessons[index].audioFilename = filename
            save()
        } catch {
            errorMessage = "导入音频失败：\(error.localizedDescription)"
        }
    }

    /// Import only entries whose lesson ID AND original source URL match the
    /// existing catalog. Never import unknown lessons by a guessed filename.
    /// User-supplied transcripts and audio remain local and are not committed.
    func importLocalStudyBundle(from url: URL, overwriteExisting: Bool) throws -> LocalStudyImportSummary {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 && size <= 40_000_000 else {
            throw NSError(domain: "WonderTalk.Bundle", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "资料包应为 40MB 以内的 JSON 文件。"])
        }
        let data = try Data(contentsOf: url)
        let bundle = try JSONDecoder().decode(LocalStudyBundle.self, from: data)
        guard bundle.formatVersion == 1, !bundle.items.isEmpty else {
            throw NSError(domain: "WonderTalk.Bundle", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "不支持此资料包版本或资料包为空。"])
        }
        var summary = LocalStudyImportSummary()
        var updatedIDs = Set<String>()
        var processedIDs = Set<String>()

        for item in bundle.items {
            guard processedIDs.insert(item.id).inserted else {
                summary.skipped += 1
                continue
            }
            guard let i = lessons.firstIndex(where: { $0.id == item.id }),
                  !item.sourceURL.isEmpty,
                  lessons[i].sourceURL == item.sourceURL else {
                summary.skipped += 1
                summary.notes.append("\(item.id)：课程来源 URL 不匹配，未导入。")
                continue
            }

            if let rawLines = item.lines {
                let cleanLines = rawLines.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty }
                if !cleanLines.isEmpty {
                    if lessons[i].lines.isEmpty || overwriteExisting {
                        lessons[i].lines = cleanLines.enumerated().map {
                            LessonLine(id: $0.offset, english: $0.element, chinese: "")
                        }
                        summary.transcriptsImported += 1
                        updatedIDs.insert(item.id)
                    } else {
                        summary.skipped += 1
                    }
                }
            }

            if let encoded = item.audioBase64, !encoded.isEmpty {
                let ext = (item.audioFilename ?? "").split(separator: ".").last.map(String.init)?
                    .lowercased() ?? ""
                guard ["mp3", "m4a", "wav", "aiff", "caf"].contains(ext),
                      let audioData = Data(base64Encoded: encoded),
                      !audioData.isEmpty, audioData.count <= 25_000_000 else {
                    summary.skipped += 1
                    summary.notes.append("\(item.id)：音频格式或数据无效，未导入音频。")
                    continue
                }
                let currentExists: Bool = {
                    guard let name = lessons[i].audioFilename else { return false }
                    return manager.fileExists(atPath: mediaDirectory.appendingPathComponent(name).path)
                }()
                if !currentExists || overwriteExisting {
                    let name = "lesson_\(item.id).\(ext)"
                    let destination = mediaDirectory.appendingPathComponent(name)
                    do {
                        try audioData.write(to: destination, options: .atomic)
                        lessons[i].audioFilename = name
                        summary.audioImported += 1
                        updatedIDs.insert(item.id)
                    } catch {
                        summary.skipped += 1
                        summary.notes.append("\(item.id)：音频保存失败：\(error.localizedDescription)")
                    }
                } else {
                    summary.skipped += 1
                }
            }
        }
        summary.lessonsUpdated = updatedIDs.count
        if !updatedIDs.isEmpty { save() }
        return summary
    }

    func setBoundary(lessonID: String, lineIndex: Int, isStart: Bool, seconds: Double) {
        guard let i = lessons.firstIndex(where: { $0.id == lessonID }),
              lessons[i].lines.indices.contains(lineIndex) else { return }
        if isStart {
            lessons[i].lines[lineIndex].start = max(0, seconds)
        } else {
            lessons[i].lines[lineIndex].end = max(0, seconds)
        }
        save()
    }

    /// Apply only reviewed, valid boundaries in one atomic catalog save.
    /// Unmatched sentences and existing manual edits are preserved by default.
    @discardableResult
    func applyAutoAlignment(lessonID: String,
                            suggestions: [SentenceAlignmentSuggestion],
                            overwriteExisting: Bool) -> Int {
        guard let lessonIndex = lessons.firstIndex(where: { $0.id == lessonID }) else {
            errorMessage = "找不到当前课程，未保存自动对齐结果。"
            return 0
        }
        var applied = 0
        for suggestion in suggestions {
            let i = suggestion.index
            guard lessons[lessonIndex].lines.indices.contains(i),
                  suggestion.start.isFinite, suggestion.end.isFinite,
                  suggestion.start >= 0, suggestion.end > suggestion.start else { continue }
            if !overwriteExisting && lessons[lessonIndex].lines[i].isAligned { continue }
            lessons[lessonIndex].lines[i].start = suggestion.start
            lessons[lessonIndex].lines[i].end = suggestion.end
            applied += 1
        }
        if applied > 0 { save() }
        return applied
    }

    func updateTranslation(lessonID: String, lineIndex: Int, text: String) {
        guard let i = lessons.firstIndex(where: { $0.id == lessonID }),
              lessons[i].lines.indices.contains(lineIndex) else { return }
        lessons[i].lines[lineIndex].chinese = text
        save()
    }

    func setTranscript(lessonID: String, transcript: String) {
        guard let index = lessons.firstIndex(where: { $0.id == lessonID }) else { return }
        let sentences = transcript.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !sentences.isEmpty else {
            errorMessage = "请至少输入一行英文原文。"
            return
        }
        lessons[index].lines = sentences.enumerated().map {
            LessonLine(id: $0.offset, english: $0.element, chinese: "")
        }
        save()
    }

    func resetCatalog() {
        // Never automatically delete imported audio or recordings.
        let bundled = bundledLessons()
        lessons = bundled
        save()
    }
}