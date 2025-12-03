import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class FavoriteButton extends StatefulWidget {
  final String drawingId;
  final String drawingOwnerId; // ⭐ added
  final bool initialIsFav;
  final VoidCallback? onChanged;

  const FavoriteButton({
    super.key,
    required this.drawingId,
    required this.drawingOwnerId,
    required this.initialIsFav,
    this.onChanged,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = widget.initialIsFav;
  }

  Future<void> _toggleFav() async {
    final uid = supabase.auth.currentUser!.id;

    if (_isFav) {
      await supabase
          .from("favorites")
          .delete()
          .eq("user_id", uid)
          .eq("drawing_id", widget.drawingId);
    } else {
      await supabase.from("favorites").insert({
        "user_id": uid,
        "drawing_id": widget.drawingId,
      });

      // ⭐ Notification for LIKE
      if (uid != widget.drawingOwnerId) {
        await supabase.from("notifications").insert({
          "receiver_id": widget.drawingOwnerId,
          "actor_id": uid,
          "drawing_id": widget.drawingId,
          "type": "like",
        });
      }
    }

    setState(() => _isFav = !_isFav);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isFav ? Icons.favorite : Icons.favorite_border,
        color: _isFav ? Colors.redAccent : Colors.white70,
      ),
      onPressed: _toggleFav,
    );
  }
}
