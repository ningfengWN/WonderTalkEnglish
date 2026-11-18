# 私有课程资源：重新安装 App 后自动可用

公开 GitHub 仓库只保留课程索引与读取逻辑，不上传第三方的完整字幕或 MP3。

## 本地工程安装
1. 先 `git switch main && git pull --ff-only origin main`。
2. 下载单独提供的「WonderTalk_工程私有课程资源包.zip」，在 Mac 解压。
3. 将解压后的 `WonderTalkEnglish/Lessons/private_course_media.json` 与 `WonderTalkEnglish/Audio/wt_*_full.mp3` 放入仓库的同名路径（压缩包内带有一键安装脚本）。
4. Xcode 打开工程，确认新文件属于 WonderTalkEnglish App target / Copy Bundle Resources，然后构建运行。
5. App 启动时，会用课程 ID **和来源 URL** 匹配本地资源；找到的 MP3 和逐句字幕直接出现在课程里，不需要再手动导入 JSON。
6. 如已有学习数据，旧的个人进度与手动对齐优先保留；e17、e20、rates、renaissance 课程将被移除且不会从旧缓存恢复。

## 备选：iPhone「文件」App 导入
提供的分卷 JSON（每份小于 40MB）也可在 App 中依次通过「课程管理 → 批量导入本地课程资料包」导入。该方式无需将私有资源拷入 Xcode 项目。

## 数据核对
- e17、e20 及最初两篇演示文章已从公开课程目录移除，并在读取本地缓存时过滤。
- e02 课程《Making Breakfast》现使用新上传的 `e02-重新(1).txt`（54 句）及 1575 号音频（约 2:46），替换先前错误的旧金山对话。
- 新增 e05《Four Conversations》的逐句字幕与对应 MP3。
- e06《Ordering in a Café》字幕更新，音频按来源课程名匹配。
- 其余 British Council 音频以文件名和课程标题关联，需在 App 内试听与自动逐句对齐后确认。
- 重复下载的 MP3 按 SHA256 去重。

**重要**：当前没有在 Xcode/iOS 真机上编译或实际播放验证。第三方资源的使用和分发必须遵守原始网站许可。

## V4 双分类课程库

- 日常英语 25 篇：课程详情 + 原有泛听、阅读、跟读录音训练。
- 知识英语 13 篇：课程详情 + 直接打开来源音频或视频网页，不要求录音。
- 课程行显示标题、来源和时长（来自本地私有资源清单；未知时显示待补充）。
- V4 本地资源包：18 份 MP3，17 份字幕，17 门两者齐备；e10 只有音频。
