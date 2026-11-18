# WhisperX 本地批量逐句对齐

WonderTalk 支持从本地 App Bundle 的 `WonderTalkEnglish/Lessons/private_course_alignment.json` 加载预先计算的句子起止时间。

## 工作流程

1. 在 Mac 下载提供的「WonderTalk_WhisperX_本地部署与18课音频字幕.zip」，解压。
2. 安装私有课程资料：`python3 install_assets.py ~/Desktop/WonderTalkEnglish`。
3. 安装环境：`brew install ffmpeg python@3.11`，然后 `bash setup_mac.sh`。
4. 先处理 e02：`./run_align.sh ~/Desktop/WonderTalkEnglish --id e02`。
5. 试听检查后批量处理：`./run_align.sh ~/Desktop/WonderTalkEnglish`。
6. 重新用 Xcode 编译安装 App，并确认 `private_course_alignment.json`、`private_course_media.json` 和 MP3 已被打包为 App 资源。

对齐程序使用 WhisperX 的 CPU/int8 路径，先识别音频、做 wav2vec2 声学对齐，再与已有字幕做单调序列匹配。输出的每一行包含 `english`、`start`、`end` 和 `confidence`；未可靠匹配的句子保留空时间戳。

App 会验证课程 ID、来源 URL、每行英文文本完全一致后才应用时间戳，避免错配。已存在的个人手动时间戳优先保留。音频、字幕、对齐结果不应提交到公开 GitHub。

**运行状态**：已静态检查脚本与对齐匹配单元测试；尚未在用户的 macOS 上安装 WhisperX 模型或执行真实音频推理。首次运行需要联网下载依赖和模型；Apple Silicon 也默认使用 CPU，不保证 M 系列 GPU 加速。

WhisperX 上游文档：https://github.com/m-bain/whisperX
