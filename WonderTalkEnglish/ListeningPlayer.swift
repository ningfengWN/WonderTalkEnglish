
import Foundation
import AVFoundation
import Combine

@MainActor
final class ListeningPlayer: NSObject,
                             ObservableObject,
                             AVSpeechSynthesizerDelegate {

    @Published private(set) var sentences: [String] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isPaused = false

    private let synthesizer = AVSpeechSynthesizer()
    private var source = ""
    private var continuous = false

    var speed: Float = 0.48

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func load(_ text: String) {
        guard source != text else { return }

        stop()
        source = text

        // 将文章切分成句子，保留原有顺序。
        let normalized = text.replacingOccurrences(
            of: #"(?<=[.!?])\s+"#,
            with: "\n",
            options: .regularExpression
        )

        sentences = normalized
            .components(separatedBy: .newlines)
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }

        currentIndex = 0
    }

    func playAll() {
        if isPaused {
            resume()
        } else {
            play(at: currentIndex, continuous: true)
        }
    }

    func playSentence(_ index: Int) {
        play(at: index, continuous: false)
    }

    private func play(at index: Int, continuous: Bool) {
        guard sentences.indices.contains(index) else {
            return
        }

        synthesizer.stopSpeaking(at: .immediate)

        currentIndex = index
        self.continuous = continuous
        isPaused = false
        isPlaying = true

        let utterance = AVSpeechUtterance(
            string: sentences[index]
        )

        utterance.voice = AVSpeechSynthesisVoice(
            language: "en-US"
        )
        utterance.rate = speed

        synthesizer.speak(utterance)
    }

    func pause() {
        if synthesizer.pauseSpeaking(at: .word) {
            isPaused = true
            isPlaying = false
        }
    }

    func resume() {
        if synthesizer.continueSpeaking() {
            isPaused = false
            isPlaying = true
        }
    }

    func stop() {
        continuous = false
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
    }

    func previous() {
        let index = max(0, currentIndex - 1)
        play(at: index, continuous: true)
    }

    func next() {
        guard !sentences.isEmpty else { return }

        let index = min(
            sentences.count - 1,
            currentIndex + 1
        )

        play(at: index, continuous: true)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.isPlaying else {
                return
            }

            if self.continuous &&
               self.currentIndex + 1 < self.sentences.count {

                self.play(
                    at: self.currentIndex + 1,
                    continuous: true
                )
            } else {
                self.isPlaying = false
                self.isPaused = false
            }
        }
    }
}
