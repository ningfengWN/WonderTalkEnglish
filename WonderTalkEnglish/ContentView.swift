import SwiftUI
import UniformTypeIdentifiers

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
        case .finish: "checkmark.seal"
        }
    }
}

struct ContentView: View {
    @StateObject private var courses = CourseStore()
    @StateObject private var audio = AudioStudio()

    @AppStorage("wt.v4.selectedLesson") private var lessonID = "rates"
    @AppStorage("wt.v4.completed") private var completed = ""
    @State private var step: StudyStep = .listen
    @State private var sentenceIndex = 0
    @State private var speed = 1.0
    @State private var showTranslation = true
    @State private var showNewLesson = false
    @State private var showAlignment = false
    @State private var importingAudio = false
    @State private var alertText: String?

    private let blue = Color(red: 0.07, green: 0.39, blue: 0.96)
    private let yellow = Color(red: 1, green: 0.80, blue: 0.18)

    private var lesson: Lesson? {
        courses.lesson(lessonID) ?? courses.lessons.first
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                blue.ignoresSafeArea()
                VStack(spacing: 14) {
                    header
                    stepsBar
                    Group {
                        if let lesson {
                            switch step {
                            case .listen: listenPage(lesson)
                            case .read: readPage(lesson)
                            case .shadow: shadowPage(lesson)
                            case .finish: finishPage(lesson)
                            }
                        } else {
                            ContentUnavailableView("尚无课程", systemImage: "books.vertical",
                                                   description: Text("请检查 Lessons 文件夹，或新建一节课程。"))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: 26))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .frame(maxWidth: 800)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .preferredColorScheme(.light)
        .onChange(of: lessonID) { _, _ in resetLesson() }
        .onChange(of: step) { _, _ in audio.stopAll() }
        .onChange(of: sentenceIndex) { _, _ in audio.stopAll() }
        .onChange(of: speed) { _, newValue in audio.setSpeed(Float(newValue)) }
        .onChange(of: audio.errorMessage) { _, newValue in
            if let newValue { alertText = newValue; audio.errorMessage = nil }
        }
        .onChange(of: courses.errorMessage) { _, newValue in
            if let newValue { alertText = newValue; courses.errorMessage = nil }
        }
        .sheet(isPresented: $showNewLesson) {
            NewLessonView { title, category, source, link, rights, transcript in
                if let id = courses.addLesson(title: title, category: category,
                                              sourceName: source, sourceURL: link,
                                              rightsNote: rights, transcript: transcript) {
                    lessonID = id
                    resetLesson()
                    showNewLesson = false
                }
            }
        }
        .sheet(isPresented: $showAlignment) {
            if let lesson {
                AlignmentView(lessonID: lesson.id, courses: courses, audio: audio)
            }
        }
        .fileImporter(isPresented: $importingAudio, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                audio.stopAll()
                courses.importAudio(from: url, for: lessonID)
            case .failure(let error):
                alertText = "文件选择失败：\(error.localizedDescription)"
            }
        }
        .alert("WonderTalk 提示", isPresented: Binding(
            get: { alertText != nil },
            set: { if !$0 { alertText = nil } }
        )) {
            Button("知道了") { alertText = nil }
        } message: {
            Text(alertText ?? "")
        }
    }

    private func resetLesson() {
        audio.stopAll()
        sentenceIndex = 0
        step = .listen
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.title)
                .foregroundStyle(yellow)
            VStack(alignment: .leading, spacing: 3) {
                Text("WONDERTALK ENGLISH · V4")
                    .font(.caption2.bold())
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.8))
                Text(lesson?.title ?? "Course Library")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Menu {
                Section("课程") {
                    ForEach(courses.lessons) { item in
                        Button(item.title) { lessonID = item.id }
                    }
                }
                Section("课程管理") {
                    Button("新建课程（粘贴逐句原文）", systemImage: "plus") {
                        showNewLesson = true
                    }
                    Button("为当前课程导入 MP3 / M4A", systemImage: "square.and.arrow.down") {
                        importingAudio = true
                    }
                    if lesson != nil {
                        Button("为当前课程对齐句子时间", systemImage: "waveform.path") {
                            showAlignment = true
                        }
                    }
                }
            } label: {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .accessibilityLabel("课程库与导入")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private var stepsBar: some View {
        HStack(spacing: 2) {
            ForEach(StudyStep.allCases, id: \.rawValue) { item in
                Button { step = item } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(item == step ? Color.black : blue)
                            .frame(width: 38, height: 38)
                            .background(item == step ? yellow : .white, in: Circle())
                        Text(item.title)
                            .font(.caption2.bold())
                            .foregroundStyle(item == step ? .white : .white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
    }

    private func listenPage(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("01", "Blind Listening", subtitle: "先泛听整篇文章，不看原文，抓住主题和逻辑。", lesson: lesson)
            Spacer(minLength: 8)
            VStack(spacing: 18) {
                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 82))
                    .foregroundStyle(blue)
                Text(lesson.subtitle)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                Text("Listen for the main idea, not every word.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 8)
            audioProgress
            HStack(spacing: 28) {
                Button {
                    audio.seek(to: max(0, audio.currentTime - 10))
                } label: { Image(systemName: "gobackward.10").font(.title) }
                Button {
                    audio.toggleFull(lesson, mediaDirectory: courses.mediaDirectory,
                                     speed: Float(speed))
                } label: {
                    Image(systemName: audio.isPlaying && audio.currentKey == "full_\(lesson.id)"
                          ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 80, height: 80)
                        .background(yellow, in: Circle())
                }
                Button {
                    audio.seek(to: audio.currentTime + 10)
                } label: { Image(systemName: "goforward.10").font(.title) }
            }
            .foregroundStyle(blue)
            .frame(maxWidth: .infinity)
            speedPicker
            if lesson.audioFilename == nil && lesson.bundledAudioStem == nil {
                Button("尚无音频 · 点击导入 MP3") { importingAudio = true }
                    .buttonStyle(.bordered)
            }
            sourceLine(lesson)
            Button("下一步 · 阅读原文") { step = .read }
                .buttonStyle(.borderedProminent)
                .tint(blue)
                .frame(maxWidth: .infinity)
        }
        .padding(22)
    }

    private func readPage(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("02", "Read & Understand", subtitle: "逐句阅读。点击扬声器，收听与原音频对齐的句子。", lesson: lesson)
            HStack {
                Toggle("中文释义", isOn: $showTranslation)
                    .font(.subheadline)
                Spacer(minLength: 8)
                Button("对齐时间") { showAlignment = true }
                    .font(.subheadline.bold())
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(lesson.lines) { line in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Text(line.english)
                                    .font(.system(size: 18, weight: .medium))
                                    .lineSpacing(4)
                                Spacer(minLength: 3)
                                Button {
                                    audio.playSentence(lesson, index: line.id,
                                                       mediaDirectory: courses.mediaDirectory,
                                                       speed: Float(speed))
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                            if showTranslation && !line.chinese.isEmpty {
                                Text(line.chinese)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if line.isAligned {
                                Text("\(formatTime(line.start ?? 0)) – \(formatTime(line.end ?? 0))")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.96, green: 0.97, blue: 0.99),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            Button("下一步 · 逐句跟读") {
                sentenceIndex = 0
                step = .shadow
            }
            .buttonStyle(.borderedProminent)
            .tint(blue)
        }
        .padding(18)
    }

    private func shadowPage(_ lesson: Lesson) -> some View {
        let index = min(sentenceIndex, max(0, lesson.lines.count - 1))
        let line = lesson.lines[index]
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Sentence \(index + 1)/\(lesson.lines.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("SHADOWING")
                    .font(.caption.bold())
                    .foregroundStyle(blue)
            }
            speedPicker
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        Text(line.english)
                            .font(.system(size: 27, weight: .bold))
                            .foregroundStyle(Color(red: 0.29, green: 0.41, blue: 0.57))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 5)
                        Button {
                            audio.playSentence(lesson, index: index,
                                               mediaDirectory: courses.mediaDirectory,
                                               speed: Float(speed))
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                        }
                    }
                    if !line.chinese.isEmpty {
                        Text(line.chinese)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        audio.playSentence(lesson, index: index,
                                           mediaDirectory: courses.mediaDirectory,
                                           speed: Float(speed))
                    } label: {
                        Label("播放真人示范 / 单句音频", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    if !line.isAligned && lesson.isImported {
                        Button("本句尚未对齐 · 前往标记时间") { showAlignment = true }
                            .font(.caption)
                    }
                    if audio.hasRecording(lessonID: lesson.id, sentenceIndex: index) {
                        Button {
                            audio.playRecording(lessonID: lesson.id, sentenceIndex: index)
                        } label: {
                            Label("回放我的录音", systemImage: "waveform")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            }
            HStack {
                Text("第 \(index + 1) 句")
                Slider(value: Binding(
                    get: { Double(index) },
                    set: { sentenceIndex = Int($0.rounded()) }
                ), in: 0...Double(max(1, lesson.lines.count - 1)), step: 1)
                Text("共 \(lesson.lines.count) 句")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button { sentenceIndex = max(0, index - 1) } label: {
                    control("backward.end.fill", "上一句")
                }
                .disabled(index == 0)
                Spacer()
                Button {
                    if audio.isRecording {
                        audio.stopRecording()
                    } else {
                        audio.requestRecording(lessonID: lesson.id, sentenceIndex: index)
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: audio.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 92, height: 92)
                            .background(audio.isRecording ? Color.red : yellow, in: Circle())
                        Text(audio.isRecording ? "停止录音" : "点击录音")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    if index < lesson.lines.count - 1 {
                        sentenceIndex += 1
                    } else {
                        step = .finish
                    }
                } label: {
                    control("forward.end.fill", index == lesson.lines.count - 1 ? "完成" : "下一句")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }

    private func finishPage(_ lesson: Lesson) -> some View {
        let count = lesson.lines.filter {
            audio.hasRecording(lessonID: lesson.id, sentenceIndex: $0.id)
        }.count
        return VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 78))
                .foregroundStyle(.green)
            Text("Lesson Complete")
                .font(.largeTitle.bold())
            Text("已录制 \(count) / \(lesson.lines.count) 句\n录音保存在当前设备。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                let ids = Set(completed.split(separator: ",").map(String.init))
                completed = ids.union([lesson.id]).sorted().joined(separator: ",")
            } label: {
                Label(completed.split(separator: ",").contains(Substring(lesson.id))
                      ? "已保存学习进度" : "保存完成记录", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(blue)
            Button("重新学习") { step = .listen; sentenceIndex = 0 }
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private func heading(_ number: String, _ title: String, subtitle: String,
                         lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STEP \(number) · \(lesson.category)")
                .font(.caption.bold())
                .foregroundStyle(blue)
            Text(title)
                .font(.system(size: 26, weight: .semibold, design: .serif))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func sourceLine(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if !lesson.sourceName.isEmpty {
                Text("来源：\(lesson.sourceName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let url = URL(string: lesson.sourceURL),
               url.scheme == "https" {
                Link("打开原始资料", destination: url)
                    .font(.caption)
            }
            if !lesson.rightsNote.isEmpty {
                Text(lesson.rightsNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    private var speedPicker: some View {
        Picker("语速", selection: $speed) {
            Text("0.8×").tag(0.8)
            Text("1.0×").tag(1.0)
            Text("1.25×").tag(1.25)
        }
        .pickerStyle(.segmented)
    }

    private var audioProgress: some View {
        VStack(spacing: 4) {
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

    private func control(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 52, height: 52)
                .background(Color(red: 0.90, green: 0.94, blue: 1), in: Circle())
            Text(text).font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

// MARK: - Create a lesson by pasting a sentence-per-line transcript

private struct NewLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = "FINANCE · B1–B2"
    @State private var sourceName = "VOA Learning English"
    @State private var sourceURL = ""
    @State private var rightsNote = "Please verify that this recording and text are VOA-owned, not third-party material. Credit: learningenglish.voanews.com"
    @State private var transcript = ""

    let onCreate: (String, String, String, String, String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("课程信息") {
                    TextField("课程标题", text: $title)
                    TextField("分类 / 难度", text: $category)
                    TextField("素材来源", text: $sourceName)
                    TextField("原文网址（https://）", text: $sourceURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("英文原文 · 每行一句") {
                    Text("请从有合法使用权限的素材中整理英文原文，一行一个句子。可先只输入 5–10 句测试。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $transcript)
                        .frame(minHeight: 220)
                        .font(.body)
                }
                Section("来源与授权记录") {
                    TextEditor(text: $rightsNote)
                        .frame(minHeight: 90)
                }
                Section {
                    Text("创建后选择 MP3 / M4A。真人长录音还需逐句标记时间，才能准确跟读。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("导入英语课程")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        onCreate(title, category, sourceName, sourceURL,
                                 rightsNote, transcript)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                              transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Manual sentence-level alignment for genuine long recordings

private struct AlignmentView: View {
    @Environment(\.dismiss) private var dismiss
    let lessonID: String
    @ObservedObject var courses: CourseStore
    @ObservedObject var audio: AudioStudio
    @State private var index = 0
    @State private var speed = 1.0
    @State private var translation = ""

    private var lesson: Lesson? { courses.lesson(lessonID) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if let lesson, !lesson.lines.isEmpty {
                    let line = lesson.lines[min(index, lesson.lines.count - 1)]
                    Text("第 \(index + 1) / \(lesson.lines.count) 句")
                        .font(.headline)
                    Text(line.english)
                        .font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text("起点：\(stamp(line.start))")
                        Spacer()
                        Text("终点：\(stamp(line.end))")
                    }
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    HStack {
                        Button(audio.isPlaying ? "暂停" : "播放整篇") {
                            audio.toggleFull(lesson, mediaDirectory: courses.mediaDirectory,
                                             speed: Float(speed))
                        }
                        .buttonStyle(.borderedProminent)
                        Button("试听本句") {
                            audio.playSentence(lesson, index: index,
                                               mediaDirectory: courses.mediaDirectory,
                                               speed: Float(speed))
                        }
                        .buttonStyle(.bordered)
                    }
                    Slider(value: Binding(
                        get: { min(audio.currentTime, max(1, audio.duration)) },
                        set: { audio.seek(to: $0) }
                    ), in: 0...max(1, audio.duration))
                    HStack {
                        Text("播放位置 \(stamp(audio.currentTime))")
                        Spacer()
                        Text("总时长 \(stamp(audio.duration))")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button("设为本句起点") {
                            courses.setBoundary(lessonID: lessonID, lineIndex: index,
                                                isStart: true, seconds: audio.currentTime)
                        }
                        .buttonStyle(.borderedProminent)
                        Button("设为本句终点") {
                            courses.setBoundary(lessonID: lessonID, lineIndex: index,
                                                isStart: false, seconds: audio.currentTime)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    HStack {
                        Button("上一句") { index = max(0, index - 1) }
                            .disabled(index == 0)
                        Spacer()
                        Button("下一句") { index = min(lesson.lines.count - 1, index + 1) }
                            .disabled(index >= lesson.lines.count - 1)
                    }
                    .buttonStyle(.bordered)
                    Divider()
                    Text("操作：播放音频 → 拖动到句子起点 → 标记起点 → 拖动到终点 → 标记终点 → 试听。时间戳自动保存在本机。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    Text("找不到课程。")
                }
            }
            .padding(20)
            .navigationTitle("逐句时间对齐")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { audio.stopPlayback(); dismiss() }
                }
            }
            .onDisappear { audio.stopPlayback() }
        }
    }

    private func stamp(_ time: Double?) -> String {
        guard let time, time.isFinite else { return "--:--.-" }
        let value = max(0, time)
        return String(format: "%02d:%04.1f", Int(value) / 60, value.truncatingRemainder(dividingBy: 60))
    }
}

private func formatTime(_ time: Double) -> String {
    let value = Int(max(0, time.isFinite ? time : 0))
    return String(format: "%02d:%02d", value / 60, value % 60)
}