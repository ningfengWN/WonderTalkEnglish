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

    var isImported: Bool { bundledAudioStem == nil }
    var fullAudioStem: String? { bundledAudioStem.map { "\($0)_full" } }
    func sentenceStem(_ index: Int) -> String? {
        bundledAudioStem.map { "\($0)_\(String(format: "%02d", index + 1))" }
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
        if let data = try? Data(contentsOf: catalogURL),
           let saved = try? JSONDecoder().decode([Lesson].self, from: data),
           !saved.isEmpty {
            lessons = saved
        } else {
            loadBundledLessons()
            save()
        }
    }

    private func loadBundledLessons() {
        var urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Lessons") ?? []
        if urls.isEmpty {
            for name in ["rates", "renaissance"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "json") {
                    urls.append(url)
                }
            }
        }
        lessons = urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Lesson.self, from: data)
        }.sorted { $0.id < $1.id }
        if lessons.isEmpty {
            errorMessage = "没有找到 Lessons 文件夹中的 JSON 课程。请将 Lessons 添加到 App Target。"
        }
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

    func updateTranslation(lessonID: String, lineIndex: Int, text: String) {
        guard let i = lessons.firstIndex(where: { $0.id == lessonID }),
              lessons[i].lines.indices.contains(lineIndex) else { return }
        lessons[i].lines[lineIndex].chinese = text
        save()
    }

    func resetCatalog() {
        // Never automatically delete imported audio or recordings.
        loadBundledLessons()
        save()
    }
}