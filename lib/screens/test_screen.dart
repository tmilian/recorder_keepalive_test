import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../controllers/lesson_controller.dart';

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LessonController());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Recorder Keep-Alive Test'),
      ),
      body: Obx(() => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Card
                Card(
                  color: controller.isInitialized.value
                      ? Colors.green[50]
                      : Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          controller.statusMessage.value,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (controller.initTime.value > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Init time: ${controller.initTime.value}ms',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[700],
                                ),
                          ),
                        ],
                        if (controller.lastActionTime.value > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Last action: ${controller.lastActionTime.value}ms',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Current Step
                if (controller.currentStep.value.isNotEmpty)
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Current: ${controller.currentStep.value}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                Center(
                  child: controller.videoController?.value.isInitialized == true
                      ? AspectRatio(
                          aspectRatio:
                              controller.videoController!.value.aspectRatio,
                          child: VideoPlayer(controller.videoController!),
                        )
                      : Container(),
                ),

                // Run Full Test Button
                ElevatedButton.icon(
                  onPressed: controller.isInitialized.value
                      ? () => controller.runFullTestCycle()
                      : null,
                  icon: const Icon(Icons.play_circle_filled),
                  label: const Text('RUN FULL TEST CYCLE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Manual Controls
                Text(
                  'Manual Controls',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                // Video Controls
                Text(
                  'Videos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    controller.videoUrls.length,
                    (index) => ElevatedButton(
                      onPressed: controller.isInitialized.value
                          ? () => controller.playVideo(index)
                          : null,
                      child: Text('Video ${index + 1}'),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Audio Controls
                Text(
                  'Audios',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    5,
                    (index) => ElevatedButton(
                      onPressed: controller.isInitialized.value
                          ? () => controller.playAudio(index)
                          : null,
                      child: Text('Audio ${index + 1}'),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Recording Control
                Text(
                  'Recording',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: controller.isInitialized.value
                      ? () => controller.startRecording()
                      : null,
                  icon: const Icon(Icons.mic),
                  label: const Text('START RECORDING (3s)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Recorded Files
                Text(
                  'Recorded Files (${controller.recordedFiles.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),

                if (controller.recordedFiles.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No recordings yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  ...List.generate(
                    controller.recordedFiles.length,
                    (index) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text('Recording ${index + 1}'),
                        subtitle: Text(
                          controller.recordedFiles[index].split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: () => controller.playRecordedFile(index),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Info Card
                Card(
                  color: Colors.amber[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber[900]),
                            const SizedBox(width: 8),
                            Text(
                              'Test Info',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.amber[900],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Recorder is in keep-alive mode (pause/resume)\n'
                          '• Watch for the recording indicator on your device\n'
                          '• Check battery usage during the test\n'
                          '• Listen for audio quality issues\n'
                          '• Note any system interruptions',
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )),
    );
  }
}
