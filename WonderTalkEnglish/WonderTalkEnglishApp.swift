import SwiftUI

@main
struct WonderTalkEnglishApp: App {
    var body: some Scene {
        WindowGroup {
            FamilyEntryView()
        }
    }
}

/// A lightweight entry screen that does not initialize audio, lesson views,
/// microphone services, or network clients until a profile is selected.
private struct FamilyEntryView: View {
    @AppStorage("wt.family.activeProfile") private var activeProfile = "adult"
    @State private var hasEntered = false

    private let blue = Color(red: 0.07, green: 0.39, blue: 0.96)

    var body: some View {
        Group {
            if hasEntered {
                ContentView()
                    .id(activeProfile)
            } else {
                profileSelection
            }
        }
        .preferredColorScheme(.light)
    }

    private var profileSelection: some View {
        ZStack {
            blue.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 32)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 62))
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)

                    Text("WonderTalk English")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Who's learning today?\n今天谁来学习？")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    VStack(spacing: 14) {
                        profileButton(
                            id: "adult",
                            icon: "person.crop.circle.fill",
                            title: "我的英语空间",
                            subtitle: "Adult · 日常对话与专业英语"
                        )
                        profileButton(
                            id: "daughter",
                            icon: "face.smiling.fill",
                            title: "女儿的英语空间",
                            subtitle: "Kids · 趣味英语学习"
                        )
                    }
                    .padding(.top, 16)

                    Text("两个档案的课程、录音与学习等级独立保存于此设备。")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Spacer(minLength: 32)
                }
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }
        }
    }

    private func profileButton(id: String, icon: String, title: String, subtitle: String) -> some View {
        Button {
            activeProfile = id
            hasEntered = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(blue)
                    .frame(width: 50)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .foregroundStyle(blue)
            }
            .padding(20)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
