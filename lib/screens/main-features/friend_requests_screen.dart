import 'package:flutter/material.dart';
import 'package:pic_collector/models/friend_request.dart';
import 'package:pic_collector/services/friend_service.dart';
import 'package:pic_collector/utils/user_notice.dart';

/// Real friend-request inbox, opened from the drawer.
///
/// Shows incoming pending requests with Accept/Decline and the user's
/// outgoing pending requests.
class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});

  Future<void> _accept(BuildContext context, FriendRequest request) async {
    try {
      await FriendService.instance.acceptRequest(request);
      if (!context.mounted) return;
      showSnackBar(context, 'You are now friends with ${request.fromUsername}');
    } catch (_) {
      if (!context.mounted) return;
      showSnackBar(context, 'Could not accept the request');
    }
  }

  Future<void> _decline(BuildContext context, FriendRequest request) async {
    try {
      await FriendService.instance.declineRequest(request);
      if (!context.mounted) return;
      showSnackBar(context, 'Request declined');
    } catch (_) {
      if (!context.mounted) return;
      showSnackBar(context, 'Could not decline the request');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Friend Requests',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Incoming',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<FriendRequest>>(
            stream: FriendService.instance.watchIncomingRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()));
              }
              final requests = snapshot.data ?? const [];
              if (requests.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No incoming requests.',
                      style: TextStyle(color: Colors.black54)),
                );
              }
              return Column(
                children: requests.map((request) {
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          request.fromUsername.isNotEmpty
                              ? request.fromUsername[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        request.fromName.isNotEmpty
                            ? request.fromName
                            : request.fromUsername,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('@${request.fromUsername}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: 'Accept',
                            onPressed: () => _accept(context, request),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.cancel, color: Colors.red),
                            tooltip: 'Decline',
                            onPressed: () => _decline(context, request),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Sent',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<FriendRequest>>(
            stream: FriendService.instance.watchOutgoingRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator()));
              }
              final requests = snapshot.data ?? const [];
              if (requests.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No sent requests.',
                      style: TextStyle(color: Colors.black54)),
                );
              }
              return Column(
                children: requests.map((request) {
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.hourglass_empty,
                            color: Colors.white),
                      ),
                      title: Text(request.toUsernameLower,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Pending'),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}