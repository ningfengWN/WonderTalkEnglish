import SwiftUI
import AVFoundation
import Speech
import Combine

// Chinese pinyin practice: visual recognition and word-level speech practice.
// Speech recognition is a learning hint, not a phoneme-level pronunciation score.
private struct PinyinCard: Identifiable {
    let id: String
    let initial: String
    let pinyin: String
    let word: String
    let hint: String
    let group: Int

    static let all: [PinyinCard] = [
        .init(id: "b", initial: "b", pinyin: "bāo zi", word: "包子",
              hint: "b：竖在左边，圆肚子在右边。读“包子”，感受不送气。", group: 0),
        .init(id: "p", initial: "p", pinyin: "píng guǒ", word: "苹果",
              hint: "p：竖往下伸，圆肚子在右边。读“苹果”，气流更明显。", group: 0),
        .init(id: "d", initial: "d", pinyin: "dà xiàng", word: "大象",
              hint: "d：圆肚子在左边，竖在右边。记住 d 和 b 方向相反。", group: 0),
        .init(id: "q", initial: "q", pinyin: "qì qiú", word: "气球",
              hint: "q：圆肚子在左边，竖往下伸。记住 q 和 p 方向相反。", group: 0),
        .init(id: "zh", initial: "zh", pinyin: "zhī zhū", word: "蜘蛛",
              hint: "zh：舌尖稍向上、向后翘。先听“蜘蛛”，再模仿。", group: 1),
        .init(id: "ch", initial: "ch", pinyin: "chī fàn", word: "吃饭",
              hint: "ch：翘舌并明显送气。可在嘴前放纸片感受气流。", group: 1),
        .init(id: "sh", initial: "sh", pinyin: "shī zi", word: "狮子",
              hint: "sh：舌尖稍翘，气流持续摩擦，不要读成 s。", group: 1),
        .init(id: "z", initial: "z", pinyin: "zǎo shang", word: "早上",
              hint: "z：舌尖靠近上齿龈，不翘舌，送气较弱。", group: 1),
        .init(id: "c", initial: "c", pinyin: "cǎo méi", word: "草莓",
              hint: "c：平舌并明显送气，与 z 对比。", group: 1),
        .init(id: "s", initial: "s", pinyin: "sān ge", word: "三个",
              hint: "s：平舌，气流持续摩擦，与 sh 对比。", group: 1)
    ]
}

@MainActor
private final class PinyinVoiceCoach: NSObject, ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var recognizing = false
    @Published private(set) var recognized = ""
    @Published private(set) var message = ""
    @Published private(set) var recordingAvailable = false

    private let synth = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordingURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("wondertalk_pinyin_latest.m4a")
    }

    func demonstrate(_ word: String) {
        if recording { return }
        player?.stop()
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.42
        synth.speak(utterance)
    }

    func start() {
        guard !recording && !recognizing else { return }
        synth.stopSpeaking(at: .immediate)
        player?.stop()
        recognized = ""
        message = ""
        recordingAvailable = false
        recognitionTask?.cancel()
        recognitionTask = nil

        AVAudioApplication.requestRecordPermission { [weak self] allowed in
            Task { @MainActor in
                guard let self else { return }
                if allowed {
                    self.beginRecording()
                } else {
                    self.message = "请在系统设置中允许 WonderTalk 使用麦克风。"
                }
            }
        }
    }

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let newRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            guard newRecorder.prepareToRecord(), newRecorder.record() else {
                message = "录音没有启动，请检查模拟器麦克风。"
                return
            }
            recorder = newRecorder
            recording = true
            message = "正在录音，请清楚读出屏幕上的词语，再点击停止。"
        } catch {
            message = "无法录音：\(error.localizedDescription)"
        }
    }

    func stopAndRecognize() {
        guard recording else { return }
        recorder?.stop()
        recorder = nil
        recording = false
        recordingAvailable = FileManager.default.fileExists(atPath: recordingURL.path)
        guard recordingAvailable else {
            message = "没有保存到录音，请重试。"
            return
        }
        recognizing = true
        message = "录音已保存，正在尝试识别中文词语……"

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                guard status == .authorized else {
                    self.recognizing = false
                    self.message = "语音识别未授权。仍可回放录音，请家长帮助判断。"
                    return
                }
                self.recognizeFile()
            }
        }
    }

    private func recognizeFile() {
        guard let recognizer, recognizer.isAvailable else {
            recognizing = false
            message = "中文语音识别暂不可用。可以回放录音并由家长判断。"
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            recognizing = false
            message = "当前设备不支持离线中文语音识别。录音已保存，请回放并由家长判断。"
            return
        }
        let request = SFSpeechURLRecognitionRequest(url: recordingURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.recognized = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.recognizing = false
                        self.message = "识别完成。请结合录音听辨，自动识别不等于发音评分。"
                    }
                }
                if let error {
                    self.recognizing = false
                    self.message = "未能完成自动识别：\(error.localizedDescription)。可回放后由家长判断。"
                }
            }
        }
    }

    func replay() {
        guard recordingAvailable && !recording else { return }
        synth.stopSpeaking(at: .immediate)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker])
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: recordingURL)
            player?.play()
        } catch {
            message = "回放失败：\(error.localizedDescription)"
        }
    }

    func reset() {
        recorder?.stop()
        recorder = nil
        player?.stop()
        synth.stopSpeaking(at: .immediate)
        recognitionTask?.cancel()
        recognitionTask = nil
        recording = false
        recognizing = false
        recognized = ""
        message = ""
        recordingAvailable = false
    }
}

struct PinyinPracticeView: View {
    @StateObject private var coach = PinyinVoiceCoach()
    @AppStorage("wt.pinyin.visualCorrect") private var visualCorrect = 0
    @AppStorage("wt.pinyin.voicePractices") private var voicePractices = 0
    @State private var group = 0
    @State private var index = 0
    @State private var mode = 0
    @State private var answer: String?
    @State private var parentFeedback: String?

    private let blue = Color(red: 0.07, green: 0.39, blue: 0.96)
    private let yellow = Color(red: 1, green: 0.80, blue: 0.18)
    private var cards: [PinyinCard] { PinyinCard.all.filter { $0.group == group } }
    private var card: PinyinCard { cards[min(index, cards.count - 1)] }
    private var choices: [String] { group == 0 ? ["b", "p", "d", "q"] : ["zh", "ch", "sh", "z", "c", "s"] }

    var body: some View {
        ZStack {
            blue.ignoresSafeArea()
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("拼音小勇士")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("看清字母 · 听清发音 · 勇敢开口")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(yellow)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                HStack(spacing: 8) {
                    groupButton("b p d q", value: 0)
                    groupButton("zh ch sh / z c s", value: 1)
                }
                .padding(.horizontal, 12)

                VStack(spacing: 10) {
                    Picker("练习模式", selection: $mode) {
                        Text("认字形").tag(0)
                        Text("听音跟读").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in resetQuestion() }

                    HStack {
                        Text("第 \(index + 1) / \(cards.count) 题")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("已认对 \(visualCorrect) · 跟读 \(voicePractices)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        VStack(spacing: 14) {
                            Text(card.initial)
                                .font(.system(size: 100, weight: .bold, design: .rounded))
                                .foregroundStyle(blue)
                                .minimumScaleFactor(0.6)
                                .accessibilityLabel("目标声母 \(card.initial)")

                            if mode == 0 {
                                visualSection
                            } else {
                                voiceSection
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    HStack(spacing: 12) {
                        Button {
                            index = (index - 1 + cards.count) % cards.count
                            resetQuestion()
                        } label: {
                            Label("上一题", systemImage: "chevron.left")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            index = (index + 1) % cards.count
                            resetQuestion()
                        } label: {
                            Label("下一题", systemImage: "chevron.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(blue)
                    }
                }
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .onDisappear { coach.reset() }
    }

    private func groupButton(_ title: String, value: Int) -> some View {
        Button {
            group = value
            index = 0
            resetQuestion()
        } label: {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(group == value ? yellow : .white.opacity(0.22),
                            in: Capsule())
                .foregroundStyle(group == value ? .black : .white)
        }
        .buttonStyle(.plain)
    }

    private var visualSection: some View {
        VStack(spacing: 14) {
            Text("请找到和上面一样的字母")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(choices, id: \.self) { option in
                    Button {
                        guard answer == nil else { return }
                        answer = option
                        if option == card.initial { visualCorrect += 1 }
                    } label: {
                        Text(option)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 75)
                            .foregroundStyle(blue)
                            .background(answer == option
                                        ? (option == card.initial ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                        : Color(red: 0.94, green: 0.96, blue: 1),
                                        in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            if let answer {
                Text(answer == card.initial ? "⭐ 找对啦！" : "再看一看字母的圆肚子和竖线方向。")
                    .font(.subheadline.bold())
                    .foregroundStyle(answer == card.initial ? .green : .orange)
            }
            Text(card.hint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var voiceSection: some View {
        VStack(spacing: 12) {
            Text(card.pinyin)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(blue)
            Text(card.word)
                .font(.system(size: 32, weight: .semibold))
            Button {
                coach.demonstrate(card.word)
            } label: {
                Label("听标准示范", systemImage: "speaker.wave.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                if coach.recording {
                    coach.stopAndRecognize()
                    voicePractices += 1
                } else {
                    coach.start()
                }
            } label: {
                Label(coach.recording ? "停止并识别" : "点击录音跟读",
                      systemImage: coach.recording ? "stop.circle.fill" : "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(coach.recording ? .red : blue)
            .disabled(coach.recognizing)

            if coach.recordingAvailable {
                Button {
                    coach.replay()
                } label: {
                    Label("回放我的声音", systemImage: "play.circle")
                }
                .buttonStyle(.bordered)
            }
            if coach.recognizing {
                ProgressView("正在识别……")
            }
            if !coach.recognized.isEmpty {
                VStack(spacing: 6) {
                    Text("系统听到：\(coach.recognized)")
                    if coach.recognized.contains(card.word) {
                        Text("识别到了目标词语 ✓（不代表声母发音完全正确）")
                            .foregroundStyle(.green)
                    } else {
                        Text("没有识别到目标词语，可重听或让家长帮助判断。")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)
            }
            if !coach.message.isEmpty {
                Text(coach.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button("家长确认：读对了") { parentFeedback = "⭐ 太棒了！" }
                Button("再练一次") { parentFeedback = "听示范，慢慢读，不着急。" }
            }
            .buttonStyle(.bordered)
            .font(.caption)
            if let parentFeedback {
                Text(parentFeedback)
                    .font(.subheadline.bold())
            }
            Text(card.hint)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("提示：自动识别只检查完整词语，不是专业声母发音评分。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func resetQuestion() {
        coach.reset()
        answer = nil
        parentFeedback = nil
    }
}
