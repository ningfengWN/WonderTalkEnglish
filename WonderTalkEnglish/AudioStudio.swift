import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioStudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var isRecording = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentKey: String?
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var ticker: Timer?
    private var clipEnd: TimeInterval?

    private func bundledAudio(_ stem: String) -> URL? {
        for ext in ["m4a", "mp3", "wav", "aiff", "caf"] {
            if let url = Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: "Audio") {
                return url
            }
            if let url = Bundle.main.url(forResource: stem, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private func fullURL(for lesson: Lesson, mediaDirectory: URL) -> URL? {
        if let filename = lesson.audioFilename {
            let url = mediaDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        if let stem = lesson.fullAudioStem { return bundledAudio(stem) }
        return nil
    }

    func playFull(_ lesson: Lesson, mediaDirectory: URL, speed: Float) {
        guard let url = fullURL(for: lesson, mediaDirectory: mediaDirectory) else {
            errorMessage = "这节课程还没有音频。请先通过课程菜单导入真人 MP3。"
            return
        }
        start(url: url, key: "full_\(lesson.id)", speed: speed)
    }

    func toggleFull(_ lesson: Lesson, mediaDirectory: URL, speed: Float) {
        let key = "full_\(lesson.id)"
        if currentKey == key, let player {
            if isPlaying {
                player.pause()
                isPlaying = false
            } else {
                if player.currentTime >= player.duration - 0.05 { player.currentTime = 0 }
                player.enableRate = true
                player.rate = speed
                isPlaying = player.play()
                startTicker()
            }
        } else {
            playFull(lesson, mediaDirectory: mediaDirectory, speed: speed)
        }
    }

    func playSentence(_ lesson: Lesson, index: Int, mediaDirectory: URL, speed: Float) {
        guard lesson.lines.indices.contains(index) else { return }
        let line = lesson.lines[index]
        if line.isAligned,
           let url = fullURL(for: lesson, mediaDirectory: mediaDirectory),
           let start = line.start, let end = line.end {
            playClip(url: url, start: start, end: end,
                     key: "line_\(lesson.id)_\(index)", speed: speed)
        } else if let stem = lesson.sentenceStem(index),
                  let url = bundledAudio(stem) {
            start(url: url, key: "line_\(lesson.id)_\(index)", speed: speed)
        } else {
            errorMessage = "本句尚未对齐音频。请在阅读页点击「对齐时间」，标记本句起点和终点。"
        }
    }

    private func playClip(url: URL, start: Double, end: Double, key: String, speed: Float) {
        startPlayback(url: url, key: key, speed: speed, seek: start, clipEnd: end)
    }

    private func start(url: URL, key: String, speed: Float) {
        startPlayback(url: url, key: key, speed: speed, seek: 0, clipEnd: nil)
    }

    private func startPlayback(url: URL, key: String, speed: Float,
                               seek: Double, clipEnd: Double?) {
        stopPlayback()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.enableRate = true
            newPlayer.rate = speed
            newPlayer.prepareToPlay()
            guard seek < newPlayer.duration else {
                errorMessage = "句子起点超过音频时长，请重新对齐。"
                return
            }
            if let clipEnd, (clipEnd <= seek || clipEnd > newPlayer.duration + 0.1) {
                errorMessage = "句子终点无效，请重新对齐。"
                return
            }
            newPlayer.currentTime = max(0, seek)
            player = newPlayer
            self.clipEnd = clipEnd
            currentKey = key
            currentTime = newPlayer.currentTime
            duration = newPlayer.duration
            isPlaying = newPlayer.play()
            startTicker()
            errorMessage = nil
        } catch {
            errorMessage = "播放失败：\(error.localizedDescription)"
        }
    }

    func setSpeed(_ speed: Float) {
        player?.enableRate = true
        player?.rate = speed
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        player.currentTime = min(max(0, seconds), player.duration)
        currentTime = player.currentTime
        if let clipEnd, player.currentTime >= clipEnd { stopPlayback() }
    }

    func stopPlayback() {
        ticker?.invalidate()
        ticker = nil
        player?.stop()
        player = nil
        clipEnd = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentKey = nil
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if let clipEnd = self.clipEnd, player.currentTime >= clipEnd {
                    self.stopPlayback()
                }
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.isPlaying = false
            self.currentTime = self.duration
            self.ticker?.invalidate()
            self.ticker = nil
        }
    }

    func recordingURL(lessonID: String, sentenceIndex: Int) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("shadow_\(lessonID)_\(sentenceIndex + 1).m4a")
    }

    func hasRecording(lessonID: String, sentenceIndex: Int) -> Bool {
        FileManager.default.fileExists(atPath: recordingURL(lessonID: lessonID, sentenceIndex: sentenceIndex).path)
    }

    func requestRecording(lessonID: String, sentenceIndex: Int) {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.beginRecording(lessonID: lessonID, sentenceIndex: sentenceIndex)
                } else {
                    self.errorMessage = "请在设置中允许麦克风权限。"
                }
            }
        }
    }

    private func beginRecording(lessonID: String, sentenceIndex: Int) {
        stopPlayback()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = recordingURL(lessonID: lessonID, sentenceIndex: sentenceIndex)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.prepareToRecord()
            guard newRecorder.record() else {
                errorMessage = "无法启动录音。"
                return
            }
            recorder = newRecorder
            isRecording = true
            errorMessage = nil
        } catch {
            errorMessage = "录音失败：\(error.localizedDescription)"
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
    }

    func playRecording(lessonID: String, sentenceIndex: Int) {
        let url = recordingURL(lessonID: lessonID, sentenceIndex: sentenceIndex)
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "还没有本句录音。"
            return
        }
        start(url: url, key: "recording_\(lessonID)_\(sentenceIndex)", speed: 1)
    }

    func stopAll() {
        stopRecording()
        stopPlayback()
    }
}