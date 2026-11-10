import SwiftUI

private enum StudyStep: Int, CaseIterable {
    case listen, read, shadow, finish

    var title: String {
        switch self {
        case .listen: "泛听"
        case .read: "原文"
        case .shadow: "跟读"
        case .finish: "完成"
        }
    }

    var symbol: String {
        switch self {
        case .listen: "headphones"
        case .read: "text.book.closed"
        case .shadow: "mic"
        case .finish: "checkmark"
        }
    }
}

struct ContentView: View {
    @StateObject private var audio = AudioStudio()
    @AppStorage("wt.v3.lesson") private var lessonID = "rates"
    @AppStorage("wt.v3.completed") private var completed = ""

    @State private var step: StudyStep = .listen
    @State private var sentenceIndex = 0
    @State private var speed = 1.0
    @State private var showTranslation = true

    private let blue = Color(red: 0.07, green: 0.39, blue: 0.96)
    private let yellow = Color(red: 1, green: 0.80, blue: 0.18)

    private var lesson: Lesson {
        Lesson.all.first(where: { $0.id == lessonID }) ?? Lesson.all[0]
    }

    private var currentSentence: LessonLine {
        lesson.lines[sentenceIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                blue.ignoresSafeArea()

                VStack(spacing: 16) {
                    header
                    stepsBar

                    VStack(spacing: 0) {
                        switch step {
                        case .listen: listenPage
                        case .read: readPage
                        case .shadow: shadowPage
                        case .finish: finishPage
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28))
                    .padding(.horizontal, 15)
                    .padding(.bottom, 12)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .preferredColorScheme(.light)
        .onChange(of: lessonID) { _, _ in
            audio.stopAll()
            sentenceIndex = 0
            step = .listen
        }
        .onChange(of: step) { _, _ in
            audio.stopAll()
        }
        .onChange(of: sentenceIndex) { _, _ in
            audio.stopAll()
        }
        .onChange(of: speed) { _, value in
            audio.setSpeed(Float(value))
        }
        .alert("音频提示", isPresented: Binding(
            get: { audio.errorMessage != nil },
            set: { if !$0 { audio.errorMessage = nil } }
        )) {
            Button("知道了") { audio.errorMessage = nil }
        } message: {
            Text(audio.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title2)
                .foregroundStyle(yellow)

            VStack(alignment: .leading, spacing: 3) {
                Text("WONDERTALK ENGLISH")
                    .font(.caption2.bold())
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.75))
                Text(lesson.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 5)

            Menu {
                ForEach(Lesson.all) { item in
                    Button(item.title) { lessonID = item.id }
                }
            } label: {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.16), in: Circle())
            }
            .accessibilityLabel("切换课程")
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private var stepsBar: some View {
        HStack(spacing: 3) {
            ForEach(StudyStep.allCases, id: \.rawValue) { item in
                Button {
                    step = item
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(item == step ? yellow : .white.opacity(0.95))
                                .frame(width: 39, height: 39)
                            Image(systemName: item.symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(item == step ? Color.black : blue)
                        }
                        Text(item.title)
                            .font(.caption2.bold())
                            .foregroundStyle(item == step ? .white : .white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
    }

    private var listenPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("01", "Blind Listening", subtitle: "第一遍只听声音，不看原文。尝试理解文章的主要观点。")

            Spacer(minLength: 8)

            VStack(spacing: 20) {
                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(blue)

                Text(lesson.subtitle)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.27, green: 0.37, blue: 0.52))

                Text("Listen for the main idea, not every word.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 8)

            audioProgress

            HStack(spacing: 26) {
                Button {
                    audio.seek(to: max(0, audio.currentTime - 10))
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title)
                }

                Button {
                    audio.toggle(lesson.fullAudioStem, speed: Float(speed))
                } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 78, height: 78)
                        .background(yellow, in: Circle())
                }

                Button {
                    audio.seek(to: audio.currentTime + 10)
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.title)
                }
            }
            .foregroundStyle(blue)
            .frame(maxWidth: .infinity)

            speedPicker

            Button {
                step = .read
            } label: {
                Text("下一步 · 阅读原文")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(blue)
        }
        .padding(24)
    }

    private var readPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("02", "Read & Understand", subtitle: "阅读英文，理解内容。点击扬声器收听单句。")

            Toggle("显示中文释义", isOn: $showTranslation)
                .font(.subheadline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(lesson.lines) { line in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(alignment: .top) {
                                Text(line.english)
                                    .font(.system(size: 18, weight: .medium))
                                    .lineSpacing(5)
                                    .foregroundStyle(Color(red: 0.24, green: 0.35, blue: 0.52))
                                Spacer(minLength: 6)
                                Button {
                                    audio.play(lesson.sentenceStem(line.id), speed: Float(speed))
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(Color.orange)
                                }
                            }
                            if showTranslation {
                                Text(line.chinese)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.96, green: 0.97, blue: 0.99), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            Button {
                sentenceIndex = 0
                step = .shadow
            } label: {
                Text("下一步 · 逐句跟读")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(blue)
        }
        .padding(20)
    }

    private var shadowPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sentence \(sentenceIndex + 1)/\(lesson.lines.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("SHADOWING")
                    .font(.caption.bold())
                    .foregroundStyle(blue)
            }

            speedPicker

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(currentSentence.english)
                            .font(.system(size: 29, weight: .bold))
                            .foregroundStyle(Color(red: 0.29, green: 0.41, blue: 0.57))
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            audio.play(lesson.sentenceStem(sentenceIndex), speed: Float(speed))
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title3)
                                .foregroundStyle(Color.orange)
                        }
                    }

                    Text(currentSentence.chinese)
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("示范音频")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack {
                            Button {
                                audio.toggle(lesson.sentenceStem(sentenceIndex), speed: Float(speed))
                            } label: {
                                Image(systemName: audio.isPlaying && audio.currentStem == lesson.sentenceStem(sentenceIndex) ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(Color.orange)
                            }
                            audioProgress
                        }
                    }
                    .padding(14)
                    .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))

                    if audio.hasRecording(lessonID: lesson.id, sentenceIndex: sentenceIndex) {
                        Button {
                            audio.playRecording(lessonID: lesson.id, sentenceIndex: sentenceIndex)
                        } label: {
                            Label("回放我的录音", systemImage: "waveform")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(blue)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 18)
            }

            HStack {
                Text("第 \(sentenceIndex + 1) 句")
                Slider(value: Binding(
                    get: { Double(sentenceIndex) },
                    set: { sentenceIndex = Int($0.rounded()) }
                ), in: 0...Double(max(0, lesson.lines.count - 1)), step: 1)
                Text("共 \(lesson.lines.count) 句")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 12) {
                Button {
                    sentenceIndex = max(0, sentenceIndex - 1)
                } label: {
                    controlLabel("backward.end.fill", "上一句")
                }
                .disabled(sentenceIndex == 0)

                Spacer()

                Button {
                    if audio.isRecording {
                        audio.stopRecording()
                    } else {
                        audio.requestRecording(lessonID: lesson.id, sentenceIndex: sentenceIndex)
                    }
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: audio.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(audio.isRecording ? Color.red : yellow, in: Circle())
                            .shadow(color: yellow.opacity(0.3), radius: 10, y: 6)
                        Text(audio.isRecording ? "停止录音" : "点击录音")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    if sentenceIndex < lesson.lines.count - 1 {
                        sentenceIndex += 1
                    } else {
                        step = .finish
                    }
                } label: {
                    controlLabel("forward.end.fill", sentenceIndex == lesson.lines.count - 1 ? "完成" : "下一句")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(22)
    }

    private var finishPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 85))
                .foregroundStyle(Color.green)
            Text("Lesson Complete")
                .font(.largeTitle.bold())
            Text("你已经完成泛听、阅读和逐句跟读。\n录音保存在当前设备，可随时回来复听。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("已录音 \(recordingCount) / \(lesson.lines.count) 句")
                .font(.headline)

            Button {
                let ids = Set(completed.split(separator: ",").map(String.init))
                completed = ids.union([lesson.id]).sorted().joined(separator: ",")
            } label: {
                Label(completed.split(separator: ",").contains(Substring(lesson.id)) ? "已保存学习进度" : "保存完成记录", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(blue)

            Button("重新练习") {
                sentenceIndex = 0
                step = .listen
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var recordingCount: Int {
        lesson.lines.filter { audio.hasRecording(lessonID: lesson.id, sentenceIndex: $0.id) }.count
    }

    private func controlLabel(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color(red: 0.29, green: 0.41, blue: 0.57))
                .frame(width: 54, height: 54)
                .background(Color(red: 0.90, green: 0.94, blue: 1), in: Circle())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sectionHeading(_ number: String, _ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STEP \(number) · \(lesson.category)")
                .font(.caption.bold())
                .foregroundStyle(blue)
            Text(title)
                .font(.system(size: 27, weight: .semibold, design: .serif))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var speedPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("播放速度")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("播放速度", selection: $speed) {
                Text("0.8×").tag(0.8)
                Text("1.0×").tag(1.0)
                Text("1.25×").tag(1.25)
            }
            .pickerStyle(.segmented)
        }
    }

    private var audioProgress: some View {
        VStack(spacing: 5) {
            Slider(value: Binding(
                get: { min(audio.currentTime, max(1, audio.duration)) },
                set: { audio.seek(to: $0) }
            ), in: 0...max(1, audio.duration))
            .tint(yellow)

            HStack {
                Text(formatTime(audio.currentTime))
                Spacer()
                Text(formatTime(audio.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func formatTime(_ value: TimeInterval) -> String {
        let seconds = Int(max(0, value.isFinite ? value : 0))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
