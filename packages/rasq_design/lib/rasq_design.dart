/// RASQ design system: tokens, theme and host-owned L2 standard components.
///
/// Everything here is **stateless and props-driven** (原典: UI_Elements
/// 「状態管理方針: 状態はDSLの外、コンポーネントはPropsとして受け取るだけ」).
/// The same widgets are used by app screens and, later, by the RRL renderer
/// as the implementation of L2 Standard Components (D-002).
library;

export 'src/tokens/colors.dart';
export 'src/tokens/spacing.dart';
export 'src/tokens/sizes.dart';
export 'src/tokens/typography.dart';
export 'src/theme/rasq_theme.dart';
export 'src/theme/rasq_tokens_extension.dart';

export 'src/components/avatar.dart';
export 'src/components/badge.dart';
export 'src/components/rich_text.dart';
export 'src/components/media_grid.dart';
export 'src/components/action_button.dart';
export 'src/components/timestamp.dart';
export 'src/components/buttons.dart';
export 'src/components/list_tiles.dart';
export 'src/components/input.dart';
export 'src/components/sns_pill.dart';
export 'src/components/user_row.dart';
export 'src/components/user_tile_large.dart';
export 'src/components/sort.dart';
export 'src/components/brand.dart';

// L2 composite — 投稿まわり (PostTile / ActionBar / PollWidget / CollapsedPost …).
export 'src/components/post_tile.dart';
export 'src/components/action_bar.dart';
export 'src/components/poll_widget.dart';
export 'src/components/collapsed_post.dart';
export 'src/components/content_warning.dart';
export 'src/components/link_banner.dart';

export 'src/layout/tabs.dart';
export 'src/layout/collapsible_header.dart';

export 'src/feedback/error_view.dart';
export 'src/feedback/empty_view.dart';
export 'src/feedback/loading.dart';
