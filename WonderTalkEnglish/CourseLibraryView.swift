import SwiftUI

/// The main course-management page. Sources open the existing lesson detail,
/// while study actions use the existing daily-English practice flow.
struct CourseLibraryView: View {
    @ObservedObject var courses: CourseStore
    let onSource: (Lesson) -> Void
    let onStudy: (Lesson) -> Void
    let onImport: () -> Void
    let onCreate: () -> Void
    let onAccount: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var group: Group = .daily

    private enum Group: String, CaseIterable {
        case daily = "日常英语"
        case knowledge = "知识英语"
    }

    private var visibleLessons: [Lesson] {
        courses.lessons.filter { lesson in
            group == .daily ? !lesson.isKnowledgeEnglish : lesson.isKnowledgeEnglish
        }.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WonderTalk English")
                        .font(.title2.bold())
                    Text("我的英语课程 · 选择学习内容")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onAccount) {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                        .padding(8)
                }
                .accessibilityLabel("学习账号")
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 12)

            Picker("课程类别", selection: $group) {
                ForEach(Group.allCases, id: \.self) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.bottom, 12)

            HStack {
                Text(group == .daily
                     ? "听力 · 阅读 · 逐句跟读 · 录音"
                     : "财经 · 财报 · 历史 · 原站听力/视频")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(visibleLessons.count) 篇")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(visibleLessons) { lesson in
                        lessonRow(lesson)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            HStack(spacing: 12) {
                Button(action: onImport) {
                    Label("批量导入资料", systemImage: "square.and.arrow.down")
                }
                Button(action: onCreate) {
                    Label("新建课程", systemImage: "plus.circle")
                }
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(lesson.id.uppercased())
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(.blue)
                Text(lesson.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Label(lesson.sourceName, systemImage: "link")
                    .lineLimit(1)
                Spacer(minLength: 4)
                Label(lesson.durationLabel, systemImage: "clock")
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    onSource(lesson)
                } label: {
                    Label("来源 / 详情", systemImage: "info.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                if lesson.isKnowledgeEnglish {
                    Button {
                        guard let url = URL(string: lesson.sourceURL),
                              url.scheme?.lowercased() == "https" else { return }
                        openURL(url)
                    } label: {
                        Label("听力 / 视频", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(URL(string: lesson.sourceURL)?.scheme?.lowercased() != "https")
                } else {
                    Button {
                        onStudy(lesson)
                    } label: {
                        Label("学习", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}
