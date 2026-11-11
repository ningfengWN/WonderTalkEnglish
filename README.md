# WonderTalk English

Native SwiftUI English learning app for iPhone and iPad.

## V4 development branch

V4 introduces a four-step learning flow (blind listening → transcript → shadowing → review), local import of MP3/M4A recordings, a native AVAudioPlayer, manual sentence time alignment, voice recording and a JSON lesson catalog.

The existing `Audio/` files are **synthetic demonstration recordings**, not VOA or other human-narrated audio. Import properly licensed human narration separately using the app's file importer.

To test: open your existing Xcode project, check that `WonderTalkEnglish/Lessons/*.json` is included in Copy Bundle Resources, and build on an iPhone Simulator. The code has not been compiled in Xcode by this assistant.

No AI API is used in this version. Never commit API keys or private user recordings.
