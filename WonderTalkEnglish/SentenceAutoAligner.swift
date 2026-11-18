import Foundation
import Speech
import AVFoundation
import Combine

/// A suggested boundary is never persisted until the learner confirms it.
struct SentenceAlignmentSuggestion: Identifiable {
    let index: Int
    let start: TimeInterval
    let end: TimeInterval
    let matchedWords: Int
    let expectedWords: Int
    var id: Int { index }
    var matchRatio: Double { Double(matchedWords) / Double(max(1, expectedWords)) }
}

private struct TimedWord {
    let word: String
    let start: TimeInterval
    let end: TimeInterval
}

private struct AlignmentAudioChunk {
    let url: URL
    let offset: TimeInterval
    let temporary: Bool
}

@MainActor
final class SentenceAutoAligner: ObservableObject {
    @Published private(set) var working = false
    @Published private(set) var progress = ""
    @Published private(set) var suggestions: [SentenceAlignmentSuggestion] = []
    @Published private(set) var status = ""
    @Published private(set) var recognizedText = ""

    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var chunks: [AlignmentAudioChunk] = []
    private var chunkIndex = 0
    private var words: [TimedWord] = []
    private var sourceLesson: Lesson?
    private var duration: TimeInterval = 0
    private var allowOnline = false
    private var generation = 0

    func cancel() {
        generation += 1
        recognitionTask?.cancel()
        recognitionTask = nil
        working = false
        cleanTemporaryFiles()
        chunks = []
    }

    func start(lesson: Lesson, mediaDirectory: URL, allowAppleOnline: Bool) {
        cancel()
        suggestions = []
        status = ""
        recognizedText = ""
        guard !lesson.lines.isEmpty else {
            status = "请先导入逐句英文原文。"
            return
        }
        let url: URL? = {
            if let name = lesson.audioFilename {
                let file = mediaDirectory.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: file.path) { return file }
            }
            if let stem = lesson.fullAudioStem {
                for ext in ["m4a", "mp3", "wav", "aiff", "caf"] {
                    if let file = Bundle.main.url(forResource: stem, withExtension: ext,
                                                  subdirectory: "Audio") ??
                                  Bundle.main.url(forResource: stem, withExtension: ext) {
                        return file
                    }
                }
            }
            return nil
        }()
        guard let url else {
            status = "找不到本课程音频。请先导入 MP3/M4A，再尝试自动对齐。"
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            status = "当前系统不支持英语语音识别。请使用手动时间对齐。"
            return
        }
        guard recognizer.supportsOnDeviceRecognition || allowAppleOnline else {
            status = "此设备不支持离线英语识别。可开启“允许 Apple 在线识别”后重试，或手动对齐。"
            return
        }
        self.recognizer = recognizer
        self.allowOnline = allowAppleOnline
        self.sourceLesson = lesson
        do {
            try prepareAudio(url)
        } catch {
            status = "无法读取音频：\(error.localizedDescription)。可继续手动对齐。"
            cleanTemporaryFiles()
            return
        }
        working = true
        progress = "正在申请语音识别权限…"
        let token = generation
        SFSpeechRecognizer.requestAuthorization { [weak self] authorization in
            Task { @MainActor in
                guard let self, self.generation == token, self.working else { return }
                guard authorization == .authorized else {
                    self.finishWithError("未获得语音识别权限。请在系统设置中允许，或使用手动对齐。")
                    return
                }
                self.runNextChunk(token: token)
            }
        }
    }

    /// Apple Speech works best with short recordings. Split long imported
    /// recordings into overlapping 44-second CAF chunks without changing the
    /// original audio file or its timing.
    private func prepareAudio(_ url: URL) throws {
        let reader = try AVAudioFile(forReading: url)
        let format = reader.processingFormat
        guard format.sampleRate > 0, reader.length > 0 else {
            throw NSError(domain: "WonderTalk.Alignment", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "音频为空或格式不受支持"])
        }
        duration = Double(reader.length) / format.sampleRate
        guard duration <= 30 * 60 else {
            throw NSError(domain: "WonderTalk.Alignment", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "单次最多处理约 30 分钟音频；请先分段导入"])
        }
        if duration <= 50 {
            chunks = [AlignmentAudioChunk(url: url, offset: 0, temporary: false)]
            return
        }
        let chunkFrames = AVAudioFramePosition(44 * format.sampleRate)
        let overlapFrames = AVAudioFramePosition(2 * format.sampleRate)
        var cursor: AVAudioFramePosition = 0
        while cursor < reader.length {
            let count = min(chunkFrames, reader.length - cursor)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                                frameCapacity: AVAudioFrameCount(count)) else {
                throw NSError(domain: "WonderTalk.Alignment", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "无法创建音频缓冲区"])
            }
            reader.framePosition = cursor
            try reader.read(into: buffer, frameCount: AVAudioFrameCount(count))
            guard buffer.frameLength > 0 else { break }
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("wt-align-\(UUID().uuidString).caf")
            let output = try AVAudioFile(forWriting: outputURL,
                                         settings: format.settings,
                                         commonFormat: format.commonFormat,
                                         interleaved: format.isInterleaved)
            try output.write(from: buffer)
            chunks.append(AlignmentAudioChunk(url: outputURL,
                                               offset: Double(cursor) / format.sampleRate,
                                               temporary: true))
            if cursor + count >= reader.length { break }
            cursor += max(1, chunkFrames - overlapFrames)
        }
        guard !chunks.isEmpty else {
            throw NSError(domain: "WonderTalk.Alignment", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "无法拆分音频"])
        }
    }

    private func runNextChunk(token: Int) {
        guard generation == token, working else { return }
        guard chunkIndex < chunks.count else {
            finishMatching()
            return
        }
        guard let recognizer else {
            finishWithError("语音识别器不可用。")
            return
        }
        let index = chunkIndex
        let chunk = chunks[index]
        progress = "识别音频片段 \(index + 1) / \(chunks.count)…"
        let request = SFSpeechURLRecognitionRequest(url: chunk.url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        // Online recognition is used only when the device cannot do it locally
        // AND the user explicitly opted in.
        if !recognizer.supportsOnDeviceRecognition && !allowOnline {
            finishWithError("未开启在线识别。")
            return
        }
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.generation == token,
                      self.working, self.chunkIndex == index else { return }
                if let result, result.isFinal {
                    self.words.append(contentsOf: Self.timedWords(
                        result.bestTranscription.segments, offset: chunk.offset))
                    self.recognizedText += (self.recognizedText.isEmpty ? "" : " ") +
                        result.bestTranscription.formattedString
                    self.recognitionTask = nil
                    self.chunkIndex += 1
                    self.runNextChunk(token: token)
                } else if let error {
                    self.finishWithError("识别第 \(index + 1) 段失败：\(error.localizedDescription)。请重试或手动对齐。")
                }
            }
        }
    }

    private func finishMatching() {
        guard let lesson = sourceLesson else {
            finishWithError("课程已发生变化，请重试。")
            return
        }
        progress = "正在匹配逐句文字…"
        suggestions = Self.match(lesson.lines, words: words, duration: duration)
        working = false
        recognitionTask = nil
        cleanTemporaryFiles()
        chunks = []
        if suggestions.isEmpty {
            status = "没有找到可信的句子对应关系。请确认音频与英文原文一致，或手动对齐。"
        } else {
            status = "已匹配 \(suggestions.count) / \(lesson.lines.count) 句。请试听检查后确认保存；未匹配的句子不会修改。"
        }
    }

    private func finishWithError(_ text: String) {
        status = text
        working = false
        recognitionTask?.cancel()
        recognitionTask = nil
        cleanTemporaryFiles()
        chunks = []
    }

    private func cleanTemporaryFiles() {
        for chunk in chunks where chunk.temporary {
            try? FileManager.default.removeItem(at: chunk.url)
        }
    }

    private static func tokens(_ input: String) -> [String] {
        input.lowercased()
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }

    private static func timedWords(_ segments: [SFTranscriptionSegment],
                                   offset: TimeInterval) -> [TimedWord] {
        segments.flatMap { segment -> [TimedWord] in
            let parts = tokens(segment.substring)
            guard !parts.isEmpty else { return [] }
            let length = max(0.01, segment.duration)
            return parts.enumerated().map { i, word in
                let start = offset + segment.timestamp + length * Double(i) / Double(parts.count)
                let end = offset + segment.timestamp + length * Double(i + 1) / Double(parts.count)
                return TimedWord(word: word, start: start, end: end)
            }
        }
    }

    private static func match(_ lines: [LessonLine], words: [TimedWord],
                              duration: TimeInterval) -> [SentenceAlignmentSuggestion] {
        let sorted = words.sorted { $0.start < $1.start }
        let expectedPerLine = lines.map { tokens($0.english) }
        let expected = expectedPerLine.flatMap { $0 }
        let n = expected.count, m = sorted.count
        guard n > 0, m > 0 else { return [] }
        // Global, monotonic word alignment. Insertions/deletions cost 1;
        // substitutions cost 2, so only exact word matches generate timestamps.
        let width = m + 1
        var directions = [UInt8](repeating: 0, count: (n + 1) * width)
        var previous = Array(0...m)
        var current = [Int](repeating: 0, count: width)
        for i in 1...n {
            current[0] = i
            directions[i * width] = 1
            for j in 1...m {
                let equal = expected[i - 1] == sorted[j - 1].word
                let diagonal = previous[j - 1] + (equal ? 0 : 2)
                let up = previous[j] + 1
                let left = current[j - 1] + 1
                let cell = i * width + j
                if equal && diagonal <= up && diagonal <= left {
                    current[j] = diagonal
                    directions[cell] = 0
                } else if up <= left && up <= diagonal {
                    current[j] = up
                    directions[cell] = 1
                } else if left <= diagonal {
                    current[j] = left
                    directions[cell] = 2
                } else {
                    current[j] = diagonal
                    directions[cell] = 0
                }
            }
            swap(&previous, &current)
        }
        var positions = [Int?](repeating: nil, count: n)
        var i = n, j = m
        while i > 0 && j > 0 {
            switch directions[i * width + j] {
            case 0:
                if expected[i - 1] == sorted[j - 1].word {
                    positions[i - 1] = j - 1
                }
                i -= 1
                j -= 1
            case 1: i -= 1
            default: j -= 1
            }
        }
        var results: [SentenceAlignmentSuggestion] = []
        var cursor = 0
        for (index, lineWords) in expectedPerLine.enumerated() {
            let count = lineWords.count
            let matches = positions[cursor..<(cursor + count)].compactMap { $0 }
            cursor += count
            guard count > 0,
                  matches.count >= min(2, count),
                  Double(matches.count) / Double(count) >= 0.55,
                  let first = matches.first, let last = matches.last else { continue }
            let start = max(0, sorted[first].start - 0.06)
            let end = min(duration, sorted[last].end + 0.12)
            guard end > start + 0.1 else { continue }
            results.append(SentenceAlignmentSuggestion(index: index, start: start,
                                                       end: end, matchedWords: matches.count,
                                                       expectedWords: count))
        }
        // Reject overlapping candidates, which usually indicate recognition
        // ambiguity around a chunk boundary or a repeated phrase.
        var safe: [SentenceAlignmentSuggestion] = []
        for suggestion in results {
            if let last = safe.last, suggestion.start < last.end {
                continue
            }
            safe.append(suggestion)
        }
        return safe
    }
}
