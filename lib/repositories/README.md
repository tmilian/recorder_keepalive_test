# Repositories Documentation

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                          UI Layer                            │
│                      (TestScreen)                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    LessonController                          │
│  (UI State Management + Workflow Orchestration)              │
│  • Observable variables (GetX)                               │
│  • Delegates all logic to MasterRepository                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│               🎯 MASTER REPOSITORY                           │
│            (Central Orchestrator)                            │
│  • Initializes all sub-repositories                          │
│  • Orchestrates interactions                                 │
│  • Manages conflicts (audio/video/recording)                 │
│  • Single entry point for controller                         │
└───┬─────────────┬─────────────┬─────────────┬───────────────┘
    │             │             │             │
    ▼             ▼             ▼             ▼
┌───────┐   ┌───────┐   ┌───────┐   ┌───────────────┐
│ Audio │   │ Audio │   │ Audio │   │ Video         │
│Session│   │Record │   │Playback   │ Playback      │
│Repo   │   │Repo   │   │Repo   │   │ Repo          │
└───────┘   └───────┘   └───────┘   └───────────────┘
    │             │             │             │
    │             │             │             │
    ▼             ▼             ▼             ▼
┌────────┐  ┌────────┐  ┌────────┐  ┌────────────┐
│ Audio  │  │Recorder│  │ Audio  │  │   Video    │
│Session │  │ Stream │  │ Player │  │ Controller │
│(iOS/   │  │Keep-   │  │        │  │            │
│Android)│  │Alive   │  │        │  │            │
└────────┘  └────────┘  └────────┘  └────────────┘
```

## Initialization Flow

```
main.dart
    │
    ├─► Request microphone permissions
    │
    ├─► Create MasterRepository
    │
    ├─► MasterRepository.initialize()
    │       │
    │       ├─► 1. AudioSessionRepository.initialize()  ⚡ FIRST
    │       │       └─► Configure iOS/Android audio session
    │       │
    │       ├─► 2. Parallel initialization:
    │       │   ├─► AudioRecordingRepository.initialize()
    │       │   │   └─► Start stream + pause (keep-alive)
    │       │   │
    │       │   ├─► AudioPlaybackRepository.initialize()
    │       │   │   └─► Create AudioPlayer instance
    │       │   │
    │       │   └─► VideoPlaybackRepository.initialize()
    │       │       └─► Ready to create controller
    │       │
    │       └─► ✅ All initialized in ~XXXms
    │
    ├─► Get.put(masterRepo)  // Register in GetX
    │
    └─► runApp()
            │
            └─► TestScreen
                    │
                    └─► LessonController.onInit()
                            │
                            └─► Get.find<MasterRepository>()
                                    │
                                    └─► ✅ Ready to use
```

## Orchestration Examples

### Example 1: Playing Video
```dart
// User calls:
controller.playVideo(0);

// Flow:
LessonController.playVideo()
    ↓
masterRepo.playVideo(url)
    ↓
├─► audioPlaybackRepo.pause()     // Stop audio first
└─► videoPlaybackRepo.playVideo()  // Then play video
```

### Example 2: Starting Recording
```dart
// User calls:
controller.startRecording();

// Flow:
LessonController.startRecording()
    ↓
masterRepo.startRecording()
    ↓
├─► audioPlaybackRepo.pause()     // Pause audio
├─► videoPlaybackRepo.pause()     // Pause video
└─► audioRecordingRepo.startCapture()  // Start recording
        ↓
        ├─► audioRecorder.resume()  ⚡ <5ms (keep-alive)
        └─► isCapturing = true      // Start capturing chunks
```

### Example 3: Full Test Cycle
```dart
// User calls:
controller.runFullTestCycle();

// Orchestration:
Video → Audio → Record → Audio → Record → Video → ...
  ↓       ↓       ↓       ↓       ↓       ↓
Pause  Pause   Pause   Pause   Pause   Pause
audio   video   both    both    both    audio
first   first   first   first   first   first
```

## Repository Details

### 1. AudioSessionRepository
**File**: `audio_session_repository.dart`

**Responsibilities**:
- Configure iOS/Android audio session (playAndRecord mode)
- Handle interruptions (phone calls, Siri)
- Handle device events (headphone disconnect)

**Key Methods**:
```dart
await initialize()  // Configure session
await dispose()     // Cleanup
```

**iOS Configuration**:
- Category: `playAndRecord` (simultaneous recording + playback)
- Options: `allowBluetooth | defaultToSpeaker | mixWithOthers`
- Background mode: `audio` (in Info.plist)

---

### 2. AudioRecordingRepository
**File**: `audio_recording_repository.dart`

**Responsibilities**:
- Manage audio recording with keep-alive pattern
- PCM16 stream → WAV file conversion
- List recorded files

**Key Methods**:
```dart
await initialize()              // Start stream in keep-alive mode
int startCapture()              // Resume + start capturing (returns resume time)
String? stopCapture()           // Pause + save to file (returns file path)
List<String> get recordedFiles  // List of recorded files
```

**Keep-Alive Pattern**:
1. Stream started at initialization
2. Immediately paused (keep-alive state)
3. Resume = instant (<5ms)
4. Capture chunks only when `_isCapturing = true`
5. Pause when done (back to keep-alive)

**Technical Details**:
- Format: PCM16, 44.1kHz, mono
- Stream always active (battery impact)
- WAV header created manually
- Files saved in temp directory

---

### 3. AudioPlaybackRepository
**File**: `audio_playback_repository.dart`

**Responsibilities**:
- Play audio from URLs or local files
- Single reusable `AudioPlayer` instance

**Key Methods**:
```dart
await initialize()        // Create AudioPlayer
await playUrl(String)     // Play from URL
await playFile(String)    // Play local file
await stop()              // Stop playback
await pause()             // Pause
await resume()            // Resume
```

**Optimization**:
- Single `AudioPlayer` instance reused for all playback
- No recreation between plays

---

### 4. VideoPlaybackRepository
**File**: `video_playback_repository.dart`

**Responsibilities**:
- Play videos from URLs
- Optimize controller reuse

**Key Methods**:
```dart
await initialize()           // Mark as initialized
await playVideo(String)      // Play video (reuse controller if same URL)
await pause()                // Pause video
await resume()               // Resume video
await stop()                 // Stop and seek to start
VideoPlayerController? get controller  // Access controller
```

**Optimization** (NEW):
- Reuses `VideoPlayerController` for the same URL
- Only recreates controller when URL changes
- Significant performance improvement

---

### 5. MasterRepository (Orchestrator)
**File**: `master_repository.dart`

**Responsibilities**:
- Initialize all repositories in correct order
- Orchestrate interactions between repositories
- Provide high-level methods to controller
- Manage conflicts automatically

**Key Methods**:

**Initialization**:
```dart
await initialize()  // Init all repos in order
```

**Audio Playback**:
```dart
await playAudioUrl(String)   // Play audio from URL
await playAudioFile(String)  // Play local audio file
await stopAudio()            // Stop audio
```

**Video Playback**:
```dart
await playVideo(String)  // Play video (auto-pauses audio)
await pauseVideo()       // Pause video
await stopVideo()        // Stop video
```

**Recording**:
```dart
int startRecording()          // Start recording (auto-pauses all)
String? stopRecording()       // Stop and save
String? recordForDuration()   // Complete workflow
```

**Advanced**:
```dart
await stopAll()  // Stop all playback
```

**Orchestration Logic**:
- `playVideo()` → pauses audio first
- `startRecording()` → pauses audio + video first
- Ensures no conflicts between media sources

## Testing the Architecture

### Unit Testing (Individual Repositories)
```dart
// Test AudioRecordingRepository alone
final repo = AudioRecordingRepository();
await repo.initialize();
final resumeTime = await repo.startCapture();
expect(resumeTime, lessThan(10)); // Should be <10ms
await Future.delayed(Duration(seconds: 1));
final filePath = await repo.stopCapture();
expect(filePath, isNotNull);
```

### Integration Testing (MasterRepository)
```dart
// Test orchestration
final master = MasterRepository();
await master.initialize();

// Test conflict resolution
await master.playAudioUrl(url);
await master.playVideo(videoUrl);  // Should auto-pause audio
// Verify audio is paused
```

## Performance Metrics

**Initialization** (all repositories):
- Target: <500ms
- Typical: ~200-300ms

**Recording Resume** (keep-alive):
- Target: <10ms
- Typical: <5ms

**Audio Playback Start**:
- Target: <1000ms (network dependent)
- Reuse of player: instant

**Video Playback Start**:
- Target: <2000ms (network dependent)
- Controller reuse: significantly faster

## Error Handling

All repositories use try-catch and print logs:
- ✓ : Success
- ⚠️ : Warning (non-fatal)
- ❌ : Error (with exception message)

Example:
```
✓ AudioSessionRepository initialized
✓ AudioRecordingRepository initialized - KEEP-ALIVE MODE
  📡 Stream active, ready for instant resume
  ⏸️ Paused by default (no capture)
✓ AudioPlaybackRepository initialized
✓ VideoPlaybackRepository initialized
✅ MasterRepository initialized in 287ms
```

## Future Enhancements

1. **Add logging abstraction** : Replace `print()` with proper logging service
2. **Add error callbacks** : Allow controller to subscribe to repo errors
3. **Add state streams** : Expose repository state as streams for UI updates
4. **Add metrics tracking** : Measure performance automatically
5. **Add recording metadata** : Duration, file size, sample rate in recording list
