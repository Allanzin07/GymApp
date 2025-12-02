import 'package:flutter/material.dart';
import 'connected_posts_feed.dart';

class ConnectedPostsFeedHolder extends StatefulWidget {
  final String? currentUserId;

  const ConnectedPostsFeedHolder({super.key, this.currentUserId});

  @override
  State<ConnectedPostsFeedHolder> createState() =>
      _ConnectedPostsFeedHolderState();
}

class _ConnectedPostsFeedHolderState extends State<ConnectedPostsFeedHolder>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 🔥 mantém vivo SEM REBUILD

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ConnectedPostsFeed(
      currentUserId: widget.currentUserId,
    );
  }
}
