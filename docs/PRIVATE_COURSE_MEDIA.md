# 私有课程资源：重新安装 App 后自动可用

公开 GitHub 仓库只保留课程索引与读取逻辑，不上传第三方的完整字幕或 MP3。

## 本地工程安装
1. 先 `git switch main && git pull --ff-only origin main`。
2. 下载单独提供的「WonderTalk_工程私有课程资源包.zip」，在 Mac 解压。
3. 将解压后的 `WonderTalkEnglish/Lessons/private_course_media.json` 与 `WonderTalkEnglish/Audio/wt_*_full.mp3` 放入仓库的同名路径（压缩包内带有一键安装脚本）。
4. Xcode 打开工程，确认新文件属于 WonderTalkEnglish App target / Copy Bundle Resources，然后构建运行。
5. App 启动时，会用课程 ID **和来源 URL** 匹配本地资源；找到的 MP3 和逐句字幕直接出现在课程里，不需要再手动导入 JSON。
6. 如已有学习数据，旧的个人进度与手动对齐优先保留；e17 课程将被移除且不会从旧缓存恢复。

## 备选：iPhone「文件」App 导入
提供的分卷 JSON（每份小于 40MB）也可在 App 中依次通过「课程管理 → 批量导入本地课程资料包」导入。该方式无需将私有资源拷入 Xcode 项目。

## 数据核对
- e17《Best and Worst Part of Your Job》已从公开课程目录移除，并在读取本地缓存时过滤。
- e02 课程仍是《Making Breakfast》；收到的 e02(2).txt 实际是旧金山对话，不得误配。
- 新增 e05《Four Conversations》的逐句字幕与对应 MP3。
- e06《Ordering in a Café》字幕更新，音频按来源课程名匹配。
- 其余 British Council 音频以文件名和课程标题关联，需在 App 内试听与自动逐句对齐后确认。
- 重复下载的 MP3 按 SHA256 去重。

**重要**：当前没有在 Xcode/iOS 真机上编译或实际播放验证。第三方资源的使用和分发必须遵守原始网站许可。
