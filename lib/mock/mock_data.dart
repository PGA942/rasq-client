import 'package:rasq_models/rasq_models.dart';

/// Mock data used by M0 screens and the component catalog.
/// Names follow the wireframes (ダグラス / 動物Poll / 事故アピール / タロ・ヤマダ).
abstract final class MockData {
  static const accountBluesky = AccountId(kind: SnsKind.bluesky, instance: 'bluesky.social', handle: 'yamada_tar_gz');
  static const accountMisskey = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');
  static const accounts = [accountMisskey, accountBluesky];

  static final me = UserSummary(
    id: 'did:plc:me',
    account: accountBluesky,
    displayName: 'タロ・ヤマダ',
    avatarUrl: Uri.parse('https://picsum.photos/seed/yamada/200'),
    bio: '航空宇宙とか工学とか\nISD 天文学科',
  );

  static final douglas = UserSummary(
    id: 'did:plc:douglas',
    account: const AccountId(kind: SnsKind.bluesky, instance: 'BlueSky', handle: 'username'),
    displayName: 'ダグラス',
    avatarUrl: Uri.parse('https://picsum.photos/seed/douglas/200'),
    presence: UserPresence.inVc,
  );

  static final animalPoll = UserSummary(
    id: 'misskey:animalpoll',
    account: const AccountId(kind: SnsKind.misskey, instance: 'いきものミスキー！', handle: 'username'),
    displayName: '動物Poll',
  );

  static final jikoAppeal = UserSummary(
    id: 'misskey:jiko',
    account: const AccountId(kind: SnsKind.misskey, instance: 'BlueWind', handle: 'username'),
    displayName: '事故アピール',
    avatarUrl: Uri.parse('https://picsum.photos/seed/jiko/200'),
    bio: 'Begin Freedom at the World\'s End\n相方:@username●misskey.io',
  );

  static final tivard = UserSummary(
    id: 'tivard',
    account: const AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'tivard'),
    displayName: 'TiVard',
    presence: UserPresence.live,
  );

  static List<Post> timeline(AccountId viewer) {
    final now = DateTime.now();
    return [
      Post(
        id: 'p1',
        account: viewer,
        author: douglas,
        createdAt: now.subtract(const Duration(minutes: 3)),
        body: '4..\n3..\n2..\n1..\nLet\'s Take off!!!',
        counts: const {'reply': 2, 'repost': 12, 'like': 48},
        reactions: const {'👍': 30, '🎉': 18},
      ),
      Post(
        id: 'p2',
        account: viewer,
        author: animalPoll,
        createdAt: now.subtract(const Duration(hours: 2)),
        body: '犬派？猫派？',
        poll: const Poll(options: [PollOption(text: '猫派', votes: 3), PollOption(text: '犬派', votes: 2), PollOption(text: 'その他', votes: 2)]),
        counts: const {'reply': 0, 'repost': 1, 'like': 5},
      ),
      Post(
        id: 'p3',
        account: viewer,
        author: jikoAppeal,
        createdAt: now.subtract(const Duration(days: 1)),
        body: '自虐的に誕生日を祝った人には永遠にプレゼントが贈られないという都市伝説があってだな…',
        media: [
          MediaItem(id: 'm1', type: MediaType.image, url: Uri.parse('https://picsum.photos/seed/rocket/800/450'), sensitive: true, width: 16, height: 9),
        ],
        counts: const {'reply': 1, 'repost': 0, 'like': 9},
      ),
    ];
  }

  static List<MediaItem> media(int n, {bool sensitiveFirst = false}) => [
        for (var i = 0; i < n; i++)
          MediaItem(
            id: 'mock-$i',
            type: i == 1 ? MediaType.video : (i == 3 ? MediaType.file : MediaType.image),
            url: Uri.parse('https://picsum.photos/seed/m$i/600/400'),
            thumbnailUrl: Uri.parse('https://picsum.photos/seed/m$i/600/400'),
            sensitive: sensitiveFirst && i == 0,
            duration: i == 1 ? const Duration(minutes: 12, seconds: 31) : null,
            fileName: i == 3 ? 'launch_log.csv' : null,
            alt: i == 2 ? 'ロケットの写真' : null,
          ),
      ];
}
