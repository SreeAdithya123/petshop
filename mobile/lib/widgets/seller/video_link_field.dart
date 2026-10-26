import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/video_room.dart';
import 'seller_common.dart';

const kVideoLinkError = 'Video links must start with https://';

/// Turns what the shop owner typed into the link to store: an empty field
/// means "use PETSTA's free video room" for [roomId]; anything else has to be
/// an https link.
({String? link, String? error}) resolveVideoLink(String raw, String roomId) {
  final text = raw.trim();
  if (text.isEmpty) return (link: jitsiRoomUrl(roomId), error: null);
  if (!isHttpsUrl(text)) return (link: null, error: kVideoLinkError);
  return (link: text, error: null);
}

/// Editable video-call link. Start it pre-filled with [jitsiRoomUrl] so
/// confirming a booking or demo never needs a pasted link; the owner can still
/// replace it with their own Meet/Zoom link, reset it, or open it to try it.
class VideoLinkField extends StatelessWidget {
  final TextEditingController controller;

  /// Booking or demo id the free room is named after.
  final String roomId;
  final bool enabled;
  final String label;
  final String? errorText;
  final VoidCallback? onChanged;

  const VideoLinkField({
    super.key,
    required this.controller,
    required this.roomId,
    this.enabled = true,
    this.label = 'Video call link',
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final room = jitsiRoomUrl(roomId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => onChanged?.call(),
          decoration: InputDecoration(
            labelText: label,
            hintText: room,
            helperText: 'A free PETSTA video room is ready. Leave it as is, or paste your own Meet/Zoom link. '
                'The customer sees it on their Services & Health pages.',
            helperMaxLines: 4,
            errorText: errorText,
            errorMaxLines: 2,
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final text = controller.text.trim();
            final isRoom = text == room;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (!isRoom)
                        TextButton.icon(
                          onPressed: enabled
                              ? () {
                                  controller.text = room;
                                  onChanged?.call();
                                }
                              : null,
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Use PETSTA room'),
                        ),
                      Tooltip(
                        message: 'Open video call link',
                        child: OutlinedButton.icon(
                          onPressed: (enabled && isSafeWebLink(text)) ? () => openExternal(context, Uri.parse(text)) : null,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open'),
                        ),
                      ),
                    ],
                  ),
                  if (text.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Left empty, the PETSTA room is used.',
                        style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
