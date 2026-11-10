import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioStudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var isRecording = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentStem: String?
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var ticker: Timer?
    private var rate: Float = 1.0

    private func audioURL(_ stem: String) -> URL? {
        for ext in ["aiff", "m4a", "mp3", "wav"] {
            if let url = Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: "Audio") {
                return url
            }
            if let url = Bundle.main.url(forResource: stem, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    func play(_ stem: String, speed: Float = 1.0) {
        stopPlayback()
        guard let url = audioURL(stem) else {
            errorMessage = "找不到音频 \(stem)。请将 Audio 文件夹添加到 App Target。"
            return
        }
        playURL(url, stem: stem, speed: speed)
    }

    private func playURL(_ url: URL, stem: String, speed: Float) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.enableRate = true
            newPlayer.rate = speed
            newPlayer.prepareToPlay()
            player = newPlayer
            currentStem = stem
            rate = speed
            duration = newPlayer.duration
            currentTime = 0
            isPlaying = newPlayer.play()
            startTicker()
            errorMessage = nil
        } catch {
            errorMessage = "音频播放失败：\(error.localizedDescription)"
        }
    }

    func toggle(_ stem: String, speed: Float) {
        if currentStem == stem, let player {
            if isPlaying {
                player.pause()
                isPlaying = false
            } else {
                if currentTime >= duration - 0.05 { player.currentTime = 0 }
                player.enableRate = true
                player.rate = speed
                isPlaying = player.play()
                startTicker()
            }
        } else {
            play(stem, speed: speed)
        }
    }

    func setSpeed(_ newSpeed: Float) {
        rate = newSpeed
        player?.enableRate = true
        player?.rate = newSpeed
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, time), player.duration)
        currentTime = player.currentTime
    }

    func stopPlayback() {
        ticker?.invalidate()
        ticker = nil
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentStem = nil
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isPlaying = false
            self.currentTime = self.duration
            self.ticker?.invalidate()
            self.ticker = nil
        }
    }

    func recordingURL(lessonID: String, sentenceIndex: Int) -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("shadow_\(lessonID)_\(sentenceIndex + 1).m4a")
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
            errorMessage = "还没有录音，请先点击录音按钮。"
            return
        }
        stopPlayback()
        playURL(url, stem: "my_recording", speed: 1)
    }

    func stopAll() {
        stopRecording()
        stopPlayback()
    }
}
