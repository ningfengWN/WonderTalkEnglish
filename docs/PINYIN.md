# 拼音训练模块（V4）

WonderTalk English 底部新增「拼音」Tab，保留原有「英语」Tab。

## 内容
- **认字形**：b / p / d / q 方向辨认；zh / ch / sh / z / c / s 声母辨认。
- **听音跟读**：示范词语 → 孩子录音 → 回放 → 系统中文词语识别（若可用）→ 家长确认。
- 练习词：包子、苹果、大象、气球、蜘蛛、吃饭、狮子、早上、草莓、三个。
- 记录累计认对次数与跟读次数，使用本机 AppStorage。

## 发音测评边界
Apple Speech 的 zh-CN 识别是**词语识别**，并非声母级的标准化发音测评。显示“识别到目标词语”只能作为提示，不保证声母发音正确；“未识别到”也不代表孩子读错。请结合录音和家长听辨，不展示虚构的准确率分数。

b/p/d/q 首先是**字形方向**容易混淆，不应仅用语音检测评估字形辨认。

## Xcode 测试
1. 拉取 `feature/wondertalk-v4` 分支。
2. 确认 `PinyinPracticeView.swift` 出现在 App target 的 Compile Sources 中（同步文件夹项目一般自动包含）。
3. 确认 `NSMicrophoneUsageDescription` 和 `NSSpeechRecognitionUsageDescription` 已设置。
4. 在 iPhone 模拟器测试页面、字形选择、示范朗读、录音、回放；中文语音识别和音质建议最终在真机测试。
5. 如有编译错误，请提供第一条 Xcode 错误和对应文件行号。

该模块未接入付费 AI API。录音保存在 App 临时目录用于回放；语音识别**仅在支持设备端中文识别时启用**（requiresOnDeviceRecognition = true），不支持时提示家长人工判断，不退回云端识别。
