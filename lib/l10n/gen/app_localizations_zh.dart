// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get adsShowLess => '减少显示频率';

  @override
  String get adsShowLessDone => '已减少此广告的显示频率';

  @override
  String get adsLabel => '广告';

  @override
  String adsLabelWithHost(String host) {
    return '广告 · $host';
  }

  @override
  String get adsMenu => '广告菜单';

  @override
  String get adsOpen => '打开广告';

  @override
  String get appNavPostTitle => '帖子';

  @override
  String get appNavReactionsTitle => '回应';

  @override
  String get appNavFollowersTitle => '关注者';

  @override
  String get appNavFollowingTitle => '关注中';

  @override
  String get appNavShortcutSearch => '搜索';

  @override
  String get appNavShortcutNewPost => '发帖';

  @override
  String get appNavShortcutNewMessage => '写消息';

  @override
  String get appNavShortcutAskRai => '和 RAi 一起找';

  @override
  String get appNavShortcutGuardianPending => '在监护人完成设置之前无法使用';

  @override
  String get appNavShortcutLoginHint => '登录 SNS 账号后即可使用';

  @override
  String get backendOauthNoToken => '无法获取访问令牌';

  @override
  String backendOauthServerRequired(String service) {
    return '登录 $service 需要 RASQ 服务器。请在设置 →“RASQ 服务器”中设置连接目标。';
  }

  @override
  String get backendOauthNoUrl => '无法获取认证 URL';

  @override
  String get backendOauthHint => '在浏览器中授权后，请返回应用并点按“确认认证”。';

  @override
  String backendResponseTooLarge(int maxBytes) {
    return '响应过大（超过 $maxBytes 字节）';
  }

  @override
  String get backendSecurityPasswordlessRemoved =>
      '仅凭邮件验证码登录的方式已停止。请使用用户名（或邮箱）和密码登录';

  @override
  String get backendSecuritySecondFactor => '请输入发送到邮箱的验证码';

  @override
  String get backendSecurityTooMany => '尝试次数过多。请稍后再试';

  @override
  String get backendSecurityNoMail => '此服务器未配置邮件发送';

  @override
  String get backendSecurityEmailUsed => '此邮箱地址已被其他账号使用';

  @override
  String get backendSecurityBadCredentials => '用户名（邮箱）或密码错误';

  @override
  String get backendSecurityBadCode => '验证码错误或已过期';

  @override
  String get backendSecurityWeakPassword =>
      '此密码过于简单（不能使用常见密码、重复字符，或与用户名、邮箱相同的密码）';

  @override
  String get backendSecurityShortPassword => '密码至少需要 8 个字符';

  @override
  String get backendSecurityBadEmail => '邮箱地址格式不正确';

  @override
  String get backendSecurityWrongPassword => '当前密码错误';

  @override
  String get backendSecurityNoPassword => '此账号没有设置密码。请使用发送到当前邮箱的验证码进行确认';

  @override
  String get backendSecurityConfirmRequired => '此操作需要当前密码或发送到当前邮箱的验证码';

  @override
  String get backendRoomClosed => '无法进入房间（房间已关闭或不存在）';

  @override
  String get backendRoomForbidden => '无法进入房间（此账号无法参加）';

  @override
  String backendRoomConnectFailed(String error) {
    return '无法连接到房间：$error';
  }

  @override
  String get backendPaidFeaturesDisabled => '公开测试期间无法使用付费插件';

  @override
  String get backendAgeTeen => '13–15 岁';

  @override
  String get backendAgeUpperTeen => '16–17 岁';

  @override
  String get backendAgeAdult => '18 岁及以上';

  @override
  String get backendNoToken => 'ORGATE 未返回令牌';

  @override
  String get backendTileAuto => '自动';

  @override
  String get backendTileShow => '显示';

  @override
  String get backendTileHide => '隐藏';

  @override
  String get backendVerifiedKeybase => '已通过 Keybase 证明验证';

  @override
  String get backendVerifiedProfile => '已通过个人资料验证';

  @override
  String get backendAudioFileName => '音频';

  @override
  String get backendServerNotConfigured => '尚未设置 RASQ 服务器的连接地址';

  @override
  String backendServerError(int status) {
    return '服务器错误（$status）';
  }

  @override
  String get backendCollectionList => '列表';

  @override
  String get backendCollectionClip => '便签';

  @override
  String get bookmarksRemoved => '已移除书签';

  @override
  String bookmarksRemoveFailed(String error) {
    return '无法移除：$error';
  }

  @override
  String get bookmarksTitle => '书签';

  @override
  String get bookmarksRetry => '重新加载';

  @override
  String get bookmarksEmptyTitle => '没有书签';

  @override
  String get bookmarksEmptyHint => '可通过帖子的 🔖、添加到便签或 ASTell 的书签来收集';

  @override
  String get bookmarksEmptyNoSnsHint => '此服务没有书签功能。长按帖子的 🔖 可将其收集到 RASQ 便签';

  @override
  String get bookmarksClips => '便签';

  @override
  String bookmarksClipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String get bookmarksClipHost => 'RASQ（跨 SNS）';

  @override
  String get bookmarksClipPrivate => '非公开便签';

  @override
  String get bookmarksSeparator => ' · ';

  @override
  String get bookmarksFavorites => '收藏';

  @override
  String get bookmarksSwipeRemove => '移除';

  @override
  String get bookmarksRemove => '移除书签';

  @override
  String get catalogTitle => '组件目录';

  @override
  String get catalogSectionBrand => 'Brand（特殊组件）';

  @override
  String get catalogSectionPostTile => 'PostTile — 标准（操作栏 / 投票 / 媒体）';

  @override
  String get catalogSectionPostTileEmbedded =>
      'PostTile — 嵌入（引用 / 回应显示 / 计时通知）& 串摘要';

  @override
  String get catalogSectionCollapsed => 'CollapsedPost（折叠显示：已读 + 长文）';

  @override
  String get catalogSectionPoll => 'PollWidget（未投票 单选 / 多选、已投票、已过期）';

  @override
  String get catalogSectionActionBar => 'ActionBar（spread / leading = 编辑器工具栏）';

  @override
  String get catalogSectionRrl => 'RRL 渲染器（post-tile.rrl.json → L1/L2/L3）';

  @override
  String get catalogSheetTitle => '底部面板';

  @override
  String get catalogSheetConfirm => '确定';

  @override
  String get catalogSheetBody => '点按背景或取消将放弃更改。\n可在此之上弹出模态框。';

  @override
  String get catalogAlertTitle => '要屏蔽吗？';

  @override
  String get catalogAlertMessage => '点按背景无效（需要明确操作）';

  @override
  String get catalogAlertConfirm => '屏蔽';

  @override
  String get catalogAlertCancel => '取消';

  @override
  String get catalogDropdownAsc => '升序';

  @override
  String get catalogDropdownDesc => '降序';

  @override
  String get catalogDropdownDefault => '默认';

  @override
  String get catalogDropdownReport => '举报';

  @override
  String get catalogSheetModalTitle => '面板 → 模态框插入';

  @override
  String get catalogModalTitle => '模态框';

  @override
  String get catalogModalMessage => '面板将保持';

  @override
  String get catalogModalOpen => '显示模态框';

  @override
  String get childSafeLevelStrict => '严格';

  @override
  String get childSafeLevelStandard => '普通';

  @override
  String get childSafeLevelMild => '宽松';

  @override
  String get childSafeTopicModeAllow => '白名单';

  @override
  String get childSafeTopicModeDeny => '黑名单';

  @override
  String get childSafeInstallNone => '不可安装';

  @override
  String get childSafeInstallListed => '仅限所选';

  @override
  String get childSafeInstallAny => '自由';

  @override
  String get childSafeInstallExamples => '接近示例的';

  @override
  String get childSafeEmptyWhitelistError => '白名单为空。请至少添加一个话题，或改为黑名单';

  @override
  String get childSafeMethodJpki => '个人编号卡（JPKI）';

  @override
  String get childSafeMethodSelfDeclared => '自行申报';

  @override
  String get childSafeErrorCodeInvalid => '验证码错误或已过期';

  @override
  String get childSafeErrorHandleTaken => '该用户名已被使用';

  @override
  String get childSafeErrorAlreadyLinked => '该账号已被监护（或正在监护他人）';

  @override
  String get childSafeErrorCodeGone => '代码已过期或已被使用。请让监护人重新生成';

  @override
  String get childSafeErrorDevice => '无法在此设备上登录';

  @override
  String get childSafeErrorTooMany => '尝试次数过多。请稍后再试';

  @override
  String get childSafeNoServer => '尚未设置 RASQ 服务器的连接地址';

  @override
  String childSafeNoticeMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '（另有 $count 条）',
    );
    return '$_temp0';
  }

  @override
  String get childSafeNoticeRefreshed => '儿童安全：已重新获取监护人的设置';

  @override
  String get childSafeNoticeView => '查看';

  @override
  String get childSafeBlocked => '已被监护人禁用';

  @override
  String childSafeBlockedWith(String label) {
    return '已被监护人禁用（$label）';
  }

  @override
  String childSafeTimeRange(String start, String end) {
    return '$start～$end';
  }

  @override
  String get childSafeLockedUntilSetup => '在监护人完成设置之前无法使用';

  @override
  String childSafeWindowNoDm(String window) {
    return '监护时段（$window）无法使用私信';
  }

  @override
  String get childSafeBlockedAstell => '监护人已禁用 ASTell';

  @override
  String childSafeWindowNoAstell(String window) {
    return '监护时段（$window）无法使用 ASTell';
  }

  @override
  String get childSafeBlockedDm => '监护人已禁用私信';

  @override
  String childSafeWindowNoNotifications(String window) {
    return '监护时段（$window）无法查看通知';
  }

  @override
  String get childSafeBlockedRai => '监护人已禁用 RAi';

  @override
  String get childSafeBlockedStore => '监护人已禁用插件商店';

  @override
  String get childSafeBlockedSearch => '监护人已禁用搜索';

  @override
  String get childSafeBlockedAddAccount => '监护人已禁止添加 SNS 账号';

  @override
  String get childSafeBlockedCustomPlugins => '监护人已禁用自定义插件';

  @override
  String get childSafeBlockedPlugins => '监护人已禁用插件';

  @override
  String childSafeWindowNoPostDetail(String window) {
    return '监护时段（$window）无法打开帖子详情';
  }

  @override
  String get childSafePostHidden => '无法显示此帖子';

  @override
  String get childSafeListSeparator => '、';

  @override
  String childSafeBullet(String text) {
    return '• $text';
  }

  @override
  String childSafeTopicsEtc(String topics) {
    return '$topics 等';
  }

  @override
  String get childSafeComposeNoTopicsAllowed => '根据监护人的设置，目前无法发帖';

  @override
  String childSafeComposeTopicsOnly(String topics) {
    return '根据监护人的设置，只能发布指定话题（$topics）的帖子。请按话题书写';
  }

  @override
  String childSafeComposeTopicDenied(String topic) {
    return '根据监护人的设置，无法发布“$topic”话题的帖子。请修改内容';
  }

  @override
  String childSafeQuoted(String text) {
    return '“$text”';
  }

  @override
  String childSafeComposeStimulus(String level, String word) {
    return '根据监护人的设置（$level），无法发送此表达$word。请换种说法';
  }

  @override
  String get childSafeBlockedThisPlugin => '监护人已禁用此插件';

  @override
  String get childSafeDevPreviewUnknown => '只能运行监护人选择的插件（此加载方式无法确认是哪个插件）';

  @override
  String get childSafeBlockedInstall => '监护人已禁止安装插件';

  @override
  String get childSafeNearDenyPlugin => '此插件接近监护人禁止的示例';

  @override
  String get childSafeInstallListedOnly => '只能安装监护人选择的插件';

  @override
  String get childSafeInstallExamplesOnly => '只能安装监护人选择的插件以及接近允许示例的插件';

  @override
  String get childSafeCacheUnverified => '无法验证已保存限制的签名。请联网重新获取';

  @override
  String get childSafeNewSettingsUnverified => '无法验证监护人新设置的签名（保持之前的设置）';

  @override
  String get childSafeComposeLocked => '在监护人完成设置前无法发送';

  @override
  String childSafeComposeDailyLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天已发送 $count 条（监护人设置的每日数量）。明天再来吧',
    );
    return '$_temp0';
  }

  @override
  String childSafeComposeAfterTransform(String message) {
    return '$message（发送前加工后的正文）';
  }

  @override
  String get childSafeStatePending => '等待设置';

  @override
  String get childSafeWatchAsGuardian => '监护（监护人）';

  @override
  String get childSafeLoginWithCode => '使用监护人提供的代码登录';

  @override
  String get childSafeChildMode => '儿童模式';

  @override
  String get childSafeGuardianStateApplied => '监护中（已送达设备）';

  @override
  String childSafeGuardianStateNotApplied(int revision) {
    return '监护中（设置 $revision 尚未送达设备）';
  }

  @override
  String childSafeGuardianPledgeTitle(String version) {
    return '监护人誓约（版本 $version）';
  }

  @override
  String childSafeGuardianPledgeMessage(String pledge) {
    return '$pledge\n\n同意后，将进入使用个人编号卡（数字认证应用）的验证（适用于居住在日本的用户）。';
  }

  @override
  String get childSafeGuardianPledgeConfirm => '同意并继续';

  @override
  String get childSafeGuardianCancel => '取消';

  @override
  String get childSafeGuardianLoadError => '无法加载';

  @override
  String get childSafeGuardianReload => '重新加载';

  @override
  String get childSafeGuardianVerifySection => '监护人验证';

  @override
  String get childSafeGuardianVerified => '已验证';

  @override
  String get childSafeGuardianNotVerified => '尚未验证';

  @override
  String get childSafeGuardianVerifyIntro =>
      '在创建或关联孩子的账号之前，需要进行监护人验证（日本使用个人编号卡）。';

  @override
  String get childSafeGuardianVerifyIntroDetail =>
      '在创建或关联孩子的账号之前，需要进行监护人验证（日本使用个人编号卡（JPKI），其他国家在网页控制台自行申报）。';

  @override
  String get childSafeGuardianVerifyJpki => '使用个人编号卡验证';

  @override
  String get childSafeGuardianVerifyJpkiSubtitle =>
      '适用于居住在日本的用户。同意誓约后，将在外部浏览器中打开';

  @override
  String get childSafeGuardianVerifyWeb => '在网页控制台验证';

  @override
  String get childSafeGuardianOpensInBrowser => '将在外部浏览器中打开';

  @override
  String childSafeGuardianChildrenSection(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '监护中的孩子（$count / $max）',
    );
    return '$_temp0';
  }

  @override
  String get childSafeGuardianNoChildren => '暂无。';

  @override
  String get childSafeGuardianCreatedByGuardian => ' · 由监护人创建';

  @override
  String get childSafeGuardianAddSection => '添加孩子';

  @override
  String get childSafeGuardianCreate => '创建孩子的账号';

  @override
  String get childSafeGuardianCreateSubtitle =>
      '设置用户名 / 名称 / 年龄段后，将显示一次用于在孩子设备上登录的代码';

  @override
  String get childSafeGuardianHandleHint => '用户名（英文字母和数字）';

  @override
  String get childSafeGuardianNameHint => '显示名称';

  @override
  String get childSafeGuardianCreateButton => '创建';

  @override
  String childSafeGuardianNewLoginCodeTitle(String handle) {
    return '@$handle 的登录代码（在孩子设备的“使用监护人提供的代码登录”中输入，或用孩子设备的相机扫描二维码）';
  }

  @override
  String get childSafeGuardianPair => '通过代码关联';

  @override
  String get childSafeGuardianPairSubtitle =>
      '通过孩子设备上的“儿童模式”关联孩子已有的 RASQ 账号（10 分钟内，仅限一次）';

  @override
  String get childSafeGuardianPairCodeTitle =>
      '关联代码（在孩子设备的“儿童模式”中输入，或用孩子设备的相机扫描二维码）';

  @override
  String childSafeGuardianCodeExpires(String time) {
    return '有效期至 $time。关闭此画面后将无法再次显示（重新生成后，之前的代码将无法使用）。';
  }

  @override
  String get childSafeGuardianCodeQr => '代码二维码';

  @override
  String get childSafeGuardianCopy => '复制';

  @override
  String get childSafeGuardianCopyLink => '复制链接';

  @override
  String get childSafeGuardianClose => '关闭';

  @override
  String get childSafeGuardianPageTimeline => '时间线';

  @override
  String get childSafeGuardianPageComposer => '帖子';

  @override
  String get childSafeGuardianPageAstell => 'ASTell';

  @override
  String get childSafeGuardianPagePlugins => '插件';

  @override
  String get childSafeGuardianPageSns => 'SNS';

  @override
  String get childSafeGuardianPageScreenTime => '屏幕使用时间';

  @override
  String get childSafeGuardianPageOther => '其他';

  @override
  String get childSafeGuardianTimeFormatError => '请以 HH:MM 格式输入时间';

  @override
  String get childSafeGuardianConfirmTitle => '发送此设置';

  @override
  String get childSafeGuardianConfirmSend => '发送';

  @override
  String childSafeGuardianConfirmIntro(String handle) {
    return '此设置将送达 @$handle 的设备。';
  }

  @override
  String childSafeGuardianConfirmIntroDetail(String handle) {
    return '@$handle 的设备将收到由 Central 签名的设置（在设备上验证后应用）。';
  }

  @override
  String childSafeGuardianSaved(int revision) {
    return '已保存（设置 $revision）。送达孩子的设备后将显示“已送达”';
  }

  @override
  String childSafeGuardianImportPreset(String band) {
    return '加载 $band 的默认设置';
  }

  @override
  String get childSafeGuardianImportCopy => '复制其他孩子的设置';

  @override
  String childSafeGuardianImportedPreset(String band) {
    return '已加载 $band 的默认设置';
  }

  @override
  String get childSafeGuardianCopyWhich => '要复制哪个孩子的设置？';

  @override
  String childSafeGuardianNotSetUp(String handle) {
    return '@$handle 尚未完成设置';
  }

  @override
  String childSafeGuardianCopied(String handle) {
    return '已复制 @$handle 的设置';
  }

  @override
  String childSafeGuardianNotSavedYet(String what) {
    return '$what（尚未保存）';
  }

  @override
  String get childSafeGuardianEnd => '结束监护';

  @override
  String childSafeGuardianEndMessage(String handle) {
    return '将解除 @$handle 的所有限制。孩子的设备将在下次连接时解除。如需恢复，请重新关联。';
  }

  @override
  String childSafeGuardianEndMessageDetail(String handle) {
    return '将解除 @$handle 的所有限制。孩子的设备将在下次连上 Central 时解除。如需恢复，请重新关联。';
  }

  @override
  String get childSafeGuardianEndConfirm => '结束';

  @override
  String get childSafeGuardianEndSubtitle => '解除所有限制';

  @override
  String get childSafeGuardianSummarySection => '近期发布内容摘要（14 天）';

  @override
  String get childSafeGuardianLoginSection => '孩子设备的登录';

  @override
  String get childSafeGuardianReissue => '重新生成代码';

  @override
  String get childSafeGuardianReissueSubtitle =>
      '在孩子设备的“使用监护人提供的代码登录”中输入的代码（10 分钟内，仅限一次。之前的代码将无法使用）';

  @override
  String childSafeGuardianLoginCodeTitle(String handle) {
    return '@$handle 的登录代码';
  }

  @override
  String get childSafeGuardianSaveButton => '保存并发送到孩子的设备';

  @override
  String get childSafeGuardianImportTooltip => '导入设置';

  @override
  String childSafeGuardianPresetCaption(String band) {
    return '选择强度后，时间线和帖子的判定强度将统一。可通过右侧的圆形按钮加载 $band 的默认设置或其他孩子的设置。';
  }

  @override
  String get childSafeGuardianSummaryEmpty => '暂无报告（孩子的设备每天发送一次已结束日期的数量）。';

  @override
  String get childSafeGuardianSummaryCaption =>
      '仅包括发送数 / 拦截数 / 拦截类型（帖子正文和话题不会送达。发送前的判定在孩子的设备上进行）。';

  @override
  String childSafeGuardianSummaryDay(int posts, int blocked, String trips) {
    return '发送 $posts · 拦截 $blocked$trips';
  }

  @override
  String childSafeGuardianSummaryTrips(String list) {
    return '（$list）';
  }

  @override
  String get childSafeGuardianSummaryTripsSeparator => '、';

  @override
  String get childSafeGuardianTimelineEnabled => '筛选时间线';

  @override
  String get childSafeGuardianTimelineEnabledSubtitle => '不显示含有强烈用语的帖子，并按话题筛选';

  @override
  String get childSafeGuardianTimelineLevel => '时间线强度';

  @override
  String get childSafeGuardianTimelineTopics => '时间线话题';

  @override
  String get childSafeGuardianTimelineAllowHint => '显示的话题（用“,”分隔词语或标签）';

  @override
  String get childSafeGuardianTimelineDenyHint => '不显示的话题（用“,”分隔词语或标签）';

  @override
  String get childSafeGuardianTimelineAllowNote => '白名单：只有符合任一话题的帖子才会出现在时间线中。';

  @override
  String get childSafeGuardianTimelineDenyNote => '黑名单：不显示符合的帖子（空 = 不按话题筛选）。';

  @override
  String get childSafeGuardianComposerEnabled => '判定帖子';

  @override
  String get childSafeGuardianComposerEnabledSubtitle =>
      '根据强烈用语和话题在发送前拦截（标记命中的词语）';

  @override
  String get childSafeGuardianComposerLevel => '帖子强度';

  @override
  String get childSafeGuardianPostsPerDayHint => '每天可发送的帖子数（空 = 不限制，0～1000）';

  @override
  String get childSafeGuardianComposerTopics => '帖子话题';

  @override
  String get childSafeGuardianComposerAllowHint => '可发送的话题（用“,”分隔词语或标签）';

  @override
  String get childSafeGuardianComposerDenyHint => '不可发送的话题（用“,”分隔词语或标签）';

  @override
  String get childSafeGuardianComposerAllowNote => '白名单：只能发送符合任一话题的帖子（不适用于私信）。';

  @override
  String get childSafeGuardianComposerDenyNote =>
      '黑名单：符合的帖子无法发送（空 = 不按话题拦截。不适用于私信）。';

  @override
  String get childSafeGuardianAstellCaption => '孩子在 ASTell（房间的通话、聊天、共享）中可以做的事。';

  @override
  String get childSafeGuardianInstallSection => '安装';

  @override
  String get childSafeGuardianInstallCaption =>
      '孩子可以自行安装的范围。插件会不断增加，因此不是逐个决定，而是通过下方的“示例”大致决定。';

  @override
  String get childSafeGuardianNamedSection => '按名称允许的插件';

  @override
  String get childSafeGuardianNamedNone => '无。';

  @override
  String get childSafeGuardianNamedCaption => '此处的插件即使接近禁止的示例也可以使用（点 ✕ 移除）。';

  @override
  String get childSafeGuardianRemove => '移除';

  @override
  String get childSafeGuardianAddIdHint => '按 id 添加（例：jp.example.quiz）';

  @override
  String get childSafeGuardianAddIdButton => '添加';

  @override
  String get childSafeGuardianIdShapeError =>
      '不是插件 id 的格式（小写英文字母、数字、“.”“_”“-”，例：jp.example.quiz）';

  @override
  String get childSafeGuardianSnsCaption =>
      '孩子可以使用的 SNS 类型和服务器（来自你的组合）。不选择服务器时，该类型的任何服务器均可。不会借出监护人的 SNS 登录。';

  @override
  String get childSafeGuardianSnsAdd => '孩子可以添加 SNS 账号';

  @override
  String get childSafeGuardianTimeEnabled => '监护时段';

  @override
  String get childSafeGuardianTimeEnabledSubtitle => '在此期间只有一条时间线（以孩子设备的时钟为准）';

  @override
  String get childSafeGuardianTimeStartHint => '开始 21:00';

  @override
  String get childSafeGuardianTimeEndHint => '结束 06:00';

  @override
  String get childSafeGuardianTimeRangeSeparator => '～';

  @override
  String get childSafeGuardianTimeLegacyNote =>
      '当前设置为旧格式的“在此期间不显示任何内容”。此格式无法重新保存，请添加要显示的话题或改为黑名单后再保存。';

  @override
  String get childSafeGuardianTimeTopics => '此期间的话题';

  @override
  String get childSafeGuardianTimeAllowHint => '此期间显示的话题（用“,”分隔词语或标签）';

  @override
  String get childSafeGuardianTimeDenyHint => '此期间不显示的话题（用“,”分隔词语或标签）';

  @override
  String get childSafeGuardianTimeAllowNote => '白名单：此期间只显示符合任一话题的帖子。';

  @override
  String get childSafeGuardianTimeDenyNote => '黑名单：此期间不显示符合的帖子（空 = 不按话题筛选）。';

  @override
  String get childSafeGuardianHideNotifications => '隐藏通知';

  @override
  String get childSafeGuardianHidePostDetail => '不允许打开帖子详情';

  @override
  String get childSafeGuardianHideDm => '隐藏私信';

  @override
  String get childSafeGuardianRaiEnabled => '可以使用 RAi';

  @override
  String get childSafeGuardianRaiComingSoon => '准备中（目前不生效）';

  @override
  String get childSafeGuardianRaiAutomation => '使用函数自动化';

  @override
  String get childSafeGuardianRaiAutomationSubtitle => '关闭时，仅通过引导（指示）进行';

  @override
  String get childSafeGuardianSearchSection => '搜索';

  @override
  String get childSafeGuardianFeaturesSection => '功能';

  @override
  String get childSafeGuardianExamplesTitlePlugins => '通过示例决定（插件）';

  @override
  String get childSafeGuardianExamplesTitleTl => '通过示例决定（便签 / 列表）';

  @override
  String get childSafeGuardianExamplesCaptionPlugins =>
      '通过示例选择“允许 / 禁止这类插件”。孩子的设备根据插件的名称和说明是否接近示例来判断。接近禁止示例的插件即使在“自由”下也无法使用。选择“接近示例的”后，可以使用按名称允许的插件以及接近允许示例的插件。';

  @override
  String get childSafeGuardianExamplesCaptionTl =>
      '从你最近的操作 / 便签 / 列表中选择“允许 / 禁止这类内容”。孩子的便签 / 列表中，内容接近禁止示例的，不会出现在列表和时间线中。';

  @override
  String get childSafeGuardianPickPlugins => '选择示例（插件 / 商店）';

  @override
  String get childSafeGuardianPickTl => '选择示例（最近的操作 / 便签 / 列表）';

  @override
  String childSafeGuardianPickCounts(int allow, int deny) {
    return '允许示例 $allow / 禁止示例 $deny';
  }

  @override
  String childSafeGuardianPickTitlePlugins(String handle) {
    return '插件示例（@$handle）';
  }

  @override
  String childSafeGuardianPickTitleTl(String handle) {
    return '时间线示例（@$handle）';
  }

  @override
  String get childSafeGuardianAllowLabel => '允许示例';

  @override
  String get childSafeGuardianDenyLabel => '禁止示例';

  @override
  String get childSafeGuardianPickIntroPlugins =>
      '查看内容，为孩子选择“允许示例”/“禁止示例”（也可向右 / 向左滑动）。孩子的设备会根据与示例的接近程度来区分新插件。';

  @override
  String get childSafeGuardianPickIntroTl =>
      '查看内容，为孩子选择“允许示例”/“禁止示例”（也可向右 / 向左滑动）。孩子的设备会根据与示例的接近程度来区分便签 / 列表。';

  @override
  String get childSafeScreensBadge => '监护中';

  @override
  String childSafeScreensWindowBanner(String window, String detail) {
    return '现在是监护时段（$window）。$detail';
  }

  @override
  String get childSafeScreensWindowNothing => '不显示任何帖子';

  @override
  String childSafeScreensWindowAllowOnly(String topics) {
    return '仅显示与“$topics”相关的话题';
  }

  @override
  String childSafeScreensWindowDenied(String topics) {
    return '不显示与“$topics”相关的话题';
  }

  @override
  String get childSafeScreensBlockedHint => '监护设置由监护人决定';

  @override
  String get childSafeScreensHubTitle => '儿童安全';

  @override
  String get childSafeScreensHubIntro =>
      '监护人决定孩子账号的使用方式。监护人只会收到数量和被阻止的类型，不会发送帖子正文。';

  @override
  String get childSafeScreensHubIntroDetail =>
      '监护人的 RASQ 账号决定孩子的 RASQ 账号的使用方式。帖子的判定在本设备上进行，监护人只会收到发送数、阻止数以及发送前阻止的类型（不会发送帖子正文或话题）。';

  @override
  String get childSafeScreensHubManagedSection => '您正受到监护';

  @override
  String get childSafeScreensHubParent => '监护人';

  @override
  String get childSafeScreensHubState => '状态';

  @override
  String childSafeScreensHubStateActive(int revision) {
    return '监护中（设置版本 $revision）';
  }

  @override
  String get childSafeScreensHubOffline => '目前无法连接服务器。将按之前的设置继续监护。';

  @override
  String get childSafeScreensHubRefresh => '重新获取监护人的设置';

  @override
  String get childSafeScreensHubAsGuardian => '作为监护人';

  @override
  String childSafeScreensHubGuardianVerified(String method) {
    return '已验证（$method）。创建、关联或设置孩子的账号';
  }

  @override
  String get childSafeScreensHubGuardianUnverified =>
      '监护人验证请在 Web 控制台进行（日本使用个人编号卡，其他地区为自行申报）';

  @override
  String get childSafeScreensHubAsChild => '作为孩子';

  @override
  String get childSafeScreensHubChildModeLogin => '使用监护人提供的代码登录';

  @override
  String get childSafeScreensHubChildModePair => '使用监护人的代码关联此账号';

  @override
  String get childSafeScreensHubLoginSubtitle => '登录监护人创建的孩子账号';

  @override
  String get childSafeScreensHubThisDevice => '此设备';

  @override
  String get childSafeScreensHubSafety => '隐私与安全模式';

  @override
  String get childSafeScreensHubSafetyManaged => '监护期间，敏感媒体始终隐藏（无法更改）';

  @override
  String get childSafeScreensHubSafetyNormal => '敏感媒体的处理方式';

  @override
  String childSafeScreensTopicsNote(String label, String topics) {
    return '（$label：$topics）';
  }

  @override
  String get childSafeScreensTopicsNone => '无';

  @override
  String get childSafeScreensTopicsShown => '显示的话题';

  @override
  String get childSafeScreensTopicsHidden => '隐藏的话题';

  @override
  String get childSafeScreensTopicsSendable => '可发送的话题';

  @override
  String get childSafeScreensTopicsUnsendable => '不可发送的话题';

  @override
  String get childSafeScreensTopicsNotShown => '不显示的话题';

  @override
  String childSafeScreensSummaryTimeline(String level, String note) {
    return '时间线：$level$note';
  }

  @override
  String childSafeScreensSummaryComposer(String level, String note) {
    return '帖子判定：$level$note';
  }

  @override
  String childSafeScreensSummaryPostsPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每天可发送的帖子：$count 条',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryTime(String window, String note) {
    return '监护时段：$window$note';
  }

  @override
  String get childSafeScreensSummaryTimeNothing => '（不显示帖子）';

  @override
  String childSafeScreensSummarySns(
    String kinds,
    String servers,
    String noAdd,
  ) {
    return '可用的 SNS：$kinds$servers$noAdd';
  }

  @override
  String get childSafeScreensSummaryAny => '任意';

  @override
  String childSafeScreensSummarySnsServers(String servers) {
    return '（$servers）';
  }

  @override
  String get childSafeScreensSummarySnsNoAdd => '，不可添加';

  @override
  String childSafeScreensSummaryFeaturesOff(String list) {
    return '已停用的功能：$list';
  }

  @override
  String childSafeScreensSummarySearchOff(String list) {
    return '已停用的搜索：$list';
  }

  @override
  String childSafeScreensSummaryPlugins(String scope, String install) {
    return '插件：$scope，安装：$install';
  }

  @override
  String childSafeScreensSummaryPluginsExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选的 $count 个，以及与允许示例相近的',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryPluginsListed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '仅限已选的 $count 个',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryExamples(int allow, int deny) {
    return '示例：允许 $allow 个 / 阻止 $deny 个（与阻止示例相近的插件、便签、列表不会显示）';
  }

  @override
  String childSafeScreensSummaryRai(int count, String noAuto) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RAi：$count 类函数$noAuto',
    );
    return '$_temp0';
  }

  @override
  String get childSafeScreensSummaryRaiNoAuto => '（无自动化）';

  @override
  String get childSafeScreensSummaryRaiOff => 'RAi：不可用';

  @override
  String childSafeScreensFromLink(String action) {
    return '已通过链接（QR 码）填入代码。请确认是从自己的监护人那里收到的，再点按“$action”。如果是陌生人的链接，请不要点按，直接关闭。';
  }

  @override
  String get childSafeScreensPaired => '已与监护人关联。请等待监护人完成设置';

  @override
  String get childSafeScreensPairNotLoggedIn =>
      '尚未登录 RASQ 账号。如果是监护人创建的账号，请使用监护人提供的代码登录。';

  @override
  String get childSafeScreensPairExistingLogin => '登录现有的 RASQ 账号';

  @override
  String childSafeScreensPairIntro(String handle) {
    return '将 @$handle 关联到监护人的监护。请输入监护人屏幕上显示的代码（8 位）。关联后，在监护人完成设置之前无法使用。';
  }

  @override
  String childSafeScreensPairIntroDetail(String handle) {
    return '将 @$handle 关联到监护人的监护。请输入监护人屏幕（应用或 Web 控制台）上显示的代码（8 位，例如 ABCD-EFGH）。关联后，在监护人完成设置之前无法使用应用。';
  }

  @override
  String get childSafeScreensPairButton => '关联';

  @override
  String get childSafeScreensPairQrHint => '也可以用本设备的相机应用扫描监护人屏幕上的 QR 码进行关联。';

  @override
  String get childSafeScreensPairQrHintDetail =>
      '用本设备的相机应用扫描监护人屏幕上的 QR 码，会打开已填入代码的此页面。粘贴链接（rasq://child-safe/pair?code=…）也可以关联。';

  @override
  String get childSafeScreensPairNoQr => '本设备无法扫描 QR 码。请输入代码。';

  @override
  String get childSafeScreensPairNoQrDetail =>
      '本设备无法扫描 QR 码。请输入代码，或粘贴链接（rasq://child-safe/pair?code=…）。';

  @override
  String get childSafeScreensLoginFailed => '无法登录';

  @override
  String childSafeScreensLoggedIn(String handle, String device) {
    return '已登录 @$handle（$device）';
  }

  @override
  String get childSafeScreensLoginIntro =>
      '监护人在应用中创建孩子账号后，会显示一个一次性代码。输入该代码后，本设备将成为该账号。本设备上的 SNS 账号不会被继承。';

  @override
  String get childSafeScreensLoginCodeHint => '登录代码';

  @override
  String get childSafeScreensLoginButton => '登录';

  @override
  String get childSafeScreensPendingUnverifiedTitle => '无法验证监护人的设置';

  @override
  String get childSafeScreensPendingTitle => '请等待监护人完成设置';

  @override
  String get childSafeScreensPendingSignatureMismatch => '设置的签名不一致。';

  @override
  String childSafeScreensPendingBody(String parent) {
    return '您已与 $parent 建立监护关联。$parent 决定使用方式后，即可开始使用。';
  }

  @override
  String get childSafeScreensPendingParent => '监护人';

  @override
  String get childSafeScreensPendingOffline => '目前无法连接服务器。';

  @override
  String get childSafeScreensPendingRefresh => '刷新';

  @override
  String get childSafeScreensPendingLogout => '退出登录';

  @override
  String get childSafeScreensPendingRasqLogin => '登录 RASQ 账号';

  @override
  String get clipsNoSession => '没有会话';

  @override
  String get clipsChildSafeBlocked => '监护人已屏蔽此便签';

  @override
  String get clipsRetry => '重新加载';

  @override
  String get clipsEmptyTitle => '此便签为空';

  @override
  String get clipsEmptyHint => '可通过帖子菜单中的“添加到便签”收集到这里';

  @override
  String clipsPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String get clipsKindHost => 'RASQ 便签（跨 SNS）';

  @override
  String get clipsKindPrivate => '非公开便签';

  @override
  String get clipsCaptionSeparator => ' · ';

  @override
  String get clipsLoading => '加载中…';

  @override
  String get clipsLoadMore => '加载更多';

  @override
  String clipsActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get clipsPublishHint => '公开后，可通过账号页面和分享链接查看';

  @override
  String clipsPublishHintSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '公开后，可通过账号页面和分享链接查看（仅关注者可见等 $count 条帖子不会包含在内）',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublishNeedsAccount => '公开需要 RASQ 账号';

  @override
  String get clipsPublish => '公开';

  @override
  String clipsPublishedPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已公开（正在确认 $count 条帖子的公开范围）',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublished => '已公开';

  @override
  String clipsPublishedStatusSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '公开中（仅关注者可见等 $count 条帖子未包含在内）',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublishedStatus => '公开中';

  @override
  String get clipsLinkCopied => '已复制链接';

  @override
  String get clipsCopyLink => '复制链接';

  @override
  String get clipsUnpublished => '已取消公开';

  @override
  String get clipsUnpublish => '取消公开';

  @override
  String get clipsAddTitle => '添加到便签';

  @override
  String get clipsAddAddedHost => '已添加 · RASQ 便签';

  @override
  String get clipsAddAddedHostPublished => '已添加 · RASQ 便签（公开中）';

  @override
  String clipsAddHostRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条 · RASQ 便签（跨 SNS）',
    );
    return '$_temp0';
  }

  @override
  String clipsAddHostRowPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条 · RASQ 便签（跨 SNS） · 公开中',
    );
    return '$_temp0';
  }

  @override
  String get clipsAddCreate => '新建便签';

  @override
  String clipsAdded(String name) {
    return '已添加到“$name”';
  }

  @override
  String clipsAddFailed(String error) {
    return '无法添加到便签：$error';
  }

  @override
  String get clipsCreateTitle => '新便签';

  @override
  String get clipsCreateNameHint => '便签名称';

  @override
  String get clipsCreateDescriptionHint => '说明（可选）';

  @override
  String get clipsCreateHost => '设为 RASQ 便签（跨 SNS）';

  @override
  String get clipsCreateHostSubtitle => '保存在本设备上，其他 SNS 的帖子也可放入同一便签';

  @override
  String get clipsCreateAndAdd => '创建并添加';

  @override
  String get clipsIndexFallback => '无法确定话题的帖子';

  @override
  String get clipsIndexSingles => '单独帖子';

  @override
  String clipsIndexRelated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '相关帖子 $count 条',
    );
    return '$_temp0';
  }

  @override
  String get clipsTocTitle => '目录';

  @override
  String clipsTocPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String get clipsTocFiltering => '筛选中';

  @override
  String get clipsNoServer => '未设置 RASQ 账号的服务器';

  @override
  String get clipsNotFound => '找不到便签';

  @override
  String get collectionsImportToTimeline => '导入时间线';

  @override
  String get collectionsNotFound => '未找到';

  @override
  String get collectionsNotFoundHint => '已被删除或设为不公开';

  @override
  String get collectionsReload => '重新加载';

  @override
  String get collectionsBlockedList => '监护人已屏蔽此列表';

  @override
  String get collectionsBlockedClip => '监护人已屏蔽此便签';

  @override
  String get collectionsMenuCopyLink => '复制链接';

  @override
  String get collectionsMenuRefresh => '立即重新获取';

  @override
  String get collectionsMenuMakePrivate => '设为不公开';

  @override
  String get collectionsMenuMakePublic => '公开';

  @override
  String get collectionsMenuRename => '修改名称和说明';

  @override
  String get collectionsMenuDelete => '删除';

  @override
  String get collectionsMenuUnpublish => '取消公开';

  @override
  String get collectionsLinkCopied => '已复制链接';

  @override
  String get collectionsRefreshFailed => '无法重新获取';

  @override
  String get collectionsRefreshed => '已重新获取';

  @override
  String get collectionsRenameTitle => '名称和说明';

  @override
  String get collectionsSave => '保存';

  @override
  String get collectionsNameHint => '名称';

  @override
  String get collectionsDescriptionHint => '说明（可选）';

  @override
  String collectionsDeleteConfirmTitle(String name) {
    return '要删除“$name”吗？';
  }

  @override
  String get collectionsDeleteConfirmMessage => '它也会从关注者的列表中消失。';

  @override
  String get collectionsDeleteButton => '删除';

  @override
  String get collectionsCancel => '取消';

  @override
  String collectionsActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get collectionsTabPosts => '帖子';

  @override
  String get collectionsTabTopics => '话题目录';

  @override
  String get collectionsTabMembers => '成员';

  @override
  String get collectionsTabServers => '服务器';

  @override
  String get collectionsStatusRefreshedOnView => '已在查看时更新';

  @override
  String get collectionsStatusRefreshFailed => '无法重新获取（显示的是之前的内容）';

  @override
  String get collectionsStatusFollowingHint => '如果你与成员属于同一服务器或关注了成员，查看时会更新';

  @override
  String get collectionsKindList => 'RASQ 列表';

  @override
  String get collectionsKindClip => 'RASQ 便签';

  @override
  String get collectionsPrivate => '不公开';

  @override
  String get collectionsPublic => '公开';

  @override
  String collectionsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String collectionsItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String collectionsFollowerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '关注者 $count',
    );
    return '$_temp0';
  }

  @override
  String collectionsUpdatedAgo(String ago) {
    return '更新于 $ago';
  }

  @override
  String get collectionsSeparator => ' · ';

  @override
  String get collectionsFollowing => '关注中';

  @override
  String get collectionsFollow => '关注';

  @override
  String get collectionsNoPostsYet => '还没有帖子';

  @override
  String get collectionsNoPostsHintEmpty => '可在用户页面的 … →“添加到 RASQ 列表”中添加成员';

  @override
  String get collectionsNoPostsHintCollecting => '有权查看的人打开时会收集帖子';

  @override
  String get collectionsClipEmpty => '此便签为空';

  @override
  String get collectionsItemGone => '此帖子已无法查看（已被删除或公开范围已更改）';

  @override
  String get collectionsItemChecking => '正在确认公开范围';

  @override
  String get collectionsAddMembers => '添加成员';

  @override
  String collectionsMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已添加 $count 人',
    );
    return '$_temp0';
  }

  @override
  String collectionsAddFailed(String error) {
    return '无法添加：$error';
  }

  @override
  String get collectionsNoMembers => '没有成员';

  @override
  String get collectionsNoMembersHint => '请使用“添加成员”，或在用户页面的 … →“添加到 RASQ 列表”';

  @override
  String collectionsMemberSubtitle(String handle, String kind) {
    return '@$handle · $kind';
  }

  @override
  String get collectionsRemoveFromListTooltip => '从列表中移除';

  @override
  String collectionsRemoveFailed(String error) {
    return '无法移除：$error';
  }

  @override
  String get collectionsNotFetchableHint =>
      '没有可以获取列表中成员信息的账号（需要与成员同一服务器的账号，或关注了成员）';

  @override
  String get collectionsNoServer => '未设置 RASQ 账号的服务器';

  @override
  String collectionsCheckFailed(String error) {
    return '无法确认：$error';
  }

  @override
  String get collectionsPickerEmpty => '还没有 RASQ 列表';

  @override
  String get collectionsPickerNoHits => '未找到';

  @override
  String get collectionsPickerMine => '我的列表';

  @override
  String get collectionsPickerNotFetchable => '无法获取';

  @override
  String get collectionsNotLoggedIn => '未登录';

  @override
  String collectionsImportRejected(String name, String reason) {
    return '无法导入“$name”($reason)';
  }

  @override
  String collectionsAlreadyImported(String name) {
    return '“$name”已在首页时间线中';
  }

  @override
  String collectionsImported(String name) {
    return '已将“$name”导入首页时间线（可通过标签栏的齿轮确认）';
  }

  @override
  String get collectionsTileOpen => '查看';

  @override
  String get collectionsCreateNeedsAccount => '创建 RASQ 列表需要 RASQ 账号';

  @override
  String get collectionsCreateTitle => '新建 RASQ 列表';

  @override
  String get collectionsListNameHint => '列表名称';

  @override
  String get collectionsPublishSwitch => '公开';

  @override
  String get collectionsPublishSwitchSubtitle => '可从账号页面和分享链接查看。关注者查看时也会更新';

  @override
  String get collectionsCreateButton => '创建';

  @override
  String collectionsCreateFailed(String error) {
    return '无法创建：$error';
  }

  @override
  String get collectionsUseNeedsAccount => '使用 RASQ 列表需要 RASQ 账号';

  @override
  String collectionsLoadListsFailed(String error) {
    return '无法加载列表：$error';
  }

  @override
  String get collectionsAddToListTitle => '添加到 RASQ 列表';

  @override
  String collectionsAddToListSubtitlePublic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0 · 公开';
  }

  @override
  String collectionsAddToListSubtitlePrivate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0 · 不公开';
  }

  @override
  String get collectionsCreateNewList => '新建列表';

  @override
  String collectionsAddedTo(String name) {
    return '已添加到“$name”';
  }

  @override
  String collectionsAlreadyIn(String name) {
    return '已在“$name”中';
  }

  @override
  String get composeTargetNormalTitle => '撰写帖子';

  @override
  String get composeTargetReplyTitle => '回复';

  @override
  String get composeTargetQuoteTitle => '引用';

  @override
  String get composeEmojiPickerTitle => '表情';

  @override
  String get composeEmojiPickerClose => '关闭';

  @override
  String get composePollRemoveTooltip => '删除投票';

  @override
  String composePollChoiceHint(int index) {
    return '选项$index';
  }

  @override
  String get composePollChoiceDeleteTooltip => '删除';

  @override
  String get composePollAddChoice => '添加选项';

  @override
  String get composePollTimed => '设置截止时间';

  @override
  String get composePollMultiple => '多选';

  @override
  String get composePollUnitDays => '天';

  @override
  String get composePollUnitHours => '小时';

  @override
  String get composePollUnitMinutes => '分钟';

  @override
  String get composePollUnitSeconds => '秒';

  @override
  String get composeDraftsTitle => '草稿';

  @override
  String get composeDraftsCancel => '取消';

  @override
  String get composeDraftsDelete => '删除';

  @override
  String get composeDraftsSaveAndClose => '保存当前内容并关闭';

  @override
  String get composeDraftsOverwriteAndClose => '用当前内容覆盖保存并关闭';

  @override
  String get composeDraftsSaveNewAndClose => '将当前内容存为新草稿并关闭';

  @override
  String get composeDraftsEmpty => '没有草稿';

  @override
  String composeDraftsAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '附件 $count',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftsOpenNow => '正在编辑';

  @override
  String get composeDraftsSelectOff => '取消选择';

  @override
  String get composeDraftsSelect => '选择';

  @override
  String composeDraftsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项',
    );
    return '$_temp0';
  }

  @override
  String composeDraftTitleAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '（附件 $count 个）',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftTitleEmpty => '（无正文）';

  @override
  String get composeDraftTargetReply => '回复';

  @override
  String get composeDraftTargetQuote => '引用';

  @override
  String get composeDraftTargetPost => '帖子';

  @override
  String get composeReactionAcceptanceAll => '全部';

  @override
  String get composeReactionAcceptanceLikeOnly => '仅限点赞';

  @override
  String get composeReactionAcceptanceLikeOnlyForRemote => '外部仅限点赞';

  @override
  String get composeReactionAcceptanceNonSensitiveOnly => '仅限非敏感';

  @override
  String
  get composeReactionAcceptanceNonSensitiveOnlyForLocalLikeOnlyForRemote =>
      '仅限非敏感&外部仅限点赞';

  @override
  String get composeEmojiResizeHandleSemantics => '调整大小手柄';

  @override
  String get composeEmojiSectionHistory => '最近使用';

  @override
  String get composeEmojiSectionPrediction => '推荐';

  @override
  String get composeEmojiBundleEditTitle => '编辑组合包';

  @override
  String get composeEmojiBundleEditMessage => '组合包编辑功能即将推出。';

  @override
  String get composeEmojiSectionDefault => '默认';

  @override
  String get composeEmojiCustomEmpty => '没有自定义表情';

  @override
  String get composeEmojiSectionServer => '服务器';

  @override
  String get composeEmojiGenreOther => '其他';

  @override
  String composeEmojiGroupHeading(String name) {
    return '· $name';
  }

  @override
  String get composeEmojiSearchHint => '搜索';

  @override
  String get composeEmojiStickersEmpty => '没有可用的素材包（可从商店安装）';

  @override
  String get composeEmojiSectionSearchResults => '搜索结果';

  @override
  String get composeEmojiSearchNoHit => '未找到';

  @override
  String composeEmojiIndexProgress(int done, int total) {
    return '正在准备语义搜索 $done / $total';
  }

  @override
  String get composeVisibilityHome => '首页';

  @override
  String get composeVisibilityFollowers => '关注者';

  @override
  String get composeVisibilityPublic => '公开';

  @override
  String composeVisibilityTooltip(String label) {
    return '公开范围：$label';
  }

  @override
  String get composeLocalOnlyOnTooltip => '不联合（仅限本服务器）';

  @override
  String get composeLocalOnlyOffTooltip => '联合（点按改为不联合）';

  @override
  String composeReactionAcceptanceTooltip(String label) {
    return '接受的回应：$label';
  }

  @override
  String get composeOn => '开';

  @override
  String get composeOff => '关';

  @override
  String composeTextPluginTooltip(String label, String state) {
    return '$label（$state · 长按进行设置）';
  }

  @override
  String get composeTextPluginHereTitle => '在此编辑器中开启';

  @override
  String get composeTextPluginHereSubtitle => '将正文的变化传给此插件';

  @override
  String get composeTextPluginAutoTitle => '下次也自动开启';

  @override
  String composeTextPluginAutoDefault(String state) {
    return '插件默认（$state）';
  }

  @override
  String composeTextPluginAutoOverridden(String state) {
    return '已在设置中覆盖（默认为 $state）';
  }

  @override
  String get composeTextPluginResetDefault => '恢复为插件默认';

  @override
  String composeTextPluginCaption(String name) {
    return '$name · 文本处理';
  }

  @override
  String get composeHeaderPost => '发帖';

  @override
  String get composeHeaderReply => '回复';

  @override
  String get composeHeaderQuote => '引用';

  @override
  String get composeCloseOverwriteTitle => '要覆盖草稿吗？';

  @override
  String get composeCloseSaveTitle => '要保存为草稿吗？';

  @override
  String get composeCloseOverwriteMessage => '将用当前内容覆盖正在编辑的草稿并关闭。';

  @override
  String get composeCloseSaveMessage => '将当前内容保留为草稿并关闭。';

  @override
  String get composeCloseOverwrite => '覆盖';

  @override
  String get composeCloseSaveNew => '另存为新草稿';

  @override
  String get composeCloseSave => '保存';

  @override
  String get composeCloseDiscard => '放弃更改';

  @override
  String get composeCancel => '取消';

  @override
  String get composeMultiNormal => '普通发帖';

  @override
  String get composeMultiLinked => '节点联动';

  @override
  String get composeRasqTarget => '发布到 RASQ';

  @override
  String get composeTargetMatchedTooltip => '符合发布目标节点的条件';

  @override
  String get composeTargetCustomize => '自定义发布目标';

  @override
  String get composeMultiSelectOff => '取消多选';

  @override
  String get composeMultiSelectOn => '多选模式';

  @override
  String get composeLinkedConfirmTitle => '确认联动发帖';

  @override
  String get composeLinkedConfirmSame => '以相同内容联动发帖';

  @override
  String get composeLinkedConfirmAlt => '以替代格式联动发帖';

  @override
  String get composeLinkedConfirmPost => '以此内容发布';

  @override
  String get composeRasqNoServer => '未设置 RASQ 服务器';

  @override
  String get composeRasqOverLimit => '超出了 RASQ 的上限';

  @override
  String get composeRasqTextOnlyTip => 'RASQ 的回复仅限文字';

  @override
  String composePickImageFailed(String error) {
    return '无法选择图片：$error';
  }

  @override
  String get composePickVideoLibrary => '图库中的视频';

  @override
  String get composePickVideoFile => '从文件选择（视频 / 音频）';

  @override
  String composePickNotMedia(String name) {
    return '不是视频 / 音频文件：$name';
  }

  @override
  String composePickMediaFailed(String error) {
    return '无法选择视频 / 音频：$error';
  }

  @override
  String get composeRasqNotLoggedIn => '未登录 RASQ 账号';

  @override
  String composeRasqMediaTooLarge(int mb) {
    return '发布到 RASQ 时，每个视频 / 音频最大 $mb MB';
  }

  @override
  String get composeRasqReplyTextOnly => 'RASQ 的回复仅限文字（不能添加附件 / 投票）';

  @override
  String composeRasqReplyMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ 的回复最多 $count 个字',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发布到 RASQ 时最多 $count 个附件',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发布到 RASQ 时最多 $count 个字',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxPollChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发布到 RASQ 时投票选项最多 $count 个',
    );
    return '$_temp0';
  }

  @override
  String get composeRasqPosted => '已发布到 RASQ';

  @override
  String get composeRasqReplyQuota => 'RASQ 的回复最多 100 条。请删除旧的回复';

  @override
  String get composeRasqPostQuota => 'RASQ 的帖子最多 3 条。请删除旧的帖子';

  @override
  String composeRasqPostFailed(String error) {
    return '无法发布到 RASQ：$error';
  }

  @override
  String get composePolicyConfirmTitle => '发送前确认';

  @override
  String get composePolicyConfirmSend => '直接发送';

  @override
  String get composePolicyConfirmEdit => '重新编辑';

  @override
  String get composeSending => '正在发送…';

  @override
  String composeModerationDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '审核延迟：还剩 $seconds 秒',
    );
    return '$_temp0';
  }

  @override
  String composeUploading(int index, int total) {
    return '正在上传 $index/$total';
  }

  @override
  String composeLinkedFailed(String errors) {
    return '联动发帖失败：$errors（主帖已发布）';
  }

  @override
  String composeSendFailed(String error) {
    return '发送失败：$error';
  }

  @override
  String composePostNoticeForAccount(String account, String message) {
    return '$account：$message';
  }

  @override
  String get composeDraftsButton => '草稿';

  @override
  String get composeDirectReplyNote => '回复私信帖子（仅对方可见）';

  @override
  String get composeChooseTargetTooltip => '选择发帖目标';

  @override
  String get composeCwHint => '内容警告..';

  @override
  String get composeCwRemoveTooltip => '移除内容警告';

  @override
  String get composeDmHint => '输入消息..';

  @override
  String get composeTextHint => '祝你有好事发生！';

  @override
  String composeHashtagUsers(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag  $count人',
    );
    return '$_temp0';
  }

  @override
  String get composeToolCamera => '相机';

  @override
  String get composeToolImage => '图片';

  @override
  String get composeToolVideo => '视频 / 音频';

  @override
  String get composeToolCw => '隐藏（CW）';

  @override
  String get composeToolPoll => '投票';

  @override
  String get composeToolEmoji => '表情';

  @override
  String get composeSendReply => '回复';

  @override
  String get composeSend => '发送';

  @override
  String get composeAttachmentRemove => '删除';

  @override
  String get composeAttachmentEdit => '编辑';

  @override
  String get composeAttachmentUnsensitive => '取消敏感标记';

  @override
  String get composeAttachmentSensitive => '标记为敏感';

  @override
  String get composeMediaPickTypeLabel => '视频 / 音频';

  @override
  String get composeMediaMotionVideoLabel => '制作成视频（在卡片中播放附带的视频，有声音）';

  @override
  String get composeMediaMotionAudioLabel => '制作成视频（卡片静态图像 + 附带的音频）';

  @override
  String composeMediaMotionAnimatedLabel(int fps, int seconds) {
    return '制作成视频（以每秒 $fps 帧录制动画 $seconds 秒）';
  }

  @override
  String get composeMediaMotionVideoNote => '此帖子附带视频。';

  @override
  String get composeMediaMotionAudioNote => '此帖子附带音频。';

  @override
  String get composeMediaMotionAnimatedNote => '此帖子包含动画（GIF / 动态 MFM）。';

  @override
  String get composeMediaPostNotOnScreen => '帖子未显示在屏幕上';

  @override
  String get composeMediaSourceFetchFailed => '无法获取原始文件';

  @override
  String composeMediaFormatUnreadable(String ext) {
    return '此设备无法读取 $ext 格式（可作为静态图像粘贴）';
  }

  @override
  String composeMediaSourceOpenFailed(String ext, int bytes) {
    return '无法打开原始文件（.$ext,$bytes 字节）';
  }

  @override
  String get composeMediaTabMine => '我的帖子';

  @override
  String get composeMediaTabReacted => '回应';

  @override
  String get composeMediaTabFavorites => '书签';

  @override
  String get composeMediaTabSearches => '最近的搜索';

  @override
  String get composeMediaStyleThread => '串';

  @override
  String get composeMediaStyleInline => '内联';

  @override
  String get composeMediaPostImageTitle => '添加帖子图片';

  @override
  String get composeMediaCancel => '取消';

  @override
  String get composeMediaConfirm => '确定';

  @override
  String get composeMediaNoAccount => '没有账号';

  @override
  String get composeMediaSearchUnsupported => '此 SNS 不支持搜索帖子';

  @override
  String composeMediaTabUnsupported(String tab) {
    return '此 SNS 不支持“$tab”';
  }

  @override
  String composeMediaFetchFailed(String error) {
    return '无法获取：$error';
  }

  @override
  String get composeMediaCaptureRetry => '请在所选帖子显示在屏幕上时，再次点按“确定”';

  @override
  String composeMediaVideoFailed(String error) {
    return '无法制作成视频：$error';
  }

  @override
  String get composeMediaFilterHistoryHint => '筛选搜索记录';

  @override
  String get composeMediaFilterListHint => '筛选列表';

  @override
  String get composeMediaFilterFromHistoryTooltip => '从最近的搜索中填入';

  @override
  String get composeMediaStyleHeading => '外观';

  @override
  String composeMediaSearchResultsTitle(String query) {
    return '“$query”的搜索结果';
  }

  @override
  String get composeMediaSearchBack => '返回最近的搜索';

  @override
  String composeMediaExcludedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '未显示 $count 条限制了公开范围的帖子。',
    );
    return '$_temp0';
  }

  @override
  String get composeMediaAsVideoOffNote => '关闭 = 该瞬间的静态图像';

  @override
  String get composeMediaExporting => '正在制作视频…';

  @override
  String get composeMediaHistoryEmpty => '没有最近的搜索（在搜索首页搜索后会显示在这里）';

  @override
  String get composeMediaHistoryNoMatch => '没有符合的搜索';

  @override
  String get composeMediaPostsEmpty => '没有帖子';

  @override
  String get composeMediaPostsNoMatch => '没有符合的帖子（可通过“加载更多”继续查找）';

  @override
  String get composeMediaLoadMore => '加载更多';

  @override
  String get composeMfmFnX2 => '放大 2 倍';

  @override
  String get composeMfmFnX3 => '放大 3 倍';

  @override
  String get composeMfmFnX4 => '放大 4 倍';

  @override
  String get composeMfmFnSmall => '缩小显示';

  @override
  String get composeMfmFnCenter => '居中';

  @override
  String get composeMfmFnBlur => '模糊（悬停 / 点按后显示）';

  @override
  String get composeMfmFnRotate => '旋转';

  @override
  String get composeMfmPropRotateDeg => '角度（默认 90）';

  @override
  String get composeMfmFnFlip => '翻转';

  @override
  String get composeMfmPropFlipH => '左右';

  @override
  String get composeMfmPropFlipV => '上下';

  @override
  String get composeMfmFnFg => '文字颜色';

  @override
  String get composeMfmPropFgColor => '十六进制（例：ff0000）';

  @override
  String get composeMfmFnBg => '背景颜色';

  @override
  String get composeMfmPropBgColor => '十六进制（例：ffff00）';

  @override
  String get composeMfmFnShake => '抖动';

  @override
  String get composeMfmPropShakeSpeed => '例：0.5s';

  @override
  String get composeMfmFnSpin => '旋转动画';

  @override
  String get composeMfmPropSpinSpeed => '例：1.5s';

  @override
  String get composeMfmPropSpinLeft => '反向旋转';

  @override
  String get composeMfmPropSpinAlternate => '往复';

  @override
  String get composeMfmPropSpinX => '横轴';

  @override
  String get composeMfmPropSpinY => '纵轴';

  @override
  String get composeMfmFnJump => '跳跃';

  @override
  String get composeMfmPropJumpSpeed => '例：0.75s';

  @override
  String get composeMfmFnBounce => '弹跳';

  @override
  String get composeMfmPropBounceSpeed => '例：0.75s';

  @override
  String get composeMfmFnRainbow => '彩虹色';

  @override
  String get composeMfmPropRainbowSpeed => '例：1s';

  @override
  String get composeMfmFnTwitch => '抽动';

  @override
  String get composeMfmPropTwitchSpeed => '例：0.5s';

  @override
  String get composeMfmFnJelly => '果冻';

  @override
  String get composeMfmPropJellySpeed => '例：1s';

  @override
  String get composeMfmFnTada => '当当';

  @override
  String get composeMfmPropTadaSpeed => '例：1s';

  @override
  String get composeMfmFnPlain => '禁用装饰';

  @override
  String get composeMfmFnFont => '更改字体';

  @override
  String get composeMfmPropFontSerif => '衬线体（serif）';

  @override
  String get composeMfmPropFontMonospace => '等宽（monospace）';

  @override
  String get composeMfmPropFontCursive => '手写体（cursive）';

  @override
  String get composeMfmPropFontFantasy => '装饰体（fantasy）';

  @override
  String get composeMfmFnPosition => '移动位置';

  @override
  String get composeMfmPropPositionX => '横向（以字号为单位，例：0.5）';

  @override
  String get composeMfmPropPositionY => '纵向（以字号为单位，例：-1）';

  @override
  String get composeMfmFnScale => '放大/缩小（最大 5 倍）';

  @override
  String get composeMfmPropScaleX => '横向倍率（例：0.5）';

  @override
  String get composeMfmPropScaleY => '纵向倍率（例：1.5）';

  @override
  String get composeMfmFnBorder => '边框';

  @override
  String get composeMfmPropBorderStyle => '线条样式（solid / dashed / dotted 等）';

  @override
  String get composeMfmPropBorderWidth => '粗细（px，默认 1）';

  @override
  String get composeMfmPropBorderColor => '十六进制（默认为强调色）';

  @override
  String get composeMfmPropBorderRadius => '圆角（px）';

  @override
  String get composeMfmPropBorderNoclip => '不裁剪溢出部分';

  @override
  String get composeMfmFnRuby => '注音（按“正文 读音”的格式书写）';

  @override
  String get composeMfmSampleRuby => '汉字 hànzì';

  @override
  String get composeMfmFnUnixtime => '将 UNIX 时间（秒）显示为日期时间';

  @override
  String get composeMfmFnSparkle => '闪闪发光';

  @override
  String get composeMfmPropDelay => '延迟开始（例：0.5s）';

  @override
  String get composeMfmSearchButton => '搜索';

  @override
  String get composeMfmMarkdownBoldName => '粗体';

  @override
  String get composeMfmMarkdownBoldDescription => '显示为 **粗体**';

  @override
  String get composeMfmMarkdownItalicName => '斜体';

  @override
  String get composeMfmMarkdownItalicDescription => '显示为 *斜体*';

  @override
  String get composeMfmMarkdownStrikeName => '删除线';

  @override
  String get composeMfmMarkdownStrikeDescription => '显示为 ~~删除线~~';

  @override
  String get composeMfmMarkdownInlineCodeName => '行内代码';

  @override
  String get composeMfmMarkdownInlineCodeDescription => '显示为 `代码`';

  @override
  String get composeMfmMarkdownCodeBlockName => '代码块';

  @override
  String get composeMfmMarkdownCodeBlockDescription => '将多行代码显示在框中';

  @override
  String get composeMfmMarkdownHeadingName => '标题';

  @override
  String get composeMfmMarkdownHeadingDescription => '在行首加上 #';

  @override
  String get composeMfmMarkdownLinkName => '链接';

  @override
  String get composeMfmMarkdownLinkDescription => '[显示名称](URL) 的格式';

  @override
  String get composeMfmClose => '关闭';

  @override
  String get composeMfmSample => '示例';

  @override
  String composeMfmSampleWithEmoji(String emoji) {
    return '示例 $emoji';
  }

  @override
  String get composeMfmBackTooltip => '返回列表';

  @override
  String get composeMfmApply => '确定';

  @override
  String get composeMfmNoProps => '此函数没有属性。';

  @override
  String get composePolicyTypeSexual => '色情内容';

  @override
  String get composePolicyTypeViolence => '暴力 / 威胁';

  @override
  String get composePolicyTypeSelfHarm => '自残 / 自杀';

  @override
  String get composePolicyTypeHarassment => '辱骂 / 骚扰';

  @override
  String get composePolicyTypePersonalInfo => '个人信息（电话号码、电子邮件地址、住址等）';

  @override
  String get composePolicyTypeLink => '外部链接';

  @override
  String get composePolicyTypeMedia => '图片 / 视频';

  @override
  String get composePolicyTypeStimulus => '过激言辞';

  @override
  String get composePolicyTypeTopic => '指定话题';

  @override
  String get composePolicyWhoGuardian => '监护人设置';

  @override
  String get composePolicyWhoSanction => '账号限制';

  @override
  String composePolicyBlockedMediaUnmeasured(String who) {
    return '由于$who，无法发送图片 / 视频（本设备无法检查附件）。请移除附件';
  }

  @override
  String composePolicyBlockedUnmeasured(String who, String label) {
    return '由于$who，目前无法发送（本设备无法检查“$label”）';
  }

  @override
  String composePolicyBlocked(String who, String label) {
    return '由于$who，无法发送涉及“$label”的内容。请修改';
  }

  @override
  String composePolicyWarn(String label, String who) {
    return '可能涉及“$label”（$who）。仍要发送吗？';
  }

  @override
  String customShareAddToRoom(String room) {
    return '添加到“$room”';
  }

  @override
  String customShareProposeToRoom(String room) {
    return '在“$room”中提议';
  }

  @override
  String get customSharePlaceOnProfile => '放到个人资料';

  @override
  String get customShareInviteBySwing => '通过 Swing 邀请（多人共用）';

  @override
  String get customShareInstallToShare => '安装后即可通过个人资料或邀请分享';

  @override
  String customAddedToRoom(String name) {
    return '已将“$name”添加到房间';
  }

  @override
  String customAddToRoomFailed(String error) {
    return '无法添加：$error';
  }

  @override
  String customShareProposedToRoom(String name) {
    return '已在房间中提议“$name”';
  }

  @override
  String get customSharePlacedOnProfile => '已放到个人资料';

  @override
  String customPlaceFailed(String error) {
    return '无法放置：$error';
  }

  @override
  String customInvitedBySwingNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '已通过 Swing 邀请(已通过 RASQ 通知 $_temp0)';
  }

  @override
  String get customInvitedBySwing => '已通过 Swing 邀请';

  @override
  String get customInviteTitle => '通过 Swing 邀请';

  @override
  String customInviteSendFailed(String error) {
    return '无法发送：$error';
  }

  @override
  String customInviteHeading(String title) {
    return '邀请加入“$title”';
  }

  @override
  String get customInviteIntroOwnPage => '通过 Swing 送达。看到的人会一起进入你的页面。';

  @override
  String get customInviteIntroCurrentPage => '通过 Swing 送达。看到的人会一起进入当前打开的页面。';

  @override
  String get customInviteHelp =>
      '发送对象：点按 = 送达 Swing · 连续点按两次 = 同时发送 RASQ 通知 🔔';

  @override
  String get customInviteFollowers => '关注者';

  @override
  String get customInviteNoLists => '创建 RASQ 列表后，也可以邀请列表中的人';

  @override
  String get customInviteTextHint => '附言（可选）';

  @override
  String get customInviteTtl => '消失时间';

  @override
  String customInviteTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小时',
    );
    return '$_temp0';
  }

  @override
  String get customInviteSendWithNotify => '通过 Swing 邀请（同时发送通知）';

  @override
  String get customInviteErrorVersionNotAvailable =>
      '当前连接的 RASQ 服务器商店未发布此插件（没有通过审核的版本）。应用内置的示例无法多人共用';

  @override
  String get customInviteErrorNotShared => '这不是多人共用的插件';

  @override
  String get customInviteErrorSessionNotShareable => '此页面的会话无法通过 Swing 邀请';

  @override
  String get customInviteErrorSwingLimit => '同时最多只能发出 20 个 Swing';

  @override
  String customInviteTargetWithNotify(String label) {
    return '$label（同时发送通知）';
  }

  @override
  String get customInviteTargetHint => '点按以选择 / 取消。连续点按两次会同时发送通知';

  @override
  String get customProfileLimit => '页面最多可放置 8 个';

  @override
  String get customProfileSideloadReplace => '重新上传（新版本）';

  @override
  String get customProfileSideloadRemove => '从页面移除';

  @override
  String customProfileRemoveFailed(String error) {
    return '无法移除：$error';
  }

  @override
  String customLoadFailed(String error) {
    return '无法加载：$error';
  }

  @override
  String get customProfileEmptyMine =>
      '点按“+ 添加”可放置 Markdown 页面或自定义插件。访客可以从这里打开。';

  @override
  String get customProfileEmpty => '还没有页面。';

  @override
  String get customProfileSharedNotStarted => '多人共用（尚未开始）';

  @override
  String get customProfileShared => '多人共用';

  @override
  String get customSolo => '单人使用';

  @override
  String customProfileHostPage(String title) {
    return '$title 的主持人页面';
  }

  @override
  String get customProfileHostPageSubtitle => '仅对你显示';

  @override
  String get customProfileMdPageWithDraft => '页面 · 有未完成的草稿';

  @override
  String get customProfileMdPage => '页面';

  @override
  String get customProfileUntitled => '（无标题）';

  @override
  String get customProfileDraft => '草稿（仅限此设备）';

  @override
  String customProfileSideloadSubtitle(String version) {
    return '自制插件 · 受限模式 · v$version';
  }

  @override
  String get customMenu => '菜单';

  @override
  String get customProfileAdd => '添加';

  @override
  String get customProfileLoginToPlace => '登录 RASQ 账号后即可放置';

  @override
  String customProfileSideloadPlaced(String name) {
    return '已放置“$name”（在访客的设备上以受限模式运行）';
  }

  @override
  String get customProfileSideloadErrorNotProfilePage =>
      'RASQ 页面上只能放置具有个人资料界面的单人使用页面型插件';

  @override
  String get customProfileSideloadErrorLimit => '自制插件最多 4 个';

  @override
  String get customProfileSideloadErrorInvalidPackage =>
      '无法读取安装包（.rspkg / .rasqpkg）';

  @override
  String get customClose => '关闭';

  @override
  String get customProfileAddTitle => '添加页面';

  @override
  String get customProfileAddMd => '撰写 Markdown 页面';

  @override
  String get customProfileAddMdSubtitle =>
      '草稿保存在此设备上，点按“发布”后公开。MFM 使用类似 HTML 的标签';

  @override
  String get customProfileAddSideload => '放置自制插件（.rspkg / .rasqpkg）';

  @override
  String get customProfileAddSideloadSubtitle =>
      '未经审核的插件。在访客的设备上以受限模式（无网络通信等）运行';

  @override
  String get customProfileAddStoreSection => '商店中的自定义插件';

  @override
  String get customProfileAddStoreEmpty => '尚未安装可放到页面上的自定义插件';

  @override
  String get customProfileAddStorePlaced => '已放置（点按以移除）';

  @override
  String get customProfileAddStoreTapToPlace => '点按以放置';

  @override
  String get customProfileAddStoreHasHostPage => '有主持人页面';

  @override
  String get customListSeparator => ' · ';

  @override
  String customProfileChangeFailed(String error) {
    return '无法更改：$error';
  }

  @override
  String get customSearchStore => '在商店中查找';

  @override
  String get customPluginsTitle => '自定义插件';

  @override
  String get customPluginsJoinByCode => '使用邀请码加入';

  @override
  String get customPluginsInviteCode => '邀请码';

  @override
  String get customPluginsJoin => '加入';

  @override
  String get customPluginsInstalled => '已安装';

  @override
  String get customPluginsEmpty => '还没有。可以在商店的“自定义”中查找。';

  @override
  String get customPluginsShared => '可多人共用';

  @override
  String get customPluginsProfile => '个人资料';

  @override
  String get customPluginsSearchStore => '在商店中查找自定义插件';

  @override
  String get customPluginsInviteNotFound => '找不到此邀请码对应的会话（可能已被关闭）';

  @override
  String get customPluginsInviteTitle => '邀请';

  @override
  String get customPluginsJoinFailed => '无法加入';

  @override
  String get customPageLoadFailed => '无法加载';

  @override
  String customPageNotPagePlugin(String name) {
    return '$name 不是页面型插件';
  }

  @override
  String customPageSoloPlugin(String name) {
    return '$name 是单人使用的插件（无法多人共用）';
  }

  @override
  String customPageJoinFailed(String error) {
    return '无法加入会话：$error';
  }

  @override
  String get customPageNoPage => '插件没有返回页面';

  @override
  String customPageWrongSession(String name) {
    return '这不是 $name 的会话';
  }

  @override
  String customPageLeftWrongSession(String name) {
    return '由于这不是 $name 的会话，已退出';
  }

  @override
  String customPageDisconnectedWithError(String error) {
    return '连接已断开：$error';
  }

  @override
  String get customPageDisconnected => '连接已断开';

  @override
  String get customPageError => '错误';

  @override
  String get customPageMenuInvite => '邀请（通过 Swing 发送）';

  @override
  String get customPageMenuCopyCode => '复制邀请码';

  @override
  String get customPageMenuCopyLink => '复制邀请链接';

  @override
  String customPageMenuParticipants(int count) {
    return '参与者（$count）';
  }

  @override
  String get customPageMenuCloseSession => '关闭会话';

  @override
  String get customPageViewInStore => '在商店中查看';

  @override
  String customPageCodeCopied(String code) {
    return '已复制邀请码 $code';
  }

  @override
  String get customPageLinkCopied => '已复制邀请链接';

  @override
  String get customPageParticipants => '参与者';

  @override
  String get customPageCloseConfirmTitle => '要关闭会话吗？';

  @override
  String get customPageCloseConfirmMessage => '所有参与者页面上的共享值都将停止更新。';

  @override
  String get customCancel => '取消';

  @override
  String customPageCloseFailed(String error) {
    return '无法关闭：$error';
  }

  @override
  String get customPageClosedBanner => '此会话已关闭（共享值不会再变化）';

  @override
  String get customPageConsentBody => '无需安装，仅在打开此页面期间运行（关闭后即删除）。';

  @override
  String get customPageConsentPermissions => '使用的权限';

  @override
  String get customPageConsentAccept => '使用';

  @override
  String get customPageConsentDecline => '不用了';

  @override
  String get customPageNotInstalled => '未安装';

  @override
  String get customPageNotInstalledHint => '从商店安装后即可打开';

  @override
  String get customPageOpenFailed => '无法打开';

  @override
  String get customClientHostOnly => '只有主持人可以部署';

  @override
  String get customClientSessionClosed => '会话已关闭';

  @override
  String get customClientNoToken => '没有 RASQ 账号的令牌';

  @override
  String customAstellWaitingApproval(String name) {
    return '“$name”正在等待主持人批准';
  }

  @override
  String customAstellApproveTitle(String name) {
    return '要在此房间中使用“$name”吗？';
  }

  @override
  String customAstellApproveMessage(String name) {
    return '这是 $name 的提议。批准后，房间内的所有人都可以打开（未安装的人会在打开时临时加载）。';
  }

  @override
  String get customAstellApprove => '批准';

  @override
  String customAstellProposed(String name) {
    return '已提议“$name”（主持人批准后即可使用）';
  }

  @override
  String get customAstellEmptyHost => '此房间中还没有运行的插件。可以通过下方的“添加插件”添加。';

  @override
  String get customAstellEmptyMember => '此房间中还没有运行的插件。可以通过“提议插件”请求主持人添加。';

  @override
  String customAstellInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人正在使用',
    );
    return '$_temp0';
  }

  @override
  String customAstellInUseAddedBy(int count, String handle) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人正在使用',
    );
    return '$_temp0 · 由 @$handle 添加';
  }

  @override
  String get customAstellOpen => '打开';

  @override
  String get customAstellRemove => '从房间移除';

  @override
  String get customAstellAdd => '添加插件';

  @override
  String get customAstellPropose => '提议插件';

  @override
  String get devGrantDebugAll => '调试版本：全部权限';

  @override
  String get devUrlInvalid => '请输入 http(s) 的 URL';

  @override
  String devUrlLoadFailed(String error) {
    return '无法从 URL 读取：$error';
  }

  @override
  String devBoundaryTimelineFailed(String error) {
    return '边界 TL：$error';
  }

  @override
  String devAssetLoadFailed(String error) {
    return '加载资源失败：$error';
  }

  @override
  String devPkgLoaded(
    String rootId,
    String version,
    int children,
    String target,
  ) {
    return '.rasqpkg：已加载 $rootId $version（子 $children）→ $target。';
  }

  @override
  String devPkgSigned(String fingerprint) {
    return '开发者密钥签名 OK（指纹 $fingerprint）。未通过商店审核。';
  }

  @override
  String get devPkgUnsigned => '未签名（没有 .sig.json）。无法确认来源。';

  @override
  String get devPkgSlotFull => '注册到插槽后为完整功能（由自己的密钥签名）';

  @override
  String get devPkgSlotRestricted =>
      '注册到插槽后为受限模式（非自己的密钥签名，因此网络 / GPU / storage.unsafe / interstitial·system 的 FOW / 分享·编辑器·静音·打开 URL 的函数均关闭）';

  @override
  String devPathLoadFailed(String path, String error) {
    return '加载 $path 失败（请使用绝对路径或以 ~/ 开头的路径）：$error';
  }

  @override
  String get devFowClose => '关闭';

  @override
  String get devFowSemantics => '插件 FOW';

  @override
  String get devRegisterNeedsMisskey => '实际注册需要使用 Misskey 账号登录';

  @override
  String get devTitle => 'WASM 插件测试（dev）';

  @override
  String get devHostHint => '实例（例：misskey.io）';

  @override
  String get devFetchTimeline => '获取 TL';

  @override
  String get devBoundaryTimeline => '边界 TL';

  @override
  String get devPathHint => '从 .wasm 路径导入（留空 = 内置资源）';

  @override
  String get devLoad => '加载';

  @override
  String get devRegisterReal => '实际注册';

  @override
  String get devUrlHint => '从 URL 读取（审核的临时导入链接）';

  @override
  String get devUrlLoad => '从 URL 读取';

  @override
  String get devOpenedFromLink => '已从链接打开。请确认来源后再点“从 URL 读取”（审核中的版本将以受限模式运行）。';

  @override
  String devParentInstalled(String id, String version) {
    return '父（基础）插件：$id $version（已安装）';
  }

  @override
  String devParentMissing(String id, String version) {
    return '父（基础）插件：$id $version — 请先安装';
  }

  @override
  String get devOpenInStore => '在商店中打开';

  @override
  String devGrantDebugNote(String grant, String hint) {
    return '$grant（release 版本按等级限制：$hint）';
  }

  @override
  String devGrantMode(String mode, String hint) {
    return '此画面：$mode — $hint';
  }

  @override
  String get devModeFull => '完整功能';

  @override
  String get devModeBundled => '完整功能（应用内置）';

  @override
  String get devModeRestricted => '受限模式';

  @override
  String get devModeSwing => '受限模式（Swing）';

  @override
  String get devSlotRegister => '注册到插槽';

  @override
  String devSlotRegistered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已注册：$count',
    );
    return '$_temp0';
  }

  @override
  String devSlotModeHint(String hint) {
    return '插槽等级：完整 / 受限 — $hint';
  }

  @override
  String get devSlotReviewed => '已审核';

  @override
  String get devSlotUnregister => '解除';

  @override
  String get devBoundaryHeader => '边界会话：sns.timeline → Post 线 → PostRow';

  @override
  String get devBoundaryClose => '关闭';

  @override
  String devActionFailed(String action, String error) {
    return 'performAction($action) 失败：$error';
  }

  @override
  String devReviewImportTooLarge(int maxBytes) {
    return '大小无效（超过 $maxBytes 字节）';
  }

  @override
  String get devReviewImportExpired => '链接已过期或不正确。请在审核画面重新创建';

  @override
  String devReviewImportHttpFailed(int status) {
    return '获取失败（HTTP $status）';
  }

  @override
  String devReviewImportBadSize(int bytes) {
    return '大小无效（$bytes 字节）';
  }

  @override
  String get dmRoomSettings => '此私信的设置';

  @override
  String get dmRetry => '重新加载';

  @override
  String get dmRoomEmpty => '还没有消息';

  @override
  String get dmTabAll => '全部';

  @override
  String get dmTabFollowing => '关注中';

  @override
  String get dmSettings => '私信设置';

  @override
  String get dmFollowingEmpty => '没有与关注对象的私信';

  @override
  String get dmNewMessage => '新消息';

  @override
  String get dmUserSearchHint => '按用户名搜索..';

  @override
  String get dmUserSearchIntro => '搜索要发送私信的对象。';

  @override
  String get dmUserNotFound => '未找到';

  @override
  String get dmEmptyTitle => '没有私信';

  @override
  String get dmEmptyHint => '私信帖子（限定公开）会显示在这里';

  @override
  String get dmYouPrefix => '你：';

  @override
  String get dmMediaPlaceholder => '[媒体]';

  @override
  String get homeCreateMissingAccount => '（不存在的账号）';

  @override
  String get homeCreatePost => '帖子';

  @override
  String get homeCreateNone => '无';

  @override
  String homeCreateNeedsRasqAccount(String label) {
    return '$label需要 RASQ 账号';
  }

  @override
  String get homeCreateAstellBlocked => 'ASTell 已被监护设置禁用';

  @override
  String get homeCreateAccountGone => '此账号已不存在';

  @override
  String get homeCreate => '创建';

  @override
  String get homeClose => '关闭';

  @override
  String get homeFabEditorTitle => '＋ 按钮';

  @override
  String homeFabEditorHelp(int count, int max) {
    return '将下方的按钮拖入框中即可添加（框之间可互换，拖回下方一行即可移除）。内侧最多 3 个，外侧最多 4 个 · $count / $max';
  }

  @override
  String get homeHeaderCollapse => '收起页眉';

  @override
  String get homeTimelineTemp => '临时更改时间线';

  @override
  String get homeTimelineSettings => '时间线设置';

  @override
  String get homeTabRecommended => '推荐';

  @override
  String get homeEmpty => '没有帖子';

  @override
  String get homePullToRefresh => '下拉刷新';

  @override
  String get homeLoadNewer => '加载新帖子';

  @override
  String get homeNewPostsPill => '新帖子';

  @override
  String get homeNewPostsPillSemantics => '查看新帖子';

  @override
  String get homeLoadingNewer => '正在刷新…';

  @override
  String get homeLoadMoreFailed => '加载失败。重试';

  @override
  String get homeLoadMore => '加载更多';

  @override
  String get homeLoadingMore => '正在加载…';

  @override
  String get homeReload => '重新加载';

  @override
  String homeSwingOf(String name) {
    return '$name 的 Swing';
  }

  @override
  String homeSwingOfSeen(String name) {
    return '$name 的 Swing（已看完）';
  }

  @override
  String homeMySwingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个',
    );
    return '我的 Swing（$_temp0）';
  }

  @override
  String get homeMySwing => '我的 Swing';

  @override
  String get homeLiveNoToken => '没有 RASQ 账号的令牌';

  @override
  String homePostAttachmentFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个附件',
    );
    return '$_temp0';
  }

  @override
  String get homePostAttachmentLink => '1 个附加链接';

  @override
  String get homePostShare => '分享';

  @override
  String get homePostSelectAccount => '选择账号';

  @override
  String get homePostLike => '赞';

  @override
  String get homePostReaction => '回应';

  @override
  String homePostRepostVia(String handle, String instance) {
    return '（使用 @$handle@$instance）';
  }

  @override
  String get homePostUndoRepost => '取消转帖';

  @override
  String homePostCw(String cw) {
    return '【CW：$cw】';
  }

  @override
  String homePostAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个附件',
    );
    return '$_temp0';
  }

  @override
  String get homeActionReply => '回复';

  @override
  String get homeActionRebroad => '转播';

  @override
  String get homeActionQueue => '队列';

  @override
  String get homeEditorCropRotate => '裁剪 / 旋转';

  @override
  String get homeEditorPaint => '绘画';

  @override
  String get homeEditorText => '文本';

  @override
  String get homeEditorPost => '帖子';

  @override
  String get homeEditorMedia => '媒体';

  @override
  String get homeEditorSticker => '贴纸';

  @override
  String get homeEditorEmoji => '表情';

  @override
  String get homeEditorFilter => '滤镜';

  @override
  String get homeEditorBlur => '模糊';

  @override
  String get homeEditorTune => '调整';

  @override
  String get homeActionAutoOn => '下次也自动开启';

  @override
  String get homeActionAutoOff => '以后也自动关闭';

  @override
  String get homeActionAutoReset => '恢复为插件默认';

  @override
  String get homeChildSafeWindowTab => '监护时段';

  @override
  String get homeCancel => '取消';

  @override
  String get homeBarPost => '帖子操作栏';

  @override
  String get homeBarViewer => '全屏操作栏';

  @override
  String get homeBarEditorImage => '编辑界面栏（图片）';

  @override
  String get homeBarEditorVideo => '编辑界面栏（视频 / 音频）';

  @override
  String get homeBarEditorSvg => '编辑界面栏（SVG）';

  @override
  String get homeBarRasqViewer => '全屏操作栏（Swing）';

  @override
  String get homeBarAstell => 'ASTell 房间下排';

  @override
  String get homeBarEditAstellTitle => '编辑房间按钮';

  @override
  String get homeBarEditTitle => '编辑操作栏';

  @override
  String get homeBarSearchPlugins => '搜索插件';

  @override
  String get homeBarSearchPluginButtons => '搜索插件按钮';

  @override
  String homeBarSearchSubtitle(String source, String detail) {
    return '$source · $detail';
  }

  @override
  String get homeBarBuiltinEditor => '内置编辑';

  @override
  String get homeBarRasqActions => 'RASQ 操作';

  @override
  String get homeBarAstellButtons => 'ASTell 按钮';

  @override
  String get homeBarSnsActions => 'SNS 操作';

  @override
  String get homeBarViewerTogglePlugin => '全屏显示插件（ON / OFF 按钮）';

  @override
  String get homeBarAstellPlugin => 'ASTell 插件（点击打开该插件）';

  @override
  String homeBarPluginTags(String tags) {
    return '标签：$tags';
  }

  @override
  String get homeBarManualPlacement => ' · 手动放置';

  @override
  String get homeBarAllGenres => '全部';

  @override
  String get homeBarSearchHint => '按钮名 / 插件名 / 标签';

  @override
  String get homeBarSearchEmptyAstell => '没有可添加的按钮。可以从商店添加插件';

  @override
  String get homeBarSearchEmpty => '没有可放在这里的插件。可以从商店添加';

  @override
  String get homeBarSearchEmptyEditorDetail => '没有声明 composer.media 的插件（从商店添加）';

  @override
  String get homeBarSearchEmptyAstellDetail =>
      '没有隐藏的按钮 / ASTell 插件（astell.action）（从商店添加插件）';

  @override
  String get homeBarSearchEmptyViewerDetail =>
      '没有全屏显示插件 / 声明 post.action 的插件（从商店添加）';

  @override
  String get homeBarSearchEmptyPostDetail => '没有声明 post.action 的插件（从商店添加）';

  @override
  String get homeBarSearchNoHits => '未找到';

  @override
  String get homeBarDetailTitle => '操作详情';

  @override
  String get homeBarDetailUnknownDeveloper => '提供者不明';

  @override
  String homeBarDetailStats(String rating, int downloads) {
    return '★$rating · $downloads 次下载';
  }

  @override
  String get homeBarDetailAction => '操作';

  @override
  String get homeBarDetailSlot => '插槽（类型）';

  @override
  String get homeBarDetailConfirm => '确认';

  @override
  String get homeBarDetailAutomation => '自动化';

  @override
  String get homeBarDetailTags => '标签';

  @override
  String get homeBarIconSearchHint => '按图标名称搜索（例：star, bolt）';

  @override
  String get homeBarBundleTitle => '组合设置';

  @override
  String get homeBarBundleDissolved => '已解除';

  @override
  String get homeBarPlugin => '插件';

  @override
  String homeBarBundleAstellMember(String label) {
    return '房间下排按钮（$label）';
  }

  @override
  String homeBarBundleSnsMember(String genre) {
    return 'SNS 插件提供的操作（$genre）';
  }

  @override
  String get homeBarBundleName => '列表名称';

  @override
  String get homeBarBundleIcon => '图标';

  @override
  String get homeBarBundlePhoto => '照片';

  @override
  String get homeBarBundlePhotoFailed => '无法使用照片';

  @override
  String get homeBarBundleMembers => '成员';

  @override
  String get homeBarMenuDetail => '详情';

  @override
  String get homeBarBundleRemoveMember => '从组合中移除';

  @override
  String get homeBarDissolveList => '解除列表';

  @override
  String get homeBarMemberMenu => '成员操作';

  @override
  String get homeBarRasqAccount => 'RASQ 账号';

  @override
  String get homeBarHelpAstell => '点 (…) 或右键打开菜单。长按可排序，叠到其他图标上即可合并。点 (+) 添加按钮。';

  @override
  String get homeBarHelp => '点 (…) 或右键打开菜单。长按可排序，叠到其他图标上即可合并。';

  @override
  String get homeBarHelpAstellDetail =>
      '(…) / shift + 点击 / 右键打开菜单（隐藏 / 组合）。长按拖动可排序，在其他图标上松开即可组合。(+) 可添加隐藏的按钮或 ASTell 插件。宽度不够时，从开头显示能放下的部分和最后一个（输入框旁），其余放入房间的齿轮菜单。';

  @override
  String get homeBarHelpDetail =>
      '(…) / shift + 点击 / 右键打开菜单。长按拖动可排序，在其他图标上松开即可组合。已声明的插件按钮和组合阈值在 设置 → SNS 插件 →“插件按钮”。';

  @override
  String get homeBarRasqBuiltinEditor => 'RASQ（内置编辑）';

  @override
  String get homeBarNewBundleName => '我的列表';

  @override
  String get homeBarMenuMakeList => '转为操作列表';

  @override
  String get homeBarMenuHide => '隐藏';

  @override
  String get homeBarMenuDelete => '删除';

  @override
  String get homeBarMenuListSettings => '操作列表设置';

  @override
  String get homeBarMenuPinList => '设为固定列表';

  @override
  String get homeBarAddButton => '添加按钮';

  @override
  String get homeBarNoHidden => '没有隐藏的按钮';

  @override
  String get homeBarHiddenLabel => '已隐藏（点击显示）：';

  @override
  String homeBarShowHidden(String label) {
    return '显示 $label';
  }

  @override
  String get homeBarResetOrder => '恢复默认排列';

  @override
  String get languageSelfName => '简体中文';

  @override
  String get languageSettingsTitle => '语言';

  @override
  String get languageSettingsRowSubtitle => '应用的显示语言';

  @override
  String get languageSettingsCaption => '选择应用文字的语言。若不支持设备的语言，将以日语显示。';

  @override
  String get languageSettingsCaptionDetail =>
      '选择应用文字的语言。“跟随系统”将按照设备的语言设置，不支持的语言将使用日语。所选语言保存在此设备上，若已登录 RASQ 账号，也会告知 ORGATE（邮件和通知的语言，D-484）。';

  @override
  String get languageSettingsSystem => '跟随系统';

  @override
  String languageSettingsSystemCurrent(String language) {
    return '当前为 $language';
  }

  @override
  String get languageSettingsListHeader => '显示语言';

  @override
  String get listsTitle => '列表';

  @override
  String get listsTabAllLabel => '全部';

  @override
  String get listsSearchHint => '搜索列表和便签';

  @override
  String get listsShowPrivateClips => '显示非公开便签';

  @override
  String get listsImportTitle => '导入列表';

  @override
  String get listsCreateTitle => '创建列表';

  @override
  String listsCreateAccountList(String account) {
    return '$account 的列表';
  }

  @override
  String get listsRasqCrossSns => 'RASQ 列表（跨 SNS）';

  @override
  String get listsCreateConfirm => '创建';

  @override
  String get listsNameHint => '列表名称';

  @override
  String listsCreated(String name) {
    return '已创建“$name”';
  }

  @override
  String listsCreateUnsupported(String sns) {
    return '无法在 $sns 上创建列表';
  }

  @override
  String listsCreateFailed(String error) {
    return '无法创建列表：$error';
  }

  @override
  String get listsEmpty => '没有列表';

  @override
  String get listsNoHits => '未找到';

  @override
  String get listsEmptyHint => '点击 ＋ 可创建列表';

  @override
  String get listsRasqCreateTitle => '新建 RASQ 列表';

  @override
  String get listsRasqCreateSubtitle =>
      '将 Misskey / Mastodon / Bluesky 的人放进一个列表';

  @override
  String listsSwitchedAccount(String account) {
    return '已切换到 $account';
  }

  @override
  String get listsSectionClips => '便签';

  @override
  String get listsSectionLists => '列表';

  @override
  String get listsSectionFeeds => '自定义动态源';

  @override
  String listsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位用户',
    );
    return '$_temp0';
  }

  @override
  String listsClipNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String get listsClipKindHost => 'RASQ（跨 SNS）';

  @override
  String get listsClipKindPrivate => '非公开便签';

  @override
  String get listsClipKindPublic => '便签';

  @override
  String get listsSeparator => ' · ';

  @override
  String get listsFeedUnsave => '取消保存';

  @override
  String get listsFeedSave => '保存动态源';

  @override
  String get listsFeedUnsaveFailed => '无法取消保存';

  @override
  String get listsFeedSaveFailed => '无法保存';

  @override
  String get listsFeedSaveUnsupported => '此 SNS 不支持保存动态源';

  @override
  String get listsNotLoggedIn => '未登录';

  @override
  String listsFeedAlreadyImported(String name) {
    return '“$name”已在首页时间线中';
  }

  @override
  String listsFeedImported(String name) {
    return '已将“$name”导入首页时间线（可通过标签栏的齿轮确认）';
  }

  @override
  String get listsTabUsers => '用户';

  @override
  String get listsTabPosts => '帖子';

  @override
  String get listsTabTopics => '话题目录';

  @override
  String get listsBlockedByGuardian => '监护人已屏蔽此列表';

  @override
  String get listsTimelineSettingsTooltip => '列表时间线设置';

  @override
  String get listsAddMembers => '添加成员';

  @override
  String listsMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已添加 $count 人',
    );
    return '$_temp0';
  }

  @override
  String get listsNoUsers => '没有用户';

  @override
  String get listsRemoveMember => '移除';

  @override
  String get listsReload => '重新加载';

  @override
  String get listsNoPosts => '没有帖子';

  @override
  String get listsFeedDefaultTitle => '动态源';

  @override
  String get listsImportToTimeline => '导入时间线';

  @override
  String get listsFeedTimelineSettingsTooltip => '动态源时间线设置';

  @override
  String get listsImportSearchHintFeeds => '搜索自定义动态源，或输入分享链接 / URL';

  @override
  String get listsImportSearchHintRasq => '搜索 RASQ 列表，或输入分享链接 / URL';

  @override
  String get listsImportSearchHintBoth => '搜索自定义动态源 / RASQ 列表，或输入分享链接 / URL';

  @override
  String get listsImportSearchPlain => '搜索';

  @override
  String get listsImportFeedsHelp => '搜索动态源或粘贴 URL，将以列表卡片显示。点按即可进入该动态源的时间线。';

  @override
  String get listsImportRasqHelp =>
      'RASQ 列表可通过“导入”加入首页时间线（将关注该列表）。只能导入可以获取列表成员信息的列表。';

  @override
  String get listsImportGenericHelp => '可以搜索列表并进行批量操作。';

  @override
  String get listsImportLocal => '从本地导入';

  @override
  String get listsImportLocalMessage => '从文件导入正在准备中。';

  @override
  String get listsImportLocalDetail => '从 CSV/JSON 导入将与列表功能（服务器端）一同实现。';

  @override
  String get listsImportPopularFeeds => '热门动态源';

  @override
  String get listsImportFeedResults => '动态源搜索结果';

  @override
  String get listsImportEnterQuery => '请输入搜索词或 URL';

  @override
  String get listsImportRasqMine => 'RASQ 列表（自己的 / 关注中）';

  @override
  String get listsImportRasqResults => 'RASQ 列表搜索结果';

  @override
  String get listsImportButton => '导入';

  @override
  String get listsImportHistory => '历史记录';

  @override
  String get listsImportHistoryEmpty => '没有历史记录';

  @override
  String get listsTopicsEmpty => '暂无话题';

  @override
  String get listsTopicsEmptyHint => '帖子积累后会按话题划分';

  @override
  String get listsTopicsCaption => '按话题划分。点按后只显示该话题的帖子。';

  @override
  String get listsTopicsCaptionDetail =>
      '将会话事件（2 条以上帖子，与关系型 TL 使用相同引擎）作为章节，单独的帖子合并为一个（indexForListTimeline）。标题为帖子中的词语（标签 / 特征词 / 域名）。';

  @override
  String listsTopicTimeRange(String start, String end) {
    return '$start～$end';
  }

  @override
  String listsTopicSubtitle(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$time · $_temp0';
  }

  @override
  String listsTopicSubtitleWithPeople(String time, int count, int people) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    String _temp1 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people 人',
    );
    return '$time · $_temp0 · $_temp1';
  }

  @override
  String listsTopicSnippet(String name, String body) {
    return '$name“$body”';
  }

  @override
  String listsTopicFilterChip(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '话题：$label（$_temp0）';
  }

  @override
  String get listsTopicFilterClear => '取消筛选';

  @override
  String listsMemberCandidateSubtitle(String handle, String instance) {
    return '@$handle · $instance';
  }

  @override
  String listsMemberNotPublished(String name) {
    return '$name 未公开此 SNS 的账号';
  }

  @override
  String listsMemberSnsNotFound(String name) {
    return '找不到 $name 的 SNS 账号';
  }

  @override
  String get listsPickerConfirm => '添加';

  @override
  String get listsPickerNoServer => '未连接到 RASQ 服务器';

  @override
  String get listsPickerLookupFailed => '无法查询';

  @override
  String get listsPickerUnavailable => '无法选择';

  @override
  String get listsPickerNone => '没有人';

  @override
  String get listsPickerSearchHint => '搜索用户（SNS / RASQ）';

  @override
  String get listsPickerSnsUsers => 'SNS 用户';

  @override
  String get listsPickerRasqUsers => 'RASQ 用户';

  @override
  String get listsPickerSnsFollowing => 'SNS 上关注的人';

  @override
  String get listsPickerRasqFollowing => 'RASQ 上关注的人';

  @override
  String get listsPickerRasqNotice => 'RASQ 用户将通过其公开的同一 SNS 账号添加。';

  @override
  String listsPickerRasqNoticeDetail(String path) {
    return '从 Central 公开页面（$path）的 snsAccounts 中选择与此会话相同的 SNS（优先相同服务器、优先已验证），并添加通过 userByHandle 查到的 id。';
  }

  @override
  String listsPickerSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择 $count 人',
    );
    return '$_temp0';
  }

  @override
  String get listsPickerRasqBadgeSemantics => 'RASQ 用户';

  @override
  String get loginBack => '返回';

  @override
  String get loginTitle => '登录社交网络';

  @override
  String get loginPluginLoadNote => '首次登录前会加载插件。请在网络良好的环境下进行。';

  @override
  String get loginChildSafeBlocked => '监护人已禁止添加 SNS 账号';

  @override
  String get loginShareDeviceOnly => '已通过邮件批准此设备。请使用下方按钮在此设备上登录 SNS 账号';

  @override
  String get loginWithBluesky => '使用 Bluesky 登录';

  @override
  String get loginWithMisskey => '使用 Misskey 登录';

  @override
  String get loginWithMixi2 => '使用 mixi2 登录';

  @override
  String get loginWithMastodon => '使用 Mastodon 登录';

  @override
  String get loginDiscover => '查找服务并登录';

  @override
  String get loginRaiInstruction => 'RAi 指引';

  @override
  String get loginShareMailUnavailable => '暂时无法发送';

  @override
  String loginShareMailSent(String to) {
    return '已向 $to 发送批准链接（30 分钟内有效）。请在浏览器中打开，登录 RASQ 账号后进行批准';
  }

  @override
  String get loginShareMailSentVerified =>
      '已向已验证的邮箱地址发送批准链接（30 分钟内有效）。请在浏览器中打开，登录 RASQ 账号后进行批准';

  @override
  String get loginShareMailNoVerified => '没有已验证的邮箱地址。请在原设备上批准，或在此设备上登录 SNS 账号';

  @override
  String get loginShareMailTooMany => '发送次数过多。请稍后再试';

  @override
  String get loginShareMailNotSupported => '此服务器不支持通过邮件批准';

  @override
  String loginShareMailFailed(String code) {
    return '发送失败（$code）';
  }

  @override
  String get loginShareWaiting =>
      '在原设备上批准共享后，将一次性登录所有 SNS 账号。也可以通过发送到已验证邮箱的链接进行批准';

  @override
  String get loginShareMailButton => '通过邮件批准（发送链接）';

  @override
  String get loginBundleTitleThis => '此 RASQ 账号的 SNS 账号';

  @override
  String loginBundleTitle(String handle) {
    return '@$handle 的 SNS 账号';
  }

  @override
  String get loginBundleHint => '尚未在此设备上登录。点按即可登录。';

  @override
  String get loginBundleUse => '使用';

  @override
  String get loginBundleLogin => '登录';

  @override
  String get loginTermsTitle => '插件条款';

  @override
  String get loginTermsAgree => '同意';

  @override
  String loginTermsBullet(String text) {
    return '• $text';
  }

  @override
  String loginSignupDivider(String service) {
    return '没有 $service 账号';
  }

  @override
  String get loginSignupButton => '注册';

  @override
  String get loginSignupReopen => '再次打开注册页面';

  @override
  String loginBrowserOpenFailed(String url) {
    return '无法打开浏览器。URL: $url';
  }

  @override
  String get loginPluginMissingMixi2 => '找不到 mixi2 插件';

  @override
  String loginMixi2BrowserPending(String url) {
    return '请在浏览器中授权后返回应用：$url';
  }

  @override
  String loginFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String get loginMixi2HostHint => '主机（例：mixi.social）';

  @override
  String get loginMixi2Note =>
      'mixi2 官方 API 需申请使用，登录将通过 RASQ 的服务器进行。在准备就绪前无法使用“在浏览器中认证”。';

  @override
  String get loginMixi2Browser => '在浏览器中认证';

  @override
  String get loginMixi2Dummy => '使用测试账号试用';

  @override
  String get loginMixi2DummyNote =>
      '测试账号不使用网络，可以用插件内置的帖子确认时间线 / 点赞 / 转发 / 发帖 / 通知的流程。';

  @override
  String get loginMixi2SignupHint =>
      '请在浏览器（或 mixi2 应用）中创建 mixi2 账号。创建后，返回此页面并通过“在浏览器中认证”登录。';

  @override
  String get loginPluginMissingBluesky => '找不到 Bluesky 插件';

  @override
  String get loginBlueskyHostHint => 'PDS（例：bsky.social）';

  @override
  String get loginBlueskyIdHint => '用户名（例：you.bsky.social）或邮箱';

  @override
  String get loginBlueskyPasswordHint => '应用密码';

  @override
  String get loginPasswordHide => '隐藏';

  @override
  String get loginPasswordShow => '显示';

  @override
  String get loginBlueskyPasswordNote =>
      '请使用在 Bluesky 的“设置 → 隐私与安全 → 应用密码”中创建的密码。请勿输入主密码。';

  @override
  String get loginButton => '登录';

  @override
  String get loginBlueskySignupHint =>
      '请在浏览器中的 Bluesky 通过“创建账号”注册。注册后，在 Bluesky 的“设置 → 隐私与安全 → 应用密码”中创建密码，然后用上方的用户名和应用密码登录。';

  @override
  String get loginServerUnreachable => '无法连接到服务器';

  @override
  String loginServerUnreachableWithError(String error) {
    return '无法连接到服务器：$error';
  }

  @override
  String loginAuthStartFailed(String error) {
    return '无法开始认证：$error';
  }

  @override
  String loginAuthCheckFailed(String error) {
    return '认证确认失败：$error';
  }

  @override
  String get loginSnsTitle => '更改 PDS';

  @override
  String get loginSnsNote => '更改 PDS 后，应用外显示的 URL 会改变。';

  @override
  String loginSnsHostHint(String example) {
    return '输入目标 URL（例：$example）';
  }

  @override
  String get loginSnsSearch => '搜索服务器';

  @override
  String get loginSnsServerSection => '服务器搜索';

  @override
  String loginSnsMaintainer(String name) {
    return '管理员：$name';
  }

  @override
  String get loginSnsRegistrationClosed => '暂停注册';

  @override
  String get loginSnsAuthCheck => '确认认证';

  @override
  String get loginSnsReopenBrowser => '再次打开浏览器';

  @override
  String get loginMisskeyAuthButton => '在浏览器中认证 (MiAuth)';

  @override
  String get loginMastodonAuthButton => '在浏览器中认证 (OAuth)';

  @override
  String get loginMastodonHostHint => '输入实例 URL（例：mastodon.social）';

  @override
  String get mediaVizStyleMirror => '上下对称条形';

  @override
  String get mediaVizStyleBars => '自下而上的条形';

  @override
  String get mediaVizStyleLine => '折线';

  @override
  String get mediaVizLeftAvatar => '账号头像';

  @override
  String get mediaVizLeftFile => '选择的图片';

  @override
  String get mediaVizLeftGlyph => '音符图标';

  @override
  String get mediaVizLeftNone => '无（波形占满宽度）';

  @override
  String get mediaVizTextBelow => '图片下方';

  @override
  String get mediaVizTextAbove => '图片上方';

  @override
  String get mediaVizQualityFast => '快速（960×540）';

  @override
  String get mediaVizQualityStandard => '标准（1280×720）';

  @override
  String get mediaVizQualityFine => '精细（2560×1440，耗时约 4 倍）';

  @override
  String get mediaWavInvalid => '不是 WAV 格式';

  @override
  String get mediaWavMissingChunks => 'WAV 缺少 fmt / data';

  @override
  String mediaWavUnsupported(int format, int bits) {
    return '不支持的 WAV(format $format,$bits bit)';
  }

  @override
  String mediaSeconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String mediaVizTimings(
    String total,
    int frameCount,
    String frames,
    String encode,
    String mux,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: '共 $total（$frameCount 帧：绘制 $frames / 编码 $encode / 合成 $mux）',
    );
    return '$_temp0';
  }

  @override
  String get mediaAudioVideoUnsupported =>
      '此设备无法将音频转为视频（仅限 Android / iOS / macOS）';

  @override
  String get mediaViewerSemantics => '帖子';

  @override
  String get mediaViewerBack => '返回';

  @override
  String get mediaViewerPip => '画中画播放';

  @override
  String get mediaViewerMenu => '菜单';

  @override
  String get mediaViewerShare => '分享';

  @override
  String get mediaPluginAsking => '正在查看图片…';

  @override
  String get mediaPluginFound => '已检测到';

  @override
  String get mediaPluginNotFound => '未检测到';

  @override
  String mediaPluginFailed(String reason) {
    return '失败：$reason（关闭后再打开即可重试）';
  }

  @override
  String get mediaPluginFetchFailed => '无法获取图片';

  @override
  String mediaPluginFetchFailedWithError(String error) {
    return '无法获取图片（$error）';
  }

  @override
  String get mediaPluginDecodeFailed => '无法读取图片';

  @override
  String mediaVideoCannotPlay(String error) {
    return '无法播放：$error';
  }

  @override
  String get mediaVideoBack5 => '后退 5 秒';

  @override
  String get mediaVideoPause => '暂停';

  @override
  String get mediaVideoPlay => '播放';

  @override
  String get mediaVideoForward5 => '前进 5 秒';

  @override
  String get mediaVideoSpeed => '播放速度';

  @override
  String get mediaVideoFowTitle => '视频';

  @override
  String get mediaVideoFowClose => '关闭';

  @override
  String get mediaSaveAsk => '每次保存时选择';

  @override
  String get mediaSavePhotos => '照片（相册）';

  @override
  String get mediaSaveFiles => '文件';

  @override
  String get mediaSaveBadFileName => '要保存的文件名无效';

  @override
  String get mediaSaveOutsideFolder => '不会写入保存文件夹以外的位置';

  @override
  String get mediaSaveTooManySameName => '同名文件过多';

  @override
  String get mediaSavePhotosDenied => '未允许保存到照片（请在“设置”App 中允许）';

  @override
  String get mediaSavedToPhotos => '已保存到照片（相册“RASQ”）';

  @override
  String mediaSavedToFilesApp(String folder, String fileName) {
    return '已保存到“文件”App 的 RASQ › $folder($fileName)';
  }

  @override
  String mediaSavedToPath(String path) {
    return '已保存：$path';
  }

  @override
  String get mediaColorBlack => '黑';

  @override
  String get mediaColorNavy => '藏青';

  @override
  String get mediaColorInk => '墨色';

  @override
  String get mediaColorDeepGreen => '深绿';

  @override
  String get mediaColorCrimson => '胭脂红';

  @override
  String get mediaColorWhite => '白';

  @override
  String get mediaColorLightGray => '浅灰';

  @override
  String get mediaColorYellow => '黄';

  @override
  String get mediaColorSkyBlue => '天蓝';

  @override
  String get mediaColorPink => '粉';

  @override
  String get mediaColorBlue => '蓝';

  @override
  String get mediaColorGreen => '绿';

  @override
  String get mediaColorOrange => '橙';

  @override
  String get mediaColorPurple => '紫';

  @override
  String get mediaVizCancel => '取消';

  @override
  String get mediaVizConfirm => '确定';

  @override
  String get mediaVizSemantics => 'Visualizer 设置';

  @override
  String get mediaVizRebuildWarning => '确定后将重新生成视频。之前的编辑会丢失';

  @override
  String mediaVizRebuildDetail(int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '当前播放位置的帧。确定后将重新导出视频（$frames 帧）。绘画、文字等之前的编辑会丢失。',
    );
    return '$_temp0';
  }

  @override
  String mediaVizRebuildDetailReducedFps(int frames, String fps) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other:
          '当前播放位置的帧。确定后将重新导出视频（$frames 帧，由于时长较长，降至 ${fps}fps）。绘画、文字等之前的编辑会丢失。',
    );
    return '$_temp0';
  }

  @override
  String get mediaVizWaveform => '波形';

  @override
  String get mediaVizBands => '频段数（低音 → 高音）';

  @override
  String get mediaVizFrameRate => '帧率';

  @override
  String get mediaVizBarColor => '条形颜色';

  @override
  String get mediaVizBackgroundColor => '背景颜色';

  @override
  String get mediaVizLeftImage => '左侧图片';

  @override
  String get mediaVizPickImage => '选择图片';

  @override
  String get mediaVizRepickImage => '重新选择图片';

  @override
  String get mediaVizPickImageHint => '选择前显示音符图标';

  @override
  String get mediaVizTitleSection => '标题 / 说明';

  @override
  String get mediaVizShowTitle => '显示标题 / 说明';

  @override
  String get mediaVizTitleHint => '标题（留空则使用文件名）';

  @override
  String get mediaVizDescriptionHint => '说明（可选）';

  @override
  String get mediaVizTextScale => '文字大小';

  @override
  String get mediaVizTextColorAuto => '文字颜色：自动';

  @override
  String get mediaVizBackgroundVideo => '背景视频';

  @override
  String get mediaVizPickVideo => '选择视频';

  @override
  String get mediaVizRepickVideo => '重新选择视频';

  @override
  String get mediaVizPickVideoHint => '以视频代替背景颜色播放（不使用其声音）';

  @override
  String mediaVizVideoSelected(String fileName) {
    return '$fileName — 比音频短时会循环播放';
  }

  @override
  String get mediaVizRemoveVideo => '移除背景视频';

  @override
  String get mediaVizDim => '视频上的暗化程度';

  @override
  String get mediaVizDimHint => '让波形和文字更易读';

  @override
  String get mediaVizFade => '淡入淡出（画面）';

  @override
  String get mediaVizFadeIn => '淡入';

  @override
  String get mediaVizFadeOut => '淡出';

  @override
  String get mediaVizFadeNone => '无';

  @override
  String get mediaVizExport => '导出';

  @override
  String get mediaVizExportCaption => '越精细，导出所需时间越长';

  @override
  String get mediaVizExportDetail =>
      '绘制波形的尺寸（输出始终为 2560×1440）。左侧图片和文字是另外单独一层，始终精细绘制。导出时间大致由 帧数 × 绘制尺寸 决定（降低 fps 也有效）。使用背景视频会变慢。';

  @override
  String mediaVizExportDetailWithLast(String timings) {
    return '上次导出：$timings。\n绘制波形的尺寸（输出始终为 2560×1440）。左侧图片和文字是另外单独一层，始终精细绘制。导出时间大致由 帧数 × 绘制尺寸 决定（降低 fps 也有效）。使用背景视频会变慢。';
  }

  @override
  String get nodeprogCatalogGenreGenerate => '生成';

  @override
  String get nodeprogCatalogGenreConvert => '转换';

  @override
  String get nodeprogCatalogGenreInput => '输入';

  @override
  String get nodeprogCatalogGenreTimeline => '时间线';

  @override
  String get nodeprogCatalogGenreProcess => '加工';

  @override
  String get nodeprogCatalogGenreCondition => '条件';

  @override
  String get nodeprogCatalogGenreFunction => '函数';

  @override
  String get nodeprogCatalogGenreFetch => '获取';

  @override
  String get nodeprogCatalogGenreComposer => '编辑器';

  @override
  String get nodeprogCatalogGenreStorage => '保存';

  @override
  String get nodeprogCatalogClockTitle => '时钟生成器';

  @override
  String get nodeprogCatalogClockDescription => '以固定间隔输出时钟。可用作时间线自动刷新等的触发器。';

  @override
  String get nodeprogCatalogTextConstTitle => '文本';

  @override
  String get nodeprogCatalogTextConstDescription =>
      '将写入的文字作为文本输出。可连接到相似度 / 关键词的基准或分割的输入。';

  @override
  String get nodeprogCatalogConvertSplitTitle => '分割';

  @override
  String get nodeprogCatalogConvertSplitDescription =>
      '按分隔符（换行 / 逗号 / 空格）将文本拆分为文本数组。可连接到关键词列表或保存的输入。';

  @override
  String get nodeprogCatalogConvertJoinTitle => '合并';

  @override
  String get nodeprogCatalogConvertJoinDescription =>
      '用分隔符（换行 / 逗号 / 空格）将文本数组合并为一个文本。';

  @override
  String get nodeprogCatalogListFirstTitle => '取出帖子';

  @override
  String get nodeprogCatalogListFirstDescription =>
      '从帖子列表中取出第几条帖子（1 = 第一条）。可将正文转为文本，连接到基准或设置。';

  @override
  String get nodeprogCatalogPostTextTitle => '帖子正文';

  @override
  String get nodeprogCatalogPostTextDescription => '将一条帖子的正文转为文本。';

  @override
  String get nodeprogCatalogRandomTitle => '随机';

  @override
  String get nodeprogCatalogRandomDescription =>
      '为每条帖子输出随机数。范围以“1-7”的形式指定，包含小数点时也会计算小数部分。可通过种子重现。';

  @override
  String get nodeprogCatalogFileTitle => '文件读取器';

  @override
  String get nodeprogCatalogFileDescription => '读取本地文件并作为文本输出。';

  @override
  String get nodeprogCatalogTimelineTitle => '时间线';

  @override
  String get nodeprogCatalogTimelineDescription => '最终输出。连接帖子列表后，会显示在此画面的时间线中。';

  @override
  String get nodeprogCatalogTlSourceTitle => '获取时间线';

  @override
  String get nodeprogCatalogTlSourceDescription => '获取所选时间线，并作为帖子列表传递。';

  @override
  String get nodeprogCatalogTlSourceDetail => '获取所选时间线，并作为帖子列表（带 RRL 标签）传递。';

  @override
  String get nodeprogCatalogSortTitle => '排序';

  @override
  String get nodeprogCatalogSortDescription => '将符合下方所连条件的帖子排到前面（保持原有顺序）。';

  @override
  String get nodeprogCatalogRemoveTitle => '删除';

  @override
  String get nodeprogCatalogRemoveDescription => '移除符合下方所连条件的帖子。';

  @override
  String get nodeprogCatalogCondTitle => '条件';

  @override
  String get nodeprogCatalogCondDescription =>
      '检查指定标签的内容并返回 True/False。向下串联表示“且”，从同一连接点并联表示“或”。';

  @override
  String get nodeprogCatalogNotDescription => '返回下方所连条件的否定。';

  @override
  String get nodeprogCatalogFnInputTitle => '函数输入';

  @override
  String get nodeprogCatalogFnInputDescription =>
      '函数内部的入口。调用方传入的帖子列表从这里输出（仅限函数内部编辑画面）。';

  @override
  String get nodeprogCatalogFnOutputTitle => '函数输出';

  @override
  String get nodeprogCatalogFnOutputDescription =>
      '函数内部的出口。连接到这里的帖子列表将成为函数节点的输出（未连接时原样通过）。';

  @override
  String get nodeprogCatalogFilterQueryTitle => '搜索筛选';

  @override
  String get nodeprogCatalogFilterQueryDescription =>
      '仅让符合搜索词的帖子通过（“排除”则反过来去掉）。';

  @override
  String get nodeprogCatalogFilterQueryDetail =>
      '仅让符合搜索词的帖子通过。搜索词为空时，使用此页面的搜索词/标签。将“排除”设为 true 后，会去掉符合的帖子（关键词静音）。';

  @override
  String get nodeprogCatalogMergeTitle => '合并';

  @override
  String get nodeprogCatalogMergeDescription => '将连接的帖子列表按时间顺序合并为一条。';

  @override
  String get nodeprogCatalogMergeDetail =>
      '将连接的帖子列表按时间顺序汇合为一条。通过不同账号收到的同一帖子会折叠为一张，可通过卡片上的 ↓ 选择账号。';

  @override
  String get nodeprogCatalogTimelineRelationalTitle => '关联时间线';

  @override
  String get nodeprogCatalogTimelineRelationalDescription => '关联时间线筛选的出口。';

  @override
  String get nodeprogCatalogTimelineRelationalDetail =>
      '关联时间线前置筛选的最终输出。连接的帖子列表将成为构建会话事件的输入（处理方式不变）。';

  @override
  String get nodeprogCatalogTlListTitle => '获取列表时间线';

  @override
  String get nodeprogCatalogTlListDescription => '获取 Misskey 列表的时间线（按列表名称指定）。';

  @override
  String get nodeprogCatalogTlSearchTitle => '获取搜索时间线';

  @override
  String get nodeprogCatalogTlSearchDescription => '获取符合搜索词的帖子。';

  @override
  String get nodeprogCatalogTlDmTitle => '获取私信';

  @override
  String get nodeprogCatalogTlDmDescription => '获取与对方（用户名）的私信。';

  @override
  String get nodeprogCatalogTrendTagsTitle => '获取趋势';

  @override
  String get nodeprogCatalogTrendTagsDescription =>
      '将当前趋势标签作为字符串数组输出（用于相似度/关键词的输入）。';

  @override
  String get nodeprogCatalogTlFeedTitle => '获取自定义动态源';

  @override
  String get nodeprogCatalogTlFeedDescription => '获取 Bluesky 的自定义动态源。';

  @override
  String get nodeprogCatalogTlFeedDetail =>
      '获取 Bluesky 自定义动态源（动态源生成器）的时间线（以 at:// URI 指定。在时间线自定义中可搜索选择）。';

  @override
  String get nodeprogCatalogTlRasqlistTitle => '获取 RASQ 列表';

  @override
  String get nodeprogCatalogTlRasqlistDescription =>
      '获取汇集了多个 SNS 用户的 RASQ 列表的帖子。';

  @override
  String get nodeprogCatalogTlRasqlistDetail =>
      '获取 RASQ 列表（将 Misskey / Mastodon / Bluesky 用户汇集为一个的列表）的帖子。只能选择可以获取列表中成员信息的列表（有同一服务器的账号 / 关注了成员）。';

  @override
  String get nodeprogCatalogTrendPostsTitle => '获取趋势搜索结果';

  @override
  String get nodeprogCatalogTrendPostsDescription =>
      '搜索当前排名靠前的趋势标签，并将其帖子合并为一条输出。';

  @override
  String get nodeprogCatalogComposerTargetTitle => '发布目标';

  @override
  String get nodeprogCatalogComposerTargetDescription =>
      '发布目标账号的候选。符合下方条件时将成为发布目标。';

  @override
  String get nodeprogCatalogComposerTargetDetail =>
      '发布目标账号的候选。在下方挂上条件后，当帖子内容符合该条件时，此账号将成为发布目标（越靠上越优先。可手动重新选择）。';

  @override
  String get nodeprogCatalogComposerFallbackTitle => '以替代格式发布';

  @override
  String get nodeprogCatalogComposerFallbackDescription =>
      '被筛选排除时，以其他形式发布到此账号。';

  @override
  String get nodeprogCatalogComposerFallbackDetail =>
      '被筛选排除出发布目标时的旁路。当下方条件（通常是前一个比较的 Not）成立时，以替代格式发布到此账号。';

  @override
  String get nodeprogCatalogComposerLinkgateTitle => '联动筛选';

  @override
  String get nodeprogCatalogComposerLinkgateDescription => '仅对一同发送的帖子生效的筛选。';

  @override
  String get nodeprogCatalogComposerLinkgateDetail =>
      '仅作用于联动发布的筛选。下方条件不成立时，不会向此账号发送联动帖子（不影响普通的发布目标判定）。';

  @override
  String get nodeprogCatalogComposerRegexTitle => '帖子加工（正则表达式）';

  @override
  String get nodeprogCatalogComposerRegexDescription => '发送时替换正文的一部分。';

  @override
  String get nodeprogCatalogComposerRegexDetail =>
      '发送时对正文进行正则表达式替换（替换与模式匹配的部分）。账号为空时，适用于所有发布目标。';

  @override
  String get nodeprogCatalogTlMyreactionsTitle => '获取已回应的帖子';

  @override
  String get nodeprogCatalogTlMyreactionsDescription =>
      '获取你在时间线中回应过的帖子（用于建立偏好画像）。';

  @override
  String get nodeprogCatalogTrendFrameTitle => '趋势框';

  @override
  String get nodeprogCatalogTrendFrameDescription =>
      '趋势首页“趋势”列表的最终输出。连接标签（文本数组）后会直接显示在列表中。';

  @override
  String get nodeprogCatalogMlSimilarTitle => '相似度 (SigLIP)';

  @override
  String get nodeprogCatalogMlSimilarDescription => '输出每条帖子与基准的相似程度（0~1）。';

  @override
  String get nodeprogCatalogMlSimilarDetail =>
      '将基准（文本/数组/向量）与每条帖子的相似度，以此时间线内的相对值 0~1 输出（0.8 ≈ 前 20%）。ML 不可用时降级为 n-gram 相似度。';

  @override
  String get nodeprogCatalogMlGlinerTitle => 'GLiNER 提取';

  @override
  String get nodeprogCatalogMlGlinerDescription =>
      '从帖子列表中提取特征词（按出现频率），并以字符串数组输出。';

  @override
  String get nodeprogCatalogMlSiglipTitle => 'SigLIP 嵌入';

  @override
  String get nodeprogCatalogMlSiglipDescription => '汇总输出帖子列表的倾向。';

  @override
  String get nodeprogCatalogMlSiglipDetail =>
      '以向量输出帖子列表的平均嵌入（画像）。ML 不可用时降级为 n-gram 画像。';

  @override
  String get nodeprogCatalogStorageSaveTitle => '保存 (storage.safe)';

  @override
  String get nodeprogCatalogStorageSaveDescription => '保存连接的数据。';

  @override
  String get nodeprogCatalogStorageSaveDetail =>
      '将连接的数据保存到插槽。storage.safe 是也可以传递给依赖的子插件的安全存放处（插件端的传递会在首次启动时确认）。';

  @override
  String get nodeprogCatalogStorageLoadTitle => '读取 (storage.safe)';

  @override
  String get nodeprogCatalogStorageLoadDescription => '读取保存在插槽中的数据。';

  @override
  String get nodeprogCatalogMlKeywordTitle => '关键词匹配 (GLiNER)';

  @override
  String get nodeprogCatalogMlKeywordDescription => '输出关键词（或数组）与每条帖子特征词的匹配数。';

  @override
  String get nodeprogCatalogMlTendencyTitle => '倾向/刺激程度（画像）';

  @override
  String get nodeprogCatalogMlTendencyDescription => '为每条帖子输出与喜好设置的契合度（0~1）。';

  @override
  String get nodeprogCatalogMlTendencyDetail =>
      '为每条帖子输出与 storage.safe 中趋势画像（喜欢的类型/方向、倾向阈值、刺激程度上限）的契合度（0~1）。画像可在搜索首页的趋势 ⚙ 中编辑，其他节点也能读取同一插槽。';

  @override
  String get nodeprogCatalogCompareTitle => '比较';

  @override
  String get nodeprogCatalogCompareDescription => '将数值与阈值比较并返回 True/False。';

  @override
  String get nodeprogCatalogCompareDetail =>
      '将数值（相似度、随机数等）与阈值比较并返回 True/False 的运算符条件。值来源未连接或无法取得值时（如插槽为空）为 False。';

  @override
  String nodeprogCatalogTypeWithFormat(String type, String format) {
    return '$type($format)';
  }

  @override
  String nodeprogCatalogPortWithType(String label, String type) {
    return '$label($type)';
  }

  @override
  String get nodeprogCatalogIoCond => '条件';

  @override
  String get nodeprogCatalogIoNone => '无';

  @override
  String get nodeprogCatalogListSeparator => '、';

  @override
  String nodeprogCatalogIoSummary(String inputs, String outputs) {
    return '输入：$inputs → 输出：$outputs';
  }

  @override
  String get nodeprogCatalogCustomFunctionAuthor => '自定义函数';

  @override
  String nodeprogCatalogCustomFunctionCondDescription(String tags) {
    return '接收条件 $tags 的自建函数。';
  }

  @override
  String nodeprogCatalogCustomFunctionCondDetail(String tags) {
    return '接收条件标签 $tags 的自定义函数（内部连线由插件/RAi 完成）。';
  }

  @override
  String get nodeprogCatalogCustomFunctionDataDescription => '自建的函数。';

  @override
  String get nodeprogCatalogCustomFunctionDataDetail =>
      '自定义函数（内部连线由插件/RAi 完成）。';

  @override
  String get nodeprogCatalogGenreSortDictionary => '排序/词典';

  @override
  String get nodeprogCatalogCustomFunctionDefaultName => '函数';

  @override
  String get nodeprogComponentsTrendFormTilesLabel => '获取趋势';

  @override
  String get nodeprogComponentsTrendFormChipsLabel => '自定义（候选标签）';

  @override
  String get nodeprogComponentsTrendFormChipsHeading => '搜索建议';

  @override
  String get nodeprogComponentsTrendFormTilesDescription =>
      '以趋势卡片的形式显示候选关键词（点按即可查看该关键词的趋势）。';

  @override
  String get nodeprogComponentsTrendFormTodayDescription =>
      '像 Today 一样汇总显示排名靠前的候选关键词的帖子。';

  @override
  String get nodeprogComponentsTrendFormChipsDescription =>
      '以搜索候选标签的形式显示候选关键词。';

  @override
  String nodeprogComponentsSuggestTitle(String what, String from) {
    return '从$from推荐$what';
  }

  @override
  String nodeprogComponentsFilterTitle(String what, String from) {
    return '按$from筛选$what';
  }

  @override
  String get nodeprogComponentsQueryFilterExcludeTitle => '搜索筛选（排除）';

  @override
  String get nodeprogComponentsTendencyTitle => '倾向/刺激程度（画像）';

  @override
  String get nodeprogComponentsPluginTitle => '自定义（时间线插件）';

  @override
  String get nodeprogComponentsDisplayTimeline => '普通时间线';

  @override
  String get nodeprogComponentsDisplayRelational => '关联时间线';

  @override
  String get nodeprogComponentsDeliveryConfirm => '确认后发布 (confirm)';

  @override
  String get nodeprogComponentsDeliveryDraft => '仅创建草稿 (draft)';

  @override
  String get nodeprogComponentsDeliveryAuto => '直接发布 (auto)';

  @override
  String get nodeprogComponentsSelfDm => '此私信的消息';

  @override
  String get nodeprogComponentsSelfSearch => '此关键词的搜索结果';

  @override
  String get nodeprogComponentsSelfToday => 'Today 的帖子';

  @override
  String get nodeprogComponentsSelfTrendWords => '趋势关键词';

  @override
  String get nodeprogComponentsSelfList => '此列表的帖子';

  @override
  String get nodeprogComponentsSelfFeed => '此动态源的帖子';

  @override
  String get nodeprogComponentsSelfBundle => '综合标签页的帖子';

  @override
  String get nodeprogComponentsSelfHome => '关注中标签页的帖子';

  @override
  String get nodeprogComponentsSelfSocial => '推荐标签页的帖子';

  @override
  String get nodeprogComponentsSelfLocal => '本地标签页的帖子';

  @override
  String get nodeprogComponentsSelfGlobal => '全局标签页的帖子';

  @override
  String get nodeprogComponentsSelfRelational => '关联标签页的帖子';

  @override
  String get nodeprogComponentsSelfTab => '此标签页的帖子';

  @override
  String get nodeprogComponentsTrendTilesNoMl => '使用 ML 模型，因此无法用于趋势卡片';

  @override
  String get nodeprogComponentsTrendTilesNoPlugin =>
      '会对帖子重新排序（可能使用 GPU），因此无法用于趋势卡片';

  @override
  String get nodeprogComposerResetConfig => '重置此配置';

  @override
  String get nodeprogComposerLearnNone => '尚未学习（发帖后会自动学习）';

  @override
  String get nodeprogComposerLearnNoneDetail => '学习画像：还没有已确定的帖子（发帖后自动学习）';

  @override
  String nodeprogComposerLearnCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已从 $count 条帖子中学习',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerLearnCountDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '学习画像：已确定的帖子 $count 条（手动切换的帖子学习权重更高，半衰期 90 天）',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerRelationStats(int pos, int neg) {
    return '记录：联动 $pos 次 / 确认时取消 $neg 次';
  }

  @override
  String get nodeprogComposerNoAccounts => '没有账号';

  @override
  String get nodeprogComposerNoAccountsHint => '登录后即可设置发布目标的条件';

  @override
  String get nodeprogComposerBanner => '与草稿内容相符的账号会成为发布目标候选';

  @override
  String get nodeprogComposerBannerDetail =>
      '为每个账号设置筛选后，与草稿内容（及内部格式）相符的账号会成为发布目标候选。';

  @override
  String get nodeprogComposerHandEdited => '发布目标已在节点编辑器中编辑。在此更改会将其覆盖';

  @override
  String get nodeprogComposerHandEditedDetail => '发布目标已在节点编辑器中编辑。在此更改会替换为简易配置。';

  @override
  String get nodeprogComposerFiltersHeader => '发布目标筛选';

  @override
  String get nodeprogComposerFormatHeader => '格式';

  @override
  String get nodeprogComposerFormatCaption => '即使不符合筛选，也可以换一种形式保留为候选';

  @override
  String get nodeprogComposerFormatCaptionDetail =>
      '不符合筛选时，以替代格式保留为候选（从即将被排除前的比较处绕过）。';

  @override
  String get nodeprogComposerDeliveryHeader => '联动帖子的发送方式';

  @override
  String get nodeprogComposerDeliveryCaption => '与其他账号一起发送时的设置';

  @override
  String get nodeprogComposerDeliveryCaptionDetail =>
      '在多选模式的“节点联动”中发送到此账号时的发送方式，以及可联动的来源账号。';

  @override
  String nodeprogComposerDeliveryTitle(String delivery) {
    return '发送方式：$delivery';
  }

  @override
  String get nodeprogComposerLinkSourcesLabel => '联动来源账号（仅当主发布目标在其中时联动）';

  @override
  String get nodeprogComposerLinkFiltersCaption => '联动筛选（仅在一起发送时生效）';

  @override
  String get nodeprogComposerLinkFiltersCaptionDetail =>
      '联动筛选（仅对联动帖子生效的关卡，不影响发布目标判定）';

  @override
  String nodeprogComposerFilterDescription(String basis, String what) {
    return '以此账号的$basis为基准，草稿在$what上相符时成为发布目标候选。';
  }

  @override
  String get nodeprogComposerFilterBasisPosts => '帖子';

  @override
  String get nodeprogComposerFilterBasisReplies => '回复';

  @override
  String get nodeprogComposerFilterDisabled => '已停用：此账号不会成为发布目标候选。';

  @override
  String nodeprogComposerLinkOnlySubtitle(String account) {
    return '$account · 仅联动';
  }

  @override
  String nodeprogComposerAndSubtitle(String account) {
    return '$account · 且';
  }

  @override
  String get nodeprogComposerLinkFilterDescription => '联动帖子不符合此条件时，不会发送到此账号。';

  @override
  String get nodeprogComposerAndDescription => '与前一个筛选以“且”连接。';

  @override
  String get nodeprogComposerDeleteNode => '删除节点';

  @override
  String nodeprogComposerRegexDescription(String pattern, String replace) {
    return '将发送到此账号的正文中的“$pattern”替换为“$replace”。';
  }

  @override
  String get nodeprogComposerRegexDescriptionEmpty =>
      '发送时对正文进行正则表达式替换（例：更换标签、遮盖文字）。';

  @override
  String get nodeprogComposerRegexUnset => '帖子加工（未设置）';

  @override
  String nodeprogComposerRegexRule(String pattern, String replace) {
    return '“$pattern”→“$replace”';
  }

  @override
  String nodeprogComposerExtraNodeSubtitle(String account) {
    return '$account · 追加节点';
  }

  @override
  String get nodeprogComposerExtraRegexDescription => '在上方的加工之后应用。';

  @override
  String get nodeprogComposerCwLabel => '内容警告';

  @override
  String get nodeprogComposerNoOtherAccounts => '没有其他账号';

  @override
  String get nodeprogComposerRegexMenuTooltip => '帖子加工操作';

  @override
  String get nodeprogComposerFilterMenuTooltip => '发布目标操作';

  @override
  String get nodeprogComposerParamsRegexEnabled => '启用帖子加工';

  @override
  String get nodeprogComposerParamsRegexEnabledSubtitle => '对发送到此账号的正文进行模式替换';

  @override
  String get nodeprogComposerParamsExtraRegex => '在上方的加工之后应用的追加节点。';

  @override
  String get nodeprogComposerParamsFilterEnabled => '启用筛选';

  @override
  String get nodeprogComposerParamsFilterEnabledSubtitle => '停用时，此账号不会成为发布目标候选';

  @override
  String get nodeprogComposerParamsWhat => '比较什么？';

  @override
  String get nodeprogComposerParamsRegexDescription => '发送时对正文进行正则表达式替换。';

  @override
  String get nodeprogComposerParamsLinkFilterDescription => '仅在一起发送时生效的条件。';

  @override
  String get nodeprogComposerParamsLinkFilterDetail =>
      '仅对联动帖子生效的关卡（不影响发布目标判定）。';

  @override
  String get nodeprogComposerParamsFilterDescription =>
      '草稿符合此条件时，此账号会成为发布目标候选。';

  @override
  String get nodeprogComposerParamsPatternLabel => '模式（正则表达式）';

  @override
  String get nodeprogComposerParamsPatternHint => '例：#剧透\\s*';

  @override
  String get nodeprogComposerParamsReplaceLabel => '替换为（留空 = 删除）';

  @override
  String get nodeprogEditorCanvasInputs => '输入';

  @override
  String get nodeprogEditorCanvasOutputs => '输出';

  @override
  String get nodeprogEditorBadgeDefaultOwner => '默认';

  @override
  String get nodeprogEditorBadgeNotRegistered => '未注册';

  @override
  String get nodeprogEditorBadgeSeparator => ' · ';

  @override
  String get nodeprogEditorNodeTabDefaultLabel => '节点 TL';

  @override
  String get nodeprogEditorInlineEmpty => '没有节点';

  @override
  String get nodeprogEditorInlineExpandTooltip => '全屏编辑';

  @override
  String get nodeprogEditorParamsMissing => '此插件未注册（请从商店重新安装）。';

  @override
  String get nodeprogEditorParamsLoading => '正在加载参数…';

  @override
  String get nodeprogEditorParamsNone => '此插件没有参数。';

  @override
  String get nodeprogEditorCancelButton => '取消';

  @override
  String get nodeprogEditorConfirmButton => '确定';

  @override
  String get nodeprogEditorParamsTitle => '设置节点';

  @override
  String get nodeprogEditorPluginSortAuthor => 'TL 插件';

  @override
  String get nodeprogEditorPluginSortDescription => '按照插件的排列方式对帖子排序。';

  @override
  String get nodeprogEditorParamsPluginDetail =>
      '使用插件的排序（tl.sort）对帖子列表排序。参数会进入节点的“参数”端口。';

  @override
  String nodeprogEditorPluginSortTitle(String name) {
    return '按$name排序';
  }

  @override
  String get nodeprogEditorPluginSortDetail => '使用插件的排序（tl.sort）对帖子列表排序。';

  @override
  String get nodeprogEditorTitleFunctionBody => '函数内容';

  @override
  String nodeprogEditorTitleFunctionBodyNamed(String name) {
    return '函数内容 — $name';
  }

  @override
  String get nodeprogEditorTitleComposer => '自定义发布目标';

  @override
  String get nodeprogEditorTitleTrend => '自定义趋势';

  @override
  String get nodeprogEditorTitleTimeline => '自定义时间线';

  @override
  String get nodeprogEditorTabTrendNotes => '帖子';

  @override
  String get nodeprogEditorTabFollowing => '关注中';

  @override
  String get nodeprogEditorTabTrendUsers => '用户';

  @override
  String get nodeprogEditorTabBundle => '综合';

  @override
  String get nodeprogEditorTabSocial => '推荐';

  @override
  String get nodeprogEditorTabRelational => '相关';

  @override
  String get nodeprogEditorTabLocal => '本地';

  @override
  String get nodeprogEditorTabGlobal => '全局';

  @override
  String get nodeprogEditorAddTabTooltip => '添加标签页';

  @override
  String get nodeprogEditorNewTabTitle => '新标签页';

  @override
  String get nodeprogEditorTabNameHint => '标签页名称';

  @override
  String get nodeprogEditorRenameTab => '重命名标签页';

  @override
  String get nodeprogEditorDeleteTab => '删除标签页';

  @override
  String get nodeprogEditorClearGraph => '清空图表';

  @override
  String get nodeprogEditorBundleTabsToggle => '在组合中集中显示节点 TL';

  @override
  String get nodeprogEditorPaletteSearchHint => '搜索插件节点';

  @override
  String nodeprogEditorConnectTypeMismatch(String from, String to) {
    return '无法连接：$from → $to（格式不匹配）';
  }

  @override
  String get nodeprogEditorCreateFunction => '创建自定义函数';

  @override
  String get nodeprogEditorFunctionNameHint => '函数名';

  @override
  String get nodeprogEditorFunctionSourceLabel => '输入来源';

  @override
  String get nodeprogEditorFunctionSourceCond => '条件';

  @override
  String get nodeprogEditorFunctionSourceData => '数据';

  @override
  String get nodeprogEditorFunctionCondTagsLabel => '条件标签（选择多个会增加下方的分支）';

  @override
  String get nodeprogEditorFunctionInputsLabel => '输入（数据格式）';

  @override
  String get nodeprogEditorFunctionOutputsLabel => '输出（数据格式）';

  @override
  String get nodeprogEditorCreateButton => '创建';

  @override
  String get nodeprogEditorMenuInfo => '节点信息';

  @override
  String get nodeprogEditorMenuEditFunctionBody => '编辑函数内容';

  @override
  String get nodeprogEditorMenuStore => '前往插件商店';

  @override
  String get nodeprogEditorMenuCopy => '复制';

  @override
  String get nodeprogEditorMenuPaste => '粘贴';

  @override
  String get nodeprogEditorMenuDelete => '删除';

  @override
  String get nodeprogEditorMoreTooltip => '更多';

  @override
  String get nodeprogEditorSearchNodesTooltip => '搜索节点';

  @override
  String get nodeprogEditorEmptyHint => '从下方搜索添加（点按查看详情，长按拖动）';

  @override
  String get nodeprogEditorToolbarSelect => '框选';

  @override
  String get nodeprogEditorToolbarSelectStop => '停止框选';

  @override
  String get nodeprogEditorToolbarDeleteSelected => '删除所选节点';

  @override
  String get nodeprogEditorToolbarTidy => '整理';

  @override
  String get nodeprogEditorToolbarZoomOut => '缩小';

  @override
  String get nodeprogEditorToolbarZoomIn => '放大';

  @override
  String get nodeprogEditorToolbarFit => '显示全部';

  @override
  String get nodeprogEditorPaletteSortChip => '排序：相关度';

  @override
  String get nodeprogEditorPaletteSortRelevance => '相关度';

  @override
  String nodeprogEditorPaletteGenreChip(String genre) {
    return '类型：$genre';
  }

  @override
  String get nodeprogEditorPaletteGenreAll => '全部';

  @override
  String get nodeprogEditorPaletteSettingsTooltip => '搜索设置（准备中）';

  @override
  String get nodeprogEditorPaletteEmptyTitle => '未找到节点';

  @override
  String get nodeprogEditorPaletteEmptyHint => '请尝试更换搜索词或类型';

  @override
  String get nodeprogEditorCreateFunctionDescription =>
      '选择条件标签或输入输出（数据格式），创建自己的函数节点。数据函数的内容可以用节点组建。';

  @override
  String nodeprogEditorTileSubtitle(String author, String genre) {
    return '$author · $genre';
  }

  @override
  String get nodeprogEditorBuiltinAuthor => '内置节点';

  @override
  String get nodeprogEditorAddToCanvas => '添加到画布';

  @override
  String get nodeprogEditorEditFunctionBody => '编辑内容';

  @override
  String get nodeprogEditorDeleteFunction => '删除函数';

  @override
  String nodeprogEditorInfoGenre(String genre) {
    return '类型：$genre';
  }

  @override
  String get nodeprogEditorInfoCondIn => '条件（上边）';

  @override
  String get nodeprogEditorInfoCondOut => '条件（下边）';

  @override
  String get nodeprogTimelineTabDmCommon => 'DM（通用）';

  @override
  String get nodeprogTimelineTabThisDm => '此 DM';

  @override
  String get nodeprogTimelineTabTrendPage => '趋势页面';

  @override
  String get nodeprogTimelineTabTrendTl => '趋势时间线';

  @override
  String get nodeprogTimelineTabThisList => '此列表';

  @override
  String get nodeprogTimelineReorderTabs => '调整标签页顺序';

  @override
  String get nodeprogTimelineShareTab => '在所有账号间共享';

  @override
  String get nodeprogTimelineResetConfig => '重置此时间线的配置';

  @override
  String get nodeprogTimelineEditAsGraph => '以图形编辑';

  @override
  String nodeprogTimelinePluginWithVersion(String version) {
    return '时间线插件 · v$version';
  }

  @override
  String get nodeprogTimelineAlgoChronoDescription => '按获取时的时间顺序排列。';

  @override
  String get nodeprogTimelineAlgoTendencyDescription =>
      '排除不符合偏好设置的帖子，并按匹配程度排序。';

  @override
  String get nodeprogTimelineAlgoTendencyDetail =>
      '排除不符合趋势画像（倾向/刺激程度、喜欢的类型）的帖子，并按适配度排序。';

  @override
  String nodeprogTimelineAlgoSuggestDescription(
    String from,
    String kind,
    String what,
  ) {
    return '以$from（$kind）为基准，将在$what上相符的帖子排到前面。';
  }

  @override
  String get nodeprogTimelineSuggestFromMyPosts => '我的帖子';

  @override
  String get nodeprogTimelineSuggestFromMyReplies => '我的回复';

  @override
  String get nodeprogTimelineSuggestFromReacted => '我回应过的帖子';

  @override
  String get nodeprogTimelineSourceHomeLabel => '关注中（home）';

  @override
  String get nodeprogTimelineSourceRasqTitle => '获取 RASQ 帖子';

  @override
  String get nodeprogTimelineSourceRasqDescription => '时间线：自己和关注中的 RASQ 账号的帖子';

  @override
  String get nodeprogTimelineSourceRasqSearchTitle => 'RASQ 搜索';

  @override
  String get nodeprogTimelineSourceRasqSearchPageQuery =>
      '搜索：此页面的搜索词 / 标签（包括未关注者的帖子）';

  @override
  String nodeprogTimelineSourceRasqSearchWord(String word) {
    return '搜索：$word（包括未关注者的帖子）';
  }

  @override
  String get nodeprogTimelineSourceRasqListTitle => '获取 RASQ 列表';

  @override
  String nodeprogTimelineSourceRasqListDescription(String name) {
    return 'RASQ 列表：$name';
  }

  @override
  String get nodeprogTimelineNotSelected => '未选择';

  @override
  String get nodeprogTimelineSectionTitle => '分区';

  @override
  String nodeprogTimelineSectionDescription(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '最多容纳 $max 个节点的框（在屏幕上按加入顺序以圆角框显示）',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceAstellTitle => 'ASTell 卡片';

  @override
  String nodeprogTimelineSourceAstellDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '当前开放的 ASTell 房间（最多 $count 个）',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineSourceSwingDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '正在发出 Swing 的人（最多 $count 位）',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceTrendFollowingTitle => '关注者的反应';

  @override
  String get nodeprogTimelineSourceTrendFollowingDescription =>
      '关注者发布的关于此页面词语 / 标签的帖子';

  @override
  String get nodeprogTimelineTrendPluginAll => '所有已安装的趋势插件';

  @override
  String nodeprogTimelineTrendPluginMissing(String id) {
    return '$id（未安装）';
  }

  @override
  String get nodeprogTimelineTrendPluginAuthor => '趋势插件';

  @override
  String nodeprogTimelineTrendPluginDescription(String name, String form) {
    return '$name · $form';
  }

  @override
  String get nodeprogTimelineCurrentAccount => '（当前账号）';

  @override
  String get nodeprogTimelineAllAccounts => '所有账号';

  @override
  String get nodeprogTimelineSourceTrendTitle => '获取趋势';

  @override
  String get nodeprogTimelineSourceTrendTagsAllDescription =>
      '类型：趋势卡片（RASQ 账号下所有 SNS 账号的趋势词）';

  @override
  String get nodeprogTimelineSourceTrendTagsDescription =>
      '类型：趋势卡片（此账号所在服务器的趋势词）';

  @override
  String get nodeprogTimelineSourceSearchTitle => '获取搜索结果';

  @override
  String get nodeprogTimelineSourceSearchPageQuery => '搜索：此页面的搜索词 / 标签';

  @override
  String nodeprogTimelineSourceSearchWord(String word) {
    return '搜索：$word';
  }

  @override
  String get nodeprogTimelineSourceTodayTitle => '获取 Today';

  @override
  String get nodeprogTimelineSourceTodayDescription => '时间线：Today（热门帖子）';

  @override
  String nodeprogTimelineSourceSelfTitle(String name) {
    return '获取$name';
  }

  @override
  String get nodeprogTimelineSourceDmTitle => '获取 DM';

  @override
  String get nodeprogTimelineSourceFeedTitle => '获取自定义动态源';

  @override
  String get nodeprogTimelineSourceListTitle => '获取列表时间线';

  @override
  String get nodeprogTimelineSourceTimelineTitle => '获取时间线';

  @override
  String nodeprogTimelineSourceTlDescription(String tl) {
    return '时间线：$tl';
  }

  @override
  String nodeprogTimelineSourceDmPeer(String peer) {
    return 'DM:@$peer';
  }

  @override
  String get nodeprogTimelineSourceTrendTlKind => '类型：趋势时间线（热门趋势标签的搜索结果）';

  @override
  String nodeprogTimelineSourceFeedName(String name) {
    return '动态源：$name';
  }

  @override
  String nodeprogTimelineSourceListName(String name) {
    return '列表：$name';
  }

  @override
  String get nodeprogTimelineMenuInfo => '详情';

  @override
  String get nodeprogTimelineMenuEditParams => '编辑参数';

  @override
  String get nodeprogTimelineMenuDisable => '暂时停用';

  @override
  String get nodeprogTimelineMenuEnable => '取消停用';

  @override
  String get nodeprogTimelineMenuStore => '前往插件的商店页面';

  @override
  String get nodeprogTimelineMenuKindToTiles => '将类型改为趋势卡片';

  @override
  String get nodeprogTimelineMenuKindToTl => '将类型改为趋势时间线';

  @override
  String nodeprogTimelineMenuLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '数量：$count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineMenuForm(String form) {
    return '形式：$form';
  }

  @override
  String nodeprogTimelineMenuDisplay(String mode) {
    return '显示模式：$mode';
  }

  @override
  String nodeprogTimelineLimitItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineInfoProvider(String provider) {
    return '提供者：$provider';
  }

  @override
  String nodeprogTimelineInfoSupported(String sns) {
    return '支持：$sns';
  }

  @override
  String get nodeprogTimelineReorderAlgorithms => '调整算法顺序';

  @override
  String get nodeprogTimelineReorderSources => '调整时间线顺序';

  @override
  String get nodeprogTimelineBannerDmCommon => '此设置用于所有 DM 页面';

  @override
  String get nodeprogTimelineBannerDmPage => '此设置仅用于此 DM 页面';

  @override
  String get nodeprogTimelineBanner => '可以决定时间线的内容和排列方式';

  @override
  String get nodeprogTimelineBannerDmCommonDetail =>
      'DM 的主设置。适用于所有没有单独设置的 DM 页面。算法从上到下依次应用。';

  @override
  String get nodeprogTimelineBannerDmPageDetail =>
      '仅用于此 DM 页面的设置（保存后优先于 DM 通用设置）。算法从上到下依次应用。';

  @override
  String get nodeprogTimelineBannerDetail =>
      '可以指定时间线的算法、导入来源、要显示的时间线等。算法从上到下依次应用。';

  @override
  String get nodeprogTimelineCreateNameLabel => '时间线名称';

  @override
  String get nodeprogTimelineCreateNameHint => '例：朋友 / 照片';

  @override
  String get nodeprogTimelineTempSearchOnly => '这是由插件排列的时间线。此处只能搜索';

  @override
  String get nodeprogTimelineTempChanged => '此时间线已被临时更改（未保存）。';

  @override
  String get nodeprogTimelineTempRevert => '还原';

  @override
  String get nodeprogTimelineTempSave => '按此内容保存';

  @override
  String get nodeprogTimelineTempNotice => '此处的更改是临时的。保存前原设置不会改变';

  @override
  String get nodeprogTimelineTempNoticeDetail => '此处的更改会临时作用于此时间线。保存前原设置不会改变。';

  @override
  String get nodeprogTimelineCreateCaption => '选择要导入的时间线和算法，然后点按“确定”';

  @override
  String get nodeprogTimelineHandEdited => '此时间线已在节点编辑器中编辑。在此更改会将其覆盖';

  @override
  String get nodeprogTimelineHandEditedDetail => '此时间线已在节点编辑器中编辑。在此更改会替换为简易配置。';

  @override
  String get nodeprogTimelineAlgorithmsHeader => '算法';

  @override
  String get nodeprogTimelineAddAlgorithm => '添加算法';

  @override
  String nodeprogTimelineSectionSubtitle(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '分区 · $count / $max',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineDisabledSuffix => ' · 已停用';

  @override
  String get nodeprogTimelineDisabled => '已停用';

  @override
  String get nodeprogTimelineMetaSeparator => ' · ';

  @override
  String get nodeprogTimelineSectionMenuTooltip => '分区操作';

  @override
  String get nodeprogTimelineAddNode => '添加节点';

  @override
  String get nodeprogTimelineNodeMenuTooltip => '节点操作';

  @override
  String get nodeprogTimelineSectionRename => '更改标题';

  @override
  String get nodeprogTimelineSectionRenameTitle => '分区标题';

  @override
  String get nodeprogTimelineMenuTakeOut => '移出分区';

  @override
  String get nodeprogTimelineDisplayHeader => '显示模式';

  @override
  String nodeprogTimelineDisplayTitle(String mode) {
    return '显示：$mode';
  }

  @override
  String get nodeprogTimelineDisplaySubtitle =>
      '将相同的帖子以普通时间线 / 对话串（关联时间线）/ 按发帖人排列的方式显示';

  @override
  String get nodeprogTimelineSourcesHeader => 'SNS 时间线';

  @override
  String get nodeprogTimelineReorderDone => '完成排序';

  @override
  String get nodeprogTimelineTrendPageCaption =>
      '在搜索首页从上到下显示。用分区区分趋势和 Today 区域';

  @override
  String get nodeprogTimelineTrendPageCaptionDetail =>
      '在搜索首页从上到下显示。默认包含“趋势”（所有账号的趋势卡片）和“Today”分区。算法作用于趋势卡片（无法使用负载较重的算法）。';

  @override
  String get nodeprogTimelineSourcesCaption => '叠加多个时会合并为一条，相同的帖子只显示一次';

  @override
  String get nodeprogTimelineSourcesCaptionDetail =>
      '叠加多个时会合并为一条，相同的帖子会折叠为一张卡片（用卡片上的 ↓ 切换账号）。帖子加工插件在各时间线提供方（SNS 插件）一侧应用。';

  @override
  String get nodeprogTimelineReorderHint => '长按即可拖动。也可以移入或移出分区（最多 3 个）';

  @override
  String get nodeprogTimelineAddSource => '添加时间线';

  @override
  String get nodeprogTimelineClockHeader => '自动刷新';

  @override
  String nodeprogTimelineClockInterval(String interval) {
    return '间隔：$interval';
  }

  @override
  String get nodeprogTimelineAlgorithmMenuTooltip => '算法操作';

  @override
  String get nodeprogTimelineSourceMenuTooltip => '时间线操作';

  @override
  String nodeprogTimelineTendencyGenres(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '喜欢的类型 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyDisliked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '不喜欢 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '示例 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyStimulus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '刺激程度上限 $count',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTendencyPinnedTitle => '倾向/刺激程度（倾向）';

  @override
  String get nodeprogTimelineTendencyPinnedSubtitle => '始终最后';

  @override
  String get nodeprogTimelineTendencyPinnedEmpty => '倾向 FOW 的设置';

  @override
  String get nodeprogTimelineTendencyPinnedInfo =>
      '将在倾向 FOW 中设置的倾向/刺激程度应用于算法的最后。此处无法移除（如需更改或停止，请在倾向 FOW 中操作）';

  @override
  String get nodeprogTimelineParamsSuggestWhat => '按什么推荐？';

  @override
  String get nodeprogTimelineParamsSuggestFrom => '从什么中读取？';

  @override
  String get nodeprogTimelineParamsPluginPending => '此插件的设置正在准备中。';

  @override
  String get nodeprogTimelineParamsQueryFilter =>
      '搜索词为空时，按此页面的搜索词/标签筛选。可以在下方的栏位中指定搜索词。';

  @override
  String get nodeprogTimelineParamsTendency => '使用偏好设置。可以在下方更改。';

  @override
  String get nodeprogTimelineParamsChrono => '时间顺序没有参数。';

  @override
  String get nodeprogTimelineParamsPluginPendingDetail =>
      '此插件的参数（RRL 设置页面）将在节点定义分发（商店集成）后显示在此处。';

  @override
  String get nodeprogTimelineParamsTendencyDetail =>
      '使用 storage.safe 中的趋势画像。可以通过下方选项编辑倾向/刺激程度、喜欢的类型以及从操作中选择类型（与搜索首页的趋势 ⚙ 相同）。';

  @override
  String get nodeprogTimelineParamsTrendPlugin => '以所选形式显示趋势插件给出的候选词。';

  @override
  String get nodeprogTimelineParamsTrendPluginDetail =>
      '将 trend.suggest 插槽的答案（候选词）以以下形式显示：获取趋势 = 趋势卡片 / Today = 热门词帖子摘要 / 自定义 = 候选标签。数量在 … 中设置。';

  @override
  String get nodeprogTimelineParamsForm => '形式';

  @override
  String get nodeprogTimelineParamsRasq => '导入自己和关注者的 RASQ 帖子。仅在登录 RASQ 时显示。';

  @override
  String get nodeprogTimelineParamsRasqDetail =>
      '导入自己和关注中的 RASQ 账号的帖子 / 转播。仅在登录 RASQ 账号时显示。没有参数。';

  @override
  String get nodeprogTimelineParamsRasqSearch => '搜索并导入 RASQ 的公开帖子。也包括未关注者的帖子。';

  @override
  String get nodeprogTimelineParamsRasqSearchDetail =>
      '使用下方的搜索词搜索并导入 RASQ 的公开帖子（无论是否关注）。留空时按此页面的搜索词 / 标签搜索。将显示模式设为“用户”后，会以发帖人卡片排列。';

  @override
  String get nodeprogTimelineParamsRasqList => '导入 RASQ 列表的帖子。在下方选择后会关注该列表。';

  @override
  String get nodeprogTimelineParamsRasqListDetail =>
      '导入 RASQ 列表的帖子（查看时由 Central 收集列表成员的帖子）。在下方栏位中从自己的列表、关注中的列表中选择，或搜索公开列表。选择后会关注该列表。';

  @override
  String nodeprogTimelineParamsSelfDetail(String name) {
    return '直接导入$name。没有参数。';
  }

  @override
  String get nodeprogTimelineParamsAccount => '账号';

  @override
  String get nodeprogTimelineParamsTlKind => '时间线类型（此 SNS 可提供的）';

  @override
  String get nodeprogTimelineParamsList => '列表（此账号的）';

  @override
  String get nodeprogTimelineParamsNoLists => '此账号没有列表（或无法获取）。';

  @override
  String get nodeprogTimelineParamsFeed => '自定义动态源（在下方栏位中搜索并选择）';

  @override
  String get nodeprogTimelineParamsTendencyEdit => '趋势的倾向/刺激程度';

  @override
  String get nodeprogTimelineParamsGenresEdit => '喜欢的类型/方向';

  @override
  String get nodeprogTimelineParamsPickGenresSubtitle => '按相似话题归类，从话题性强的开始';

  @override
  String get nodeprogTimelineParamsRasqSearchWordLabel =>
      '搜索词（留空 = 此页面的词语 / 标签）';

  @override
  String get nodeprogTimelineParamsRasqListSearchLabel =>
      '搜索 RASQ 列表（名称 / @创建者 / 分享链接）';

  @override
  String get nodeprogTimelineParamsFeedSearchLabel => '搜索动态源';

  @override
  String get nodeprogTimelineParamsFeedNotFound => '未找到';

  @override
  String get nodeprogTimelineParamsQueryLabel => '搜索词（留空 = 此页面的搜索词）';

  @override
  String get nodeprogTimelineParamsExcludeTitle => '排除包含此词的帖子';

  @override
  String get nodeprogTimelineParamsExcludeSubtitle => '关闭时仅保留包含此词的帖子';

  @override
  String get nodeprogTimelineCreateTitle => '创建时间线';

  @override
  String nodeprogTimelineCreateDefaultName(int number) {
    return '时间线 $number';
  }

  @override
  String get nodeprogTimelineCreateShareTitle => '是否也应用到其他账号？';

  @override
  String get nodeprogTimelineCreateShareMessage =>
      '选择“应用到所有账号”后，所有账号都会显示此时间线，内容的更改也会作用于全部账号（之后可以在 … 菜单中更改）。';

  @override
  String get nodeprogTimelineCreateShareConfirm => '应用到所有账号';

  @override
  String get nodeprogTimelineCreateShareCancel => '仅此账号';

  @override
  String get nodeprogTimelineLoadFailed => '无法加载';

  @override
  String get nodeprogTimelineNodeTrend => '趋势';

  @override
  String get nodeprogTimelineNodeTabFallback => '节点时间线';

  @override
  String get nodeprogTimelineReload => '重新加载';

  @override
  String get nodeprogTimelineAstellEmpty => '目前没有开放的 ASTell';

  @override
  String nodeprogTimelineAstellEmptyQuery(String query) {
    return '没有关于“$query”的 ASTell';
  }

  @override
  String get nodeprogTimelineSwingEmpty => '目前没有 Swing';

  @override
  String nodeprogTimelineSwingEmptyQuery(String query) {
    return '没有关于“$query”的 Swing';
  }

  @override
  String get nodeprogTimelineTrendEmpty => '暂无趋势';

  @override
  String get nodeprogTimelineTrendFollowingNoQuery => '在趋势时间线中显示';

  @override
  String get nodeprogTimelineTrendFollowingEmpty => '暂无关注者的反应';

  @override
  String get nodeprogTimelinePostsEmpty => '暂无内容';

  @override
  String get nodeprogTimelineEventsEmpty => '暂无对话串';

  @override
  String get nodeprogTimelineUsersEmpty => '暂无用户';

  @override
  String nodeprogTimelineUserPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条帖子',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTempSemantics => '临时更改时间线';

  @override
  String get nodeprogTimelineSearchPrev => '上一个匹配的帖子';

  @override
  String get nodeprogTimelineSearchNext => '下一个匹配的帖子';

  @override
  String get nodeprogTimelineSearchHint => '在此时间线中搜索';

  @override
  String get nodeprogTimelineSearchFuzzy => '模糊搜索';

  @override
  String get nodeprogTimelineTempClose => '关闭';

  @override
  String get nodeprogTimelineTempTitle => '临时更改时间线';

  @override
  String get nodeprogTimelinePaletteSuggestTitle => '推荐';

  @override
  String get nodeprogTimelinePaletteSuggestDescription => '将与你的帖子或反应相近的帖子排到前面。';

  @override
  String get nodeprogTimelinePaletteSuggestDetail =>
      '从[帖子内容/回应/对话内容]中读取[关键词/相似度]，将匹配的帖子排到前面。';

  @override
  String get nodeprogTimelinePaletteFilterTitle => '筛选';

  @override
  String get nodeprogTimelinePaletteFilterDescription => '排除与你的帖子或反应不符的帖子。';

  @override
  String get nodeprogTimelinePaletteFilterDetail =>
      '从[帖子内容/回应/对话内容]中读取[关键词/相似度]，排除不匹配的帖子（参数与推荐相同）。';

  @override
  String get nodeprogTimelinePaletteQueryFilterTitle => '搜索筛选';

  @override
  String get nodeprogTimelinePaletteQueryFilterDescription =>
      '仅保留符合此页面搜索词/标签（或指定词）的帖子。';

  @override
  String get nodeprogTimelinePaletteTendencyTitle => '倾向/刺激程度';

  @override
  String get nodeprogTimelinePaletteTendencyDescription =>
      '排除不符合偏好设置的帖子，并按匹配程度排序。';

  @override
  String get nodeprogTimelinePaletteTendencyDetail =>
      '排除不符合趋势画像（喜欢的类型/方向、倾向阈值、刺激程度上限）的帖子，并按适配度排序。画像可在搜索首页的趋势 ⚙ 中编辑。';

  @override
  String get nodeprogTimelinePalettePickGenresTitle => '从操作中选择类型';

  @override
  String get nodeprogTimelinePalettePickGenresDescription =>
      '从你回应过的帖子的话题中选择喜欢的类型。';

  @override
  String get nodeprogTimelinePalettePickGenresDetail =>
      '将你回应过的帖子按相似话题归类，从话题性强的开始以“喜欢 / 不喜欢”决定喜欢的类型（倾向/刺激程度组件会使用此画像）。';

  @override
  String get nodeprogTimelinePaletteChronoTitle => '时间顺序';

  @override
  String get nodeprogTimelinePaletteChronoDescription => '按获取时的时间顺序排列。';

  @override
  String get nodeprogTimelinePaletteThisDmDescription => '直接导入此 DM 页面的消息。';

  @override
  String get nodeprogTimelinePaletteThisDmDetail =>
      '直接导入此 DM 页面的消息（在通用设置中为各页面的 DM）。';

  @override
  String get nodeprogTimelinePaletteSearchResultsDescription =>
      '导入用此账号搜索此页面搜索词 / 标签的结果。';

  @override
  String get nodeprogTimelinePaletteRasqPostsTitle => 'RASQ 帖子';

  @override
  String get nodeprogTimelinePaletteRasqPostsDescription =>
      '导入自己和关注者的 RASQ 帖子。';

  @override
  String get nodeprogTimelinePaletteRasqPostsDetail =>
      '导入自己和关注中的 RASQ 账号的帖子 / 转播。可以与 SNS 帖子混合在同一时间线中。';

  @override
  String get nodeprogTimelinePaletteTimelineTitle => '时间线';

  @override
  String get nodeprogTimelinePaletteTimelineDescription => '导入账号的时间线。添加后可选择类型。';

  @override
  String get nodeprogTimelinePaletteTimelineDetail =>
      '导入账号的基本时间线。添加后可在卡片上选择账号以及该 SNS 提供的类型（关注中 / 本地 / 全局 / Discover …）。';

  @override
  String get nodeprogTimelinePaletteListTlTitle => '列表时间线';

  @override
  String get nodeprogTimelinePaletteListTlDescription => '导入账号的列表。添加后可选择列表。';

  @override
  String get nodeprogTimelinePaletteListTlDetail =>
      '导入账号及该账号所含列表的时间线（添加后在卡片上选择）。';

  @override
  String get nodeprogTimelinePaletteFeedTitle => '自定义动态源（Bluesky）';

  @override
  String get nodeprogTimelinePaletteFeedDescription => '查找并导入 Bluesky 的自定义动态源。';

  @override
  String get nodeprogTimelinePaletteFeedDetail =>
      '搜索并导入 Bluesky 的自定义动态源（跨 SNS 的列表请使用“RASQ 列表”）。';

  @override
  String get nodeprogTimelinePaletteRasqListTitle => 'RASQ 列表';

  @override
  String get nodeprogTimelinePaletteRasqListDescription =>
      '导入汇集多个 SNS 用户的列表中的帖子。';

  @override
  String get nodeprogTimelinePaletteRasqListDetail =>
      '导入 RASQ 列表（将 Misskey / Mastodon / Bluesky 的用户汇集为一个列表）中的帖子。从自己的列表、关注中的列表中选择，或搜索公开列表。仅能选择可获取列表成员信息的列表（有同一服务器的账号 / 关注了其中的成员）。';

  @override
  String get nodeprogTimelinePaletteTrendDescription =>
      '导入当前的趋势。添加后可切换类型（趋势卡片 / 趋势时间线）。';

  @override
  String get nodeprogTimelinePaletteTrendDetail =>
      '趋势卡片 = 服务器趋势词的卡片；趋势时间线 = 将当前热门趋势标签的搜索结果合并为一条的帖子。';

  @override
  String get nodeprogTimelinePaletteTrendFollowingDescription =>
      '显示关注者发布的关于此页面词语 / 标签的帖子。';

  @override
  String nodeprogTimelinePaletteDmPeerDescription(String peer) {
    return '导入与 @$peer 的 DM。';
  }

  @override
  String get nodeprogTimelinePaletteSectionDescription =>
      '最多容纳 3 个节点的框。在屏幕上按加入顺序显示在标题下方。';

  @override
  String get nodeprogTimelinePaletteAstellDescription =>
      '以卡片显示当前开放的 ASTell 房间。';

  @override
  String get nodeprogTimelinePaletteSwingDescription => '列出正在发出 Swing 的人。';

  @override
  String nodeprogTimelinePaletteTrendPluginTitle(String form, String name) {
    return '$form:$name';
  }

  @override
  String nodeprogTimelinePaletteTrendPluginDetail(String form) {
    return '$form（以此形式的节点显示 trend.suggest 插槽的答案）';
  }

  @override
  String nodeprogTimelinePaletteTodayTitle(String account) {
    return 'Today:$account';
  }

  @override
  String get nodeprogTimelinePaletteSnsPluginAuthor => 'SNS 插件';

  @override
  String get nodeprogTimelinePaletteListsAuthor => '列表类';

  @override
  String get nodeprogTimelinePaletteTodayDescription => '导入此账号的 Today（热门帖子）。';

  @override
  String nodeprogTimelinePaletteTrendTagsTitle(String account) {
    return '趋势：$account';
  }

  @override
  String get nodeprogTimelinePaletteTrendTagsAllDescription =>
      '以卡片显示 RASQ 账号下所有 SNS 账号的趋势词。';

  @override
  String get nodeprogTimelinePaletteTrendTagsDescription =>
      '以卡片显示此账号所在服务器的趋势词。';

  @override
  String nodeprogTimelinePaletteSearchResultsTitle(String account) {
    return '搜索结果：$account';
  }

  @override
  String nodeprogTimelinePaletteSelfDescription(String name) {
    return '直接导入$name。';
  }

  @override
  String get nodeprogTimelinePaletteRasqSearchDescription =>
      '搜索并导入 RASQ 帖子，包括未关注者的帖子。使用显示模式“用户”可显示为用户卡片。';

  @override
  String get nodeprogTimelinePaletteEmptyTitle => '未找到组件';

  @override
  String get nodeprogTimelinePaletteEmptyHint => '请尝试更换搜索词';

  @override
  String get notificationsPrefReaction => '通知回应';

  @override
  String get notificationsPrefRepost => '通知转帖';

  @override
  String get notificationsPrefQuote => '通知引用';

  @override
  String get notificationsPrefAstell => '通知 ASTell';

  @override
  String get notificationsPrefTimer => '通知定时书签';

  @override
  String get notificationsPrefPollEnded => '通知投票结束';

  @override
  String get notificationsPrefFollow => '通知关注';

  @override
  String get notificationsPrefSystem => '显示系统通知';

  @override
  String get notificationsPrefOther => '推送其他通知';

  @override
  String get notificationsTabAll => '全部';

  @override
  String get notificationsTabFollowing => '关注中';

  @override
  String get notificationsPrefsTitle => '通知配置文件设置';

  @override
  String get notificationsEmptyFollowing => '没有来自关注对象的通知';

  @override
  String get notificationsClose => '关闭';

  @override
  String get notificationsPrefEnabled => '开启通知';

  @override
  String get notificationsPushTitle => '接收推送通知';

  @override
  String get notificationsPushDetail => '仅用于通知的访问令牌';

  @override
  String get notificationsQuickReadAll => '将所有通知标为已读';

  @override
  String get notificationsQuickReadFollowing => '将关注对象的通知标为已读';

  @override
  String get notificationsQuickOff => '关闭通知';

  @override
  String get notificationsEmpty => '没有通知';

  @override
  String get notificationsRetry => '重新加载';

  @override
  String get notificationsRemindersHeader => '已登记开始通知的 ASTell';

  @override
  String notificationsReminderSchedule(String when) {
    return '预定于 $when';
  }

  @override
  String get notificationsReminderCancel => '取消';

  @override
  String get notificationsSystemFallbackTitle => '系统通知';

  @override
  String notificationsActorsOne(String name) {
    return '$name';
  }

  @override
  String notificationsActorsTwo(String first, String second) {
    return '$first、$second';
  }

  @override
  String notificationsActorsMore(String first, String second, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$first、$second等另外 $count 人',
    );
    return '$_temp0';
  }

  @override
  String notificationsActionReacted(String names) {
    return '$names回应了你的帖子';
  }

  @override
  String notificationsActionReposted(String names) {
    return '$names转帖了你的帖子';
  }

  @override
  String notificationsActionPollEnded(String names) {
    return '$names的投票已结束';
  }

  @override
  String notificationsActionOther(String names) {
    return '$names的通知';
  }

  @override
  String get notificationsMenuTooltip => '菜单';

  @override
  String notificationsFollowFollowed(String name) {
    return '$name关注了你';
  }

  @override
  String notificationsFollowRequested(String name) {
    return '$name向你发送了关注请求';
  }

  @override
  String notificationsFollowAccepted(String name) {
    return '$name接受了你的关注请求';
  }

  @override
  String notificationsFollowListAdded(String name) {
    return '$name将你添加到了列表';
  }

  @override
  String get notificationsFollowButton => '关注';

  @override
  String get notificationsFollowingButton => '关注中';

  @override
  String get notificationsPostReply => '回复';

  @override
  String get notificationsPostQuote => '引用';

  @override
  String get notificationsPostMention => '提及';

  @override
  String get notificationsTimerAstell => '已加入书签的 ASTell 即将开始！';

  @override
  String get notificationsTimerBookmark => '定时书签';

  @override
  String get notificationsRasqLoadError => '无法加载';

  @override
  String get notificationsRasqEmpty => '没有 RASQ 通知';

  @override
  String get notificationsRasqEmptyHint => '收到提及 / 回复 / 引用 / Swing 邀请时会显示在这里';

  @override
  String get notifyPushChannelName => 'RASQ 通知';

  @override
  String get notifyPushChannelDescription => '提及、回复、Swing 等通知';

  @override
  String get notifyOpenAction => '打开';

  @override
  String get notifyGlimpseChannelName => '读取屏幕';

  @override
  String get notifyGlimpseChannelDescription => '点按后，将简单读取当前显示的屏幕内容';

  @override
  String get notifyAstellChannelName => 'ASTell 开始';

  @override
  String get notifyAstellChannelDescription => '已加入书签的 ASTell 开始时通知';

  @override
  String get onboardingBack => '返回';

  @override
  String get onboardingHandleTooShort => '至少需要 3 个字符';

  @override
  String get onboardingHandleTooLong => '最多 32 个字符';

  @override
  String get onboardingHandleInvalid => '只能使用小写英文字母、数字和 _';

  @override
  String get onboardingAccountTitleNew => '创建新的 RASQ 账号';

  @override
  String get onboardingAccountTitle => '创建 RASQ 账号';

  @override
  String get onboardingAccountDescription =>
      'RASQ 账号是把你登录的 SNS 账号汇集在一起的“你”的容器。已安装的插件、设置和账号组合也能在其他设备上使用。';

  @override
  String get onboardingHandleLabel => '用户名（@ 后面的名字）';

  @override
  String get onboardingHandleHelper => '3~32 个小写英文字母、数字或 _';

  @override
  String onboardingPasswordLabel(int min) {
    return '密码（至少 $min 个字符）';
  }

  @override
  String get onboardingPasswordHide => '隐藏';

  @override
  String get onboardingPasswordShow => '显示';

  @override
  String get onboardingPasswordConfirmLabel => '密码（确认）';

  @override
  String get onboardingPasswordMismatch => '密码不一致';

  @override
  String get onboardingPasswordCaption => '从其他设备或网页版登录此账号时使用。';

  @override
  String get onboardingAgeHeading => '年龄';

  @override
  String get onboardingAgeCaption =>
      'RASQ 供 13 岁及以上的人使用。未满 18 岁的人将在下一页确认监护人的同意。';

  @override
  String get onboardingNoCentral => '尚未设置 RASQ Central 的连接地址';

  @override
  String get onboardingSetCentral => '设置连接地址';

  @override
  String get onboardingNext => '下一步';

  @override
  String onboardingCreateFailed(String error) {
    return '无法创建 RASQ 账号：$error';
  }

  @override
  String get onboardingTermsTitle => '使用条款和隐私政策';

  @override
  String get onboardingTermsNoDraft => '请先在第 ① 页填写用户名等信息';

  @override
  String get onboardingTermsRead => '阅读使用条款';

  @override
  String get onboardingPrivacyRead => '阅读隐私政策';

  @override
  String get onboardingAgree => '同意使用条款和隐私政策';

  @override
  String get onboardingChildSafeHeading => '儿童安全（未满 18 岁）';

  @override
  String onboardingChildSafeNote(String age) {
    return '$age的人需要获得监护人的同意。与监护人的 RASQ 账号关联后，监护人可以决定使用方式（可见帖子的强度、使用时间和可用功能）（设置 → 儿童安全 → 儿童模式）。';
  }

  @override
  String get onboardingGuardianConsent => '已获得监护人同意';

  @override
  String get onboardingChildLogin => '使用监护人提供的代码登录';

  @override
  String get onboardingChildLoginCaption =>
      '如果监护人已为你创建账号，请不要在这里注册，而是使用收到的代码登录。';

  @override
  String get onboardingBundleHeading => '账号组合';

  @override
  String get onboardingBundleReplace => '替换为此设备上的 SNS 账号';

  @override
  String onboardingBundleReplaceSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '将已登录的 $count 个账号汇集到此 RASQ 账号',
    );
    return '$_temp0';
  }

  @override
  String get onboardingBundleKeep => '不替换';

  @override
  String get onboardingBundleKeepSubtitle => 'SNS 账号只保留在此设备上';

  @override
  String get onboardingTermsContributionNote =>
      '“为算法和社区做贡献”不包含在本次注册中（这是另外的可选同意，默认为“不提供”）。你可以随时删除 RASQ 账号。';

  @override
  String get onboardingRegister => '同意并注册';

  @override
  String get onboardingSnsTitle => '使用 SNS 账号登录';

  @override
  String get onboardingSnsDescription =>
      'RASQ 账号已创建。请使用你正在用的社交媒体账号登录。如果还没有使用任何社交媒体，可以通过“寻找 SNS 服务”找到合适的服务器或列表。';

  @override
  String onboardingSnsLoginWith(String service) {
    return '使用 $service 登录';
  }

  @override
  String get onboardingSnsPluginLoadNote => '首次登录前会加载插件。请在网络良好的环境下进行。';

  @override
  String onboardingSignupGuideClosed(String name) {
    return '$name 目前不接受新注册，或仅限邀请。如果没有邀请链接，请选择其他服务器。';
  }

  @override
  String onboardingSignupGuideMastodonOpened(String name) {
    return '已打开 $name 的注册页面。出现服务器规则后，请阅读并点击“同意”。';
  }

  @override
  String get onboardingSignupGuideMastodonForm =>
      '填写显示名称、用户名、电子邮件地址和密码。用户名之后无法更改，请选一个你喜欢的。';

  @override
  String get onboardingSignupGuideMastodonMail =>
      '点击注册后，会收到一封确认邮件。请打开邮件中的链接，验证你的电子邮件地址。';

  @override
  String onboardingSignupGuideOpened(String name) {
    return '已打开 $name 的页面。请点击页面上的“注册”。';
  }

  @override
  String get onboardingSignupGuideForm => '设置用户名和密码。用户名之后无法更改，请选一个你喜欢的。';

  @override
  String get onboardingSignupGuideChecks =>
      '根据服务器的不同，可能会要求填写电子邮件地址、邀请码或进行人机验证。请按照屏幕上的提示填写。';

  @override
  String get onboardingSignupGuideRules =>
      '阅读并同意服务器的规则（使用条款）。如果要求确认电子邮件，请打开收到的邮件中的链接。';

  @override
  String get onboardingSignupGuideDone => '注册完成后，请点击下方的“已注册”。RASQ 会登录此服务器。';

  @override
  String get onboardingSignupGuideThenPost => '登录后，将打开刚才的帖子。';

  @override
  String onboardingSignupGuideThenList(String name) {
    return '登录后，将打开 RASQ 列表“$name”。';
  }

  @override
  String get onboardingSignupGuideRasqLater => '之后可以在侧边栏的 … 中创建 RASQ 账号。';

  @override
  String get onboardingSignupTitleFallback => '注册服务器';

  @override
  String get onboardingSignupNoTarget => '未选择要注册的服务器';

  @override
  String get onboardingSignupDone => '已注册（前往登录）';

  @override
  String onboardingSignupTitle(String name) {
    return '注册 $name';
  }

  @override
  String get onboardingSignupGuideHeading => 'RAi 指南';

  @override
  String get onboardingSignupGuidePrev => '上一步';

  @override
  String get onboardingSignupNoWebView =>
      '此设备无法在应用内打开注册页面。请在浏览器中打开并注册，完成后返回此界面。';

  @override
  String get onboardingSignupOpenBrowser => '在浏览器中打开注册页面';

  @override
  String onboardingSignupPostNotFound(String account) {
    return '在 $account 上找不到刚才的帖子';
  }

  @override
  String get onboardingEntryCreateNew => '创建新的 RASQ 账号';

  @override
  String get onboardingEntryCreate => '创建 RASQ 账号';

  @override
  String get onboardingEntryLogin => '登录 RASQ 账号';

  @override
  String get onboardingEntryDiscover => '寻找社交媒体服务（通过图片、用户或 RAi）';

  @override
  String onboardingEntryResume(String name) {
    return '以 $name 继续';
  }

  @override
  String onboardingEntryResumeWithHandle(String name, String handle) {
    return '以 $name（@$handle）继续';
  }

  @override
  String get onboardingEntryResumeFallbackName => 'RASQ 账号';

  @override
  String get onboardingEntrySnsOnly => '仅使用 SNS 账号';

  @override
  String get onboardingEntrySkip => '跳过，仅在此设备上使用';

  @override
  String get onboardingEntryHaveAccount => '我已有 RASQ 账号';

  @override
  String get onboardingEntryLoginQuestion => '要登录 RASQ 账号吗？';

  @override
  String get onboardingEntryCreateQuestion => '要创建 RASQ 账号吗？';

  @override
  String get onboardingEntryLoginBody =>
      '登录 RASQ 账号后，汇集的 SNS 账号、已安装的插件和设置都会恢复到此设备上。';

  @override
  String get onboardingEntryCreateBody =>
      'RASQ 账号是把你登录的 SNS 账号汇集在一起的“你”的容器。创建后，已安装的插件、设置和账号的汇集方式会保存到 RASQ Central，在其他设备上也能以相同状态使用。';

  @override
  String get onboardingEntryWebNote =>
      '在网页版中，社交媒体的登录信息会存放在 RASQ 服务器的保管库中（使用服务器的密钥加密，RASQ 的服务器可以解密）。也可以仅使用社交媒体账号，但这样关闭此标签页后登录状态就会消失。';

  @override
  String get onboardingEntrySnsOnlyNote =>
      '也可以仅使用 SNS 账号。这种情况下，已安装的插件和设置只会保存在此设备中。';

  @override
  String get onboardingEntrySkipNote =>
      '跳过也可以使用 RASQ。这种情况下，已安装的插件和设置只会保存在此设备中（之后可以在侧边栏的 … 中创建）。';

  @override
  String get onboardingShowcaseTitle => '看看服务器和列表';

  @override
  String get onboardingShowcaseServersHint => '点按即可注册该服务器';

  @override
  String get onboardingShowcaseOpenServer => '打开服务器';

  @override
  String get onboardingShowcaseSignupServer => '注册此服务器';

  @override
  String get onboardingShowcaseListsHint => '跨社交媒体的用户列表。点按即可注册列表中用户所在的服务器';

  @override
  String get onboardingShowcaseListCannotSignup => '无法从应用注册此列表的服务器';

  @override
  String get onboardingShowcasePickServer => '要注册哪个服务器？';

  @override
  String onboardingShowcasePickServerSubtitle(String host, String kind) {
    return '$host · $kind';
  }

  @override
  String onboardingShowcasePostImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张图片',
    );
    return '$_temp0';
  }

  @override
  String get onboardingGenreGame => '游戏';

  @override
  String get onboardingGenreAnime => '动漫';

  @override
  String get onboardingGenreMusic => '音乐';

  @override
  String get onboardingGenreArt => '插画与创作';

  @override
  String get onboardingGenrePhoto => '摄影';

  @override
  String get onboardingGenreFood => '美食';

  @override
  String get onboardingGenreTech => 'IT 与编程';

  @override
  String get onboardingGenreAnimal => '动物与宠物';

  @override
  String get onboardingGenreSports => '体育';

  @override
  String get onboardingGenreTravel => '旅行与出游';

  @override
  String get onboardingGenreBooks => '书籍与阅读';

  @override
  String get onboardingGenreMovie => '电影与剧集';

  @override
  String get onboardingGenreNature => '季节与自然';

  @override
  String onboardingPasswordTooShort(int min) {
    return '至少需要 $min 个字符';
  }

  @override
  String get onboardingPasswordTooLong => '最多 256 个字符';

  @override
  String get onboardingPasswordRepeated => '不能使用重复的同一个字符';

  @override
  String get onboardingTermsOutdated => '使用条款已更新。请更新应用后重新注册';

  @override
  String get onboardingNoServer => '尚未设置 RASQ 服务器的连接地址';

  @override
  String get onboardingHandleTaken => '此用户名已被使用';

  @override
  String onboardingHandleUnusable(String error) {
    return '此用户名无法使用（$error）';
  }

  @override
  String onboardingHandleKept(String reason, String handle) {
    return '$reason。用户名保持为 @$handle（可在编辑个人资料中更改）';
  }

  @override
  String onboardingPasswordSetFailed(String error) {
    return '账号已创建，但无法设置密码（$error）。请在设置 →“账号保护”中设置';
  }

  @override
  String get onboardingRestored => '已切换回此设备的 RASQ 账号';

  @override
  String get onboardingNudgeTitle => '要创建 RASQ 账号吗？';

  @override
  String get onboardingNudgeMessage =>
      '有了 RASQ 账号，已安装的插件、设置和社交媒体账号组合也能在其他设备上使用。Swing 和 RASQ 列表也需要通过 RASQ 账号使用。之后也可以在侧边栏的 … 中创建。';

  @override
  String get onboardingNudgeCreate => '创建';

  @override
  String get onboardingNudgeLogin => '登录（已有账号）';

  @override
  String get onboardingNudgeLater => '以后再说';

  @override
  String onboardingNudgeCreated(String handle) {
    return '已创建 RASQ 账号 @$handle';
  }

  @override
  String get onboardingFeedTitle => '来自公开的 RASQ 列表';

  @override
  String get onboardingFeedCaption => '跨社交媒体的用户列表中阅读量高的帖子';

  @override
  String get onboardingFeedEmpty => '目前没有可显示的帖子';

  @override
  String onboardingFeedListName(String name) {
    return '列表“$name”';
  }

  @override
  String get onboardingDiscoverTitle => '寻找 SNS 服务';

  @override
  String get onboardingDiscoverIntro =>
      '从你喜欢的东西出发，寻找适合你的社交网络服务器和 RASQ 列表（跨社交网络的人员列表）。';

  @override
  String get onboardingDiscoverContentTitle => '从喜欢的图片或内容中寻找';

  @override
  String get onboardingDiscoverContentSubtitle => '选择图片，圈出想搜索的部分';

  @override
  String get onboardingDiscoverPeopleTitle => '从热门用户 / 网红中寻找';

  @override
  String get onboardingDiscoverPeopleSubtitle => '通过喜欢的人的名字或领域';

  @override
  String get onboardingDiscoverExportTitle => '从其他社交网络的导出数据中寻找';

  @override
  String get onboardingDiscoverExportSubtitle => '即将推出';

  @override
  String get onboardingDiscoverAskTitle => '问问 RAi';

  @override
  String get onboardingDiscoverAskSubtitle => '边聊边寻找适合你的社交网络';

  @override
  String get onboardingDiscoverRaiBlocked => '监护人已禁用 RAi';

  @override
  String onboardingDiscoverCannotLogin(String host) {
    return '无法从应用登录 $host';
  }

  @override
  String onboardingDiscoverCannotSignup(String host) {
    return '无法从应用注册 $host';
  }

  @override
  String get onboardingDiscoverAddAccountBlocked => '监护人已禁止添加 SNS 账号';

  @override
  String get onboardingDiscoverDummyResult => '这是示例结果（服务器的外部服务尚未配置）';

  @override
  String get onboardingDiscoverPeopleWebHeading => '社交网络上的人（网页搜索）';

  @override
  String get onboardingDiscoverListsHeading => 'RASQ 列表';

  @override
  String get onboardingDiscoverServersHeading => '服务器';

  @override
  String onboardingDiscoverListMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverListOwner(String handle) {
    return '@$handle 的列表';
  }

  @override
  String onboardingDiscoverListHosts(String hosts) {
    return '服务器：$hosts';
  }

  @override
  String get onboardingDiscoverListSeparator => '、';

  @override
  String get onboardingDiscoverListOpenImport => '打开列表并导入';

  @override
  String get onboardingDiscoverListSignup => '在列表中用户所在的服务器注册';

  @override
  String get onboardingDiscoverLoginButton => '登录';

  @override
  String get onboardingDiscoverSignupButton => '注册';

  @override
  String get onboardingDiscoverSearchFailed => '搜索失败。请稍后再试';

  @override
  String get onboardingDiscoverGlimpseStoppedSystem =>
      '屏幕读取已被停止（设备上的“停止共享”或屏幕锁定）。请从“在常用浏览器中浏览并寻找”重新开始';

  @override
  String get onboardingDiscoverGlimpseStoppedShort =>
      '直播停止得太快，未能读取。请先在浏览器中打开想搜索的页面，然后再停止';

  @override
  String get onboardingDiscoverGlimpseStoppedTimeout => '已过 10 分钟，已停止屏幕读取的准备';

  @override
  String get onboardingDiscoverGlimpseStoppedKilled => '屏幕读取被设备停止了。请重新开始';

  @override
  String get onboardingDiscoverGlimpseStoppedEmpty => '未能读取屏幕（未能截取画面）';

  @override
  String get onboardingDiscoverGlimpseFailed => '未能读取屏幕';

  @override
  String get onboardingDiscoverGlimpseBroadcastDenied =>
      '屏幕直播未能开始。如需读取，请再次点按并选择“开始直播”（仅读取停止直播前的 3 秒）';

  @override
  String get onboardingDiscoverGlimpseDenied =>
      '未允许读取屏幕。如需读取，请再次点按并选择“开始”（仅读取点按按钮后的 3 秒）';

  @override
  String get onboardingDiscoverGlimpseNotificationsDenied =>
      '无法显示通知。读取按钮会显示在通知中，请在设备设置中允许 RASQ 的通知';

  @override
  String get onboardingDiscoverGlimpseUnavailable =>
      '此设备无法读取屏幕。请选择图片，或在应用内浏览器中搜索';

  @override
  String get onboardingDiscoverNotificationFailed =>
      '无法显示通知。请在设备设置中允许 RASQ 的通知';

  @override
  String get onboardingDiscoverGlimpseResultMissing => '找不到读取的画面（已过期或已发送）';

  @override
  String onboardingDiscoverPicksFull(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '最多 $max 张图片。请先移除再添加',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickFailed => '无法加载图片';

  @override
  String onboardingDiscoverPicksOver(int over, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      over,
      locale: localeName,
      other: '最多 $max 张图片。有 $over 张未添加',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPicksUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 张图片无法加载',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverNoticeSeparator => '。';

  @override
  String onboardingDiscoverPicksSkipped(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已移除 $count 张超出发送限制（每张 10 MiB、合计 24 MiB、最多 $max 张）的图片',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverImageFormat => '请选择 JPEG / PNG / WebP 图片';

  @override
  String get onboardingDiscoverImageFormatSize =>
      '请选择 10 MiB 以内的 JPEG / PNG / WebP 图片';

  @override
  String get onboardingDiscoverNoCentral => '尚未设置 RASQ Central 的连接地址';

  @override
  String get onboardingDiscoverContentIntro =>
      '选择喜欢的图片并圈出想搜索的部分，RAi 会生成搜索关键词。图片不会保存在服务器上（搜索完成后即丢弃）。';

  @override
  String onboardingDiscoverPicksCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count / $max 张。点按可重新圈选，长按可调整顺序',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickImages => '选择图片';

  @override
  String get onboardingDiscoverAddImages => '添加图片';

  @override
  String get onboardingDiscoverTakePhoto => '拍照';

  @override
  String get onboardingDiscoverSearchOne => '用这张图片搜索';

  @override
  String onboardingDiscoverSearchMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '用这 $count 张图片搜索',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverOtherWays => '其他方式';

  @override
  String get onboardingDiscoverGlimpseButton => '在常用浏览器中浏览并寻找';

  @override
  String get onboardingDiscoverBrowseButton => '在应用内浏览器中寻找';

  @override
  String get onboardingDiscoverGlimpseCancel => '取消';

  @override
  String onboardingDiscoverGlimpseCapturing(int elapsed, int total) {
    return '正在读取屏幕（$elapsed / $total 秒）';
  }

  @override
  String onboardingDiscoverGlimpseDone(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '已读取屏幕 $seconds 秒（$frames 帧）',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverGlimpseDoneDummy(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '已读取屏幕 $seconds 秒（$frames 帧）。目前为试用版，使用的是虚拟画面',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPictureIndex(int index) {
    return '第 $index 张';
  }

  @override
  String onboardingDiscoverFrameIndex(int index) {
    return '第 $index 帧';
  }

  @override
  String get onboardingDiscoverQueryHeading => '搜索关键词';

  @override
  String get onboardingDiscoverNoResults => '未找到合适的列表或服务器';

  @override
  String get onboardingDiscoverPickWhole => '全图';

  @override
  String get onboardingDiscoverPickRect => '矩形';

  @override
  String get onboardingDiscoverPickLasso => '手绘';

  @override
  String get onboardingDiscoverPickRemove => '移除';

  @override
  String get onboardingDiscoverGlimpseDummyNote => '目前为试用版，不读取屏幕，而是发送虚拟画面';

  @override
  String get onboardingDiscoverCaptureFailed => '无法读取此页面';

  @override
  String get onboardingDiscoverBrowseAddressHint => '搜索内容 / URL';

  @override
  String get onboardingDiscoverBrowseCapture => '从此页面寻找';

  @override
  String get onboardingDiscoverManualIntro =>
      '此设备无法在应用内打开浏览器。请在常用浏览器中浏览，然后粘贴页面 URL 和你在意的文字。';

  @override
  String get onboardingDiscoverManualOpenBrowser => '打开浏览器';

  @override
  String get onboardingDiscoverManualUrl => '页面 URL';

  @override
  String get onboardingDiscoverManualText => '在意的文字（可选）';

  @override
  String get onboardingDiscoverManualSubmit => '用此内容搜索';

  @override
  String get onboardingDiscoverPeopleIntro =>
      '请输入喜欢的人的名字或感兴趣的领域。会先从公开的 RASQ 列表中搜索。';

  @override
  String get onboardingDiscoverPeopleQueryLabel => '人名 / 领域';

  @override
  String get onboardingDiscoverPeopleQueryHint => '例如：铁道摄影、插画师';

  @override
  String get onboardingDiscoverPeopleSearch => '搜索';

  @override
  String get onboardingDiscoverPeopleNotFound => '在 RASQ 列表中未找到';

  @override
  String get onboardingDiscoverPeopleNotFoundHint => '试试从喜欢的图片或网页中寻找，或者问问 RAi。';

  @override
  String get onboardingDiscoverPeopleTryContent => '从图片或内容中寻找';

  @override
  String get onboardingDiscoverPeopleBrave => 'RASQ 列表中没有找到，以下是网页搜索找到的候选';

  @override
  String get onboardingDiscoverPersonOpenProfile => '在浏览器中打开个人资料';

  @override
  String get onboardingDiscoverPersonLists => '包含此人的 RASQ 列表';

  @override
  String get onboardingDiscoverAskFailed => '未能回答。请稍后再问一次';

  @override
  String get onboardingDiscoverAskEmptyTitle => '一起寻找适合你的社交网络吧！';

  @override
  String get onboardingDiscoverAskEmptyBody =>
      '告诉我你喜欢什么、想看什么、想和什么样的人交流。我会帮你寻找适合的社交网络服务器和 RASQ 列表。';

  @override
  String get onboardingDiscoverAskEmptyCloud => '对话会发送到 RASQ 服务器上的 RAi（云端）。';

  @override
  String get onboardingDiscoverAskModelLabel => '云端版 RAi';

  @override
  String get onboardingDiscoverAskHint => '你喜欢什么？';

  @override
  String get onboardingDiscoverEditorTitle => '圈选搜索';

  @override
  String onboardingDiscoverEditorTitleStep(String step) {
    return '圈选搜索（$step）';
  }

  @override
  String get onboardingDiscoverEditorHint =>
      '请圈出想搜索的部分。不圈选直接确定，将用整张图片搜索。可用两指缩放和移动。';

  @override
  String get onboardingDiscoverEditorHintSelected => '只裁剪圈选的部分进行搜索。重新绘制会替换圈选。';

  @override
  String get onboardingDiscoverEditorToolRect => '矩形';

  @override
  String get onboardingDiscoverEditorToolLasso => '手绘';

  @override
  String get onboardingDiscoverEditorResetView => '恢复原始大小';

  @override
  String get onboardingDiscoverEditorClear => '清除圈选';

  @override
  String get onboardingDiscoverEditorDoneWhole => '确定（整张图片）';

  @override
  String get onboardingDiscoverEditorDone => '确定';

  @override
  String get onboardingDiscoverGlimpseArmedBroadcast =>
      '屏幕直播已开始。在浏览器中打开想搜索的页面后，请通过屏幕顶部的红色标识（或控制中心）停止直播。仅读取停止前的 3 秒，返回 RASQ 后即可看到结果。';

  @override
  String get onboardingDiscoverGlimpseArmedNotification =>
      '已显示通知。请先在浏览器中打开想搜索的页面，然后点按通知。点按后将读取该页面 3 秒。';

  @override
  String get onboardingDiscoverGlimpseNotificationTitle => '用 RASQ 寻找';

  @override
  String get onboardingDiscoverGlimpseNotificationBody => '点按即可读取当前屏幕 3 秒';

  @override
  String get onboardingDiscoverApiImageFormat => '只能发送 jpeg / png / webp 图片';

  @override
  String get onboardingDiscoverApiImageSize => '图片不能超过 10 MiB';

  @override
  String get onboardingDiscoverApiImageAndFrames => '图片和帧不能同时发送';

  @override
  String onboardingDiscoverApiFramesCount(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '帧最多 $max 张',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverApiFrameFormat => '只能发送 jpeg / png / webp 帧';

  @override
  String get onboardingDiscoverApiFrameSize => '每帧不能超过 10 MiB';

  @override
  String get onboardingDiscoverApiFramesTotal => '帧合计不能超过 24 MiB';

  @override
  String get onboardingDiscoverApiEmpty => '需要图片、正文或 URL 中的任意一项';

  @override
  String get onboardingTourPageSnsTitle => '多个 SNS，集中在一处';

  @override
  String get onboardingTourPageSnsBody =>
      '可以集中使用 Misskey、Mastodon、Bluesky 等账号。有了 RASQ 账号，设置和账号分组也能在其他设备上使用。';

  @override
  String get onboardingTourPageSnsPicture =>
      'Bluesky、Misskey、mixi2、Mastodon 汇集到 RASQ 的插图';

  @override
  String get onboardingTourPageTimelineTitle => '用节点搭建时间线';

  @override
  String get onboardingTourPageTimelineBody =>
      '可以排列节点，按自己的喜好搭建首页时间线。趋势和 Today 也能作为节点放入时间线。';

  @override
  String get onboardingTourPageTimelineNote => '可以通过时间线的齿轮图标更改。';

  @override
  String get onboardingTourPageTimelinePicture =>
      '“SNS 时间线”“获取趋势”“Today”节点纵向排列的插图';

  @override
  String get onboardingTourPageTrendTitle => '趋势和 Today';

  @override
  String get onboardingTourPageTrendBody =>
      '可以在趋势和 Today 中查看当下热门的词语和帖子。初始时将恐惧、厌恶、愤怒限制在 45% 以内，因此带有强烈愤怒或厌恶的帖子在推荐 / 趋势 / Today / 关联时间线中会排名靠后或不再显示。';

  @override
  String get onboardingTourPageTrendNoteSupervised =>
      '此上限可随时更改。在监护期间，会根据监护人的设置进一步限制。';

  @override
  String get onboardingTourPageTrendNote => '此上限可随时更改。';

  @override
  String get onboardingTourPageTrendPicture => '刺激程度雷达图';

  @override
  String get onboardingTourPageAstellTitle => '用 ASTell 以声音相连';

  @override
  String get onboardingTourPageAstellBody =>
      'ASTell 是可以用语音交谈的房间。也可以只收听，从下方的 ASTell 标签页进入。';

  @override
  String get onboardingTourPageAstellPicture => 'ASTell 的天线和表示正在说话的波形';

  @override
  String get onboardingTourPageSwingTitle => '用 Swing 轻松分享';

  @override
  String get onboardingTourPageSwingBody =>
      'Swing 是会随时间消失的帖子。它会送达关注者和 RASQ 列表中的人，并在 1~24 小时后消失。';

  @override
  String get onboardingTourPageSwingNote => '需要 RASQ 账号才能使用。';

  @override
  String get onboardingTourPageSwingPicture => '一排圆形 Swing 图标的插图';

  @override
  String get onboardingTourPageRaiTitle => '不知所措时就问 RAi';

  @override
  String get onboardingTourPageRaiBody =>
      'RAi 是 RASQ 的助手。告诉它你想做什么，它会带你找到按钮的位置，或代你操作。';

  @override
  String get onboardingTourPageRaiPicture => 'RAi 和对话气泡';

  @override
  String get onboardingTourPagePluginsTitle => '用插件扩展';

  @override
  String get onboardingTourPagePluginsBody =>
      'SNS、显示方式和功能都可以通过插件添加。可以在插件商店中查找并安装。';

  @override
  String get onboardingTourPagePluginsPicture => '一排插件卡片的插图';

  @override
  String get onboardingTourTitle => 'RASQ 使用指南';

  @override
  String get onboardingTourSkip => '跳过';

  @override
  String get onboardingTourBack => '返回';

  @override
  String onboardingTourPageSemantics(int number, int total) {
    return '第 $number / $total 页';
  }

  @override
  String get onboardingTourStart => '开始';

  @override
  String get onboardingTourNext => '下一步';

  @override
  String get onboardingTourOpenTendency => '立即查看设置';

  @override
  String get onboardingTourNodeSnsTimeline => 'SNS 时间线';

  @override
  String get onboardingTourNodeTrend => '获取趋势';

  @override
  String get onboardingTourRaiBubble => '我想在时间线中添加列表';

  @override
  String get platformWebRuntimeLoadFailed => '无法加载运行所需的文件（网络 / CDN）';

  @override
  String get platformWebServerNotConfigured => '尚未设置 RASQ 服务器的连接地址';

  @override
  String platformWebDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String platformWebModelLoadFailed(String error) {
    return '无法加载模型：$error';
  }

  @override
  String get pluginsCancel => '取消';

  @override
  String get pluginsClose => '关闭';

  @override
  String get pluginsSwingNotPackage => 'Swing 插件须为 .rasqpkg 或 .wasm';

  @override
  String get pluginsSwingNoRequires => '基于其他插件的子插件无法通过 Swing 分发';

  @override
  String get pluginsSwingSingleOnly => 'Swing 只能分发仅含一个插件的包';

  @override
  String get pluginsPageNotPage => '这不是页面型插件';

  @override
  String pluginsPageSwingRequires(String ids) {
    return '因基于其他插件（$ids），无法通过 Swing 分发';
  }

  @override
  String get pluginsPageSwingChild => '因是其他插件包中的子插件，无法通过 Swing 分发';

  @override
  String pluginsPageSwingSiblings(String names) {
    return '因与子插件（$names）在同一个包中，无法通过 Swing 分发';
  }

  @override
  String pluginsArtifactMismatch(String pluginId) {
    return '$pluginId：重新获取的分发文件与安装时不同，因此不加载（请在商店中重新安装）';
  }

  @override
  String pluginsIsSnsPlugin(String id) {
    return '$id 是 SNS 插件（无法注册到插槽）';
  }

  @override
  String get pluginsManifestMissing => '缺少 plugin.manifest';

  @override
  String get pluginsManifestIdEmpty => 'plugin.manifest.id 为空';

  @override
  String get pluginsSwingSurfaceOnly =>
      'Swing 只能分发用于 Swing 界面（surfaces: swing、solo）的页面型插件';

  @override
  String get pluginsRasqPageSurfaceOnly =>
      '只有用于个人资料界面（surfaces: profile、solo）的页面型插件才能放在 RASQ 页面上';

  @override
  String pluginsIdMismatch(String expected, String actual) {
    return '分发包的目录为 $expected，但 wasm 自称 $actual';
  }

  @override
  String pluginsRegistered(String name, String slots) {
    return '已注册 $name（$slots）';
  }

  @override
  String pluginsRegisterFailed(String error) {
    return '无法注册：$error';
  }

  @override
  String pluginsImageReceiveFailed(String name, String error) {
    return '$name：无法接收图片（$error）';
  }

  @override
  String pluginsSharedNoSession(String name) {
    return '$name：未加入共享会话，无法更改大家的值';
  }

  @override
  String get pluginsMuteAddTitle => '添加静音词';

  @override
  String pluginsMuteAddMessage(String name, String word) {
    return '$name 想将“$word”添加到静音词。';
  }

  @override
  String get pluginsMuteAddConfirm => '添加';

  @override
  String pluginsMuteAdded(String word) {
    return '已将“$word”添加到静音词';
  }

  @override
  String pluginsEffectSendFailed(String name, String error) {
    return '$name：无法发送特效视频（$error）';
  }

  @override
  String pluginsImageScaled(String name) {
    return '$name：为便于编辑已缩小图片';
  }

  @override
  String get pluginsErrorReturned => '插件返回了错误';

  @override
  String get pluginsGenreTone => '色调';

  @override
  String get pluginsGenreProcess => '处理';

  @override
  String get pluginsGenreTransform => '变形';

  @override
  String get pluginsGenreAdd => '添加';

  @override
  String get pluginsGenreDraw => '绘制';

  @override
  String get pluginsTrustFull => '完整';

  @override
  String get pluginsTrustBundled => '完整（内置）';

  @override
  String get pluginsTrustRestricted => '受限';

  @override
  String get pluginsTrustSwing => '受限（Swing）';

  @override
  String get pluginsTrustHint =>
      '用自己的开发者密钥签名的 .rspkg / .rasqpkg 拥有完整功能。rasq build 会进行签名';

  @override
  String get pluginsEditorCancel => '取消';

  @override
  String get pluginsEditorUndo => '撤销';

  @override
  String get pluginsEditorRedo => '重做';

  @override
  String get pluginsEditorDone => '完成';

  @override
  String get pluginsEditorRemove => '删除';

  @override
  String get pluginsEditorBack => '返回';

  @override
  String get pluginsEditorMore => '更多';

  @override
  String get pluginsEditorApplying => '正在应用更改';

  @override
  String get pluginsEditorPreparing => '正在准备编辑器';

  @override
  String get pluginsEditorPleaseWait => '请稍候…';

  @override
  String get pluginsEditorCloseWarningTitle => '要停止编辑吗？';

  @override
  String get pluginsEditorCloseWarningMessage => '更改将不会保存。';

  @override
  String get pluginsEditorCloseWarningConfirm => '停止';

  @override
  String get pluginsEditorCloseWarningCancel => '继续';

  @override
  String get pluginsEditorLayerEdit => '编辑';

  @override
  String get pluginsEditorLayerRotateScale => '旋转和缩放';

  @override
  String get pluginsEditorPaint => '画笔';

  @override
  String get pluginsEditorZoom => '缩放';

  @override
  String get pluginsEditorFreehand => '自由绘制';

  @override
  String get pluginsEditorArrow => '箭头';

  @override
  String get pluginsEditorLine => '直线';

  @override
  String get pluginsEditorRectangle => '矩形';

  @override
  String get pluginsEditorCircle => '圆形';

  @override
  String get pluginsEditorDashLine => '虚线';

  @override
  String get pluginsEditorBlur => '模糊';

  @override
  String get pluginsEditorPixelate => '马赛克';

  @override
  String get pluginsEditorLineWidth => '线条粗细';

  @override
  String get pluginsEditorEraser => '橡皮擦';

  @override
  String get pluginsEditorFill => '填充';

  @override
  String get pluginsEditorOpacity => '不透明度';

  @override
  String get pluginsEditorColor => '颜色';

  @override
  String get pluginsEditorTextHint => '输入文字';

  @override
  String get pluginsEditorText => '文字';

  @override
  String get pluginsEditorTextAlign => '对齐';

  @override
  String get pluginsEditorFontScale => '文字大小';

  @override
  String get pluginsEditorTextBackground => '背景';

  @override
  String get pluginsEditorCropRotate => '裁剪 / 旋转';

  @override
  String get pluginsEditorRotate => '旋转';

  @override
  String get pluginsEditorFlip => '翻转';

  @override
  String get pluginsEditorTilt => '倾斜';

  @override
  String get pluginsEditorTiltHorizontal => '水平';

  @override
  String get pluginsEditorTiltVertical => '垂直';

  @override
  String get pluginsEditorRatio => '比例';

  @override
  String get pluginsEditorReset => '重置';

  @override
  String get pluginsEditorTune => '调整';

  @override
  String get pluginsEditorBrightness => '亮度';

  @override
  String get pluginsEditorContrast => '对比度';

  @override
  String get pluginsEditorSaturation => '饱和度';

  @override
  String get pluginsEditorExposure => '曝光';

  @override
  String get pluginsEditorHue => '色相';

  @override
  String get pluginsEditorTemperature => '色温';

  @override
  String get pluginsEditorFade => '褪色';

  @override
  String get pluginsEditorTint => '色调';

  @override
  String get pluginsEditorFilter => '滤镜';

  @override
  String get pluginsEditorSticker => '贴纸';

  @override
  String get pluginsEditorEmoji => '表情符号';

  @override
  String get pluginsEditorEmojiSearch => '搜索';

  @override
  String get pluginsEditorEmojiRecent => '最近';

  @override
  String get pluginsEditorEmojiSmileys => '笑脸和人物';

  @override
  String get pluginsEditorEmojiAnimals => '动物和自然';

  @override
  String get pluginsEditorEmojiFood => '食物';

  @override
  String get pluginsEditorEmojiActivities => '活动';

  @override
  String get pluginsEditorEmojiTravel => '旅行和地点';

  @override
  String get pluginsEditorEmojiObjects => '物品';

  @override
  String get pluginsEditorEmojiSymbols => '符号';

  @override
  String get pluginsEditorEmojiFlags => '旗帜';

  @override
  String get pluginsMediaCancel => '取消';

  @override
  String get pluginsMediaClose => '关闭';

  @override
  String get pluginsMediaApply => '应用';

  @override
  String pluginsMediaNotSvg(String name) {
    return '$name 没有返回 SVG，因此未使用';
  }

  @override
  String get pluginsMediaPaperDoneMissing => '暂时无法使用（找不到画纸的“完成”）';

  @override
  String get pluginsMediaBarEdit => '编辑工具栏';

  @override
  String get pluginsMediaAudioUnsupported =>
      '此设备无法将音频转为视频（仅限 Android / iOS / macOS）。可以直接以音频形式添加';

  @override
  String pluginsMediaOpenAudioFailed(String error) {
    return '无法打开音频：$error';
  }

  @override
  String pluginsMediaOpenVideoFailed(String error) {
    return '无法打开视频：$error';
  }

  @override
  String pluginsMediaReexportFailed(String error) {
    return '无法重新导出视频：$error';
  }

  @override
  String get pluginsMediaCropWithMovingObject => '裁剪 / 旋转不能与动态对象同时使用。已以静态图片添加';

  @override
  String pluginsMediaExportFailed(String error) {
    return '无法导出视频：$error';
  }

  @override
  String pluginsMediaOverlayFailed(String error) {
    return '无法叠加动态对象，已以静态图片添加：$error';
  }

  @override
  String pluginsMediaFilterNotReceived(String label) {
    return '$label：未能接收滤镜';
  }

  @override
  String pluginsMediaFilterDropped(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个',
    );
    return '$label：绘制内容过多，已省略 $_temp0';
  }

  @override
  String pluginsMediaFiltersFailed(String names) {
    return '未能应用的滤镜：$names（未包含这些处理）';
  }

  @override
  String get pluginsMediaCropWithMovingPost => '裁剪 / 旋转不能与动态帖子同时使用。帖子已以静态图片添加';

  @override
  String get pluginsMediaVideoImageUnreadable => '无法制作视频，已以静态图片添加（无法读取图片）';

  @override
  String pluginsMediaVideoPostFailed(String error) {
    return '无法制作视频，帖子已以静态图片添加：$error';
  }

  @override
  String get pluginsMediaToVideoTitle => '要转换为视频吗？';

  @override
  String pluginsMediaToVideoMessage(String note) {
    return '$note\n选择“制作视频”，将导出为在放置位置播放的视频。选择“以静态图片粘贴”，只粘贴当前图片。';
  }

  @override
  String get pluginsMediaToVideoConfirm => '制作视频';

  @override
  String get pluginsMediaToVideoStill => '以静态图片粘贴';

  @override
  String get pluginsMediaImageUnreadable => '无法读取图片';

  @override
  String get pluginsMediaExportOnDone => '完成后将导出为视频';

  @override
  String get pluginsMediaObjectNote => '帖子';

  @override
  String get pluginsMediaObjectVideo => '视频';

  @override
  String get pluginsMediaObjectImage => '图片';

  @override
  String get pluginsMediaAddImage => '添加图片';

  @override
  String get pluginsMediaAddVideo => '添加视频';

  @override
  String get pluginsMediaVideoLoadFailed => '无法加载视频';

  @override
  String pluginsMediaVideoLoadFailedDetail(
    String ext,
    int bytes,
    String error,
  ) {
    return '无法获取视频（.$ext，$bytes 字节）的第一帧：$error';
  }

  @override
  String get pluginsMediaFirstFrameFailed => '无法获取视频的第一帧';

  @override
  String get pluginsMediaVideoAsObject => '将视频作为对象放置。';

  @override
  String pluginsMediaAddFailed(String error) {
    return '无法添加媒体：$error';
  }

  @override
  String get pluginsMediaAudioConverting => '正在将音频转换为视频…';

  @override
  String pluginsMediaPanelNotEditable(String name) {
    return '$name 无法在此编辑（请在插件面板中操作）';
  }

  @override
  String get pluginsMediaSnapDragUnset => '拖到此处（取消）';

  @override
  String get pluginsMediaSnapDragSet => '拖到此处（设为对齐目标）';

  @override
  String get pluginsMediaSnapPick => '选择对齐目标…';

  @override
  String get pluginsMediaSnapClearAll => '取消所有对齐目标';

  @override
  String get pluginsMediaSnapTitle => '对齐目标';

  @override
  String get pluginsMediaSnapEmpty => '没有已命名的框';

  @override
  String pluginsMediaSnapSize(int width, int height) {
    return '$width × $height';
  }

  @override
  String pluginsMediaSnapSizeAngle(int width, int height, int angle) {
    return '$width × $height，$angle°';
  }

  @override
  String get pluginsMediaPanelNoResult => '无法应用（插件未返回结果）';

  @override
  String get pluginsMediaPanelNoEdits => '此插件没有可编辑项';

  @override
  String pluginsMediaObjectEditSemantics(String title) {
    return '编辑 $title';
  }

  @override
  String get pluginsMediaObjectLoop => '循环播放';

  @override
  String get pluginsMediaObjectLoopSubtitle => '关 = 播放结束后停在最后一帧';

  @override
  String get pluginsMediaObjectSpeed => '播放速度';

  @override
  String get pluginsMediaObjectVolume => '声音';

  @override
  String get pluginsMediaObjectMuted => '静音';

  @override
  String get pluginsMediaObjectOpacity => '不透明度';

  @override
  String get pluginsMediaObjectRemove => '删除此对象';

  @override
  String pluginsMediaFilterAdjustSemantics(String title) {
    return '调整 $title';
  }

  @override
  String get pluginsMediaFilterObjectHint => '在画面上拖动可移动，双指捏合可缩放 / 旋转。';

  @override
  String get pluginsMediaFilterRemove => '移除此滤镜';

  @override
  String get pluginsMediaStickerEmpty => '没有贴纸。在商店中安装后会显示在这里';

  @override
  String get pluginsMediaStickerEmptyDetail =>
      '没有贴纸。在商店中安装素材包（分类“assets”）后会显示在这里。';

  @override
  String get pluginsMediaStickerGenerate => '用插件制作';

  @override
  String get pluginsPaintTitle => '涂鸦';

  @override
  String get pluginsPaintCancel => '取消';

  @override
  String get pluginsPaintDone => '完成';

  @override
  String get pluginsPaintCanvasSemantics => '涂鸦画布';

  @override
  String get pluginsPaintFillLeak => '请点按由线条围成的形状内部';

  @override
  String get pluginsPaintFillOnLine => '请点按线条内侧';

  @override
  String get pluginsPaintFillEmpty => '没有可填充的形状';

  @override
  String get pluginsPaintToolPen => '画笔';

  @override
  String get pluginsPaintToolEraser => '橡皮擦';

  @override
  String get pluginsPaintToolLasso => '套索';

  @override
  String get pluginsPaintToolFill => '填充';

  @override
  String get pluginsPaintUndo => '撤销';

  @override
  String get pluginsPaintRedo => '重做';

  @override
  String get pluginsPaintClear => '全部清除';

  @override
  String get pluginsPaintStabilizer => '防抖';

  @override
  String get pluginsPaintStabilizerOff => '关';

  @override
  String get pluginsPaintEraserCut => '切断';

  @override
  String get pluginsPaintEraserWhole => '整条线';

  @override
  String get pluginsPaintLassoHint => '圈选（线条一半以上在圈内的）';

  @override
  String get pluginsPaintSelectionDelete => '删除';

  @override
  String get pluginsPaintSelectionDuplicate => '复制';

  @override
  String get pluginsPaintSelectionRecolor => '更改颜色';

  @override
  String get pluginsPaintSelectionDeselect => '取消选择';

  @override
  String get pluginsPaintFillHint => '点按由线条围成的形状内部，会在线条下方填色';

  @override
  String pluginsPaintWidthSemantics(String width) {
    return '粗细 $width';
  }

  @override
  String pluginsPaintColorSemantics(String color) {
    return '颜色 $color';
  }

  @override
  String get pluginsPaintNibMili => '针管笔';

  @override
  String get pluginsPaintNibKabura => '卡布拉笔';

  @override
  String get pluginsPaintNibBrush => '毛笔笔尖';

  @override
  String get postThreadSortRelevance => '按相关性';

  @override
  String get postThreadSortReactions => '回应数';

  @override
  String get postThreadSortKeyword => '按关键词';

  @override
  String get postThreadSortDefault => '默认';

  @override
  String get postThreadModeRenotes => '引用（转帖）';

  @override
  String get postThreadModeRenotesShort => '引用';

  @override
  String get postThreadModeReplies => '回复';

  @override
  String get postThreadModeRepliesShort => '回复';

  @override
  String get postThreadModeReactions => '回应';

  @override
  String get postThreadModeReactionsShort => '回应';

  @override
  String get postThreadModeQuotes => '分享（引用帖子）';

  @override
  String get postThreadModeQuotesShort => '分享';

  @override
  String get postBookmarkClipTooltip => '添加到便签（长按）';

  @override
  String get postBookmarkRemoveTooltip => '取消书签（长按添加到便签）';

  @override
  String get postBookmarkAddTooltip => '书签（长按添加到便签）';

  @override
  String get postBookmarkUnsupported => '此服务没有书签功能。长按可添加到便签';

  @override
  String get postBookmarkRemoved => '已移除书签';

  @override
  String get postBookmarkAdded => '已添加书签';

  @override
  String postBookmarkError(String error) {
    return '无法添加书签：$error';
  }

  @override
  String get postReactionsTitle => '回应';

  @override
  String get postReactionsTabReplies => '回复';

  @override
  String get postReactionsTabQuotes => '引用';

  @override
  String get postReactionsTabReactions => '回应';

  @override
  String get postReactionsTabShares => '分享';

  @override
  String get postReactionsBookmarkTooltip => '书签';

  @override
  String get postRepliesEmpty => '没有回复';

  @override
  String get postQuotesEmpty => '没有引用帖子';

  @override
  String get postRepostersEmpty => '没有转帖或引用';

  @override
  String get postReactionsEmpty => '没有回应';

  @override
  String get postReactionsMine => '你';

  @override
  String postDetailNotFoundOnAccount(String account) {
    return '在 $account 上找不到此帖子';
  }

  @override
  String get postDetailTitle => '帖子';

  @override
  String get postDetailOpenedAccount => '打开时使用的账号';

  @override
  String get postDetailNotFound => '帖子不存在';

  @override
  String get postReload => '重新加载';

  @override
  String get postDetailShowReactions => '显示回应';

  @override
  String get postDetailShowMore => '显示更多';

  @override
  String get postRenotesEmpty => '没有转帖';

  @override
  String get postShareAccountTooltip => '用于分享的账号';

  @override
  String get postShareAccountFixedTooltip => '只能用接收到的账号分享';

  @override
  String get postShareSemantics => '分享';

  @override
  String get postShareContentCopied => '已复制内容';

  @override
  String get postShareLinkCopied => '已复制链接';

  @override
  String get postShareDmTitle => '分享到私信';

  @override
  String get postShareClose => '关闭';

  @override
  String get postShareDmNoRooms => '没有私信对象';

  @override
  String postShareAstellShared(String room) {
    return '已分享到“$room”';
  }

  @override
  String get postShareCopyContent => '复制内容';

  @override
  String get postShareCopyLink => '复制链接';

  @override
  String get postShareOtherAccount => '用其他账号分享';

  @override
  String get postSharePluginsHeader => '分享到插件';

  @override
  String get postShareAstellTitle => '分享到 ASTell';

  @override
  String postShareAstellSubtitle(String room) {
    return '将帖子发送到正在参加的房间“$room”';
  }

  @override
  String get postSharePluginsEmpty => '支持分享的插件会显示在这里';

  @override
  String get postSharePluginsEmptyDetail =>
      '声明了 post.share 的插件（以及正在参加的 ASTell）会显示在这里';

  @override
  String get postShareOtherHeader => '其他';

  @override
  String get postShareDmSubtitle => '将链接发送到所选账号的私信';

  @override
  String get postShareOpenBrowser => '在浏览器中打开';

  @override
  String get postMenuCopyLink => '复制链接';

  @override
  String get postMenuUnpin => '取消置顶';

  @override
  String get postMenuPin => '置顶';

  @override
  String get postMenuDetail => '详情';

  @override
  String get postMenuShare => '分享';

  @override
  String get postMenuEditActionBar => '编辑操作栏';

  @override
  String get postMenuUnfavorite => '取消收藏';

  @override
  String get postMenuFavorite => '收藏';

  @override
  String get postMenuAddToClip => '添加到便签';

  @override
  String get postMenuUnfollow => '取消关注';

  @override
  String get postMenuFollow => '关注';

  @override
  String get postMenuUnmute => '取消静音';

  @override
  String get postMenuMute => '静音';

  @override
  String get postMenuUnblock => '取消屏蔽';

  @override
  String get postMenuBlock => '屏蔽';

  @override
  String get postMenuReport => '举报';

  @override
  String get postMenuDelete => '删除';

  @override
  String postBlockConfirmTitle(String name) {
    return '要屏蔽 $name 吗？';
  }

  @override
  String get postCancel => '取消';

  @override
  String get postReportConfirmTitle => '要举报此帖子吗？';

  @override
  String get postReportConfirmMessage => '将向服务器管理员举报。';

  @override
  String get postDeleteConfirmTitle => '要删除帖子吗？';

  @override
  String get postDeleteConfirmMessage => '此操作无法撤销。';

  @override
  String postSaveMediaLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': '保存视频',
      'other': '保存图片',
    });
    return '$_temp0';
  }

  @override
  String postSaveDestinationTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': '视频保存位置',
      'other': '图片保存位置',
    });
    return '$_temp0';
  }

  @override
  String get postSaveToPhotosSubtitle => '保存到相册“RASQ”';

  @override
  String get postSaveToFilesIosSubtitle =>
      '“文件”App 的 我的iPad（我的iPhone）› RASQ › 保存';

  @override
  String get postSaveToFilesSubtitle => '选择保存位置';

  @override
  String get postSaveRememberTitle => '以后也使用此保存位置';

  @override
  String get postSaveRememberSubtitle => '可在 设置 → 应用外观 →“图片和视频的保存位置”中更改';

  @override
  String postSaveFailed(String kind, String error) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': '无法保存视频：$error',
      'other': '无法保存图片：$error',
    });
    return '$_temp0';
  }

  @override
  String get profileEditTitle => '更新个人资料';

  @override
  String get profileEditSave => '确定';

  @override
  String get profileEditNotLoggedIn => '未登录 RASQ 账号。';

  @override
  String get profileEditBannerRemove => '移除横幅';

  @override
  String get profileEditBannerPick => '选择横幅';

  @override
  String get profileEditAvatarPick => '选择头像';

  @override
  String get profileEditAvatarRemove => '移除头像';

  @override
  String get profileEditPickImage => '选择图片';

  @override
  String get profileEditNameHint => '输入名称…';

  @override
  String get profileEditBirthdayHint => '生日（YYYY-MM-DD / MM-DD）';

  @override
  String get profileEditBirthdayHintSns => '生日（YYYY-MM-DD）';

  @override
  String get profileEditHandleLabel => '用户名（不含 @，a-z 0-9 _，3～32 个字符）';

  @override
  String get profileEditBioLabel => '自我介绍';

  @override
  String get profileEditBioHint => '自我介绍（最多 500 字）';

  @override
  String get profileEditLocationLabel => '所在地';

  @override
  String get profileEditLinksLabel => '链接';

  @override
  String get profileEditLinkRemove => '删除';

  @override
  String get profileEditLinkCaptionHint => '标题';

  @override
  String get profileEditLinkAdd => '添加';

  @override
  String get profileEditReload => '重新加载';

  @override
  String get profileEditSnsTilesLabel => '在账号页面显示的 SNS 账号';

  @override
  String get profileEditSnsTilesCaption => '“自动”不会显示锁定账号等。浅色的卡片表示目前未显示。';

  @override
  String get profileEditSnsTilesCaptionDetail =>
      '“自动”不会显示锁定账号，以及最近帖子的公开范围以仅关注者为主的账号。浅色的卡片表示目前未显示。更改会立即生效。';

  @override
  String profileEditSnsTileAuto(String state) {
    return '自动（$state）';
  }

  @override
  String get profileEditSnsTileShown => '显示';

  @override
  String get profileEditSnsTileHidden => '隐藏';

  @override
  String profileEditVerified(String method) {
    return '已验证所有者（$method）';
  }

  @override
  String get profileEditVerify => '验证所有者';

  @override
  String get profileEditShowOnSnsLabel => 'SNS 个人资料';

  @override
  String get profileEditShowOnSnsTitle => '在 SNS 个人资料中也显示关联的账号';

  @override
  String get profileEditShowOnSnsSubtitle =>
      '当有人在 RASQ 中查看你的 SNS 个人资料时，显示关联的账号。';

  @override
  String get profileEditShowOnSnsDetail =>
      '当有人在应用中查看你的 SNS 个人资料时，显示此 RASQ 账号以及账号页面上显示的其他账号。自我介绍中已写明的不会重复显示。更改会立即生效。';

  @override
  String get profileEditKeybaseConnect => '关联 Keybase';

  @override
  String get profileEditKeybaseConnectSubtitle => '通过 Keybase 验证身份，并显示在账号页面';

  @override
  String get profileEditKeybaseLinkedSubtitle => '已验证。将显示在账号页面';

  @override
  String get profileEditNotice => '个人资料会显示在公开页面和商店评价中。邮箱和密码请在“安全”中设置。';

  @override
  String get profileEditNoticeDetail =>
      '个人资料会显示在 RASQ 的公开页面和商店评价中。图片会在服务器上缩小后重新保存（不会保留位置信息等）。邮箱地址和密码请在“安全”中设置。';

  @override
  String get profileEditErrorHandleTaken => '该用户名已被使用';

  @override
  String get profileEditErrorHandle => '用户名须为 3～32 个 a-z 0-9 _ 字符';

  @override
  String get profileEditErrorBirthday => '请以 YYYY-MM-DD 或 MM-DD 格式输入生日';

  @override
  String get profileEditErrorLink => '链接须为标题（最多 40 字）与 http(s) URL 的组合（最多 8 组）';

  @override
  String get profileEditErrorImage =>
      '无法使用该图片（PNG / JPEG / WebP / GIF，最大 8 MiB）';

  @override
  String get profileEditErrorBio => '自我介绍最多 500 字';

  @override
  String get profileEditErrorLocation => '所在地最多 60 字';

  @override
  String profileEditErrorFailed(String message) {
    return '更新失败：$message';
  }

  @override
  String get profileEditSnsPostsWithdrawn => '已删除托管的密钥和获取的帖子';

  @override
  String profileEditSnsPostsWithdrawFailed(String message) {
    return '无法删除：$message';
  }

  @override
  String get profileEditSnsPostsNoLogin => '此设备上没有该账号的登录';

  @override
  String get profileEditSnsPostsNoDid => '无法得知此账号的 DID。请重新登录';

  @override
  String get profileEditSnsPostsBlueskyConsentTitle => '在账号页面显示 Bluesky 的帖子';

  @override
  String profileEditSnsPostsBlueskyConsentMessage(String account) {
    return 'RASQ 的服务器将通过 Bluesky 的公开 API 读取 $account 的帖子，使其**在 RASQ 账号页面上任何人都可查看**。\n\n• Bluesky 的帖子原本就是任何人都可阅读的。不导入回复和转发。\n• **不托管登录密钥（应用密码 / 会话）**。交给服务器的只有此账号的 DID 和用户名。\n• 仅限已验证所有者的账号使用（以免显示他人账号的帖子）。\n• 关闭此开关后，获取的帖子将立即删除。';
  }

  @override
  String get profileEditSnsPostsAgreeShow => '同意并显示';

  @override
  String get profileEditCancel => '取消';

  @override
  String get profileEditSnsPostsTokenConsentTitle => '将登录密钥托管给 RASQ';

  @override
  String profileEditSnsPostsTokenConsentMessage(String account) {
    return '为了在账号页面显示 $account 的帖子，**将此 SNS 的登录密钥（访问令牌）托管给 RASQ 的服务器**。\n\n• 你的“公开”和“首页（不公开列出）”帖子将**在 RASQ 账号页面上任何人都可查看**。“首页”并非仅关注者可见。\n• 仅关注者 / 指定用户·私信 / 仅本地 / 公开范围不明的帖子不会导入。\n• 密钥仅用于读取你的帖子。不会用于发帖、关注等操作或其他目的。\n• 密钥使用服务器的密钥加密保存（RASQ 的服务器可以解密）。不会返回给应用或其他人。\n• 关闭此开关后，托管的密钥和获取的帖子将立即删除。\n\n持有此密钥即可操作该账号。如有顾虑，托管后也可以在 SNS 一侧的设置中使此密钥（令牌）失效。';
  }

  @override
  String get profileEditSnsPostsAgreeDeposit => '同意并托管';

  @override
  String profileEditSnsPostsFetched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已获取 $count 条帖子',
    );
    return '$_temp0';
  }

  @override
  String profileEditSnsPostsFetchFailed(String error) {
    return '已托管，但无法获取帖子（$error）';
  }

  @override
  String get profileEditSnsPostsUnsupported => '此服务器暂不支持';

  @override
  String get profileEditSnsPostsVerifyFirst => '请先完成此账号的“验证所有者”';

  @override
  String profileEditSnsPostsDepositFailed(String message) {
    return '无法托管：$message';
  }

  @override
  String get profileEditSnsPostsSwitchTitle => '在账号页面也显示帖子';

  @override
  String profileEditSnsPostsFetchError(String error) {
    return '获取失败：$error';
  }

  @override
  String profileEditSnsPostsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条（公开 / 首页帖子。每 30 分钟更新）',
    );
    return '$_temp0';
  }

  @override
  String get profileEditSnsPostsBlueskySubtitle =>
      'RASQ 的服务器读取 Bluesky 的公开帖子（不托管密钥）';

  @override
  String get profileEditSnsPostsTokenSubtitle =>
      '将 SNS 的登录密钥托管给 RASQ（开启时会进行确认）';

  @override
  String get profileEditSnsPostsCollectionsTitle => '也将此密钥用于 RASQ 列表';

  @override
  String get profileEditSnsPostsCollectionsSubtitle => '用于获取打开的 RASQ 列表及确认能否查看';

  @override
  String get profileEditSnsPostsCollectionsDetail =>
      '打开 RASQ 列表或便签时，用此密钥向 SNS 查询“是否关注列表中的人”，并获取其中成员的公开帖子。与为显示帖子而托管密钥的目的不同，因此需单独选择（默认关闭，选择 / 取消会记录在同意记录中）。';

  @override
  String get profileEditSnsPostsCollectionsConsentTitle => '也将托管的密钥用于 RASQ 列表';

  @override
  String get profileEditSnsPostsCollectionsConsentMessage =>
      '为显示帖子而托管的密钥，也将用于其他目的。\n\n• 打开 RASQ 列表或便签时，用此密钥向 SNS 查询“是否关注列表中的人”（确认能否查看）。\n• 用此密钥获取列表中成员的公开 / 首页帖子。\n• 不会用于发帖、关注等操作。\n• 关闭此开关后，将立即停止使用。';

  @override
  String get profileEditSnsPostsCollectionsAgree => '同意并使用';

  @override
  String profileEditSnsPostsCollectionsFailed(String message) {
    return '无法更改：$message';
  }

  @override
  String get profileOwnershipWhereMisskey =>
      '请将其粘贴到个人简介或个人资料的“附加信息”中的任意一处，然后保存。';

  @override
  String get profileOwnershipWhereMastodon =>
      '请将其粘贴到个人简介或个人资料的“额外字段”中的任意一处，然后保存。';

  @override
  String get profileOwnershipWhereBluesky => '请将其粘贴到个人简介（个人资料说明）中，然后保存。';

  @override
  String get profileOwnershipWhereFields => '请将其粘贴到个人简介或个人资料的任意字段中，然后保存。';

  @override
  String get profileOwnershipWhereBio => '请将其粘贴到个人简介中，然后保存。';

  @override
  String get profileOwnershipErrorNotLinked => '此 SNS 账号未关联到 RASQ 账号';

  @override
  String get profileOwnershipErrorUnsupported => '此 SNS 尚不支持所有者验证';

  @override
  String get profileOwnershipErrorTooMany => '尝试次数过多。请稍候再试';

  @override
  String get profileOwnershipErrorNotStarted => '尚未创建验证文本，或已过期。请从“创建验证文本”重新开始';

  @override
  String get profileOwnershipErrorCodeNotFound =>
      '未在个人资料中找到验证文本。请确认是否已保存，以及是否显示在公开的个人资料中（反映可能需要一些时间）';

  @override
  String get profileOwnershipErrorProfileNotFound => '找不到该 SNS 账号的公开个人资料';

  @override
  String get profileOwnershipErrorReadFailed => '无法读取该 SNS 的个人资料。请稍候再试';

  @override
  String profileOwnershipErrorFailed(String message) {
    return '无法验证：$message';
  }

  @override
  String get profileOwnershipKeybaseErrorUsername =>
      '请输入 Keybase 用户名（小写英文字母、数字、_,2~16 个字符）';

  @override
  String get profileOwnershipKeybaseErrorSignature =>
      '无法读取签名。请将从 BEGIN KEYBASE SALTPACK SIGNED MESSAGE 到 END KEYBASE SALTPACK SIGNED MESSAGE. 的内容原样粘贴';

  @override
  String get profileOwnershipKeybaseErrorStatement => '签名的文本不一致。请原样使用上面的命令';

  @override
  String get profileOwnershipKeybaseErrorKey => '未使用该 Keybase 用户的密钥签名';

  @override
  String get profileOwnershipKeybaseErrorNoUser => '找不到该 Keybase 用户';

  @override
  String get profileOwnershipKeybaseErrorOtherAccount =>
      '该 Keybase 已关联到其他 RASQ 账号';

  @override
  String get profileOwnershipKeybaseErrorExpired =>
      '文本已过期或尚未创建。请从“创建要签名的文本”重新开始';

  @override
  String get profileOwnershipKeybaseErrorUnreachable => '无法连接到 Keybase。请稍候再试';

  @override
  String profileOwnershipKeybaseErrorFailed(String message) {
    return '无法确认：$message';
  }

  @override
  String get profileOwnershipVerifyTitle => '验证所有者';

  @override
  String get profileOwnershipNotLinked => '此 SNS 账号未关联到 RASQ 账号。';

  @override
  String profileOwnershipVerified(String method) {
    return '已验证（$method）';
  }

  @override
  String get profileOwnershipJustVerified => '验证成功。可以删除粘贴在个人资料中的文本了。';

  @override
  String get profileOwnershipVerifiedCaption => '账号页面和 SNS 个人资料上会显示已验证标记。';

  @override
  String get profileOwnershipVerifiedCaptionDetail =>
      '账号页面以及 SNS 个人资料中显示的 RASQ 账号栏会显示已验证标记。在解除此 SNS 账号之前会一直保留。';

  @override
  String get profileOwnershipUnsupportedKind =>
      '此 SNS 尚不支持身份验证（仅限 Misskey / Mastodon / Bluesky）。';

  @override
  String get profileOwnershipIntro => '验证此 SNS 账号是否属于你。请将验证文本暂时粘贴到个人资料中。';

  @override
  String get profileOwnershipIntroDetail =>
      '验证此 SNS 账号是否属于你。请将验证文本暂时粘贴到该 SNS 的个人资料中，RASQ 会读取公开的个人资料进行确认。';

  @override
  String get profileOwnershipEffect => '验证后，将显示已验证标记。';

  @override
  String get profileOwnershipEffectDetail =>
      '验证后，账号页面和 SNS 个人资料的 RASQ 账号栏会显示已验证标记。即使其他人也关联了同一 SNS 账号，也以已验证的人为准。';

  @override
  String get profileOwnershipStart => '创建验证文本';

  @override
  String get profileOwnershipStep1 => '1. 复制此文本';

  @override
  String get profileOwnershipCopied => '已复制验证文本';

  @override
  String get profileOwnershipCopy => '复制';

  @override
  String profileOwnershipValidUntil(String time) {
    return '有效期至 $time';
  }

  @override
  String get profileOwnershipStep2 => '2. 粘贴到该 SNS 的个人资料中';

  @override
  String get profileOwnershipNoRewrite => 'RASQ 不会修改你的个人资料。请在该 SNS 上自行粘贴。';

  @override
  String get profileOwnershipStep3 => '3. 粘贴后点按“验证”';

  @override
  String get profileOwnershipCheck => '验证';

  @override
  String get profileOwnershipRestart => '重新创建文本';

  @override
  String get profileOwnershipKeybaseNoLinks => 'Keybase 证明中没有已关联的 SNS 账号。';

  @override
  String profileOwnershipKeybaseLinksVerified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '通过 Keybase 证明，$count 个已关联的 SNS 账号也已验证。',
    );
    return '$_temp0';
  }

  @override
  String profileOwnershipKeybaseLinked(String username, String links) {
    return '已关联 @$username。$links';
  }

  @override
  String get profileOwnershipKeybaseUnlinked =>
      '已解除 Keybase。通过 Keybase 证明验证的 SNS 账号将恢复为未验证。';

  @override
  String profileOwnershipKeybaseVerifiedAt(String time) {
    return '于 $time 验证';
  }

  @override
  String profileOwnershipKeybaseCaption(String username) {
    return '账号页面会显示“Keybase: @$username”。';
  }

  @override
  String profileOwnershipKeybaseCaptionDetail(String username) {
    return '账号页面会显示“Keybase: @$username”。在 Keybase 上添加 Mastodon 等证明后，通过“重新读取证明”，已关联的 SNS 账号也会被验证。';
  }

  @override
  String get profileOwnershipKeybaseRefresh => '重新读取证明';

  @override
  String get profileOwnershipKeybaseUnlink => '解除 Keybase';

  @override
  String get profileOwnershipKeybaseIntro =>
      '使用 Keybase 签名，与此 RASQ 账号关联。关联的 Keybase 将会公开。';

  @override
  String get profileOwnershipKeybaseIntroDetail =>
      '使用 Keybase 账号签名，与此 RASQ 账号关联。关联的 Keybase 会显示在账号页面上（与 Keybase 个人资料一样是公开的）。';

  @override
  String get profileOwnershipKeybaseUsername => 'Keybase 用户名';

  @override
  String get profileOwnershipKeybaseStart => '创建要签名的文本';

  @override
  String get profileOwnershipKeybaseStep1 => '1. 在安装了 Keybase 的设备上运行此命令';

  @override
  String get profileOwnershipKeybaseCopied => '已复制命令';

  @override
  String profileOwnershipKeybaseStatement(String statement) {
    return '要签名的文本：$statement';
  }

  @override
  String get profileOwnershipKeybaseStep2 =>
      '2. 粘贴生成的签名，从 BEGIN 到 END … MESSAGE.';

  @override
  String get profileOwnershipKeybaseVerify => '确认';

  @override
  String profilePagePostLimit(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: '帖子最多 $limit 条。请删除旧帖子后再发布',
    );
    return '$_temp0';
  }

  @override
  String get profilePageEdit => '编辑';

  @override
  String get profilePageCompose => '发布到 RASQ';

  @override
  String profilePageNotFound(String handle) {
    return '不存在名为 @$handle 的 RASQ 账号';
  }

  @override
  String profilePageLoadFailed(String message) {
    return '无法加载：$message';
  }

  @override
  String get profilePageLoadFailedShort => '无法加载。';

  @override
  String get profilePageTabPosts => '帖子';

  @override
  String get profilePageTabMedia => '媒体';

  @override
  String get profilePageTabPages => '页面';

  @override
  String get profilePageTabLists => '列表';

  @override
  String get profilePageTabClips => '便签';

  @override
  String get profilePageTabPlugins => '插件';

  @override
  String get profilePageTabReviews => '评价';

  @override
  String get profilePageTileNoDestination => '无法确定此账号的目标位置';

  @override
  String profilePageOpenFailed(String url) {
    return '无法打开：$url';
  }

  @override
  String get profilePageListsEmptyMine => '你公开的 RASQ 列表会显示在这里（可在列表画面中创建）。';

  @override
  String get profilePageClipsEmptyMine => '你公开的 RASQ 便签会显示在这里（在便签页面中选择“公开”）。';

  @override
  String get profilePageListsEmpty => '没有公开的列表。';

  @override
  String get profilePageClipsEmpty => '没有公开的便签。';

  @override
  String profilePageSince(String date) {
    return '自 $date 起';
  }

  @override
  String profilePagePinLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '最多只能置顶 $count 条',
    );
    return '$_temp0';
  }

  @override
  String profilePagePinFailed(String message) {
    return '无法置顶：$message';
  }

  @override
  String get profilePagePinned => '置顶帖子';

  @override
  String profilePagePostsNote(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: 'RASQ 帖子最多 $limit 条（$used / $limit）。托管登录密钥后，SNS 帖子也会一起显示。',
    );
    return '$_temp0';
  }

  @override
  String profilePagePostsNoteDetail(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          '以 RASQ 账号发布的帖子目前最多 $limit 条（$used / $limit）。将 SNS 账号的访问令牌托管给 RASQ 后，该账号的帖子也会一起显示在这里。',
    );
    return '$_temp0';
  }

  @override
  String get profilePageSnsHintTitle => '已关联的 SNS 账号的帖子尚未显示在这里。';

  @override
  String get profilePageSnsHint => '在编辑个人资料中开启“在账号页面也显示帖子”后，就会显示在这里。';

  @override
  String get profilePageSnsHintDetail =>
      '在编辑个人资料的“在账号页面显示的 SNS 账号”中，为每个账号开启“在账号页面也显示帖子”（会将该 SNS 的访问令牌托管给 RASQ），其公开 / 首页帖子就会显示在这里。';

  @override
  String get profilePageSnsHintOpen => '前往 SNS 帖子显示设置';

  @override
  String get profilePageNoPostsYet => '还没有帖子。';

  @override
  String get profilePageNoMediaYet => '还没有媒体。';

  @override
  String get profilePageNoReviewsYet => '还没有评价。';

  @override
  String get profilePageNoPluginsPublished => '没有已发布的插件。';

  @override
  String get profilePageImageUrlMissing => '未返回图片 URL';

  @override
  String get profilePageNotConnected => '未连接到 RASQ 服务器';

  @override
  String get profilePagePackageTypeLabel => '插件（.rspkg / .rasqpkg）';

  @override
  String get profilePageImage => '图片';

  @override
  String profilePageImageAlt(String alt) {
    return '（图片：$alt）';
  }

  @override
  String get profilePageMdFallbackTitle => '页面';

  @override
  String get profilePageMdLoadFailed => '无法加载页面';

  @override
  String get profilePageMdToolBold => '粗体';

  @override
  String get profilePageMdToolHeading => '标题';

  @override
  String get profilePageMdToolBullet => '项目符号';

  @override
  String get profilePageMdToolLink => '链接';

  @override
  String get profilePageMdToolCenter => '居中';

  @override
  String get profilePageMdToolBig => '放大';

  @override
  String get profilePageMdToolSmall => '缩小';

  @override
  String get profilePageMdToolSpin => '旋转';

  @override
  String get profilePageMdToolJump => '跳动';

  @override
  String get profilePageMdToolColor => '颜色';

  @override
  String get profilePageMdToolRainbow => '彩虹';

  @override
  String get profilePageMdToolRuby => '注音';

  @override
  String get profilePageMdToolRubyReading => '读音';

  @override
  String profilePageImageUploadFailed(String error) {
    return '无法上传图片：$error';
  }

  @override
  String get profilePageMdTitleRequired => '请输入标题';

  @override
  String get profilePageMdLoginToPublish => '登录 RASQ 账号后即可公开';

  @override
  String get profilePageMdPublished => '已公开';

  @override
  String profilePageMdPublishFailed(String error) {
    return '无法公开：$error';
  }

  @override
  String get profilePageMdDeleteTitle => '删除页面';

  @override
  String get profilePageMdDeleteDraft => '将删除草稿。';

  @override
  String get profilePageMdDeletePublished => '将删除已公开的页面和草稿。此操作无法撤销。';

  @override
  String get profilePageDeleteConfirm => '删除';

  @override
  String get profilePageCancel => '取消';

  @override
  String profilePageMdDeleteFailed(String error) {
    return '无法删除：$error';
  }

  @override
  String get profilePageMdEditTitle => '编辑页面';

  @override
  String get profilePageMdDelete => '删除';

  @override
  String get profilePageMdWrite => '编写';

  @override
  String get profilePageMdPreview => '预览';

  @override
  String get profilePageMdPublish => '公开';

  @override
  String get profilePageMdTitleHint => '标题';

  @override
  String get profilePageMdBodyHint =>
      '使用 Markdown 编写。也可以使用 @提及 / #话题标签 / :表情：/ <center> 等 MFM 标签';

  @override
  String get profilePageMdDraftCaption => '草稿保留在此设备上。点按“公开”即可发布到 RASQ 页面';

  @override
  String get profilePageRasqAccount => 'RASQ 账号';

  @override
  String profilePageViewingVerified(String method) {
    return '此账号的所有者已验证（$method）';
  }

  @override
  String get profilePageVerifiedSemantics => '所有者已验证';

  @override
  String get profilePostLoginToUse => '登录 RASQ 账号后即可使用';

  @override
  String get profilePostLoginToReply => '登录 RASQ 账号后即可回复';

  @override
  String get profilePostLoginToRebroad => '登录 RASQ 账号后即可转播';

  @override
  String get profilePostLoginToQueue => '登录 RASQ 账号后即可 Queue';

  @override
  String get profilePostErrorInstallPack => '从商店安装此素材包后，即可用这张图片 Queue';

  @override
  String get profilePostErrorForbidden => '无法对此帖子执行此操作';

  @override
  String get profilePostErrorRebroadLimit => '此帖子已无法再转播';

  @override
  String get profilePostErrorReplyLimit => '最多只能回复 100 条。请删除旧的回复';

  @override
  String get profilePostErrorGone => '此帖子 / 图片已不存在';

  @override
  String profilePostErrorFailed(String message) {
    return '失败：$message';
  }

  @override
  String get profilePostMenuReactions => '查看回应';

  @override
  String get profilePostMenuCopyLink => '复制链接';

  @override
  String get profilePostMenuOpenBrowser => '在浏览器中打开';

  @override
  String get profilePostMenuEditActions => '编辑操作栏';

  @override
  String get profilePostMenuUnpin => '取消置顶';

  @override
  String get profilePostMenuPin => '置顶';

  @override
  String get profilePostMenuDelete => '删除';

  @override
  String get profilePostLinkCopied => '已复制链接';

  @override
  String get profilePostDeleteTitle => '删除帖子';

  @override
  String get profilePostDeleteMessage => '将删除此帖子及其附带的图片。此操作无法撤销。';

  @override
  String get profilePostDeleteConfirm => '删除';

  @override
  String get profilePostCancel => '取消';

  @override
  String get profilePostQuoteUnavailable => '无法查看被引用的帖子';

  @override
  String get profilePostReply => '回复';

  @override
  String get profilePostRebroad => '转播';

  @override
  String get profilePostRebroadUndo => '取消转播';

  @override
  String get profilePostQuote => '引用';

  @override
  String get profilePostQueue => 'Queue';

  @override
  String get profilePostLike => '点赞';

  @override
  String get profilePostQuoteFollowersOnly => '无法引用仅限关注者的帖子';

  @override
  String profilePostRebroadedBy(String name) {
    return '$name 转播了';
  }

  @override
  String get profilePostReplyToDeleted => '回复已删除的帖子';

  @override
  String get profilePostShare => '分享';

  @override
  String get profilePostCwHide => '隐藏';

  @override
  String get profilePostCwShow => '显示更多';

  @override
  String get profilePostNoPacksTitle => '没有素材包';

  @override
  String get profilePostNoPacksMessage => 'Queue 是使用从商店获取的素材包图片进行的回应。';

  @override
  String get profilePostNoPacksStore => '在商店中查找';

  @override
  String get profilePostClose => '关闭';

  @override
  String profilePostOverlayQueueTooltip(String label) {
    return '$label（长按选择图片）';
  }

  @override
  String get profilePostMenu => '菜单';

  @override
  String get profilePostTitle => '帖子';

  @override
  String get profilePostGone => '此帖子已不存在';

  @override
  String profilePostLoadFailed(String message) {
    return '无法加载：$message';
  }

  @override
  String get profilePostParentDeleted => '原帖子已被删除。';

  @override
  String profilePostRepliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '回复 $count',
    );
    return '$_temp0';
  }

  @override
  String get profilePostNoRepliesYet => '还没有回复。';

  @override
  String get profilePostNoReplies => '没有回复';

  @override
  String get profilePostNoRebroads => '没有转播';

  @override
  String get profilePostNoQuotes => '没有引用';

  @override
  String get profilePostNoQueues => '没有 Queue';

  @override
  String get profilePostReactionsTitle => '回应';

  @override
  String get profilePostYou => '你';

  @override
  String get quickPickEmojiTitle => '快捷表情';

  @override
  String get quickPickEmojiMore => '更多表情';

  @override
  String get quickPickSettingsCaption =>
      '长按回应按钮或编辑器的表情按钮，会在按钮旁弹出面板，显示这里的表情和最近使用的表情。手指不离开屏幕滑动，松开时所在的表情会被添加（插入）。若不滑动直接松开，面板会保持打开，可点按选择。';

  @override
  String get quickPickSettingsAdd => '添加表情';

  @override
  String get quickPickSettingsReset => '恢复默认';

  @override
  String quickPickSettingsRemove(String name) {
    return '移除 $name';
  }

  @override
  String get quickPickSettingsEmpty => '没有表情。面板中只会显示最近使用的表情';

  @override
  String get raiModeInstruction => '指导';

  @override
  String get raiModeAssistant => '助手';

  @override
  String get raiGuideDefaultTitle => '引导';

  @override
  String raiHeldDeclined(String calls) {
    return '未执行（$calls）';
  }

  @override
  String raiAutoDeclined(String title) {
    return '明白了。要通过引导进行“$title”时，请点按“按此步骤引导”';
  }

  @override
  String raiAutoProgress(int step, int total, String text) {
    return '正在自动进行（$step / $total）：$text';
  }

  @override
  String raiAutoAskingDetail(String label) {
    return '选择$label';
  }

  @override
  String raiAutoAskDestination(String title) {
    return '“$title”要导入到哪里？';
  }

  @override
  String raiAutoAskWhich(String label) {
    return '要选哪个$label?';
  }

  @override
  String get raiAutoAskHint => '请从候选中选择，或输入其他词语';

  @override
  String raiAutoNotFoundDetail(String label) {
    return '找不到$label';
  }

  @override
  String raiAutoNotFoundAsk(String label) {
    return '找不到$label。要搜索其他$label吗？';
  }

  @override
  String raiAutoAskWhichCount(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '要选哪个$label?（$count 个）',
    );
    return '$_temp0';
  }

  @override
  String raiAutoCancelled(String title) {
    return '已停止“$title”的自动化';
  }

  @override
  String raiAutoFailedAt(String title, int step, String detail) {
    return '“$title”在第 $step 步停止：$detail';
  }

  @override
  String raiAutoPartlyDone(int done, int step, String text) {
    String _temp0 = intl.Intl.pluralLogic(
      done,
      locale: localeName,
      other: '已用函数完成 $done 个步骤。从第 $step 步“$text”开始有需要点按的部件，将进行引导',
    );
    return '$_temp0';
  }

  @override
  String raiAutoDone(String title) {
    return '已用函数完成“$title”';
  }

  @override
  String get raiInstructionUnknown => '这是我还没学会的操作。请试着问“发帖”“登录”“分享”等。';

  @override
  String get raiAskChoice => '你指的是哪个？请从上面的选项中选择';

  @override
  String get raiNoReply => '没有回应';

  @override
  String raiFailureDevice(String message) {
    return '设备端模型：$message';
  }

  @override
  String raiFailureFallUp(String message) {
    return '上行回退：$message';
  }

  @override
  String raiProposalReady(String title) {
    return '已准备好引导“$title”（可从下方的卡片开始）';
  }

  @override
  String raiProposalReadyStopAt(String title, int step) {
    return '已准备好将引导“$title”进行到第 $step 步（从下方的卡片开始）';
  }

  @override
  String raiHeldNote(String calls) {
    return '（基于获取的信息进行的操作，将在确认后执行：$calls）';
  }

  @override
  String get raiNoReplyParen => '（没有回应）';

  @override
  String raiRestartInjecting(String keys) {
    return '注入获取的信息（$keys）并重新启动模型';
  }

  @override
  String get raiAutoDetailReplaced => '由函数代替';

  @override
  String get raiAutoDetailNoFunction => '没有对应的函数';

  @override
  String get raiAutoDetailGuideParts => '需点按的部件将进行引导';

  @override
  String get raiAutoDetailExplanationOnly => '仅说明';

  @override
  String raiAutoDescribeNoBound(String title) {
    return '“$title”没有可用函数代替的步骤，将通过引导（指示）进行。';
  }

  @override
  String raiAutoDescribeHead(String title) {
    return '我将不显示引导，用函数完成“$title”：';
  }

  @override
  String raiAutoDescribeGuideMark(String detail) {
    return '（从这里开始引导：$detail）';
  }

  @override
  String get raiListSeparator => '、';

  @override
  String raiAutoDescribeFromQuestion(String inputs) {
    return '来自问题：$inputs';
  }

  @override
  String raiAutoDescribeEntrusted(String labels) {
    return '$labels将使用候选中的第一个（因为已交给我处理）';
  }

  @override
  String raiAutoDescribeAskLater(String labels) {
    return '$labels将在执行过程中由你选择';
  }

  @override
  String get raiAutoDescribeConfirm => '如果可以，请点按“执行”。';

  @override
  String raiProposalHead(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '若是“$title”，将按此顺序进行（$count 个步骤）',
    );
    return '$_temp0';
  }

  @override
  String raiProposalFunction(String function) {
    return '〔$function〕';
  }

  @override
  String raiProposalInputs(String inputs) {
    return ' 输入：$inputs';
  }

  @override
  String raiProposalPresets(String presets) {
    return ' 固定：$presets';
  }

  @override
  String get raiModeSemantics => 'RAi 模式';

  @override
  String get raiAskButton => '提问';

  @override
  String get raiInputHint => '遇到困难时，我来帮你！';

  @override
  String raiInputPredicted(String prediction) {
    return '$prediction（按空格键输入）';
  }

  @override
  String get raiCollapse => '收起';

  @override
  String get raiExpand => '展开';

  @override
  String get raiAskMore => '继续提问';

  @override
  String get raiHistoryClose => '关闭历史记录';

  @override
  String get raiHistory => '发言历史';

  @override
  String get raiClose => '关闭 RAi';

  @override
  String get raiNext => '下一步';

  @override
  String get raiDone => '知道了（关闭）';

  @override
  String get raiSpeechClose => '关闭';

  @override
  String get raiHistoryEmpty => '还没有发言';

  @override
  String get raiCopy => '复制';

  @override
  String get raiCopied => '已复制';

  @override
  String raiChatSuspended(int step, int total) {
    return '引导已暂停（第 $step / $total 步）。返回后将继续。';
  }

  @override
  String get raiChatResume => '继续';

  @override
  String get raiChatHeadline => '宏之类的就交给我吧！';

  @override
  String get raiChatIntro => '询问操作方法后，RAi 会指向按钮告诉你。';

  @override
  String get raiChatIntroDetail =>
      '指导：询问操作方法后，RAi 会移动到按钮处并指向它。\n助手：使用设备端模型回答。可从栏中的标签选择模型（宏将在第二期推出）。';

  @override
  String get raiChatRecent => '最近的问题';

  @override
  String get raiChatRejectCandidates => '不是这个（排除候选后重新回答）';

  @override
  String raiChatProposalTitle(String title, int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$title · $steps 个步骤',
    );
    return '$_temp0';
  }

  @override
  String get raiChatSkip => '跳过';

  @override
  String get raiChatGuide => '按此步骤引导';

  @override
  String raiChatGuideTitle(String title) {
    return '引导“$title”';
  }

  @override
  String get raiChatTrace => '流程';

  @override
  String get raiChatShowGraph => '以图表视图显示';

  @override
  String get raiChatApproveHeld => '要执行此操作吗？（这是根据获取的信息得出的操作）';

  @override
  String get raiChatApprove => '交给 RAi 处理吗？';

  @override
  String get raiChatDecline => '取消';

  @override
  String get raiChatRun => '执行';

  @override
  String get raiHomeSidebarSemantics => 'RAi 侧边栏';

  @override
  String get raiHomeClose => '关闭';

  @override
  String get raiHomeNewConversation => '新对话';

  @override
  String get raiHomeHistory => '对话历史';

  @override
  String raiHomeCurrentConversation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '当前对话 · $count 条',
    );
    return '$_temp0';
  }

  @override
  String raiHomeConversationSubtitle(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$when · $count 条',
    );
    return '$_temp0';
  }

  @override
  String get raiHomeDelete => '删除';

  @override
  String get raiHomeHistoryEmpty => '还没有。提问后，对话会保存在这里。';

  @override
  String get raiHomeOther => '其他';

  @override
  String get raiAchievementsTitle => '成就';

  @override
  String raiAchievementsProgress(int unlocked, int total) {
    return '已达成 $unlocked / $total';
  }

  @override
  String get raiHomeMacro => '宏';

  @override
  String get raiHomeMacroSoon => '即将推出';

  @override
  String get raiBarSemantics => 'RAi 栏';

  @override
  String get raiAskCancel => '取消';

  @override
  String raiAskInputHint(String label) {
    return '输入$label';
  }

  @override
  String raiAskInputOtherHint(String label) {
    return '输入其他$label';
  }

  @override
  String get raiAskDone => '确定';

  @override
  String raiAchievementsStats(
    int instructions,
    int assistant,
    int app,
    int completed,
    int repeated,
  ) {
    return '指导 $instructions 次 · 助手 $assistant 次（关于应用 $app 次）· 完成 $completed 次 · 重复提问 $repeated 次';
  }

  @override
  String get raiAchievementAsk1Title => '第一个问题';

  @override
  String get raiAchievementAsk1Description => '询问了 1 次指导';

  @override
  String get raiAchievementAsk10Title => '善于提问';

  @override
  String get raiAchievementAsk10Description => '询问了 10 次指导';

  @override
  String get raiAchievementAsk50Title => 'RAi 常客';

  @override
  String get raiAchievementAsk50Description => '询问了 50 次指导';

  @override
  String get raiAchievementApp5Title => '应用通';

  @override
  String get raiAchievementApp5Description => '与助手聊了 5 次关于应用的话题';

  @override
  String get raiAchievementChat20Title => '话匣子';

  @override
  String get raiAchievementChat20Description => '与助手对话了 20 次';

  @override
  String get raiAchievementDone1Title => '一次完成';

  @override
  String get raiAchievementDone1Description => '按引导完成到最后一步';

  @override
  String get raiAchievementDone10Title => '完成大师';

  @override
  String get raiAchievementDone10Description => '10 次按引导完成到最后';

  @override
  String get raiAchievementAgain3Title => '复习中';

  @override
  String get raiAchievementAgain3Description => '同一操作重复询问了 3 次';

  @override
  String get raiAchievementAuto1Title => '全权交给 RAi';

  @override
  String get raiAchievementAuto1Description => '通过“跳过”交给了 RAi';

  @override
  String get raiTracePortPrev => '上一步';

  @override
  String get raiTracePortState => '状态';

  @override
  String get raiTracePortFunction => '函数';

  @override
  String get raiTracePortResult => '结果';

  @override
  String get raiTracePortNext => '下一步';

  @override
  String get raiTraceStatusDone => '已由函数完成';

  @override
  String get raiTraceStatusSkipped => '已折叠';

  @override
  String get raiTraceStatusGuide => '转为引导';

  @override
  String get raiTraceStatusFailed => '失败';

  @override
  String get raiTraceStatusAsking => '等待选择';

  @override
  String get raiTraceStatusRunning => '执行中';

  @override
  String get raiTraceStatusPending => '未执行';

  @override
  String raiTraceCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '流程 $count 个步骤',
    );
    return '$_temp0';
  }

  @override
  String get raiDiagTitle => '诊断（开发者模式）';

  @override
  String get raiDiag3dOn => '3D RAi:使用';

  @override
  String get raiDiag3dOff => '3D RAi:不使用（以 2D 显示）';

  @override
  String get raiDiag3dOffAndroid =>
      '3D RAi:不使用(Android 默认为 2D。可在开发者模式的“试用 3D RAi(Android)”中开启)';

  @override
  String raiDiag3dFailed(String reason) {
    return '3D RAi:失败，已切换为 2D($reason)';
  }

  @override
  String raiDiagLlm(String phase, String message) {
    return '设备端 LLM:$phase($message)';
  }

  @override
  String raiDiagEmbedding(String phase, String message) {
    return '嵌入模型：$phase($message)';
  }

  @override
  String get raiDiagEmpty => '没有记录的失败';

  @override
  String get raiDiagRetry3d => '再次尝试 3D';

  @override
  String raiFunctionsSettingMissing(String area, String key, String keys) {
    return '“$area”中没有名为“$key”的设置（现有：$keys）';
  }

  @override
  String raiFunctionsSettingNotWritable(String key) {
    return '“$key”不是可以从界面写入的设置';
  }

  @override
  String raiFunctionsSettingNeedsPassword(String key) {
    return '“$key”需要密码，因此 RAi 不会写入';
  }

  @override
  String raiFunctionsSettingLocked(String key) {
    return '“$key”带有禁止操作标签，因此 RAi 不会写入';
  }

  @override
  String raiFunctionsFoldEmpty(String head) {
    return '$head:无结果';
  }

  @override
  String raiFunctionsFoldHead(String head, int total, int shown) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$head（共 $total 条，显示 $shown 条）：',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsUnsupported(String name) {
    return '此 SNS 不支持（$name）';
  }

  @override
  String raiFunctionsNotAutomatable(String name, String alt, String result) {
    return '$name 无法自动化（发送需由用户点按）。改为 $alt:$result';
  }

  @override
  String raiFunctionsUnknown(String name) {
    return '未知的函数：$name';
  }

  @override
  String raiFunctionsFailed(String name, String error) {
    return '$name 失败：$error';
  }

  @override
  String get raiFunctionsNotLoggedInSns => '尚未登录 SNS';

  @override
  String raiFunctionsLineReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '（回应 $count）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsPostsNone => '没有符合条件的帖子';

  @override
  String raiFunctionsPostsHead(int count, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '帖子 $count 条（共 $total 条）：',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsReferenceOperation(String title, String id, String steps) {
    return '操作“$title”($id):$steps';
  }

  @override
  String raiFunctionsReferenceFunction(String id, String does) {
    return '函数 $id:$does';
  }

  @override
  String raiFunctionsReferenceParams(String params) {
    return ' 参数：$params';
  }

  @override
  String get raiFunctionsReferenceParamInput => '输入';

  @override
  String raiFunctionsReferenceParamFixed(String value) {
    return '固定=$value';
  }

  @override
  String raiFunctionsReferenceMissing(String id) {
    return '参考中没有 $id';
  }

  @override
  String raiFunctionsActionMissing(String id) {
    return '没有操作 $id';
  }

  @override
  String raiFunctionsActionNotAllowed(String label) {
    return '“$label”不允许自动化（RAi 不会执行）。请改为按步骤引导，或由用户点按';
  }

  @override
  String raiFunctionsActionDone(String label, String state) {
    return '已执行 $label($state)';
  }

  @override
  String get raiFunctionsActionDoneYes => '已完成';

  @override
  String get raiFunctionsActionDoneNo => '未完成';

  @override
  String get raiFunctionsAstellNoRooms => '没有 ASTell 房间';

  @override
  String raiFunctionsAstellRooms(String rooms) {
    return 'ASTell 房间：$rooms';
  }

  @override
  String get raiFunctionsAstellNoTitle => '没有标题';

  @override
  String raiFunctionsAstellCreated(String title, String id) {
    return '已创建 ASTell“$title”[$id]';
  }

  @override
  String raiFunctionsNotifReaction(String who, String reaction) {
    return '$who 回应了$reaction';
  }

  @override
  String raiFunctionsNotifRepost(String who) {
    return '$who 转帖了';
  }

  @override
  String raiFunctionsNotifQuote(String who) {
    return '$who 引用了';
  }

  @override
  String raiFunctionsNotifReply(String who) {
    return '$who 回复了';
  }

  @override
  String raiFunctionsNotifMention(String who) {
    return '$who 提及了你';
  }

  @override
  String raiFunctionsNotifFollow(String who) {
    return '$who 关注了你';
  }

  @override
  String raiFunctionsNotifFollowRequest(String who) {
    return '$who 发送了关注请求';
  }

  @override
  String raiFunctionsNotifFollowAccepted(String who) {
    return '$who 批准了关注请求';
  }

  @override
  String raiFunctionsNotifListAdded(String who) {
    return '$who 将你加入了列表';
  }

  @override
  String get raiFunctionsNotifPollEnded => '投票已结束';

  @override
  String get raiFunctionsNotifTimer => '定时通知';

  @override
  String get raiFunctionsNotifVc => 'ASTell 通知';

  @override
  String get raiFunctionsNotifSystem => '系统通知';

  @override
  String get raiFunctionsNotifOther => '其他通知';

  @override
  String get raiFunctionsUnreadMark => '（未读）';

  @override
  String get raiFunctionsMissingPostId => '缺少帖子 id(id=)';

  @override
  String get raiFunctionsMissingPostArg => '缺少帖子 id(post=)';

  @override
  String raiFunctionsThreadReply(String line) {
    return '回复：$line';
  }

  @override
  String get raiFunctionsHeadThread => '帖子串';

  @override
  String get raiFunctionsHeadReactions => '回应';

  @override
  String get raiFunctionsHeadReposters => '转帖的人';

  @override
  String get raiFunctionsHeadQuotes => '引用';

  @override
  String get raiFunctionsHeadFavorites => '收藏';

  @override
  String get raiFunctionsHeadReacted => '已回应';

  @override
  String raiFunctionsMe(String user, String plugin) {
    return '我：$user 插件=$plugin';
  }

  @override
  String get raiFunctionsUserIdOrHandle => '请指定 id= 或 handle=';

  @override
  String get raiFunctionsNotFound => '未找到';

  @override
  String raiFunctionsUserCounts(String followers, String following) {
    return ' 关注者 $followers 正在关注 $following';
  }

  @override
  String get raiFunctionsMissingUser => '缺少用户 id(user=)';

  @override
  String raiFunctionsHeadUserPosts(String filter) {
    return '帖子（$filter）';
  }

  @override
  String get raiFunctionsMissingKeyword => '缺少 keyword';

  @override
  String raiFunctionsHeadUserSearch(String keyword) {
    return '用户搜索“$keyword”';
  }

  @override
  String get raiFunctionsHeadFollowing => '关注中';

  @override
  String get raiFunctionsHeadFollowers => '关注者';

  @override
  String get raiFunctionsRelFollowing => '关注中';

  @override
  String get raiFunctionsRelFollowedBy => '关注了你';

  @override
  String get raiFunctionsRelRequested => '请求中';

  @override
  String get raiFunctionsRelMuted => '已静音';

  @override
  String get raiFunctionsRelBlocked => '已屏蔽';

  @override
  String get raiFunctionsRelBlockedBy => '屏蔽了你';

  @override
  String get raiFunctionsRelNone => '无';

  @override
  String raiFunctionsRelation(String flags) {
    return '关系：$flags';
  }

  @override
  String raiFunctionsRequestLine(String user, String id) {
    return '$user [请求 $id]';
  }

  @override
  String raiFunctionsHeadModeration(String kind) {
    return '审核（$kind）';
  }

  @override
  String raiFunctionsHeadNotifications(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '通知（未读 $unread 条）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNotificationsRead => '已将通知标为已读';

  @override
  String raiFunctionsTrendLine(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag（$count 人）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadTrends => '趋势';

  @override
  String raiFunctionsListLine(String name, String id, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name [$id]（$count 人）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadLists => '列表';

  @override
  String get raiFunctionsMissingList => '缺少列表 id(list=)';

  @override
  String get raiFunctionsHeadListMembers => '列表成员';

  @override
  String raiFunctionsClipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '（$count 条）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadClips => '便签';

  @override
  String get raiFunctionsMissingClip => '缺少便签 id(clip=)';

  @override
  String get raiFunctionsHeadClipNotes => '便签内容';

  @override
  String get raiFunctionsHeadFeeds => '动态源';

  @override
  String raiFunctionsDmUnread(int count) {
    return '（未读 $count）';
  }

  @override
  String raiFunctionsHeadEmoji(String keyword) {
    return '表情符号“$keyword”';
  }

  @override
  String get raiFunctionsUnfollowed => '已取消关注';

  @override
  String get raiFunctionsFollowRequested => '已发送关注请求';

  @override
  String get raiFunctionsFollowed => '已关注';

  @override
  String get raiFunctionsListUserArgs => '请指定 list= 和 user=';

  @override
  String get raiFunctionsListAdded => '已加入列表';

  @override
  String get raiFunctionsListRemoved => '已从列表移除';

  @override
  String get raiFunctionsMissingName => '缺少名称（name=）';

  @override
  String raiFunctionsListCreated(String name, String id) {
    return '已创建列表“$name”[$id]';
  }

  @override
  String get raiFunctionsClipPostArgs => '请指定 clip= 和 post=';

  @override
  String get raiFunctionsClipAdded => '已加入便签';

  @override
  String get raiFunctionsClipRemoved => '已从便签移除';

  @override
  String raiFunctionsClipCreated(String name, String id) {
    return '已创建便签“$name”[$id]';
  }

  @override
  String get raiFunctionsAreaKeyArgs => '请指定 area= 和 key=';

  @override
  String raiFunctionsSettingsPageMissing(String area) {
    return '没有设置页面“$area”';
  }

  @override
  String get raiFunctionsAreaKeyValueArgs => '请指定 area=、key= 和 value=';

  @override
  String raiFunctionsSettingBadValue(String key, String value, String current) {
    return '无法将“$key”设为“$value”（当前值：$current）';
  }

  @override
  String raiFunctionsSettingSet(String area, String key, String value) {
    return '已将 $area.$key 设为 $value';
  }

  @override
  String get raiFunctionsMissingText => '缺少正文（text=）';

  @override
  String get raiFunctionsMissingRoom => '缺少房间 id(room=)';

  @override
  String raiFunctionsDmRoomMissing(String id) {
    return '没有 DM 房间 $id';
  }

  @override
  String raiFunctionsComposeFilled(String target) {
    return '已将$target的草稿放入编辑器（尚未发送）';
  }

  @override
  String raiFunctionsFeedNotFound(String feed) {
    return '找不到动态源“$feed”';
  }

  @override
  String raiFunctionsFeedSaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已保存“$name”（已保存 $count 个）',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsFeedUnsaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已取消保存“$name”（已保存 $count 个）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNoBluesky => '没有 Bluesky 账号（自定义动态源仅限 Bluesky）';

  @override
  String raiFunctionsFeedAlreadyHome(String name) {
    return '“$name”已在首页时间线中';
  }

  @override
  String raiFunctionsFeedAddedHome(String name, String account) {
    return '已将“$name”（$account）加入首页时间线';
  }

  @override
  String get raiFunctionsNotLoggedInRasq => '未登录 RASQ 账号';

  @override
  String get raiFunctionsRasqListMine => '自己的';

  @override
  String get raiFunctionsRasqListUnfetchable => '无法导入';

  @override
  String get raiFunctionsRasqListFollowing => '关注中';

  @override
  String raiFunctionsRasqListLine(String name, int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name（$count 人 · $state）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadRasqLists => 'RASQ 列表';

  @override
  String get raiFunctionsMissingListArg => '缺少列表（list=）';

  @override
  String raiFunctionsRasqListNotFound(String query) {
    return '找不到 RASQ 列表“$query”';
  }

  @override
  String get raiFunctionsMissingWord => '缺少关键词（word=）';

  @override
  String get raiFunctionsNotLoggedIn => '未登录';

  @override
  String raiFunctionsWordExcludeAlready(String word) {
    return '已在排除“$word”';
  }

  @override
  String raiFunctionsWordIncludeAlready(String word) {
    return '已在按“$word”筛选';
  }

  @override
  String raiFunctionsWordExcluded(String word, String scope) {
    return '已设置为从 $scope 时间线中排除包含“$word”的帖子';
  }

  @override
  String raiFunctionsWordIncluded(String word, String scope) {
    return '已设置为 $scope 时间线只显示包含“$word”的帖子';
  }

  @override
  String get raiFunctionsFeedKindLabel => '动态源';

  @override
  String get raiFunctionsHeadFeedTimeline => '动态源时间线';

  @override
  String raiFunctionsPageList(String name, String id) {
    return '列表 $name [$id]';
  }

  @override
  String raiFunctionsPageFeed(String name, String uri) {
    return '动态源 $name [$uri]';
  }

  @override
  String get raiFunctionsHeadListsPage => '列表页面';

  @override
  String get raiFunctionsHeadNotificationsPage => '通知';

  @override
  String get raiFunctionsHeadHomeTimeline => '首页时间线';

  @override
  String get raiFunctionsMissingSource => '缺少来源（source=）';

  @override
  String raiFunctionsSeedNoPosts(String label) {
    return '“$label”没有帖子，无法提取特征词';
  }

  @override
  String raiFunctionsSeedNoWords(String label) {
    return '无法从“$label”提取特征词';
  }

  @override
  String get raiFunctionsSeedWordSeparator => '、';

  @override
  String raiFunctionsSeedAdded(String label, String words) {
    return '已将“$label”的特征词（$words）加入趋势倾向（喜欢的类型）';
  }

  @override
  String get raiFunctionsMissingQuery => '缺少搜索词（q=）';

  @override
  String raiFunctionsHeadWeb(String query) {
    return '网页“$query”';
  }

  @override
  String get raiFunctionsNotAutomatableMark => '（无法自动化）';

  @override
  String get raiFunctionsHeadActions => '操作';

  @override
  String get raiModelsTitle => '模型';

  @override
  String get raiModelsClose => '关闭';

  @override
  String get raiModelsRamUnknown => 'RAM:未知';

  @override
  String raiModelsRamFree(String gb) {
    return '（可用 $gb GB）';
  }

  @override
  String raiModelsCaption(String codename, String ram) {
    return '$codename = 在此设备上运行的模型。$ram';
  }

  @override
  String raiModelsCaptionDetail(String codename, String label, String ram) {
    return '$codename = 设备端运行的模型（$label）。$ram';
  }

  @override
  String get raiModelsSectionLocal => '本地';

  @override
  String get raiModelsSectionEmbedding => 'RAi 搜索与帖子嵌入';

  @override
  String get raiModelsPostVisionReady => '关联时间线和时间线算法也会比较帖子的图片';

  @override
  String get raiModelsPostVisionIdle => '关联时间线和时间线算法除了帖子正文外，还能比较图片（请同时安装文本模型）';

  @override
  String get raiModelsSectionEmoji => '表情图片搜索（两个都需要）';

  @override
  String get raiModelsEmojiTextReady => '可以用输入的文字搜索表情图片';

  @override
  String get raiModelsEmojiTextIdle => '可以按含义搜索表情图片（请同时安装图像模型）';

  @override
  String get raiModelsEmojiVisionReady => '在后台逐步读取表情图片（每个服务器 1 次）';

  @override
  String get raiModelsEmojiVisionIdle => '即使表情名称没有意义，也能根据图片内容搜索';

  @override
  String get raiModelsSectionCloud => '云端（设备无法回答时）';

  @override
  String get raiModelsCompletionCaption => '完成率 = 引导或回答顺利进行到最后的比例。';

  @override
  String get raiModelsCompletionCaptionDetail =>
      '完成率 = 操作引导 / 回答成立到最后的比例汇总（仅统计小于 35B 的模型，演示中为“-%”）。';

  @override
  String get raiModelsRateExcluded => '不计入统计';

  @override
  String get raiModelsNotConnected => '未连接';

  @override
  String get raiModelsPhaseNotInstalled => '未下载';

  @override
  String raiModelsPhaseDownloading(int percent) {
    return '正在下载 $percent%';
  }

  @override
  String get raiModelsPhaseReady => '就绪';

  @override
  String get raiModelsPhaseReadyBundled => '就绪（内置）';

  @override
  String get raiModelsPhaseLoading => '正在加载';

  @override
  String get raiModelsPhaseGenerating => '正在生成';

  @override
  String get raiModelsPhaseUnavailable => '无法使用';

  @override
  String get raiModelsPillCloud => '云端';

  @override
  String get raiModelsPillLocal => '本地';

  @override
  String raiModelsCloudLine(String label, String params) {
    return '$label · ${params}B · 云端';
  }

  @override
  String raiModelsCompletionRate(String rate) {
    return '完成率 $rate';
  }

  @override
  String get raiModelsMemoryNotNeeded => '内存：无需设备';

  @override
  String raiModelsMemory(String verdict) {
    return '内存：$verdict';
  }

  @override
  String get raiModelsUse => '使用';

  @override
  String get raiModelsExtract => '解压（内置）';

  @override
  String get raiModelsDownload => '下载';

  @override
  String get raiModelsRelease => '释放内存';

  @override
  String get raiModelsDeleteTitle => '要删除模型吗？';

  @override
  String raiModelsDeleteMessage(String file) {
    return '将从设备中删除 $file。';
  }

  @override
  String get raiModelsDelete => '删除';

  @override
  String get raiModelsCancel => '取消';

  @override
  String raiModelsEmbeddingLine(String file, int size, int dims) {
    return 'onnxruntime · $file · 约 $size MB · $dims 维';
  }

  @override
  String get raiModelsSearchSemantic => '按语义相近程度搜索';

  @override
  String raiModelsSearchSemanticDetail(String label) {
    return '搜索：$label（按语义检索）';
  }

  @override
  String get raiModelsSearchNgram => '目前按词语匹配搜索。下载后对换种说法也更有效';

  @override
  String get raiModelsSearchNgramDetail => '搜索：n-gram 替代（按词语匹配检索。下载后对换种说法也更有效）';

  @override
  String get raiModelsServerTitle => '本地推理服务器';

  @override
  String get raiModelsServerConfigured => '已设置';

  @override
  String get raiModelsServerNotConfigured => '未设置';

  @override
  String get raiModelsServerCaption => '设备端模型无法回答时，将询问这里。';

  @override
  String get raiModelsServerCaptionDetail =>
      '兼容 OpenAI 的聊天 API（llama-server / vLLM 等）。设备端模型失败 / 无响应时，会附上与问题相近的参考资料一并传递。';

  @override
  String get raiModelsServerModelHint => '模型名称（可选）';

  @override
  String get raiModelsRamOk => '可运行';

  @override
  String get raiModelsRamTight => '勉强';

  @override
  String get raiModelsRamNo => '内存不足';

  @override
  String get raiModelsRamUnknownVerdict => '未知';

  @override
  String get raiModelsFallUpNotConnected => '上行回退目标（服务器端）未连接';

  @override
  String raiModelsServerHttpError(int status) {
    return '推理服务器 HTTP $status';
  }

  @override
  String get raiModelsServerNoReply => '推理服务器没有回应';

  @override
  String raiModelsServerUnreachable(String error) {
    return '无法连接到推理服务器：$error';
  }

  @override
  String get raiModelsLlmUnavailableHere => '此环境中无法使用设备端模型';

  @override
  String raiModelsLlamaFetching(String tag) {
    return '正在获取 llama.cpp 运行时（$tag）';
  }

  @override
  String get raiModelsLlamaMissingIos =>
      '未嵌入 llama.cpp（请在 Runner 中添加 llama.xcframework）';

  @override
  String get raiModelsLlamaMissing => '缺少 llama.cpp 库';

  @override
  String raiModelsLlamaFetchFailed(int status) {
    return '无法获取 llama.cpp 运行时（HTTP $status）';
  }

  @override
  String raiModelsStateCheckFailed(String error) {
    return '无法确认模型状态：$error';
  }

  @override
  String get raiModelsExtracting => '正在解压内置模型';

  @override
  String get raiModelsExtractTooLarge => '此设备无法解压内置模型（请下载）';

  @override
  String raiModelsExtractFailed(String error) {
    return '解压失败：$error';
  }

  @override
  String raiModelsDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String raiModelsNotDownloaded(String codename) {
    return '设备端模型（$codename）尚未下载';
  }

  @override
  String get raiModelsDeviceUnavailable => '无法使用设备端模型';

  @override
  String raiModelsFileMissing(String path) {
    return '找不到模型文件：$path';
  }

  @override
  String get raiModelsTimeoutFirstToken => '设备端模型 30 秒内没有回应';

  @override
  String get raiModelsTimeoutOverall => '设备端模型的回应过长，已中断';

  @override
  String get raiModelsOnlyThinking => '设备端模型没有回应（可能仅完成了思考）';

  @override
  String raiModelsGenerateFailed(String error) {
    return '生成失败：$error';
  }

  @override
  String get raiModelsHintSystemPolicy =>
      '“system policy” = 被沙盒 / 库验证拒绝。请使用 Debug 的 entitlements（app-sandbox=false、disable-library-validation）重新构建';

  @override
  String get raiModelsHintGatekeeper =>
      '如果被 Gatekeeper 阻止：请在“系统设置 > 隐私与安全性”中允许，或对 Application Support/llama_cpp 中的 dylib 执行 xattr -dr com.apple.quarantine';

  @override
  String raiModelsLoadFailedLlama(String error) {
    return '无法加载模型（llama.cpp）：$error';
  }

  @override
  String raiModelsLoadFailed(String error) {
    return '无法加载模型：$error';
  }

  @override
  String get raiModelsEmbeddingRasqText => 'RASQ MiniLM（文本）';

  @override
  String get raiModelsEmbeddingMiniLmL12 => 'MiniLM-L12 多语言（paraphrase, int8）';

  @override
  String get raiModelsEmbeddingRasqVision => 'RASQ MobileNet（帖子图片）';

  @override
  String get raiModelsEmbeddingSiglipText => 'SigLIP2 base（文本塔 · int8）';

  @override
  String get raiModelsEmbeddingSiglipVision => 'SigLIP2 base（图像端 · int8）';

  @override
  String raiModelsEmbeddingFailed(String message) {
    return '失败：$message';
  }

  @override
  String get raiModelsEmbeddingUnavailableHere => '此环境中无法使用设备端嵌入模型';

  @override
  String get raiModelsChecksumMismatch => '模型文件已损坏（sha256 不一致）';

  @override
  String get raiModelsSizeMismatch => '模型文件不完整';

  @override
  String get raiModelsCentralNotConfigured => '尚未设置 RASQ 服务器的连接地址';

  @override
  String raiModelsLoadFailedOnnx(String error) {
    return '无法加载模型（onnxruntime）：$error';
  }

  @override
  String get raiModelsWebDisabled => '网络搜索尚不可用';

  @override
  String get raiModelsWebNoKey => '未设置 Brave Search 的密钥';

  @override
  String get raiModelsWebAnswerTitle => '网络答案';

  @override
  String raiModelsWebFailed(String error) {
    return '搜索失败：$error';
  }

  @override
  String get raiModelsNoteNotInstalled => '未下载';

  @override
  String get regionHeading => '居住地区';

  @override
  String get regionCaption => '请选择您居住的国家或地区(自行申报)。如在美国,还需选择所在的州。';

  @override
  String get regionChoose => '请选择';

  @override
  String regionCountryAndState(String country, String state) {
    return '$country · $state';
  }

  @override
  String get regionPickerTitle => '选择居住地区';

  @override
  String get regionStatePickerTitle => '选择州';

  @override
  String get regionSearchHint => '按国家或地区名称搜索';

  @override
  String get regionStateSearchHint => '按州名搜索';

  @override
  String get regionNoMatch => '未找到';

  @override
  String get regionUnavailableBadge => '暂未提供';

  @override
  String get regionUnavailableTitle => '您所在的地区暂未提供 RASQ';

  @override
  String get regionUnavailableBody =>
      'RASQ 目前仅在部分地区提供。您所在的地区无法创建 RASQ 账号。提供服务的地区今后可能会有变化。';

  @override
  String regionUnavailableBodyWith(String region) {
    return 'RASQ 目前仅在部分地区提供。在$region无法创建 RASQ 账号。提供服务的地区今后可能会有变化。';
  }

  @override
  String get regionUnavailableBack => '返回';

  @override
  String get regionRequiredError => '请先选择居住地区,然后重试。';

  @override
  String get relationalPostTitle => '帖子';

  @override
  String relationalEventTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name +$count 人',
    );
    return '$_temp0';
  }

  @override
  String relationalEventCaption(int posts, int members) {
    String _temp0 = intl.Intl.pluralLogic(
      posts,
      locale: localeName,
      other: '$posts 条',
    );
    String _temp1 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members 人',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String relationalEventPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String relationalDurationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小时',
    );
    return '$_temp0';
  }

  @override
  String relationalDurationHoursMinutes(int hours, int minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String relationalDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分钟',
    );
    return '$_temp0';
  }

  @override
  String relationalLookback(String duration) {
    return '正在显示 $duration前为止的对话';
  }

  @override
  String get relationalLookbackReset => '恢复';

  @override
  String get relationalHeader => '按对话分组显示';

  @override
  String relationalHeaderDetail(int bias, int maxMinutes) {
    return '聚合度 $bias / 根据对话节奏最长 $maxMinutes 分钟后沉底';
  }

  @override
  String get relationalTuningTitle => '关系时间线调整';

  @override
  String get relationalRetry => '重新加载';

  @override
  String get relationalEmptyTitle => '目前没有进行中的对话';

  @override
  String get relationalEmptyHint => '关注对象的对话会在这里分组显示。下拉还能查看过去的对话';

  @override
  String get relationalTuningCancel => '取消';

  @override
  String get relationalTuningConfirm => '确定';

  @override
  String get relationalAdvanced => '高级设置';

  @override
  String get relationalSectionLinking => '聚合判定';

  @override
  String get relationalCandidateWindow => '候选窗口';

  @override
  String get relationalCandidateWindowSubtitle => '搜索父帖候选的最近范围';

  @override
  String relationalMinutesValue(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分钟',
    );
    return '$_temp0';
  }

  @override
  String relationalSecondsValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds 秒',
    );
    return '$_temp0';
  }

  @override
  String get relationalSectionWeightsPlain => '权重（普通帖子）';

  @override
  String get relationalWeightContent => '内容相似度';

  @override
  String get relationalWeightEntity => '实体匹配';

  @override
  String get relationalWeightTime => '时间衰减';

  @override
  String get relationalWeightAffinity => '双方亲密度';

  @override
  String get relationalWeightTurn => '轮流发言';

  @override
  String get relationalWeightAnchor => '锚点';

  @override
  String get relationalSectionFlatBonus => '固定加分';

  @override
  String get relationalWeightCommunityPrior => '社群先验 ±';

  @override
  String get relationalSectionLifecycle => '生命周期';

  @override
  String get relationalTentativeHold => '临时 ROOT 保留';

  @override
  String get relationalTentativeHoldSubtitle => '确认为新话题前的保留时间';

  @override
  String get relationalResetDefaults => '恢复默认';

  @override
  String get relationalLinkBias => '聚合度';

  @override
  String get relationalLinkBiasSubtitle => '越低聚合范围越广（阈值按社群自动调整）';

  @override
  String get relationalTauSubtitle => '越大，时间相隔较远的帖子也越容易关联（τ）';

  @override
  String get relationalSectionWeights => '权重';

  @override
  String get relationalSimilarity => '相似性';

  @override
  String get relationalSimilaritySubtitle => '内容相似度 + 实体匹配（明细见高级设置）';

  @override
  String get relationalCloseness => '亲密度';

  @override
  String get relationalClosenessSubtitle => '双方亲密度 + 轮流发言（明细见高级设置）';

  @override
  String get relationalSectionExtra => '附加判定';

  @override
  String get relationalHardAnchor => '强锚点（URL/引用目标）';

  @override
  String get relationalReactive => '反应表达（“确实”“懂了”等）';

  @override
  String get relationalTtlSubtitle => '对话沉底前的时间。根据发帖间隔在此范围内自动调整';

  @override
  String relationalTtlValue(int min, int max) {
    return '$min–$max 分钟';
  }

  @override
  String get searchChildSafePostsBlocked => '监护人已停用帖子搜索';

  @override
  String get searchChildSafeTrendBlocked => '监护人已停用趋势';

  @override
  String get searchTrendSettings => '趋势设置';

  @override
  String get searchTrendCustomize => '自定义趋势页面';

  @override
  String get searchTrendPage => '趋势页面';

  @override
  String get searchTrendMenu => '菜单';

  @override
  String get searchHint => '搜索';

  @override
  String get searchSettings => '搜索设置';

  @override
  String get searchSettingsTendency => '搜索结果的倾向/刺激程度';

  @override
  String get searchSettingsTrendPlugins => '趋势插件设置';

  @override
  String get searchSettingsCacheNetwork => '缓存网络设置';

  @override
  String get searchSettingsComingSoon => '此设置正在准备中。';

  @override
  String get searchSortRelevance => '相关度';

  @override
  String get searchSortNewest => '最新';

  @override
  String get searchSortOldest => '最早';

  @override
  String get searchSortReactions => '回应最多';

  @override
  String get searchPeriodAll => '全部';

  @override
  String get searchPeriodDay => '24小时';

  @override
  String get searchPeriodWeek => '1周';

  @override
  String get searchPeriodMonth => '1个月';

  @override
  String get searchPeriodChip => '期间';

  @override
  String get searchAgoJustNow => '刚刚';

  @override
  String searchAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
    );
    return '$_temp0';
  }

  @override
  String searchAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
    );
    return '$_temp0';
  }

  @override
  String searchAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String get serversOpen => '打开服务器';

  @override
  String serversUsers(String count) {
    return '$count 位用户';
  }

  @override
  String serversPosts(String count) {
    return '$count 条帖子';
  }

  @override
  String get serversRegistrationOpen => '开放注册';

  @override
  String get serversRegistrationClosed => '邀请制 / 停止注册';

  @override
  String get serversStatsSeparator => ' · ';

  @override
  String get serversRaiTitle => 'RAi 分析的用户倾向';

  @override
  String serversRaiSource(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '由云端版 RAi 根据 $count 条公开帖子整理',
    );
    return '$_temp0';
  }

  @override
  String get serversInfoTitle => '服务器信息';

  @override
  String serversInfoUnavailable(String host) {
    return '$host 未提供服务器信息（可能是没有实例的服务，或无法获取）';
  }

  @override
  String serversCountHundredMillions(String value) {
    return '$value亿';
  }

  @override
  String serversCountTenThousands(String value) {
    return '$value万';
  }

  @override
  String get sessionUnnamedDevice => '未命名设备';

  @override
  String get sessionShareAskFirstTitle => '要共享访问令牌并一次性登录 SNS 账号吗？';

  @override
  String sessionShareAskDeviceTitle(String device) {
    return '也要与新设备（$device）共享 SNS 访问令牌吗？';
  }

  @override
  String sessionShareAskFirstMessage(String devices) {
    return '有新设备（$devices）登录了此 RASQ 账号。选择“是”后，SNS 访问令牌将在设备之间以端到端加密（E2E）方式共享，新设备也会登录 SNS 账号。RASQ 的服务器无法读取内容。之后可在“账号安全”中更改。';
  }

  @override
  String sessionShareAskFirstMessageHandle(String devices, String handle) {
    return '有新设备（$devices）登录了 RASQ 账号 @$handle。选择“是”后，SNS 访问令牌将在设备之间以端到端加密（E2E）方式共享，新设备也会登录 SNS 账号。RASQ 的服务器无法读取内容。之后可在“账号安全”中更改。';
  }

  @override
  String get sessionShareAskDeviceMessage =>
      '有新设备登录了此 RASQ 账号。如果不是你本人操作，请选择“否”，并在“账号安全”中将该设备退出登录。';

  @override
  String sessionShareAskDeviceMessageHandle(String handle) {
    return '有新设备登录了 RASQ 账号 @$handle。如果不是你本人操作，请选择“否”，并在“账号安全”中将该设备退出登录。';
  }

  @override
  String get sessionDeviceListSeparator => '、';

  @override
  String get sessionShareYes => '是';

  @override
  String get sessionShareNo => '否';

  @override
  String sessionShareEmailApproved(String device) {
    return '已与通过邮件批准的设备（$device）共享 SNS 访问令牌';
  }

  @override
  String sessionShareImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已使用共享的访问令牌一次性登录 SNS 账号（$count 个）',
    );
    return '$_temp0';
  }

  @override
  String get sessionLoginFailed => '登录失败';

  @override
  String get sessionSanctionLight => '轻度限制';

  @override
  String get sessionSanctionModerate => '中度限制（发言需审查延迟）';

  @override
  String get sessionSanctionSevere => '重度限制（功能停用）';

  @override
  String get sessionSanctionPermanent => '永久冻结';

  @override
  String get sessionSanctionNone => '无限制';

  @override
  String sessionSanctionBlocked(String feature) {
    return '由于账号处置，$feature无法使用。';
  }

  @override
  String sessionSanctionBlockedUntil(String feature, String until) {
    return '由于账号处置，$feature无法使用（至 $until）。';
  }

  @override
  String get sessionFeatureAstellJoin => '加入 ASTell';

  @override
  String get sessionFeatureAstellCreate => '创建 ASTell 房间';

  @override
  String get sessionFeatureAstellShare => '在 ASTell 中共享和聊天';

  @override
  String get sessionFeatureAstellStream => 'ASTell 的屏幕共享和直播';

  @override
  String get sessionFeatureStoreReview => '发布商店评价';

  @override
  String get sessionFeatureAccountFollow => '关注 RASQ 账号';

  @override
  String get sessionFeaturePost => '发帖';

  @override
  String get sessionFeaturePostMedia => '发布带媒体的帖子';

  @override
  String get sessionFeatureDm => '私信';

  @override
  String get sessionFeatureReaction => '回应';

  @override
  String get sessionCentralNotConfigured => '未设置 RASQ Central 的连接目标';

  @override
  String get sessionLogoutSnsHeading => '此 RASQ 账号的 SNS 账号';

  @override
  String get sessionLogoutSnsLogout => '同时退出 SNS 账号';

  @override
  String get sessionLogoutSnsLogoutSubtitle => '从此设备中删除 SNS 登录信息';

  @override
  String get sessionLogoutSnsMoveToLocal => '移至“仅限此设备”';

  @override
  String get sessionLogoutSnsMoveToLocalSubtitle => '可以作为“仅限此设备”的账号继续使用';

  @override
  String get sessionCancel => '取消';

  @override
  String get sessionChildSafeAddBlocked => '监护人已禁止添加 SNS 账号';

  @override
  String get sessionAccountKindLocal => '仅限此设备';

  @override
  String get sessionAccountKindCentral => 'RASQ Central';

  @override
  String get sessionCarryThisAccount => '此 RASQ 账号';

  @override
  String get sessionCarrySemantics => '要添加此设备的 SNS 账号吗？';

  @override
  String sessionCarryTitle(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '要将此设备上打开的 $count 个账号添加到 $account 吗？',
    );
    return '$_temp0';
  }

  @override
  String sessionCarryMessage(String account) {
    return '添加的账号将成为 $account 的 SNS 账号，也会显示在其他设备和 Web 控制台中。未添加的账号保留在“仅限此设备”中（之后用 $account 登录 SNS 时也会被添加）。';
  }

  @override
  String get sessionCarryInBundle => '（之前用此 RASQ 账号关联过）';

  @override
  String get sessionCarryNone => '不添加';

  @override
  String sessionCarryAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添加所选的 $count 个',
    );
    return '$_temp0';
  }

  @override
  String get settingsActionBarTitle => '插件按钮';

  @override
  String get settingsActionBarBackTooltip => '返回';

  @override
  String get settingsActionBarBundleManual => '手动放置（从栏上的 (+) 添加前不显示）';

  @override
  String get settingsActionBarBundleAlone => '单独放在末尾';

  @override
  String settingsActionBarBundleInto(String label, String percent) {
    return '并入“$label”的组合（$percent%）';
  }

  @override
  String get settingsActionBarAutoOnTitle => '打开界面时自动开启';

  @override
  String get settingsActionBarOn => '开';

  @override
  String get settingsActionBarOff => '关';

  @override
  String settingsActionBarAutoDefault(String state) {
    return '默认（$state）';
  }

  @override
  String settingsActionBarAutoDefaultDeclared(String state) {
    return '默认（$state，由插件声明）';
  }

  @override
  String settingsActionBarAutoOverridden(String state) {
    return '已在设置中覆盖（默认为 $state）';
  }

  @override
  String get settingsActionBarEmptyCaption => '从商店添加的插件会显示在这里';

  @override
  String get settingsActionBarIntroCaption => '关闭开关后，所有账号中都不再显示。';

  @override
  String get settingsActionBarIntroDetail =>
      '开关是整个设备的总开关（关闭时在所有账号、所有界面中都不显示，也不会自动运行）。“打开界面时自动开启”是打开该界面那一刻的初始状态（在界面内切换的值不会保留到下次）。';

  @override
  String get settingsActionBarPostTileHeader => '帖子卡片';

  @override
  String get settingsActionBarPostTileEmptyDetail =>
      '声明了 post.action 的插件会显示在这里（从商店添加）';

  @override
  String get settingsActionBarViewerHeader => '全屏';

  @override
  String get settingsActionBarViewerEmptyDetail =>
      '声明了 viewer.overlay 的插件（如二维码识别）会显示在这里';

  @override
  String get settingsActionBarViewerPlacement => '全屏操作栏上的开 / 关按钮';

  @override
  String get settingsActionBarMediaHeader => '编辑界面';

  @override
  String get settingsActionBarMediaEmptyDetail =>
      '声明了 composer.media 的插件会显示在这里';

  @override
  String settingsActionBarFilterPlacement(String placement) {
    return '滤镜 · $placement';
  }

  @override
  String get settingsActionBarComposerTextHeader => '编辑器正文';

  @override
  String get settingsActionBarComposerTextEmptyDetail =>
      '声明了 composer.text 的插件会显示在这里';

  @override
  String get settingsActionBarComposerTextPlacement =>
      '编辑器操作栏上的开 / 关按钮（长按进入设置）';

  @override
  String get settingsActionBarTransformHeader => '帖子加工（自动）';

  @override
  String get settingsActionBarTransformEmptyDetail =>
      '声明了 post.transform 的插件会显示在这里';

  @override
  String get settingsActionBarTransformPlacement => '显示前加工正文（无按钮）';

  @override
  String settingsActionBarThisAccountHeader(String account) {
    return '此账号（$account）';
  }

  @override
  String get settingsActionBarNoAccount => '未选择';

  @override
  String get settingsActionBarThisAccountEmptyCaption => '是否在此账号中显示';

  @override
  String get settingsActionBarThisAccountEmptyDetail => '是否在此账号中显示帖子卡片的按钮';

  @override
  String settingsActionBarSlotSubtitle(String plugin, String tags) {
    return '$plugin · 标签：$tags';
  }

  @override
  String get settingsActionBarThresholdTitle => '合并阈值';

  @override
  String get settingsActionBarThresholdSubtitle => '合并相似按钮的程度';

  @override
  String get settingsActionBarThresholdDetail => '标签相似度达到此值以上时，并入现有按钮的组合';

  @override
  String get settingsActionBarEditButton => '编辑操作栏';

  @override
  String get settingsBackendTitle => 'RASQ 服务器';

  @override
  String get settingsBackendErrorUnparseable =>
      '无法解析连接地址。请按“http://192.168.3.14:8080”或“https://central.example”的格式输入。';

  @override
  String get settingsBackendSaved => '已保存';

  @override
  String get settingsBackendErrorEnterUrl =>
      '请输入连接地址（例：http://192.168.3.14:8080）';

  @override
  String get settingsBackendCentralNotCentralHint =>
      '请在 Central 栏中输入 RASQ Central 的地址，而不是 ORGATE';

  @override
  String settingsBackendCentralConnectFailed(
    String url,
    String error,
    String hint,
  ) {
    return '无法连接（$url）— $error$hint';
  }

  @override
  String settingsBackendCentralOk(String algorithm, String keyHead) {
    return '连接正常 — 签名密钥 $algorithm $keyHead…';
  }

  @override
  String settingsBackendAccountLine(String handle, String displayName) {
    return 'RASQ 账号：@$handle（$displayName）';
  }

  @override
  String get settingsBackendAccountNotCreatedLine =>
      'RASQ 账号：未创建（可通过下方的“打开 RASQ 账号”创建）';

  @override
  String settingsBackendAccountLoadFailedLine(String error) {
    return '无法获取 RASQ 账号 — $error';
  }

  @override
  String get settingsBackendOrgateNotConfiguredLine =>
      'ORGATE：未设置（无法登录 RASQ 账号）';

  @override
  String settingsBackendOrgateOk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个',
    );
    return 'ORGATE：连接正常 — 令牌公钥 $_temp0';
  }

  @override
  String settingsBackendOrgateNoKeys(String url) {
    return 'ORGATE：响应中没有令牌公钥（$url）';
  }

  @override
  String settingsBackendOrgateConnectFailed(String url, String error) {
    return '无法连接到 ORGATE（$url）— $error';
  }

  @override
  String get settingsBackendCaption => 'RASQ 账号和商店所用服务器的连接地址。SNS 的帖子和时间线不经过这里。';

  @override
  String get settingsBackendCaptionDetail =>
      'RASQ Central 是存放公开、共享内容（个人资料、商店、ASTell、帖子、列表等）的服务器；ORGATE 是存放仅本人可见信息（登录、密码、邮箱地址）以及 Mastodon 等登录（OAuth 代理）的服务器。RASQ 账号的登录通过 ORGATE 进行，其令牌也用于 Central。SNS 的帖子和时间线都不经过这两者，由插件直接连接各实例。';

  @override
  String get settingsBackendCentralLabel => 'RASQ Central 的连接地址（留空则沿用 ORGATE）';

  @override
  String get settingsBackendOrgateLabel => 'ORGATE（登录、仅本人信息）的连接地址';

  @override
  String get settingsBackendSaveButton => '保存';

  @override
  String get settingsBackendTestButton => '测试连接';

  @override
  String get settingsBackendCentralDisconnected => 'Central：未连接（无法创建 RASQ 账号）';

  @override
  String get settingsBackendCentralDisconnectedDetail =>
      'Central：未连接 — 插件商店仅有内置插件，无法创建 RASQ 账号（仅限此设备）。';

  @override
  String get settingsBackendOrgateDisconnected => 'ORGATE：未连接（无法登录 RASQ 账号）';

  @override
  String get settingsBackendTestEndpointsSection => '测试用连接地址';

  @override
  String get settingsBackendTestEndpointsTitle =>
      '使用模拟 SNS 和演示用 Central / ORGATE';

  @override
  String get settingsBackendTestEndpointsSubtitle => '用于录制预览';

  @override
  String settingsBackendTestEndpointsDetail(
    String misskeyHost,
    String mastodonHost,
    String blueskyHost,
    String centralPort,
    String orgatePort,
  ) {
    return '用于录制预览。将 Misskey / Mastodon / Bluesky 的 $misskeyHost / $mastodonHost / $blueskyHost 指向此地址的模拟服务，并同时切换 Central（:$centralPort）和 ORGATE（:$orgatePort）';
  }

  @override
  String get settingsBackendTestAddressLabel =>
      '模拟环境的地址（同一台机器为 127.0.0.1，其他机器则为其 IP）';

  @override
  String get settingsBackendTestCaption => '请在 SNS 登录页面的服务器栏中输入上方的主机名。';

  @override
  String get settingsBackendTestCaptionDetail =>
      '各 SNS 在其登录页面的服务器栏中输入上方的主机名（授权页面会自动通过；Bluesky 的 ID / 密码可任意填写）。RASQ 账号请从账号登录进入。切换后，已登录的 SNS 会从下次加载起使用新的连接地址。';

  @override
  String get settingsBackendAccountSection => 'RASQ 账号';

  @override
  String settingsBackendAccountLoadError(String error) {
    return '无法获取账号：$error';
  }

  @override
  String get settingsBackendNoServer => '尚未设置连接地址。';

  @override
  String get settingsBackendAccountNotCreated => '尚未创建 RASQ 账号。';

  @override
  String get settingsBackendOpenAccountButton => '打开 RASQ 账号';

  @override
  String get settingsBackendAccountDeviceOnly =>
      '此账号仅在本设备上有效。可在编辑个人资料中更改用户名和显示名称。';

  @override
  String get settingsBackendBundleSection => '账号组合';

  @override
  String get settingsBackendBundleCaption =>
      '捆绑时只发送 SNS 账号列表。仅在你选择设备间共享、网页版或在账号页面显示帖子时，才会发送登录密钥。';

  @override
  String get settingsBackendBundleCaptionDetail =>
      '捆绑时发送到服务器的只有 SNS 类型、服务器、账号和显示名称。访问令牌仅在你选择设备间共享（端到端加密，服务器无法读取）、网页版保管库（用服务器密钥加密，服务器可以解密）、在账号页面显示帖子（同上）时才会发送（隐私政策第 4 条）。';

  @override
  String get settingsBackendNoSessions => '没有已登录的账号。';

  @override
  String get settingsColumnsTitle => '栏宽';

  @override
  String get settingsColumnsIntroCaption => '在平板电脑或电脑等宽屏上，设置左右栏的宽度。';

  @override
  String get settingsColumnsIntroDetail =>
      '在宽屏（平板 / 桌面 / Web）上，设置小栏（搜索或打开页面的一侧）与大栏（打开的页面）的宽度比例。';

  @override
  String get settingsColumnsSplitHeader => '小栏 / 大栏比例';

  @override
  String settingsColumnsSplitDefault(String hint) {
    return '$hint（默认）';
  }

  @override
  String get settingsColumnsLargeWidthLabel => '大栏宽度';

  @override
  String get settingsColumnsSmallWidthLabel => '小栏宽度';

  @override
  String get settingsColumnsShrinkCaption => '屏幕放不下时会自动缩小。';

  @override
  String settingsColumnsShrinkDetail(String minWidth) {
    return '屏幕太窄放不下时，会保留另一栏至少 $minWidth px，并缩小到使小栏不宽于大栏。';
  }

  @override
  String get settingsColumnsSwingInColumnTitle => '在右栏中打开 Swing';

  @override
  String get settingsColumnsSwingInColumnSubtitle =>
      '关闭时以全屏打开（默认开启。指定全屏的插件的 Swing 始终全屏）';

  @override
  String get settingsColumnsCurrentHeader => '当前屏幕上的宽度';

  @override
  String settingsColumnsPreviewWidths(String small, String large) {
    return '小 $small px / 大 $large px';
  }

  @override
  String get settingsColumnsNarrowCaption => '当前屏幕较窄，因此只有一栏。';

  @override
  String settingsColumnsNarrowDetail(String breakpoint) {
    return '当前屏幕较窄，因此只显示一栏（宽度达到 $breakpoint px 以上时分为小栏 / 大栏）。';
  }

  @override
  String get settingsColumnsPreviewSmall => '小';

  @override
  String get settingsColumnsPreviewLarge => '大';

  @override
  String get settingsCommonSeparator => ' · ';

  @override
  String settingsCommonBullet(String text) {
    return '• $text';
  }

  @override
  String settingsCommonRange(int min, int max) {
    return '$min–$max';
  }

  @override
  String get settingsComposerTitle => '帖子编辑器';

  @override
  String get settingsComposerAutoAccountTitle => '自动选择发帖账号';

  @override
  String get settingsComposerAutoAccountSubtitle => '自动将发布目标切换为符合草稿的账号';

  @override
  String get settingsComposerAutoAccountDetail =>
      '自动将发布目标切换为草稿内容符合发布目标筛选条件的账号（手动选择始终优先）';

  @override
  String get settingsComposerRasqLinkedTitle => '同时发布到 RASQ 账号';

  @override
  String get settingsComposerRasqLinkedSubtitle => '向多个账号发布时，也可以选择 RASQ 账号';

  @override
  String get settingsComposerRasqLinkedDetail =>
      '在多选模式下，也可以选择 RASQ 账号这一行（普通帖子 / 节点联动）。发送方式和筛选在“自定义发布目标”的 RASQ 标签页中设置。超出 RASQ 上限（1000 字 / 6 个附件 / 6 个投票选项 / 3 条帖子）的帖子不会发送到 RASQ';

  @override
  String get settingsEmomTitle => 'EmoM 阈值';

  @override
  String get settingsEmomBandLow => '保守 — 更早隐藏被运营方限制的趋势';

  @override
  String get settingsEmomBandMiddle => '普通';

  @override
  String get settingsEmomBandHigh => '宽松 — 仅隐藏被运营方严格限制的趋势';

  @override
  String get settingsEmomStatusSending => '正在发送…';

  @override
  String get settingsEmomStatusNoAccount => '使用 RASQ 账号登录后即可公开（在此设备上仍可使用）';

  @override
  String get settingsEmomStatusFailed => '发送失败。下次打开时（或重新加载趋势时）将重新发送';

  @override
  String settingsEmomStatusDisclosed(String value) {
    return '已公开（值 $value）';
  }

  @override
  String get settingsEmomStatusPending => '尚未送达';

  @override
  String get settingsEmomStatusNotDisclosed => '未公开';

  @override
  String get settingsEmomIntro =>
      'EmoM 是 RASQ 用于估算帖子和趋势的情绪强度与刺激强度的模型（准备中）。目前，此阈值仅在 RASQ 运营方核实举报并限制趋势时作为参考。';

  @override
  String get settingsEmomThresholdLabel => '阈值';

  @override
  String get settingsEmomScaleLow => '低（更容易隐藏）';

  @override
  String get settingsEmomScaleHigh => '高（不易隐藏）';

  @override
  String settingsEmomExplanation(String defaultValue) {
    return '阈值越高，越能接受刺激性强的话题，被运营方限制的趋势越不容易被隐藏。阈值越低，越早隐藏被限制的趋势。默认值为 $defaultValue。';
  }

  @override
  String get settingsEmomDiscloseTitle => '公开阈值（用作限制的参考）';

  @override
  String get settingsEmomDiscloseSubtitle =>
      '仅将数值发送到 RASQ 的服务器。运营方只使用已公开数值的汇总分布（每个数值有多少人），不会单独查看你的数值。关闭后，将删除已发送的数值。';

  @override
  String get settingsEmomRestrictionExplanation =>
      '运营方以“N%”限制某个趋势时，已公开阈值从低到高约 N% 的人将看不到该趋势。即使不公开，也会用此设备上的阈值进行同样的判定（阈值保存在此设备上）。被设为“对所有人隐藏”的趋势，无论阈值如何都不会显示。被隐藏的趋势只是不再出现在搜索的趋势列表中。';

  @override
  String get settingsHomeTitle => '全部设置';

  @override
  String get settingsHomeSearchHint => '搜索设置和操作';

  @override
  String get settingsHomeSearchClear => '清除';

  @override
  String get settingsHomeSearchError => '无法搜索设置';

  @override
  String get settingsHomeSearchEmpty => '未找到结果';

  @override
  String settingsHomeSearchEmptyHint(String query) {
    return '没有与“$query”匹配的设置。请换个说法，或者问问 RAi';
  }

  @override
  String get settingsHomeSearchOperations => '操作（由 RAi 引导）';

  @override
  String get settingsHomeOtherHeader => '其他设置';

  @override
  String get settingsHomeComposer => '帖子编辑器';

  @override
  String get settingsHomeComposerKeywords => '发帖界面，草稿';

  @override
  String get settingsHomeThemeKeywords => '主题，换肤，深色模式，浅色，颜色，字体';

  @override
  String get settingsHomeAccountImportant => '账号重要设置';

  @override
  String get settingsHomeAccountImportantSubtitle => '更改密码或删除账号请在网页版进行';

  @override
  String get settingsHomeAccountImportantDetail => '重设密码、删除账号等需要密码的操作请在网页版进行';

  @override
  String settingsHomeLogout(String handle) {
    return '退出 @$handle';
  }

  @override
  String get settingsHomeLogoutConfirmTitle => '要退出登录吗？';

  @override
  String get settingsHomeLogoutConfirmMessage => '此账号的插件配置会保留在设备上。';

  @override
  String get settingsHomeLogoutConfirm => '退出登录';

  @override
  String get settingsHomeCancel => '取消';

  @override
  String get settingsHomeOk => '确定';

  @override
  String get settingsHomeGenericTitle => '设置';

  @override
  String get settingsHomeUnknownSection => '未知的设置分区';

  @override
  String get settingsHomeThemeModeSystem => '系统';

  @override
  String get settingsHomeThemeModeLight => '浅色';

  @override
  String get settingsHomeThemeModeDark => '深色';

  @override
  String get settingsHomePlaceholder => '此设置正在准备中。';

  @override
  String get settingsHomePlaceholderDetail =>
      '此设置将在第二层级及以下的规格确定后（M4：FOW/DSL 渲染）实现。';

  @override
  String get settingsHomePageMissing => '此页面不存在';

  @override
  String get settingsHomePageMissingHint => '此账号的 SNS 没有这项设置。';

  @override
  String get settingsHomePageLoadError => '无法加载设置页面';

  @override
  String get settingsHomeRemoteLoadError => '无法从服务器获取设置';

  @override
  String get settingsHomeRemotePermissionHint =>
      '\n\n应用的权限不足。退出后重新登录，即可授予新的权限。';

  @override
  String get settingsHomeSaveFailed => '无法保存';

  @override
  String get settingsHomeChildLocked => '由于处于监护中，此处无法更改（敏感媒体始终隐藏）。';

  @override
  String get settingsHomeTargetAccount => '要设置的账号';

  @override
  String settingsHomeMissingSnsPage(String area) {
    return 'SNS 插件未提供设置页面“$area”';
  }

  @override
  String get settingsLearningTitle => '为算法和社区做贡献';

  @override
  String settingsLearningError(String error) {
    return '操作失败 — $error';
  }

  @override
  String get settingsLearningGrantConfirmButton => '同意并参与';

  @override
  String get settingsLearningGrantPointOptional =>
      '此项为自愿。即使拒绝或退出，RASQ 的功能和付费功能仍可照常使用';

  @override
  String get settingsLearningGrantPointScope => '仅包括你自己发布的公开帖子，以及这些帖子是否属于同一对话';

  @override
  String get settingsLearningGrantPointExcluded =>
      '不会发送他人的帖子、私信、限定公开的帖子、ASTell 的对话、RAi 的提问与回答';

  @override
  String get settingsLearningGrantPointVerifiedOnly => '仅接受已完成所有者验证的 SNS 账号的帖子';

  @override
  String get settingsLearningGrantPointPurpose => '用于改进关联时间线归纳对话的方式';

  @override
  String get settingsLearningGrantPointDeletion => '退出时，会立即删除已发送的数据';

  @override
  String get settingsLearningGrantExtendedNotice =>
      '这是验证用的设置。还会发送对他人帖子的判定和 RAi 的对话。';

  @override
  String get settingsLearningGrantExtendedNoticeDetail =>
      'CENTRAL_LEARNING_SCOPE=extended(S-049 / S-050)。正式环境中不使用。';

  @override
  String get settingsLearningGrantScopeDetail =>
      'D-370 / S-051。从关联 TL 的对话事件中，仅将自己的帖子（可确认为公开的帖子。Bluesky 全部为公开）发送到 POST /me/learning/contributions（v2，self = 自己的 SNS 账号）。Central 会确认所有者验证（sns_links.verified_at），以及所有帖子是否均为 a=-1·vis=public。每次接收时都会重新确认年龄和监护人同意。正文中的 @提及和 URL 会被隐去。';

  @override
  String get settingsLearningGrantReadFullButton => '阅读完整说明';

  @override
  String get settingsLearningGrantAgreeCheckbox => '我已阅读说明，并同意提供数据';

  @override
  String settingsLearningDocumentVersion(String version) {
    return '文档版本：$version';
  }

  @override
  String get settingsLearningAgeTitle => '申报年龄';

  @override
  String get settingsLearningAgeConfirmButton => '申报';

  @override
  String get settingsLearningGuardianConsent => '已获得监护人同意';

  @override
  String get settingsLearningAgeDeclared => '已申报年龄';

  @override
  String get settingsLearningCodeSheetTitle => '使用撤回码撤回';

  @override
  String get settingsLearningCodeConfirmButton => '撤回';

  @override
  String get settingsLearningCodeSheetBody =>
      '请输入同意时发放的撤回码。即使无法登录提供数据的 RASQ 账号，也可以撤回。';

  @override
  String get settingsLearningCodeHint => '撤回码';

  @override
  String get settingsLearningWithdrawnByCode => '已退出。已发送的数据将被删除';

  @override
  String get settingsLearningReasonAgeRequired => '需要申报年龄';

  @override
  String get settingsLearningReasonUnder16 => '需年满 16 岁才能参与';

  @override
  String get settingsLearningReasonGuardianRequired => '16～17 岁的用户需要监护人同意';

  @override
  String get settingsLearningIntroNotice =>
      '你可以发送自己发布的公开帖子，协助改进对话的归纳方式。此项为自愿，可随时退出。';

  @override
  String get settingsLearningIntroNoticeDetail =>
      'D-243 / D-363 / D-370。同意记录在 Central 的 account_consents（kind = learning）中。默认范围（own）下，仅将关联 TL 对话中自己的公开帖子发送到 POST /me/learning/contributions。正式环境中关闭接收（CENTRAL_LEARNING_OPEN=false）。';

  @override
  String get settingsLearningReadAboutTitle => '阅读说明';

  @override
  String get settingsLearningReadAboutSubtitle => '发送的内容、用途和保存期限';

  @override
  String get settingsLearningStatusSection => '状态';

  @override
  String get settingsLearningServerNotConfiguredTitle => '尚未设置 RASQ 服务器的连接地址';

  @override
  String get settingsLearningServerNotConfiguredSubtitle => '设置连接地址后即可查看';

  @override
  String get settingsLearningNoAccountTitle => '尚未创建 RASQ 账号';

  @override
  String get settingsLearningNoAccountSubtitle => '数据提供按 RASQ 账号记录';

  @override
  String settingsLearningLoadError(String error) {
    return '无法获取：$error';
  }

  @override
  String get settingsLearningStatusTitle => '贡献';

  @override
  String get settingsLearningStatusJoined => '参与中';

  @override
  String get settingsLearningStatusNotJoined => '未参与';

  @override
  String get settingsLearningSinceTitle => '同意日期';

  @override
  String get settingsLearningOpenTitle => '接收';

  @override
  String get settingsLearningOpenYes => '接收中';

  @override
  String get settingsLearningOpenNo => '尚未开始';

  @override
  String get settingsLearningAgeUndeclared => '未申报';

  @override
  String get settingsLearningSentTitle => '已发送的数据';

  @override
  String settingsLearningSentValue(int relational, int rai) {
    String _temp0 = intl.Intl.pluralLogic(
      relational,
      locale: localeName,
      other: '$relational 条',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rai,
      locale: localeName,
      other: '$rai 条',
    );
    return '对话 $_temp0 · RAi $_temp1';
  }

  @override
  String get settingsLearningExamplesTitle => '云端判定示例';

  @override
  String settingsLearningExamplesValue(int examples, int hardNegative) {
    String _temp0 = intl.Intl.pluralLogic(
      examples,
      locale: localeName,
      other: '$examples 条',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hardNegative,
      locale: localeName,
      other: '$hardNegative 条',
    );
    return '$_temp0(疑似但不同 $_temp1)';
  }

  @override
  String get settingsLearningPostsLabelsTitle => '帖子 / 标签';

  @override
  String get settingsLearningModelsTitle => '使用这些数据的模型';

  @override
  String get settingsLearningModelsNone => '无';

  @override
  String get settingsLearningModelsSeparator => '、';

  @override
  String get settingsLearningWithdrawTitle => '停止贡献';

  @override
  String get settingsLearningWithdrawMessage => '将立即停止发送数据，并删除已发送的数据。';

  @override
  String get settingsLearningWithdrawConfirm => '停止';

  @override
  String get settingsLearningCancel => '取消';

  @override
  String get settingsLearningWithdrawn => '已撤回';

  @override
  String get settingsLearningDeclareAgeButton => '申报年龄';

  @override
  String get settingsLearningGranted => '已参与。请记下下方的撤回码，即使无法登录也能退出';

  @override
  String get settingsLearningGrantButton => '确认内容并参与';

  @override
  String get settingsLearningGrantClosedButton => '接收尚未开始';

  @override
  String get settingsLearningCodeSection => '撤回码';

  @override
  String get settingsLearningCodeSubtitle => '点按即可复制。即使无法登录，也可以用此码退出';

  @override
  String get settingsLearningCodeCopied => '已复制撤回码';

  @override
  String get settingsLearningCodeStoredOnGrantDevice => '撤回码已保存在同意时使用的设备上。';

  @override
  String get settingsLearningOtherSection => '其他';

  @override
  String get settingsLearningByCodeTitle => '使用撤回码退出';

  @override
  String get settingsLearningByCodeSubtitle => '无法登录时';

  @override
  String get settingsLearningDeletionCaption =>
      '删除账号时，已发送的数据也会被删除。任何人都无法查询他人是否参与。';

  @override
  String get settingsLearningDeletionCaptionDetail =>
      '删除 RASQ 账号时，也会同时开始停止提供并删除已提供的数据（learning_contributions 随 accounts 的删除而删除）。任何人都无法查询他人是否提供了数据（GET /me/learning 只返回自己的状态）。';

  @override
  String get settingsLearningKindsSection => '发送的内容';

  @override
  String get settingsLearningKindRelationalTitle => '自己的公开帖子';

  @override
  String get settingsLearningKindRelationalSubtitleExtended => '在时间线中归纳的对话';

  @override
  String get settingsLearningKindRelationalSubtitle => '在时间线中归纳为对话的你的公开帖子';

  @override
  String get settingsLearningKindRelationalDetailExtended =>
      '对话事件（组）中的公开帖子。按作者判定是否允许用于学习，仅发送已允许作者和自己的帖子。正文中的 @提及和 URL 会被隐去。';

  @override
  String get settingsLearningKindRelationalDetail =>
      'D-370。对话事件中自己的帖子（可确认为公开的帖子），以及这些帖子属于同一对话这一信息（关联标签）。他人的帖子仅发送数量（参与者·帖子数）。';

  @override
  String get settingsLearningUnverifiedNotice =>
      '未完成所有者验证的 SNS 账号的帖子未被接受。可在编辑个人资料中进行验证。';

  @override
  String get settingsLearningUnverifiedButton => '验证';

  @override
  String get settingsLearningKindCloudTitle => '在云端归纳';

  @override
  String get settingsLearningKindCloudSubtitle => '难以判断的对话归纳由云端 RAi 来决定';

  @override
  String get settingsLearningKindCloudDetail =>
      'D-367 / S-050。将设备端引擎在阈值附近决定的关联（帖子 → 对话）发送到 POST /me/relational/judge，根据云端 LLM 的判定重新归纳。仅限作者已允许的组合。判定示例（疑似但不同 = hard_negative，分开但相同 = hard_positive）会保留用于学习，退出后删除。';

  @override
  String get settingsLearningKindRaiSubtitle => '向 RAi 的提问与回答';

  @override
  String get settingsLearningKindRaiDetail =>
      '提问（@提及和 URL 会被隐去）、回答、模式、使用的函数名称、模型 id。不包含他人的帖子。';

  @override
  String get settingsLearningPreloadTitle => '预先加载设备端模型';

  @override
  String get settingsLearningPreloadSubtitle => '加快判定的预检（仅限已下载时）';

  @override
  String get settingsLearningPreloadDetail =>
      '在启动后不久加载 RAi 的设备端模型（默认 Qwen3.5 2B），用于作者的预检。未下载时不会下载（仅按规则预检）。';

  @override
  String get settingsLearningDebugSection => '开发者详细信息';

  @override
  String get settingsLearningDebugActiveTitle => '是否在收集';

  @override
  String get settingsLearningDebugActiveYes => '是';

  @override
  String get settingsLearningDebugActiveNo => '否（请确认同意、接收、监护状态）';

  @override
  String get settingsLearningDebugScopeTitle => '接收范围';

  @override
  String get settingsLearningDebugScopeExtended => 'extended（验证用）';

  @override
  String get settingsLearningDebugScopeOwn => 'own（仅自己的公开帖子）';

  @override
  String get settingsLearningDebugPendingTitle => '等待发送';

  @override
  String settingsLearningDebugPendingValue(String relational, String rai) {
    return '对话 $relational · RAi $rai';
  }

  @override
  String get settingsLearningDebugSentTitle => '本次启动已发送';

  @override
  String settingsLearningDebugSentValue(
    String relational,
    String rai,
    String skipped,
  ) {
    return '对话 $relational · RAi $rai · 跳过 $skipped';
  }

  @override
  String settingsLearningDebugCloudValue(
    String decisions,
    String hardNegative,
    String hardPositive,
    String agree,
    String pending,
    String skipped,
  ) {
    return '判定 $decisions（疑似但不同 $hardNegative · 分开但相同 $hardPositive · 一致 $agree）· 等待 $pending · 跳过 $skipped';
  }

  @override
  String get settingsLearningDebugCloudOff => '关';

  @override
  String get settingsLearningDebugModelTitle => '设备端模型';

  @override
  String get settingsLearningDebugFlushing => '发送中…';

  @override
  String get settingsLearningDebugFlushButton => '立即发送';

  @override
  String get settingsLearningDebugVerdictsSection => '作者判定';

  @override
  String get settingsLearningDebugLogSection => '记录';

  @override
  String get settingsLegalTitle => '帮助与法律声明';

  @override
  String get settingsLegalVersionTitle => '版本';

  @override
  String get settingsLegalHelpTitle => '帮助';

  @override
  String get settingsLegalTourTitle => '再次查看 RASQ 使用指南';

  @override
  String get settingsLegalCookiesTitle => '关于 Cookie';

  @override
  String get settingsLegalPluginTermsHeader => 'SNS 插件条款';

  @override
  String get settingsLegalPluginNoTerms => '未提供条款';

  @override
  String get settingsLegalLicensesHeader => '许可证';

  @override
  String get settingsLegalLicensesTitle => '开源许可证';

  @override
  String get settingsLegalLicensesSubtitle => 'Flutter 及内置库';

  @override
  String get settingsMuteBlockTitle => '静音/屏蔽';

  @override
  String get settingsMuteBlockBlockTab => '屏蔽';

  @override
  String get settingsMuteBlockMuteTab => '静音';

  @override
  String get settingsMuteBlockBlockedUsers => '已屏蔽的用户';

  @override
  String get settingsMuteBlockBlockedWords => '已屏蔽的词语';

  @override
  String get settingsMuteBlockBlockedLists => '已屏蔽的列表';

  @override
  String get settingsMuteBlockComingSoonHint => '准备中';

  @override
  String get settingsMuteBlockComingSoonDetail => '词语/列表屏蔽计划在 M2 后半期推出';

  @override
  String get settingsMuteBlockRetryButton => '重新加载';

  @override
  String get settingsMuteBlockNoBlockedUsers => '没有已屏蔽的用户';

  @override
  String get settingsMuteBlockNoMutedUsers => '没有已静音的用户';

  @override
  String get settingsMuteBlockBlockButton => '屏蔽';

  @override
  String get settingsMuteBlockMuteButton => '静音';

  @override
  String get settingsMuteBlockBlockingButton => '已屏蔽';

  @override
  String get settingsMuteBlockMutingButton => '已静音';

  @override
  String get settingsNotifyTokenTitle => '仅用于通知的访问令牌';

  @override
  String settingsNotifyTokenError(String error) {
    return '操作失败 — $error';
  }

  @override
  String get settingsNotifyTokenCaption => '仅用于接收通知的密钥。无法发帖或操作账号。';

  @override
  String get settingsNotifyTokenCaptionDetail =>
      '通知令牌仅用于接收来自 RASQ 服务器的通知（只能读取发给自己的通知收件箱，无法发帖或操作账号）。宏 / ASTell 用的子令牌也在此签发。';

  @override
  String get settingsNotifyTokenStatusSection => '状态';

  @override
  String get settingsNotifyTokenPushTitle => '推送';

  @override
  String get settingsNotifyTokenPushPending => '即将推出';

  @override
  String get settingsNotifyTokenPushPendingDetail => '虚拟（尚未连接 APNs / FCM）';

  @override
  String get settingsNotifyTokenServerNotConfiguredTitle =>
      '尚未设置 RASQ 服务器的连接地址';

  @override
  String get settingsNotifyTokenServerNotConfiguredSubtitle => '输入连接地址后即可签发';

  @override
  String get settingsNotifyTokenNoAccountTitle => '尚未创建 RASQ 账号';

  @override
  String get settingsNotifyTokenNoAccountSubtitle => '创建后即可签发通知令牌';

  @override
  String settingsNotifyTokenLoadError(String error) {
    return '无法获取：$error';
  }

  @override
  String get settingsNotifyTokenLocalTokenTitle => '此设备的令牌';

  @override
  String get settingsNotifyTokenLocalTokenActive => '有效';

  @override
  String get settingsNotifyTokenLocalTokenNone => '未签发';

  @override
  String get settingsNotifyTokenDevicesTitle => '已注册推送的设备';

  @override
  String settingsNotifyTokenDevicesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return '$_temp0';
  }

  @override
  String get settingsNotifyTokenTestNotFound => '已加入测试通知，但在收件箱中未找到';

  @override
  String settingsNotifyTokenTestFound(
    String title,
    String status,
    int devices,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      devices,
      locale: localeName,
      other: '$devices 台',
    );
    return '已在收件箱中确认：“$title”（$status，$_temp0设备）';
  }

  @override
  String get settingsNotifyTokenTestButton => '发送测试通知';

  @override
  String get settingsNotifyTokenLocalRevoked => '已吊销此设备的令牌';

  @override
  String get settingsNotifyTokenRevokeButton => '吊销';

  @override
  String get settingsNotifyTokenEnabled => '已签发，并已为此设备注册推送';

  @override
  String get settingsNotifyTokenEnableButton => '签发通知令牌并注册此设备';

  @override
  String get settingsNotifyTokenTokensSection => '已签发的令牌';

  @override
  String get settingsNotifyTokenKindRoot => '通知令牌';

  @override
  String get settingsNotifyTokenKindChild => '子令牌';

  @override
  String settingsNotifyTokenLabelSuffix(String label) {
    return '（$label）';
  }

  @override
  String get settingsNotifyTokenThisDevice => '此设备';

  @override
  String settingsNotifyTokenIssuedAt(String time) {
    return '签发于 $time';
  }

  @override
  String get settingsNotifyTokenUnused => '未使用';

  @override
  String settingsNotifyTokenLastUsedAt(String time) {
    return '最后使用 $time';
  }

  @override
  String get settingsNotifyTokenIssueChildTooltip => '签发子令牌（宏 / ASTell 共用）';

  @override
  String get settingsNotifyTokenChildIssued => '已签发子令牌并复制到剪贴板（原始值仅此时可见）';

  @override
  String get settingsNotifyTokenRevoked => '已吊销';

  @override
  String get settingsNotifyTokenStorageCaption => '密钥会安全地保存在此设备中。';

  @override
  String get settingsNotifyTokenStorageCaptionDetail =>
      '原始令牌仅在签发时接收，并保存在设备内的安全区域。服务器上只保留哈希值。吊销父令牌时，其子令牌也会一并吊销。';

  @override
  String get settingsPagesAboutCookiesTitle => '关于 Cookie';

  @override
  String get settingsPagesAboutCookiesSection1Title => 'Cookie';

  @override
  String get settingsPagesAboutCookiesText1 =>
      'iOS、Android 和桌面应用与 RASQ 服务器通信时不使用 Cookie。与 RASQ 服务器的通信使用设备令牌（Authorization 标头），各 SNS 的访问令牌保存在设备内的安全区域。';

  @override
  String get settingsPagesAboutCookiesText2 =>
      'iOS 和 Android 应用中的广告（Google AdMob）使用设备的广告 ID，而不是 Cookie。在首次显示的 Google 同意画面中，你可以选择是否使用个性化广告。';

  @override
  String get settingsPagesAboutCookiesText3 =>
      '在网页版以及 RASQ 公开的个人资料和帖子网页上，Google 会为广告（Google AdSense）使用 Cookie。广告 Cookie 的处理遵循 Google 的政策。';

  @override
  String get settingsPagesAboutCookiesText4 =>
      '在应用内浏览器中打开 SNS 的网页版或注册页面时，遵循该 SNS 对 Cookie 的处理方式。';

  @override
  String get settingsPagesAboutDeveloperTitle => '开发者模式';

  @override
  String get settingsPagesAboutDeveloperEnabledSubtitle =>
      '详细显示画面说明，包括工作原理和发送数据的格式';

  @override
  String get settingsPagesAboutDeveloperEnabledDetail =>
      '开启期间，设置和同意画面会显示原始的详细说明（保存位置的 KV、发送的 JSON 格式等），代替简短的说明。只改变显示，不改变行为。';

  @override
  String get settingsPagesAboutDeveloperNotice1 => '只改变显示。设置和发送的数据不会改变。';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseTitle => '试用屏幕读取（iOS）';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseSubtitle =>
      '在 iPhone / iPad 的“寻找 SNS 服务”中显示“在常用浏览器中浏览并寻找”';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseDetail =>
      '由于在部分设备上，屏幕读取的 Broadcast Upload Extension（ScreenGlimpseBroadcast）不会出现在屏幕录制的选项中（未解决），iOS 上默认隐藏。开启后会显示入口。Android 上始终显示。';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dTitle =>
      '试用 3D RAi(Android)';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dSubtitle =>
      '在 Android 上也以 3D 显示 RAi 吉祥物';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dDetail =>
      '由于有报告称 RAi 在 Android 上无法打开，且怀疑是 3D 基础（flutter_angle）的初始化问题，默认使用 2D。开启后会尝试 3D。若 20 秒后仍未显示或失败，会自动恢复为 2D，并在 RAi 侧边栏的“诊断”中记录原因。iPhone / iPad / Mac 始终使用 3D。';

  @override
  String get settingsPagesAboutHelpTitle => '帮助';

  @override
  String get settingsPagesAboutHelpSection1Title => '使用方法';

  @override
  String get settingsPagesAboutHelpText1 => '不知道如何操作时，请在侧边菜单中询问 RAi。';

  @override
  String get settingsPagesAboutHelpText1Detail =>
      '不知道如何操作时，请询问 RAi。在侧边菜单的 RAi 中，可以使用“指引”（引导到按钮）和“助手”（用设备端模型回答，通过函数代为操作）。';

  @override
  String get settingsPagesAboutHelpRaiTitle => '打开 RAi';

  @override
  String get settingsPagesAboutHelpTourAgain1Title => '再次查看 RASQ 使用指南';

  @override
  String get settingsPagesAboutHelpTourAgain1Subtitle =>
      '功能介绍（时间线、趋势、ASTell、RAi 等）';

  @override
  String get settingsPagesAboutHelpSection2Title => '遇到问题时';

  @override
  String get settingsPagesAboutHelpText2 => '无法登录或发帖时，请确认权限并重新登录。';

  @override
  String get settingsPagesAboutHelpText2Detail =>
      '无法登录或帖子没有送达时，请先在“SNS 插件 → 安全”中确认权限，然后退出登录一次再重新登录。';

  @override
  String get settingsPagesAboutHelpSettingsDslSnsSecurityTitle => '安全（权限和令牌）';

  @override
  String get settingsPagesAboutHelpSettingsServerTitle => 'RASQ 服务器连接目标';

  @override
  String get settingsPagesAboutSubscriptionTitle => '订阅状态';

  @override
  String get settingsPagesAboutSubscriptionSection1Title => 'RASQ 订阅';

  @override
  String get settingsPagesAboutSubscriptionValueRow1Title => '方案';

  @override
  String get settingsPagesAboutSubscriptionValueRow1Value => '免费';

  @override
  String get settingsPagesAboutSubscriptionValueRow2Title => '插件代理';

  @override
  String get settingsPagesAboutSubscriptionValueRow2Value => '未订阅';

  @override
  String get settingsPagesAboutSubscriptionText1 => '付费方案正在准备中。';

  @override
  String get settingsPagesAboutSubscriptionText1Detail =>
      '方案：免费（目前没有订阅方案）。今后将提供与 RASQ 账号关联的付费方案。';

  @override
  String get settingsPagesAppearanceDisplayTitle => '界面显示大小';

  @override
  String get settingsPagesAppearanceDisplaySection1Title => '显示大小';

  @override
  String get settingsPagesAppearanceDisplayTextScaleTitle => '文字和 UI 大小';

  @override
  String get settingsPagesAppearanceDisplayTextScaleSubtitle =>
      '更改整个应用的文字大小（立即生效）';

  @override
  String get settingsPagesAppearanceFabTitle => '＋ 按钮的功能';

  @override
  String get settingsPagesAppearanceFabNotice1 =>
      '可以选择按下 ＋ 时启动的功能。周围的按钮（内圈最多 3 个、外圈最多 4 个）可以长按 ＋（鼠标则悬停），再通过齿轮重新排列。';

  @override
  String get settingsPagesAppearanceFabNotice1Detail =>
      '区域 appearance.fab（<scope>Tap / <scope>Slots = 放置顺序，最多 7 个）。';

  @override
  String get settingsPagesAppearanceFabSection1Title => '在首页按下 ＋ 时';

  @override
  String get settingsPagesAppearanceFabHomeTapPostTitle => '发帖';

  @override
  String get settingsPagesAppearanceFabHomeTapRasqTitle => '发布到 RASQ';

  @override
  String get settingsPagesAppearanceFabHomeTapSwingTitle => '创建 Swing';

  @override
  String get settingsPagesAppearanceFabHomeTapAstellTitle => '创建 ASTell';

  @override
  String get settingsPagesAppearanceFabSection2Title => '在趋势中按下 ＋ 时';

  @override
  String get settingsPagesAppearanceFabSection3Title => '在 ASTell 中按下 ＋ 时';

  @override
  String get settingsPagesAppearanceMfmTitle => '自定义动效与动画';

  @override
  String get settingsPagesAppearanceMfmSection1Title => 'MFM 动画';

  @override
  String get settingsPagesAppearanceMfmAnimationsTitle => '播放动态装饰';

  @override
  String get settingsPagesAppearanceMfmAnimationsSubtitle => '播放旋转、彩虹色等动态装饰';

  @override
  String get settingsPagesAppearanceMfmAnimationsDetail =>
      '让 spin / jump / rainbow 等 MFM 动起来。关闭后显示为静止画面（“减少动态效果”开启时始终静止）';

  @override
  String get settingsPagesAppearanceMfmSpeedTitle => '动画速度';

  @override
  String get settingsPagesAppearanceMfmSpeedSubtitle => '100% 为标准。数值越大动得越快';

  @override
  String get settingsPagesAppearanceMfmSettingsDslAppearanceMotionTitle =>
      '减少动态效果';

  @override
  String get settingsPagesAppearanceMfmSettingsDslAppearanceMotionSubtitle =>
      '包括画面切换在内一并减少';

  @override
  String get settingsPagesAppearanceMotionTitle => '减少动态效果';

  @override
  String get settingsPagesAppearanceMotionSection1Title => '动画';

  @override
  String get settingsPagesAppearanceMotionReduceMotionTitle => '减少动态效果';

  @override
  String get settingsPagesAppearanceMotionReduceMotionSubtitle =>
      '停止动态装饰，减少画面动作';

  @override
  String get settingsPagesAppearanceMotionReduceMotionDetail =>
      '将 MFM 的 spin / rainbow 等动画改为静止画面，并减少画面切换的动作';

  @override
  String get settingsPagesAppearanceNotificationsTitle => '通知显示样式';

  @override
  String get settingsPagesAppearanceNotificationsSection1Title => '通知页面';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabAllTitle =>
      '从“全部”打开';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabFollowingTitle =>
      '从“关注中”打开';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabFollowingSubtitle =>
      '优先查看来自你关注的人的通知';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersTitle =>
      '在顶部显示 ASTell 开始通知的预定';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersSubtitle =>
      '在通知页面顶部显示已登记的开始通知';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersDetail =>
      '在通知页面顶部显示已登记的开始通知（设备的本地通知）列表';

  @override
  String get settingsPagesAppearanceNotificationsText1 =>
      '要通知的类型请在“通知 → 配置文件”中选择（保存在设备上）。';

  @override
  String get settingsPagesAppearanceTimelineTitle => '时间线显示';

  @override
  String get settingsPagesAppearanceTimelineSection1Title => '更新';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesTitle => '在时间线上下显示“加载帖子”';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesSubtitle =>
      '手机上默认不显示（下拉刷新）';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesDetail =>
      '显示后会加载新帖子 / 更多帖子。默认在手机应用中不显示（下拉刷新），在网页版和电脑上显示';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillTitle => '显示新帖子提示';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillSubtitle =>
      '刷新后有新帖子时，在标题栏正下方显示“新帖子”';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillDetail =>
      '显示发帖者的头像（最多 3 人）和“新帖子”。点按可回到顶部。一段时间后或滚动到顶部时消失。标题栏收起期间不显示';

  @override
  String get settingsPagesAppearanceVideoTitle => '画中画';

  @override
  String get settingsPagesAppearanceVideoSection1Title => '视频';

  @override
  String get settingsPagesAppearanceVideoAutoplayTitle => '打开后自动播放';

  @override
  String get settingsPagesAppearanceVideoAutoplaySubtitle => '在全屏和小窗口中立即播放';

  @override
  String get settingsPagesAppearanceVideoAutoplayDetail =>
      '在全屏查看器和小窗口（PiP）中，准备就绪后立即播放';

  @override
  String get settingsPagesAppearanceVideoPipKeepPositionTitle =>
      '切换到小窗口时延续播放位置';

  @override
  String get settingsPagesAppearanceVideoPipKeepPositionSubtitle =>
      '在全屏中按下“在小窗口中播放”时，从当前位置继续播放';

  @override
  String get settingsPagesAppearanceVideoSection2Title => '默认播放速度';

  @override
  String get settingsPagesAppearanceVideoDefaultSpeed10Title => '1.0×（标准）';

  @override
  String get settingsPagesAppearanceVideoText1 => '可以拖动小窗口到任意位置。';

  @override
  String get settingsPagesAppearanceVideoText1Detail => '小窗口是 FOW，可以拖动到栏或上下移动。';

  @override
  String get settingsPagesAstellBackgroundTitle => '屏幕关闭时的行为';

  @override
  String get settingsPagesAstellBackgroundSection1Title => '通话中关闭屏幕时';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffKeepTitle => '继续通话';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffKeepSubtitle =>
      '音频保持不变，只停止接收屏幕共享';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffMuteTitle => '静音麦克风并继续';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffLeaveTitle => '离开房间';

  @override
  String get settingsPagesAstellBackgroundNotice1 =>
      '此设置正在准备中。目前 ASTell 仅在屏幕亮着时运行。';

  @override
  String get settingsPagesAstellBackgroundNotice1Detail =>
      '此设置会被保存，但要在实现通话常驻（后台音频）之后才会生效。目前 ASTell 仅在屏幕亮着时运行。';

  @override
  String get settingsPagesAstellSubscriptionTitle => '订阅 ASTell 4U';

  @override
  String get settingsPagesAstellSubscriptionSection1Title => '状态';

  @override
  String get settingsPagesAstellSubscriptionValueRow1Title => '订阅';

  @override
  String get settingsPagesAstellSubscriptionValueRow1Value => '未订阅';

  @override
  String get settingsPagesAstellSubscriptionValueRow2Title => '提供';

  @override
  String get settingsPagesAstellSubscriptionValueRow2Value => '即将推出';

  @override
  String get settingsPagesAstellSubscriptionText1 =>
      'ASTell 4U 是正在准备中的付费方案。推荐栏可以免费使用。';

  @override
  String get settingsPagesAstellSubscriptionText1Detail =>
      'ASTell 4U 是 ASTell 推荐（For You）推送以及服务器端转写 / 摘要的付费方案，目前尚未提供。推荐栏由 RASQ 服务器的免费推荐驱动。';

  @override
  String get settingsPagesAstellTilesTitle => 'Tell 卡片';

  @override
  String get settingsPagesAstellTilesSection1Title => '首页标题栏';

  @override
  String get settingsPagesAstellTilesHeaderStripTitle => '在标题栏显示关注中主持人的 ASTell';

  @override
  String get settingsPagesAstellTilesHeaderStripSubtitle => '在首页上方排列正在进行的房间';

  @override
  String get settingsPagesAstellTilesHeaderStripDetail =>
      '在首页标题栏的圆角框中排列正在进行的房间';

  @override
  String get settingsPagesAstellTilesHeaderMaxTitle => '显示数量';

  @override
  String get settingsPagesAstellTilesHeaderMaxUnit => '个';

  @override
  String get settingsPagesAstellTrendTitle => '推送到趋势时间线';

  @override
  String get settingsPagesAstellTrendSection1Title => 'ASTell 首页栏目';

  @override
  String get settingsPagesAstellTrendShowRecommendedTitle => '显示“推荐”';

  @override
  String get settingsPagesAstellTrendShowTrendingTitle => '显示“趋势”';

  @override
  String get settingsPagesAstellTrendShowTrendingSubtitle =>
      '在 ASTell 首页排列趋势房间';

  @override
  String get settingsPagesAstellTrendText1 => '要在搜索首页的趋势中显示房间，请在“自定义趋势”中设置。';

  @override
  String get settingsPagesAstellTrendText1Detail =>
      '将房间插入趋势时间线（搜索首页）需在趋势的节点（算法）一侧设置。';

  @override
  String get settingsPagesAstellTrendTlconfigTrendTitle => '自定义趋势';

  @override
  String get settingsPagesMediaSaveTitle => '图片和视频的保存位置';

  @override
  String get settingsPagesMediaSaveSection1Title => '“保存图片”和“保存视频”的保存位置';

  @override
  String get settingsPagesMediaSaveDestinationAskTitle => '每次保存时选择';

  @override
  String get settingsPagesMediaSaveDestinationAskSubtitle => '每次询问保存到照片还是文件';

  @override
  String get settingsPagesMediaSaveDestinationAskDetail =>
      '每次询问保存到照片还是文件（只有一个可选位置的设备不会询问）';

  @override
  String get settingsPagesMediaSaveDestinationPhotosTitle => '照片（相册）';

  @override
  String get settingsPagesMediaSaveDestinationPhotosSubtitle => '保存到相册“RASQ”';

  @override
  String get settingsPagesMediaSaveDestinationPhotosDetail =>
      '存入 iPhone / iPad / Mac 的“照片”或 Android 图库中的“RASQ”相册';

  @override
  String get settingsPagesMediaSaveDestinationFilesTitle => '文件';

  @override
  String get settingsPagesMediaSaveDestinationFilesSubtitle =>
      '保存到“文件”App 或你选择的位置';

  @override
  String get settingsPagesMediaSaveDestinationFilesDetail =>
      'iPhone / iPad 保存在“文件”App 的 我的 iPad（我的 iPhone）› RASQ › 保存。电脑上可选择保存位置。Android 则存入图库';

  @override
  String get settingsPagesPluginsAccountPickTitle => '用于分享 / 转帖的账号';

  @override
  String get settingsPagesPluginsAccountPickSection1Title => '同一帖子在多个账号中可见时';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentTitle => '优先使用指定的账号';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentSubtitle =>
      '关闭后，会选择与对方互动最多的账号';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentDetail =>
      '选择某个 SNS 账号查看时，会用该账号分享 / 转帖。关闭后，会根据最近的互动（回应 / 转帖 / 回复）预测并选择与对方互动最多的账号。用 RASQ 账号统一查看时，始终通过预测选择';

  @override
  String get settingsPagesPluginsComposerTitle => '发帖插件';

  @override
  String get settingsPagesPluginsComposerSection1Title => '编辑器';

  @override
  String get settingsPagesPluginsComposerEnabledTitle => '使用发帖插件';

  @override
  String get settingsPagesPluginsComposerEnabledSubtitle => '使用可加工帖子文字和图片的插件';

  @override
  String get settingsPagesPluginsComposerEnabledDetail =>
      '启用编辑器的文本转换（composer.text）和媒体编辑（composer.media）插件';

  @override
  String get settingsPagesPluginsComposerText1 => '关闭后，编辑器和媒体编辑器中的插件栏将为空。';

  @override
  String get settingsPagesPluginsComposerSettingsComposerTitle => '发帖编辑器设置';

  @override
  String get settingsPagesPluginsComposerStoreTitle => '插件商店';

  @override
  String get settingsPagesPluginsEmojiTitle => '表情符号搜索';

  @override
  String get settingsPagesPluginsEmojiSection1Title => '表情符号选择器搜索';

  @override
  String get settingsPagesPluginsEmojiSemanticTitle => '也查找含义相近的表情符号';

  @override
  String get settingsPagesPluginsEmojiSemanticSubtitle =>
      '即使名称不匹配，也会显示含义相近的表情符号。输入的文字不会发送到外部';

  @override
  String get settingsPagesPluginsEmojiSemanticDetail =>
      '即使名称或别名中不包含输入的文字，也会在后面列出含义相近的表情符号。仅在已安装设备端搜索模型（RAi →“模型”→ 搜索）时有效。计算只在设备内进行，输入的文字不会发送到外部。首次打开的服务器在后台建立索引期间会显示“准备中”';

  @override
  String get settingsPagesPluginsProxyTitle => 'RASQ 插件代理订阅';

  @override
  String get settingsPagesPluginsProxySection1Title => '状态';

  @override
  String get settingsPagesPluginsProxyValueRow1Title => '订阅';

  @override
  String get settingsPagesPluginsProxyValueRow1Value => '未订阅';

  @override
  String get settingsPagesPluginsProxyValueRow2Title => '提供';

  @override
  String get settingsPagesPluginsProxyValueRow2Value => '即将推出';

  @override
  String get settingsPagesPluginsProxyText1 => '插件代理正在准备中。目前插件直接从设备通信。';

  @override
  String get settingsPagesPluginsProxyText1Detail =>
      '插件代理是将 wasm 插件的外部通信统一经由 RASQ 服务器的付费服务。由于尚未提供，插件会直接从设备与 SNS / 自建服务器通信。提供时间：与 RASQ 服务器的计费平台同时。';

  @override
  String get settingsPagesPluginsProxySettingsServerTitle => 'RASQ 服务器连接目标';

  @override
  String get settingsPagesPluginsProxySettingsServerSubtitle =>
      '开始提供后，将使用此处选择的服务器';

  @override
  String get settingsPagesPluginsReactionTitle => '回应预测';

  @override
  String get settingsPagesPluginsReactionSection1Title => '短按回应按钮';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptyTitle =>
      '即使没有人回应的帖子也进行预测';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptySubtitle =>
      '预测常用的表情符号，短按即可添加';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptyDetail =>
      '关闭时，对还没有回应的帖子不进行预测，按下会打开表情符号选择器。开启时，会将你常用的表情符号作为预测显示，短按即可添加';

  @override
  String get settingsPagesPluginsTelemetryTitle => '举报可疑通信';

  @override
  String get settingsPagesPluginsTelemetrySection1Title => '向商店举报插件的可疑通信';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesTitle => '举报可疑通信';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesSubtitle =>
      '只将通信的格式发送给审核。不发送正文、令牌等内容。默认关闭';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesDetail =>
      '只在本设备首次看到时，将插件通信的“格式”（目标主机、方法、路径模式、标头名称、发送的 JSON 键结构）发送一次到 RASQ 商店。令牌、正文、用户名、URL 中的 ID 等值不会发送。审核方会用它来重新审查获批后通信格式发生变化的插件。默认关闭。';

  @override
  String get settingsPagesPluginsTelemetryText1 => '相同的格式不会发送第二次。关闭后，会记录为撤回同意。';

  @override
  String settingsPagesPluginsTelemetryText1Detail(String example) {
    return '发送的内容：例如 $example。不发送的内容：值本身。相同的格式不会发送第二次。同意也会记录在商店的同意记录中，关闭后会记录为撤回。';
  }

  @override
  String get settingsPagesPluginsTimelineTitle => '放置自定义时间线';

  @override
  String get settingsPagesPluginsTimelineSection1Title => '时间线插件';

  @override
  String get settingsPagesPluginsTimelineEnabledTitle => '使用自定义时间线';

  @override
  String get settingsPagesPluginsTimelineEnabledSubtitle => '将插件的时间线显示为首页的标签页';

  @override
  String get settingsPagesPluginsTimelineEnabledDetail =>
      '将 TL 插件（tl）声明的时间线显示在首页的标签页和“自定义时间线”的算法中';

  @override
  String get settingsPagesPluginsTimelineText1 => '排列和导入请通过首页标签行的齿轮（自定义时间线）设置。';

  @override
  String get settingsPagesPluginsTimelineStoreTitle => '插件商店';

  @override
  String get settingsPagesPluginsTrendTitle => '自定义趋势发布';

  @override
  String get settingsPagesPluginsTrendSection1Title => '趋势插件';

  @override
  String get settingsPagesPluginsTrendEnabledTitle => '显示趋势插件的候选';

  @override
  String get settingsPagesPluginsTrendEnabledSubtitle => '在搜索首页的趋势栏中显示插件的候选';

  @override
  String get settingsPagesPluginsTrendEnabledDetail =>
      '在搜索首页的趋势栏中显示已安装趋势插件（trend.suggest）的候选标签';

  @override
  String get settingsPagesPluginsTrendText1 => '关闭后，插件不会被调用（即使保持安装也不会通信）。';

  @override
  String get settingsPagesPluginsTrendStoreTitle => '插件商店';

  @override
  String get settingsPagesPluginsTrendStoreSubtitle => '查找 / 管理趋势插件';

  @override
  String get settingsPagesRaiTitle => 'RAi（助手）';

  @override
  String get settingsPagesRaiSection1Title => '自动化';

  @override
  String get settingsPagesRaiTraceGraphAutoTitle => '自动显示流程图';

  @override
  String get settingsPagesRaiTraceGraphAutoSubtitle => '以图表显示 3 个步骤以上的自动化';

  @override
  String get settingsPagesRaiTraceGraphAutoDetail =>
      '交给 RAi 的自动化有 3 个步骤以上时，会自动以节点图显示流程。关闭时会显示“以图表视图显示”按钮';

  @override
  String get settingsPagesRaiText1 => 'AI 模型和网页搜索请通过 RAi 栏的模型按钮设置。';

  @override
  String get settingsPagesRaiText1Detail => '推理服务器和网页搜索的密钥请通过 RAi 栏的模型标签设置。';

  @override
  String get settingsPagesRelationalPluginsTitle => '插件高级设置';

  @override
  String get settingsPagesRelationalPluginsSection1Title => '状态';

  @override
  String get settingsPagesRelationalPluginsValueRow1Title => '插件槽';

  @override
  String get settingsPagesRelationalPluginsValueRow1Value => '即将推出';

  @override
  String get settingsPagesRelationalPluginsText1 => '此画面的插件正在准备中。';

  @override
  String get settingsPagesRelationalPluginsText1Detail =>
      '契约 v0.7 中尚无用于关联时间线的插件槽（替换聚合方式）。ML 相似度使用 RASQ 服务器的 ML 网关。插件槽：未定义。';

  @override
  String get settingsPagesRelationalPluginsSettingsServerTitle =>
      'RASQ 服务器连接目标';

  @override
  String get settingsPagesRelationalRelayTitle => 'Relay 卡片';

  @override
  String get settingsPagesRelationalRelaySection1Title => '状态';

  @override
  String get settingsPagesRelationalRelayValueRow1Title => '提供';

  @override
  String get settingsPagesRelationalRelayValueRow1Value => '即将推出';

  @override
  String get settingsPagesRelationalRelayText1 =>
      'Relay 卡片正在准备中。目前可以在“帖子聚类”中更改对话的归纳方式。';

  @override
  String get settingsPagesRelationalRelayText1Detail =>
      'Relay 卡片会将话题跨对话事件传递的流程（接力）汇总到一张卡片中显示。将在聚合方式确定后加入。目前可以通过调整“帖子聚类”来更改对话事件的聚合方式。提供时间：算法确定后。';

  @override
  String get settingsPagesRelationalTrendTitle => '推送到趋势时间线';

  @override
  String get settingsPagesRelationalTrendSection1Title => '状态';

  @override
  String get settingsPagesRelationalTrendValueRow1Title => '提供';

  @override
  String get settingsPagesRelationalTrendValueRow1Value => '即将推出';

  @override
  String get settingsPagesRelationalTrendText1 => '可以通过“自定义趋势”将关联时间线推送到趋势中。';

  @override
  String get settingsPagesRelationalTrendText1Detail =>
      '将关联标签页的对话事件推送到趋势时间线，可以通过在趋势一侧的节点（算法）中放置“关联时间线”节点来设置。提供时间：算法确定后。';

  @override
  String get settingsPagesRelationalTrendTlconfigTrendTitle => '自定义趋势';

  @override
  String get settingsPagesResourcesTitle => '资源与广告';

  @override
  String get settingsPagesResourcesSection1Title => '广告';

  @override
  String get settingsPagesResourcesShowAdsTitle => '显示广告';

  @override
  String get settingsPagesResourcesShowAdsSubtitle => '时间线帖子之间和搜索首页上的广告';

  @override
  String get settingsPagesResourcesShowAdsDetail =>
      '时间线帖子之间（每 10 条一个，不会放在带内容警告或敏感内容的帖子旁边）以及搜索首页的广告位（AdMob，目前为测试广告）。不显示个性化广告';

  @override
  String get settingsPagesResourcesSection2Title => '资源';

  @override
  String get settingsPagesResourcesValueRow1Title => '插件通信';

  @override
  String get settingsPagesResourcesValueRow1Value => '直接从设备';

  @override
  String get settingsPagesResourcesValueRow2Title => '推理';

  @override
  String get settingsPagesResourcesValueRow2Value => '设备端 + 所选服务器';

  @override
  String get settingsPagesResourcesText1 => '各插件是否有广告及其价格，显示在插件商店的各个页面上。';

  @override
  String get settingsPagesResourcesText1Detail =>
      '各插件是否有广告及其价格，显示在插件商店的各个页面上。插件通信：直接从设备（无代理）。推理：设备端模型（RAi）+ 任选的推理服务器。';

  @override
  String get settingsPagesResourcesStoreTitle => '插件商店';

  @override
  String get settingsPagesTrendCdnTitle => '缓存网络设置';

  @override
  String get settingsPagesTrendCdnSection1Title => '状态';

  @override
  String get settingsPagesTrendCdnValueRow1Title => '缓存网络';

  @override
  String get settingsPagesTrendCdnValueRow1Value => '即将推出';

  @override
  String get settingsPagesTrendCdnText1 => '正在准备中。目前直接从各 SNS 获取。';

  @override
  String get settingsPagesTrendCdnText1Detail =>
      '从 CDN（缓存网络）读取趋势获取结果的机制，将与 RASQ 服务器的分发平台同时推出。目前直接从各 SNS 获取。缓存网络：未提供。';

  @override
  String get settingsSectionsPluginsTitle => '插件配置';

  @override
  String get settingsSectionsPluginsProxyTitle => 'RASQ 插件代理订阅';

  @override
  String get settingsSectionsPluginsProxySubtitle => '即将推出';

  @override
  String get settingsSectionsPluginsProxyDetail => '未订阅（第二期）';

  @override
  String get settingsSectionsPluginsActionBarTitle => '在帖子上放置插件自动化';

  @override
  String get settingsSectionsPluginsActionBarSubtitle => '显示在帖子下方的插件按钮';

  @override
  String get settingsSectionsPluginsActionBarDetail =>
      '显示在帖子操作栏中的插件按钮（总开关 / 自动开启 / 位置）';

  @override
  String get settingsSectionsPluginsTrendTitle => '自定义趋势发布';

  @override
  String get settingsSectionsPluginsComposerTitle => '发帖插件';

  @override
  String get settingsSectionsPluginsTimelineTitle => '放置自定义时间线';

  @override
  String get settingsSectionsPluginsStoreTitle => '插件高级设置';

  @override
  String get settingsSectionsPluginsStoreSubtitle => '插件商店（管理已安装的插件）';

  @override
  String get settingsSectionsPluginsTelemetryTitle => '举报可疑通信';

  @override
  String get settingsSectionsPluginsTelemetrySubtitle => '默认关闭';

  @override
  String get settingsSectionsPluginsTelemetryDetail =>
      '通信形态报告：仅在首次发现时，将插件的通信形态（不含数值）发送到商店。默认关闭';

  @override
  String get settingsSectionsSnsTitle => 'SNS 插件';

  @override
  String get settingsSectionsSnsAccountTitle => '账号';

  @override
  String get settingsSectionsSnsTimelineTitle => '时间线';

  @override
  String get settingsSectionsSnsSecurityTitle => '安全';

  @override
  String get settingsSectionsSnsSafetyTitle => '隐私与安全模式';

  @override
  String get settingsSectionsSnsChildSafeTitle => '儿童安全';

  @override
  String get settingsSectionsSnsChildSafeSubtitle => '监护人监护 / 儿童模式';

  @override
  String get settingsSectionsSnsChildSafeDetail => '以监护人身份看护 / 儿童模式（用监护人的代码连接）';

  @override
  String get settingsSectionsSnsListsTitle => '列表';

  @override
  String get settingsSectionsSnsMuteBlockTitle => '静音/屏蔽';

  @override
  String get settingsSectionsSnsPluginButtonsTitle => '插件按钮';

  @override
  String get settingsSectionsSnsPluginButtonsSubtitle => '插件按钮的显示方式';

  @override
  String get settingsSectionsSnsPluginButtonsDetail =>
      '各界面的总开关和“打开时自动开启”、此账号的启用 / 停用以及合并阈值';

  @override
  String get settingsSectionsSnsEmojiSearchTitle => '表情符号搜索';

  @override
  String get settingsSectionsSnsEmojiSearchSubtitle => '也查找含义相近的表情符号';

  @override
  String get settingsSectionsSnsEmojiSearchDetail => '同时查找含义相近的表情（设备端模型）';

  @override
  String get settingsSectionsSnsReactionPredictTitle => '回应预测';

  @override
  String get settingsSectionsSnsReactionPredictSubtitle => '是否对还没有人回应的帖子也进行预测';

  @override
  String get settingsSectionsSnsQuickEmojiTitle => '快捷表情';

  @override
  String get settingsSectionsSnsQuickEmojiSubtitle => '长按回应按钮并滑动选择的表情';

  @override
  String get settingsSectionsSnsAccountPickTitle => '用于分享 / 转帖的账号';

  @override
  String get settingsSectionsSnsAccountPickSubtitle => '同一帖子在多个账号中可见时';

  @override
  String get settingsSectionsSnsAccountPickDetail => '对在多个账号中可见的帖子，使用哪个账号处理';

  @override
  String get settingsSectionsSnsMfmTitle => '自定义动效与动画';

  @override
  String get settingsSectionsSnsResourcesTitle => '资源与广告';

  @override
  String get settingsSectionsSnsLegalTitle => '帮助与法律声明';

  @override
  String get settingsSectionsSnsNote =>
      '账号 / 时间线 / 安全 / 隐私是由你所用 SNS 的插件提供的页面（插件未提供的页面不会显示）。';

  @override
  String get settingsSectionsSnsNoteDetail =>
      '账号 / 时间线 / 安全 / 隐私是由所设置账号的 SNS 插件提供的设置页面（sns.settingsPages。未声明的页面行不显示，D-482）。';

  @override
  String get settingsSectionsAppearanceTitle => '应用外观';

  @override
  String get settingsSectionsAppearanceDisplayTitle => '界面显示大小';

  @override
  String get settingsSectionsAppearanceThemeTitle => '字体与配色方案';

  @override
  String get settingsSectionsAppearanceThemeSubtitle => '主题（颜色、图标、背景图片）';

  @override
  String get settingsSectionsAppearanceColumnsTitle => '栏宽';

  @override
  String get settingsSectionsAppearanceColumnsSubtitle => '宽屏上左右栏的宽度';

  @override
  String get settingsSectionsAppearanceColumnsDetail =>
      '宽屏上小栏 / 大栏的比例（1:1 / 2:3 / 3:5 / 固定宽度）';

  @override
  String get settingsSectionsAppearanceMotionTitle => '减少动态效果';

  @override
  String get settingsSectionsAppearanceTimelineTitle => '时间线显示';

  @override
  String get settingsSectionsAppearanceTimelineSubtitle => '时间线的“加载帖子”';

  @override
  String get settingsSectionsAppearanceTimelineDetail => '时间线上下方的“加载帖子”';

  @override
  String get settingsSectionsAppearancePipTitle => '画中画';

  @override
  String get settingsSectionsAppearanceFabTitle => '＋ 按钮的功能';

  @override
  String get settingsSectionsAppearanceFabSubtitle => '点按时开始的操作';

  @override
  String get settingsSectionsAppearanceMediaSaveTitle => '图片和视频的保存位置';

  @override
  String get settingsSectionsAppearanceMediaSaveSubtitle =>
      '照片（相册）/ 文件 / 每次保存时选择';

  @override
  String get settingsSectionsAppearanceNotificationsTitle => '通知显示样式';

  @override
  String get settingsSectionsAstellTitle => 'ASTell';

  @override
  String get settingsSectionsAstellSubscriptionTitle => '订阅 ASTell 4U';

  @override
  String get settingsSectionsAstellSubscriptionSubtitle => '即将推出';

  @override
  String get settingsSectionsAstellSubscriptionDetail => '未订阅（第二期）';

  @override
  String get settingsSectionsAstellTilesTitle => 'Tell 卡片';

  @override
  String get settingsSectionsAstellTrendTitle => '推送到趋势时间线';

  @override
  String get settingsSectionsAstellRoomButtonsTitle => '房间按钮';

  @override
  String get settingsSectionsAstellRoomButtonsSubtitle => '输入框左侧的按钮';

  @override
  String get settingsSectionsAstellRoomButtonsDetail =>
      '房间底部、输入框左侧的圆形按钮排列（排序 / 显示 / 隐藏 / 添加插件按钮）';

  @override
  String get settingsSectionsAstellStoreTitle => '插件高级设置';

  @override
  String get settingsSectionsAstellStoreSubtitle => '在 ASTell 中使用的插件';

  @override
  String get settingsSectionsAstellStoreDetail => 'ASTell 的操作插件（商店）';

  @override
  String get settingsSectionsAstellBackgroundTitle => '屏幕关闭时的行为';

  @override
  String get settingsSectionsRelationalTitle => '关系时间线';

  @override
  String get settingsSectionsRelationalClusterTitle => '帖子聚类';

  @override
  String get settingsSectionsRelationalClusterSubtitle => '对话的归并方式';

  @override
  String get settingsSectionsRelationalClusterDetail =>
      '对话事件的归并方式（归并难易度 / 权重 / 沉底所需时间）';

  @override
  String get settingsSectionsRelationalRelayTitle => 'Relay 卡片';

  @override
  String get settingsSectionsRelationalTrendTitle => '推送到趋势时间线';

  @override
  String get settingsSectionsRelationalPluginsTitle => '插件高级设置';

  @override
  String get settingsSectionsRelationalSamplingTitle => '趋势采样级别';

  @override
  String get settingsSectionsRelationalSamplingSubtitle => '纳入候选的时间范围';

  @override
  String get settingsSectionsRelationalSamplingDetail => '纳入候选的时间范围（归并判定的高级设置）';

  @override
  String get settingsSectionsRelationalNote => 'Relay 卡片和趋势发布即将推出。';

  @override
  String get settingsSectionsRelationalNoteDetail =>
      'Relay 卡片和趋势发布将在算法确定后提供（D-011）。';

  @override
  String get settingsSectionsTrendTitle => '趋势';

  @override
  String get settingsSectionsTrendGenresTitle => '类别';

  @override
  String get settingsSectionsTrendTendencyTitle => '趋势的倾向/刺激程度';

  @override
  String get settingsSectionsTrendEmomTitle => 'EmoM 阈值';

  @override
  String get settingsSectionsTrendEmomSubtitle => '隐藏运营方限制的趋势 / 公开阈值';

  @override
  String get settingsSectionsTrendEmomDetail =>
      'EmoM 阈值（0–100，默认 50）和“公开阈值”（默认关闭）。运营方限制分数高于此值的趋势不会显示在列表中（D-404）';

  @override
  String get settingsSectionsTrendPluginsTitle => '插件高级设置';

  @override
  String get settingsSectionsTrendCdnTitle => '缓存网络设置';

  @override
  String get settingsSectionsTrendCdnSubtitle => '即将推出';

  @override
  String get settingsSectionsTrendCdnDetail => '暂未提供（第二期）';

  @override
  String get settingsSectionsRaiTitle => 'RAi（助手）';

  @override
  String get settingsSectionsRaiGraphTitle => '自动显示流程图';

  @override
  String get settingsSectionsNotificationsTitle => '通知';

  @override
  String get settingsSectionsNotificationsProfileTitle => '配置文件';

  @override
  String get settingsSectionsNotificationsAccessTokenTitle => '访问令牌';

  @override
  String get settingsSectionsNotificationsAccessTokenSubtitle => '接收通知的设置';

  @override
  String get settingsSectionsNotificationsAccessTokenDetail =>
      '签发 / 吊销通知专用令牌，设备推送注册';

  @override
  String get settingsSectionsNotificationsSecurityTitle => '安全';

  @override
  String get settingsSectionsNotificationsSecuritySubtitle => 'SNS 权限与访问令牌';

  @override
  String get settingsSectionsAboutTitle => '关于 RASQ';

  @override
  String get settingsSectionsAboutServerTitle => 'RASQ 服务器';

  @override
  String get settingsSectionsAboutServerSubtitle => '要连接的服务器';

  @override
  String get settingsSectionsAboutServerDetail => '插件商店 / RASQ 账号 / 登录的连接目标';

  @override
  String get settingsSectionsAboutHelpTitle => '帮助';

  @override
  String get settingsSectionsAboutTourTitle => '再次查看 RASQ 使用指南';

  @override
  String get settingsSectionsAboutTourSubtitle => '功能介绍（时间线、趋势、ASTell、RAi 等）';

  @override
  String get settingsSectionsAboutSubscriptionTitle => '订阅状态';

  @override
  String get settingsSectionsAboutCookiesTitle => '关于 Cookie';

  @override
  String get settingsSectionsAboutPrivacyTitle => '隐私政策';

  @override
  String get settingsSectionsAboutTermsTitle => '使用条款';

  @override
  String get settingsSectionsAboutLearningTitle => '为算法和社区做贡献';

  @override
  String get settingsSectionsAboutLearningSubtitle => '可选。默认为“不提供”';

  @override
  String get settingsSectionsAboutAstellTermsTitle => 'ASTell 使用条款';

  @override
  String get settingsSectionsAboutRaiTermsTitle => 'RAi 使用条款';

  @override
  String get settingsSectionsAboutStoreTermsTitle => '插件商店使用条款';

  @override
  String get settingsSectionsAboutDevTermsTitle => '插件开发者上架与审核条款';

  @override
  String get settingsSectionsAboutDevTermsSubtitle => '含审核费';

  @override
  String get settingsSectionsAboutBillingTitle => '费用与积分条款';

  @override
  String get settingsSectionsAboutCommerceTitle => '基于《特定商业交易法》的标示';

  @override
  String get settingsSectionsAboutResourcesTitle => '资源与广告';

  @override
  String get settingsSectionsAboutLegalTitle => '帮助与法律声明';

  @override
  String get settingsSectionsAboutDeveloperTitle => '开发者模式';

  @override
  String get settingsSectionsAboutDeveloperSubtitle => '显示更详细的界面说明';

  @override
  String get settingsSecurityAgoJustNow => '刚刚';

  @override
  String settingsSecurityAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityCodeSentTo(String to) {
    return '已向 $to 发送验证码';
  }

  @override
  String get settingsSecurityTitle => '账号安全';

  @override
  String get settingsSecurityNotSignedIn => '未登录 RASQ 账号。';

  @override
  String get settingsSecurityToLoginTitle => '登录现有的 RASQ 账号';

  @override
  String get settingsSecurityToLoginSubtitle => '用户名（或邮箱）和密码';

  @override
  String get settingsSecurityEmailHeader => '邮箱地址';

  @override
  String get settingsSecurityEmailCaption => '用于忘记密码时的重置，以及登录的第二步验证。其他人看不到。';

  @override
  String get settingsSecurityEmailDetail =>
      '注册后，可用于忘记密码时的重置、从其他设备登录时的第二步验证（输入密码后再输入邮件验证码），以及重要操作的确认和通知。如果未验证邮箱，忘记密码时将无法重置。其他人看不到。';

  @override
  String get settingsSecurityEmailCurrentTitle => '当前邮箱';

  @override
  String get settingsSecurityEmailUnregistered => '未注册';

  @override
  String get settingsSecurityEmailNewHint => '新邮箱地址';

  @override
  String get settingsSecurityEmailHint => '邮箱地址';

  @override
  String get settingsSecuritySendCodeButton => '发送验证码';

  @override
  String get settingsSecurityEmailChangeNeedsPasswordOrCode =>
      '更换时，需要当前密码或发送到当前邮箱的验证码。';

  @override
  String get settingsSecurityEmailChangeNeedsCode => '更换时，需要发送到当前邮箱的验证码。';

  @override
  String get settingsSecurityCurrentPasswordHint => '当前密码';

  @override
  String get settingsSecurityEmailSendCodeToCurrentButton => '向当前邮箱发送验证码';

  @override
  String get settingsSecurityEmailNeedsPassword => '已设置密码的账号，添加邮箱地址时需要当前密码。';

  @override
  String settingsSecurityEmailPendingCaption(String email) {
    return '请输入发送到 $email 的验证码（15 分钟后失效）。';
  }

  @override
  String get settingsSecurityEmailVerified => '邮箱地址已验证';

  @override
  String get settingsSecurityVerifyButton => '验证';

  @override
  String get settingsSecurityEmailRemoveTitle => '移除邮箱地址';

  @override
  String get settingsSecurityEmailRemoveSubtitle => '需要验证码';

  @override
  String get settingsSecurityPasswordHeader => '密码';

  @override
  String get settingsSecurityPasswordChangeCaption =>
      '更改后，其他设备将退出登录。需要当前密码或邮件验证码。';

  @override
  String get settingsSecurityPasswordNoneCaption =>
      '没有密码时，无法从其他设备登录（只能在此设备上使用）。设置后，可在其他设备上用用户名（或邮箱）和密码登录同一账号。';

  @override
  String get settingsSecurityPasswordNewHint => '新密码（8 个字符以上）';

  @override
  String get settingsSecurityPasswordHint => '密码（8 个字符以上）';

  @override
  String get settingsSecurityPasswordChanged => '密码已更改';

  @override
  String get settingsSecurityPasswordSet => '密码已设置';

  @override
  String get settingsSecurityPasswordChangeButton => '更改密码';

  @override
  String get settingsSecurityPasswordSetButton => '设置密码';

  @override
  String get settingsSecurityPasswordByCodeButton => '用邮件验证码更改';

  @override
  String get settingsSecurityPasswordResetWarning => '如果“重置”密码，将无法读取已同步的设置。';

  @override
  String get settingsSecurityPasswordResetWarningDetail =>
      '密码也用于加密已同步的设置。如果进行“重置密码”（登录画面），用旧密码加密的数据将无法解密。';

  @override
  String get settingsSecuritySecondFactorHeader => '登录的第二步验证';

  @override
  String get settingsSecuritySecondFactorNeedsEmailCaption =>
      '验证邮箱地址后，从其他设备登录时，输入密码后还需要输入邮件验证码（默认开启）。';

  @override
  String get settingsSecuritySecondFactorActiveCaption =>
      '从其他设备登录时，输入密码后还需要输入发送到邮箱的验证码（10 分钟内有效）。';

  @override
  String get settingsSecuritySecondFactorOffCaption => '已关闭。其他设备仅凭密码即可登录。';

  @override
  String get settingsSecuritySecondFactorTitle => '同时要求邮件验证码';

  @override
  String get settingsSecuritySecondFactorNeedsEmailSubtitle => '需要验证邮箱地址';

  @override
  String get settingsSecuritySecondFactorEnabled => '已开启登录的第二步验证';

  @override
  String get settingsSecuritySecondFactorDisableNeedsPasswordOrCode =>
      '关闭时，需要当前密码或发送到邮箱的验证码。';

  @override
  String get settingsSecuritySecondFactorDisableNeedsCode => '关闭时，需要发送到邮箱的验证码。';

  @override
  String get settingsSecuritySendCodeToEmailButton => '向邮箱发送验证码';

  @override
  String get settingsSecurityCancelButton => '取消';

  @override
  String get settingsSecuritySecondFactorDisabled => '已关闭登录的第二步验证';

  @override
  String get settingsSecuritySecondFactorDisableButton => '关闭第二步验证';

  @override
  String get settingsSecuritySessionsHeader => '已登录的设备';

  @override
  String settingsSecuritySessionsRevokedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台设备',
    );
    return '已将其他 $_temp0退出登录';
  }

  @override
  String get settingsSecuritySessionsRevokeOthersButton => '将其他设备全部退出登录';

  @override
  String get settingsSecuritySessionUnnamed => '未命名设备';

  @override
  String get settingsSecurityThisDeviceSuffix => '（此设备）';

  @override
  String settingsSecuritySessionLastUsed(String ago) {
    return '上次使用：$ago';
  }

  @override
  String settingsSecuritySessionExpires(String date) {
    return '到期 $date';
  }

  @override
  String get settingsSecuritySessionRevoked => '已退出登录';

  @override
  String get settingsSecuritySessionLogoutButton => '退出登录';

  @override
  String get settingsSecurityConfirmDeleteHeader => '确认删除账号';

  @override
  String get settingsSecurityConfirmEmailRemoveHeader => '确认移除邮箱地址';

  @override
  String settingsSecurityConfirmCodeCaption(String to) {
    return '请输入发送到 $to 的验证码。';
  }

  @override
  String get settingsSecurityDeleteButton => '删除';

  @override
  String get settingsSecurityRemoveButton => '移除';

  @override
  String get settingsSecurityDeleteHeader => '删除账号';

  @override
  String get settingsSecurityDeleteTitle => '删除 RASQ 账号';

  @override
  String get settingsSecurityDeleteSubtitleWithEmail => '需要邮件验证码。此操作无法撤销';

  @override
  String get settingsSecurityDeleteSubtitle => '此操作无法撤销';

  @override
  String get settingsSecurityRolesHeader => '角色';

  @override
  String get settingsSecurityRolesTitle => '此账号的角色';

  @override
  String get settingsSecurityRoleDeveloper => '开发者';

  @override
  String get settingsSecurityRoleReviewer => '审核员';

  @override
  String get settingsSecurityEmailReplaceNeedsPasswordOrCodeError =>
      '请输入当前密码，或用发送到当前邮箱的验证码进行确认';

  @override
  String get settingsSecurityEmailReplaceNeedsCodeError => '请用发送到当前邮箱的验证码进行确认';

  @override
  String get settingsSecurityEnterCurrentPasswordError => '请输入当前密码';

  @override
  String get settingsSecurityCodeSent => '已发送验证码';

  @override
  String get settingsSecurityDeleteConfirmMessage =>
      '将删除服务器上的个人资料、账号组合、已同步的设置、评价和书签、ASTell 的房间和共享、通知令牌以及同意记录。此操作无法撤销。';

  @override
  String get settingsSecuritySendConfirmCodeButton => '发送验证码';

  @override
  String get settingsSecurityDeleted => '已删除 RASQ 账号';

  @override
  String get settingsSecurityEmailRemoved => '已移除邮箱地址';

  @override
  String get settingsSecurityCodeHint => '验证码（例如 3mJr7-AoUXx）';

  @override
  String get settingsSecurityCodeHelper => '也可以粘贴邮件中的链接进行验证';

  @override
  String get settingsSecurityLoginFailedHelp =>
      '用户名（邮箱）或密码不正确。\n未设置密码的 RASQ 账号无法从其他设备登录。请在创建该账号的设备（目前仍已登录的设备）上，通过“设置 → 账号安全”设置密码后，再重新登录。';

  @override
  String get settingsSecurityServerNotConfiguredError => '尚未设置 RASQ 服务器的连接地址';

  @override
  String get settingsSecurityLoginFailed => '无法登录';

  @override
  String settingsSecurityLoggedInAs(String handle) {
    return '已登录 @$handle';
  }

  @override
  String get settingsSecurityLoginEnterCredentialsError => '请输入用户名（或邮箱）和密码';

  @override
  String get settingsSecurityVerifiedEmailFallback => '已验证的邮箱';

  @override
  String get settingsSecurityLoginTitle => '登录 RASQ 账号';

  @override
  String get settingsSecurityLoginCaption => '使用用户名（可省略 @）或已验证的邮箱地址，以及密码登录。';

  @override
  String get settingsSecurityLoginDetail =>
      '使用用户名（可省略 @）或已验证的邮箱地址，以及密码登录。拥有已验证邮箱的账号，之后还需输入发送到邮箱的验证码（第二步验证）。';

  @override
  String get settingsSecurityLoginIdentifierHint => '用户名或邮箱地址';

  @override
  String get settingsSecurityLoginPasswordHint => '密码';

  @override
  String get settingsSecurityLoginButton => '登录';

  @override
  String get settingsSecurityLoginForgotButton => '忘记密码';

  @override
  String get settingsSecurityLoginNoPasswordHint =>
      '未设置密码的账号无法从其他设备登录（只能在创建它的设备上使用）。请在该设备的“设置 → 账号安全”中设置密码。';

  @override
  String get settingsSecurityLoginCodeHeader => '验证码';

  @override
  String settingsSecurityLoginChallengeCaption(String email, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分钟内有效',
    );
    return '已向 $email 发送验证码($_temp0，仅限一次)。请输入收到的验证码。';
  }

  @override
  String get settingsSecurityVerifiedEmailAddressFallback => '已验证的邮箱地址';

  @override
  String get settingsSecurityLoginConfirmButton => '验证并登录';

  @override
  String get settingsSecurityLoginResendButton => '重新发送验证码';

  @override
  String get settingsSecurityLoginBackButton => '返回用户名 / 密码';

  @override
  String get settingsSecurityLoginNoMailHint =>
      '如果没有收到邮件，请同时查看垃圾邮件文件夹。如果收到了你没有进行过的登录邮件，请更改密码。';

  @override
  String get settingsSecurityLoginChildHeader => '儿童账号';

  @override
  String get settingsSecurityLoginChildTitle => '使用监护人提供的代码登录';

  @override
  String get settingsSecurityLoginChildSubtitle => '登录监护人创建的孩子账号';

  @override
  String get settingsSecurityResetEnterEmailError => '请输入已验证的邮箱地址';

  @override
  String get settingsSecurityResetCodeSent =>
      '如果存在已验证该邮箱地址的账号，验证码已发送（10 分钟内有效）';

  @override
  String settingsSecurityResetDoneKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return '密码已重置。已将其他 $_temp0设备退出登录';
  }

  @override
  String settingsSecurityResetDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return '密码已重置(已将 $_temp0设备退出登录)。请使用新密码登录';
  }

  @override
  String get settingsSecurityResetTitle => '重置密码';

  @override
  String get settingsSecurityResetCaption =>
      '将向已验证的邮箱地址发送验证码（10 分钟内有效，仅限一次），然后设置新密码。其他所有设备都将退出登录。';

  @override
  String get settingsSecurityResetNoEmailWarning => '未验证邮箱地址的账号无法重置密码。';

  @override
  String get settingsSecurityResetNoEmailDetail =>
      '请在创建该账号的设备（目前仍已登录的设备）上，通过“设置 → 账号安全”设置新密码。如果连该设备也没有，将无法恢复账号。';

  @override
  String get settingsSecurityResetEmailHint => '已验证的邮箱地址';

  @override
  String get settingsSecurityResendButton => '重新发送';

  @override
  String settingsSecurityResetNewPasswordHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个字符以上',
    );
    return '新密码($_temp0)';
  }

  @override
  String get settingsSecurityResetConfirmPasswordHint => '新密码（确认）';

  @override
  String get settingsSecurityResetMismatchError => '不一致';

  @override
  String get settingsSecurityResetKeepTitle => '保留此设备的登录状态';

  @override
  String get settingsSecurityResetKeepSubtitle => '仅在重置此设备当前登录的账号时保留';

  @override
  String get settingsSecurityResetSyncWarning => '重置后，将无法读取已同步的设置。';

  @override
  String get settingsSecurityResetSyncWarningDetail =>
      '密码也用于加密已同步的设置。用旧密码加密的数据将无法解密。';

  @override
  String get settingsSecurityResetSubmitButton => '重置密码';

  @override
  String get settingsSnsShareConflictError => '其他设备已先行更改。请重试';

  @override
  String get settingsSnsShareOffConfirmTitle => '要停止共享 SNS 登录吗？';

  @override
  String get settingsSnsShareOffConfirmMessage =>
      '将删除共享的数据和所有设备的密钥。各设备的 SNS 登录将保持不变。';

  @override
  String get settingsSnsShareOffConfirmDetail =>
      '将删除 RASQ Central 上的共享内容（已加密）以及所有设备的密钥。各设备的 SNS 登录将保持不变。';

  @override
  String get settingsSnsShareOffConfirmButton => '停止';

  @override
  String get settingsSnsShareCancelButton => '取消';

  @override
  String get settingsSnsShareStopped => '已停止共享';

  @override
  String get settingsSnsShareSubtitleLoading => '加载中…';

  @override
  String get settingsSnsShareSubtitleUnsupported => '此设备的登录不支持共享。请重新登录';

  @override
  String get settingsSnsShareSubtitleOffAsk => '关闭（在其他设备登录时询问）';

  @override
  String get settingsSnsShareSubtitleOff => '关闭';

  @override
  String get settingsSnsShareSubtitleOnHolding => '开启 · 此设备正在共享';

  @override
  String get settingsSnsShareSubtitleOnWaiting => '开启 · 正在等待共享设备的批准';

  @override
  String get settingsSnsShareSubtitleOnNotYet => '开启 · 此设备尚未共享';

  @override
  String get settingsSnsShareHeader => '在设备间共享 SNS 登录';

  @override
  String get settingsSnsShareCaption => '在新设备上也能自动登录 SNS。内容经过加密，RASQ 的服务器无法读取。';

  @override
  String get settingsSnsShareDetail =>
      '在已登录此 RASQ 账号的设备之间，以端到端加密（E2E）方式共享 SNS 访问令牌。在新设备上登录后，经共享设备批准，该设备也会一并登录 SNS 账号。RASQ 的服务器无法读取内容。';

  @override
  String get settingsSnsShareSwitchTitle => '与其他设备共享 SNS 登录';

  @override
  String get settingsSnsShareRequestTitle => '请求共享到此设备';

  @override
  String get settingsSnsShareRequestSubtitle => '共享设备上会显示批准请求';

  @override
  String get settingsSnsShareRequested => '已向共享设备请求批准';

  @override
  String get settingsSnsShareDevicesLabel => '设备';

  @override
  String get settingsSnsShareThisDeviceSuffix => '（此设备）';

  @override
  String get settingsSnsShareDeviceShared => '共享中';

  @override
  String get settingsSnsShareDeviceWaiting => '等待批准';

  @override
  String get settingsSnsShareDeviceNotShared => '未共享';

  @override
  String settingsSnsShareApproved(String name) {
    return '已共享给 $name';
  }

  @override
  String get settingsSnsShareApproveButton => '共享';

  @override
  String get settingsSnsShareDeclineButton => '拒绝';

  @override
  String settingsSnsShareRemoved(String name) {
    return '已将 $name 移出共享';
  }

  @override
  String get settingsSnsShareRemoveButton => '移除';

  @override
  String get settingsSnsShareRemovedCaption =>
      '被移除的设备仍保留之前的登录。若不认识该设备，请同时在 SNS 一侧退出登录。';

  @override
  String get settingsSnsShareRemovedDetail =>
      '在“已登录的设备”中让该设备退出登录，该设备的密钥也会被删除。被移除的设备仍持有之前收到的访问令牌（若不认识该设备，请同时在 SNS 一侧退出登录）。';

  @override
  String get shellColumnSplitSmallFixedLabel => '固定小栏宽度';

  @override
  String get shellColumnSplitLargeFixedLabel => '固定大栏宽度';

  @override
  String get shellColumnSplitEvenHint => '等宽';

  @override
  String get shellColumnSplitTwoThreeHint => '小 2 : 大 3';

  @override
  String get shellColumnSplitThreeFiveHint => '小 3 : 大 5';

  @override
  String get shellColumnSplitSmallFixedHint => '小栏使用固定宽度，其余给大栏';

  @override
  String get shellColumnSplitLargeFixedHint => '大栏使用固定宽度，其余给小栏';

  @override
  String get shellColumnWidthErrorEmpty => '请输入宽度';

  @override
  String get shellColumnWidthErrorNotInteger => '请输入整数';

  @override
  String shellColumnWidthErrorRange(String min, String max) {
    return '请输入 $min～$max px 之间的值';
  }

  @override
  String get shellColumnThirdEmptySearch => '搜索';

  @override
  String get shellColumnThirdEmptyNotifications => '通知';

  @override
  String get shellColumnThirdEmptyNone => '不显示';

  @override
  String get shellColumnThirdSettingsTooltip => '第三栏设置';

  @override
  String get shellColumnThirdCloseTooltip => '关闭';

  @override
  String get shellColumnThirdEmptyTitle => '第三栏';

  @override
  String get shellColumnThirdEmptyHint => '可以将打开的页面移到这里';

  @override
  String get shellColumnThirdEmptyHintDetail => '可以将 FOW 移到这里（M5c）';

  @override
  String get shellNavHome => '首页';

  @override
  String get shellNavSearch => '搜索';

  @override
  String get shellNavNotifications => '通知';

  @override
  String get shellHeaderTimelineSwitchTooltip => '切换时间线';

  @override
  String get shellHeaderExpandTooltip => '恢复标题栏';

  @override
  String get shellHeaderScrollToTopTooltip => '回到顶部';

  @override
  String get shellHeaderSearchHint => '搜索';

  @override
  String get shellHeaderBackTooltip => '返回';

  @override
  String get shellHeaderCloseButton => '关闭';

  @override
  String get shellHeaderMenuTooltip => '菜单';

  @override
  String get shellHeaderOpenSidebarSemantics => '打开侧边栏';

  @override
  String get shellSidebarSemantics => '侧边栏';

  @override
  String shellSidebarSwitchToAccountTooltip(String name) {
    return '切换到 $name';
  }

  @override
  String get shellSidebarRasqAccountTooltip => 'RASQ 账号';

  @override
  String get shellSidebarHideAccountsTooltip => '隐藏账号列表';

  @override
  String get shellSidebarShowAccountsTooltip => '显示账号列表';

  @override
  String get shellSidebarAccountSettingsButton => '账号设置';

  @override
  String get shellSidebarBookmarks => '书签';

  @override
  String get shellSidebarLists => '列表';

  @override
  String get shellSidebarPlugins => '插件';

  @override
  String get shellSidebarCustomPlugins => '自定义插件';

  @override
  String get shellSidebarAllSettings => '全部设置';

  @override
  String get shellSidebarHelp => '帮助';

  @override
  String get shellSidebarDevCatalog => '组件目录 (dev)';

  @override
  String get shellSidebarDevWasmPlugin => 'WASM 插件测试（dev）';

  @override
  String get shellSidebarWebConsole => 'Web 控制台';

  @override
  String get shellSidebarAccountActionsTooltip => '账号操作';

  @override
  String get shellSidebarShowAccountMenu => '查看此账号';

  @override
  String get shellSidebarLogoutMenu => '退出登录';

  @override
  String get shellAccountHeaderPickTooltip => '选择账号';

  @override
  String shellAccountHeaderReadingAsTooltip(String account) {
    return '正在以 $account 浏览';
  }

  @override
  String get shellAccountHeaderSwitchSemantics => '切换账号';

  @override
  String get shellAccountHeaderAvatarSemantics => '账号';

  @override
  String get shellAccountPickerSemantics => '选择账号';

  @override
  String get shellAccountPickerCloseTooltip => '关闭';

  @override
  String get shellAccountFowTitle => 'RASQ 账号';

  @override
  String get shellAccountFowCloseButton => '关闭';

  @override
  String get shellAccountAppealSheetTitle => '申请解除处置';

  @override
  String get shellAccountAppealCaption => '运营方负责人会阅读你的申请，如果受理，处置将被解除。';

  @override
  String get shellAccountAppealCaptionDetail =>
      '运营方（rasq-judge）负责人会阅读你的申请，如果受理，处置将被解除。不经过自动判定。';

  @override
  String get shellAccountAppealReasonHint => '申请理由（必填）';

  @override
  String shellAccountAppealFailedError(String error) {
    return '无法提交申请：$error';
  }

  @override
  String get shellAccountAppealSubmitButton => '提交申请';

  @override
  String get shellAccountAppealSentSnack => '已提交解除申请。负责人将进行确认';

  @override
  String get shellAccountLocalDisplayName => '此设备';

  @override
  String get shellAccountMenuAddSns => '添加 SNS 账号';

  @override
  String get shellAccountMenuAllSettings => '设置';

  @override
  String get shellAccountMenuAccountPage => '账号页面';

  @override
  String get shellAccountMenuEditProfile => '编辑个人资料';

  @override
  String get shellAccountMenuAccountSettings => '账号设置';

  @override
  String get shellAccountMenuNotificationSettings => '通知设置';

  @override
  String get shellAccountMenuSecurity => '安全（邮箱 / 密码 / 设备）';

  @override
  String get shellAccountMenuLogout => '退出登录';

  @override
  String get shellAccountMenuDelete => '删除 RASQ 账号';

  @override
  String get shellAccountLogoutTitle => '退出 RASQ 账号';

  @override
  String get shellAccountLogoutMessage => '将从此设备移除 RASQ 账号。';

  @override
  String get shellAccountLogoutConfirmButton => '退出登录';

  @override
  String get shellAccountLoggedOutWithSnsSnack => '已退出 RASQ 账号及其 SNS 账号';

  @override
  String get shellAccountLoggedOutKeptSnsSnack =>
      '已退出 RASQ 账号。SNS 账号已移至“仅限此设备”';

  @override
  String get shellAccountDeleteReloginRequiredError => '请重新登录此账号后再删除';

  @override
  String get shellAccountDeleteNeedsEmailCodeSnack => '删除需要邮件验证码。请从“删除账号”继续操作';

  @override
  String get shellAccountDeleteTitle => '删除 RASQ 账号';

  @override
  String get shellAccountDeleteMessage =>
      '将删除服务器上的个人资料、账号组合、已同步的设置、评价和书签、ASTell 的房间和共享、通知令牌以及同意记录。如果你曾同意“为算法和社区做贡献”，还将同时停止提供并开始删除已提供的数据。\n此操作无法撤销。各 SNS 上的账号和帖子不会被删除。';

  @override
  String get shellAccountDeleteConfirmButton => '删除';

  @override
  String get shellAccountDeletedSnack => '已删除 RASQ 账号';

  @override
  String shellAccountDeleteFailedError(String error) {
    return '无法删除：$error';
  }

  @override
  String shellAccountCreatedSnack(String handle) {
    return '已创建 RASQ 账号 @$handle';
  }

  @override
  String shellAccountSanctionActive(String level) {
    return '此账号受到处置：$level';
  }

  @override
  String shellAccountSanctionRestrictedFeatures(String features) {
    return '已停用的功能：$features';
  }

  @override
  String shellAccountSanctionReviewDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '每次发言都会有 $seconds 秒的审查延迟',
    );
    return '$_temp0';
  }

  @override
  String shellAccountSanctionStaffNote(String note) {
    return '运营方留言：$note';
  }

  @override
  String get shellAccountSanctionNoExpiry => '期限：无';

  @override
  String shellAccountSanctionExpiry(String expiresAt) {
    return '期限：$expiresAt';
  }

  @override
  String shellAccountSanctionAppealButton(String category, String level) {
    return '申请解除（$category / $level）';
  }

  @override
  String shellAccountSanctionAppealPending(String category) {
    return '申请中（$category）';
  }

  @override
  String get shellAccountEmpty => '还没有 RASQ 账号。';

  @override
  String shellAccountRowSubtitle(String kind, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个',
    );
    return '$kind · SNS $_temp0';
  }

  @override
  String get shellAccountRowInUseSuffix => ' · 使用中';

  @override
  String get shellAccountRowNeedsLoginSuffix => ' · 需要登录';

  @override
  String get shellAccountCollapseActionsTooltip => '收起操作';

  @override
  String get shellAccountActionsTooltip => '账号操作';

  @override
  String shellAccountReloginSnack(String handle) {
    return '请重新登录 @$handle';
  }

  @override
  String get shellAccountChildSafeButton => '儿童安全';

  @override
  String get shellAccountCreateButton => '新建账号';

  @override
  String get shellAccountLoginButton => '登录';

  @override
  String get shellAccountServerNotConfigured => '尚未设置 RASQ 服务器的连接地址';

  @override
  String get shellAccountConfigureServerButton => '设置连接目标';

  @override
  String get shellAccountProfileSheetTitle => '编辑个人资料';

  @override
  String get shellAccountProfileSaveButton => '保存';

  @override
  String get shellAccountProfileDisplayNameLabel => '显示名称';

  @override
  String get shellAccountProfileDisplayNameHint => '显示名称';

  @override
  String get shellAccountProfileHandleLabel => '用户名（不含 @,a-z 0-9 _）';

  @override
  String get shellAccountProfileCentralCaption => '将更新 RASQ 服务器上的个人资料。';

  @override
  String get shellAccountProfileLocalCaption =>
      '这是仅存在于此设备的账号。创建 RASQ 账号后才会分配用户名。';

  @override
  String get shellAccountProfileSavedSnack => '已保存个人资料';

  @override
  String shellAccountProfileSaveFailedError(String error) {
    return '无法保存：$error';
  }

  @override
  String get shellAccountTileMenuTooltip => 'RASQ 账号';

  @override
  String get shellTermsSheetTitle => '同意使用条款';

  @override
  String get shellTermsAgreeButton => '同意';

  @override
  String get shellTermsNotice =>
      '要继续使用 RASQ 账号，需要同意当前的使用条款和隐私政策。在同意之前，无法使用 ASTell、购买和数据托管。';

  @override
  String shellTermsNoticeDetail(String endpoints) {
    return 'D-371 / S-053。在与服务器的 CENTRAL_TERMS_VERSION / CENTRAL_PRIVACY_VERSION 相同版本的同意全部记录之前，状态为“等待同意”。PUT /me/consents/$endpoints。';
  }

  @override
  String get shellTermsReadTermsButton => '阅读使用条款';

  @override
  String get shellTermsReadPrivacyButton => '阅读隐私政策';

  @override
  String get shellTermsAgeHeader => '年龄';

  @override
  String get shellTermsGuardianConsentCheck => '已获得监护人同意';

  @override
  String get shellTermsAgreeCheck => '我已阅读并同意使用条款和隐私政策';

  @override
  String shellTermsVersionCaption(String termsVersion, String privacyVersion) {
    return '版本：使用条款 $termsVersion · 隐私政策 $privacyVersion';
  }

  @override
  String get shellTermsAcceptedSnack => '已同意使用条款';

  @override
  String get shellTermsOutdatedError => '使用条款已更新。请先更新应用再同意';

  @override
  String shellTermsRecordFailedError(String error) {
    return '无法记录同意：$error';
  }

  @override
  String get shellTermsBannerText => '需要同意使用条款。在同意之前，无法使用 ASTell、购买等功能。';

  @override
  String get shellTermsBannerOpenButton => '查看';

  @override
  String get storeStatusInReview => '审核中';

  @override
  String get storeStatusPublished => '已发布';

  @override
  String get storeStatusUpdateAvailable => '有更新';

  @override
  String get storeStatusWarning => '警告';

  @override
  String get storeStatusSuspended => '已停止';

  @override
  String get storeStatusWithdrawn => '已撤下';

  @override
  String get storeStatusUnlisted => '非公开';

  @override
  String get storeStatusBeta => '测试版';

  @override
  String get storeStatusRevoked => '已失效';

  @override
  String get storeOriginOfficial => '官方';

  @override
  String get storeOriginVerified => '已验证';

  @override
  String get storeOriginCommunity => '社区';

  @override
  String get storeTypeComposer => '发帖';

  @override
  String get storeTypePost => '帖子';

  @override
  String get storeTypeViewer => '全屏显示';

  @override
  String get storeTypeTimeline => '时间线';

  @override
  String get storeTypeTrend => '趋势';

  @override
  String get storeTypeTheme => '主题';

  @override
  String get storeTypeAssets => '贴纸 / 素材';

  @override
  String get storeTypeCustom => '自定义';

  @override
  String get storeTypeOther => '其他';

  @override
  String get storeFilterFree => '免费';

  @override
  String get storeFilterNoAds => '无广告';

  @override
  String get storeFilterOfficial => '官方';

  @override
  String get storeFilterVerified => '已认证';

  @override
  String get storeFilterRecent => '30 天内';

  @override
  String get storeFilterLightweight => '轻量（小于 5MB）';

  @override
  String get storeFilterOffline => '离线';

  @override
  String get storePermNetwork => '网络';

  @override
  String get storePermNetworkDescription => '对外通信';

  @override
  String get storePermStorage => '存储';

  @override
  String get storePermStorageDescription => '设备内的存储空间';

  @override
  String get storePermFiles => '文件';

  @override
  String get storePermFilesDescription => '读写用户选择的文件';

  @override
  String get storePermSns => '帖子和账号';

  @override
  String get storePermSnsDescription => '使用 SNS 账号进行的操作';

  @override
  String get storePermDm => '私信';

  @override
  String get storePermDmDescription => '读写私信';

  @override
  String get storePermGpuMl => 'GPU / 机器学习';

  @override
  String get storePermGpuMlDescription => 'GPU 运行、模型推理';

  @override
  String get storePermClipboard => '剪贴板';

  @override
  String get storePermClipboardDescription => '读写复制的内容';

  @override
  String get storePermBackground => '后台运行';

  @override
  String get storePermBackgroundDescription => '关闭画面后仍会运行';

  @override
  String get storePermUi => '画面与布局';

  @override
  String get storePermUiDescription => '画面显示和按钮布局';

  @override
  String get storePermOther => '其他';

  @override
  String get storeReviewSortHelpful => '相关度';

  @override
  String get storeReviewSortRecent => '最新';

  @override
  String get storeReviewSortRatingHigh => '评分最高';

  @override
  String get storeReviewSortRatingLow => '评分最低';

  @override
  String storeScopePermission(String permission) {
    return '权限 $permission';
  }

  @override
  String storeScopeHost(String host) {
    return '连接目标 $host';
  }

  @override
  String get storeScopeInstance => '连接目标 登录的实例';

  @override
  String storeScopeSlot(String slot) {
    return '使用位置 $slot';
  }

  @override
  String storeScopeReason(String permission, String reason) {
    return '用途 $permission — $reason';
  }

  @override
  String storeScopeDataHandling(String text) {
    return '数据处理 — $text';
  }

  @override
  String storeNeedsOrgate(String feature) {
    return '连接 ORGATE-Server 后即可使用$feature（尚未设置连接地址）';
  }

  @override
  String get storeFeaturePurchase => '购买';

  @override
  String get storeFeaturePoints => '积分';

  @override
  String get storeFeatureReview => '评价';

  @override
  String storeSessionPluginMismatch(String actual, String expected) {
    return '配置中的插件（$actual）与请求的（$expected）不同';
  }

  @override
  String storeSessionVersionMismatch(String actual, String expected) {
    return '配置的版本（$actual）与请求的版本（$expected）不同';
  }

  @override
  String get storeNoBundle => '没有分发包';

  @override
  String get storeListSeparator => '、';

  @override
  String get storeDotSeparator => ' · ';

  @override
  String get storeVerifyHashOnly => 'SHA-512 校验 OK（无签名）';

  @override
  String get storeVerifyFull => 'SHA-512 + ed25519 签名验证 OK';

  @override
  String get storeVerifyHashMismatch => '完整性验证失败（SHA-512 不一致）。请稍后重新获取';

  @override
  String get storeVerifyKeyMismatch => '商店的签名密钥与应用内置的密钥不一致。请检查连接地址';

  @override
  String get storeVerifyUnsigned => '分发包没有签名（此版本仅允许已签名的商店）';

  @override
  String get storeVerifyBadSignature => '分发包的签名不正确。已中止安装';

  @override
  String storeVerifyError(String error) {
    return '无法验证签名：$error';
  }

  @override
  String get storeWidenedNoRecord => '因为没有上次允许内容的记录（请在管理插件中确认后安装）';

  @override
  String storeWidenedOver(String items) {
    return '因为超出了上次允许的内容（$items）';
  }

  @override
  String get storeManifestUnavailable => '无法获取配置（清单）';

  @override
  String storeManifestVersionNotFound(String version) {
    return '未找到 Ver.$version 的配置';
  }

  @override
  String storeConsentChanged(String version) {
    return '商店的配置与你确认的内容（Ver.$version）有所不同。请再次确认';
  }

  @override
  String storePackageInvalid(String error) {
    return '无法验证分发包的内容：$error';
  }

  @override
  String storePackageMismatch(String actual, String expected) {
    return '分发包的内容（$actual）与商店上架信息（$expected）不同';
  }

  @override
  String storePackageRequires(String plugins) {
    return '此插件需要 $plugins（尚不支持，无法安装）';
  }

  @override
  String storeThemeSaveFailed(String error) {
    return '无法保存主题：$error';
  }

  @override
  String storeAssetsSaveFailed(String error) {
    return '无法保存素材包：$error';
  }

  @override
  String get storeSlotRegisterFailed => '无法注册到插槽';

  @override
  String storeVersionBundleChanged(String version) {
    return 'Ver.$version 的分发包与安装时不同，因此不会加载（请重新安装）';
  }

  @override
  String storeVersionLoadFailed(String version, String error) {
    return '无法加载 Ver.$version：$error';
  }

  @override
  String get storeVersionNoScopeRecord => '没有此版本允许内容的记录（重新安装即可确认）';

  @override
  String storeVersionNotInstalled(String version) {
    return '未安装 Ver.$version';
  }

  @override
  String get storeNotInstalled => '未安装';

  @override
  String storeVersionInUse(String version) {
    return 'Ver.$version 正在使用中（请先取消默认 / 账号的指定）';
  }

  @override
  String get storeManageTitle => '管理插件';

  @override
  String get storeManageUpdatesHeader => '更新';

  @override
  String get storeManageUpdateSettingsTitle => '更新设置';

  @override
  String get storeManageUpdateSettingsSubtitle => '是否自动更新 · 更新日志';

  @override
  String get storeManageUpdateSettingsDetail =>
      '按 SNS / 操作 / 视图分别选择：自动、仅安装、手动 · 更新日志';

  @override
  String get storeManagePointsTitle => '积分';

  @override
  String get storeManagePointsDisabled => '公开测试中无法使用';

  @override
  String storeManagePointsBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '积分 $count',
    );
    return '$_temp0';
  }

  @override
  String get storeManagePointsSignIn => '登录 RASQ 账号后即可使用';

  @override
  String get storeManagePointsBuyInConsole => '可在网页控制台购买（发放后 1 个月失效）';

  @override
  String storeManagePointsExpiring(int month, int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 积分将于 $month/$day 失效 · 在网页控制台购买',
    );
    return '$_temp0';
  }

  @override
  String get storeNoInstalledPlugins => '没有已安装的插件';

  @override
  String get storeManageImportTitle => '导入插件';

  @override
  String get storeManageImportSubtitle => '安装开发中的插件（审核前）';

  @override
  String get storeManageImportDetail => '安装开发中的 wasm / .rasqpkg（未经审核）';

  @override
  String get storeManageHomeHeader => '首页显示';

  @override
  String get storeManageShowInstalledTitle => '在首页也显示已安装的插件';

  @override
  String get storeManageShowInstalledSubtitle => '在本周趋势 / 新上架栏中也列出已安装的插件';

  @override
  String get storeBookmarksTitle => '书签';

  @override
  String storeManageSwitchTo(String version) {
    return '切换到 $version';
  }

  @override
  String storeVersionMadeDefault(String version) {
    return '已将 $version 设为默认版本';
  }

  @override
  String storeManageUpdateTo(String version) {
    return '更新到 $version';
  }

  @override
  String get storeManageOffline => '无法连接到商店';

  @override
  String get storeManageUpToDate => '已是最新';

  @override
  String get storeManageDeployedVersion => '已部署的版本';

  @override
  String get storeAccountVersionsTitle => '按账号设置版本';

  @override
  String storeManageAccountVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '按账号（已指定 $count 个）',
    );
    return '$_temp0';
  }

  @override
  String get storePluginNotFound => '未找到此插件';

  @override
  String storeInstallFailed(String error) {
    return '无法安装：$error';
  }

  @override
  String get storeHasAds => '含广告';

  @override
  String get storeBuyDisabled => '公开测试中无法购买';

  @override
  String get storeTileGet => '获取';

  @override
  String get storeTileUpdate => '更新';

  @override
  String get storeOpen => '打开';

  @override
  String get storeTileUnavailable => '已停止';

  @override
  String storeDownloadsTenThousands(String value) {
    return '$value万';
  }

  @override
  String storeNotAssetPack(String id) {
    return '不是素材包：$id';
  }

  @override
  String get storeUpdatesNoneApplied => '没有自动安装的更新';

  @override
  String get storeUpdateSettingsTitle => '更新/部署设置';

  @override
  String get storeUpdateSettingsModeHeader => '更新/部署';

  @override
  String get storeUpdateSettingsPopup => '更新后启动时显示弹窗';

  @override
  String get storeUpdateLogTitle => '更新日志';

  @override
  String get storeUpdateSettingsCheckNow => '立即检查';

  @override
  String get storeUpdateSettingsCaption => '扩大已允许内容的版本和付费版本不会自动安装';

  @override
  String get storeUpdateSettingsCaptionDetail =>
      '权限、连接目标、使用位置、用途超出上次允许内容的版本（包括无法确认的版本），以及未购买的付费版本，在任何模式下都不会自动开始使用（原因会记录在更新日志中）。每次启动时检查一次。';

  @override
  String get storeUpdateLogEmpty => '暂无';

  @override
  String get storeUpdateLogEmptyHint => '更新后会记录在这里';

  @override
  String get storeInstalledTitle => '已安装';

  @override
  String get storeInstalledEmptyHint => '可以从商店添加';

  @override
  String storeInstalledItemSubtitle(String version, String id) {
    return 'v$version · $id';
  }

  @override
  String get storeUnknown => '未知';

  @override
  String get storeInstalledMissingHint => '已被删除，或是在其他设备上安装的';

  @override
  String get storeInstalledSourceSnapshot => '安装时上架信息的副本。';

  @override
  String get storeInstalledSourceManifest => '插件自身的声明（仅权限 id）。';

  @override
  String get storeInstalledRemoveTitle => '要删除吗？';

  @override
  String storeInstalledRemoveMessage(String name) {
    return '将从设备中删除 $name。';
  }

  @override
  String get storeRemove => '删除';

  @override
  String get storeCancel => '取消';

  @override
  String get storeInstalledOffline => '无法连接到商店，因此显示本地信息。';

  @override
  String get storeInstalledUnlisted => '未找到商店上架信息（可能已被撤下）。可以继续使用，也可以删除。';

  @override
  String get storeInstalledVersionHeader => '已安装的版本';

  @override
  String storeInstalledAt(String date) {
    return '安装：$date';
  }

  @override
  String storeInstalledAtVerified(String date, String sha512) {
    return '安装：$date · 已验证 SHA-512 $sha512';
  }

  @override
  String storeInstalledNewerTitle(String version) {
    return '商店中有 v$version';
  }

  @override
  String get storeInstalledNewerSubtitle => '可以从商店页面重新安装';

  @override
  String storeInstalledSlots(String slots) {
    return '运行位置：$slots';
  }

  @override
  String get storeInstalledOpenStore => '打开商店页面';

  @override
  String get storePrivacyHeader => '隐私和所需权限';

  @override
  String get storeVersionsInstalledHeader => '已安装的版本';

  @override
  String get storeVersionsDefault => '默认版本';

  @override
  String storeVersionsUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个账号正在使用',
    );
    return '$_temp0';
  }

  @override
  String storeVersionsInstalledOn(int year, int month, int day) {
    return '安装于 $year/$month/$day';
  }

  @override
  String get storeMenu => '菜单';

  @override
  String get storeVersionsMakeDefault => '设为默认版本';

  @override
  String get storeVersionsRemove => '删除此版本';

  @override
  String storeVersionsRemoved(String version) {
    return '已删除 $version';
  }

  @override
  String get storeVersionsOthersHeader => '安装其他版本';

  @override
  String get storeVersionsMorePermissions => '权限会增加';

  @override
  String get storeVersionsInstall => '安装';

  @override
  String get storeVersionsPerAccountHeader => '按账号';

  @override
  String get storeVersionsPerAccountCaption => '可以为每个账号选择使用的版本';

  @override
  String get storeVersionsPerAccountDetail => '使用该账号期间，插槽插件和节点排序将以此处选择的版本运行。';

  @override
  String storeVersionsFollowDefault(String version) {
    return '跟随默认（$version）';
  }

  @override
  String storeVersionsAccountFollows(String account) {
    return '$account 跟随默认版本';
  }

  @override
  String storeVersionsAccountUses(String account, String version) {
    return '$account 使用 $version';
  }

  @override
  String storeVersionsDefaultShort(String version) {
    return '默认（$version）';
  }

  @override
  String get storeVersionsPackNote => '主题 / 贴纸·素材在整个设备上使用同一个版本（默认版本）。';

  @override
  String get storeUpdateModeAuto => '全自动';

  @override
  String get storeUpdateModeAutoDescription => '安装新版本并设为默认版本（按账号指定的版本保持不变）';

  @override
  String get storeUpdateModeInstallOnly => '仅自动安装';

  @override
  String get storeUpdateModeInstallOnlyDescription => '仅安装新版本，不更改使用的版本';

  @override
  String get storeUpdateModeManual => '全部手动配置';

  @override
  String get storeUpdateModeManualDescription => '不自动进行任何操作（从管理插件安装）';

  @override
  String get storeUpdateGroupSns => 'SNS 插件';

  @override
  String get storeUpdateGroupAction => '操作插件';

  @override
  String get storeUpdateGroupView => '视图插件';

  @override
  String storeUpdateLogActivated(String from, String to) {
    return '$from → $to（已设为默认版本）';
  }

  @override
  String storeUpdateLogInstalled(String from, String to) {
    return '已安装 $to（使用的版本仍为 $from）';
  }

  @override
  String storeUpdateLogSwitched(String from, String to) {
    return '$from → $to（将已安装的版本设为默认）';
  }

  @override
  String storeUpdateLogSkipped(String to) {
    return '$to 不会自动安装';
  }

  @override
  String storeUpdateLogSkippedNote(String to, String note) {
    return '$to 不会自动安装（$note）';
  }

  @override
  String storeUpdateLogFailed(String to) {
    return '无法安装 $to';
  }

  @override
  String storeUpdateLogFailedNote(String to, String note) {
    return '无法安装 $to（$note）';
  }

  @override
  String get storeUpdatePopupTitle => '插件已更新';

  @override
  String get storeClose => '关闭';

  @override
  String get storeReviewsTitle => '评价';

  @override
  String get storeReviewsLoadFailed => '无法获取评价';

  @override
  String get storeReviewWrite => '撰写评价';

  @override
  String get storeReviewsEmpty => '暂无评价';

  @override
  String get storeReviewsEmptyHint => '点击右下角的 + 撰写第一条评价';

  @override
  String get storeCopyLink => '复制链接';

  @override
  String get storeReviewReport => '举报评价';

  @override
  String get storeReviewLinkCopied => '已复制评价链接';

  @override
  String get storeReviewReportUnavailable => '举报评价功能准备中';

  @override
  String storeReloadFailed(String error) {
    return '无法重新加载：$error';
  }

  @override
  String get storeNoNewPlugins => '没有新发布的插件';

  @override
  String storeNewPluginsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已添加 $count 个新发布的插件',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchTitle => '搜索插件';

  @override
  String get storeSearchRecentPick => '根据最近的帖子内容推荐';

  @override
  String get storeSearchFailed => '无法搜索';

  @override
  String get storeSearchNoRecentPosts => '未找到最近的帖子';

  @override
  String get storeSearchNoRecentPostsHint => '使用 SNS 账号发帖后，将推荐与内容相近的插件';

  @override
  String storeSearchRecentCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '按与最近 $count 条帖子内容的接近程度排序（在设备内选出）',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchNoRecentMatches => '未找到与最近帖子相近的插件';

  @override
  String get storeSearchNoResults => '未找到结果';

  @override
  String get storeSearchNoResultsHint => '请尝试更换关键词或筛选条件';

  @override
  String get storeHomeTitle => '插件商店';

  @override
  String get storeConnectFailed => '无法连接到商店';

  @override
  String get storeHomeOffline => '未连接到 RASQ 服务器。仅显示应用内置的插件';

  @override
  String get storeHomeOfflineDetail =>
      '未连接 Central：仅显示内置的实物（Misskey 连接器和插槽示例）。评分 / 下载数 / 评价 / 购买在连接服务器后显示。';

  @override
  String get storeHomeTrending => '本周趋势';

  @override
  String get storeHomeRecent => '新上架';

  @override
  String get storeHomeReviewedOnly => '仅上架已审核的插件';

  @override
  String get storeHomeReviewedOnlyDetail =>
      '开发中的插件可在开发者模式下，通过右上角的齿轮 → 管理插件 →“导入插件”安装。';

  @override
  String get storeRowEmpty => '目前没有可显示的插件';

  @override
  String get storeInstallManifestUnavailable => '无法获取配置';

  @override
  String storeInstallSheetTitle(String name, String version) {
    return '安装 $name $version';
  }

  @override
  String get storeInstallPermissionsHeader => '此插件使用的权限';

  @override
  String get storeInstallHostsHeader => '连接目标';

  @override
  String get storeInstallLoginInstance => '登录的实例';

  @override
  String get storeInstallScopeNoRecord => '允许的内容（没有之前安装时的记录）';

  @override
  String get storeInstallScopeWidened => '超出上次允许内容的部分';

  @override
  String get storeInstallPermissionsAdded => '比上一版本增加的权限';

  @override
  String storeInstallBundleSummary(String size, String signature) {
    return '${size}MB · $signature';
  }

  @override
  String get storeInstallSignedShort => '有商店签名';

  @override
  String get storeInstallUnsignedShort => '无商店签名';

  @override
  String storeInstallBundleDetail(
    String size,
    String sha512,
    String signature,
  ) {
    return '分发包：${size}MB · SHA-512 $sha512… · $signature';
  }

  @override
  String get storeInstallSignedDetail => '带商店签名（ed25519）';

  @override
  String get storeInstallUnsignedDetail => '无商店签名（仅哈希校验）';

  @override
  String get storeInstallConfirm => '安装';

  @override
  String storeInstallThemeDarkOnly(String name) {
    return '将使用 $name。在深色模式下生效';
  }

  @override
  String storeInstallThemeLightOnly(String name) {
    return '将使用 $name。在浅色模式下生效';
  }

  @override
  String storeInstallThemeApplied(String name) {
    return '将使用 $name';
  }

  @override
  String storeInstallDone(String name, String version) {
    return '已安装 $name $version';
  }

  @override
  String storeVersionScopeTitle(String version) {
    return 'Ver.$version 将扩大允许的内容';
  }

  @override
  String get storeVersionScopeConfirm => '允许并使用';

  @override
  String get storeVersionScopeCancel => '取消';

  @override
  String storePurchasePointsFailed(String error) {
    return '无法确认积分（是否已登录 RASQ 账号？）：$error';
  }

  @override
  String storePurchaseTitle(String name) {
    return '购买 $name';
  }

  @override
  String storePurchasePrice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 积分',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩余 $count 积分',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalanceExpiring(int count, String date, int expiring) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩余 $count 积分 · $expiring 积分将于 $date 失效',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseCaption => '购买的插件在同一账号的任何设备上都可以使用';

  @override
  String get storePurchaseCaptionDetail =>
      '购买的插件在同一 RASQ 账号的任何设备上都可以安装。积分从最接近到期的开始使用。';

  @override
  String storePurchaseBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '用 $count 积分购买',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '积分不足（还差 $count 积分）',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseConsole => '在网页控制台购买积分';

  @override
  String get storePurchaseFailed => '无法购买';

  @override
  String storeReleaseNotesSemantics(String version) {
    return '发布说明 $version';
  }

  @override
  String get storeReleaseBeta => '预览版（β）';

  @override
  String get storeReleaseStable => '稳定版';

  @override
  String storeReleasePublishedOn(int year, int month, int day) {
    return '$year/$month/$day 发布';
  }

  @override
  String get storeReleaseCurrentListing => '当前上架版本';

  @override
  String get storeReleaseInstalled => '已安装';

  @override
  String get storeReleaseNoNotes => '此版本没有发布说明。';

  @override
  String get storeReleasePermissionsAdded => '此版本增加的权限';

  @override
  String get storeReleasePermissionsNote => '增加权限的更新不会自动进行。请确认内容后再安装。';

  @override
  String storeReleaseAlreadyInstalled(String version) {
    return 'Ver.$version 已安装';
  }

  @override
  String storeReleaseBlocked(String status) {
    return '因$status而无法安装';
  }

  @override
  String storeReleaseInstall(String version) {
    return '安装 Ver.$version';
  }

  @override
  String storeReleaseReplaces(String version) {
    return '当前已安装 v$version。将替换为此版本。';
  }

  @override
  String get storeReviewNoVotes => '暂无评分';

  @override
  String storeReviewHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人认为有帮助。',
    );
    return '$_temp0';
  }

  @override
  String get storeShare => '分享';

  @override
  String get storeReviewHelpful => '有帮助';

  @override
  String get storeReviewNotHelpful => '没有帮助';

  @override
  String get storeReviewAnonymous => '匿名';

  @override
  String get storeReviewVerifiedUse => '已实际使用';

  @override
  String storeReviewDeveloperReply(String reply) {
    return '开发者回复：$reply';
  }

  @override
  String get storeReviewNoBody => '（无正文）';

  @override
  String get storeReviewComposeTitle => '撰写评价';

  @override
  String get storeReviewSend => '发送';

  @override
  String get storeRatingLabel => '评分';

  @override
  String get storeReviewTitleHint => '标题（可选）';

  @override
  String get storeReviewBodyHint => '请输入使用感受或在意的地方';

  @override
  String storeReviewUsedVersion(String version) {
    return '使用版本：v$version';
  }

  @override
  String get storeReviewPickRating => '请选择 ★';

  @override
  String get storeReviewSent => '已发送评价';

  @override
  String storeReviewSendFailed(String error) {
    return '无法发送评价：$error';
  }

  @override
  String get storeReviewNeedsInstall => '只能评价已安装的插件';

  @override
  String get storeReviewNeedsInstallServer => '只能评价已安装的插件。在登录状态下重新安装（或更新）后即可评价';

  @override
  String get storeSafetyNoPermissions => '所需权限：无';

  @override
  String get storeSafetyExternalHeader => '外部通信与数据';

  @override
  String get storeSafetyNoHosts => '外部通信目标：无';

  @override
  String storeSafetyHosts(String hosts) {
    return '外部通信目标：$hosts';
  }

  @override
  String storeSafetyDataHandling(String text) {
    return '数据处理：$text';
  }

  @override
  String storeSafetySdks(String sdks) {
    return '外部 SDK：$sdks';
  }

  @override
  String get storeSafetyRuntimeHeader => '运行环境';

  @override
  String storeSafetyCrashFree(String rate) {
    return '正常启动率 $rate%';
  }

  @override
  String get storeSafetyBackground => '有后台运行';

  @override
  String get storeSafetyNoBackground => '无后台运行';

  @override
  String get storeSafetyGpu => '使用 GPU';

  @override
  String get storeSafetyNoGpu => '不使用 GPU';

  @override
  String get storeSafetyNoAds => '无广告';

  @override
  String storeSafetyAds(String placements) {
    return '含广告（$placements）';
  }

  @override
  String get storePageMenuPostReview => '发布评价';

  @override
  String get storePageMenuReport => '举报插件';

  @override
  String get storePageLinkCopied => '已复制商店页面链接';

  @override
  String get storePageTitle => '插件';

  @override
  String get storePageMaybeWithdrawn => '可能已被撤下';

  @override
  String get storePageOpenInstalled => '查看已安装的信息';

  @override
  String get storePageRequiresPrefix => '要使用此插件，需要安装 ';

  @override
  String get storePageRequiresSuffix => '。';

  @override
  String storePageInstalledVersion(String version) {
    return '已安装 v$version';
  }

  @override
  String storePageInstalledVersionVerified(String version) {
    return '已安装 v$version（SHA-512 已验证）';
  }

  @override
  String get storeFree => '免费';

  @override
  String storePriceYen(String amount) {
    return '¥$amount';
  }

  @override
  String get storePageInstall => '安装';

  @override
  String storePageBuy(String amount) {
    return '以 ¥$amount 购买';
  }

  @override
  String get storePageThemeInUse => '使用中';

  @override
  String get storePageThemeUse => '使用';

  @override
  String get storePageUnknownDeveloper => '提供者不明';

  @override
  String storePageRatingDownloads(String rating, String downloads) {
    return '★$rating · $downloads 次下载';
  }

  @override
  String storePageStatus(String status) {
    return '状态：$status';
  }

  @override
  String get storePagePreview => '预览';

  @override
  String get storePageDownloadsLastMonth => '上月下载数';

  @override
  String storePageReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String get storePageReviewsEmptyBody => '来写第一条评价吧。';

  @override
  String get storePageUpdatesHeader => '更新与版本';

  @override
  String get storePageNoReleaseNotes => '暂无发布说明。';

  @override
  String get storeInUse => '使用中';

  @override
  String storePermissionsAddedList(String permissions) {
    return '新增权限：$permissions';
  }

  @override
  String get storePagePermissionsHeader => '权限';

  @override
  String get storePageNoPermissions => '此插件不需要额外的权限。';

  @override
  String get storePageCompatibilityHeader => '兼容性';

  @override
  String storePageRuntimes(String runtimes) {
    return '运行时：$runtimes';
  }

  @override
  String storePageRequiredPlugins(String plugins) {
    return '所需插件：$plugins';
  }

  @override
  String storePageConflicts(String plugins) {
    return '冲突：$plugins';
  }

  @override
  String storePageRasqFeatures(String features) {
    return '使用的 RASQ 功能：$features';
  }

  @override
  String get storePageVersionsTitle => '版本';

  @override
  String storePageNoPreview(String name) {
    return '$name 暂无预览图';
  }

  @override
  String get storePageBookmarkRemove => '移除书签';

  @override
  String get storePageBookmarkAdd => '加入书签';

  @override
  String storePageBookmarkFailed(String error) {
    return '无法更新书签：$error';
  }

  @override
  String storeNeedsServer(String feature) {
    return '连接 RASQ 服务器后即可使用$feature';
  }

  @override
  String get storeNoListing => '没有上架信息';

  @override
  String get storeCatalogMisskeyName => 'Misskey 连接器';

  @override
  String get storeCatalogMisskeySummary =>
      '将 Misskey 接入 RASQ 的 SNS 插件（wasm 示例）。涵盖获取时间线、发帖、回应、表情符号和帖子加工。';

  @override
  String get storeCatalogMisskeyDescription =>
      'rasq-sdk-sample 中用 Rust 编写的 wasm 插件。实现了 sns.login / sns.timeline / post.transform / tl.sort 等契约（PROTOCOL.md），并用 RRL 卡片渲染时间线。没有节点定义的帖子加工会在传给获取节点之前应用。';

  @override
  String get storeCatalogFeatureTimelineRrl => '时间线渲染 (RRL)';

  @override
  String get storeCatalogFeatureNodeGraph => '节点图 (tl.sort)';

  @override
  String get storeCatalogMisskeyPerm1 => '用于调用 Misskey 实例的 API（仅连接登录时指定的主机）';

  @override
  String get storeCatalogMisskeyPerm2 => '保存会话令牌和时间线设置';

  @override
  String get storeCatalogMisskeyHost => '<已登录的 Misskey 实例>';

  @override
  String get storeCatalogMisskeyDataHandling =>
      '帖子和令牌仅保存在设备内（storage.safe）。不会发送给开发者。';

  @override
  String get storeCatalogSampleDataHandling => '处理完全在设备内的 wasm 中完成，不会向外部发送。';

  @override
  String get storeCatalogAstellName => 'ASTell 音效与特效画面';

  @override
  String get storeCatalogAstellSummary => '通过 ASTell 的插件操作播放音效、生成的特效画面和固定文本。';

  @override
  String get storeCatalogAstellDescription =>
      '插槽 `astell.action`。点按房间下方由本插件声明的按钮即可打开 FOW，共享系统音效（叮咚 / 点击）、生成的彩带、烟花、鼓掌 PNG 以及固定文本。也会显示通过“分享到 ASTell”收到的帖子。';

  @override
  String get storeCatalogFeatureAstellAction => 'ASTell 插件操作';

  @override
  String get storeCatalogAstellPerm1 => '用于显示操作面板（FOW）';

  @override
  String get storeCatalogAstellPerm2 => '保存特效的使用次数';

  @override
  String get storeCatalogComposerMediaName => '媒体加工';

  @override
  String get storeCatalogComposerMediaSummary => '对附加图片进行伽马校正、旋转、色相调整和裁剪。';

  @override
  String get storeCatalogComposerMediaDescription =>
      '插槽 `composer.media`。在编辑器的附件卡片中点按“用插件加工”即可打开 FOW，边看预览边应用。处理仅在设备内的 wasm 中完成。';

  @override
  String get storeCatalogFeatureMediaComposer => '媒体编辑器';

  @override
  String get storeCatalogComposerMediaPerm1 => '用于显示加工面板（FOW）';

  @override
  String get storeCatalogComposerMediaPerm2 => '保存上次的设置';

  @override
  String get storeCatalogComposerTextName => '话题标签建议';

  @override
  String get storeCatalogComposerTextSummary => '在正文中输入 # 即显示建议，点按即可插入。';

  @override
  String get storeCatalogComposerTextDescription =>
      '插槽 `composer.text`。接收正文的变化，当光标前是 #… 时显示建议 FOW（最近使用的标签 + 词典）。';

  @override
  String get storeCatalogFeatureTextComposer => '文本编辑器';

  @override
  String get storeCatalogComposerTextPerm1 => '用于显示建议面板（FOW）';

  @override
  String get storeCatalogComposerTextPerm2 => '保存最近使用的标签';

  @override
  String get storeCatalogMediaFullscreenName => 'QR 码检测';

  @override
  String get storeCatalogMediaFullscreenSummary =>
      '在全屏显示的图片中查找 QR 码并标出边框，点按即可打开链接。';

  @override
  String get storeCatalogMediaFullscreenDescription =>
      '插槽 `viewer.overlay`。接收全屏查看器中的图片并检测 QR 码，叠加边界框。点按后显示链接 FOW（复制 / 在浏览器中打开 / 添加到静音词）。';

  @override
  String get storeCatalogFeatureViewerPlugin => '全屏显示插件';

  @override
  String get storeCatalogMediaFullscreenPerm1 => '用于显示链接面板（FOW）';

  @override
  String get storeCatalogMediaFullscreenPerm2 => '用于通过“静音此链接”添加到静音词（每次都会确认）';

  @override
  String get storeCatalogPostProcessName => '相对日期转为日期';

  @override
  String get storeCatalogPostProcessSummary => '将“今天”“昨天”“明天”替换为以发帖日期为基准的日期。';

  @override
  String get storeCatalogPostProcessDescription =>
      '插槽 `post.transform`。在所有时间线显示之前，将正文中的相对日期改写为“9/10（今天）”这样的形式（JST）。不会改动 URL 内的内容。';

  @override
  String get storeCatalogFeaturePostTransform => '帖子加工 (post.transform)';

  @override
  String get storeCatalogTimelineName => 'Unicode 升序时间线';

  @override
  String get storeCatalogTimelineSummary => '在首页添加按正文 Unicode 顺序排列的标签页。';

  @override
  String get storeCatalogTimelineDescription =>
      '插槽 `tl`。接收基础时间线（首页），显示按正文 Unicode 码位升序重新排列的自定义标签页。';

  @override
  String get storeCatalogFeatureTimelineSort => '时间线 (tl.sort)';

  @override
  String get storeCatalogPostShareName => '分享模板';

  @override
  String get storeCatalogPostShareSummary =>
      '在分享 FOW 中用模板（链接 / 引用 / 提及作者）整理帖子并送到编辑器。';

  @override
  String get storeCatalogPostShareDescription =>
      '插槽 `post.share`。自动排列在帖子分享 FOW 的“插件”部分，点按后在内嵌 FOW 中选择文案，并传给编辑器 / 复制 / 浏览器 / ASTell。';

  @override
  String get storeCatalogFeaturePostShare => '帖子分享 (post.share)';

  @override
  String get storeCatalogPostSharePerm1 => '用于显示模板选择面板（FOW）';

  @override
  String get storeCatalogPostSharePerm2 => '保存上次的模板';

  @override
  String get storeCatalogMediaTransformName => '变形手柄';

  @override
  String get storeCatalogMediaTransformSummary => '在图片上叠加旋转 / 裁剪手柄进行编辑。';

  @override
  String get storeCatalogMediaTransformDescription =>
      '插槽 `composer.media`（变形）。在媒体编辑器的预览上用 RRL 叠加层（契约 v0.5 `composer.media.overlay`）绘制手柄，用手指拖动来确定旋转角度或裁剪范围。';

  @override
  String get storeCatalogFeatureOverlay => '叠加层 (overlay)';

  @override
  String get storeCatalogMediaTransformPerm1 => '用于显示面板（FOW）';

  @override
  String get storeCatalogMediaProcessName => '加工（人脸模糊 / 贴纸）';

  @override
  String get storeCatalogMediaProcessSummary =>
      '检测并模糊人脸，将贴纸作为对象贴上（移动 / 缩放 / 旋转 / 删除 / 复制）。';

  @override
  String get storeCatalogMediaProcessDescription =>
      '插槽 `composer.media`（加工）。人脸检测在设备内的 wasm（rustface）中进行，不会向外部发送。贴纸可以通过叠加层的边框和手柄移动。';

  @override
  String get storeCatalogMediaProcessPerm1 => '用于显示贴纸选择面板（FOW）';

  @override
  String get storeCatalogMediaDrawName => '绘图（画笔 / 图形）';

  @override
  String get storeCatalogMediaDrawSummary => '用样条曲线绘制画笔轨迹，并可添加和编辑矩形 / 圆形。';

  @override
  String get storeCatalogMediaDrawDescription =>
      '插槽 `composer.media`（绘图）。画笔用 Catmull-Rom 样条曲线平滑手指轨迹后绘制。图形作为对象可以移动 / 缩放 / 删除 / 复制。';

  @override
  String get storeCatalogMediaDrawPerm1 => '用于显示画笔粗细 / 颜色面板（FOW）';

  @override
  String get storeCatalogMediaDrawPerm2 => '保存画笔设置';

  @override
  String get storeCatalogPostActionName => '帖子按钮';

  @override
  String get storeCatalogPostActionSummary =>
      '稍后阅读 / 复制正文 / 引用草稿 — 按标签加入现有按钮组。';

  @override
  String get storeCatalogPostActionDescription =>
      '插槽 `post.action`。如果清单中的标签（期望插槽）与现有操作按钮相近，会自动加入该按钮组的最底层。在“编辑操作列表”中可按账号更改启用 / 停用和阈值。';

  @override
  String get storeCatalogFeaturePostAction => '帖子操作按钮 (post.action)';

  @override
  String get storeCatalogPostActionPerm1 => '用于显示稍后阅读列表（FOW）';

  @override
  String get storeCatalogPostActionPerm2 => '保存稍后阅读';

  @override
  String get storeCatalogThemeStarryName => '主题“星空”';

  @override
  String get storeCatalogThemeStarrySummary => '夜空背景、点缀星光的帖子卡片、星星点赞。';

  @override
  String get storeCatalogThemeStarryDescription =>
      '主题（`kind: \"theme\"`，契约 v0.16）。不含代码的发布物，声明颜色、图标替换，以及屏幕、帖子卡片、FOW、按钮背景的图片图层。安装后在 设置 → 应用外观 → 字体和配色方案 中选择（在深色模式下生效）。';

  @override
  String get storeCatalogFeatureTheme => '主题';

  @override
  String get storeCatalogThemeRasqName => '主题“RASQ”';

  @override
  String get storeCatalogThemeRasqSummary =>
      '帖子上方带有藏青色渐变条和淡淡的 RASQ 标志，FOW 为绿色渐变。';

  @override
  String get storeCatalogThemeRasqDescription =>
      '主题（`kind: \"theme\"`，契约 v0.17）。帖子卡片上边缘有从 #1F1E33 渐变融入帖子背景色的条带，背景带有淡淡的 RASQ 标志，FOW 背景为从上到下 #02775C → #178178 的渐变（文字为白色）。浅色 / 深色模式均生效。';

  @override
  String get storeCatalogPaintName => '大家一起涂鸦';

  @override
  String get storeCatalogPaintSummary =>
      '每人一格涂鸦，在限定时间内互相展示。可在 ASTell 房间或个人资料中使用。';

  @override
  String get storeCatalogPaintDescription =>
      '自定义插件（插槽 `page`，契约 v0.23）。将 3:4 的格子排成 2 列（每个人看到的顺序随机），点按自己的格子即可在媒体编辑画面的 SVG 模式中涂鸦（用 zstd 压缩后发送保存）。显示期限由各人选择，管理员（会话所有者）决定默认值和上限。到期后由 Central 删除。管理员可以删除他人的涂鸦。';

  @override
  String get storeCatalogFeatureCustomPage => '自定义插件 (page)';

  @override
  String get storeCatalogFeatureSvgPaint => 'SVG 涂鸦';

  @override
  String get storeCatalogFeatureDisplayPeriod => '显示期限';

  @override
  String get storeCatalogFeatureProfile => '个人资料';

  @override
  String get storeCatalogPaintPerm1 => '用于显示涂鸦格子并打开编辑画面';

  @override
  String get storeCatalogPaintPerm2 => '用于在限定时间内共享大家的涂鸦和管理员的设置';

  @override
  String get storeCatalogBoardName => '大家的看板';

  @override
  String get storeCatalogBoardSummary =>
      '计数器、投票、留言墙、🎉。在 ASTell 房间或个人资料中，大家可以使用同一个看板。';

  @override
  String get storeCatalogBoardDescription =>
      '自定义插件（插槽 `page`，契约 v0.18）。添加一个页面，在共享会话中通过服务器变量（计数器 / 投票 / 留言墙）和服务器函数（向所有人发送 🎉）共享同一画面。没有会话时仅在设备内运行。';

  @override
  String get storeCatalogBoardPerm1 => '用于绘制页面';

  @override
  String get storeCatalogBoardPerm2 => '用于共享大家的数值（计数器 / 投票 / 留言墙）';

  @override
  String get storeCatalogBoardPerm3 => '单人使用时保存看板';

  @override
  String get storeCatalogTrendName => '趋势建议';

  @override
  String get storeCatalogTrendSummary => '根据当前的趋势词，用本地规则推荐相关标签。';

  @override
  String get storeCatalogTrendDescription =>
      '插槽 `trend.suggest`。显示在时间线节点（获取趋势 / Today / 建议标签）和搜索首页的“搜索建议”中。使用无需服务器的共现词典 + 前缀匹配。';

  @override
  String get storeCatalogFeatureTrendSuggest => '趋势 (trend.suggest)';

  @override
  String storePkgMissingPlugin(String id) {
    return '分发包中缺少 $id';
  }

  @override
  String get storePkgNotPackage => '分发包不是 .rasqpkg(zstd)';

  @override
  String storePkgUnpack(String error) {
    return '无法解压分发包（已损坏或过大）：$error';
  }

  @override
  String storePkgTar(String error) {
    return '无法读取分发包的 tar:$error';
  }

  @override
  String get storePkgTooManyFiles => '分发包中的文件过多';

  @override
  String storePkgNotRegularFile(String path) {
    return '分发包中含有非普通文件：$path';
  }

  @override
  String storePkgDuplicatePath(String path) {
    return '分发包内的路径重复：$path';
  }

  @override
  String get storePkgBundleFirst => '分发包的开头不是 bundle.json';

  @override
  String storePkgBundleRead(String error) {
    return '无法读取 bundle.json:$error';
  }

  @override
  String storePkgBundleSchema(String schema) {
    return 'bundle.json 的 schema 不是 rasq.bundle/1:$schema';
  }

  @override
  String storePkgFileShape(String what) {
    return 'bundle.json:$what 的 wasm / file 格式不正确';
  }

  @override
  String storePkgNoPath(String what) {
    return 'bundle.json:$what 缺少 path';
  }

  @override
  String storePkgSizeMismatch(String path) {
    return '$path:大小与目录不符';
  }

  @override
  String storePkgHashMismatch(String path) {
    return '$path:SHA-512 与目录不符';
  }

  @override
  String storePkgNoSha512(String what) {
    return 'bundle.json:$what 缺少 sha512';
  }

  @override
  String storePkgNotWasm(String path) {
    return '$path:不是 wasm';
  }

  @override
  String storePkgPluginShape(String what) {
    return 'bundle.json:$what 的格式不正确';
  }

  @override
  String storePkgBadId(String what, String id) {
    return 'bundle.json:$what 的 id 无效：$id';
  }

  @override
  String storePkgBadVersion(String id, String version) {
    return 'bundle.json:$id 的 version 无效：$version';
  }

  @override
  String storePkgBadKind(String id, String kind) {
    return 'bundle.json:$id 的 kind 无效：$kind';
  }

  @override
  String storePkgNoManifest(String id) {
    return 'bundle.json:$id 缺少 manifest';
  }

  @override
  String storePkgManifestRead(String path, String error) {
    return '无法读取 $path:$error';
  }

  @override
  String storePkgManifestMismatch(
    String path,
    String id,
    String version,
    String kind,
  ) {
    return '$path:id / version / kind 与目录（$id $version $kind）不符';
  }

  @override
  String storePkgChildPackKind(String id, String kind) {
    return 'bundle.json:子项 $id 不能为 kind = $kind';
  }

  @override
  String storePkgPackHasWasm(String kind, String id) {
    return 'bundle.json:$kind $id 包含 wasm';
  }

  @override
  String storePkgMissingKey(String key) {
    return 'bundle.json:缺少 $key';
  }

  @override
  String get storePkgChildrenNotSns => 'bundle.json:sns 以外的 root 不能有 children';

  @override
  String storePkgChildPrefix(String id, String root) {
    return 'bundle.json:子项 $id 的 id 不是以 $root. 开头';
  }

  @override
  String storePkgChildSns(String id) {
    return 'bundle.json:子项 $id 不能为 kind = sns';
  }

  @override
  String get storePkgDuplicateId => 'bundle.json:插件 id 重复';

  @override
  String get storePkgLibsShape => 'bundle.json:libs 的格式不正确';

  @override
  String get storePkgAssetsShape => 'bundle.json:assets 的格式不正确';

  @override
  String get storePkgPackExtras =>
      'bundle.json:素材包 / 主题不能有 children / libs / models';

  @override
  String get storePkgPackWasm => '素材包 / 主题中包含 wasm';

  @override
  String storePkgPackImageCount(int max, int count) {
    return '素材包的图片数量须为 1~$max 张：$count';
  }

  @override
  String storePkgNotImage(String path) {
    return '$path:不是图片（PNG / JPEG / WebP / GIF）';
  }

  @override
  String storePkgImageTooLarge(String path, int mib) {
    return '$path:过大（每张最多 $mib MiB）';
  }

  @override
  String storePkgAssetNotListed(String path) {
    return 'manifest.assets 中的 $path 不在分发包的目录中';
  }

  @override
  String get storePkgModelsShape => 'bundle.json:models 的格式不正确';

  @override
  String get storePkgRequiresShape => 'bundle.json:requires 的格式不正确';

  @override
  String get storePkgNoSums => '缺少 SHA512SUMS';

  @override
  String storePkgSumsMissingFile(String path) {
    return '$path:列在 SHA512SUMS 中但不在包内';
  }

  @override
  String storePkgSumsMismatch(String path) {
    return '$path:与 SHA512SUMS 不符';
  }

  @override
  String storePkgUnlisted(String path) {
    return '$path:存在未列入目录的文件';
  }

  @override
  String get storePkgThemeMissing => '主题的清单中缺少 theme';

  @override
  String storePkgThemeAsset(String where, String id) {
    return 'theme.$where 的图片 $id 不在 assets（use: theme）中';
  }

  @override
  String storePkgThemeSurface(String surface) {
    return 'theme.surfaces 中不能使用 $surface(app / postTile / fow / actionButton)';
  }

  @override
  String storePkgThemeLayer(String surface) {
    return 'theme.surfaces.$surface.layers:请只填写 asset 或 gradient 中的一个';
  }

  @override
  String storePkgThemeColors(String surface) {
    return 'theme.surfaces.$surface.layers:gradient.colors 须为 2~8 种颜色';
  }

  @override
  String storePkgThemeStops(String surface) {
    return 'theme.surfaces.$surface.layers:gradient.stops 的数量须与 colors 相同';
  }

  @override
  String storePkgBadPath(String path) {
    return '不能用作分发包内的路径：$path';
  }

  @override
  String storePkgSigAlg(String alg) {
    return '签名的 alg 不是 ed25519:$alg';
  }

  @override
  String get storePkgSigDigest => 'sig.json 的 digest 与分发包不符（分发包已被替换）';

  @override
  String get storePkgSigRead => '无法读取 sig.json 的 publicKey / signature';

  @override
  String get storePkgSigLength => 'sig.json 中密钥 / 签名的长度不正确';

  @override
  String get storePkgSigInvalid => '开发者密钥的签名不匹配';

  @override
  String storePkgFileMissing(String path) {
    return '$path:列在目录中但不在包内';
  }

  @override
  String storePkgTwice(String path) {
    return 'bundle.json:$path 出现了 2 次';
  }

  @override
  String get storePkgKindTheme => '主题';

  @override
  String get storePkgKindAssets => '素材包';

  @override
  String swingActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get swingReplyHint => '发送回复…';

  @override
  String swingReplyToHint(String handle) {
    return '回复 @$handle…';
  }

  @override
  String swingReplyCount(int count) {
    return '回复 $count';
  }

  @override
  String get swingQueueTooltip => '队列（长按选择图片）';

  @override
  String get swingThreadBackReply => '返回上一条回复';

  @override
  String get swingThreadBackSwing => '返回 Swing 的回复';

  @override
  String swingRepliesTo(String handle, int count) {
    return '对 @$handle 的回复 $count';
  }

  @override
  String get swingThreadClose => '收起回复';

  @override
  String swingLoadFailed(String error) {
    return '无法加载：$error';
  }

  @override
  String get swingNoReplies => '还没有回复。';

  @override
  String swingViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '查看 $_temp0回复';
  }

  @override
  String swingAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个',
    );
    return '附件 $_temp0';
  }

  @override
  String get swingPoll => '投票';

  @override
  String swingReplyOf(String name) {
    return '$name 的回复';
  }

  @override
  String get swingImageSwing => '图片 Swing';

  @override
  String get swingVideoSwing => '视频 Swing';

  @override
  String get swingPluginSwing => '插件 Swing';

  @override
  String swingOf(String name) {
    return '$name 的 Swing';
  }

  @override
  String get swingBarSemantics => 'Swing 的回复和进度条';

  @override
  String swingReportIntro(String name) {
    return '举报 $name 的 Swing。RASQ 将进行审核。';
  }

  @override
  String get swingReported => '已举报。将进行审核';

  @override
  String swingReportFailed(String error) {
    return '无法举报：$error';
  }

  @override
  String get swingDeleteTitle => '删除 Swing';

  @override
  String get swingDeleteMessage => '将删除此 Swing 及其回复。此操作无法撤销。';

  @override
  String get swingDeleteConfirm => '删除';

  @override
  String get swingCancel => '取消';

  @override
  String swingDeleteFailed(String error) {
    return '无法删除：$error';
  }

  @override
  String get swingDeleted => '已删除 Swing';

  @override
  String get swingViewerEmptyMine => '你没有发布中的 Swing';

  @override
  String get swingViewerEmptyMineHint => '将 ＋ 向上滑动即可创建 Swing';

  @override
  String get swingViewerEmpty => '没有 Swing';

  @override
  String get swingViewerEmptyHint => '你关注的人以及将你加入 RASQ 列表的人的 Swing 会显示在这里';

  @override
  String get swingClose => '关闭';

  @override
  String swingRemainingHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小时',
    );
    return '剩余 $_temp0';
  }

  @override
  String swingRemainingMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分钟',
    );
    return '剩余 $_temp0';
  }

  @override
  String get swingRemainingSoon => '即将消失';

  @override
  String swingRemainingAndPosition(String remaining, String position) {
    return '$remaining · $position';
  }

  @override
  String swingViewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0看过';
  }

  @override
  String get swingReport => '举报';

  @override
  String get swingMenu => '菜单';

  @override
  String get swingDelete => '删除';

  @override
  String get swingSensitive => '敏感内容';

  @override
  String get swingReveal => '显示';

  @override
  String swingPluginJoinNote(String name) {
    return '大家一起进入 $name 的页面。无需安装，仅在观看此 Swing 期间运行。';
  }

  @override
  String get swingPluginJoin => '加入';

  @override
  String get swingPluginConsent => '这是未经审核的插件。将在无法联网的状态下，仅在观看此 Swing 期间运行。';

  @override
  String get swingPluginConsentDetail =>
      '受限模式（network / storage.unsafe / interstitial·system 的 FOW / 打开 URL 等均关闭，GPU 可用）。仅限没有子插件的单个插件。';

  @override
  String get swingPluginRun => '运行';

  @override
  String swingPluginNeedsInstall(String name) {
    return '安装 $name 后即可查看';
  }

  @override
  String get swingPluginNeedsInstallHint => '这是插件 Swing。请从商店安装';

  @override
  String get swingViewInStore => '在商店中查看';

  @override
  String get swingPluginOpenFailed => '无法打开';

  @override
  String get swingPluginTapToExpand => '点击返回全屏';

  @override
  String get swingPluginSwipeHint => '左右或上下滑动查看下一个 Swing';

  @override
  String get swingPluginShrink => '退出全屏';

  @override
  String get swingAd => '广告';

  @override
  String get swingAdSwipeHint => '滑动查看下一个 Swing';

  @override
  String get swingKindText => '文本';

  @override
  String get swingKindImage => '图片';

  @override
  String get swingKindVideo => '视频';

  @override
  String get swingKindPlugin => '插件';

  @override
  String swingKindSwing(String kind) {
    return '$kind Swing';
  }

  @override
  String swingBannerNew(int count) {
    return '新 $count';
  }

  @override
  String swingBannerTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String get swingComposerPluginShared => '大家一起用：观看者会进入你创建的同一个页面';

  @override
  String get swingComposerPluginFullscreen => '在观看者的设备上全屏运行';

  @override
  String get swingComposerPluginPage => '在观看者的设备上作为页面运行';

  @override
  String swingTtlLabel(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小时后消失',
    );
    return '$_temp0';
  }

  @override
  String get swingTtl => '消失时间';

  @override
  String swingTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小时',
    );
    return '$_temp0';
  }

  @override
  String get swingBackgroundImage => '以图片作为背景';

  @override
  String get swingBackgroundVideo => '以视频作为背景';

  @override
  String get swingPickVideoFile => '请选择视频文件';

  @override
  String get swingPickImageFile => '请选择图片文件';

  @override
  String get swingChangeBackground => '更换背景';

  @override
  String get swingAudience => '发送对象';

  @override
  String get swingLoadFailedShort => '无法加载';

  @override
  String swingSent(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小时后消失',
    );
    return '已发布 Swing（$_temp0）';
  }

  @override
  String get swingErrorLimit => '同时最多只能发出 20 个 Swing';

  @override
  String swingSendFailed(String error) {
    return '无法发布：$error';
  }

  @override
  String get swingComposerTitle => '创建 Swing';

  @override
  String get swingNext => '下一步';

  @override
  String get swingSend => '发布';

  @override
  String get swingNeedsAccount => '需要 RASQ 账号';

  @override
  String get swingNeedsAccountHint => 'Swing 通过 RASQ 账号发布。请从侧边栏登录';

  @override
  String swingUnreviewed(String name) {
    return '$name（未审核）';
  }

  @override
  String swingTtlRemaining(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小时后消失',
    );
    return '$_temp0';
  }

  @override
  String get swingRepick => '重新选择';

  @override
  String get swingReedit => '重新编辑';

  @override
  String swingCwTooLong(int max) {
    return 'CW 最多 $max 个字';
  }

  @override
  String get swingCwHint => 'CW 文本';

  @override
  String get swingCwOff => '移除 CW';

  @override
  String get swingCwOn => '添加 CW（敏感内容）';

  @override
  String get swingPluginSection => '要分发的插件';

  @override
  String get swingPluginNone =>
      '未安装可通过 Swing 分发的自定义插件。可从商店安装，或通过下方的“从文件”分发你自己的插件。';

  @override
  String get swingPluginNoneDetail =>
      '页面型（自定义插件）中，与其他插件没有父子关系的插件（solo / shared 均可）。';

  @override
  String get swingFromFile => '从文件（未审核）';

  @override
  String get swingFromFileSubtitle => '分发你自己制作的 .rspkg / .rasqpkg / .wasm';

  @override
  String get swingFromFileDetail =>
      '未经审核的插件会在观看者的设备上以无法联网的状态运行（可使用 GPU）。基于其他插件的子插件无法分发。';

  @override
  String get swingAudienceEmpty => '请至少选择一个发送对象';

  @override
  String get swingAudienceFollowers => '关注者';

  @override
  String get swingAudienceFollowersSubtitle => '关注你 RASQ 账号的人';

  @override
  String get swingAudienceList => 'RASQ 列表';

  @override
  String get swingAudienceNoLists => '创建 RASQ 列表后，也可以发送给列表中的人';

  @override
  String swingPackageFetchFailed(int status) {
    return '无法获取插件（HTTP $status）';
  }

  @override
  String get swingNotLoggedIn => '未登录 RASQ 账号';

  @override
  String get swingUnreadable => '无法读取 Swing';

  @override
  String themeNotAThemePack(String id) {
    return '不是主题包：$id';
  }

  @override
  String get themePickerLabel => '主题（.rspkg / .rasqpkg）';

  @override
  String themeNotATheme(String id, String kind) {
    return '不是主题（kind: theme）：$id（$kind）';
  }

  @override
  String themeLoadFailed(String error) {
    return '无法加载：$error';
  }

  @override
  String get themeTitle => '字体与配色方案';

  @override
  String get themeCaption => '可更改颜色、图标和背景。同时只能使用一个';

  @override
  String get themeCaptionDetail =>
      '主题是更改颜色、图标以及屏幕 / 帖子卡片 / FOW / 按钮背景的包。不会运行代码。同时只能使用一个。';

  @override
  String get themeColorScheme => '配色方案';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get themePacks => '主题';

  @override
  String get themeNone => '不使用主题（默认）';

  @override
  String get themeDarkOnly => '在深色模式下生效';

  @override
  String get themeLightOnly => '在浅色模式下生效';

  @override
  String get themeSideloaded => '从文件加载（未审核）';

  @override
  String get themeSeparator => ' · ';

  @override
  String get themeRemove => '删除';

  @override
  String themeDarkOnlyNotice(String name) {
    return '“$name”在深色模式下生效。当前为浅色模式。';
  }

  @override
  String themeLightOnlyNotice(String name) {
    return '“$name”在浅色模式下生效。当前为深色模式。';
  }

  @override
  String get themeSwitchToDark => '切换到深色模式';

  @override
  String get themeSwitchToLight => '切换到浅色模式';

  @override
  String get themeEmpty => '尚未安装主题。';

  @override
  String get themeFindInStore => '在商店中查找主题';

  @override
  String get themeImport => '从文件加载（.rspkg / .rasqpkg）';

  @override
  String get themeImportSubtitle => '加载自己制作的主题';

  @override
  String get themeImportDetail => '用 rasq build 制作的主题包。不含代码，因此即使未经审核也可直接使用';

  @override
  String get trendTitle => '趋势';

  @override
  String get trendTabNotes => '帖子';

  @override
  String get trendTabFollowing => '关注中';

  @override
  String get trendTabUsers => '用户';

  @override
  String get trendBackToHome => '返回趋势首页';

  @override
  String get trendSourceAccountMark => '提供此趋势的账号';

  @override
  String get trendSettingsTooltip => '趋势设置';

  @override
  String get trendCustomizeTooltip => '自定义趋势时间线';

  @override
  String get trendReload => '重新加载';

  @override
  String get trendEmptyTitle => '这里什么都没有';

  @override
  String get trendEmptyHint => '更改关键词或筛选条件也许能找到';

  @override
  String get trendFollowingEmptyTitle => '没有关注对象的帖子';

  @override
  String get trendFollowingEmptyHint => '你关注的人还没有发布有关此关键词的帖子';

  @override
  String get trendUsersBlocked => '监护人已停用用户搜索';

  @override
  String get trendUsersEmpty => '没有用户';

  @override
  String trendUserReactions(int count) {
    return '回应 $count';
  }

  @override
  String get trendMenuOpenAs => '用其他账号打开';

  @override
  String get trendMenuReport => '举报';

  @override
  String trendMenuAccountSourced(String account) {
    return '$account（提供此趋势的账号）';
  }

  @override
  String get trendReportTitle => '举报';

  @override
  String trendReportMessage(String tag) {
    return '举报趋势“$tag”。RASQ 将进行审核。已举报的趋势将不再显示在趋势列表中。';
  }

  @override
  String trendReportMessageWithServer(String tag, String server) {
    return '举报趋势“$tag”($server)。RASQ 将进行审核。已举报的趋势将不再显示在趋势列表中。';
  }

  @override
  String get trendReportNoteHint => '补充说明（可选）';

  @override
  String get trendReportSend => '举报';

  @override
  String get trendReportSent => '已举报。RASQ 将进行审核';

  @override
  String get trendReportStored => '已保存在此设备上。连接到 RASQ 账号后将发送';

  @override
  String get trendReportFailed => '发送失败，已保存在此设备上（稍后将重新发送）';

  @override
  String get trendReportUnhide => '恢复显示';

  @override
  String get trendPluginFallbackName => '趋势插件';

  @override
  String get trendPluginLoadFailed => '无法加载';

  @override
  String get trendPluginNoWords => '还没有候选关键词';

  @override
  String trendPluginWordQuoted(String word) {
    return '“$word”';
  }

  @override
  String trendPluginTodayEmpty(String words) {
    return '还没有关于$words的帖子';
  }

  @override
  String trendPluginTodayHeading(String words) {
    return '关于$words的帖子';
  }

  @override
  String get trendEmotionJoy => '喜悦';

  @override
  String get trendEmotionTrust => '信任';

  @override
  String get trendEmotionFear => '恐惧';

  @override
  String get trendEmotionSurprise => '惊讶';

  @override
  String get trendEmotionSadness => '悲伤';

  @override
  String get trendEmotionDisgust => '厌恶';

  @override
  String get trendEmotionAnger => '愤怒';

  @override
  String get trendEmotionAnticipation => '期待';

  @override
  String get trendExamplesNoCandidates => '没有候选';

  @override
  String get trendExamplesAllow => '喜欢';

  @override
  String get trendExamplesDeny => '不喜欢';

  @override
  String get trendExamplesDecide => '确定';

  @override
  String trendExamplesLoadFailed(String source, String error) {
    return '无法加载$source：$error';
  }

  @override
  String get trendExamplesAllSeen => '已全部看完';

  @override
  String trendExamplesAllSeenHint(
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
  ) {
    return '$allowLabel $allow / $denyLabel $deny。点击确定即可保存';
  }

  @override
  String trendExamplesIntro(String allowLabel, String denyLabel) {
    return '查看内容后，用下方的“$allowLabel”/“$denyLabel”（也可右滑 / 左滑）将其设为示例。新内容会根据与示例的接近程度进行分类。';
  }

  @override
  String trendExamplesSummary(
    String intro,
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
    int remaining,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining 项',
    );
    return '$intro（$allowLabel $allow / $denyLabel $deny · 剩余 $_temp0）';
  }

  @override
  String get trendExamplesSearch => '搜索';

  @override
  String get trendExamplesSkip => '跳过';

  @override
  String trendExamplesMorePosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '+$_temp0';
  }

  @override
  String get trendExamplesPostsUnreadable => '无法读取帖子（将按名称和说明进行比较）';

  @override
  String trendExamplesOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项',
    );
    return '另外 $_temp0';
  }

  @override
  String get trendExamplesSourceActions => '最近的操作';

  @override
  String get trendExamplesSourceActionsEmpty => '没有最近的操作';

  @override
  String get trendExamplesSourceActionsEmptyHint => '回应或收藏书签后，即可在这里选择';

  @override
  String get trendExamplesSourcePlugins => '插件';

  @override
  String get trendExamplesSourcePluginsEmpty => '未安装插件';

  @override
  String get trendExamplesSourceClips => '便签';

  @override
  String get trendExamplesSourceClipsEmpty => '没有便签';

  @override
  String get trendExamplesSourceLists => '列表';

  @override
  String get trendExamplesSourceListsEmpty => '没有列表';

  @override
  String get trendExamplesSourceStore => '商店';

  @override
  String get trendExamplesSourceStoreHint => '搜索商店（留空 = 全部）';

  @override
  String get trendExamplesSourceStoreEmpty => '未找到结果';

  @override
  String get trendExamplesKindPlugin => '插件';

  @override
  String get trendExamplesKindClip => '便签';

  @override
  String get trendExamplesKindList => '列表';

  @override
  String get trendExamplesKindPost => '帖子';

  @override
  String get trendExamplesKindText => '文字';

  @override
  String get trendProfileSheetTitle => '趋势画像设置';

  @override
  String get trendProfileClose => '关闭';

  @override
  String get trendProfileDecide => '确定';

  @override
  String get trendProfileGenres => '喜欢的类型/方向';

  @override
  String get trendProfileGenresSnsDefault => '喜欢的类型/方向（交给 SNS 的设置）';

  @override
  String get trendProfileGenresAuto => '喜欢的类型/方向（从操作中自动提取）';

  @override
  String get trendProfileAddGenrePill => '+ 添加类型';

  @override
  String get trendProfileEdit => '编辑';

  @override
  String get trendProfileTendencyTitle => '趋势的倾向/刺激程度';

  @override
  String trendProfileTendencySummary(String directivity, String stimulus) {
    return '倾向 $directivity · 刺激程度 $stimulus';
  }

  @override
  String get trendProfilePluginsTitle => '趋势插件设置';

  @override
  String get trendProfilePluginsSubtitle => '时间线节点 / 搜索建议';

  @override
  String get trendProfilePluginsDetail =>
      'trend.suggest 插件。用于时间线自定义的节点（获取趋势 / Today / 自定义）和搜索建议';

  @override
  String get trendProfileCacheNetworkTitle => '缓存网络设置';

  @override
  String get trendProfileComingSoon => '即将推出';

  @override
  String get trendProfileAlgorithmTitle => '编辑算法（节点）';

  @override
  String get trendProfileAlgorithmSubtitle => '编辑趋势的收集与排序方式';

  @override
  String get trendProfileAlgorithmDetail => '趋势获取与排序的链（ml.tendency 节点可使用此画像）';

  @override
  String get trendProfileSharedCaption => '此设置由推荐 / 趋势 / 关联时间线共用。';

  @override
  String get trendProfileSharedCaptionDetail =>
      '此画像保存在 storage.safe（trend.profile）中，推荐 / 趋势 / 关联时间线的默认设置以及节点编辑器的“倾向/刺激程度”节点都会读取它。';

  @override
  String get trendProfileDirNarrow => '窄';

  @override
  String get trendProfileDirWide => '宽';

  @override
  String get trendProfileDirNormal => '普通';

  @override
  String get trendProfileStimNone => '无限制';

  @override
  String trendProfileStimCapped(String emotions) {
    return '抑制$emotions';
  }

  @override
  String get trendProfileListSeparator => '、';

  @override
  String get trendProfileDirectivityTitle => '趋势的倾向';

  @override
  String get trendProfileDirectivitySubtitle => '越窄，越不会显示偏离喜欢类型的帖子。';

  @override
  String get trendProfileDirectivityDetail =>
      '与喜欢的类型/方向接近程度的阈值（窄 ⇄ 宽）。越窄，越会剔除偏离的帖子。';

  @override
  String get trendProfileShareTitle => '共用设置';

  @override
  String get trendProfileShareSubtitle => '将此设置用于推荐 / 趋势 / 关联时间线';

  @override
  String get trendProfileShareDetail => '关闭后将停止作为时间线默认设置应用（在节点中明确指定的部分仍然有效）';

  @override
  String get trendProfileStimulusTitle => '趋势的刺激程度';

  @override
  String get trendProfileStimulusCaption => '各种情绪的上限。越靠近中心，抑制越强';

  @override
  String get trendProfileStimulusReset => '重置刺激程度';

  @override
  String get trendProfileEchoChamberWarning => '加强趋势的倾向/刺激程度，可能更容易受到回音室效应的影响。';

  @override
  String get trendProfileStimulusEstimate => '刺激程度目前是根据用词倾向推测的。';

  @override
  String get trendProfileStimulusEstimateDetail => '刺激程度通过词汇规则推测。';

  @override
  String get trendProfileTendencySaved => '已保存趋势的倾向/刺激程度';

  @override
  String get trendProfileSnsDefaultTitle => '交给 SNS 的设置';

  @override
  String get trendProfileSnsDefaultSubtitle => '开启期间，设备端不进行筛选';

  @override
  String get trendProfileAutoGenreTitle => '从你的操作中自动提取';

  @override
  String get trendProfileAutoGenreSubtitle => '将你回应过的帖子中的特征词添加到喜欢的类型';

  @override
  String get trendProfilePickFromActions => '从最近的操作中选择喜欢的内容';

  @override
  String get trendProfileGenresTapToRemove => '喜欢的类型/方向（点按移除）';

  @override
  String get trendProfileNoneYet => '暂无';

  @override
  String get trendProfileAddGenreHint => '添加类型/关键词';

  @override
  String get trendProfileAddGenre => '添加类型';

  @override
  String trendProfileExamplesLabel(int allow, int deny) {
    return '示例（喜欢 $allow / 不喜欢 $deny，点按移除）';
  }

  @override
  String trendProfileExampleAllow(String label) {
    return '喜欢：$label';
  }

  @override
  String trendProfileExampleDeny(String label) {
    return '不喜欢：$label';
  }

  @override
  String get trendProfileDislikedTapToRemove => '不喜欢（点按移除）';

  @override
  String get trendProfileGenresSaved => '已保存喜欢的类型/方向';

  @override
  String get trendProfilePickTitle => '从操作中选择类型';

  @override
  String get trendProfilePickIntro =>
      '最近的操作按话题分组显示。选择卡片并归入“喜欢”/“不喜欢”（也可向右/向左滑动）。';

  @override
  String trendProfilePickIntroDetail(int perPage) {
    String _temp0 = intl.Intl.pluralLogic(
      perPage,
      locale: localeName,
      other: '$perPage 条',
    );
    return '将最近的操作按相似话题归类，从话题性最强的开始每次显示 $_temp0（也可通过上方的标签从插件 / 便签 / 列表选取）。点按卡片进行选择，选好候选类型后点下方的“喜欢”/“不喜欢”（也可向右/向左滑动）。';
  }

  @override
  String userPageViewTitle(String tab) {
    return '$tab的显示';
  }

  @override
  String get userPageViewClose => '关闭';

  @override
  String userPageViewSearchHint(String tab) {
    return '在此用户的$tab中搜索';
  }

  @override
  String get userPageViewSortLabel => '排序';

  @override
  String get userPageViewSortNewest => '最新优先';

  @override
  String get userPageViewSortOldest => '最早优先';

  @override
  String get userPageViewSortReactions => '回应数';

  @override
  String get userPageViewSortTendency => '最符合倾向';

  @override
  String get userPageViewShowLabel => '显示';

  @override
  String get userPageViewShowPinned => '置顶';

  @override
  String get userPageViewShowRenotes => '转帖';

  @override
  String get userPageViewShowQuotes => '引用帖子';

  @override
  String get userPageViewShowDigest => '摘要';

  @override
  String get userPageViewTendencyLabel => '倾向 / 刺激程度';

  @override
  String get userPageViewDirectivityTitle => '倾向';

  @override
  String get userPageViewDirectivityNoGenres => '设置喜欢的类型后生效';

  @override
  String get userPageViewStimulusTitle => '刺激程度';

  @override
  String get userPageViewReset => '重置';

  @override
  String userPageViewCount(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total 条中显示 $shown 条',
    );
    return '$_temp0';
  }

  @override
  String get userPageViewEmptyTitle => '没有符合条件的帖子';

  @override
  String get userPageViewEmptyHint => '再次点击标签页，更改或重置显示设置';

  @override
  String get usersImageViewerBack => '返回';

  @override
  String get usersFollowRequestsTabRelevance => '相关性';

  @override
  String get usersFollowRequestsTabFollowing => '关注中';

  @override
  String get usersFollowRequestsTabOther => '其他';

  @override
  String get usersFollowRequestsTitle => '关注请求';

  @override
  String get usersReload => '重新加载';

  @override
  String get usersFollowRequestsEmpty => '没有关注请求';

  @override
  String get usersFollowRequestsEmptyOther => '无';

  @override
  String get usersFollowRequestAccept => '允许';

  @override
  String get usersFollowRequestReject => '拒绝';

  @override
  String get usersFollowsTabFollowing => '关注中';

  @override
  String get usersFollowsTabFollowers => '关注者';

  @override
  String get usersFollowsTitle => '关注/关注者';

  @override
  String get usersFollowersEmpty => '没有关注者';

  @override
  String get usersFollowingEmpty => '没有关注的用户';

  @override
  String get usersPageTabNotes => '帖子';

  @override
  String get usersPageTabReplies => '回复';

  @override
  String get usersPageTabQuotes => '引用';

  @override
  String get usersPageTabMedia => '媒体';

  @override
  String get usersPageTabClips => '便签/Play';

  @override
  String get usersRestrictedTitle => '这是受限制的用户';

  @override
  String get usersRestrictedHint => '点按“显示”以显示内容';

  @override
  String get usersMenuCopyLink => '复制链接';

  @override
  String get usersMenuAddToRasqList => '添加到 RASQ 列表';

  @override
  String get usersMenuServerInfo => '服务器信息';

  @override
  String get usersMenuUnmute => '取消静音';

  @override
  String get usersMenuMute => '静音';

  @override
  String get usersMenuUnblock => '取消屏蔽';

  @override
  String get usersMenuBlock => '屏蔽';

  @override
  String get usersMenuReport => '举报';

  @override
  String usersBlockConfirmTitle(String name) {
    return '要屏蔽 $name 吗？';
  }

  @override
  String get usersBlockConfirmMessage => '将不再收到对方的关注、回应和回复。';

  @override
  String get usersCancel => '取消';

  @override
  String usersReportConfirmTitle(String name) {
    return '要举报 $name 吗？';
  }

  @override
  String get usersReportConfirmMessage => '将向服务器管理员举报。';

  @override
  String get usersPostsEmpty => '没有帖子';

  @override
  String get usersPinnedBadge => '置顶';

  @override
  String get usersClipsUnsupportedTitle => '便签 / Play';

  @override
  String get usersClipsUnsupportedHint => '此 SNS 不支持便签和 Play';

  @override
  String get usersClipsEmpty => '没有公开的便签或 Play';

  @override
  String get usersClipsHeader => '便签';

  @override
  String usersClipNoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条',
    );
    return '$_temp0';
  }

  @override
  String get usersClipSubtitleSeparator => ' · ';

  @override
  String get usersNotFound => '该用户似乎不存在。';

  @override
  String get vcSectionInvited => '邀请';

  @override
  String get vcSectionRecommended => '推荐';

  @override
  String get vcSectionUpcoming => '即将举行';

  @override
  String get vcSectionTrending => '趋势';

  @override
  String get vcSectionFollowing => '关注中';

  @override
  String vcSectionSettingsTooltip(String title) {
    return '$title设置';
  }

  @override
  String get vcSearchHint => '搜索 ASTell / Swing';

  @override
  String get vcSearchRefineHint => '进一步筛选';

  @override
  String vcSearchTermChip(String term) {
    return '“$term” ×';
  }

  @override
  String get vcSearchClear => '清除';

  @override
  String get vcCreateTooltip => '创建 ASTell';

  @override
  String get vcHomeLoadError => '无法获取 ASTell';

  @override
  String vcJoinedRoom(String title) {
    return '参与中：$title';
  }

  @override
  String vcJoinedPeers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人 · 点按打开',
    );
    return '$_temp0';
  }

  @override
  String get vcConnecting => '正在连接…';

  @override
  String vcInvitedBy(String name) {
    return '$name 邀请了你 · 点按查看';
  }

  @override
  String get vcInviteDecline => '拒绝';

  @override
  String get vcRecommendedEmpty => '还没有推荐的 ASTell';

  @override
  String get vcTrendingEmpty => '还没有趋势中的 ASTell';

  @override
  String get vcFollowingEmpty => '没有关注用户的 ASTell';

  @override
  String get vcSearchNoResults => '未找到';

  @override
  String get vcSearchNoResultsInSection => '此栏目中没有';

  @override
  String vcSearchNoResultsFor(String query) {
    return '没有与“$query”匹配的 ASTell / Swing';
  }

  @override
  String get vcTileOpen => '查看';

  @override
  String get vcBookmarkRemove => '从书签中删除';

  @override
  String get vcBookmarkSave => '保存到书签';

  @override
  String get vcRemindCancel => '取消开始通知';

  @override
  String get vcRemindSet => '开始时通知';

  @override
  String get vcMenuTooltip => '菜单';

  @override
  String vcScheduledAt(String when) {
    return '预定于 $when';
  }

  @override
  String get vcSummaryPrivate => '概要不公开。';

  @override
  String get vcTileStripEmpty => '还没有 ASTell';

  @override
  String get vcLinkCopied => '已复制链接';

  @override
  String get vcBookmarkSaved => '已保存到书签';

  @override
  String get vcBookmarkRemoved => '已从书签中删除';

  @override
  String vcRemindRegistered(String when) {
    return '将在 $when 通知你';
  }

  @override
  String get vcRemindRemoved => '已取消通知';

  @override
  String get vcRemindUnavailable => '无法在此设备上设置通知';

  @override
  String get vcRemindNotScheduled => '此房间没有预定时间';

  @override
  String get vcMenuShareAsPost => '以帖子分享';

  @override
  String get vcMenuCopyLink => '复制链接';

  @override
  String get vcMenuStartNow => '立即开始';

  @override
  String get vcMenuBackToRoom => '返回房间';

  @override
  String get vcMenuJoin => '加入';

  @override
  String get vcMenuClose => '结束';

  @override
  String get vcMenuUnfollowHost => '取消关注主持人';

  @override
  String get vcMenuFollowHost => '关注主持人';

  @override
  String get vcMenuMute => '静音';

  @override
  String get vcMenuReport => '举报';

  @override
  String vcUnfollowed(String name) {
    return '已取消关注 $name';
  }

  @override
  String vcFollowed(String name) {
    return '已关注 $name';
  }

  @override
  String vcReportWhatRoom(String title) {
    return '房间“$title”';
  }

  @override
  String vcMenuNotYet(String title, String action) {
    return '“$title”的操作（$action）将在 M5 后期推出';
  }

  @override
  String get vcCloseRoomTitle => '结束房间';

  @override
  String vcCloseScheduledBody(String title) {
    return '将取消“$title”的预定。已添加书签或设置开始通知的人不会收到通知。';
  }

  @override
  String vcCloseRoomBody(String title) {
    return '将结束“$title”。参与中的成员将退出。';
  }

  @override
  String vcClosedScheduled(String title) {
    return '已取消“$title”的预定';
  }

  @override
  String vcClosedRoom(String title) {
    return '已结束“$title”';
  }

  @override
  String vcCloseFailed(String error) {
    return '无法结束：$error';
  }

  @override
  String get vcTileBack => '返回';

  @override
  String get vcReminderNotificationTitle => '已加入书签的 ASTell 即将开始！';

  @override
  String vcReminderNotificationBody(String host, String title) {
    return '$host 的“$title”';
  }

  @override
  String vcShareTextScheduled(String title, String when) {
    return '“$title”将于 $when 举行';
  }

  @override
  String vcShareTextOpen(String title) {
    return '“$title”正在进行中';
  }

  @override
  String get vcViewerPluginsTooltip => '全屏显示插件（准备中）';

  @override
  String vcViewerSharedBy(String name) {
    return '$name 分享';
  }

  @override
  String get vcViewerSave => '保存';

  @override
  String get vcViewerSaveNotYet => '保存功能准备中';

  @override
  String get vcViewerShare => '分享';

  @override
  String get vcViewerShareNotYet => '分享功能准备中';

  @override
  String get vcBarSpeaker => '扬声器';

  @override
  String get vcBarMic => '麦克风';

  @override
  String get vcBarScreen => '屏幕共享';

  @override
  String get vcBarFullscreen => '全屏（共享框中有画面时）';

  @override
  String get vcBarCaptions => '字幕（语音转文字）';

  @override
  String vcCallConnectFailed(String error) {
    return '通话连接失败：$error';
  }

  @override
  String get vcOpenNotFound => '找不到此房间（可能已结束，或链接有误）';

  @override
  String get vcOpenFailed => '无法打开房间';

  @override
  String get vcOpenGoHome => '前往 ASTell 首页';

  @override
  String vcOpenHost(String name, String handle) {
    return '主持人：$name(@$handle)';
  }

  @override
  String get vcOpenRoom => '打开房间';

  @override
  String get vcShareBlockDirect => '私信帖子无法分享到 ASTell';

  @override
  String get vcShareBlockLocalOnly => '仅限本地的帖子无法分享到 ASTell';

  @override
  String get vcShareBlockUnknownVisibility => '无法确定公开范围的帖子无法分享到 ASTell';

  @override
  String get vcShareBlockLimited => '限制了公开范围的帖子无法分享到 ASTell';

  @override
  String get vcShares => '共享';

  @override
  String vcSharesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '共享 ($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcSharesShowAll => '查看全部共享';

  @override
  String get vcSharesEmpty => '在聊天中 📌 的内容会显示在这里。';

  @override
  String get vcShareActions => '共享操作';

  @override
  String get vcShareTranscriptSource => 'RASQ · 文字记录';

  @override
  String get vcUnpin => '取消置顶';

  @override
  String get vcYou => '你';

  @override
  String get vcNoDescription => '没有说明。';

  @override
  String get vcReportReasonSpam => '垃圾信息';

  @override
  String get vcReportReasonHarassment => '骚扰 / 辱骂';

  @override
  String get vcReportReasonIllegal => '违法 / 危险内容';

  @override
  String get vcReportReasonOther => '其他';

  @override
  String get vcJoinPolicyAnyone => '任何人';

  @override
  String get vcJoinPolicyAnyoneHint => '公开房间任何人都可以加入';

  @override
  String get vcJoinPolicyFollowers => '仅关注者';

  @override
  String get vcJoinPolicyFollowersHint => '用 RASQ 账号关注你（主持人）的人';

  @override
  String get vcJoinPolicyFollowing => '仅你关注的人';

  @override
  String get vcJoinPolicyFollowingHint => '你关注的人';

  @override
  String get vcJoinPolicyMutual => '仅互相关注';

  @override
  String get vcJoinPolicyMutualHint => '与你互相关注的人';

  @override
  String get vcSharePolicyEveryone => '所有人';

  @override
  String get vcSharePolicyModerators => '仅版主';

  @override
  String vcShareContentWarning(String warning) {
    return '⚠ $warning（敏感内容）';
  }

  @override
  String vcSharePluginWant(String name) {
    return '想使用“$name”';
  }

  @override
  String get vcKindPost => '帖子';

  @override
  String get vcKindMedia => '媒体';

  @override
  String get vcKindVideo => '视频';

  @override
  String get vcKindLink => '链接';

  @override
  String get vcKindText => '文本';

  @override
  String get vcKindPlugin => '插件';

  @override
  String get vcMediaInsecureContext => '网页版通话仅在通过 https 打开时可用';

  @override
  String get vcMediaPermissionDenied => '没有麦克风（摄像头）权限。请在设备设置中允许';

  @override
  String get vcMediaNoDevice => '找不到麦克风（摄像头）';

  @override
  String get vcMediaUnsupported => '此设备无法使用';

  @override
  String vcMediaUnsupportedDetail(String detail) {
    return '此设备无法使用（$detail）';
  }

  @override
  String get vcMediaMicClosed => '无法打开已结束通话的麦克风';

  @override
  String get vcStreamNotConnected => '未连接到直播服务器';

  @override
  String get vcStreamPublishFailed => '无法将视频上传到直播服务器';

  @override
  String get vcScreenSharingNotification => '正在共享屏幕';

  @override
  String get vcScreenPickTitle => '选择要共享的画面';

  @override
  String get vcScreenPickScreen => '整个屏幕';

  @override
  String get vcScreenPickWindow => '窗口';

  @override
  String get vcScreenPickCancel => '取消';

  @override
  String get vcScreenPickShare => '共享';

  @override
  String get vcNoticeAudioBlocked => '声音已停止。点按屏幕即可播放';

  @override
  String vcNoticeCallFull(int cap) {
    return '通话已满（最多 $cap 人）。如有直播，可通过直播收听';
  }

  @override
  String get vcNoticeHoldWaiting => '请等待开始。正在播放等待音乐';

  @override
  String get vcNoticeStarted => '已开始';

  @override
  String get vcNoticeHoldIdle => '因为很安静，正在播放等待音乐';

  @override
  String get vcShareClassImage => '图片';

  @override
  String get vcShareClassFile => '文件';

  @override
  String get vcShareClassTranscript => '文字记录';

  @override
  String get vcShareStyleCards => '卡片（横向滑动）';

  @override
  String get vcShareStyleList => '列表（旧版）';

  @override
  String get vcTermsRequired => '需要同意使用条款（可在 ASTell 顶部的提示中同意）';

  @override
  String get vcClosedByModeration => '房间已被运营方关闭';

  @override
  String get vcClosedByHost => '主持人已结束房间';

  @override
  String get vcKickedBanned => '你已被此房间封禁';

  @override
  String get vcKickedSanctioned => '由于账号处置，你已被移出';

  @override
  String get vcKickedByModerator => '版主已将你移出房间';

  @override
  String vcShareHeld(String seconds) {
    return '审查中：将在 $seconds 秒后判定并发送（账号处置）';
  }

  @override
  String vcShareRejected(String source) {
    return '审查未通过（$source）。此发言未被发送';
  }

  @override
  String get vcNotInRoom => '你不在房间中';

  @override
  String vcStreamReceiveFailed(String error) {
    return '无法接收视频：$error';
  }

  @override
  String get vcStreamBlockedByScreenShare => '屏幕共享期间无法开始直播（请先停止共享）';

  @override
  String vcStreamStartFailed(String error) {
    return '无法开始直播：$error';
  }

  @override
  String vcStreamClearFailed(String error) {
    return '无法清除直播标记：$error';
  }

  @override
  String get vcScreenShareBlockedByStream => '直播期间无法开始屏幕共享（请先停止直播）';

  @override
  String vcScreenShareStartFailed(String error) {
    return '无法开始屏幕共享：$error';
  }

  @override
  String get vcStreamUnavailable => '直播尚不可用（未设置直播服务器）';

  @override
  String vcStreamForbidden(String message) {
    return '不允许（$message）';
  }

  @override
  String get vcTtsNotConfigured => '未设置朗读后端（CENTRAL_TTS_URL）';

  @override
  String get vcLoginRequired => '请登录 RASQ 账号';

  @override
  String vcCreateUninvite(String name) {
    return '取消邀请 $name';
  }

  @override
  String vcCreateInvite(String name) {
    return '邀请 $name';
  }

  @override
  String get vcCreateCancel => '取消';

  @override
  String get vcCreateShareAfterOn => '创建后发帖分享（开）';

  @override
  String get vcCreateShareAfter => '创建后发帖分享';

  @override
  String vcCreateScheduled(String title, String when) {
    return '已将“$title”预约在 $when';
  }

  @override
  String get vcCreateScheduleInPast => '预定时间必须晚于当前时间';

  @override
  String vcCreateGenresMax(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '最多可添加 $max 个类型',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateTitleRequired => '请输入标题';

  @override
  String vcCreateInviteFailed(String error) {
    return '无法发送邀请：$error';
  }

  @override
  String vcCreateFailed(String error) {
    return '无法创建：$error';
  }

  @override
  String get vcCreateSearchAdd => '搜索并添加';

  @override
  String get vcCreateHandleHint => '@handle（RASQ 账号）';

  @override
  String vcCreateHandleNotFound(String handle) {
    return '未找到：$handle';
  }

  @override
  String get vcCreateAddInvitee => '添加到邀请';

  @override
  String get vcCreateTitleHint => '标题';

  @override
  String get vcCreateInviteFollowers => '邀请关注者';

  @override
  String vcCreateInviteFollowersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '邀请关注者（$count）',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateWelcomeToggle => '加入时显示欢迎消息';

  @override
  String get vcCreateWelcomeHint => '设置欢迎消息..';

  @override
  String vcCreateGenresLabel(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '选择类型（最多 $max 个）',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateGenreHint => '输入类型';

  @override
  String get vcCreateGenreAdd => '添加类型';

  @override
  String get vcCreateSchedule => '预约开始时间';

  @override
  String get vcCreateScheduleCaption => '预约期间，在你进入之前其他人无法进入。';

  @override
  String get vcCreateScheduleCaptionDetail =>
      '预约期间，在你（或管理员）进入之前其他人无法参加。可从“即将开始”栏目和分享链接订阅开始通知。';

  @override
  String get vcCreateSummaryHint => '简要概述（可选；留空则自动生成）';

  @override
  String get vcCreateMicAfterCreate => '麦克风（创建后切换）';

  @override
  String get vcCreateScheduleButton => '预约';

  @override
  String get vcCreateButton => '创建';

  @override
  String get vcRoomHostPresent => '在场';

  @override
  String get vcRoomHostBeforeStart => '未开始';

  @override
  String get vcRoomHostAbsent => '不在';

  @override
  String vcRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 人参与',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomMembersHostOnly => '除了主持人以外还没有其他人';

  @override
  String get vcRoomMembersNone => '还没有人';

  @override
  String vcRoomMembersRest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '等 $count 人',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomScreenShown => '正在共享框中显示';

  @override
  String get vcRoomScreenShow => '显示屏幕共享';

  @override
  String vcRoomNotYet(String what) {
    return '$what正在准备中';
  }

  @override
  String get vcRoomDeviceSettingsTitle => 'ASTell 设置（此设备）';

  @override
  String get vcRoomEditBar => '编辑底部按钮排列';

  @override
  String get vcRoomEditBarSubtitle => '排序 / 显示 / 隐藏 / 添加插件按钮';

  @override
  String get vcRoomAutoShareLabel => '自动将聊天内容显示在共享栏中（即使未置顶）';

  @override
  String get vcRoomShareStyleLabel => '共享栏显示方式';

  @override
  String get vcRoomAutoPlayLabel => '自动播放';

  @override
  String get vcRoomAutoPlayScreen => '屏幕共享开始时显示在共享框中';

  @override
  String get vcRoomHoldMusicLabel => '等待音乐';

  @override
  String get vcRoomHoldMusicDevice => '播放等待音乐（此设备）';

  @override
  String get vcRoomHoldMusicSourceLabel => '等待音乐的音源';

  @override
  String get vcRoomHoldMusicSourceAstronomies =>
      'We：Astronomies on the Blue Planet';

  @override
  String get vcRoomHoldMusicSourceClassic => '经典等待音乐';

  @override
  String get vcRoomHoldMusicVolume => '等待音乐音量';

  @override
  String vcRoomHoldMusicVolumeValue(int percent) {
    return '$percent%';
  }

  @override
  String get vcRoomDeviceSettingsCaption => '房间设置可在加入后通过房间的齿轮更改（房主）。';

  @override
  String get vcRoomDeviceSettingsCaptionDetail =>
      '每个房间的设置（可加入的人、朗读等）可在加入后通过房间的齿轮更改（房主）。';

  @override
  String get vcRoomClose => '关闭';

  @override
  String get vcRoomShare => '共享';

  @override
  String get vcRoomHost => '主持人';

  @override
  String get vcRoomMembers => '参与成员';

  @override
  String get vcRoomLocked => '运营方已停止新的进入。';

  @override
  String get vcRoomLockedDetail => '运营方已停止新进入（D-151）。';

  @override
  String get vcRoomRemindOn => '将在开始时通知你';

  @override
  String get vcRoomWaitForHost => '主持人开始之前无法加入';

  @override
  String get vcRoomRemindOff => '取消通知';

  @override
  String get vcRoomSummary => '概要';

  @override
  String get vcRoomSummaryPrivate => '此房间未公开概要。';

  @override
  String vcRoomWelcome(String message) {
    return '欢迎：$message';
  }

  @override
  String get vcRoomMicAfterJoin => '麦克风（加入后切换）';

  @override
  String get vcRoomCaptions => '字幕';

  @override
  String get vcRoomJoin => '加入';

  @override
  String get vcRoomSettings => '设置';

  @override
  String get vcRoomTabHome => '首页';

  @override
  String get vcRoomTabChat => '聊天';

  @override
  String get vcRoomTabToc => '目录';

  @override
  String get vcRoomTabRoom => '房间';

  @override
  String get vcRoomLeft => '已退出';

  @override
  String get vcRoomLeave => '退出';

  @override
  String get vcRoomStreamingScreen => '正在直播屏幕';

  @override
  String get vcRoomStreamingCamera => '正在用摄像头直播';

  @override
  String get vcRoomStopSharing => '停止共享';

  @override
  String get vcRoomStopStream => '停止直播';

  @override
  String get vcRoomSpeakerUnmute => '取消扬声器静音';

  @override
  String get vcRoomSpeakerMute => '扬声器静音';

  @override
  String get vcRoomMutedByModerator => '已被版主静音';

  @override
  String get vcRoomMicOpening => '正在准备麦克风（点按取消）';

  @override
  String get vcRoomMicOff => '关闭麦克风';

  @override
  String get vcRoomMicOn => '打开麦克风';

  @override
  String get vcRoomScreenShareOff => '关闭屏幕共享';

  @override
  String get vcRoomFullscreen => '全屏';

  @override
  String get vcRoomCaptionsOff => '关闭字幕';

  @override
  String get vcRoomCaptionsOn => '打开字幕';

  @override
  String get vcRoomShareAsLinkLimited => '此帖子限制了公开范围，将以链接形式分享';

  @override
  String vcRoomShareAsLinkFailed(String error) {
    return '无法获取帖子，将以链接形式分享：$error';
  }

  @override
  String vcRoomPickFileFailed(String error) {
    return '无法选择文件：$error';
  }

  @override
  String get vcRoomStream => '直播';

  @override
  String vcRoomLiveCardTitle(String kind, String title) {
    return '$kind:$title';
  }

  @override
  String vcRoomPeerScreen(String name) {
    return '$name 的屏幕';
  }

  @override
  String vcRoomPeerScreenTitled(String name, String title) {
    return '$name 的屏幕 — $title';
  }

  @override
  String get vcRoomAllShares => '全部共享';

  @override
  String get vcRoomSettingsTitle => 'ASTell 设置';

  @override
  String get vcRoomModerationLabel => '管理（房主）';

  @override
  String get vcRoomJoinPolicyLabel => '可以加入的人';

  @override
  String get vcRoomSharePolicyLabel => '可以共享（在聊天中发布）的人';

  @override
  String vcRoomModeratorsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '版主（$count）— 从成员的“…”中添加',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomRemoveModerator => '移除版主';

  @override
  String get vcRoomTendencyLabel => '发言倾向';

  @override
  String get vcRoomTendencyFilter => '拒绝捣乱者进入（测试中）';

  @override
  String get vcRoomTendencyCaption => '开启后，被判定为有敌意的人将无法进入。判定仍为临时性的。';

  @override
  String get vcRoomTendencyCaptionDetail =>
      '正式版将使用 rasq-judge 的 GoEmotion（发言的情绪倾向），由于需要训练，目前使用服务器的模拟判定（仅显示名称中含有 hostile 或日语中意为“捣乱者”的词的人被视为有敌意）。开启后，被判定为有敌意的人将无法进入。可从成员行的“…”中查看判定结果。';

  @override
  String get vcRoomHostStreamLabel => '直播（主持人）';

  @override
  String get vcRoomStreamCamera => '用摄像头直播';

  @override
  String get vcRoomStreamScreen => '直播屏幕';

  @override
  String get vcRoomStreamScreenIos => 'iPhone / iPad 仅限此应用的画面（不会显示其他应用）';

  @override
  String get vcRoomHostStreamCaption => '直播影像和声音。无法加入通话的人也可以通过直播收听。';

  @override
  String vcRoomHostStreamCaptionDetail(int cap) {
    return '将影像和麦克风上传到直播服务器（LiveKit）。参与者在保持通话声音的同时可观看影像，无法加入通话的人（第 $cap 人之后）通过直播收听你的声音。';
  }

  @override
  String get vcRoomHoldMusicRoom => '允许在此房间播放等待音乐（房主）';

  @override
  String get vcRoomHoldMusicCaption => '在等待开始期间，或一段时间没人说话时播放。';

  @override
  String vcRoomHoldMusicCaptionDetail(int minutes) {
    return '在等待预定开始期间，以及所有人都关闭麦克风（且没有屏幕共享 / 直播）、聊天 $minutes 分钟以上没有动静时播放。有人开始说话或聊天有新消息时停止。';
  }

  @override
  String get vcRoomTts => '朗读';

  @override
  String get vcRoomTtsUnavailable => '朗读（无法使用）';

  @override
  String vcRoomTtsDetail(String model) {
    return '朗读（$model，默认语音）';
  }

  @override
  String vcRoomTtsDetailUnavailable(String model) {
    return '朗读（$model，默认语音）— 服务器未设置';
  }

  @override
  String get vcRoomTtsNone => '不朗读';

  @override
  String get vcRoomTtsCaptionOwner => '朗读语音在服务器上生成（应用内播放准备中）。';

  @override
  String get vcRoomTtsCaptionGuest => '朗读语音由主持人选择。';

  @override
  String get vcRoomTtsCaptionOwnerDetail =>
      '聊天和共享的朗读在 Central 端合成（设备端播放将在今后支持）。';

  @override
  String get vcRoomDiagnosticsLabel => '连接状态（面向开发者）';

  @override
  String get vcRoomDiagnosticsOpen => '查看通话 / 直播连接';

  @override
  String get vcRoomDiagnosticsOpenSubtitle => 'ICE 状态、候选、收发量、接收中的轨道';

  @override
  String get vcRoomDiagnosticsTitle => '连接状态';

  @override
  String vcRoomHostStreamTitle(String name) {
    return '$name 的直播';
  }

  @override
  String get vcRoomPostViewNotYet => '显示此帖子（未安装对应的 SNS 插件）';

  @override
  String get vcRoomOpen => '打开';

  @override
  String get vcRoomDelete => '删除';

  @override
  String get vcRoomCopied => '已复制';

  @override
  String vcRoomReportWhatShare(String headline) {
    return '共享“$headline”';
  }

  @override
  String get vcRoomPinToFrame => '在共享框中显示';

  @override
  String get vcRoomUnfollow => '取消关注';

  @override
  String get vcRoomFollow => '关注';

  @override
  String get vcRoomUnmute => '取消静音';

  @override
  String get vcRoomModUnmute => '取消对所有人的静音';

  @override
  String get vcRoomModMute => '对所有人静音';

  @override
  String get vcRoomKick => '踢出';

  @override
  String get vcRoomMakeModerator => '设为版主';

  @override
  String get vcRoomShowTendency => '查看发言倾向（测试中）';

  @override
  String get vcRoomUnblock => '取消屏蔽';

  @override
  String get vcRoomBlock => '屏蔽';

  @override
  String get vcRoomReport => '举报';

  @override
  String vcRoomTendencyResult(String name, String source, String summary) {
    return '$name 的发言倾向（$source）：$summary';
  }

  @override
  String vcRoomTendencyResultHostile(
    String name,
    String source,
    String summary,
  ) {
    return '$name 的发言倾向（$source）：$summary — 有敌意';
  }

  @override
  String vcRoomUnblocked(String name) {
    return '已取消屏蔽 $name';
  }

  @override
  String vcRoomBlocked(String name) {
    return '已屏蔽 $name（隐藏其发言，且无法进入你的房间）';
  }

  @override
  String vcRoomActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get vcRoomPinToShares => '置顶到共享栏';

  @override
  String vcRoomReportWhatChat(String name) {
    return '$name 的发言';
  }

  @override
  String get vcRoomShowSummary => '在预览中显示概要';

  @override
  String get vcRoomAutoGenre => '自动选择类型';

  @override
  String get vcRoomEditAutoGenres => '编辑自动选择的类型';

  @override
  String get vcRoomGenres => '类型';

  @override
  String get vcRoomChatEmpty => '说话内容的文字记录以及聊天、共享会显示在这里。';

  @override
  String vcRoomChatHiddenBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已隐藏 $count 条来自已屏蔽用户的发言',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomTyping => '正在输入…';

  @override
  String get vcRoomDraft => '草稿';

  @override
  String get vcRoomTypingLabel => '正在输入';

  @override
  String get vcRoomChatActions => '聊天操作';

  @override
  String vcRoomTocStart(String title) {
    return '开始：$title';
  }

  @override
  String vcRoomTocShared(String name, String kind, String headline) {
    return '$name 分享了 $kind:$headline';
  }

  @override
  String get vcRoomTocCaption => '共享和文字记录的分隔。';

  @override
  String vcRoomMembersWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '参与成员（$count）',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomModerator => '版主';

  @override
  String get vcRoomCustomPlugins => '自定义插件';

  @override
  String vcRoomUpdateFailed(String error) {
    return '无法更新设置：$error';
  }

  @override
  String get vcRoomShareAction => '共享';

  @override
  String get vcRoomSendDone => '完成发送';

  @override
  String vcRoomPeerScreenTap(String name) {
    return '$name 的屏幕（点按全屏）';
  }

  @override
  String get vcRoomPinnedSharesEmpty => '置顶的共享会显示在这里';

  @override
  String vcRoomCompactShare(String headline) {
    return '共享：$headline';
  }

  @override
  String get vcRoomNoTranscripts => '还没有文字记录';

  @override
  String get vcRoomTranscriptsDisabled => '文字记录已停用（概要不公开）';

  @override
  String get vcRoomSharesCollapse => '收起共享';

  @override
  String get vcRoomSharesExpand => '显示全部共享';

  @override
  String vcRoomSharedByPinned(String name) {
    return '$name 分享 · 📌';
  }

  @override
  String vcRoomSharedByAuto(String name) {
    return '$name 分享 · 自动显示';
  }

  @override
  String vcRoomTranscriptMetaPinned(String name, String time) {
    return '$name · $time · 📌';
  }

  @override
  String vcRoomTranscriptMetaAuto(String name, String time) {
    return '$name · $time · 自动显示';
  }

  @override
  String get vcRoomMuted => '已静音';

  @override
  String get vcRoomScreenFrameActions => '共享框操作';

  @override
  String vcRoomMemberSelf(String name) {
    return '$name（你）';
  }

  @override
  String get vcRoomForceMuted => '强制静音';

  @override
  String get vcRoomMemberActions => '成员操作';

  @override
  String get vcRoomDiagnosticsLogHint =>
      '也会以“astell call:”“astell stream:”输出到浏览器 / Xcode 的日志中。';

  @override
  String get vcRoomCopy => '复制';

  @override
  String vcRoomBansLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '封禁（$count）— 从成员行的“…”中操作',
    );
    return '$_temp0';
  }

  @override
  String vcRoomBansLoadFailed(String error) {
    return '无法读取封禁列表：$error';
  }

  @override
  String get vcRoomUnban => '解除封禁';

  @override
  String vcRoomReportBody(String what) {
    return '举报$what。RASQ 将进行审核。';
  }

  @override
  String get vcRoomReportNoteHint => '补充说明（可选）';

  @override
  String vcRoomReportFailed(String error) {
    return '无法举报：$error';
  }

  @override
  String get vcRoomReportSubmit => '举报';

  @override
  String get vcRoomReported => '已举报。将进行审核';

  @override
  String vcRoomLiveBy(String name, String kind) {
    return '$name 正在$kind';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get adsShowLess => '降低顯示頻率';

  @override
  String get adsShowLessDone => '已降低此廣告的顯示頻率';

  @override
  String get adsLabel => '廣告';

  @override
  String adsLabelWithHost(String host) {
    return '廣告 · $host';
  }

  @override
  String get adsMenu => '廣告選單';

  @override
  String get adsOpen => '開啟廣告';

  @override
  String get appNavPostTitle => '貼文';

  @override
  String get appNavReactionsTitle => '回應';

  @override
  String get appNavFollowersTitle => '追蹤者';

  @override
  String get appNavFollowingTitle => '追蹤中';

  @override
  String get appNavShortcutSearch => '搜尋';

  @override
  String get appNavShortcutNewPost => '發文';

  @override
  String get appNavShortcutNewMessage => '撰寫訊息';

  @override
  String get appNavShortcutAskRai => '和 RAi 一起找';

  @override
  String get appNavShortcutGuardianPending => '在監護人完成設定之前無法使用';

  @override
  String get appNavShortcutLoginHint => '登入 SNS 帳號後即可使用';

  @override
  String get backendOauthNoToken => '無法取得存取權杖';

  @override
  String backendOauthServerRequired(String service) {
    return '登入 $service 需要 RASQ 伺服器。請在設定 →「RASQ 伺服器」中設定連線目標。';
  }

  @override
  String get backendOauthNoUrl => '無法取得認證 URL';

  @override
  String get backendOauthHint => '在瀏覽器中授權後，請返回 App 並點按「確認驗證」。';

  @override
  String backendResponseTooLarge(int maxBytes) {
    return '回應過大（超過 $maxBytes 位元組）';
  }

  @override
  String get backendSecurityPasswordlessRemoved =>
      '僅憑電子郵件驗證碼登入的方式已停止。請使用帳號代稱（或電子郵件）和密碼登入';

  @override
  String get backendSecuritySecondFactor => '請輸入寄到電子郵件的驗證碼';

  @override
  String get backendSecurityTooMany => '嘗試次數過多。請稍後再試';

  @override
  String get backendSecurityNoMail => '此伺服器未設定寄送電子郵件';

  @override
  String get backendSecurityEmailUsed => '此電子郵件地址已被其他帳號使用';

  @override
  String get backendSecurityBadCredentials => '帳號代稱（電子郵件）或密碼錯誤';

  @override
  String get backendSecurityBadCode => '驗證碼錯誤或已過期';

  @override
  String get backendSecurityWeakPassword =>
      '此密碼過於簡單（不能使用常見密碼、重複字元，或與帳號代稱、電子郵件相同的密碼）';

  @override
  String get backendSecurityShortPassword => '密碼至少需要 8 個字元';

  @override
  String get backendSecurityBadEmail => '電子郵件地址格式不正確';

  @override
  String get backendSecurityWrongPassword => '目前的密碼錯誤';

  @override
  String get backendSecurityNoPassword => '此帳號沒有設定密碼。請使用寄到目前電子郵件的驗證碼進行確認';

  @override
  String get backendSecurityConfirmRequired => '此操作需要目前的密碼或寄到目前電子郵件的驗證碼';

  @override
  String get backendRoomClosed => '無法進入房間（房間已關閉或不存在）';

  @override
  String get backendRoomForbidden => '無法進入房間（此帳號無法參加）';

  @override
  String backendRoomConnectFailed(String error) {
    return '無法連線到房間：$error';
  }

  @override
  String get backendPaidFeaturesDisabled => '公開測試期間無法使用付費外掛';

  @override
  String get backendAgeTeen => '13–15 歲';

  @override
  String get backendAgeUpperTeen => '16–17 歲';

  @override
  String get backendAgeAdult => '18 歲以上';

  @override
  String get backendNoToken => 'ORGATE 未傳回權杖';

  @override
  String get backendTileAuto => '自動';

  @override
  String get backendTileShow => '顯示';

  @override
  String get backendTileHide => '隱藏';

  @override
  String get backendVerifiedKeybase => '已透過 Keybase 證明驗證';

  @override
  String get backendVerifiedProfile => '已透過個人檔案驗證';

  @override
  String get backendAudioFileName => '音訊';

  @override
  String get backendServerNotConfigured => '尚未設定 RASQ 伺服器的連線位址';

  @override
  String backendServerError(int status) {
    return '伺服器錯誤（$status）';
  }

  @override
  String get backendCollectionList => '清單';

  @override
  String get backendCollectionClip => '便籤';

  @override
  String get bookmarksRemoved => '已移除書籤';

  @override
  String bookmarksRemoveFailed(String error) {
    return '無法移除：$error';
  }

  @override
  String get bookmarksTitle => '書籤';

  @override
  String get bookmarksRetry => '重新載入';

  @override
  String get bookmarksEmptyTitle => '沒有書籤';

  @override
  String get bookmarksEmptyHint => '可透過貼文的 🔖、加入便籤或 ASTell 的書籤來收集';

  @override
  String get bookmarksEmptyNoSnsHint => '此服務沒有書籤功能。長按貼文的 🔖 可將其收集到 RASQ 便籤';

  @override
  String get bookmarksClips => '便籤';

  @override
  String bookmarksClipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$_temp0';
  }

  @override
  String get bookmarksClipHost => 'RASQ（跨 SNS）';

  @override
  String get bookmarksClipPrivate => '非公開便籤';

  @override
  String get bookmarksSeparator => ' · ';

  @override
  String get bookmarksFavorites => '最愛';

  @override
  String get bookmarksSwipeRemove => '移除';

  @override
  String get bookmarksRemove => '移除書籤';

  @override
  String get catalogTitle => '元件目錄';

  @override
  String get catalogSectionBrand => 'Brand（特殊元件）';

  @override
  String get catalogSectionPostTile => 'PostTile — 標準（操作列 / 投票 / 媒體）';

  @override
  String get catalogSectionPostTileEmbedded =>
      'PostTile — 嵌入（引用 / 回應顯示 / 計時通知）& 串摘要';

  @override
  String get catalogSectionCollapsed => 'CollapsedPost（摺疊顯示：已讀 + 長文）';

  @override
  String get catalogSectionPoll => 'PollWidget（未投票 單選 / 多選、已投票、已過期）';

  @override
  String get catalogSectionActionBar => 'ActionBar（spread / leading = 編輯器工具列）';

  @override
  String get catalogSectionRrl => 'RRL 渲染器（post-tile.rrl.json → L1/L2/L3）';

  @override
  String get catalogSheetTitle => '底部面板';

  @override
  String get catalogSheetConfirm => '確定';

  @override
  String get catalogSheetBody => '點按背景或取消將捨棄變更。\n可在此之上彈出強制回應視窗。';

  @override
  String get catalogAlertTitle => '要封鎖嗎？';

  @override
  String get catalogAlertMessage => '點按背景無效（需要明確操作）';

  @override
  String get catalogAlertConfirm => '封鎖';

  @override
  String get catalogAlertCancel => '取消';

  @override
  String get catalogDropdownAsc => '遞增';

  @override
  String get catalogDropdownDesc => '遞減';

  @override
  String get catalogDropdownDefault => '預設';

  @override
  String get catalogDropdownReport => '檢舉';

  @override
  String get catalogSheetModalTitle => '面板 → 強制回應視窗插入';

  @override
  String get catalogModalTitle => '強制回應視窗';

  @override
  String get catalogModalMessage => '面板將保留';

  @override
  String get catalogModalOpen => '顯示強制回應視窗';

  @override
  String get childSafeLevelStrict => '嚴格';

  @override
  String get childSafeLevelStandard => '普通';

  @override
  String get childSafeLevelMild => '寬鬆';

  @override
  String get childSafeTopicModeAllow => '白名單';

  @override
  String get childSafeTopicModeDeny => '黑名單';

  @override
  String get childSafeInstallNone => '不可安裝';

  @override
  String get childSafeInstallListed => '僅限所選';

  @override
  String get childSafeInstallAny => '自由';

  @override
  String get childSafeInstallExamples => '接近範例的';

  @override
  String get childSafeEmptyWhitelistError => '白名單為空。請至少加入一個話題，或改為黑名單';

  @override
  String get childSafeMethodJpki => '個人編號卡（JPKI）';

  @override
  String get childSafeMethodSelfDeclared => '自行申報';

  @override
  String get childSafeErrorCodeInvalid => '驗證碼錯誤或已過期';

  @override
  String get childSafeErrorHandleTaken => '該帳號代稱已被使用';

  @override
  String get childSafeErrorAlreadyLinked => '該帳號已被監護（或正在監護他人）';

  @override
  String get childSafeErrorCodeGone => '代碼已過期或已被使用。請請監護人重新產生';

  @override
  String get childSafeErrorDevice => '無法在此裝置上登入';

  @override
  String get childSafeErrorTooMany => '嘗試次數過多。請稍後再試';

  @override
  String get childSafeNoServer => '尚未設定 RASQ 伺服器的連線位址';

  @override
  String childSafeNoticeMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '（另有 $count 則）',
    );
    return '$_temp0';
  }

  @override
  String get childSafeNoticeRefreshed => '兒童安全：已重新取得監護人的設定';

  @override
  String get childSafeNoticeView => '查看';

  @override
  String get childSafeBlocked => '已被監護人停用';

  @override
  String childSafeBlockedWith(String label) {
    return '已被監護人停用（$label）';
  }

  @override
  String childSafeTimeRange(String start, String end) {
    return '$start～$end';
  }

  @override
  String get childSafeLockedUntilSetup => '在監護人完成設定之前無法使用';

  @override
  String childSafeWindowNoDm(String window) {
    return '監護時段（$window）無法使用私訊';
  }

  @override
  String get childSafeBlockedAstell => '監護人已停用 ASTell';

  @override
  String childSafeWindowNoAstell(String window) {
    return '監護時段（$window）無法使用 ASTell';
  }

  @override
  String get childSafeBlockedDm => '監護人已停用私訊';

  @override
  String childSafeWindowNoNotifications(String window) {
    return '監護時段（$window）無法查看通知';
  }

  @override
  String get childSafeBlockedRai => '監護人已停用 RAi';

  @override
  String get childSafeBlockedStore => '監護人已停用外掛商店';

  @override
  String get childSafeBlockedSearch => '監護人已停用搜尋';

  @override
  String get childSafeBlockedAddAccount => '監護人已禁止新增 SNS 帳號';

  @override
  String get childSafeBlockedCustomPlugins => '監護人已停用自訂外掛';

  @override
  String get childSafeBlockedPlugins => '監護人已停用外掛';

  @override
  String childSafeWindowNoPostDetail(String window) {
    return '監護時段（$window）無法開啟貼文詳情';
  }

  @override
  String get childSafePostHidden => '無法顯示此貼文';

  @override
  String get childSafeListSeparator => '、';

  @override
  String childSafeBullet(String text) {
    return '• $text';
  }

  @override
  String childSafeTopicsEtc(String topics) {
    return '$topics 等';
  }

  @override
  String get childSafeComposeNoTopicsAllowed => '根據監護人的設定，目前無法發文';

  @override
  String childSafeComposeTopicsOnly(String topics) {
    return '根據監護人的設定，只能發布指定話題（$topics）的貼文。請依話題撰寫';
  }

  @override
  String childSafeComposeTopicDenied(String topic) {
    return '根據監護人的設定，無法發布「$topic」話題的貼文。請修改內容';
  }

  @override
  String childSafeQuoted(String text) {
    return '「$text」';
  }

  @override
  String childSafeComposeStimulus(String level, String word) {
    return '根據監護人的設定（$level），無法傳送此表達$word。請換個說法';
  }

  @override
  String get childSafeBlockedThisPlugin => '監護人已停用此外掛';

  @override
  String get childSafeDevPreviewUnknown => '只能執行監護人選擇的外掛（此載入方式無法確認是哪個外掛）';

  @override
  String get childSafeBlockedInstall => '監護人已禁止安裝外掛';

  @override
  String get childSafeNearDenyPlugin => '此外掛接近監護人禁止的範例';

  @override
  String get childSafeInstallListedOnly => '只能安裝監護人選擇的外掛';

  @override
  String get childSafeInstallExamplesOnly => '只能安裝監護人選擇的外掛以及接近允許範例的外掛';

  @override
  String get childSafeCacheUnverified => '無法驗證已儲存限制的簽章。請連網重新取得';

  @override
  String get childSafeNewSettingsUnverified => '無法驗證監護人新設定的簽章（維持先前的設定）';

  @override
  String get childSafeComposeLocked => '在監護人完成設定前無法傳送';

  @override
  String childSafeComposeDailyLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天已傳送 $count 則（監護人設定的每日數量）。明天再來吧',
    );
    return '$_temp0';
  }

  @override
  String childSafeComposeAfterTransform(String message) {
    return '$message（傳送前加工後的內文）';
  }

  @override
  String get childSafeStatePending => '等待設定';

  @override
  String get childSafeWatchAsGuardian => '監護（監護人）';

  @override
  String get childSafeLoginWithCode => '使用監護人提供的代碼登入';

  @override
  String get childSafeChildMode => '兒童模式';

  @override
  String get childSafeGuardianStateApplied => '監護中（已送達裝置）';

  @override
  String childSafeGuardianStateNotApplied(int revision) {
    return '監護中（設定 $revision 尚未送達裝置）';
  }

  @override
  String childSafeGuardianPledgeTitle(String version) {
    return '監護人誓約（版本 $version）';
  }

  @override
  String childSafeGuardianPledgeMessage(String pledge) {
    return '$pledge\n\n同意後，將進入使用個人編號卡（數位認證 App）的驗證（適用於居住在日本的使用者）。';
  }

  @override
  String get childSafeGuardianPledgeConfirm => '同意並繼續';

  @override
  String get childSafeGuardianCancel => '取消';

  @override
  String get childSafeGuardianLoadError => '無法載入';

  @override
  String get childSafeGuardianReload => '重新載入';

  @override
  String get childSafeGuardianVerifySection => '監護人驗證';

  @override
  String get childSafeGuardianVerified => '已驗證';

  @override
  String get childSafeGuardianNotVerified => '尚未驗證';

  @override
  String get childSafeGuardianVerifyIntro =>
      '在建立或連結孩子的帳號之前，需要進行監護人驗證（日本使用個人編號卡）。';

  @override
  String get childSafeGuardianVerifyIntroDetail =>
      '在建立或連結孩子的帳號之前，需要進行監護人驗證（日本使用個人編號卡（JPKI），其他國家在網頁主控台自行申報）。';

  @override
  String get childSafeGuardianVerifyJpki => '使用個人編號卡驗證';

  @override
  String get childSafeGuardianVerifyJpkiSubtitle =>
      '適用於居住在日本的使用者。同意誓約後，將在外部瀏覽器中開啟';

  @override
  String get childSafeGuardianVerifyWeb => '在網頁主控台驗證';

  @override
  String get childSafeGuardianOpensInBrowser => '將在外部瀏覽器中開啟';

  @override
  String childSafeGuardianChildrenSection(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '監護中的孩子（$count / $max）',
    );
    return '$_temp0';
  }

  @override
  String get childSafeGuardianNoChildren => '尚無。';

  @override
  String get childSafeGuardianCreatedByGuardian => ' · 由監護人建立';

  @override
  String get childSafeGuardianAddSection => '新增孩子';

  @override
  String get childSafeGuardianCreate => '建立孩子的帳號';

  @override
  String get childSafeGuardianCreateSubtitle =>
      '設定帳號代稱 / 名稱 / 年齡層後，將顯示一次用於在孩子裝置上登入的代碼';

  @override
  String get childSafeGuardianHandleHint => '帳號代稱（英文字母和數字）';

  @override
  String get childSafeGuardianNameHint => '顯示名稱';

  @override
  String get childSafeGuardianCreateButton => '建立';

  @override
  String childSafeGuardianNewLoginCodeTitle(String handle) {
    return '@$handle 的登入代碼（在孩子裝置的「使用監護人提供的代碼登入」中輸入，或用孩子裝置的相機掃描 QR 碼）';
  }

  @override
  String get childSafeGuardianPair => '透過代碼連結';

  @override
  String get childSafeGuardianPairSubtitle =>
      '透過孩子裝置上的「兒童模式」連結孩子已有的 RASQ 帳號（10 分鐘內，僅限一次）';

  @override
  String get childSafeGuardianPairCodeTitle =>
      '連結代碼（在孩子裝置的「兒童模式」中輸入，或用孩子裝置的相機掃描 QR 碼）';

  @override
  String childSafeGuardianCodeExpires(String time) {
    return '有效期限至 $time。關閉此畫面後將無法再次顯示（重新產生後，先前的代碼將無法使用）。';
  }

  @override
  String get childSafeGuardianCodeQr => '代碼 QR 碼';

  @override
  String get childSafeGuardianCopy => '複製';

  @override
  String get childSafeGuardianCopyLink => '複製連結';

  @override
  String get childSafeGuardianClose => '關閉';

  @override
  String get childSafeGuardianPageTimeline => '時間軸';

  @override
  String get childSafeGuardianPageComposer => '貼文';

  @override
  String get childSafeGuardianPageAstell => 'ASTell';

  @override
  String get childSafeGuardianPagePlugins => '外掛';

  @override
  String get childSafeGuardianPageSns => 'SNS';

  @override
  String get childSafeGuardianPageScreenTime => '螢幕使用時間';

  @override
  String get childSafeGuardianPageOther => '其他';

  @override
  String get childSafeGuardianTimeFormatError => '請以 HH:MM 格式輸入時間';

  @override
  String get childSafeGuardianConfirmTitle => '傳送此設定';

  @override
  String get childSafeGuardianConfirmSend => '傳送';

  @override
  String childSafeGuardianConfirmIntro(String handle) {
    return '此設定將送達 @$handle 的裝置。';
  }

  @override
  String childSafeGuardianConfirmIntroDetail(String handle) {
    return '@$handle 的裝置將收到由 Central 簽署的設定（在裝置上驗證後套用）。';
  }

  @override
  String childSafeGuardianSaved(int revision) {
    return '已儲存（設定 $revision）。送達孩子的裝置後將顯示「已送達」';
  }

  @override
  String childSafeGuardianImportPreset(String band) {
    return '載入 $band 的預設';
  }

  @override
  String get childSafeGuardianImportCopy => '複製其他孩子的設定';

  @override
  String childSafeGuardianImportedPreset(String band) {
    return '已載入 $band 的預設';
  }

  @override
  String get childSafeGuardianCopyWhich => '要複製哪個孩子的設定？';

  @override
  String childSafeGuardianNotSetUp(String handle) {
    return '@$handle 尚未完成設定';
  }

  @override
  String childSafeGuardianCopied(String handle) {
    return '已複製 @$handle 的設定';
  }

  @override
  String childSafeGuardianNotSavedYet(String what) {
    return '$what（尚未儲存）';
  }

  @override
  String get childSafeGuardianEnd => '結束監護';

  @override
  String childSafeGuardianEndMessage(String handle) {
    return '將解除 @$handle 的所有限制。孩子的裝置將在下次連線時解除。如需恢復，請重新連結。';
  }

  @override
  String childSafeGuardianEndMessageDetail(String handle) {
    return '將解除 @$handle 的所有限制。孩子的裝置將在下次連上 Central 時解除。如需恢復，請重新連結。';
  }

  @override
  String get childSafeGuardianEndConfirm => '結束';

  @override
  String get childSafeGuardianEndSubtitle => '解除所有限制';

  @override
  String get childSafeGuardianSummarySection => '近期發布內容摘要（14 天）';

  @override
  String get childSafeGuardianLoginSection => '孩子裝置的登入';

  @override
  String get childSafeGuardianReissue => '重新產生代碼';

  @override
  String get childSafeGuardianReissueSubtitle =>
      '在孩子裝置的「使用監護人提供的代碼登入」中輸入的代碼（10 分鐘內，僅限一次。先前的代碼將無法使用）';

  @override
  String childSafeGuardianLoginCodeTitle(String handle) {
    return '@$handle 的登入代碼';
  }

  @override
  String get childSafeGuardianSaveButton => '儲存並傳送到孩子的裝置';

  @override
  String get childSafeGuardianImportTooltip => '匯入設定';

  @override
  String childSafeGuardianPresetCaption(String band) {
    return '選擇強度後，時間軸和貼文的判定強度將統一。可透過右側的圓形按鈕載入 $band 的預設或其他孩子的設定。';
  }

  @override
  String get childSafeGuardianSummaryEmpty => '尚無報告（孩子的裝置每天傳送一次已結束日期的數量）。';

  @override
  String get childSafeGuardianSummaryCaption =>
      '僅包括傳送數 / 攔截數 / 攔截類型（貼文內文和話題不會送達。傳送前的判定在孩子的裝置上進行）。';

  @override
  String childSafeGuardianSummaryDay(int posts, int blocked, String trips) {
    return '傳送 $posts · 攔截 $blocked$trips';
  }

  @override
  String childSafeGuardianSummaryTrips(String list) {
    return '（$list）';
  }

  @override
  String get childSafeGuardianSummaryTripsSeparator => '、';

  @override
  String get childSafeGuardianTimelineEnabled => '篩選時間軸';

  @override
  String get childSafeGuardianTimelineEnabledSubtitle => '不顯示含有強烈用語的貼文，並依話題篩選';

  @override
  String get childSafeGuardianTimelineLevel => '時間軸強度';

  @override
  String get childSafeGuardianTimelineTopics => '時間軸話題';

  @override
  String get childSafeGuardianTimelineAllowHint => '顯示的話題（用「,」分隔詞語或標籤）';

  @override
  String get childSafeGuardianTimelineDenyHint => '不顯示的話題（用「,」分隔詞語或標籤）';

  @override
  String get childSafeGuardianTimelineAllowNote => '白名單：只有符合任一話題的貼文才會出現在時間軸中。';

  @override
  String get childSafeGuardianTimelineDenyNote => '黑名單：不顯示符合的貼文（空 = 不依話題篩選）。';

  @override
  String get childSafeGuardianComposerEnabled => '判定貼文';

  @override
  String get childSafeGuardianComposerEnabledSubtitle =>
      '依強烈用語和話題在傳送前攔截（標記命中的詞語）';

  @override
  String get childSafeGuardianComposerLevel => '貼文強度';

  @override
  String get childSafeGuardianPostsPerDayHint => '每天可傳送的貼文數（空 = 不限制，0～1000）';

  @override
  String get childSafeGuardianComposerTopics => '貼文話題';

  @override
  String get childSafeGuardianComposerAllowHint => '可傳送的話題（用「,」分隔詞語或標籤）';

  @override
  String get childSafeGuardianComposerDenyHint => '不可傳送的話題（用「,」分隔詞語或標籤）';

  @override
  String get childSafeGuardianComposerAllowNote => '白名單：只能傳送符合任一話題的貼文（不適用於私訊）。';

  @override
  String get childSafeGuardianComposerDenyNote =>
      '黑名單：符合的貼文無法傳送（空 = 不依話題攔截。不適用於私訊）。';

  @override
  String get childSafeGuardianAstellCaption => '孩子在 ASTell（房間的通話、聊天、分享）中可以做的事。';

  @override
  String get childSafeGuardianInstallSection => '安裝';

  @override
  String get childSafeGuardianInstallCaption =>
      '孩子可以自行安裝的範圍。外掛會不斷增加，因此不是逐一決定，而是透過下方的「範例」大致決定。';

  @override
  String get childSafeGuardianNamedSection => '依名稱允許的外掛';

  @override
  String get childSafeGuardianNamedNone => '無。';

  @override
  String get childSafeGuardianNamedCaption => '此處的外掛即使接近禁止的範例也可以使用（點 ✕ 移除）。';

  @override
  String get childSafeGuardianRemove => '移除';

  @override
  String get childSafeGuardianAddIdHint => '依 id 新增（例：jp.example.quiz）';

  @override
  String get childSafeGuardianAddIdButton => '新增';

  @override
  String get childSafeGuardianIdShapeError =>
      '不是外掛 id 的格式（小寫英文字母、數字、「.」「_」「-」，例：jp.example.quiz）';

  @override
  String get childSafeGuardianSnsCaption =>
      '孩子可以使用的 SNS 類型和伺服器（來自你的組合）。不選擇伺服器時，該類型的任何伺服器皆可。不會借出監護人的 SNS 登入。';

  @override
  String get childSafeGuardianSnsAdd => '孩子可以新增 SNS 帳號';

  @override
  String get childSafeGuardianTimeEnabled => '監護時段';

  @override
  String get childSafeGuardianTimeEnabledSubtitle => '在此期間只有一條時間軸（以孩子裝置的時鐘為準）';

  @override
  String get childSafeGuardianTimeStartHint => '開始 21:00';

  @override
  String get childSafeGuardianTimeEndHint => '結束 06:00';

  @override
  String get childSafeGuardianTimeRangeSeparator => '～';

  @override
  String get childSafeGuardianTimeLegacyNote =>
      '目前設定為舊格式的「在此期間不顯示任何內容」。此格式無法重新儲存，請加入要顯示的話題或改為黑名單後再儲存。';

  @override
  String get childSafeGuardianTimeTopics => '此期間的話題';

  @override
  String get childSafeGuardianTimeAllowHint => '此期間顯示的話題（用「,」分隔詞語或標籤）';

  @override
  String get childSafeGuardianTimeDenyHint => '此期間不顯示的話題（用「,」分隔詞語或標籤）';

  @override
  String get childSafeGuardianTimeAllowNote => '白名單：此期間只顯示符合任一話題的貼文。';

  @override
  String get childSafeGuardianTimeDenyNote => '黑名單：此期間不顯示符合的貼文（空 = 不依話題篩選）。';

  @override
  String get childSafeGuardianHideNotifications => '隱藏通知';

  @override
  String get childSafeGuardianHidePostDetail => '不允許開啟貼文詳情';

  @override
  String get childSafeGuardianHideDm => '隱藏私訊';

  @override
  String get childSafeGuardianRaiEnabled => '可以使用 RAi';

  @override
  String get childSafeGuardianRaiComingSoon => '準備中（目前不生效）';

  @override
  String get childSafeGuardianRaiAutomation => '使用函式自動化';

  @override
  String get childSafeGuardianRaiAutomationSubtitle => '關閉時，僅透過引導（指示）進行';

  @override
  String get childSafeGuardianSearchSection => '搜尋';

  @override
  String get childSafeGuardianFeaturesSection => '功能';

  @override
  String get childSafeGuardianExamplesTitlePlugins => '透過範例決定（外掛）';

  @override
  String get childSafeGuardianExamplesTitleTl => '透過範例決定（便籤 / 清單）';

  @override
  String get childSafeGuardianExamplesCaptionPlugins =>
      '透過範例選擇「允許 / 禁止這類外掛」。孩子的裝置根據外掛的名稱和說明是否接近範例來判斷。接近禁止範例的外掛即使在「自由」下也無法使用。選擇「接近範例的」後，可以使用依名稱允許的外掛以及接近允許範例的外掛。';

  @override
  String get childSafeGuardianExamplesCaptionTl =>
      '從你最近的操作 / 便籤 / 清單中選擇「允許 / 禁止這類內容」。孩子的便籤 / 清單中，內容接近禁止範例的，不會出現在清單和時間軸中。';

  @override
  String get childSafeGuardianPickPlugins => '選擇範例（外掛 / 商店）';

  @override
  String get childSafeGuardianPickTl => '選擇範例（最近的操作 / 便籤 / 清單）';

  @override
  String childSafeGuardianPickCounts(int allow, int deny) {
    return '允許範例 $allow / 禁止範例 $deny';
  }

  @override
  String childSafeGuardianPickTitlePlugins(String handle) {
    return '外掛範例（@$handle）';
  }

  @override
  String childSafeGuardianPickTitleTl(String handle) {
    return '時間軸範例（@$handle）';
  }

  @override
  String get childSafeGuardianAllowLabel => '允許範例';

  @override
  String get childSafeGuardianDenyLabel => '禁止範例';

  @override
  String get childSafeGuardianPickIntroPlugins =>
      '查看內容，為孩子選擇「允許範例」/「禁止範例」（也可向右 / 向左滑動）。孩子的裝置會根據與範例的接近程度來區分新外掛。';

  @override
  String get childSafeGuardianPickIntroTl =>
      '查看內容，為孩子選擇「允許範例」/「禁止範例」（也可向右 / 向左滑動）。孩子的裝置會根據與範例的接近程度來區分便籤 / 清單。';

  @override
  String get childSafeScreensBadge => '監護中';

  @override
  String childSafeScreensWindowBanner(String window, String detail) {
    return '現在是監護時段（$window）。$detail';
  }

  @override
  String get childSafeScreensWindowNothing => '不顯示任何貼文';

  @override
  String childSafeScreensWindowAllowOnly(String topics) {
    return '僅顯示與「$topics」相關的話題';
  }

  @override
  String childSafeScreensWindowDenied(String topics) {
    return '不顯示與「$topics」相關的話題';
  }

  @override
  String get childSafeScreensBlockedHint => '監護設定由監護人決定';

  @override
  String get childSafeScreensHubTitle => '兒童安全';

  @override
  String get childSafeScreensHubIntro =>
      '監護人決定孩子帳號的使用方式。監護人只會收到數量和被阻止的類型，不會傳送貼文內文。';

  @override
  String get childSafeScreensHubIntroDetail =>
      '監護人的 RASQ 帳號決定孩子的 RASQ 帳號的使用方式。貼文的判定在本裝置上進行，監護人只會收到傳送數、阻止數以及傳送前阻止的類型（不會傳送貼文內文或話題）。';

  @override
  String get childSafeScreensHubManagedSection => '您正受到監護';

  @override
  String get childSafeScreensHubParent => '監護人';

  @override
  String get childSafeScreensHubState => '狀態';

  @override
  String childSafeScreensHubStateActive(int revision) {
    return '監護中（設定版本 $revision）';
  }

  @override
  String get childSafeScreensHubOffline => '目前無法連線至伺服器。將依先前的設定繼續監護。';

  @override
  String get childSafeScreensHubRefresh => '重新取得監護人的設定';

  @override
  String get childSafeScreensHubAsGuardian => '以監護人身分';

  @override
  String childSafeScreensHubGuardianVerified(String method) {
    return '已驗證（$method）。建立、連結或設定孩子的帳號';
  }

  @override
  String get childSafeScreensHubGuardianUnverified =>
      '監護人驗證請在 Web 主控台進行（日本使用個人編號卡，其他地區為自行申報）';

  @override
  String get childSafeScreensHubAsChild => '以孩子身分';

  @override
  String get childSafeScreensHubChildModeLogin => '使用監護人提供的代碼登入';

  @override
  String get childSafeScreensHubChildModePair => '使用監護人的代碼連結此帳號';

  @override
  String get childSafeScreensHubLoginSubtitle => '登入監護人建立的孩子帳號';

  @override
  String get childSafeScreensHubThisDevice => '此裝置';

  @override
  String get childSafeScreensHubSafety => '隱私與安全模式';

  @override
  String get childSafeScreensHubSafetyManaged => '監護期間，敏感媒體一律隱藏（無法變更）';

  @override
  String get childSafeScreensHubSafetyNormal => '敏感媒體的處理方式';

  @override
  String childSafeScreensTopicsNote(String label, String topics) {
    return '（$label：$topics）';
  }

  @override
  String get childSafeScreensTopicsNone => '無';

  @override
  String get childSafeScreensTopicsShown => '顯示的話題';

  @override
  String get childSafeScreensTopicsHidden => '隱藏的話題';

  @override
  String get childSafeScreensTopicsSendable => '可傳送的話題';

  @override
  String get childSafeScreensTopicsUnsendable => '不可傳送的話題';

  @override
  String get childSafeScreensTopicsNotShown => '不顯示的話題';

  @override
  String childSafeScreensSummaryTimeline(String level, String note) {
    return '時間軸：$level$note';
  }

  @override
  String childSafeScreensSummaryComposer(String level, String note) {
    return '貼文判定：$level$note';
  }

  @override
  String childSafeScreensSummaryPostsPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每天可傳送的貼文：$count 則',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryTime(String window, String note) {
    return '監護時段：$window$note';
  }

  @override
  String get childSafeScreensSummaryTimeNothing => '（不顯示貼文）';

  @override
  String childSafeScreensSummarySns(
    String kinds,
    String servers,
    String noAdd,
  ) {
    return '可用的 SNS：$kinds$servers$noAdd';
  }

  @override
  String get childSafeScreensSummaryAny => '任意';

  @override
  String childSafeScreensSummarySnsServers(String servers) {
    return '（$servers）';
  }

  @override
  String get childSafeScreensSummarySnsNoAdd => '，不可新增';

  @override
  String childSafeScreensSummaryFeaturesOff(String list) {
    return '已停用的功能：$list';
  }

  @override
  String childSafeScreensSummarySearchOff(String list) {
    return '已停用的搜尋：$list';
  }

  @override
  String childSafeScreensSummaryPlugins(String scope, String install) {
    return '外掛：$scope，安裝：$install';
  }

  @override
  String childSafeScreensSummaryPluginsExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已選的 $count 個，以及與允許範例相近的',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryPluginsListed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '僅限已選的 $count 個',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryExamples(int allow, int deny) {
    return '範例：允許 $allow 個 / 阻止 $deny 個（與阻止範例相近的外掛、便籤、清單不會顯示）';
  }

  @override
  String childSafeScreensSummaryRai(int count, String noAuto) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RAi：$count 類函式$noAuto',
    );
    return '$_temp0';
  }

  @override
  String get childSafeScreensSummaryRaiNoAuto => '（無自動化）';

  @override
  String get childSafeScreensSummaryRaiOff => 'RAi：無法使用';

  @override
  String childSafeScreensFromLink(String action) {
    return '已透過連結（QR 碼）填入代碼。請確認是從自己的監護人那裡收到的，再點按「$action」。如果是陌生人的連結，請不要點按，直接關閉。';
  }

  @override
  String get childSafeScreensPaired => '已與監護人連結。請等待監護人完成設定';

  @override
  String get childSafeScreensPairNotLoggedIn =>
      '尚未登入 RASQ 帳號。如果是監護人建立的帳號，請使用監護人提供的代碼登入。';

  @override
  String get childSafeScreensPairExistingLogin => '登入現有的 RASQ 帳號';

  @override
  String childSafeScreensPairIntro(String handle) {
    return '將 @$handle 連結到監護人的監護。請輸入監護人螢幕上顯示的代碼（8 碼）。連結後，在監護人完成設定之前無法使用。';
  }

  @override
  String childSafeScreensPairIntroDetail(String handle) {
    return '將 @$handle 連結到監護人的監護。請輸入監護人螢幕（App 或 Web 主控台）上顯示的代碼（8 碼，例如 ABCD-EFGH）。連結後，在監護人完成設定之前無法使用 App。';
  }

  @override
  String get childSafeScreensPairButton => '連結';

  @override
  String get childSafeScreensPairQrHint => '也可以用本裝置的相機 App 掃描監護人螢幕上的 QR 碼進行連結。';

  @override
  String get childSafeScreensPairQrHintDetail =>
      '用本裝置的相機 App 掃描監護人螢幕上的 QR 碼，會開啟已填入代碼的此畫面。貼上連結（rasq://child-safe/pair?code=…）也可以連結。';

  @override
  String get childSafeScreensPairNoQr => '本裝置無法掃描 QR 碼。請輸入代碼。';

  @override
  String get childSafeScreensPairNoQrDetail =>
      '本裝置無法掃描 QR 碼。請輸入代碼，或貼上連結（rasq://child-safe/pair?code=…）。';

  @override
  String get childSafeScreensLoginFailed => '無法登入';

  @override
  String childSafeScreensLoggedIn(String handle, String device) {
    return '已登入 @$handle（$device）';
  }

  @override
  String get childSafeScreensLoginIntro =>
      '監護人在 App 中建立孩子帳號後，會顯示一組一次性代碼。輸入該代碼後，本裝置將成為該帳號。本裝置上的 SNS 帳號不會被沿用。';

  @override
  String get childSafeScreensLoginCodeHint => '登入代碼';

  @override
  String get childSafeScreensLoginButton => '登入';

  @override
  String get childSafeScreensPendingUnverifiedTitle => '無法驗證監護人的設定';

  @override
  String get childSafeScreensPendingTitle => '請等待監護人完成設定';

  @override
  String get childSafeScreensPendingSignatureMismatch => '設定的簽章不一致。';

  @override
  String childSafeScreensPendingBody(String parent) {
    return '您已與 $parent 建立監護連結。$parent 決定使用方式後，即可開始使用。';
  }

  @override
  String get childSafeScreensPendingParent => '監護人';

  @override
  String get childSafeScreensPendingOffline => '目前無法連線至伺服器。';

  @override
  String get childSafeScreensPendingRefresh => '重新整理';

  @override
  String get childSafeScreensPendingLogout => '登出';

  @override
  String get childSafeScreensPendingRasqLogin => '登入 RASQ 帳號';

  @override
  String get clipsNoSession => '沒有工作階段';

  @override
  String get clipsChildSafeBlocked => '監護人已封鎖此便籤';

  @override
  String get clipsRetry => '重新載入';

  @override
  String get clipsEmptyTitle => '此便籤是空的';

  @override
  String get clipsEmptyHint => '可透過貼文選單中的「加入便籤」收集到這裡';

  @override
  String clipsPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$_temp0';
  }

  @override
  String get clipsKindHost => 'RASQ 便籤（跨 SNS）';

  @override
  String get clipsKindPrivate => '非公開便籤';

  @override
  String get clipsCaptionSeparator => ' · ';

  @override
  String get clipsLoading => '載入中…';

  @override
  String get clipsLoadMore => '載入更多';

  @override
  String clipsActionFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get clipsPublishHint => '公開後，可透過帳號頁面和分享連結檢視';

  @override
  String clipsPublishHintSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '公開後，可透過帳號頁面和分享連結檢視（僅限追蹤者等 $count 則貼文不會包含在內）',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublishNeedsAccount => '公開需要 RASQ 帳號';

  @override
  String get clipsPublish => '公開';

  @override
  String clipsPublishedPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已公開（正在確認 $count 則貼文的公開範圍）',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublished => '已公開';

  @override
  String clipsPublishedStatusSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '公開中（僅限追蹤者等 $count 則貼文未包含在內）',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublishedStatus => '公開中';

  @override
  String get clipsLinkCopied => '已複製連結';

  @override
  String get clipsCopyLink => '複製連結';

  @override
  String get clipsUnpublished => '已取消公開';

  @override
  String get clipsUnpublish => '取消公開';

  @override
  String get clipsAddTitle => '加入便籤';

  @override
  String get clipsAddAddedHost => '已新增 · RASQ 便籤';

  @override
  String get clipsAddAddedHostPublished => '已新增 · RASQ 便籤（公開中）';

  @override
  String clipsAddHostRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則 · RASQ 便籤（跨 SNS）',
    );
    return '$_temp0';
  }

  @override
  String clipsAddHostRowPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則 · RASQ 便籤（跨 SNS） · 公開中',
    );
    return '$_temp0';
  }

  @override
  String get clipsAddCreate => '建立新便籤';

  @override
  String clipsAdded(String name) {
    return '已新增至「$name」';
  }

  @override
  String clipsAddFailed(String error) {
    return '無法加入便籤：$error';
  }

  @override
  String get clipsCreateTitle => '新便籤';

  @override
  String get clipsCreateNameHint => '便籤名稱';

  @override
  String get clipsCreateDescriptionHint => '說明（選填）';

  @override
  String get clipsCreateHost => '設為 RASQ 便籤（跨 SNS）';

  @override
  String get clipsCreateHostSubtitle => '儲存在此裝置上，其他 SNS 的貼文也可放入同一便籤';

  @override
  String get clipsCreateAndAdd => '建立並新增';

  @override
  String get clipsIndexFallback => '無法判斷話題的貼文';

  @override
  String get clipsIndexSingles => '單獨貼文';

  @override
  String clipsIndexRelated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '相關貼文 $count 則',
    );
    return '$_temp0';
  }

  @override
  String get clipsTocTitle => '目錄';

  @override
  String clipsTocPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String get clipsTocFiltering => '篩選中';

  @override
  String get clipsNoServer => '尚未設定 RASQ 帳號的伺服器';

  @override
  String get clipsNotFound => '找不到便籤';

  @override
  String get collectionsImportToTimeline => '匯入時間軸';

  @override
  String get collectionsNotFound => '找不到';

  @override
  String get collectionsNotFoundHint => '已被刪除或設為不公開';

  @override
  String get collectionsReload => '重新載入';

  @override
  String get collectionsBlockedList => '監護人已封鎖此清單';

  @override
  String get collectionsBlockedClip => '監護人已封鎖此便籤';

  @override
  String get collectionsMenuCopyLink => '複製連結';

  @override
  String get collectionsMenuRefresh => '立即重新取得';

  @override
  String get collectionsMenuMakePrivate => '設為不公開';

  @override
  String get collectionsMenuMakePublic => '公開';

  @override
  String get collectionsMenuRename => '修改名稱和說明';

  @override
  String get collectionsMenuDelete => '刪除';

  @override
  String get collectionsMenuUnpublish => '取消公開';

  @override
  String get collectionsLinkCopied => '已複製連結';

  @override
  String get collectionsRefreshFailed => '無法重新取得';

  @override
  String get collectionsRefreshed => '已重新取得';

  @override
  String get collectionsRenameTitle => '名稱和說明';

  @override
  String get collectionsSave => '儲存';

  @override
  String get collectionsNameHint => '名稱';

  @override
  String get collectionsDescriptionHint => '說明（選填）';

  @override
  String collectionsDeleteConfirmTitle(String name) {
    return '要刪除「$name」嗎？';
  }

  @override
  String get collectionsDeleteConfirmMessage => '它也會從追蹤者的列表中消失。';

  @override
  String get collectionsDeleteButton => '刪除';

  @override
  String get collectionsCancel => '取消';

  @override
  String collectionsActionFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get collectionsTabPosts => '貼文';

  @override
  String get collectionsTabTopics => '話題目錄';

  @override
  String get collectionsTabMembers => '成員';

  @override
  String get collectionsTabServers => '伺服器';

  @override
  String get collectionsStatusRefreshedOnView => '已在查看時更新';

  @override
  String get collectionsStatusRefreshFailed => '無法重新取得（顯示的是先前的內容）';

  @override
  String get collectionsStatusFollowingHint => '如果你與成員屬於同一伺服器或追蹤了成員，查看時會更新';

  @override
  String get collectionsKindList => 'RASQ 清單';

  @override
  String get collectionsKindClip => 'RASQ 便籤';

  @override
  String get collectionsPrivate => '不公開';

  @override
  String get collectionsPublic => '公開';

  @override
  String collectionsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String collectionsItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$_temp0';
  }

  @override
  String collectionsFollowerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '追蹤者 $count',
    );
    return '$_temp0';
  }

  @override
  String collectionsUpdatedAgo(String ago) {
    return '更新於 $ago';
  }

  @override
  String get collectionsSeparator => ' · ';

  @override
  String get collectionsFollowing => '追蹤中';

  @override
  String get collectionsFollow => '追蹤';

  @override
  String get collectionsNoPostsYet => '還沒有貼文';

  @override
  String get collectionsNoPostsHintEmpty => '可在使用者頁面的 … →「新增至 RASQ 清單」中加入成員';

  @override
  String get collectionsNoPostsHintCollecting => '有權查看的人開啟時會收集貼文';

  @override
  String get collectionsClipEmpty => '此便籤是空的';

  @override
  String get collectionsItemGone => '此貼文已無法查看（已被刪除或公開範圍已變更）';

  @override
  String get collectionsItemChecking => '正在確認公開範圍';

  @override
  String get collectionsAddMembers => '新增成員';

  @override
  String collectionsMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已新增 $count 人',
    );
    return '$_temp0';
  }

  @override
  String collectionsAddFailed(String error) {
    return '無法新增：$error';
  }

  @override
  String get collectionsNoMembers => '沒有成員';

  @override
  String get collectionsNoMembersHint => '請使用「新增成員」，或在使用者頁面的 … →「新增至 RASQ 清單」';

  @override
  String collectionsMemberSubtitle(String handle, String kind) {
    return '@$handle · $kind';
  }

  @override
  String get collectionsRemoveFromListTooltip => '從清單中移除';

  @override
  String collectionsRemoveFailed(String error) {
    return '無法移除：$error';
  }

  @override
  String get collectionsNotFetchableHint =>
      '沒有可以取得清單中成員資訊的帳號（需要與成員同一伺服器的帳號，或追蹤了成員）';

  @override
  String get collectionsNoServer => '尚未設定 RASQ 帳號的伺服器';

  @override
  String collectionsCheckFailed(String error) {
    return '無法確認：$error';
  }

  @override
  String get collectionsPickerEmpty => '還沒有 RASQ 清單';

  @override
  String get collectionsPickerNoHits => '找不到';

  @override
  String get collectionsPickerMine => '我的清單';

  @override
  String get collectionsPickerNotFetchable => '無法取得';

  @override
  String get collectionsNotLoggedIn => '未登入';

  @override
  String collectionsImportRejected(String name, String reason) {
    return '無法匯入「$name」($reason)';
  }

  @override
  String collectionsAlreadyImported(String name) {
    return '「$name」已在首頁時間軸中';
  }

  @override
  String collectionsImported(String name) {
    return '已將「$name」匯入首頁時間軸（可透過分頁列的齒輪確認）';
  }

  @override
  String get collectionsTileOpen => '查看';

  @override
  String get collectionsCreateNeedsAccount => '建立 RASQ 清單需要 RASQ 帳號';

  @override
  String get collectionsCreateTitle => '新增 RASQ 清單';

  @override
  String get collectionsListNameHint => '清單名稱';

  @override
  String get collectionsPublishSwitch => '公開';

  @override
  String get collectionsPublishSwitchSubtitle => '可從帳號頁面和分享連結查看。追蹤者查看時也會更新';

  @override
  String get collectionsCreateButton => '建立';

  @override
  String collectionsCreateFailed(String error) {
    return '無法建立：$error';
  }

  @override
  String get collectionsUseNeedsAccount => '使用 RASQ 清單需要 RASQ 帳號';

  @override
  String collectionsLoadListsFailed(String error) {
    return '無法載入清單：$error';
  }

  @override
  String get collectionsAddToListTitle => '加入 RASQ 清單';

  @override
  String collectionsAddToListSubtitlePublic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0 · 公開';
  }

  @override
  String collectionsAddToListSubtitlePrivate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0 · 不公開';
  }

  @override
  String get collectionsCreateNewList => '建立新清單';

  @override
  String collectionsAddedTo(String name) {
    return '已新增至「$name」';
  }

  @override
  String collectionsAlreadyIn(String name) {
    return '已在「$name」中';
  }

  @override
  String get composeTargetNormalTitle => '撰寫貼文';

  @override
  String get composeTargetReplyTitle => '回覆';

  @override
  String get composeTargetQuoteTitle => '引用';

  @override
  String get composeEmojiPickerTitle => '表情符號';

  @override
  String get composeEmojiPickerClose => '關閉';

  @override
  String get composePollRemoveTooltip => '刪除投票';

  @override
  String composePollChoiceHint(int index) {
    return '選項$index';
  }

  @override
  String get composePollChoiceDeleteTooltip => '刪除';

  @override
  String get composePollAddChoice => '新增選項';

  @override
  String get composePollTimed => '設定截止時間';

  @override
  String get composePollMultiple => '複選';

  @override
  String get composePollUnitDays => '天';

  @override
  String get composePollUnitHours => '小時';

  @override
  String get composePollUnitMinutes => '分鐘';

  @override
  String get composePollUnitSeconds => '秒';

  @override
  String get composeDraftsTitle => '草稿';

  @override
  String get composeDraftsCancel => '取消';

  @override
  String get composeDraftsDelete => '刪除';

  @override
  String get composeDraftsSaveAndClose => '儲存目前內容並關閉';

  @override
  String get composeDraftsOverwriteAndClose => '以目前內容覆寫儲存並關閉';

  @override
  String get composeDraftsSaveNewAndClose => '將目前內容存為新草稿並關閉';

  @override
  String get composeDraftsEmpty => '沒有草稿';

  @override
  String composeDraftsAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '附件 $count',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftsOpenNow => '編輯中';

  @override
  String get composeDraftsSelectOff => '取消選取';

  @override
  String get composeDraftsSelect => '選取';

  @override
  String composeDraftsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 項',
    );
    return '$_temp0';
  }

  @override
  String composeDraftTitleAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '（附件 $count 個）',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftTitleEmpty => '（無內文）';

  @override
  String get composeDraftTargetReply => '回覆';

  @override
  String get composeDraftTargetQuote => '引用';

  @override
  String get composeDraftTargetPost => '貼文';

  @override
  String get composeReactionAcceptanceAll => '全部';

  @override
  String get composeReactionAcceptanceLikeOnly => '僅限按讚';

  @override
  String get composeReactionAcceptanceLikeOnlyForRemote => '外部僅限按讚';

  @override
  String get composeReactionAcceptanceNonSensitiveOnly => '僅限非敏感';

  @override
  String
  get composeReactionAcceptanceNonSensitiveOnlyForLocalLikeOnlyForRemote =>
      '僅限非敏感&外部僅限按讚';

  @override
  String get composeEmojiResizeHandleSemantics => '調整大小控點';

  @override
  String get composeEmojiSectionHistory => '最近使用';

  @override
  String get composeEmojiSectionPrediction => '推薦';

  @override
  String get composeEmojiBundleEditTitle => '編輯組合包';

  @override
  String get composeEmojiBundleEditMessage => '組合包編輯功能即將推出。';

  @override
  String get composeEmojiSectionDefault => '預設';

  @override
  String get composeEmojiCustomEmpty => '沒有自訂表情符號';

  @override
  String get composeEmojiSectionServer => '伺服器';

  @override
  String get composeEmojiGenreOther => '其他';

  @override
  String composeEmojiGroupHeading(String name) {
    return '· $name';
  }

  @override
  String get composeEmojiSearchHint => '搜尋';

  @override
  String get composeEmojiStickersEmpty => '沒有可用的素材包（可從商店安裝）';

  @override
  String get composeEmojiSectionSearchResults => '搜尋結果';

  @override
  String get composeEmojiSearchNoHit => '找不到結果';

  @override
  String composeEmojiIndexProgress(int done, int total) {
    return '正在準備語意搜尋 $done / $total';
  }

  @override
  String get composeVisibilityHome => '首頁';

  @override
  String get composeVisibilityFollowers => '追蹤者';

  @override
  String get composeVisibilityPublic => '公開';

  @override
  String composeVisibilityTooltip(String label) {
    return '公開範圍：$label';
  }

  @override
  String get composeLocalOnlyOnTooltip => '不聯合（僅限此伺服器）';

  @override
  String get composeLocalOnlyOffTooltip => '聯合（點按改為不聯合）';

  @override
  String composeReactionAcceptanceTooltip(String label) {
    return '接受的回應：$label';
  }

  @override
  String get composeOn => '開';

  @override
  String get composeOff => '關';

  @override
  String composeTextPluginTooltip(String label, String state) {
    return '$label（$state · 長按進行設定）';
  }

  @override
  String get composeTextPluginHereTitle => '在此編輯器中開啟';

  @override
  String get composeTextPluginHereSubtitle => '將內文的變更傳給此外掛';

  @override
  String get composeTextPluginAutoTitle => '下次也自動開啟';

  @override
  String composeTextPluginAutoDefault(String state) {
    return '外掛預設（$state）';
  }

  @override
  String composeTextPluginAutoOverridden(String state) {
    return '已在設定中覆寫（預設為 $state）';
  }

  @override
  String get composeTextPluginResetDefault => '還原為外掛預設';

  @override
  String composeTextPluginCaption(String name) {
    return '$name · 文字處理';
  }

  @override
  String get composeHeaderPost => '發文';

  @override
  String get composeHeaderReply => '回覆';

  @override
  String get composeHeaderQuote => '引用';

  @override
  String get composeCloseOverwriteTitle => '要覆寫草稿嗎？';

  @override
  String get composeCloseSaveTitle => '要儲存為草稿嗎？';

  @override
  String get composeCloseOverwriteMessage => '將以目前內容覆寫正在編輯的草稿並關閉。';

  @override
  String get composeCloseSaveMessage => '將目前內容保留為草稿並關閉。';

  @override
  String get composeCloseOverwrite => '覆寫';

  @override
  String get composeCloseSaveNew => '另存新草稿';

  @override
  String get composeCloseSave => '儲存';

  @override
  String get composeCloseDiscard => '捨棄變更';

  @override
  String get composeCancel => '取消';

  @override
  String get composeMultiNormal => '一般發文';

  @override
  String get composeMultiLinked => '節點連動';

  @override
  String get composeRasqTarget => '發布到 RASQ';

  @override
  String get composeTargetMatchedTooltip => '符合發布目標節點的條件';

  @override
  String get composeTargetCustomize => '自訂發布目標';

  @override
  String get composeMultiSelectOff => '取消複選';

  @override
  String get composeMultiSelectOn => '複選模式';

  @override
  String get composeLinkedConfirmTitle => '確認連動發文';

  @override
  String get composeLinkedConfirmSame => '以相同內容連動發文';

  @override
  String get composeLinkedConfirmAlt => '以替代格式連動發文';

  @override
  String get composeLinkedConfirmPost => '以此內容發布';

  @override
  String get composeRasqNoServer => '尚未設定 RASQ 伺服器';

  @override
  String get composeRasqOverLimit => '超出了 RASQ 的上限';

  @override
  String get composeRasqTextOnlyTip => 'RASQ 的回覆僅限文字';

  @override
  String composePickImageFailed(String error) {
    return '無法選取圖片：$error';
  }

  @override
  String get composePickVideoLibrary => '圖庫中的影片';

  @override
  String get composePickVideoFile => '從檔案選取（影片 / 音訊）';

  @override
  String composePickNotMedia(String name) {
    return '不是影片 / 音訊檔案：$name';
  }

  @override
  String composePickMediaFailed(String error) {
    return '無法選取影片 / 音訊：$error';
  }

  @override
  String get composeRasqNotLoggedIn => '尚未登入 RASQ 帳號';

  @override
  String composeRasqMediaTooLarge(int mb) {
    return '發布到 RASQ 時，每個影片 / 音訊最大 $mb MB';
  }

  @override
  String get composeRasqReplyTextOnly => 'RASQ 的回覆僅限文字（無法加入附件 / 投票）';

  @override
  String composeRasqReplyMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ 的回覆最多 $count 個字',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '發布到 RASQ 時最多 $count 個附件',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '發布到 RASQ 時最多 $count 個字',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxPollChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '發布到 RASQ 時投票選項最多 $count 個',
    );
    return '$_temp0';
  }

  @override
  String get composeRasqPosted => '已發布到 RASQ';

  @override
  String get composeRasqReplyQuota => 'RASQ 的回覆最多 100 則。請刪除舊的回覆';

  @override
  String get composeRasqPostQuota => 'RASQ 的貼文最多 3 則。請刪除舊的貼文';

  @override
  String composeRasqPostFailed(String error) {
    return '無法發布到 RASQ：$error';
  }

  @override
  String get composePolicyConfirmTitle => '傳送前確認';

  @override
  String get composePolicyConfirmSend => '直接傳送';

  @override
  String get composePolicyConfirmEdit => '重新編輯';

  @override
  String get composeSending => '傳送中…';

  @override
  String composeModerationDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '審核延遲：還剩 $seconds 秒',
    );
    return '$_temp0';
  }

  @override
  String composeUploading(int index, int total) {
    return '正在上傳 $index/$total';
  }

  @override
  String composeLinkedFailed(String errors) {
    return '連動發文失敗：$errors（主貼文已發布）';
  }

  @override
  String composeSendFailed(String error) {
    return '傳送失敗：$error';
  }

  @override
  String composePostNoticeForAccount(String account, String message) {
    return '$account：$message';
  }

  @override
  String get composeDraftsButton => '草稿';

  @override
  String get composeDirectReplyNote => '回覆私訊貼文（僅對方可見）';

  @override
  String get composeChooseTargetTooltip => '選擇發文目標';

  @override
  String get composeCwHint => '內容警告..';

  @override
  String get composeCwRemoveTooltip => '移除內容警告';

  @override
  String get composeDmHint => '輸入訊息..';

  @override
  String get composeTextHint => '祝你有好事發生！';

  @override
  String composeHashtagUsers(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag  $count人',
    );
    return '$_temp0';
  }

  @override
  String get composeToolCamera => '相機';

  @override
  String get composeToolImage => '圖片';

  @override
  String get composeToolVideo => '影片 / 音訊';

  @override
  String get composeToolCw => '隱藏（CW）';

  @override
  String get composeToolPoll => '投票';

  @override
  String get composeToolEmoji => '表情符號';

  @override
  String get composeSendReply => '回覆';

  @override
  String get composeSend => '傳送';

  @override
  String get composeAttachmentRemove => '刪除';

  @override
  String get composeAttachmentEdit => '編輯';

  @override
  String get composeAttachmentUnsensitive => '取消敏感標記';

  @override
  String get composeAttachmentSensitive => '標記為敏感';

  @override
  String get composeMediaPickTypeLabel => '影片 / 音訊';

  @override
  String get composeMediaMotionVideoLabel => '製作成影片（在卡片中播放附帶的影片，有聲音）';

  @override
  String get composeMediaMotionAudioLabel => '製作成影片（卡片靜態圖像 + 附帶的音訊）';

  @override
  String composeMediaMotionAnimatedLabel(int fps, int seconds) {
    return '製作成影片（以每秒 $fps 格錄製動畫 $seconds 秒）';
  }

  @override
  String get composeMediaMotionVideoNote => '此貼文附帶影片。';

  @override
  String get composeMediaMotionAudioNote => '此貼文附帶音訊。';

  @override
  String get composeMediaMotionAnimatedNote => '此貼文包含動畫（GIF / 動態 MFM）。';

  @override
  String get composeMediaPostNotOnScreen => '貼文未顯示在螢幕上';

  @override
  String get composeMediaSourceFetchFailed => '無法取得原始檔案';

  @override
  String composeMediaFormatUnreadable(String ext) {
    return '此裝置無法讀取 $ext 格式（可作為靜態圖像貼上）';
  }

  @override
  String composeMediaSourceOpenFailed(String ext, int bytes) {
    return '無法開啟原始檔案（.$ext,$bytes 位元組）';
  }

  @override
  String get composeMediaTabMine => '我的貼文';

  @override
  String get composeMediaTabReacted => '回應';

  @override
  String get composeMediaTabFavorites => '書籤';

  @override
  String get composeMediaTabSearches => '最近的搜尋';

  @override
  String get composeMediaStyleThread => '串文';

  @override
  String get composeMediaStyleInline => '內嵌';

  @override
  String get composeMediaPostImageTitle => '新增貼文圖片';

  @override
  String get composeMediaCancel => '取消';

  @override
  String get composeMediaConfirm => '確定';

  @override
  String get composeMediaNoAccount => '沒有帳號';

  @override
  String get composeMediaSearchUnsupported => '此 SNS 不支援搜尋貼文';

  @override
  String composeMediaTabUnsupported(String tab) {
    return '此 SNS 不支援「$tab」';
  }

  @override
  String composeMediaFetchFailed(String error) {
    return '無法取得：$error';
  }

  @override
  String get composeMediaCaptureRetry => '請在所選貼文顯示於螢幕上時，再次點按「確定」';

  @override
  String composeMediaVideoFailed(String error) {
    return '無法製作成影片：$error';
  }

  @override
  String get composeMediaFilterHistoryHint => '篩選搜尋紀錄';

  @override
  String get composeMediaFilterListHint => '篩選列表';

  @override
  String get composeMediaFilterFromHistoryTooltip => '從最近的搜尋中填入';

  @override
  String get composeMediaStyleHeading => '外觀';

  @override
  String composeMediaSearchResultsTitle(String query) {
    return '「$query」的搜尋結果';
  }

  @override
  String get composeMediaSearchBack => '返回最近的搜尋';

  @override
  String composeMediaExcludedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '未顯示 $count 則限制了公開範圍的貼文。',
    );
    return '$_temp0';
  }

  @override
  String get composeMediaAsVideoOffNote => '關閉 = 該瞬間的靜態圖像';

  @override
  String get composeMediaExporting => '正在製作影片…';

  @override
  String get composeMediaHistoryEmpty => '沒有最近的搜尋（在搜尋首頁搜尋後會顯示在這裡）';

  @override
  String get composeMediaHistoryNoMatch => '沒有符合的搜尋';

  @override
  String get composeMediaPostsEmpty => '沒有貼文';

  @override
  String get composeMediaPostsNoMatch => '沒有符合的貼文（可透過「載入更多」繼續尋找）';

  @override
  String get composeMediaLoadMore => '載入更多';

  @override
  String get composeMfmFnX2 => '放大 2 倍';

  @override
  String get composeMfmFnX3 => '放大 3 倍';

  @override
  String get composeMfmFnX4 => '放大 4 倍';

  @override
  String get composeMfmFnSmall => '縮小顯示';

  @override
  String get composeMfmFnCenter => '置中';

  @override
  String get composeMfmFnBlur => '模糊（滑過 / 點按後顯示）';

  @override
  String get composeMfmFnRotate => '旋轉';

  @override
  String get composeMfmPropRotateDeg => '角度（預設 90）';

  @override
  String get composeMfmFnFlip => '翻轉';

  @override
  String get composeMfmPropFlipH => '左右';

  @override
  String get composeMfmPropFlipV => '上下';

  @override
  String get composeMfmFnFg => '文字顏色';

  @override
  String get composeMfmPropFgColor => '十六進位（例：ff0000）';

  @override
  String get composeMfmFnBg => '背景顏色';

  @override
  String get composeMfmPropBgColor => '十六進位（例：ffff00）';

  @override
  String get composeMfmFnShake => '震動';

  @override
  String get composeMfmPropShakeSpeed => '例：0.5s';

  @override
  String get composeMfmFnSpin => '旋轉動畫';

  @override
  String get composeMfmPropSpinSpeed => '例：1.5s';

  @override
  String get composeMfmPropSpinLeft => '反向旋轉';

  @override
  String get composeMfmPropSpinAlternate => '來回';

  @override
  String get composeMfmPropSpinX => '橫軸';

  @override
  String get composeMfmPropSpinY => '縱軸';

  @override
  String get composeMfmFnJump => '跳躍';

  @override
  String get composeMfmPropJumpSpeed => '例：0.75s';

  @override
  String get composeMfmFnBounce => '彈跳';

  @override
  String get composeMfmPropBounceSpeed => '例：0.75s';

  @override
  String get composeMfmFnRainbow => '彩虹色';

  @override
  String get composeMfmPropRainbowSpeed => '例：1s';

  @override
  String get composeMfmFnTwitch => '抽動';

  @override
  String get composeMfmPropTwitchSpeed => '例：0.5s';

  @override
  String get composeMfmFnJelly => '果凍';

  @override
  String get composeMfmPropJellySpeed => '例：1s';

  @override
  String get composeMfmFnTada => '噹噹';

  @override
  String get composeMfmPropTadaSpeed => '例：1s';

  @override
  String get composeMfmFnPlain => '停用裝飾';

  @override
  String get composeMfmFnFont => '變更字型';

  @override
  String get composeMfmPropFontSerif => '襯線體（serif）';

  @override
  String get composeMfmPropFontMonospace => '等寬（monospace）';

  @override
  String get composeMfmPropFontCursive => '手寫體（cursive）';

  @override
  String get composeMfmPropFontFantasy => '裝飾體（fantasy）';

  @override
  String get composeMfmFnPosition => '移動位置';

  @override
  String get composeMfmPropPositionX => '橫向（以字級為單位，例：0.5）';

  @override
  String get composeMfmPropPositionY => '縱向（以字級為單位，例：-1）';

  @override
  String get composeMfmFnScale => '放大/縮小（最大 5 倍）';

  @override
  String get composeMfmPropScaleX => '橫向倍率（例：0.5）';

  @override
  String get composeMfmPropScaleY => '縱向倍率（例：1.5）';

  @override
  String get composeMfmFnBorder => '框線';

  @override
  String get composeMfmPropBorderStyle => '線條樣式（solid / dashed / dotted 等）';

  @override
  String get composeMfmPropBorderWidth => '粗細（px，預設 1）';

  @override
  String get composeMfmPropBorderColor => '十六進位（預設為強調色）';

  @override
  String get composeMfmPropBorderRadius => '圓角（px）';

  @override
  String get composeMfmPropBorderNoclip => '不裁切超出部分';

  @override
  String get composeMfmFnRuby => '注音（以「內文 讀音」的格式書寫）';

  @override
  String get composeMfmSampleRuby => '漢字 ㄏㄢˋㄗˋ';

  @override
  String get composeMfmFnUnixtime => '將 UNIX 時間（秒）顯示為日期時間';

  @override
  String get composeMfmFnSparkle => '閃閃發亮';

  @override
  String get composeMfmPropDelay => '延遲開始（例：0.5s）';

  @override
  String get composeMfmSearchButton => '搜尋';

  @override
  String get composeMfmMarkdownBoldName => '粗體';

  @override
  String get composeMfmMarkdownBoldDescription => '顯示為 **粗體**';

  @override
  String get composeMfmMarkdownItalicName => '斜體';

  @override
  String get composeMfmMarkdownItalicDescription => '顯示為 *斜體*';

  @override
  String get composeMfmMarkdownStrikeName => '刪除線';

  @override
  String get composeMfmMarkdownStrikeDescription => '顯示為 ~~刪除線~~';

  @override
  String get composeMfmMarkdownInlineCodeName => '行內程式碼';

  @override
  String get composeMfmMarkdownInlineCodeDescription => '顯示為 `程式碼`';

  @override
  String get composeMfmMarkdownCodeBlockName => '程式碼區塊';

  @override
  String get composeMfmMarkdownCodeBlockDescription => '將多行程式碼顯示在框中';

  @override
  String get composeMfmMarkdownHeadingName => '標題';

  @override
  String get composeMfmMarkdownHeadingDescription => '在行首加上 #';

  @override
  String get composeMfmMarkdownLinkName => '連結';

  @override
  String get composeMfmMarkdownLinkDescription => '[顯示名稱](URL) 的格式';

  @override
  String get composeMfmClose => '關閉';

  @override
  String get composeMfmSample => '範例';

  @override
  String composeMfmSampleWithEmoji(String emoji) {
    return '範例 $emoji';
  }

  @override
  String get composeMfmBackTooltip => '返回列表';

  @override
  String get composeMfmApply => '確定';

  @override
  String get composeMfmNoProps => '此函式沒有屬性。';

  @override
  String get composePolicyTypeSexual => '色情內容';

  @override
  String get composePolicyTypeViolence => '暴力 / 威脅';

  @override
  String get composePolicyTypeSelfHarm => '自傷 / 自殺';

  @override
  String get composePolicyTypeHarassment => '辱罵 / 騷擾';

  @override
  String get composePolicyTypePersonalInfo => '個人資料（電話號碼、電子郵件地址、住址等）';

  @override
  String get composePolicyTypeLink => '外部連結';

  @override
  String get composePolicyTypeMedia => '圖片 / 影片';

  @override
  String get composePolicyTypeStimulus => '過激言詞';

  @override
  String get composePolicyTypeTopic => '指定話題';

  @override
  String get composePolicyWhoGuardian => '監護人設定';

  @override
  String get composePolicyWhoSanction => '帳號限制';

  @override
  String composePolicyBlockedMediaUnmeasured(String who) {
    return '由於$who，無法傳送圖片 / 影片（此裝置無法檢查附件）。請移除附件';
  }

  @override
  String composePolicyBlockedUnmeasured(String who, String label) {
    return '由於$who，目前無法傳送（此裝置無法檢查「$label」）';
  }

  @override
  String composePolicyBlocked(String who, String label) {
    return '由於$who，無法傳送涉及「$label」的內容。請修改';
  }

  @override
  String composePolicyWarn(String label, String who) {
    return '可能涉及「$label」（$who）。仍要傳送嗎？';
  }

  @override
  String customShareAddToRoom(String room) {
    return '新增到「$room」';
  }

  @override
  String customShareProposeToRoom(String room) {
    return '在「$room」中提議';
  }

  @override
  String get customSharePlaceOnProfile => '放到個人檔案';

  @override
  String get customShareInviteBySwing => '透過 Swing 邀請（多人共用）';

  @override
  String get customShareInstallToShare => '安裝後即可透過個人檔案或邀請分享';

  @override
  String customAddedToRoom(String name) {
    return '已將「$name」新增到房間';
  }

  @override
  String customAddToRoomFailed(String error) {
    return '無法新增：$error';
  }

  @override
  String customShareProposedToRoom(String name) {
    return '已在房間中提議「$name」';
  }

  @override
  String get customSharePlacedOnProfile => '已放到個人檔案';

  @override
  String customPlaceFailed(String error) {
    return '無法放置：$error';
  }

  @override
  String customInvitedBySwingNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '已透過 Swing 邀請(已透過 RASQ 通知 $_temp0)';
  }

  @override
  String get customInvitedBySwing => '已透過 Swing 邀請';

  @override
  String get customInviteTitle => '透過 Swing 邀請';

  @override
  String customInviteSendFailed(String error) {
    return '無法傳送：$error';
  }

  @override
  String customInviteHeading(String title) {
    return '邀請加入「$title」';
  }

  @override
  String get customInviteIntroOwnPage => '透過 Swing 送達。看到的人會一起進入你的頁面。';

  @override
  String get customInviteIntroCurrentPage => '透過 Swing 送達。看到的人會一起進入目前開啟的頁面。';

  @override
  String get customInviteHelp =>
      '傳送對象：點按 = 送達 Swing · 連續點按兩次 = 同時傳送 RASQ 通知 🔔';

  @override
  String get customInviteFollowers => '追蹤者';

  @override
  String get customInviteNoLists => '建立 RASQ 清單後，也可以邀請清單中的人';

  @override
  String get customInviteTextHint => '附言（選填）';

  @override
  String get customInviteTtl => '消失時間';

  @override
  String customInviteTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小時',
    );
    return '$_temp0';
  }

  @override
  String get customInviteSendWithNotify => '透過 Swing 邀請（同時傳送通知）';

  @override
  String get customInviteErrorVersionNotAvailable =>
      '目前連線的 RASQ 伺服器商店未發布此外掛（沒有通過審核的版本）。App 內建的範例無法多人共用';

  @override
  String get customInviteErrorNotShared => '這不是多人共用的外掛';

  @override
  String get customInviteErrorSessionNotShareable => '此頁面的工作階段無法透過 Swing 邀請';

  @override
  String get customInviteErrorSwingLimit => '同時最多只能發出 20 個 Swing';

  @override
  String customInviteTargetWithNotify(String label) {
    return '$label（同時傳送通知）';
  }

  @override
  String get customInviteTargetHint => '點按以選取 / 取消。連續點按兩次會同時傳送通知';

  @override
  String get customProfileLimit => '頁面最多可放置 8 個';

  @override
  String get customProfileSideloadReplace => '重新上傳（新版本）';

  @override
  String get customProfileSideloadRemove => '從頁面移除';

  @override
  String customProfileRemoveFailed(String error) {
    return '無法移除：$error';
  }

  @override
  String customLoadFailed(String error) {
    return '無法載入：$error';
  }

  @override
  String get customProfileEmptyMine =>
      '點按「+ 新增」可放置 Markdown 頁面或自訂外掛。訪客可以從這裡開啟。';

  @override
  String get customProfileEmpty => '還沒有頁面。';

  @override
  String get customProfileSharedNotStarted => '多人共用（尚未開始）';

  @override
  String get customProfileShared => '多人共用';

  @override
  String get customSolo => '單人使用';

  @override
  String customProfileHostPage(String title) {
    return '$title 的主持人頁面';
  }

  @override
  String get customProfileHostPageSubtitle => '僅對你顯示';

  @override
  String get customProfileMdPageWithDraft => '頁面 · 有未完成的草稿';

  @override
  String get customProfileMdPage => '頁面';

  @override
  String get customProfileUntitled => '（無標題）';

  @override
  String get customProfileDraft => '草稿（僅限此裝置）';

  @override
  String customProfileSideloadSubtitle(String version) {
    return '自製外掛 · 受限模式 · v$version';
  }

  @override
  String get customMenu => '選單';

  @override
  String get customProfileAdd => '新增';

  @override
  String get customProfileLoginToPlace => '登入 RASQ 帳號後即可放置';

  @override
  String customProfileSideloadPlaced(String name) {
    return '已放置「$name」（在訪客的裝置上以受限模式執行）';
  }

  @override
  String get customProfileSideloadErrorNotProfilePage =>
      'RASQ 頁面上只能放置具有個人檔案介面的單人使用頁面型外掛';

  @override
  String get customProfileSideloadErrorLimit => '自製外掛最多 4 個';

  @override
  String get customProfileSideloadErrorInvalidPackage =>
      '無法讀取套件檔（.rspkg / .rasqpkg）';

  @override
  String get customClose => '關閉';

  @override
  String get customProfileAddTitle => '新增頁面';

  @override
  String get customProfileAddMd => '撰寫 Markdown 頁面';

  @override
  String get customProfileAddMdSubtitle =>
      '草稿儲存在此裝置上，點按「發布」後公開。MFM 使用類似 HTML 的標籤';

  @override
  String get customProfileAddSideload => '放置自製外掛（.rspkg / .rasqpkg）';

  @override
  String get customProfileAddSideloadSubtitle =>
      '未經審核的外掛。在訪客的裝置上以受限模式（無網路通訊等）執行';

  @override
  String get customProfileAddStoreSection => '商店中的自訂外掛';

  @override
  String get customProfileAddStoreEmpty => '尚未安裝可放到頁面上的自訂外掛';

  @override
  String get customProfileAddStorePlaced => '已放置（點按以移除）';

  @override
  String get customProfileAddStoreTapToPlace => '點按以放置';

  @override
  String get customProfileAddStoreHasHostPage => '有主持人頁面';

  @override
  String get customListSeparator => ' · ';

  @override
  String customProfileChangeFailed(String error) {
    return '無法變更：$error';
  }

  @override
  String get customSearchStore => '在商店中尋找';

  @override
  String get customPluginsTitle => '自訂外掛';

  @override
  String get customPluginsJoinByCode => '使用邀請碼加入';

  @override
  String get customPluginsInviteCode => '邀請碼';

  @override
  String get customPluginsJoin => '加入';

  @override
  String get customPluginsInstalled => '已安裝';

  @override
  String get customPluginsEmpty => '還沒有。可以在商店的「自訂」中尋找。';

  @override
  String get customPluginsShared => '可多人共用';

  @override
  String get customPluginsProfile => '個人檔案';

  @override
  String get customPluginsSearchStore => '在商店中尋找自訂外掛';

  @override
  String get customPluginsInviteNotFound => '找不到此邀請碼對應的工作階段（可能已被關閉）';

  @override
  String get customPluginsInviteTitle => '邀請';

  @override
  String get customPluginsJoinFailed => '無法加入';

  @override
  String get customPageLoadFailed => '無法載入';

  @override
  String customPageNotPagePlugin(String name) {
    return '$name 不是頁面型外掛';
  }

  @override
  String customPageSoloPlugin(String name) {
    return '$name 是單人使用的外掛（無法多人共用）';
  }

  @override
  String customPageJoinFailed(String error) {
    return '無法加入工作階段：$error';
  }

  @override
  String get customPageNoPage => '外掛沒有傳回頁面';

  @override
  String customPageWrongSession(String name) {
    return '這不是 $name 的工作階段';
  }

  @override
  String customPageLeftWrongSession(String name) {
    return '由於這不是 $name 的工作階段，已退出';
  }

  @override
  String customPageDisconnectedWithError(String error) {
    return '連線已中斷：$error';
  }

  @override
  String get customPageDisconnected => '連線已中斷';

  @override
  String get customPageError => '錯誤';

  @override
  String get customPageMenuInvite => '邀請（透過 Swing 傳送）';

  @override
  String get customPageMenuCopyCode => '複製邀請碼';

  @override
  String get customPageMenuCopyLink => '複製邀請連結';

  @override
  String customPageMenuParticipants(int count) {
    return '參與者（$count）';
  }

  @override
  String get customPageMenuCloseSession => '關閉工作階段';

  @override
  String get customPageViewInStore => '在商店中查看';

  @override
  String customPageCodeCopied(String code) {
    return '已複製邀請碼 $code';
  }

  @override
  String get customPageLinkCopied => '已複製邀請連結';

  @override
  String get customPageParticipants => '參與者';

  @override
  String get customPageCloseConfirmTitle => '要關閉工作階段嗎？';

  @override
  String get customPageCloseConfirmMessage => '所有參與者頁面上的共用值都將停止更新。';

  @override
  String get customCancel => '取消';

  @override
  String customPageCloseFailed(String error) {
    return '無法關閉：$error';
  }

  @override
  String get customPageClosedBanner => '此工作階段已關閉（共用值不會再變化）';

  @override
  String get customPageConsentBody => '無需安裝，僅在開啟此頁面期間執行（關閉後即刪除）。';

  @override
  String get customPageConsentPermissions => '使用的權限';

  @override
  String get customPageConsentAccept => '使用';

  @override
  String get customPageConsentDecline => '不用了';

  @override
  String get customPageNotInstalled => '未安裝';

  @override
  String get customPageNotInstalledHint => '從商店安裝後即可開啟';

  @override
  String get customPageOpenFailed => '無法開啟';

  @override
  String get customClientHostOnly => '只有主持人可以部署';

  @override
  String get customClientSessionClosed => '工作階段已關閉';

  @override
  String get customClientNoToken => '沒有 RASQ 帳號的權杖';

  @override
  String customAstellWaitingApproval(String name) {
    return '「$name」正在等待主持人核准';
  }

  @override
  String customAstellApproveTitle(String name) {
    return '要在此房間中使用「$name」嗎？';
  }

  @override
  String customAstellApproveMessage(String name) {
    return '這是 $name 的提議。核准後，房間內的所有人都可以開啟（未安裝的人會在開啟時暫時載入）。';
  }

  @override
  String get customAstellApprove => '核准';

  @override
  String customAstellProposed(String name) {
    return '已提議「$name」（主持人核准後即可使用）';
  }

  @override
  String get customAstellEmptyHost => '此房間中還沒有執行中的外掛。可以透過下方的「新增外掛」新增。';

  @override
  String get customAstellEmptyMember => '此房間中還沒有執行中的外掛。可以透過「提議外掛」請主持人新增。';

  @override
  String customAstellInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人正在使用',
    );
    return '$_temp0';
  }

  @override
  String customAstellInUseAddedBy(int count, String handle) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人正在使用',
    );
    return '$_temp0 · 由 @$handle 新增';
  }

  @override
  String get customAstellOpen => '開啟';

  @override
  String get customAstellRemove => '從房間移除';

  @override
  String get customAstellAdd => '新增外掛';

  @override
  String get customAstellPropose => '提議外掛';

  @override
  String get devGrantDebugAll => '偵錯版本：全部權限';

  @override
  String get devUrlInvalid => '請輸入 http(s) 的 URL';

  @override
  String devUrlLoadFailed(String error) {
    return '無法從 URL 讀取：$error';
  }

  @override
  String devBoundaryTimelineFailed(String error) {
    return '邊界 TL：$error';
  }

  @override
  String devAssetLoadFailed(String error) {
    return '載入資源失敗：$error';
  }

  @override
  String devPkgLoaded(
    String rootId,
    String version,
    int children,
    String target,
  ) {
    return '.rasqpkg：已載入 $rootId $version（子 $children）→ $target。';
  }

  @override
  String devPkgSigned(String fingerprint) {
    return '開發者金鑰簽章 OK（指紋 $fingerprint）。未通過商店審核。';
  }

  @override
  String get devPkgUnsigned => '未簽章（沒有 .sig.json）。無法確認來源。';

  @override
  String get devPkgSlotFull => '註冊到插槽後為完整功能（由自己的金鑰簽章）';

  @override
  String get devPkgSlotRestricted =>
      '註冊到插槽後為受限模式（非自己的金鑰簽章，因此網路 / GPU / storage.unsafe / interstitial·system 的 FOW / 分享·編輯器·靜音·開啟 URL 的函式均關閉）';

  @override
  String devPathLoadFailed(String path, String error) {
    return '載入 $path 失敗（請使用絕對路徑或以 ~/ 開頭的路徑）：$error';
  }

  @override
  String get devFowClose => '關閉';

  @override
  String get devFowSemantics => '外掛 FOW';

  @override
  String get devRegisterNeedsMisskey => '實際註冊需要使用 Misskey 帳號登入';

  @override
  String get devTitle => 'WASM 外掛測試（dev）';

  @override
  String get devHostHint => '實例（例：misskey.io）';

  @override
  String get devFetchTimeline => '取得 TL';

  @override
  String get devBoundaryTimeline => '邊界 TL';

  @override
  String get devPathHint => '從 .wasm 路徑匯入（留空 = 內建資源）';

  @override
  String get devLoad => '載入';

  @override
  String get devRegisterReal => '實際註冊';

  @override
  String get devUrlHint => '從 URL 讀取（審核的臨時匯入連結）';

  @override
  String get devUrlLoad => '從 URL 讀取';

  @override
  String get devOpenedFromLink => '已從連結開啟。請確認來源後再點「從 URL 讀取」（審核中的版本將以受限模式執行）。';

  @override
  String devParentInstalled(String id, String version) {
    return '父（基礎）外掛：$id $version（已安裝）';
  }

  @override
  String devParentMissing(String id, String version) {
    return '父（基礎）外掛：$id $version — 請先安裝';
  }

  @override
  String get devOpenInStore => '在商店中開啟';

  @override
  String devGrantDebugNote(String grant, String hint) {
    return '$grant（release 版本依等級限制：$hint）';
  }

  @override
  String devGrantMode(String mode, String hint) {
    return '此畫面：$mode — $hint';
  }

  @override
  String get devModeFull => '完整功能';

  @override
  String get devModeBundled => '完整功能（App 內建）';

  @override
  String get devModeRestricted => '受限模式';

  @override
  String get devModeSwing => '受限模式（Swing）';

  @override
  String get devSlotRegister => '註冊到插槽';

  @override
  String devSlotRegistered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已註冊：$count',
    );
    return '$_temp0';
  }

  @override
  String devSlotModeHint(String hint) {
    return '插槽等級：完整 / 受限 — $hint';
  }

  @override
  String get devSlotReviewed => '已審核';

  @override
  String get devSlotUnregister => '解除';

  @override
  String get devBoundaryHeader => '邊界工作階段：sns.timeline → Post 線 → PostRow';

  @override
  String get devBoundaryClose => '關閉';

  @override
  String devActionFailed(String action, String error) {
    return 'performAction($action) 失敗：$error';
  }

  @override
  String devReviewImportTooLarge(int maxBytes) {
    return '大小無效（超過 $maxBytes 位元組）';
  }

  @override
  String get devReviewImportExpired => '連結已過期或不正確。請在審核畫面重新建立';

  @override
  String devReviewImportHttpFailed(int status) {
    return '取得失敗（HTTP $status）';
  }

  @override
  String devReviewImportBadSize(int bytes) {
    return '大小無效（$bytes 位元組）';
  }

  @override
  String get dmRoomSettings => '此私訊的設定';

  @override
  String get dmRetry => '重新載入';

  @override
  String get dmRoomEmpty => '還沒有訊息';

  @override
  String get dmTabAll => '全部';

  @override
  String get dmTabFollowing => '追蹤中';

  @override
  String get dmSettings => '私訊設定';

  @override
  String get dmFollowingEmpty => '沒有與追蹤對象的私訊';

  @override
  String get dmNewMessage => '新訊息';

  @override
  String get dmUserSearchHint => '依使用者名稱搜尋..';

  @override
  String get dmUserSearchIntro => '搜尋要傳送私訊的對象。';

  @override
  String get dmUserNotFound => '找不到';

  @override
  String get dmEmptyTitle => '沒有私訊';

  @override
  String get dmEmptyHint => '私訊貼文（限定公開）會顯示在這裡';

  @override
  String get dmYouPrefix => '你：';

  @override
  String get dmMediaPlaceholder => '[媒體]';

  @override
  String get homeCreateMissingAccount => '（不存在的帳號）';

  @override
  String get homeCreatePost => '貼文';

  @override
  String get homeCreateNone => '無';

  @override
  String homeCreateNeedsRasqAccount(String label) {
    return '$label需要 RASQ 帳號';
  }

  @override
  String get homeCreateAstellBlocked => 'ASTell 已被監護設定停用';

  @override
  String get homeCreateAccountGone => '此帳號已不存在';

  @override
  String get homeCreate => '建立';

  @override
  String get homeClose => '關閉';

  @override
  String get homeFabEditorTitle => '＋ 按鈕';

  @override
  String homeFabEditorHelp(int count, int max) {
    return '將下方的按鈕拖入框中即可加入（框之間可互換，拖回下方一列即可移除）。內側最多 3 個，外側最多 4 個 · $count / $max';
  }

  @override
  String get homeHeaderCollapse => '收合頁首';

  @override
  String get homeTimelineTemp => '暫時變更時間軸';

  @override
  String get homeTimelineSettings => '時間軸設定';

  @override
  String get homeTabRecommended => '推薦';

  @override
  String get homeEmpty => '沒有貼文';

  @override
  String get homePullToRefresh => '下拉重新整理';

  @override
  String get homeLoadNewer => '載入新貼文';

  @override
  String get homeNewPostsPill => '新貼文';

  @override
  String get homeNewPostsPillSemantics => '查看新貼文';

  @override
  String get homeLoadingNewer => '正在重新整理…';

  @override
  String get homeLoadMoreFailed => '載入失敗。重試';

  @override
  String get homeLoadMore => '載入更多';

  @override
  String get homeLoadingMore => '正在載入…';

  @override
  String get homeReload => '重新載入';

  @override
  String homeSwingOf(String name) {
    return '$name 的 Swing';
  }

  @override
  String homeSwingOfSeen(String name) {
    return '$name 的 Swing（已看完）';
  }

  @override
  String homeMySwingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個',
    );
    return '我的 Swing（$_temp0）';
  }

  @override
  String get homeMySwing => '我的 Swing';

  @override
  String get homeLiveNoToken => '沒有 RASQ 帳號的權杖';

  @override
  String homePostAttachmentFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個附件',
    );
    return '$_temp0';
  }

  @override
  String get homePostAttachmentLink => '1 個附加連結';

  @override
  String get homePostShare => '分享';

  @override
  String get homePostSelectAccount => '選擇帳號';

  @override
  String get homePostLike => '讚';

  @override
  String get homePostReaction => '回應';

  @override
  String homePostRepostVia(String handle, String instance) {
    return '（使用 @$handle@$instance）';
  }

  @override
  String get homePostUndoRepost => '取消轉貼';

  @override
  String homePostCw(String cw) {
    return '【CW：$cw】';
  }

  @override
  String homePostAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個附件',
    );
    return '$_temp0';
  }

  @override
  String get homeActionReply => '回覆';

  @override
  String get homeActionRebroad => '轉播';

  @override
  String get homeActionQueue => '佇列';

  @override
  String get homeEditorCropRotate => '裁切 / 旋轉';

  @override
  String get homeEditorPaint => '繪圖';

  @override
  String get homeEditorText => '文字';

  @override
  String get homeEditorPost => '貼文';

  @override
  String get homeEditorMedia => '媒體';

  @override
  String get homeEditorSticker => '貼圖';

  @override
  String get homeEditorEmoji => '表情符號';

  @override
  String get homeEditorFilter => '濾鏡';

  @override
  String get homeEditorBlur => '模糊';

  @override
  String get homeEditorTune => '調整';

  @override
  String get homeActionAutoOn => '下次也自動開啟';

  @override
  String get homeActionAutoOff => '之後也自動關閉';

  @override
  String get homeActionAutoReset => '還原為外掛預設';

  @override
  String get homeChildSafeWindowTab => '監護時段';

  @override
  String get homeCancel => '取消';

  @override
  String get homeBarPost => '貼文操作列';

  @override
  String get homeBarViewer => '全螢幕操作列';

  @override
  String get homeBarEditorImage => '編輯畫面列（圖片）';

  @override
  String get homeBarEditorVideo => '編輯畫面列（影片 / 音訊）';

  @override
  String get homeBarEditorSvg => '編輯畫面列（SVG）';

  @override
  String get homeBarRasqViewer => '全螢幕操作列（Swing）';

  @override
  String get homeBarAstell => 'ASTell 房間下排';

  @override
  String get homeBarEditAstellTitle => '編輯房間按鈕';

  @override
  String get homeBarEditTitle => '編輯操作列';

  @override
  String get homeBarSearchPlugins => '搜尋外掛';

  @override
  String get homeBarSearchPluginButtons => '搜尋外掛按鈕';

  @override
  String homeBarSearchSubtitle(String source, String detail) {
    return '$source · $detail';
  }

  @override
  String get homeBarBuiltinEditor => '內建編輯';

  @override
  String get homeBarRasqActions => 'RASQ 操作';

  @override
  String get homeBarAstellButtons => 'ASTell 按鈕';

  @override
  String get homeBarSnsActions => 'SNS 操作';

  @override
  String get homeBarViewerTogglePlugin => '全螢幕顯示外掛（ON / OFF 按鈕）';

  @override
  String get homeBarAstellPlugin => 'ASTell 外掛（點擊開啟該外掛）';

  @override
  String homeBarPluginTags(String tags) {
    return '標籤：$tags';
  }

  @override
  String get homeBarManualPlacement => ' · 手動放置';

  @override
  String get homeBarAllGenres => '全部';

  @override
  String get homeBarSearchHint => '按鈕名稱 / 外掛名稱 / 標籤';

  @override
  String get homeBarSearchEmptyAstell => '沒有可加入的按鈕。可以從商店加入外掛';

  @override
  String get homeBarSearchEmpty => '沒有可放在這裡的外掛。可以從商店加入';

  @override
  String get homeBarSearchEmptyEditorDetail => '沒有宣告 composer.media 的外掛（從商店加入）';

  @override
  String get homeBarSearchEmptyAstellDetail =>
      '沒有隱藏的按鈕 / ASTell 外掛（astell.action）（從商店加入外掛）';

  @override
  String get homeBarSearchEmptyViewerDetail =>
      '沒有全螢幕顯示外掛 / 宣告 post.action 的外掛（從商店加入）';

  @override
  String get homeBarSearchEmptyPostDetail => '沒有宣告 post.action 的外掛（從商店加入）';

  @override
  String get homeBarSearchNoHits => '找不到';

  @override
  String get homeBarDetailTitle => '操作詳情';

  @override
  String get homeBarDetailUnknownDeveloper => '提供者不明';

  @override
  String homeBarDetailStats(String rating, int downloads) {
    return '★$rating · $downloads 次下載';
  }

  @override
  String get homeBarDetailAction => '操作';

  @override
  String get homeBarDetailSlot => '插槽（類型）';

  @override
  String get homeBarDetailConfirm => '確認';

  @override
  String get homeBarDetailAutomation => '自動化';

  @override
  String get homeBarDetailTags => '標籤';

  @override
  String get homeBarIconSearchHint => '依圖示名稱搜尋（例：star, bolt）';

  @override
  String get homeBarBundleTitle => '組合設定';

  @override
  String get homeBarBundleDissolved => '已解除';

  @override
  String get homeBarPlugin => '外掛';

  @override
  String homeBarBundleAstellMember(String label) {
    return '房間下排按鈕（$label）';
  }

  @override
  String homeBarBundleSnsMember(String genre) {
    return 'SNS 外掛提供的操作（$genre）';
  }

  @override
  String get homeBarBundleName => '清單名稱';

  @override
  String get homeBarBundleIcon => '圖示';

  @override
  String get homeBarBundlePhoto => '照片';

  @override
  String get homeBarBundlePhotoFailed => '無法使用照片';

  @override
  String get homeBarBundleMembers => '成員';

  @override
  String get homeBarMenuDetail => '詳情';

  @override
  String get homeBarBundleRemoveMember => '從組合中移除';

  @override
  String get homeBarDissolveList => '解除清單';

  @override
  String get homeBarMemberMenu => '成員操作';

  @override
  String get homeBarRasqAccount => 'RASQ 帳號';

  @override
  String get homeBarHelpAstell =>
      '點 (…) 或按右鍵開啟選單。長按可排序，疊到其他圖示上即可合併。點 (+) 加入按鈕。';

  @override
  String get homeBarHelp => '點 (…) 或按右鍵開啟選單。長按可排序，疊到其他圖示上即可合併。';

  @override
  String get homeBarHelpAstellDetail =>
      '(…) / shift + 點擊 / 右鍵開啟選單（隱藏 / 組合）。長按拖曳可排序，在其他圖示上放開即可組合。(+) 可加入隱藏的按鈕或 ASTell 外掛。寬度不夠時，從開頭顯示放得下的部分和最後一個（輸入欄旁），其餘放入房間的齒輪選單。';

  @override
  String get homeBarHelpDetail =>
      '(…) / shift + 點擊 / 右鍵開啟選單。長按拖曳可排序，在其他圖示上放開即可組合。已宣告的外掛按鈕和組合門檻在 設定 → SNS 外掛 →「外掛按鈕」。';

  @override
  String get homeBarRasqBuiltinEditor => 'RASQ（內建編輯）';

  @override
  String get homeBarNewBundleName => '我的清單';

  @override
  String get homeBarMenuMakeList => '轉為操作清單';

  @override
  String get homeBarMenuHide => '隱藏';

  @override
  String get homeBarMenuDelete => '刪除';

  @override
  String get homeBarMenuListSettings => '操作清單設定';

  @override
  String get homeBarMenuPinList => '設為固定清單';

  @override
  String get homeBarAddButton => '加入按鈕';

  @override
  String get homeBarNoHidden => '沒有隱藏的按鈕';

  @override
  String get homeBarHiddenLabel => '已隱藏（點擊顯示）：';

  @override
  String homeBarShowHidden(String label) {
    return '顯示 $label';
  }

  @override
  String get homeBarResetOrder => '恢復預設排列';

  @override
  String get languageSelfName => '繁體中文';

  @override
  String get languageSettingsTitle => '語言';

  @override
  String get languageSettingsRowSubtitle => 'App 的顯示語言';

  @override
  String get languageSettingsCaption => '選擇 App 文字的語言。若不支援裝置的語言，將以日文顯示。';

  @override
  String get languageSettingsCaptionDetail =>
      '選擇 App 文字的語言。「跟隨系統」會依照裝置的語言設定，不支援的語言將使用日文。所選語言會儲存在此裝置上，若已登入 RASQ 帳號，也會告知 ORGATE（電子郵件與通知的語言，D-484）。';

  @override
  String get languageSettingsSystem => '跟隨系統';

  @override
  String languageSettingsSystemCurrent(String language) {
    return '目前為 $language';
  }

  @override
  String get languageSettingsListHeader => '顯示語言';

  @override
  String get listsTitle => '清單';

  @override
  String get listsTabAllLabel => '全部';

  @override
  String get listsSearchHint => '搜尋清單和便籤';

  @override
  String get listsShowPrivateClips => '顯示非公開便籤';

  @override
  String get listsImportTitle => '匯入清單';

  @override
  String get listsCreateTitle => '建立清單';

  @override
  String listsCreateAccountList(String account) {
    return '$account 的清單';
  }

  @override
  String get listsRasqCrossSns => 'RASQ 清單（跨 SNS）';

  @override
  String get listsCreateConfirm => '建立';

  @override
  String get listsNameHint => '清單名稱';

  @override
  String listsCreated(String name) {
    return '已建立「$name」';
  }

  @override
  String listsCreateUnsupported(String sns) {
    return '無法在 $sns 上建立清單';
  }

  @override
  String listsCreateFailed(String error) {
    return '無法建立清單：$error';
  }

  @override
  String get listsEmpty => '沒有清單';

  @override
  String get listsNoHits => '找不到';

  @override
  String get listsEmptyHint => '點擊 ＋ 可建立清單';

  @override
  String get listsRasqCreateTitle => '新增 RASQ 清單';

  @override
  String get listsRasqCreateSubtitle =>
      '將 Misskey / Mastodon / Bluesky 的人放進一個清單';

  @override
  String listsSwitchedAccount(String account) {
    return '已切換到 $account';
  }

  @override
  String get listsSectionClips => '便籤';

  @override
  String get listsSectionLists => '清單';

  @override
  String get listsSectionFeeds => '自訂動態';

  @override
  String listsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位使用者',
    );
    return '$_temp0';
  }

  @override
  String listsClipNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$_temp0';
  }

  @override
  String get listsClipKindHost => 'RASQ（跨 SNS）';

  @override
  String get listsClipKindPrivate => '非公開便籤';

  @override
  String get listsClipKindPublic => '便籤';

  @override
  String get listsSeparator => ' · ';

  @override
  String get listsFeedUnsave => '取消儲存';

  @override
  String get listsFeedSave => '儲存動態';

  @override
  String get listsFeedUnsaveFailed => '無法取消儲存';

  @override
  String get listsFeedSaveFailed => '無法儲存';

  @override
  String get listsFeedSaveUnsupported => '此 SNS 不支援儲存動態';

  @override
  String get listsNotLoggedIn => '未登入';

  @override
  String listsFeedAlreadyImported(String name) {
    return '「$name」已在首頁時間軸中';
  }

  @override
  String listsFeedImported(String name) {
    return '已將「$name」匯入首頁時間軸（可透過分頁列的齒輪確認）';
  }

  @override
  String get listsTabUsers => '使用者';

  @override
  String get listsTabPosts => '貼文';

  @override
  String get listsTabTopics => '話題目錄';

  @override
  String get listsBlockedByGuardian => '監護人已封鎖此清單';

  @override
  String get listsTimelineSettingsTooltip => '清單時間軸設定';

  @override
  String get listsAddMembers => '新增成員';

  @override
  String listsMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已新增 $count 人',
    );
    return '$_temp0';
  }

  @override
  String get listsNoUsers => '沒有使用者';

  @override
  String get listsRemoveMember => '移除';

  @override
  String get listsReload => '重新載入';

  @override
  String get listsNoPosts => '沒有貼文';

  @override
  String get listsFeedDefaultTitle => '動態';

  @override
  String get listsImportToTimeline => '匯入時間軸';

  @override
  String get listsFeedTimelineSettingsTooltip => '動態時間軸設定';

  @override
  String get listsImportSearchHintFeeds => '搜尋自訂動態，或輸入分享連結 / URL';

  @override
  String get listsImportSearchHintRasq => '搜尋 RASQ 清單，或輸入分享連結 / URL';

  @override
  String get listsImportSearchHintBoth => '搜尋自訂動態 / RASQ 清單，或輸入分享連結 / URL';

  @override
  String get listsImportSearchPlain => '搜尋';

  @override
  String get listsImportFeedsHelp => '搜尋動態或貼上 URL，將以清單卡片顯示。點按即可進入該動態的時間軸。';

  @override
  String get listsImportRasqHelp =>
      'RASQ 清單可透過「匯入」加入首頁時間軸（將追蹤該清單）。只能匯入可以取得清單成員資訊的清單。';

  @override
  String get listsImportGenericHelp => '可以搜尋清單並進行批次操作。';

  @override
  String get listsImportLocal => '從本機匯入';

  @override
  String get listsImportLocalMessage => '從檔案匯入正在準備中。';

  @override
  String get listsImportLocalDetail => '從 CSV/JSON 匯入將與清單功能（伺服器端）一同實作。';

  @override
  String get listsImportPopularFeeds => '熱門動態';

  @override
  String get listsImportFeedResults => '動態搜尋結果';

  @override
  String get listsImportEnterQuery => '請輸入搜尋字詞或 URL';

  @override
  String get listsImportRasqMine => 'RASQ 清單（自己的 / 追蹤中）';

  @override
  String get listsImportRasqResults => 'RASQ 清單搜尋結果';

  @override
  String get listsImportButton => '匯入';

  @override
  String get listsImportHistory => '歷史紀錄';

  @override
  String get listsImportHistoryEmpty => '沒有歷史紀錄';

  @override
  String get listsTopicsEmpty => '尚無話題';

  @override
  String get listsTopicsEmptyHint => '貼文累積後會依話題劃分';

  @override
  String get listsTopicsCaption => '依話題劃分。點按後只顯示該話題的貼文。';

  @override
  String get listsTopicsCaptionDetail =>
      '將對話事件（2 則以上貼文，與關聯式 TL 使用相同引擎）作為章節，單獨的貼文合併為一個（indexForListTimeline）。標題為貼文中的詞語（標籤 / 特徵詞 / 網域）。';

  @override
  String listsTopicTimeRange(String start, String end) {
    return '$start～$end';
  }

  @override
  String listsTopicSubtitle(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$time · $_temp0';
  }

  @override
  String listsTopicSubtitleWithPeople(String time, int count, int people) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    String _temp1 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people 人',
    );
    return '$time · $_temp0 · $_temp1';
  }

  @override
  String listsTopicSnippet(String name, String body) {
    return '$name「$body」';
  }

  @override
  String listsTopicFilterChip(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '話題：$label（$_temp0）';
  }

  @override
  String get listsTopicFilterClear => '取消篩選';

  @override
  String listsMemberCandidateSubtitle(String handle, String instance) {
    return '@$handle · $instance';
  }

  @override
  String listsMemberNotPublished(String name) {
    return '$name 未公開此 SNS 的帳號';
  }

  @override
  String listsMemberSnsNotFound(String name) {
    return '找不到 $name 的 SNS 帳號';
  }

  @override
  String get listsPickerConfirm => '新增';

  @override
  String get listsPickerNoServer => '未連線到 RASQ 伺服器';

  @override
  String get listsPickerLookupFailed => '無法查詢';

  @override
  String get listsPickerUnavailable => '無法選擇';

  @override
  String get listsPickerNone => '沒有人';

  @override
  String get listsPickerSearchHint => '搜尋使用者（SNS / RASQ）';

  @override
  String get listsPickerSnsUsers => 'SNS 使用者';

  @override
  String get listsPickerRasqUsers => 'RASQ 使用者';

  @override
  String get listsPickerSnsFollowing => 'SNS 上追蹤的人';

  @override
  String get listsPickerRasqFollowing => 'RASQ 上追蹤的人';

  @override
  String get listsPickerRasqNotice => 'RASQ 使用者將透過其公開的同一 SNS 帳號新增。';

  @override
  String listsPickerRasqNoticeDetail(String path) {
    return '從 Central 公開頁面（$path）的 snsAccounts 中選擇與此工作階段相同的 SNS（優先相同伺服器、優先已驗證），並新增透過 userByHandle 查到的 id。';
  }

  @override
  String listsPickerSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已選擇 $count 人',
    );
    return '$_temp0';
  }

  @override
  String get listsPickerRasqBadgeSemantics => 'RASQ 使用者';

  @override
  String get loginBack => '返回';

  @override
  String get loginTitle => '登入社群網路';

  @override
  String get loginPluginLoadNote => '首次登入前會載入外掛。請在網路良好的環境下進行。';

  @override
  String get loginChildSafeBlocked => '監護人已禁止新增 SNS 帳號';

  @override
  String get loginShareDeviceOnly => '已透過電子郵件核准此裝置。請使用下方按鈕在此裝置上登入 SNS 帳號';

  @override
  String get loginWithBluesky => '使用 Bluesky 登入';

  @override
  String get loginWithMisskey => '使用 Misskey 登入';

  @override
  String get loginWithMixi2 => '使用 mixi2 登入';

  @override
  String get loginWithMastodon => '使用 Mastodon 登入';

  @override
  String get loginDiscover => '尋找服務並登入';

  @override
  String get loginRaiInstruction => 'RAi 指引';

  @override
  String get loginShareMailUnavailable => '目前無法傳送';

  @override
  String loginShareMailSent(String to) {
    return '已將核准連結傳送至 $to（30 分鐘內有效）。請在瀏覽器中開啟，登入 RASQ 帳號後進行核准';
  }

  @override
  String get loginShareMailSentVerified =>
      '已將核准連結傳送至已驗證的電子郵件地址（30 分鐘內有效）。請在瀏覽器中開啟，登入 RASQ 帳號後進行核准';

  @override
  String get loginShareMailNoVerified =>
      '沒有已驗證的電子郵件地址。請在原裝置上核准，或在此裝置上登入 SNS 帳號';

  @override
  String get loginShareMailTooMany => '傳送次數過多。請稍後再試';

  @override
  String get loginShareMailNotSupported => '此伺服器不支援透過電子郵件核准';

  @override
  String loginShareMailFailed(String code) {
    return '傳送失敗（$code）';
  }

  @override
  String get loginShareWaiting =>
      '在原裝置上核准共享後，將一次登入所有 SNS 帳號。也可以透過寄到已驗證電子郵件的連結進行核准';

  @override
  String get loginShareMailButton => '透過電子郵件核准（傳送連結）';

  @override
  String get loginBundleTitleThis => '此 RASQ 帳號的 SNS 帳號';

  @override
  String loginBundleTitle(String handle) {
    return '@$handle 的 SNS 帳號';
  }

  @override
  String get loginBundleHint => '尚未在此裝置上登入。點按即可登入。';

  @override
  String get loginBundleUse => '使用';

  @override
  String get loginBundleLogin => '登入';

  @override
  String get loginTermsTitle => '外掛條款';

  @override
  String get loginTermsAgree => '同意';

  @override
  String loginTermsBullet(String text) {
    return '• $text';
  }

  @override
  String loginSignupDivider(String service) {
    return '沒有 $service 帳號';
  }

  @override
  String get loginSignupButton => '註冊';

  @override
  String get loginSignupReopen => '再次開啟註冊頁面';

  @override
  String loginBrowserOpenFailed(String url) {
    return '無法開啟瀏覽器。URL: $url';
  }

  @override
  String get loginPluginMissingMixi2 => '找不到 mixi2 外掛';

  @override
  String loginMixi2BrowserPending(String url) {
    return '請在瀏覽器中授權後返回 App：$url';
  }

  @override
  String loginFailed(String error) {
    return '登入失敗：$error';
  }

  @override
  String get loginMixi2HostHint => '主機（例：mixi.social）';

  @override
  String get loginMixi2Note =>
      'mixi2 官方 API 需申請使用，登入將透過 RASQ 的伺服器進行。在準備就緒前無法使用「在瀏覽器中驗證」。';

  @override
  String get loginMixi2Browser => '在瀏覽器中驗證';

  @override
  String get loginMixi2Dummy => '使用測試帳號試用';

  @override
  String get loginMixi2DummyNote =>
      '測試帳號不使用網路，可以用外掛內建的貼文確認時間軸 / 按讚 / 轉發 / 發文 / 通知的流程。';

  @override
  String get loginMixi2SignupHint =>
      '請在瀏覽器（或 mixi2 App）中建立 mixi2 帳號。建立後，返回此畫面並透過「在瀏覽器中驗證」登入。';

  @override
  String get loginPluginMissingBluesky => '找不到 Bluesky 外掛';

  @override
  String get loginBlueskyHostHint => 'PDS（例：bsky.social）';

  @override
  String get loginBlueskyIdHint => '帳號代稱（例：you.bsky.social）或電子郵件';

  @override
  String get loginBlueskyPasswordHint => 'App 密碼';

  @override
  String get loginPasswordHide => '隱藏';

  @override
  String get loginPasswordShow => '顯示';

  @override
  String get loginBlueskyPasswordNote =>
      '請使用在 Bluesky 的「設定 → 隱私與安全 → App 密碼」中建立的密碼。請勿輸入主密碼。';

  @override
  String get loginButton => '登入';

  @override
  String get loginBlueskySignupHint =>
      '請在瀏覽器中的 Bluesky 透過「建立帳號」註冊。註冊後，在 Bluesky 的「設定 → 隱私與安全 → App 密碼」中建立密碼，然後用上方的帳號代稱和 App 密碼登入。';

  @override
  String get loginServerUnreachable => '無法連線到伺服器';

  @override
  String loginServerUnreachableWithError(String error) {
    return '無法連線到伺服器：$error';
  }

  @override
  String loginAuthStartFailed(String error) {
    return '無法開始驗證：$error';
  }

  @override
  String loginAuthCheckFailed(String error) {
    return '驗證確認失敗：$error';
  }

  @override
  String get loginSnsTitle => '變更 PDS';

  @override
  String get loginSnsNote => '變更 PDS 後，App 外顯示的 URL 會改變。';

  @override
  String loginSnsHostHint(String example) {
    return '輸入目標 URL（例：$example）';
  }

  @override
  String get loginSnsSearch => '搜尋伺服器';

  @override
  String get loginSnsServerSection => '伺服器搜尋';

  @override
  String loginSnsMaintainer(String name) {
    return '管理員：$name';
  }

  @override
  String get loginSnsRegistrationClosed => '暫停註冊';

  @override
  String get loginSnsAuthCheck => '確認驗證';

  @override
  String get loginSnsReopenBrowser => '再次開啟瀏覽器';

  @override
  String get loginMisskeyAuthButton => '在瀏覽器中驗證 (MiAuth)';

  @override
  String get loginMastodonAuthButton => '在瀏覽器中驗證 (OAuth)';

  @override
  String get loginMastodonHostHint => '輸入站台 URL（例：mastodon.social）';

  @override
  String get mediaVizStyleMirror => '上下對稱長條';

  @override
  String get mediaVizStyleBars => '由下往上的長條';

  @override
  String get mediaVizStyleLine => '折線';

  @override
  String get mediaVizLeftAvatar => '帳號頭像';

  @override
  String get mediaVizLeftFile => '選擇的圖片';

  @override
  String get mediaVizLeftGlyph => '音符圖示';

  @override
  String get mediaVizLeftNone => '無（波形佔滿寬度）';

  @override
  String get mediaVizTextBelow => '圖片下方';

  @override
  String get mediaVizTextAbove => '圖片上方';

  @override
  String get mediaVizQualityFast => '快速（960×540）';

  @override
  String get mediaVizQualityStandard => '標準（1280×720）';

  @override
  String get mediaVizQualityFine => '精細（2560×1440，耗時約 4 倍）';

  @override
  String get mediaWavInvalid => '不是 WAV 格式';

  @override
  String get mediaWavMissingChunks => 'WAV 缺少 fmt / data';

  @override
  String mediaWavUnsupported(int format, int bits) {
    return '不支援的 WAV(format $format,$bits bit)';
  }

  @override
  String mediaSeconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String mediaVizTimings(
    String total,
    int frameCount,
    String frames,
    String encode,
    String mux,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: '共 $total（$frameCount 影格：繪製 $frames / 編碼 $encode / 合成 $mux）',
    );
    return '$_temp0';
  }

  @override
  String get mediaAudioVideoUnsupported =>
      '此裝置無法將音訊轉為影片（僅限 Android / iOS / macOS）';

  @override
  String get mediaViewerSemantics => '貼文';

  @override
  String get mediaViewerBack => '返回';

  @override
  String get mediaViewerPip => '子母畫面播放';

  @override
  String get mediaViewerMenu => '選單';

  @override
  String get mediaViewerShare => '分享';

  @override
  String get mediaPluginAsking => '正在查看圖片…';

  @override
  String get mediaPluginFound => '已偵測到';

  @override
  String get mediaPluginNotFound => '未偵測到';

  @override
  String mediaPluginFailed(String reason) {
    return '失敗：$reason（關閉後再開啟即可重試）';
  }

  @override
  String get mediaPluginFetchFailed => '無法取得圖片';

  @override
  String mediaPluginFetchFailedWithError(String error) {
    return '無法取得圖片（$error）';
  }

  @override
  String get mediaPluginDecodeFailed => '無法讀取圖片';

  @override
  String mediaVideoCannotPlay(String error) {
    return '無法播放：$error';
  }

  @override
  String get mediaVideoBack5 => '倒退 5 秒';

  @override
  String get mediaVideoPause => '暫停';

  @override
  String get mediaVideoPlay => '播放';

  @override
  String get mediaVideoForward5 => '快轉 5 秒';

  @override
  String get mediaVideoSpeed => '播放速度';

  @override
  String get mediaVideoFowTitle => '影片';

  @override
  String get mediaVideoFowClose => '關閉';

  @override
  String get mediaSaveAsk => '每次儲存時選擇';

  @override
  String get mediaSavePhotos => '照片（相簿）';

  @override
  String get mediaSaveFiles => '檔案';

  @override
  String get mediaSaveBadFileName => '要儲存的檔案名稱無效';

  @override
  String get mediaSaveOutsideFolder => '不會寫入儲存資料夾以外的位置';

  @override
  String get mediaSaveTooManySameName => '同名檔案過多';

  @override
  String get mediaSavePhotosDenied => '未允許儲存到照片（請在「設定」App 中允許）';

  @override
  String get mediaSavedToPhotos => '已儲存到照片（相簿「RASQ」）';

  @override
  String mediaSavedToFilesApp(String folder, String fileName) {
    return '已儲存到「檔案」App 的 RASQ › $folder($fileName)';
  }

  @override
  String mediaSavedToPath(String path) {
    return '已儲存：$path';
  }

  @override
  String get mediaColorBlack => '黑';

  @override
  String get mediaColorNavy => '深藍';

  @override
  String get mediaColorInk => '墨色';

  @override
  String get mediaColorDeepGreen => '深綠';

  @override
  String get mediaColorCrimson => '胭脂紅';

  @override
  String get mediaColorWhite => '白';

  @override
  String get mediaColorLightGray => '淺灰';

  @override
  String get mediaColorYellow => '黃';

  @override
  String get mediaColorSkyBlue => '天藍';

  @override
  String get mediaColorPink => '粉紅';

  @override
  String get mediaColorBlue => '藍';

  @override
  String get mediaColorGreen => '綠';

  @override
  String get mediaColorOrange => '橙';

  @override
  String get mediaColorPurple => '紫';

  @override
  String get mediaVizCancel => '取消';

  @override
  String get mediaVizConfirm => '確定';

  @override
  String get mediaVizSemantics => 'Visualizer 設定';

  @override
  String get mediaVizRebuildWarning => '確定後將重新產生影片。之前的編輯會遺失';

  @override
  String mediaVizRebuildDetail(int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '目前播放位置的影格。確定後將重新匯出影片（$frames 影格）。繪圖、文字等之前的編輯會遺失。',
    );
    return '$_temp0';
  }

  @override
  String mediaVizRebuildDetailReducedFps(int frames, String fps) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other:
          '目前播放位置的影格。確定後將重新匯出影片（$frames 影格，由於時間較長，降至 ${fps}fps）。繪圖、文字等之前的編輯會遺失。',
    );
    return '$_temp0';
  }

  @override
  String get mediaVizWaveform => '波形';

  @override
  String get mediaVizBands => '頻段數（低音 → 高音）';

  @override
  String get mediaVizFrameRate => '影格率';

  @override
  String get mediaVizBarColor => '長條顏色';

  @override
  String get mediaVizBackgroundColor => '背景顏色';

  @override
  String get mediaVizLeftImage => '左側圖片';

  @override
  String get mediaVizPickImage => '選擇圖片';

  @override
  String get mediaVizRepickImage => '重新選擇圖片';

  @override
  String get mediaVizPickImageHint => '選擇前顯示音符圖示';

  @override
  String get mediaVizTitleSection => '標題 / 說明';

  @override
  String get mediaVizShowTitle => '顯示標題 / 說明';

  @override
  String get mediaVizTitleHint => '標題（留空則使用檔案名稱）';

  @override
  String get mediaVizDescriptionHint => '說明（選填）';

  @override
  String get mediaVizTextScale => '文字大小';

  @override
  String get mediaVizTextColorAuto => '文字顏色：自動';

  @override
  String get mediaVizBackgroundVideo => '背景影片';

  @override
  String get mediaVizPickVideo => '選擇影片';

  @override
  String get mediaVizRepickVideo => '重新選擇影片';

  @override
  String get mediaVizPickVideoHint => '以影片取代背景顏色播放（不使用其聲音）';

  @override
  String mediaVizVideoSelected(String fileName) {
    return '$fileName — 比音訊短時會重複播放';
  }

  @override
  String get mediaVizRemoveVideo => '移除背景影片';

  @override
  String get mediaVizDim => '影片上的暗化程度';

  @override
  String get mediaVizDimHint => '讓波形和文字更易讀';

  @override
  String get mediaVizFade => '淡入淡出（畫面）';

  @override
  String get mediaVizFadeIn => '淡入';

  @override
  String get mediaVizFadeOut => '淡出';

  @override
  String get mediaVizFadeNone => '無';

  @override
  String get mediaVizExport => '匯出';

  @override
  String get mediaVizExportCaption => '越精細，匯出所需時間越長';

  @override
  String get mediaVizExportDetail =>
      '繪製波形的尺寸（匯出一律為 2560×1440）。左側圖片和文字是另外單獨一層，一律精細繪製。匯出時間大致由 影格數 × 繪製尺寸 決定（降低 fps 也有效）。使用背景影片會變慢。';

  @override
  String mediaVizExportDetailWithLast(String timings) {
    return '上次匯出：$timings。\n繪製波形的尺寸（匯出一律為 2560×1440）。左側圖片和文字是另外單獨一層，一律精細繪製。匯出時間大致由 影格數 × 繪製尺寸 決定（降低 fps 也有效）。使用背景影片會變慢。';
  }

  @override
  String get nodeprogCatalogGenreGenerate => '產生';

  @override
  String get nodeprogCatalogGenreConvert => '轉換';

  @override
  String get nodeprogCatalogGenreInput => '輸入';

  @override
  String get nodeprogCatalogGenreTimeline => '時間軸';

  @override
  String get nodeprogCatalogGenreProcess => '加工';

  @override
  String get nodeprogCatalogGenreCondition => '條件';

  @override
  String get nodeprogCatalogGenreFunction => '函式';

  @override
  String get nodeprogCatalogGenreFetch => '取得';

  @override
  String get nodeprogCatalogGenreComposer => '編輯器';

  @override
  String get nodeprogCatalogGenreStorage => '儲存';

  @override
  String get nodeprogCatalogClockTitle => '時鐘產生器';

  @override
  String get nodeprogCatalogClockDescription => '以固定間隔輸出時鐘。可用作時間軸自動更新等的觸發器。';

  @override
  String get nodeprogCatalogTextConstTitle => '文字';

  @override
  String get nodeprogCatalogTextConstDescription =>
      '將寫入的文字作為文字輸出。可連接到相似度 / 關鍵字的基準或分割的輸入。';

  @override
  String get nodeprogCatalogConvertSplitTitle => '分割';

  @override
  String get nodeprogCatalogConvertSplitDescription =>
      '依分隔符號（換行 / 逗號 / 空白）將文字拆分為文字陣列。可連接到關鍵字清單或儲存的輸入。';

  @override
  String get nodeprogCatalogConvertJoinTitle => '合併';

  @override
  String get nodeprogCatalogConvertJoinDescription =>
      '用分隔符號（換行 / 逗號 / 空白）將文字陣列合併為一個文字。';

  @override
  String get nodeprogCatalogListFirstTitle => '取出貼文';

  @override
  String get nodeprogCatalogListFirstDescription =>
      '從貼文清單中取出第幾則貼文（1 = 第一則）。可將內文轉為文字，連接到基準或設定。';

  @override
  String get nodeprogCatalogPostTextTitle => '貼文內文';

  @override
  String get nodeprogCatalogPostTextDescription => '將一則貼文的內文轉為文字。';

  @override
  String get nodeprogCatalogRandomTitle => '隨機';

  @override
  String get nodeprogCatalogRandomDescription =>
      '為每則貼文輸出隨機數。範圍以「1-7」的形式指定，包含小數點時也會計算小數部分。可透過種子重現。';

  @override
  String get nodeprogCatalogFileTitle => '檔案讀取器';

  @override
  String get nodeprogCatalogFileDescription => '讀取本機檔案並作為文字輸出。';

  @override
  String get nodeprogCatalogTimelineTitle => '時間軸';

  @override
  String get nodeprogCatalogTimelineDescription => '最終輸出。連接貼文清單後，會顯示在此畫面的時間軸中。';

  @override
  String get nodeprogCatalogTlSourceTitle => '取得時間軸';

  @override
  String get nodeprogCatalogTlSourceDescription => '取得所選時間軸，並作為貼文清單傳遞。';

  @override
  String get nodeprogCatalogTlSourceDetail => '取得所選時間軸，並作為貼文清單（附 RRL 標籤）傳遞。';

  @override
  String get nodeprogCatalogSortTitle => '排序';

  @override
  String get nodeprogCatalogSortDescription => '將符合下方所連條件的貼文排到前面（保持原有順序）。';

  @override
  String get nodeprogCatalogRemoveTitle => '刪除';

  @override
  String get nodeprogCatalogRemoveDescription => '移除符合下方所連條件的貼文。';

  @override
  String get nodeprogCatalogCondTitle => '條件';

  @override
  String get nodeprogCatalogCondDescription =>
      '檢查指定標籤的內容並傳回 True/False。向下串聯表示「且」，從同一連接點並聯表示「或」。';

  @override
  String get nodeprogCatalogNotDescription => '傳回下方所連條件的否定。';

  @override
  String get nodeprogCatalogFnInputTitle => '函式輸入';

  @override
  String get nodeprogCatalogFnInputDescription =>
      '函式內部的入口。呼叫端傳入的貼文清單從這裡輸出（僅限函式內部編輯畫面）。';

  @override
  String get nodeprogCatalogFnOutputTitle => '函式輸出';

  @override
  String get nodeprogCatalogFnOutputDescription =>
      '函式內部的出口。連接到這裡的貼文清單將成為函式節點的輸出（未連接時原樣通過）。';

  @override
  String get nodeprogCatalogFilterQueryTitle => '搜尋篩選';

  @override
  String get nodeprogCatalogFilterQueryDescription =>
      '僅讓符合搜尋詞的貼文通過（「排除」則反過來去除）。';

  @override
  String get nodeprogCatalogFilterQueryDetail =>
      '僅讓符合搜尋詞的貼文通過。搜尋詞為空時，使用此頁面的搜尋詞/標籤。將「排除」設為 true 後，會去除符合的貼文（關鍵字靜音）。';

  @override
  String get nodeprogCatalogMergeTitle => '合併';

  @override
  String get nodeprogCatalogMergeDescription => '將連接的貼文清單依時間順序合併為一條。';

  @override
  String get nodeprogCatalogMergeDetail =>
      '將連接的貼文清單依時間順序匯合為一條。透過不同帳號收到的同一貼文會收合為一張，可透過卡片上的 ↓ 選擇帳號。';

  @override
  String get nodeprogCatalogTimelineRelationalTitle => '關聯時間軸';

  @override
  String get nodeprogCatalogTimelineRelationalDescription => '關聯時間軸篩選的出口。';

  @override
  String get nodeprogCatalogTimelineRelationalDetail =>
      '關聯時間軸前置篩選的最終輸出。連接的貼文清單將成為建構對話事件的輸入（處理方式不變）。';

  @override
  String get nodeprogCatalogTlListTitle => '取得清單時間軸';

  @override
  String get nodeprogCatalogTlListDescription => '取得 Misskey 清單的時間軸（依清單名稱指定）。';

  @override
  String get nodeprogCatalogTlSearchTitle => '取得搜尋時間軸';

  @override
  String get nodeprogCatalogTlSearchDescription => '取得符合搜尋詞的貼文。';

  @override
  String get nodeprogCatalogTlDmTitle => '取得私訊';

  @override
  String get nodeprogCatalogTlDmDescription => '取得與對方（帳號代稱）的私訊。';

  @override
  String get nodeprogCatalogTrendTagsTitle => '取得趨勢';

  @override
  String get nodeprogCatalogTrendTagsDescription =>
      '將目前的趨勢標籤作為字串陣列輸出（用於相似度/關鍵字的輸入）。';

  @override
  String get nodeprogCatalogTlFeedTitle => '取得自訂動態來源';

  @override
  String get nodeprogCatalogTlFeedDescription => '取得 Bluesky 的自訂動態來源。';

  @override
  String get nodeprogCatalogTlFeedDetail =>
      '取得 Bluesky 自訂動態來源（動態來源產生器）的時間軸（以 at:// URI 指定。在時間軸自訂中可搜尋選擇）。';

  @override
  String get nodeprogCatalogTlRasqlistTitle => '取得 RASQ 清單';

  @override
  String get nodeprogCatalogTlRasqlistDescription =>
      '取得匯集了多個 SNS 使用者的 RASQ 清單的貼文。';

  @override
  String get nodeprogCatalogTlRasqlistDetail =>
      '取得 RASQ 清單（將 Misskey / Mastodon / Bluesky 使用者匯集為一個的清單）的貼文。只能選擇可以取得清單中成員資訊的清單（有同一伺服器的帳號 / 追蹤了成員）。';

  @override
  String get nodeprogCatalogTrendPostsTitle => '取得趨勢搜尋結果';

  @override
  String get nodeprogCatalogTrendPostsDescription =>
      '搜尋目前排名靠前的趨勢標籤，並將其貼文合併為一條輸出。';

  @override
  String get nodeprogCatalogComposerTargetTitle => '發布目標';

  @override
  String get nodeprogCatalogComposerTargetDescription =>
      '發布目標帳號的候選。符合下方條件時將成為發布目標。';

  @override
  String get nodeprogCatalogComposerTargetDetail =>
      '發布目標帳號的候選。在下方掛上條件後，當貼文內容符合該條件時，此帳號將成為發布目標（越靠上越優先。可手動重新選擇）。';

  @override
  String get nodeprogCatalogComposerFallbackTitle => '以替代格式發布';

  @override
  String get nodeprogCatalogComposerFallbackDescription =>
      '被篩選排除時，以其他形式發布到此帳號。';

  @override
  String get nodeprogCatalogComposerFallbackDetail =>
      '被篩選排除出發布目標時的旁路。當下方條件（通常是前一個比較的 Not）成立時，以替代格式發布到此帳號。';

  @override
  String get nodeprogCatalogComposerLinkgateTitle => '連動篩選';

  @override
  String get nodeprogCatalogComposerLinkgateDescription => '僅對一同傳送的貼文生效的篩選。';

  @override
  String get nodeprogCatalogComposerLinkgateDetail =>
      '僅作用於連動發布的篩選。下方條件不成立時，不會向此帳號傳送連動貼文（不影響一般的發布目標判定）。';

  @override
  String get nodeprogCatalogComposerRegexTitle => '貼文加工（正規表示式）';

  @override
  String get nodeprogCatalogComposerRegexDescription => '傳送時替換內文的一部分。';

  @override
  String get nodeprogCatalogComposerRegexDetail =>
      '傳送時對內文進行正規表示式替換（替換與模式相符的部分）。帳號為空時，適用於所有發布目標。';

  @override
  String get nodeprogCatalogTlMyreactionsTitle => '取得已回應的貼文';

  @override
  String get nodeprogCatalogTlMyreactionsDescription =>
      '取得你在時間軸中回應過的貼文（用於建立喜好設定檔）。';

  @override
  String get nodeprogCatalogTrendFrameTitle => '趨勢框';

  @override
  String get nodeprogCatalogTrendFrameDescription =>
      '趨勢首頁「趨勢」列表的最終輸出。連接標籤（文字陣列）後會直接顯示在列表中。';

  @override
  String get nodeprogCatalogMlSimilarTitle => '相似度 (SigLIP)';

  @override
  String get nodeprogCatalogMlSimilarDescription => '輸出每則貼文與基準的相似程度（0~1）。';

  @override
  String get nodeprogCatalogMlSimilarDetail =>
      '將基準（文字/陣列/向量）與每則貼文的相似度，以此時間軸內的相對值 0~1 輸出（0.8 ≈ 前 20%）。ML 無法使用時降級為 n-gram 相似度。';

  @override
  String get nodeprogCatalogMlGlinerTitle => 'GLiNER 擷取';

  @override
  String get nodeprogCatalogMlGlinerDescription =>
      '從貼文清單中擷取特徵詞（依出現頻率），並以字串陣列輸出。';

  @override
  String get nodeprogCatalogMlSiglipTitle => 'SigLIP 嵌入';

  @override
  String get nodeprogCatalogMlSiglipDescription => '彙總輸出貼文清單的傾向。';

  @override
  String get nodeprogCatalogMlSiglipDetail =>
      '以向量輸出貼文清單的平均嵌入（設定檔）。ML 無法使用時降級為 n-gram 設定檔。';

  @override
  String get nodeprogCatalogStorageSaveTitle => '儲存 (storage.safe)';

  @override
  String get nodeprogCatalogStorageSaveDescription => '儲存連接的資料。';

  @override
  String get nodeprogCatalogStorageSaveDetail =>
      '將連接的資料儲存到插槽。storage.safe 是也可以傳遞給相依子外掛的安全存放處（外掛端的傳遞會在首次啟動時確認）。';

  @override
  String get nodeprogCatalogStorageLoadTitle => '讀取 (storage.safe)';

  @override
  String get nodeprogCatalogStorageLoadDescription => '讀取儲存在插槽中的資料。';

  @override
  String get nodeprogCatalogMlKeywordTitle => '關鍵字比對 (GLiNER)';

  @override
  String get nodeprogCatalogMlKeywordDescription => '輸出關鍵字（或陣列）與每則貼文特徵詞的相符數。';

  @override
  String get nodeprogCatalogMlTendencyTitle => '傾向/刺激程度（設定檔）';

  @override
  String get nodeprogCatalogMlTendencyDescription => '為每則貼文輸出與喜好設定的契合度（0~1）。';

  @override
  String get nodeprogCatalogMlTendencyDetail =>
      '為每則貼文輸出與 storage.safe 中趨勢設定檔（喜歡的類型/方向、傾向閾值、刺激程度上限）的契合度（0~1）。設定檔可在搜尋首頁的趨勢 ⚙ 中編輯，其他節點也能讀取同一插槽。';

  @override
  String get nodeprogCatalogCompareTitle => '比較';

  @override
  String get nodeprogCatalogCompareDescription => '將數值與閾值比較並傳回 True/False。';

  @override
  String get nodeprogCatalogCompareDetail =>
      '將數值（相似度、隨機數等）與閾值比較並傳回 True/False 的運算子條件。值來源未連接或無法取得值時（如插槽為空）為 False。';

  @override
  String nodeprogCatalogTypeWithFormat(String type, String format) {
    return '$type($format)';
  }

  @override
  String nodeprogCatalogPortWithType(String label, String type) {
    return '$label($type)';
  }

  @override
  String get nodeprogCatalogIoCond => '條件';

  @override
  String get nodeprogCatalogIoNone => '無';

  @override
  String get nodeprogCatalogListSeparator => '、';

  @override
  String nodeprogCatalogIoSummary(String inputs, String outputs) {
    return '輸入：$inputs → 輸出：$outputs';
  }

  @override
  String get nodeprogCatalogCustomFunctionAuthor => '自訂函式';

  @override
  String nodeprogCatalogCustomFunctionCondDescription(String tags) {
    return '接收條件 $tags 的自建函式。';
  }

  @override
  String nodeprogCatalogCustomFunctionCondDetail(String tags) {
    return '接收條件標籤 $tags 的自訂函式（內部連線由外掛/RAi 完成）。';
  }

  @override
  String get nodeprogCatalogCustomFunctionDataDescription => '自建的函式。';

  @override
  String get nodeprogCatalogCustomFunctionDataDetail => '自訂函式（內部連線由外掛/RAi 完成）。';

  @override
  String get nodeprogCatalogGenreSortDictionary => '排序/詞典';

  @override
  String get nodeprogCatalogCustomFunctionDefaultName => '函式';

  @override
  String get nodeprogComponentsTrendFormTilesLabel => '取得趨勢';

  @override
  String get nodeprogComponentsTrendFormChipsLabel => '自訂（候選標籤）';

  @override
  String get nodeprogComponentsTrendFormChipsHeading => '搜尋建議';

  @override
  String get nodeprogComponentsTrendFormTilesDescription =>
      '以趨勢卡片的形式顯示候選關鍵字（點按即可查看該關鍵字的趨勢）。';

  @override
  String get nodeprogComponentsTrendFormTodayDescription =>
      '像 Today 一樣彙總顯示排名靠前的候選關鍵字的貼文。';

  @override
  String get nodeprogComponentsTrendFormChipsDescription =>
      '以搜尋候選標籤的形式顯示候選關鍵字。';

  @override
  String nodeprogComponentsSuggestTitle(String what, String from) {
    return '從$from推薦$what';
  }

  @override
  String nodeprogComponentsFilterTitle(String what, String from) {
    return '依$from篩選$what';
  }

  @override
  String get nodeprogComponentsQueryFilterExcludeTitle => '搜尋篩選（排除）';

  @override
  String get nodeprogComponentsTendencyTitle => '傾向/刺激程度（設定檔）';

  @override
  String get nodeprogComponentsPluginTitle => '自訂（時間軸外掛）';

  @override
  String get nodeprogComponentsDisplayTimeline => '一般時間軸';

  @override
  String get nodeprogComponentsDisplayRelational => '關聯時間軸';

  @override
  String get nodeprogComponentsDeliveryConfirm => '確認後發布 (confirm)';

  @override
  String get nodeprogComponentsDeliveryDraft => '僅建立草稿 (draft)';

  @override
  String get nodeprogComponentsDeliveryAuto => '直接發布 (auto)';

  @override
  String get nodeprogComponentsSelfDm => '此私訊的訊息';

  @override
  String get nodeprogComponentsSelfSearch => '此關鍵字的搜尋結果';

  @override
  String get nodeprogComponentsSelfToday => 'Today 的貼文';

  @override
  String get nodeprogComponentsSelfTrendWords => '趨勢關鍵字';

  @override
  String get nodeprogComponentsSelfList => '此清單的貼文';

  @override
  String get nodeprogComponentsSelfFeed => '此動態來源的貼文';

  @override
  String get nodeprogComponentsSelfBundle => '綜合分頁的貼文';

  @override
  String get nodeprogComponentsSelfHome => '追蹤中分頁的貼文';

  @override
  String get nodeprogComponentsSelfSocial => '推薦分頁的貼文';

  @override
  String get nodeprogComponentsSelfLocal => '本地分頁的貼文';

  @override
  String get nodeprogComponentsSelfGlobal => '全域分頁的貼文';

  @override
  String get nodeprogComponentsSelfRelational => '關聯分頁的貼文';

  @override
  String get nodeprogComponentsSelfTab => '此分頁的貼文';

  @override
  String get nodeprogComponentsTrendTilesNoMl => '使用 ML 模型，因此無法用於趨勢卡片';

  @override
  String get nodeprogComponentsTrendTilesNoPlugin =>
      '會對貼文重新排序（可能使用 GPU），因此無法用於趨勢卡片';

  @override
  String get nodeprogComposerResetConfig => '重設此配置';

  @override
  String get nodeprogComposerLearnNone => '尚未學習（發文後會自動學習）';

  @override
  String get nodeprogComposerLearnNoneDetail => '學習設定檔：還沒有已確定的貼文（發文後自動學習）';

  @override
  String nodeprogComposerLearnCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已從 $count 則貼文中學習',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerLearnCountDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '學習設定檔：已確定的貼文 $count 則（手動切換的貼文學習權重較高，半衰期 90 天）',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerRelationStats(int pos, int neg) {
    return '紀錄：連動 $pos 次 / 確認時取消 $neg 次';
  }

  @override
  String get nodeprogComposerNoAccounts => '沒有帳號';

  @override
  String get nodeprogComposerNoAccountsHint => '登入後即可設定發布目標的條件';

  @override
  String get nodeprogComposerBanner => '與草稿內容相符的帳號會成為發布目標候選';

  @override
  String get nodeprogComposerBannerDetail =>
      '為每個帳號設定篩選後，與草稿內容（及內部格式）相符的帳號會成為發布目標候選。';

  @override
  String get nodeprogComposerHandEdited => '發布目標已在節點編輯器中編輯。在此變更會將其覆寫';

  @override
  String get nodeprogComposerHandEditedDetail => '發布目標已在節點編輯器中編輯。在此變更會替換為簡易配置。';

  @override
  String get nodeprogComposerFiltersHeader => '發布目標篩選';

  @override
  String get nodeprogComposerFormatHeader => '格式';

  @override
  String get nodeprogComposerFormatCaption => '即使不符合篩選，也可以換一種形式保留為候選';

  @override
  String get nodeprogComposerFormatCaptionDetail =>
      '不符合篩選時，以替代格式保留為候選（從即將被排除前的比較處繞過）。';

  @override
  String get nodeprogComposerDeliveryHeader => '連動貼文的傳送方式';

  @override
  String get nodeprogComposerDeliveryCaption => '與其他帳號一起傳送時的設定';

  @override
  String get nodeprogComposerDeliveryCaptionDetail =>
      '在多選模式的「節點連動」中傳送到此帳號時的傳送方式，以及可連動的來源帳號。';

  @override
  String nodeprogComposerDeliveryTitle(String delivery) {
    return '傳送方式：$delivery';
  }

  @override
  String get nodeprogComposerLinkSourcesLabel => '連動來源帳號（僅當主發布目標在其中時連動）';

  @override
  String get nodeprogComposerLinkFiltersCaption => '連動篩選（僅在一起傳送時生效）';

  @override
  String get nodeprogComposerLinkFiltersCaptionDetail =>
      '連動篩選（僅對連動貼文生效的關卡，不影響發布目標判定）';

  @override
  String nodeprogComposerFilterDescription(String basis, String what) {
    return '以此帳號的$basis為基準，草稿在$what上相符時成為發布目標候選。';
  }

  @override
  String get nodeprogComposerFilterBasisPosts => '貼文';

  @override
  String get nodeprogComposerFilterBasisReplies => '回覆';

  @override
  String get nodeprogComposerFilterDisabled => '已停用：此帳號不會成為發布目標候選。';

  @override
  String nodeprogComposerLinkOnlySubtitle(String account) {
    return '$account · 僅連動';
  }

  @override
  String nodeprogComposerAndSubtitle(String account) {
    return '$account · 且';
  }

  @override
  String get nodeprogComposerLinkFilterDescription => '連動貼文不符合此條件時，不會傳送到此帳號。';

  @override
  String get nodeprogComposerAndDescription => '與前一個篩選以「且」連接。';

  @override
  String get nodeprogComposerDeleteNode => '刪除節點';

  @override
  String nodeprogComposerRegexDescription(String pattern, String replace) {
    return '將傳送到此帳號的內文中的「$pattern」替換為「$replace」。';
  }

  @override
  String get nodeprogComposerRegexDescriptionEmpty =>
      '傳送時對內文進行正規表示式替換（例：更換標籤、遮蔽文字）。';

  @override
  String get nodeprogComposerRegexUnset => '貼文加工（未設定）';

  @override
  String nodeprogComposerRegexRule(String pattern, String replace) {
    return '「$pattern」→「$replace」';
  }

  @override
  String nodeprogComposerExtraNodeSubtitle(String account) {
    return '$account · 追加節點';
  }

  @override
  String get nodeprogComposerExtraRegexDescription => '在上方的加工之後套用。';

  @override
  String get nodeprogComposerCwLabel => '內容警告';

  @override
  String get nodeprogComposerNoOtherAccounts => '沒有其他帳號';

  @override
  String get nodeprogComposerRegexMenuTooltip => '貼文加工操作';

  @override
  String get nodeprogComposerFilterMenuTooltip => '發布目標操作';

  @override
  String get nodeprogComposerParamsRegexEnabled => '啟用貼文加工';

  @override
  String get nodeprogComposerParamsRegexEnabledSubtitle => '對傳送到此帳號的內文進行模式替換';

  @override
  String get nodeprogComposerParamsExtraRegex => '在上方的加工之後套用的追加節點。';

  @override
  String get nodeprogComposerParamsFilterEnabled => '啟用篩選';

  @override
  String get nodeprogComposerParamsFilterEnabledSubtitle => '停用時，此帳號不會成為發布目標候選';

  @override
  String get nodeprogComposerParamsWhat => '比較什麼？';

  @override
  String get nodeprogComposerParamsRegexDescription => '傳送時對內文進行正規表示式替換。';

  @override
  String get nodeprogComposerParamsLinkFilterDescription => '僅在一起傳送時生效的條件。';

  @override
  String get nodeprogComposerParamsLinkFilterDetail =>
      '僅對連動貼文生效的關卡（不影響發布目標判定）。';

  @override
  String get nodeprogComposerParamsFilterDescription =>
      '草稿符合此條件時，此帳號會成為發布目標候選。';

  @override
  String get nodeprogComposerParamsPatternLabel => '模式（正規表示式）';

  @override
  String get nodeprogComposerParamsPatternHint => '例：#爆雷\\s*';

  @override
  String get nodeprogComposerParamsReplaceLabel => '替換為（留空 = 刪除）';

  @override
  String get nodeprogEditorCanvasInputs => '輸入';

  @override
  String get nodeprogEditorCanvasOutputs => '輸出';

  @override
  String get nodeprogEditorBadgeDefaultOwner => '預設';

  @override
  String get nodeprogEditorBadgeNotRegistered => '未註冊';

  @override
  String get nodeprogEditorBadgeSeparator => ' · ';

  @override
  String get nodeprogEditorNodeTabDefaultLabel => '節點 TL';

  @override
  String get nodeprogEditorInlineEmpty => '沒有節點';

  @override
  String get nodeprogEditorInlineExpandTooltip => '全螢幕編輯';

  @override
  String get nodeprogEditorParamsMissing => '此外掛未註冊（請從商店重新安裝）。';

  @override
  String get nodeprogEditorParamsLoading => '正在載入參數…';

  @override
  String get nodeprogEditorParamsNone => '此外掛沒有參數。';

  @override
  String get nodeprogEditorCancelButton => '取消';

  @override
  String get nodeprogEditorConfirmButton => '確定';

  @override
  String get nodeprogEditorParamsTitle => '設定節點';

  @override
  String get nodeprogEditorPluginSortAuthor => 'TL 外掛';

  @override
  String get nodeprogEditorPluginSortDescription => '依照外掛的排列方式排序貼文。';

  @override
  String get nodeprogEditorParamsPluginDetail =>
      '使用外掛的排序（tl.sort）排序貼文清單。參數會進入節點的「參數」連接埠。';

  @override
  String nodeprogEditorPluginSortTitle(String name) {
    return '依$name排序';
  }

  @override
  String get nodeprogEditorPluginSortDetail => '使用外掛的排序（tl.sort）排序貼文清單。';

  @override
  String get nodeprogEditorTitleFunctionBody => '函式內容';

  @override
  String nodeprogEditorTitleFunctionBodyNamed(String name) {
    return '函式內容 — $name';
  }

  @override
  String get nodeprogEditorTitleComposer => '自訂發布目標';

  @override
  String get nodeprogEditorTitleTrend => '自訂趨勢';

  @override
  String get nodeprogEditorTitleTimeline => '自訂時間軸';

  @override
  String get nodeprogEditorTabTrendNotes => '貼文';

  @override
  String get nodeprogEditorTabFollowing => '追蹤中';

  @override
  String get nodeprogEditorTabTrendUsers => '使用者';

  @override
  String get nodeprogEditorTabBundle => '綜合';

  @override
  String get nodeprogEditorTabSocial => '推薦';

  @override
  String get nodeprogEditorTabRelational => '相關';

  @override
  String get nodeprogEditorTabLocal => '本站';

  @override
  String get nodeprogEditorTabGlobal => '全域';

  @override
  String get nodeprogEditorAddTabTooltip => '新增分頁';

  @override
  String get nodeprogEditorNewTabTitle => '新分頁';

  @override
  String get nodeprogEditorTabNameHint => '分頁名稱';

  @override
  String get nodeprogEditorRenameTab => '重新命名分頁';

  @override
  String get nodeprogEditorDeleteTab => '刪除分頁';

  @override
  String get nodeprogEditorClearGraph => '清除圖表';

  @override
  String get nodeprogEditorBundleTabsToggle => '在組合中集中顯示節點 TL';

  @override
  String get nodeprogEditorPaletteSearchHint => '搜尋外掛節點';

  @override
  String nodeprogEditorConnectTypeMismatch(String from, String to) {
    return '無法連接：$from → $to（格式不符）';
  }

  @override
  String get nodeprogEditorCreateFunction => '建立自訂函式';

  @override
  String get nodeprogEditorFunctionNameHint => '函式名稱';

  @override
  String get nodeprogEditorFunctionSourceLabel => '輸入來源';

  @override
  String get nodeprogEditorFunctionSourceCond => '條件';

  @override
  String get nodeprogEditorFunctionSourceData => '資料';

  @override
  String get nodeprogEditorFunctionCondTagsLabel => '條件標籤（選擇多個會增加下方的分支）';

  @override
  String get nodeprogEditorFunctionInputsLabel => '輸入（資料格式）';

  @override
  String get nodeprogEditorFunctionOutputsLabel => '輸出（資料格式）';

  @override
  String get nodeprogEditorCreateButton => '建立';

  @override
  String get nodeprogEditorMenuInfo => '節點資訊';

  @override
  String get nodeprogEditorMenuEditFunctionBody => '編輯函式內容';

  @override
  String get nodeprogEditorMenuStore => '前往外掛商店';

  @override
  String get nodeprogEditorMenuCopy => '複製';

  @override
  String get nodeprogEditorMenuPaste => '貼上';

  @override
  String get nodeprogEditorMenuDelete => '刪除';

  @override
  String get nodeprogEditorMoreTooltip => '更多';

  @override
  String get nodeprogEditorSearchNodesTooltip => '搜尋節點';

  @override
  String get nodeprogEditorEmptyHint => '從下方搜尋新增（點按查看詳情，長按拖曳）';

  @override
  String get nodeprogEditorToolbarSelect => '框選';

  @override
  String get nodeprogEditorToolbarSelectStop => '停止框選';

  @override
  String get nodeprogEditorToolbarDeleteSelected => '刪除所選節點';

  @override
  String get nodeprogEditorToolbarTidy => '整理';

  @override
  String get nodeprogEditorToolbarZoomOut => '縮小';

  @override
  String get nodeprogEditorToolbarZoomIn => '放大';

  @override
  String get nodeprogEditorToolbarFit => '顯示全部';

  @override
  String get nodeprogEditorPaletteSortChip => '排序：相關度';

  @override
  String get nodeprogEditorPaletteSortRelevance => '相關度';

  @override
  String nodeprogEditorPaletteGenreChip(String genre) {
    return '類型：$genre';
  }

  @override
  String get nodeprogEditorPaletteGenreAll => '全部';

  @override
  String get nodeprogEditorPaletteSettingsTooltip => '搜尋設定（準備中）';

  @override
  String get nodeprogEditorPaletteEmptyTitle => '找不到節點';

  @override
  String get nodeprogEditorPaletteEmptyHint => '請嘗試更換搜尋字詞或類型';

  @override
  String get nodeprogEditorCreateFunctionDescription =>
      '選擇條件標籤或輸入輸出（資料格式），建立自己的函式節點。資料函式的內容可以用節點組建。';

  @override
  String nodeprogEditorTileSubtitle(String author, String genre) {
    return '$author · $genre';
  }

  @override
  String get nodeprogEditorBuiltinAuthor => '內建節點';

  @override
  String get nodeprogEditorAddToCanvas => '加入畫布';

  @override
  String get nodeprogEditorEditFunctionBody => '編輯內容';

  @override
  String get nodeprogEditorDeleteFunction => '刪除函式';

  @override
  String nodeprogEditorInfoGenre(String genre) {
    return '類型：$genre';
  }

  @override
  String get nodeprogEditorInfoCondIn => '條件（上緣）';

  @override
  String get nodeprogEditorInfoCondOut => '條件（下緣）';

  @override
  String get nodeprogTimelineTabDmCommon => 'DM（通用）';

  @override
  String get nodeprogTimelineTabThisDm => '此 DM';

  @override
  String get nodeprogTimelineTabTrendPage => '趨勢頁面';

  @override
  String get nodeprogTimelineTabTrendTl => '趨勢時間軸';

  @override
  String get nodeprogTimelineTabThisList => '此清單';

  @override
  String get nodeprogTimelineReorderTabs => '調整分頁順序';

  @override
  String get nodeprogTimelineShareTab => '在所有帳號間共用';

  @override
  String get nodeprogTimelineResetConfig => '重設此時間軸的配置';

  @override
  String get nodeprogTimelineEditAsGraph => '以圖形編輯';

  @override
  String nodeprogTimelinePluginWithVersion(String version) {
    return '時間軸外掛 · v$version';
  }

  @override
  String get nodeprogTimelineAlgoChronoDescription => '依取得時的時間順序排列。';

  @override
  String get nodeprogTimelineAlgoTendencyDescription =>
      '排除不符合偏好設定的貼文，並依符合程度排序。';

  @override
  String get nodeprogTimelineAlgoTendencyDetail =>
      '排除不符合趨勢設定檔（傾向/刺激程度、喜歡的類型）的貼文，並依適配度排序。';

  @override
  String nodeprogTimelineAlgoSuggestDescription(
    String from,
    String kind,
    String what,
  ) {
    return '以$from（$kind）為基準，將在$what上相符的貼文排到前面。';
  }

  @override
  String get nodeprogTimelineSuggestFromMyPosts => '我的貼文';

  @override
  String get nodeprogTimelineSuggestFromMyReplies => '我的回覆';

  @override
  String get nodeprogTimelineSuggestFromReacted => '我回應過的貼文';

  @override
  String get nodeprogTimelineSourceHomeLabel => '追蹤中（home）';

  @override
  String get nodeprogTimelineSourceRasqTitle => '取得 RASQ 貼文';

  @override
  String get nodeprogTimelineSourceRasqDescription => '時間軸：自己和追蹤中的 RASQ 帳號的貼文';

  @override
  String get nodeprogTimelineSourceRasqSearchTitle => 'RASQ 搜尋';

  @override
  String get nodeprogTimelineSourceRasqSearchPageQuery =>
      '搜尋：此頁面的搜尋字詞 / 標籤（包括未追蹤者的貼文）';

  @override
  String nodeprogTimelineSourceRasqSearchWord(String word) {
    return '搜尋：$word（包括未追蹤者的貼文）';
  }

  @override
  String get nodeprogTimelineSourceRasqListTitle => '取得 RASQ 清單';

  @override
  String nodeprogTimelineSourceRasqListDescription(String name) {
    return 'RASQ 清單：$name';
  }

  @override
  String get nodeprogTimelineNotSelected => '未選擇';

  @override
  String get nodeprogTimelineSectionTitle => '區段';

  @override
  String nodeprogTimelineSectionDescription(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '最多容納 $max 個節點的框（在螢幕上依加入順序以圓角框顯示）',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceAstellTitle => 'ASTell 卡片';

  @override
  String nodeprogTimelineSourceAstellDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '目前開放的 ASTell 房間（最多 $count 個）',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineSourceSwingDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '正在發出 Swing 的人（最多 $count 位）',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceTrendFollowingTitle => '追蹤對象的反應';

  @override
  String get nodeprogTimelineSourceTrendFollowingDescription =>
      '追蹤對象發布的關於此頁面字詞 / 標籤的貼文';

  @override
  String get nodeprogTimelineTrendPluginAll => '所有已安裝的趨勢外掛';

  @override
  String nodeprogTimelineTrendPluginMissing(String id) {
    return '$id（未安裝）';
  }

  @override
  String get nodeprogTimelineTrendPluginAuthor => '趨勢外掛';

  @override
  String nodeprogTimelineTrendPluginDescription(String name, String form) {
    return '$name · $form';
  }

  @override
  String get nodeprogTimelineCurrentAccount => '（目前帳號）';

  @override
  String get nodeprogTimelineAllAccounts => '所有帳號';

  @override
  String get nodeprogTimelineSourceTrendTitle => '取得趨勢';

  @override
  String get nodeprogTimelineSourceTrendTagsAllDescription =>
      '類型：趨勢卡片（RASQ 帳號下所有 SNS 帳號的趨勢字詞）';

  @override
  String get nodeprogTimelineSourceTrendTagsDescription =>
      '類型：趨勢卡片（此帳號所在伺服器的趨勢字詞）';

  @override
  String get nodeprogTimelineSourceSearchTitle => '取得搜尋結果';

  @override
  String get nodeprogTimelineSourceSearchPageQuery => '搜尋：此頁面的搜尋字詞 / 標籤';

  @override
  String nodeprogTimelineSourceSearchWord(String word) {
    return '搜尋：$word';
  }

  @override
  String get nodeprogTimelineSourceTodayTitle => '取得 Today';

  @override
  String get nodeprogTimelineSourceTodayDescription => '時間軸：Today（熱門貼文）';

  @override
  String nodeprogTimelineSourceSelfTitle(String name) {
    return '取得$name';
  }

  @override
  String get nodeprogTimelineSourceDmTitle => '取得 DM';

  @override
  String get nodeprogTimelineSourceFeedTitle => '取得自訂動態';

  @override
  String get nodeprogTimelineSourceListTitle => '取得清單時間軸';

  @override
  String get nodeprogTimelineSourceTimelineTitle => '取得時間軸';

  @override
  String nodeprogTimelineSourceTlDescription(String tl) {
    return '時間軸：$tl';
  }

  @override
  String nodeprogTimelineSourceDmPeer(String peer) {
    return 'DM:@$peer';
  }

  @override
  String get nodeprogTimelineSourceTrendTlKind => '類型：趨勢時間軸（熱門趨勢標籤的搜尋結果）';

  @override
  String nodeprogTimelineSourceFeedName(String name) {
    return '動態：$name';
  }

  @override
  String nodeprogTimelineSourceListName(String name) {
    return '清單：$name';
  }

  @override
  String get nodeprogTimelineMenuInfo => '詳細資料';

  @override
  String get nodeprogTimelineMenuEditParams => '編輯參數';

  @override
  String get nodeprogTimelineMenuDisable => '暫時停用';

  @override
  String get nodeprogTimelineMenuEnable => '取消停用';

  @override
  String get nodeprogTimelineMenuStore => '前往外掛的商店頁面';

  @override
  String get nodeprogTimelineMenuKindToTiles => '將類型改為趨勢卡片';

  @override
  String get nodeprogTimelineMenuKindToTl => '將類型改為趨勢時間軸';

  @override
  String nodeprogTimelineMenuLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '數量：$count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineMenuForm(String form) {
    return '形式：$form';
  }

  @override
  String nodeprogTimelineMenuDisplay(String mode) {
    return '顯示模式：$mode';
  }

  @override
  String nodeprogTimelineLimitItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineInfoProvider(String provider) {
    return '提供者：$provider';
  }

  @override
  String nodeprogTimelineInfoSupported(String sns) {
    return '支援：$sns';
  }

  @override
  String get nodeprogTimelineReorderAlgorithms => '調整演算法順序';

  @override
  String get nodeprogTimelineReorderSources => '調整時間軸順序';

  @override
  String get nodeprogTimelineBannerDmCommon => '此設定用於所有 DM 頁面';

  @override
  String get nodeprogTimelineBannerDmPage => '此設定僅用於此 DM 頁面';

  @override
  String get nodeprogTimelineBanner => '可以決定時間軸的內容和排列方式';

  @override
  String get nodeprogTimelineBannerDmCommonDetail =>
      'DM 的主設定。適用於所有沒有個別設定的 DM 頁面。演算法由上而下依序套用。';

  @override
  String get nodeprogTimelineBannerDmPageDetail =>
      '僅用於此 DM 頁面的設定（儲存後優先於 DM 通用設定）。演算法由上而下依序套用。';

  @override
  String get nodeprogTimelineBannerDetail =>
      '可以指定時間軸的演算法、匯入來源、要顯示的時間軸等。演算法由上而下依序套用。';

  @override
  String get nodeprogTimelineCreateNameLabel => '時間軸名稱';

  @override
  String get nodeprogTimelineCreateNameHint => '例：朋友 / 相片';

  @override
  String get nodeprogTimelineTempSearchOnly => '這是由外掛排列的時間軸。此處只能搜尋';

  @override
  String get nodeprogTimelineTempChanged => '此時間軸已被暫時變更（未儲存）。';

  @override
  String get nodeprogTimelineTempRevert => '還原';

  @override
  String get nodeprogTimelineTempSave => '依此內容儲存';

  @override
  String get nodeprogTimelineTempNotice => '此處的變更是暫時的。儲存前原設定不會改變';

  @override
  String get nodeprogTimelineTempNoticeDetail => '此處的變更會暫時作用於此時間軸。儲存前原設定不會改變。';

  @override
  String get nodeprogTimelineCreateCaption => '選擇要匯入的時間軸和演算法，然後點按「確定」';

  @override
  String get nodeprogTimelineHandEdited => '此時間軸已在節點編輯器中編輯。在此變更會將其覆寫';

  @override
  String get nodeprogTimelineHandEditedDetail => '此時間軸已在節點編輯器中編輯。在此變更會替換為簡易配置。';

  @override
  String get nodeprogTimelineAlgorithmsHeader => '演算法';

  @override
  String get nodeprogTimelineAddAlgorithm => '新增演算法';

  @override
  String nodeprogTimelineSectionSubtitle(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '區段 · $count / $max',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineDisabledSuffix => ' · 已停用';

  @override
  String get nodeprogTimelineDisabled => '已停用';

  @override
  String get nodeprogTimelineMetaSeparator => ' · ';

  @override
  String get nodeprogTimelineSectionMenuTooltip => '區段操作';

  @override
  String get nodeprogTimelineAddNode => '新增節點';

  @override
  String get nodeprogTimelineNodeMenuTooltip => '節點操作';

  @override
  String get nodeprogTimelineSectionRename => '變更標題';

  @override
  String get nodeprogTimelineSectionRenameTitle => '區段標題';

  @override
  String get nodeprogTimelineMenuTakeOut => '移出區段';

  @override
  String get nodeprogTimelineDisplayHeader => '顯示模式';

  @override
  String nodeprogTimelineDisplayTitle(String mode) {
    return '顯示：$mode';
  }

  @override
  String get nodeprogTimelineDisplaySubtitle =>
      '將相同的貼文以一般時間軸 / 對話串（關聯時間軸）/ 依發文者排列的方式顯示';

  @override
  String get nodeprogTimelineSourcesHeader => 'SNS 時間軸';

  @override
  String get nodeprogTimelineReorderDone => '完成排序';

  @override
  String get nodeprogTimelineTrendPageCaption =>
      '在搜尋首頁由上而下顯示。用區段區分趨勢和 Today 區域';

  @override
  String get nodeprogTimelineTrendPageCaptionDetail =>
      '在搜尋首頁由上而下顯示。預設包含「趨勢」（所有帳號的趨勢卡片）和「Today」區段。演算法作用於趨勢卡片（無法使用負載較重的演算法）。';

  @override
  String get nodeprogTimelineSourcesCaption => '疊加多個時會合併為一條，相同的貼文只顯示一次';

  @override
  String get nodeprogTimelineSourcesCaptionDetail =>
      '疊加多個時會合併為一條，相同的貼文會摺疊為一張卡片（用卡片上的 ↓ 切換帳號）。貼文加工外掛在各時間軸提供方（SNS 外掛）一側套用。';

  @override
  String get nodeprogTimelineReorderHint => '長按即可拖曳。也可以移入或移出區段（最多 3 個）';

  @override
  String get nodeprogTimelineAddSource => '新增時間軸';

  @override
  String get nodeprogTimelineClockHeader => '自動重新整理';

  @override
  String nodeprogTimelineClockInterval(String interval) {
    return '間隔：$interval';
  }

  @override
  String get nodeprogTimelineAlgorithmMenuTooltip => '演算法操作';

  @override
  String get nodeprogTimelineSourceMenuTooltip => '時間軸操作';

  @override
  String nodeprogTimelineTendencyGenres(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '喜歡的類型 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyDisliked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '不喜歡 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '範例 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyStimulus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '刺激程度上限 $count',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTendencyPinnedTitle => '傾向/刺激程度（傾向）';

  @override
  String get nodeprogTimelineTendencyPinnedSubtitle => '永遠最後';

  @override
  String get nodeprogTimelineTendencyPinnedEmpty => '傾向 FOW 的設定';

  @override
  String get nodeprogTimelineTendencyPinnedInfo =>
      '將在傾向 FOW 中設定的傾向/刺激程度套用於演算法的最後。此處無法移除（如需變更或停止，請在傾向 FOW 中操作）';

  @override
  String get nodeprogTimelineParamsSuggestWhat => '依什麼推薦？';

  @override
  String get nodeprogTimelineParamsSuggestFrom => '從什麼中讀取？';

  @override
  String get nodeprogTimelineParamsPluginPending => '此外掛的設定正在準備中。';

  @override
  String get nodeprogTimelineParamsQueryFilter =>
      '搜尋字詞為空時，依此頁面的搜尋字詞/標籤篩選。可以在下方的欄位中指定字詞。';

  @override
  String get nodeprogTimelineParamsTendency => '使用偏好設定。可以在下方變更。';

  @override
  String get nodeprogTimelineParamsChrono => '時間順序沒有參數。';

  @override
  String get nodeprogTimelineParamsPluginPendingDetail =>
      '此外掛的參數（RRL 設定頁面）將在節點定義發布（商店整合）後顯示在此處。';

  @override
  String get nodeprogTimelineParamsTendencyDetail =>
      '使用 storage.safe 中的趨勢設定檔。可以透過下方選項編輯傾向/刺激程度、喜歡的類型以及從操作中選擇類型（與搜尋首頁的趨勢 ⚙ 相同）。';

  @override
  String get nodeprogTimelineParamsTrendPlugin => '以所選形式顯示趨勢外掛給出的候選字詞。';

  @override
  String get nodeprogTimelineParamsTrendPluginDetail =>
      '將 trend.suggest 插槽的答案（候選字詞）以下列形式顯示：取得趨勢 = 趨勢卡片 / Today = 熱門字詞貼文摘要 / 自訂 = 候選標籤。數量在 … 中設定。';

  @override
  String get nodeprogTimelineParamsForm => '形式';

  @override
  String get nodeprogTimelineParamsRasq => '匯入自己和追蹤對象的 RASQ 貼文。僅在登入 RASQ 時顯示。';

  @override
  String get nodeprogTimelineParamsRasqDetail =>
      '匯入自己和追蹤中的 RASQ 帳號的貼文 / 轉播。僅在登入 RASQ 帳號時顯示。沒有參數。';

  @override
  String get nodeprogTimelineParamsRasqSearch => '搜尋並匯入 RASQ 的公開貼文。也包括未追蹤者的貼文。';

  @override
  String get nodeprogTimelineParamsRasqSearchDetail =>
      '使用下方的搜尋字詞搜尋並匯入 RASQ 的公開貼文（無論是否追蹤）。留空時依此頁面的搜尋字詞 / 標籤搜尋。將顯示模式設為「使用者」後，會以發文者卡片排列。';

  @override
  String get nodeprogTimelineParamsRasqList => '匯入 RASQ 清單的貼文。在下方選擇後會追蹤該清單。';

  @override
  String get nodeprogTimelineParamsRasqListDetail =>
      '匯入 RASQ 清單的貼文（檢視時由 Central 收集清單成員的貼文）。在下方欄位中從自己的清單、追蹤中的清單中選擇，或搜尋公開清單。選擇後會追蹤該清單。';

  @override
  String nodeprogTimelineParamsSelfDetail(String name) {
    return '直接匯入$name。沒有參數。';
  }

  @override
  String get nodeprogTimelineParamsAccount => '帳號';

  @override
  String get nodeprogTimelineParamsTlKind => '時間軸類型（此 SNS 可提供的）';

  @override
  String get nodeprogTimelineParamsList => '清單（此帳號的）';

  @override
  String get nodeprogTimelineParamsNoLists => '此帳號沒有清單（或無法取得）。';

  @override
  String get nodeprogTimelineParamsFeed => '自訂動態（在下方欄位中搜尋並選擇）';

  @override
  String get nodeprogTimelineParamsTendencyEdit => '趨勢的傾向/刺激程度';

  @override
  String get nodeprogTimelineParamsGenresEdit => '喜歡的類型/方向';

  @override
  String get nodeprogTimelineParamsPickGenresSubtitle => '依相似話題歸類，從話題性強的開始';

  @override
  String get nodeprogTimelineParamsRasqSearchWordLabel =>
      '搜尋字詞（留空 = 此頁面的字詞 / 標籤）';

  @override
  String get nodeprogTimelineParamsRasqListSearchLabel =>
      '搜尋 RASQ 清單（名稱 / @建立者 / 分享連結）';

  @override
  String get nodeprogTimelineParamsFeedSearchLabel => '搜尋動態';

  @override
  String get nodeprogTimelineParamsFeedNotFound => '找不到';

  @override
  String get nodeprogTimelineParamsQueryLabel => '搜尋字詞（留空 = 此頁面的搜尋字詞）';

  @override
  String get nodeprogTimelineParamsExcludeTitle => '排除包含此字詞的貼文';

  @override
  String get nodeprogTimelineParamsExcludeSubtitle => '關閉時僅保留包含此字詞的貼文';

  @override
  String get nodeprogTimelineCreateTitle => '建立時間軸';

  @override
  String nodeprogTimelineCreateDefaultName(int number) {
    return '時間軸 $number';
  }

  @override
  String get nodeprogTimelineCreateShareTitle => '是否也套用到其他帳號？';

  @override
  String get nodeprogTimelineCreateShareMessage =>
      '選擇「套用到所有帳號」後，所有帳號都會顯示此時間軸，內容的變更也會作用於全部帳號（之後可以在 … 選單中變更）。';

  @override
  String get nodeprogTimelineCreateShareConfirm => '套用到所有帳號';

  @override
  String get nodeprogTimelineCreateShareCancel => '僅此帳號';

  @override
  String get nodeprogTimelineLoadFailed => '無法載入';

  @override
  String get nodeprogTimelineNodeTrend => '趨勢';

  @override
  String get nodeprogTimelineNodeTabFallback => '節點時間軸';

  @override
  String get nodeprogTimelineReload => '重新載入';

  @override
  String get nodeprogTimelineAstellEmpty => '目前沒有開放的 ASTell';

  @override
  String nodeprogTimelineAstellEmptyQuery(String query) {
    return '沒有關於「$query」的 ASTell';
  }

  @override
  String get nodeprogTimelineSwingEmpty => '目前沒有 Swing';

  @override
  String nodeprogTimelineSwingEmptyQuery(String query) {
    return '沒有關於「$query」的 Swing';
  }

  @override
  String get nodeprogTimelineTrendEmpty => '尚無趨勢';

  @override
  String get nodeprogTimelineTrendFollowingNoQuery => '在趨勢時間軸中顯示';

  @override
  String get nodeprogTimelineTrendFollowingEmpty => '尚無追蹤對象的反應';

  @override
  String get nodeprogTimelinePostsEmpty => '尚無內容';

  @override
  String get nodeprogTimelineEventsEmpty => '尚無對話串';

  @override
  String get nodeprogTimelineUsersEmpty => '尚無使用者';

  @override
  String nodeprogTimelineUserPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則貼文',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTempSemantics => '暫時變更時間軸';

  @override
  String get nodeprogTimelineSearchPrev => '上一則符合的貼文';

  @override
  String get nodeprogTimelineSearchNext => '下一則符合的貼文';

  @override
  String get nodeprogTimelineSearchHint => '在此時間軸中搜尋';

  @override
  String get nodeprogTimelineSearchFuzzy => '模糊搜尋';

  @override
  String get nodeprogTimelineTempClose => '關閉';

  @override
  String get nodeprogTimelineTempTitle => '暫時變更時間軸';

  @override
  String get nodeprogTimelinePaletteSuggestTitle => '推薦';

  @override
  String get nodeprogTimelinePaletteSuggestDescription => '將與你的貼文或反應相近的貼文排到前面。';

  @override
  String get nodeprogTimelinePaletteSuggestDetail =>
      '從[貼文內容/回應/對話內容]中讀取[關鍵字/相似度]，將符合的貼文排到前面。';

  @override
  String get nodeprogTimelinePaletteFilterTitle => '篩選';

  @override
  String get nodeprogTimelinePaletteFilterDescription => '排除與你的貼文或反應不符的貼文。';

  @override
  String get nodeprogTimelinePaletteFilterDetail =>
      '從[貼文內容/回應/對話內容]中讀取[關鍵字/相似度]，排除不符合的貼文（參數與推薦相同）。';

  @override
  String get nodeprogTimelinePaletteQueryFilterTitle => '搜尋篩選';

  @override
  String get nodeprogTimelinePaletteQueryFilterDescription =>
      '僅保留符合此頁面搜尋字詞/標籤（或指定字詞）的貼文。';

  @override
  String get nodeprogTimelinePaletteTendencyTitle => '傾向/刺激程度';

  @override
  String get nodeprogTimelinePaletteTendencyDescription =>
      '排除不符合偏好設定的貼文，並依符合程度排序。';

  @override
  String get nodeprogTimelinePaletteTendencyDetail =>
      '排除不符合趨勢設定檔（喜歡的類型/方向、傾向門檻、刺激程度上限）的貼文，並依適配度排序。設定檔可在搜尋首頁的趨勢 ⚙ 中編輯。';

  @override
  String get nodeprogTimelinePalettePickGenresTitle => '從操作中選擇類型';

  @override
  String get nodeprogTimelinePalettePickGenresDescription =>
      '從你回應過的貼文的話題中選擇喜歡的類型。';

  @override
  String get nodeprogTimelinePalettePickGenresDetail =>
      '將你回應過的貼文依相似話題歸類，從話題性強的開始以「喜歡 / 不喜歡」決定喜歡的類型（傾向/刺激程度元件會使用此設定檔）。';

  @override
  String get nodeprogTimelinePaletteChronoTitle => '時間順序';

  @override
  String get nodeprogTimelinePaletteChronoDescription => '依取得時的時間順序排列。';

  @override
  String get nodeprogTimelinePaletteThisDmDescription => '直接匯入此 DM 頁面的訊息。';

  @override
  String get nodeprogTimelinePaletteThisDmDetail =>
      '直接匯入此 DM 頁面的訊息（在通用設定中為各頁面的 DM）。';

  @override
  String get nodeprogTimelinePaletteSearchResultsDescription =>
      '匯入用此帳號搜尋此頁面搜尋字詞 / 標籤的結果。';

  @override
  String get nodeprogTimelinePaletteRasqPostsTitle => 'RASQ 貼文';

  @override
  String get nodeprogTimelinePaletteRasqPostsDescription =>
      '匯入自己和追蹤對象的 RASQ 貼文。';

  @override
  String get nodeprogTimelinePaletteRasqPostsDetail =>
      '匯入自己和追蹤中的 RASQ 帳號的貼文 / 轉播。可以與 SNS 貼文混合在同一時間軸中。';

  @override
  String get nodeprogTimelinePaletteTimelineTitle => '時間軸';

  @override
  String get nodeprogTimelinePaletteTimelineDescription => '匯入帳號的時間軸。新增後可選擇類型。';

  @override
  String get nodeprogTimelinePaletteTimelineDetail =>
      '匯入帳號的基本時間軸。新增後可在卡片上選擇帳號以及該 SNS 提供的類型（追蹤中 / 本地 / 全域 / Discover …）。';

  @override
  String get nodeprogTimelinePaletteListTlTitle => '清單時間軸';

  @override
  String get nodeprogTimelinePaletteListTlDescription => '匯入帳號的清單。新增後可選擇清單。';

  @override
  String get nodeprogTimelinePaletteListTlDetail =>
      '匯入帳號及該帳號所含清單的時間軸（新增後在卡片上選擇）。';

  @override
  String get nodeprogTimelinePaletteFeedTitle => '自訂動態（Bluesky）';

  @override
  String get nodeprogTimelinePaletteFeedDescription => '尋找並匯入 Bluesky 的自訂動態。';

  @override
  String get nodeprogTimelinePaletteFeedDetail =>
      '搜尋並匯入 Bluesky 的自訂動態（跨 SNS 的清單請使用「RASQ 清單」）。';

  @override
  String get nodeprogTimelinePaletteRasqListTitle => 'RASQ 清單';

  @override
  String get nodeprogTimelinePaletteRasqListDescription =>
      '匯入彙集多個 SNS 使用者的清單中的貼文。';

  @override
  String get nodeprogTimelinePaletteRasqListDetail =>
      '匯入 RASQ 清單（將 Misskey / Mastodon / Bluesky 的使用者彙集為一個清單）中的貼文。從自己的清單、追蹤中的清單中選擇，或搜尋公開清單。僅能選擇可取得清單成員資訊的清單（有同一伺服器的帳號 / 追蹤了其中的成員）。';

  @override
  String get nodeprogTimelinePaletteTrendDescription =>
      '匯入目前的趨勢。新增後可切換類型（趨勢卡片 / 趨勢時間軸）。';

  @override
  String get nodeprogTimelinePaletteTrendDetail =>
      '趨勢卡片 = 伺服器趨勢字詞的卡片；趨勢時間軸 = 將目前熱門趨勢標籤的搜尋結果合併為一條的貼文。';

  @override
  String get nodeprogTimelinePaletteTrendFollowingDescription =>
      '顯示追蹤對象發布的關於此頁面字詞 / 標籤的貼文。';

  @override
  String nodeprogTimelinePaletteDmPeerDescription(String peer) {
    return '匯入與 @$peer 的 DM。';
  }

  @override
  String get nodeprogTimelinePaletteSectionDescription =>
      '最多容納 3 個節點的框。在螢幕上依加入順序顯示在標題下方。';

  @override
  String get nodeprogTimelinePaletteAstellDescription =>
      '以卡片顯示目前開放的 ASTell 房間。';

  @override
  String get nodeprogTimelinePaletteSwingDescription => '列出正在發出 Swing 的人。';

  @override
  String nodeprogTimelinePaletteTrendPluginTitle(String form, String name) {
    return '$form:$name';
  }

  @override
  String nodeprogTimelinePaletteTrendPluginDetail(String form) {
    return '$form（以此形式的節點顯示 trend.suggest 插槽的答案）';
  }

  @override
  String nodeprogTimelinePaletteTodayTitle(String account) {
    return 'Today:$account';
  }

  @override
  String get nodeprogTimelinePaletteSnsPluginAuthor => 'SNS 外掛';

  @override
  String get nodeprogTimelinePaletteListsAuthor => '清單類';

  @override
  String get nodeprogTimelinePaletteTodayDescription => '匯入此帳號的 Today（熱門貼文）。';

  @override
  String nodeprogTimelinePaletteTrendTagsTitle(String account) {
    return '趨勢：$account';
  }

  @override
  String get nodeprogTimelinePaletteTrendTagsAllDescription =>
      '以卡片顯示 RASQ 帳號下所有 SNS 帳號的趨勢字詞。';

  @override
  String get nodeprogTimelinePaletteTrendTagsDescription =>
      '以卡片顯示此帳號所在伺服器的趨勢字詞。';

  @override
  String nodeprogTimelinePaletteSearchResultsTitle(String account) {
    return '搜尋結果：$account';
  }

  @override
  String nodeprogTimelinePaletteSelfDescription(String name) {
    return '直接匯入$name。';
  }

  @override
  String get nodeprogTimelinePaletteRasqSearchDescription =>
      '搜尋並匯入 RASQ 貼文，包括未追蹤者的貼文。使用顯示模式「使用者」可顯示為使用者卡片。';

  @override
  String get nodeprogTimelinePaletteEmptyTitle => '找不到元件';

  @override
  String get nodeprogTimelinePaletteEmptyHint => '請嘗試更換搜尋字詞';

  @override
  String get notificationsPrefReaction => '通知回應';

  @override
  String get notificationsPrefRepost => '通知轉貼';

  @override
  String get notificationsPrefQuote => '通知引用';

  @override
  String get notificationsPrefAstell => '通知 ASTell';

  @override
  String get notificationsPrefTimer => '通知定時書籤';

  @override
  String get notificationsPrefPollEnded => '通知投票結束';

  @override
  String get notificationsPrefFollow => '通知追蹤';

  @override
  String get notificationsPrefSystem => '顯示系統通知';

  @override
  String get notificationsPrefOther => '推送其他通知';

  @override
  String get notificationsTabAll => '全部';

  @override
  String get notificationsTabFollowing => '追蹤中';

  @override
  String get notificationsPrefsTitle => '通知設定檔設定';

  @override
  String get notificationsEmptyFollowing => '沒有來自追蹤對象的通知';

  @override
  String get notificationsClose => '關閉';

  @override
  String get notificationsPrefEnabled => '開啟通知';

  @override
  String get notificationsPushTitle => '接收推播通知';

  @override
  String get notificationsPushDetail => '僅用於通知的存取權杖';

  @override
  String get notificationsQuickReadAll => '將所有通知標為已讀';

  @override
  String get notificationsQuickReadFollowing => '將追蹤對象的通知標為已讀';

  @override
  String get notificationsQuickOff => '關閉通知';

  @override
  String get notificationsEmpty => '沒有通知';

  @override
  String get notificationsRetry => '重新載入';

  @override
  String get notificationsRemindersHeader => '已登記開始通知的 ASTell';

  @override
  String notificationsReminderSchedule(String when) {
    return '預定於 $when';
  }

  @override
  String get notificationsReminderCancel => '取消';

  @override
  String get notificationsSystemFallbackTitle => '系統通知';

  @override
  String notificationsActorsOne(String name) {
    return '$name';
  }

  @override
  String notificationsActorsTwo(String first, String second) {
    return '$first、$second';
  }

  @override
  String notificationsActorsMore(String first, String second, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$first、$second等另外 $count 人',
    );
    return '$_temp0';
  }

  @override
  String notificationsActionReacted(String names) {
    return '$names回應了你的貼文';
  }

  @override
  String notificationsActionReposted(String names) {
    return '$names轉貼了你的貼文';
  }

  @override
  String notificationsActionPollEnded(String names) {
    return '$names的投票已結束';
  }

  @override
  String notificationsActionOther(String names) {
    return '$names的通知';
  }

  @override
  String get notificationsMenuTooltip => '選單';

  @override
  String notificationsFollowFollowed(String name) {
    return '$name追蹤了你';
  }

  @override
  String notificationsFollowRequested(String name) {
    return '$name向你傳送了追蹤請求';
  }

  @override
  String notificationsFollowAccepted(String name) {
    return '$name接受了你的追蹤請求';
  }

  @override
  String notificationsFollowListAdded(String name) {
    return '$name將你加入了清單';
  }

  @override
  String get notificationsFollowButton => '追蹤';

  @override
  String get notificationsFollowingButton => '追蹤中';

  @override
  String get notificationsPostReply => '回覆';

  @override
  String get notificationsPostQuote => '引用';

  @override
  String get notificationsPostMention => '提及';

  @override
  String get notificationsTimerAstell => '已加入書籤的 ASTell 即將開始！';

  @override
  String get notificationsTimerBookmark => '定時書籤';

  @override
  String get notificationsRasqLoadError => '無法載入';

  @override
  String get notificationsRasqEmpty => '沒有 RASQ 通知';

  @override
  String get notificationsRasqEmptyHint => '收到提及 / 回覆 / 引用 / Swing 邀請時會顯示在這裡';

  @override
  String get notifyPushChannelName => 'RASQ 通知';

  @override
  String get notifyPushChannelDescription => '提及、回覆、Swing 等通知';

  @override
  String get notifyOpenAction => '開啟';

  @override
  String get notifyGlimpseChannelName => '讀取螢幕';

  @override
  String get notifyGlimpseChannelDescription => '點按後，將簡單讀取目前顯示的螢幕內容';

  @override
  String get notifyAstellChannelName => 'ASTell 開始';

  @override
  String get notifyAstellChannelDescription => '已加入書籤的 ASTell 開始時通知';

  @override
  String get onboardingBack => '返回';

  @override
  String get onboardingHandleTooShort => '至少需要 3 個字元';

  @override
  String get onboardingHandleTooLong => '最多 32 個字元';

  @override
  String get onboardingHandleInvalid => '只能使用小寫英文字母、數字和 _';

  @override
  String get onboardingAccountTitleNew => '建立新的 RASQ 帳號';

  @override
  String get onboardingAccountTitle => '建立 RASQ 帳號';

  @override
  String get onboardingAccountDescription =>
      'RASQ 帳號是把你登入的 SNS 帳號彙整在一起的「你」的容器。已安裝的外掛、設定和帳號組合也能在其他裝置上使用。';

  @override
  String get onboardingHandleLabel => '使用者名稱（@ 後面的名字）';

  @override
  String get onboardingHandleHelper => '3~32 個小寫英文字母、數字或 _';

  @override
  String onboardingPasswordLabel(int min) {
    return '密碼（至少 $min 個字元）';
  }

  @override
  String get onboardingPasswordHide => '隱藏';

  @override
  String get onboardingPasswordShow => '顯示';

  @override
  String get onboardingPasswordConfirmLabel => '密碼（確認）';

  @override
  String get onboardingPasswordMismatch => '密碼不一致';

  @override
  String get onboardingPasswordCaption => '從其他裝置或網頁版登入此帳號時使用。';

  @override
  String get onboardingAgeHeading => '年齡';

  @override
  String get onboardingAgeCaption =>
      'RASQ 供 13 歲以上的人使用。未滿 18 歲的人將在下一頁確認監護人的同意。';

  @override
  String get onboardingNoCentral => '尚未設定 RASQ Central 的連線位址';

  @override
  String get onboardingSetCentral => '設定連線位址';

  @override
  String get onboardingNext => '下一步';

  @override
  String onboardingCreateFailed(String error) {
    return '無法建立 RASQ 帳號：$error';
  }

  @override
  String get onboardingTermsTitle => '使用條款與隱私權政策';

  @override
  String get onboardingTermsNoDraft => '請先在第 ① 頁填寫使用者名稱等資訊';

  @override
  String get onboardingTermsRead => '閱讀使用條款';

  @override
  String get onboardingPrivacyRead => '閱讀隱私權政策';

  @override
  String get onboardingAgree => '同意使用條款與隱私權政策';

  @override
  String get onboardingChildSafeHeading => '兒童安全（未滿 18 歲）';

  @override
  String onboardingChildSafeNote(String age) {
    return '$age的人需要取得監護人的同意。與監護人的 RASQ 帳號連結後，監護人可以決定使用方式（可見貼文的強度、使用時間和可用功能）（設定 → 兒童安全 → 兒童模式）。';
  }

  @override
  String get onboardingGuardianConsent => '已取得監護人同意';

  @override
  String get onboardingChildLogin => '使用監護人提供的代碼登入';

  @override
  String get onboardingChildLoginCaption =>
      '如果監護人已為你建立帳號，請不要在這裡註冊，而是使用收到的代碼登入。';

  @override
  String get onboardingBundleHeading => '帳號組合';

  @override
  String get onboardingBundleReplace => '以此裝置上的 SNS 帳號取代';

  @override
  String onboardingBundleReplaceSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '將已登入的 $count 個帳號彙整到此 RASQ 帳號',
    );
    return '$_temp0';
  }

  @override
  String get onboardingBundleKeep => '不取代';

  @override
  String get onboardingBundleKeepSubtitle => 'SNS 帳號只保留在此裝置上';

  @override
  String get onboardingTermsContributionNote =>
      '「為演算法和社群做出貢獻」不包含在本次註冊中（這是另外的選擇性同意，預設為「不提供」）。你可以隨時刪除 RASQ 帳號。';

  @override
  String get onboardingRegister => '同意並註冊';

  @override
  String get onboardingSnsTitle => '使用 SNS 帳號登入';

  @override
  String get onboardingSnsDescription =>
      'RASQ 帳號已建立。請使用你正在用的社群帳號登入。如果還沒有使用任何社群服務，可以透過「尋找 SNS 服務」找到合適的伺服器或清單。';

  @override
  String onboardingSnsLoginWith(String service) {
    return '使用 $service 登入';
  }

  @override
  String get onboardingSnsPluginLoadNote => '首次登入前會載入外掛。請在網路良好的環境下進行。';

  @override
  String onboardingSignupGuideClosed(String name) {
    return '$name 目前不接受新註冊，或僅限邀請。如果沒有邀請連結，請選擇其他伺服器。';
  }

  @override
  String onboardingSignupGuideMastodonOpened(String name) {
    return '已開啟 $name 的註冊頁面。出現伺服器規則後，請閱讀並點選「同意」。';
  }

  @override
  String get onboardingSignupGuideMastodonForm =>
      '填寫顯示名稱、使用者名稱、電子郵件地址和密碼。使用者名稱之後無法變更，請選一個你喜歡的。';

  @override
  String get onboardingSignupGuideMastodonMail =>
      '點選註冊後，會收到一封確認郵件。請開啟郵件中的連結，驗證你的電子郵件地址。';

  @override
  String onboardingSignupGuideOpened(String name) {
    return '已開啟 $name 的頁面。請點選頁面上的「註冊」。';
  }

  @override
  String get onboardingSignupGuideForm => '設定使用者名稱和密碼。使用者名稱之後無法變更，請選一個你喜歡的。';

  @override
  String get onboardingSignupGuideChecks =>
      '依伺服器而定，可能會要求填寫電子郵件地址、邀請碼或進行機器人驗證。請依照螢幕上的指示填寫。';

  @override
  String get onboardingSignupGuideRules =>
      '閱讀並同意伺服器的規則（使用條款）。如果要求確認電子郵件，請開啟收到的郵件中的連結。';

  @override
  String get onboardingSignupGuideDone => '註冊完成後，請點選下方的「已註冊」。RASQ 會登入此伺服器。';

  @override
  String get onboardingSignupGuideThenPost => '登入後，將開啟剛才的貼文。';

  @override
  String onboardingSignupGuideThenList(String name) {
    return '登入後，將開啟 RASQ 清單「$name」。';
  }

  @override
  String get onboardingSignupGuideRasqLater => '之後可以在側邊欄的 … 中建立 RASQ 帳號。';

  @override
  String get onboardingSignupTitleFallback => '註冊伺服器';

  @override
  String get onboardingSignupNoTarget => '未選擇要註冊的伺服器';

  @override
  String get onboardingSignupDone => '已註冊（前往登入）';

  @override
  String onboardingSignupTitle(String name) {
    return '註冊 $name';
  }

  @override
  String get onboardingSignupGuideHeading => 'RAi 指南';

  @override
  String get onboardingSignupGuidePrev => '上一步';

  @override
  String get onboardingSignupNoWebView =>
      '此裝置無法在 App 內開啟註冊頁面。請在瀏覽器中開啟並註冊，完成後回到此畫面。';

  @override
  String get onboardingSignupOpenBrowser => '在瀏覽器中開啟註冊頁面';

  @override
  String onboardingSignupPostNotFound(String account) {
    return '在 $account 上找不到剛才的貼文';
  }

  @override
  String get onboardingEntryCreateNew => '建立新的 RASQ 帳號';

  @override
  String get onboardingEntryCreate => '建立 RASQ 帳號';

  @override
  String get onboardingEntryLogin => '登入 RASQ 帳號';

  @override
  String get onboardingEntryDiscover => '尋找社群服務（透過圖片、使用者或 RAi）';

  @override
  String onboardingEntryResume(String name) {
    return '以 $name 繼續';
  }

  @override
  String onboardingEntryResumeWithHandle(String name, String handle) {
    return '以 $name（@$handle）繼續';
  }

  @override
  String get onboardingEntryResumeFallbackName => 'RASQ 帳號';

  @override
  String get onboardingEntrySnsOnly => '僅使用 SNS 帳號';

  @override
  String get onboardingEntrySkip => '略過，僅在此裝置上使用';

  @override
  String get onboardingEntryHaveAccount => '我已有 RASQ 帳號';

  @override
  String get onboardingEntryLoginQuestion => '要登入 RASQ 帳號嗎？';

  @override
  String get onboardingEntryCreateQuestion => '要建立 RASQ 帳號嗎？';

  @override
  String get onboardingEntryLoginBody =>
      '登入 RASQ 帳號後，彙整的 SNS 帳號、已安裝的外掛和設定都會回到此裝置上。';

  @override
  String get onboardingEntryCreateBody =>
      'RASQ 帳號是把你登入的 SNS 帳號彙整在一起的「你」的容器。建立後，已安裝的外掛、設定和帳號的彙整方式會儲存到 RASQ Central，在其他裝置上也能以相同狀態使用。';

  @override
  String get onboardingEntryWebNote =>
      '在網頁版中，社群服務的登入資訊會存放在 RASQ 伺服器的保管庫中（使用伺服器的金鑰加密，RASQ 的伺服器可以解密）。也可以僅使用社群帳號，但這樣關閉此分頁後登入狀態就會消失。';

  @override
  String get onboardingEntrySnsOnlyNote =>
      '也可以僅使用 SNS 帳號。這種情況下，已安裝的外掛和設定只會儲存在此裝置中。';

  @override
  String get onboardingEntrySkipNote =>
      '略過也可以使用 RASQ。這種情況下，已安裝的外掛和設定只會儲存在此裝置中（之後可以在側邊欄的 … 中建立）。';

  @override
  String get onboardingShowcaseTitle => '看看伺服器和清單';

  @override
  String get onboardingShowcaseServersHint => '點按即可註冊該伺服器';

  @override
  String get onboardingShowcaseOpenServer => '開啟伺服器';

  @override
  String get onboardingShowcaseSignupServer => '註冊此伺服器';

  @override
  String get onboardingShowcaseListsHint => '跨社群服務的使用者清單。點按即可註冊清單中使用者所在的伺服器';

  @override
  String get onboardingShowcaseListCannotSignup => '無法從 App 註冊此清單的伺服器';

  @override
  String get onboardingShowcasePickServer => '要註冊哪個伺服器？';

  @override
  String onboardingShowcasePickServerSubtitle(String host, String kind) {
    return '$host · $kind';
  }

  @override
  String onboardingShowcasePostImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 張圖片',
    );
    return '$_temp0';
  }

  @override
  String get onboardingGenreGame => '遊戲';

  @override
  String get onboardingGenreAnime => '動漫';

  @override
  String get onboardingGenreMusic => '音樂';

  @override
  String get onboardingGenreArt => '插畫與創作';

  @override
  String get onboardingGenrePhoto => '攝影';

  @override
  String get onboardingGenreFood => '美食';

  @override
  String get onboardingGenreTech => 'IT 與程式設計';

  @override
  String get onboardingGenreAnimal => '動物與寵物';

  @override
  String get onboardingGenreSports => '運動';

  @override
  String get onboardingGenreTravel => '旅行與出遊';

  @override
  String get onboardingGenreBooks => '書籍與閱讀';

  @override
  String get onboardingGenreMovie => '電影與影集';

  @override
  String get onboardingGenreNature => '季節與自然';

  @override
  String onboardingPasswordTooShort(int min) {
    return '至少需要 $min 個字元';
  }

  @override
  String get onboardingPasswordTooLong => '最多 256 個字元';

  @override
  String get onboardingPasswordRepeated => '不能使用重複的同一個字元';

  @override
  String get onboardingTermsOutdated => '使用條款已更新。請更新 App 後重新註冊';

  @override
  String get onboardingNoServer => '尚未設定 RASQ 伺服器的連線位址';

  @override
  String get onboardingHandleTaken => '此使用者名稱已被使用';

  @override
  String onboardingHandleUnusable(String error) {
    return '此使用者名稱無法使用（$error）';
  }

  @override
  String onboardingHandleKept(String reason, String handle) {
    return '$reason。使用者名稱維持為 @$handle（可在編輯個人檔案中變更）';
  }

  @override
  String onboardingPasswordSetFailed(String error) {
    return '帳號已建立，但無法設定密碼（$error）。請在設定 →「帳號保護」中設定';
  }

  @override
  String get onboardingRestored => '已切換回此裝置的 RASQ 帳號';

  @override
  String get onboardingNudgeTitle => '要建立 RASQ 帳號嗎？';

  @override
  String get onboardingNudgeMessage =>
      '有了 RASQ 帳號，已安裝的外掛、設定和社群帳號組合也能在其他裝置上使用。Swing 和 RASQ 清單也需要透過 RASQ 帳號使用。之後也可以在側邊欄的 … 中建立。';

  @override
  String get onboardingNudgeCreate => '建立';

  @override
  String get onboardingNudgeLogin => '登入（已有帳號）';

  @override
  String get onboardingNudgeLater => '稍後再說';

  @override
  String onboardingNudgeCreated(String handle) {
    return '已建立 RASQ 帳號 @$handle';
  }

  @override
  String get onboardingFeedTitle => '來自公開的 RASQ 清單';

  @override
  String get onboardingFeedCaption => '跨社群服務的使用者清單中閱讀量高的貼文';

  @override
  String get onboardingFeedEmpty => '目前沒有可顯示的貼文';

  @override
  String onboardingFeedListName(String name) {
    return '清單「$name」';
  }

  @override
  String get onboardingDiscoverTitle => '尋找 SNS 服務';

  @override
  String get onboardingDiscoverIntro =>
      '從你喜歡的東西出發，尋找適合你的社群網路伺服器和 RASQ 清單（跨社群網路的人員清單）。';

  @override
  String get onboardingDiscoverContentTitle => '從喜歡的圖片或內容中尋找';

  @override
  String get onboardingDiscoverContentSubtitle => '選擇圖片，圈出想搜尋的部分';

  @override
  String get onboardingDiscoverPeopleTitle => '從熱門使用者 / 網紅中尋找';

  @override
  String get onboardingDiscoverPeopleSubtitle => '透過喜歡的人的名字或領域';

  @override
  String get onboardingDiscoverExportTitle => '從其他社群網路的匯出資料中尋找';

  @override
  String get onboardingDiscoverExportSubtitle => '即將推出';

  @override
  String get onboardingDiscoverAskTitle => '問問 RAi';

  @override
  String get onboardingDiscoverAskSubtitle => '邊聊邊尋找適合你的社群網路';

  @override
  String get onboardingDiscoverRaiBlocked => '監護人已停用 RAi';

  @override
  String onboardingDiscoverCannotLogin(String host) {
    return '無法從 App 登入 $host';
  }

  @override
  String onboardingDiscoverCannotSignup(String host) {
    return '無法從 App 註冊 $host';
  }

  @override
  String get onboardingDiscoverAddAccountBlocked => '監護人已禁止新增 SNS 帳號';

  @override
  String get onboardingDiscoverDummyResult => '這是範例結果（伺服器的外部服務尚未設定）';

  @override
  String get onboardingDiscoverPeopleWebHeading => '社群網路上的人（網頁搜尋）';

  @override
  String get onboardingDiscoverListsHeading => 'RASQ 清單';

  @override
  String get onboardingDiscoverServersHeading => '伺服器';

  @override
  String onboardingDiscoverListMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverListOwner(String handle) {
    return '@$handle 的清單';
  }

  @override
  String onboardingDiscoverListHosts(String hosts) {
    return '伺服器：$hosts';
  }

  @override
  String get onboardingDiscoverListSeparator => '、';

  @override
  String get onboardingDiscoverListOpenImport => '開啟清單並匯入';

  @override
  String get onboardingDiscoverListSignup => '在清單中使用者所在的伺服器註冊';

  @override
  String get onboardingDiscoverLoginButton => '登入';

  @override
  String get onboardingDiscoverSignupButton => '註冊';

  @override
  String get onboardingDiscoverSearchFailed => '搜尋失敗。請稍後再試';

  @override
  String get onboardingDiscoverGlimpseStoppedSystem =>
      '螢幕讀取已被停止（裝置上的「停止分享」或螢幕鎖定）。請從「在常用瀏覽器中瀏覽並尋找」重新開始';

  @override
  String get onboardingDiscoverGlimpseStoppedShort =>
      '廣播停止得太快，未能讀取。請先在瀏覽器中開啟想搜尋的頁面，然後再停止';

  @override
  String get onboardingDiscoverGlimpseStoppedTimeout => '已過 10 分鐘，已停止螢幕讀取的準備';

  @override
  String get onboardingDiscoverGlimpseStoppedKilled => '螢幕讀取被裝置停止了。請重新開始';

  @override
  String get onboardingDiscoverGlimpseStoppedEmpty => '未能讀取螢幕（未能擷取畫面）';

  @override
  String get onboardingDiscoverGlimpseFailed => '未能讀取螢幕';

  @override
  String get onboardingDiscoverGlimpseBroadcastDenied =>
      '螢幕廣播未能開始。如需讀取，請再次點一下並選擇「開始廣播」（僅讀取停止廣播前的 3 秒）';

  @override
  String get onboardingDiscoverGlimpseDenied =>
      '未允許讀取螢幕。如需讀取，請再次點一下並選擇「開始」（僅讀取點按按鈕後的 3 秒）';

  @override
  String get onboardingDiscoverGlimpseNotificationsDenied =>
      '無法顯示通知。讀取按鈕會顯示在通知中，請在裝置設定中允許 RASQ 的通知';

  @override
  String get onboardingDiscoverGlimpseUnavailable =>
      '此裝置無法讀取螢幕。請選擇圖片，或在 App 內瀏覽器中搜尋';

  @override
  String get onboardingDiscoverNotificationFailed =>
      '無法顯示通知。請在裝置設定中允許 RASQ 的通知';

  @override
  String get onboardingDiscoverGlimpseResultMissing => '找不到讀取的畫面（已過期或已傳送）';

  @override
  String onboardingDiscoverPicksFull(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '最多 $max 張圖片。請先移除再新增',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickFailed => '無法載入圖片';

  @override
  String onboardingDiscoverPicksOver(int over, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      over,
      locale: localeName,
      other: '最多 $max 張圖片。有 $over 張未新增',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPicksUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 張圖片無法載入',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverNoticeSeparator => '。';

  @override
  String onboardingDiscoverPicksSkipped(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已移除 $count 張超出傳送限制（每張 10 MiB、合計 24 MiB、最多 $max 張）的圖片',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverImageFormat => '請選擇 JPEG / PNG / WebP 圖片';

  @override
  String get onboardingDiscoverImageFormatSize =>
      '請選擇 10 MiB 以內的 JPEG / PNG / WebP 圖片';

  @override
  String get onboardingDiscoverNoCentral => '尚未設定 RASQ Central 的連線位址';

  @override
  String get onboardingDiscoverContentIntro =>
      '選擇喜歡的圖片並圈出想搜尋的部分，RAi 會產生搜尋關鍵字。圖片不會儲存在伺服器上（搜尋完成後即捨棄）。';

  @override
  String onboardingDiscoverPicksCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count / $max 張。點按可重新圈選，長按可調整順序',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickImages => '選擇圖片';

  @override
  String get onboardingDiscoverAddImages => '新增圖片';

  @override
  String get onboardingDiscoverTakePhoto => '拍照';

  @override
  String get onboardingDiscoverSearchOne => '用這張圖片搜尋';

  @override
  String onboardingDiscoverSearchMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '用這 $count 張圖片搜尋',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverOtherWays => '其他方式';

  @override
  String get onboardingDiscoverGlimpseButton => '在常用瀏覽器中瀏覽並尋找';

  @override
  String get onboardingDiscoverBrowseButton => '在 App 內瀏覽器中尋找';

  @override
  String get onboardingDiscoverGlimpseCancel => '取消';

  @override
  String onboardingDiscoverGlimpseCapturing(int elapsed, int total) {
    return '正在讀取螢幕（$elapsed / $total 秒）';
  }

  @override
  String onboardingDiscoverGlimpseDone(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '已讀取螢幕 $seconds 秒（$frames 個畫格）',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverGlimpseDoneDummy(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '已讀取螢幕 $seconds 秒（$frames 個畫格）。目前為試用版，使用的是虛擬畫面',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPictureIndex(int index) {
    return '第 $index 張';
  }

  @override
  String onboardingDiscoverFrameIndex(int index) {
    return '第 $index 個畫格';
  }

  @override
  String get onboardingDiscoverQueryHeading => '搜尋關鍵字';

  @override
  String get onboardingDiscoverNoResults => '找不到合適的清單或伺服器';

  @override
  String get onboardingDiscoverPickWhole => '全圖';

  @override
  String get onboardingDiscoverPickRect => '矩形';

  @override
  String get onboardingDiscoverPickLasso => '手繪';

  @override
  String get onboardingDiscoverPickRemove => '移除';

  @override
  String get onboardingDiscoverGlimpseDummyNote => '目前為試用版，不讀取螢幕，而是傳送虛擬畫面';

  @override
  String get onboardingDiscoverCaptureFailed => '無法讀取此頁面';

  @override
  String get onboardingDiscoverBrowseAddressHint => '搜尋內容 / URL';

  @override
  String get onboardingDiscoverBrowseCapture => '從此頁面尋找';

  @override
  String get onboardingDiscoverManualIntro =>
      '此裝置無法在 App 內開啟瀏覽器。請在常用瀏覽器中瀏覽，然後貼上頁面 URL 和你在意的文字。';

  @override
  String get onboardingDiscoverManualOpenBrowser => '開啟瀏覽器';

  @override
  String get onboardingDiscoverManualUrl => '頁面 URL';

  @override
  String get onboardingDiscoverManualText => '在意的文字（選填）';

  @override
  String get onboardingDiscoverManualSubmit => '用此內容搜尋';

  @override
  String get onboardingDiscoverPeopleIntro =>
      '請輸入喜歡的人的名字或感興趣的領域。會先從公開的 RASQ 清單中搜尋。';

  @override
  String get onboardingDiscoverPeopleQueryLabel => '人名 / 領域';

  @override
  String get onboardingDiscoverPeopleQueryHint => '例如：鐵道攝影、插畫家';

  @override
  String get onboardingDiscoverPeopleSearch => '搜尋';

  @override
  String get onboardingDiscoverPeopleNotFound => '在 RASQ 清單中找不到';

  @override
  String get onboardingDiscoverPeopleNotFoundHint => '試試從喜歡的圖片或網頁中尋找，或者問問 RAi。';

  @override
  String get onboardingDiscoverPeopleTryContent => '從圖片或內容中尋找';

  @override
  String get onboardingDiscoverPeopleBrave => 'RASQ 清單中沒有找到，以下是網頁搜尋找到的候選';

  @override
  String get onboardingDiscoverPersonOpenProfile => '在瀏覽器中開啟個人檔案';

  @override
  String get onboardingDiscoverPersonLists => '包含此人的 RASQ 清單';

  @override
  String get onboardingDiscoverAskFailed => '未能回答。請稍後再問一次';

  @override
  String get onboardingDiscoverAskEmptyTitle => '一起尋找適合你的社群網路吧！';

  @override
  String get onboardingDiscoverAskEmptyBody =>
      '告訴我你喜歡什麼、想看什麼、想和什麼樣的人交流。我會幫你尋找適合的社群網路伺服器和 RASQ 清單。';

  @override
  String get onboardingDiscoverAskEmptyCloud => '對話會傳送到 RASQ 伺服器上的 RAi（雲端）。';

  @override
  String get onboardingDiscoverAskModelLabel => '雲端版 RAi';

  @override
  String get onboardingDiscoverAskHint => '你喜歡什麼？';

  @override
  String get onboardingDiscoverEditorTitle => '圈選搜尋';

  @override
  String onboardingDiscoverEditorTitleStep(String step) {
    return '圈選搜尋（$step）';
  }

  @override
  String get onboardingDiscoverEditorHint =>
      '請圈出想搜尋的部分。不圈選直接確定，將用整張圖片搜尋。可用兩指縮放和移動。';

  @override
  String get onboardingDiscoverEditorHintSelected => '只裁切圈選的部分進行搜尋。重新繪製會取代圈選。';

  @override
  String get onboardingDiscoverEditorToolRect => '矩形';

  @override
  String get onboardingDiscoverEditorToolLasso => '手繪';

  @override
  String get onboardingDiscoverEditorResetView => '恢復原始大小';

  @override
  String get onboardingDiscoverEditorClear => '清除圈選';

  @override
  String get onboardingDiscoverEditorDoneWhole => '確定（整張圖片）';

  @override
  String get onboardingDiscoverEditorDone => '確定';

  @override
  String get onboardingDiscoverGlimpseArmedBroadcast =>
      '螢幕廣播已開始。在瀏覽器中開啟想搜尋的頁面後，請透過螢幕頂端的紅色標示（或控制中心）停止廣播。僅讀取停止前的 3 秒，回到 RASQ 後即可看到結果。';

  @override
  String get onboardingDiscoverGlimpseArmedNotification =>
      '已顯示通知。請先在瀏覽器中開啟想搜尋的頁面，然後點按通知。點按後將讀取該頁面 3 秒。';

  @override
  String get onboardingDiscoverGlimpseNotificationTitle => '用 RASQ 尋找';

  @override
  String get onboardingDiscoverGlimpseNotificationBody => '點按即可讀取目前螢幕 3 秒';

  @override
  String get onboardingDiscoverApiImageFormat => '只能傳送 jpeg / png / webp 圖片';

  @override
  String get onboardingDiscoverApiImageSize => '圖片不能超過 10 MiB';

  @override
  String get onboardingDiscoverApiImageAndFrames => '圖片和畫格不能同時傳送';

  @override
  String onboardingDiscoverApiFramesCount(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '畫格最多 $max 張',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverApiFrameFormat => '只能傳送 jpeg / png / webp 畫格';

  @override
  String get onboardingDiscoverApiFrameSize => '每個畫格不能超過 10 MiB';

  @override
  String get onboardingDiscoverApiFramesTotal => '畫格合計不能超過 24 MiB';

  @override
  String get onboardingDiscoverApiEmpty => '需要圖片、內文或 URL 中的任一項';

  @override
  String get onboardingTourPageSnsTitle => '多個 SNS，集中在一處';

  @override
  String get onboardingTourPageSnsBody =>
      '可以集中使用 Misskey、Mastodon、Bluesky 等帳號。有了 RASQ 帳號，設定和帳號分組也能在其他裝置上使用。';

  @override
  String get onboardingTourPageSnsPicture =>
      'Bluesky、Misskey、mixi2、Mastodon 匯集到 RASQ 的插圖';

  @override
  String get onboardingTourPageTimelineTitle => '用節點組建時間軸';

  @override
  String get onboardingTourPageTimelineBody =>
      '可以排列節點，依自己的喜好組建首頁時間軸。趨勢和 Today 也能作為節點放入時間軸。';

  @override
  String get onboardingTourPageTimelineNote => '可以透過時間軸的齒輪圖示變更。';

  @override
  String get onboardingTourPageTimelinePicture =>
      '「SNS 時間軸」「取得趨勢」「Today」節點縱向排列的插圖';

  @override
  String get onboardingTourPageTrendTitle => '趨勢和 Today';

  @override
  String get onboardingTourPageTrendBody =>
      '可以在趨勢和 Today 中查看當下熱門的詞語和貼文。初始時將恐懼、厭惡、憤怒限制在 45% 以內，因此帶有強烈憤怒或厭惡的貼文在推薦 / 趨勢 / Today / 關聯時間軸中會排名靠後或不再顯示。';

  @override
  String get onboardingTourPageTrendNoteSupervised =>
      '此上限可隨時變更。在監護期間，會依監護人的設定進一步限制。';

  @override
  String get onboardingTourPageTrendNote => '此上限可隨時變更。';

  @override
  String get onboardingTourPageTrendPicture => '刺激程度雷達圖';

  @override
  String get onboardingTourPageAstellTitle => '用 ASTell 以聲音相連';

  @override
  String get onboardingTourPageAstellBody =>
      'ASTell 是可以用語音交談的房間。也可以只收聽，從下方的 ASTell 分頁進入。';

  @override
  String get onboardingTourPageAstellPicture => 'ASTell 的天線和表示正在說話的波形';

  @override
  String get onboardingTourPageSwingTitle => '用 Swing 輕鬆分享';

  @override
  String get onboardingTourPageSwingBody =>
      'Swing 是會隨時間消失的貼文。它會送達追蹤者和 RASQ 清單中的人，並在 1~24 小時後消失。';

  @override
  String get onboardingTourPageSwingNote => '需要 RASQ 帳號才能使用。';

  @override
  String get onboardingTourPageSwingPicture => '一排圓形 Swing 圖示的插圖';

  @override
  String get onboardingTourPageRaiTitle => '不知道怎麼做時就問 RAi';

  @override
  String get onboardingTourPageRaiBody =>
      'RAi 是 RASQ 的助理。告訴它你想做什麼，它會帶你找到按鈕的位置，或代你操作。';

  @override
  String get onboardingTourPageRaiPicture => 'RAi 和對話氣泡';

  @override
  String get onboardingTourPagePluginsTitle => '用外掛擴充';

  @override
  String get onboardingTourPagePluginsBody =>
      'SNS、顯示方式和功能都可以透過外掛新增。可以在外掛商店中尋找並安裝。';

  @override
  String get onboardingTourPagePluginsPicture => '一排外掛卡片的插圖';

  @override
  String get onboardingTourTitle => 'RASQ 使用指南';

  @override
  String get onboardingTourSkip => '略過';

  @override
  String get onboardingTourBack => '返回';

  @override
  String onboardingTourPageSemantics(int number, int total) {
    return '第 $number / $total 頁';
  }

  @override
  String get onboardingTourStart => '開始';

  @override
  String get onboardingTourNext => '下一步';

  @override
  String get onboardingTourOpenTendency => '立即查看設定';

  @override
  String get onboardingTourNodeSnsTimeline => 'SNS 時間軸';

  @override
  String get onboardingTourNodeTrend => '取得趨勢';

  @override
  String get onboardingTourRaiBubble => '我想在時間軸中新增清單';

  @override
  String get platformWebRuntimeLoadFailed => '無法載入執行所需的檔案（網路 / CDN）';

  @override
  String get platformWebServerNotConfigured => '尚未設定 RASQ 伺服器的連線位址';

  @override
  String platformWebDownloadFailed(String error) {
    return '下載失敗：$error';
  }

  @override
  String platformWebModelLoadFailed(String error) {
    return '無法載入模型：$error';
  }

  @override
  String get pluginsCancel => '取消';

  @override
  String get pluginsClose => '關閉';

  @override
  String get pluginsSwingNotPackage => 'Swing 外掛須為 .rasqpkg 或 .wasm';

  @override
  String get pluginsSwingNoRequires => '以其他外掛為基礎的子外掛無法透過 Swing 散布';

  @override
  String get pluginsSwingSingleOnly => 'Swing 只能散布僅含一個外掛的套件';

  @override
  String get pluginsPageNotPage => '這不是頁面型外掛';

  @override
  String pluginsPageSwingRequires(String ids) {
    return '因以其他外掛（$ids）為基礎，無法透過 Swing 散布';
  }

  @override
  String get pluginsPageSwingChild => '因是其他外掛套件中的子外掛，無法透過 Swing 散布';

  @override
  String pluginsPageSwingSiblings(String names) {
    return '因與子外掛（$names）在同一個套件中，無法透過 Swing 散布';
  }

  @override
  String pluginsArtifactMismatch(String pluginId) {
    return '$pluginId：重新取得的發布檔案與安裝時不同，因此不載入（請在商店中重新安裝）';
  }

  @override
  String pluginsIsSnsPlugin(String id) {
    return '$id 是 SNS 外掛（無法註冊到插槽）';
  }

  @override
  String get pluginsManifestMissing => '缺少 plugin.manifest';

  @override
  String get pluginsManifestIdEmpty => 'plugin.manifest.id 為空';

  @override
  String get pluginsSwingSurfaceOnly =>
      'Swing 只能散布用於 Swing 介面（surfaces: swing、solo）的頁面型外掛';

  @override
  String get pluginsRasqPageSurfaceOnly =>
      '只有用於個人檔案介面（surfaces: profile、solo）的頁面型外掛才能放在 RASQ 頁面上';

  @override
  String pluginsIdMismatch(String expected, String actual) {
    return '發布套件的目錄為 $expected，但 wasm 自稱 $actual';
  }

  @override
  String pluginsRegistered(String name, String slots) {
    return '已註冊 $name（$slots）';
  }

  @override
  String pluginsRegisterFailed(String error) {
    return '無法註冊：$error';
  }

  @override
  String pluginsImageReceiveFailed(String name, String error) {
    return '$name：無法接收圖片（$error）';
  }

  @override
  String pluginsSharedNoSession(String name) {
    return '$name：未加入共享工作階段，無法變更大家的值';
  }

  @override
  String get pluginsMuteAddTitle => '新增靜音字詞';

  @override
  String pluginsMuteAddMessage(String name, String word) {
    return '$name 想將「$word」新增至靜音字詞。';
  }

  @override
  String get pluginsMuteAddConfirm => '新增';

  @override
  String pluginsMuteAdded(String word) {
    return '已將「$word」新增至靜音字詞';
  }

  @override
  String pluginsEffectSendFailed(String name, String error) {
    return '$name：無法傳送特效影片（$error）';
  }

  @override
  String pluginsImageScaled(String name) {
    return '$name：為了編輯已縮小圖片';
  }

  @override
  String get pluginsErrorReturned => '外掛傳回了錯誤';

  @override
  String get pluginsGenreTone => '色調';

  @override
  String get pluginsGenreProcess => '處理';

  @override
  String get pluginsGenreTransform => '變形';

  @override
  String get pluginsGenreAdd => '新增';

  @override
  String get pluginsGenreDraw => '繪製';

  @override
  String get pluginsTrustFull => '完整';

  @override
  String get pluginsTrustBundled => '完整（內建）';

  @override
  String get pluginsTrustRestricted => '受限';

  @override
  String get pluginsTrustSwing => '受限（Swing）';

  @override
  String get pluginsTrustHint =>
      '以自己的開發者金鑰簽署的 .rspkg / .rasqpkg 擁有完整功能。rasq build 會進行簽署';

  @override
  String get pluginsEditorCancel => '取消';

  @override
  String get pluginsEditorUndo => '復原';

  @override
  String get pluginsEditorRedo => '重做';

  @override
  String get pluginsEditorDone => '完成';

  @override
  String get pluginsEditorRemove => '刪除';

  @override
  String get pluginsEditorBack => '返回';

  @override
  String get pluginsEditorMore => '更多';

  @override
  String get pluginsEditorApplying => '正在套用變更';

  @override
  String get pluginsEditorPreparing => '正在準備編輯器';

  @override
  String get pluginsEditorPleaseWait => '請稍候…';

  @override
  String get pluginsEditorCloseWarningTitle => '要停止編輯嗎？';

  @override
  String get pluginsEditorCloseWarningMessage => '變更將不會儲存。';

  @override
  String get pluginsEditorCloseWarningConfirm => '停止';

  @override
  String get pluginsEditorCloseWarningCancel => '繼續';

  @override
  String get pluginsEditorLayerEdit => '編輯';

  @override
  String get pluginsEditorLayerRotateScale => '旋轉和縮放';

  @override
  String get pluginsEditorPaint => '畫筆';

  @override
  String get pluginsEditorZoom => '縮放';

  @override
  String get pluginsEditorFreehand => '自由繪製';

  @override
  String get pluginsEditorArrow => '箭頭';

  @override
  String get pluginsEditorLine => '直線';

  @override
  String get pluginsEditorRectangle => '矩形';

  @override
  String get pluginsEditorCircle => '圓形';

  @override
  String get pluginsEditorDashLine => '虛線';

  @override
  String get pluginsEditorBlur => '模糊';

  @override
  String get pluginsEditorPixelate => '馬賽克';

  @override
  String get pluginsEditorLineWidth => '線條粗細';

  @override
  String get pluginsEditorEraser => '橡皮擦';

  @override
  String get pluginsEditorFill => '填滿';

  @override
  String get pluginsEditorOpacity => '不透明度';

  @override
  String get pluginsEditorColor => '顏色';

  @override
  String get pluginsEditorTextHint => '輸入文字';

  @override
  String get pluginsEditorText => '文字';

  @override
  String get pluginsEditorTextAlign => '對齊';

  @override
  String get pluginsEditorFontScale => '文字大小';

  @override
  String get pluginsEditorTextBackground => '背景';

  @override
  String get pluginsEditorCropRotate => '裁切 / 旋轉';

  @override
  String get pluginsEditorRotate => '旋轉';

  @override
  String get pluginsEditorFlip => '翻轉';

  @override
  String get pluginsEditorTilt => '傾斜';

  @override
  String get pluginsEditorTiltHorizontal => '水平';

  @override
  String get pluginsEditorTiltVertical => '垂直';

  @override
  String get pluginsEditorRatio => '比例';

  @override
  String get pluginsEditorReset => '重設';

  @override
  String get pluginsEditorTune => '調整';

  @override
  String get pluginsEditorBrightness => '亮度';

  @override
  String get pluginsEditorContrast => '對比度';

  @override
  String get pluginsEditorSaturation => '飽和度';

  @override
  String get pluginsEditorExposure => '曝光';

  @override
  String get pluginsEditorHue => '色相';

  @override
  String get pluginsEditorTemperature => '色溫';

  @override
  String get pluginsEditorFade => '褪色';

  @override
  String get pluginsEditorTint => '色調';

  @override
  String get pluginsEditorFilter => '濾鏡';

  @override
  String get pluginsEditorSticker => '貼圖';

  @override
  String get pluginsEditorEmoji => '表情符號';

  @override
  String get pluginsEditorEmojiSearch => '搜尋';

  @override
  String get pluginsEditorEmojiRecent => '最近';

  @override
  String get pluginsEditorEmojiSmileys => '笑臉和人物';

  @override
  String get pluginsEditorEmojiAnimals => '動物和自然';

  @override
  String get pluginsEditorEmojiFood => '食物';

  @override
  String get pluginsEditorEmojiActivities => '活動';

  @override
  String get pluginsEditorEmojiTravel => '旅遊和地點';

  @override
  String get pluginsEditorEmojiObjects => '物品';

  @override
  String get pluginsEditorEmojiSymbols => '符號';

  @override
  String get pluginsEditorEmojiFlags => '旗幟';

  @override
  String get pluginsMediaCancel => '取消';

  @override
  String get pluginsMediaClose => '關閉';

  @override
  String get pluginsMediaApply => '套用';

  @override
  String pluginsMediaNotSvg(String name) {
    return '$name 沒有回傳 SVG，因此未使用';
  }

  @override
  String get pluginsMediaPaperDoneMissing => '目前無法使用（找不到畫紙的「完成」）';

  @override
  String get pluginsMediaBarEdit => '編輯工具列';

  @override
  String get pluginsMediaAudioUnsupported =>
      '此裝置無法將音訊轉為影片（僅限 Android / iOS / macOS）。可以直接以音訊形式附加';

  @override
  String pluginsMediaOpenAudioFailed(String error) {
    return '無法開啟音訊：$error';
  }

  @override
  String pluginsMediaOpenVideoFailed(String error) {
    return '無法開啟影片：$error';
  }

  @override
  String pluginsMediaReexportFailed(String error) {
    return '無法重新匯出影片：$error';
  }

  @override
  String get pluginsMediaCropWithMovingObject => '裁切 / 旋轉無法與動態物件同時使用。已以靜態圖片加入';

  @override
  String pluginsMediaExportFailed(String error) {
    return '無法匯出影片：$error';
  }

  @override
  String pluginsMediaOverlayFailed(String error) {
    return '無法疊加動態物件，已以靜態圖片加入：$error';
  }

  @override
  String pluginsMediaFilterNotReceived(String label) {
    return '$label：未能接收濾鏡';
  }

  @override
  String pluginsMediaFilterDropped(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個',
    );
    return '$label：繪製內容過多，已省略 $_temp0';
  }

  @override
  String pluginsMediaFiltersFailed(String names) {
    return '未能套用的濾鏡：$names（未包含這些處理）';
  }

  @override
  String get pluginsMediaCropWithMovingPost => '裁切 / 旋轉無法與動態貼文同時使用。貼文已以靜態圖片加入';

  @override
  String get pluginsMediaVideoImageUnreadable => '無法製作影片，已以靜態圖片加入（無法讀取圖片）';

  @override
  String pluginsMediaVideoPostFailed(String error) {
    return '無法製作影片，貼文已以靜態圖片加入：$error';
  }

  @override
  String get pluginsMediaToVideoTitle => '要轉換為影片嗎？';

  @override
  String pluginsMediaToVideoMessage(String note) {
    return '$note\n選擇「製作影片」，將匯出為在放置位置播放的影片。選擇「以靜態圖片貼上」，只貼上目前的圖片。';
  }

  @override
  String get pluginsMediaToVideoConfirm => '製作影片';

  @override
  String get pluginsMediaToVideoStill => '以靜態圖片貼上';

  @override
  String get pluginsMediaImageUnreadable => '無法讀取圖片';

  @override
  String get pluginsMediaExportOnDone => '完成後將匯出為影片';

  @override
  String get pluginsMediaObjectNote => '貼文';

  @override
  String get pluginsMediaObjectVideo => '影片';

  @override
  String get pluginsMediaObjectImage => '圖片';

  @override
  String get pluginsMediaAddImage => '新增圖片';

  @override
  String get pluginsMediaAddVideo => '新增影片';

  @override
  String get pluginsMediaVideoLoadFailed => '無法載入影片';

  @override
  String pluginsMediaVideoLoadFailedDetail(
    String ext,
    int bytes,
    String error,
  ) {
    return '無法取得影片（.$ext，$bytes 位元組）的第一個畫格：$error';
  }

  @override
  String get pluginsMediaFirstFrameFailed => '無法取得影片的第一個畫格';

  @override
  String get pluginsMediaVideoAsObject => '將影片作為物件放置。';

  @override
  String pluginsMediaAddFailed(String error) {
    return '無法新增媒體：$error';
  }

  @override
  String get pluginsMediaAudioConverting => '正在將音訊轉換為影片…';

  @override
  String pluginsMediaPanelNotEditable(String name) {
    return '$name 無法在此編輯（請在外掛面板中操作）';
  }

  @override
  String get pluginsMediaSnapDragUnset => '拖曳到此處（取消）';

  @override
  String get pluginsMediaSnapDragSet => '拖曳到此處（設為對齊目標）';

  @override
  String get pluginsMediaSnapPick => '選擇對齊目標…';

  @override
  String get pluginsMediaSnapClearAll => '取消所有對齊目標';

  @override
  String get pluginsMediaSnapTitle => '對齊目標';

  @override
  String get pluginsMediaSnapEmpty => '沒有已命名的框';

  @override
  String pluginsMediaSnapSize(int width, int height) {
    return '$width × $height';
  }

  @override
  String pluginsMediaSnapSizeAngle(int width, int height, int angle) {
    return '$width × $height，$angle°';
  }

  @override
  String get pluginsMediaPanelNoResult => '無法套用（外掛未回傳結果）';

  @override
  String get pluginsMediaPanelNoEdits => '此外掛沒有可編輯項目';

  @override
  String pluginsMediaObjectEditSemantics(String title) {
    return '編輯 $title';
  }

  @override
  String get pluginsMediaObjectLoop => '重複播放';

  @override
  String get pluginsMediaObjectLoopSubtitle => '關 = 播放結束後停在最後一個畫格';

  @override
  String get pluginsMediaObjectSpeed => '播放速度';

  @override
  String get pluginsMediaObjectVolume => '聲音';

  @override
  String get pluginsMediaObjectMuted => '靜音';

  @override
  String get pluginsMediaObjectOpacity => '不透明度';

  @override
  String get pluginsMediaObjectRemove => '刪除此物件';

  @override
  String pluginsMediaFilterAdjustSemantics(String title) {
    return '調整 $title';
  }

  @override
  String get pluginsMediaFilterObjectHint => '在畫面上拖曳可移動，雙指捏合可縮放 / 旋轉。';

  @override
  String get pluginsMediaFilterRemove => '移除此濾鏡';

  @override
  String get pluginsMediaStickerEmpty => '沒有貼圖。在商店中安裝後會顯示在這裡';

  @override
  String get pluginsMediaStickerEmptyDetail =>
      '沒有貼圖。在商店中安裝素材包（類別「assets」）後會顯示在這裡。';

  @override
  String get pluginsMediaStickerGenerate => '用外掛製作';

  @override
  String get pluginsPaintTitle => '塗鴉';

  @override
  String get pluginsPaintCancel => '取消';

  @override
  String get pluginsPaintDone => '完成';

  @override
  String get pluginsPaintCanvasSemantics => '塗鴉畫布';

  @override
  String get pluginsPaintFillLeak => '請點按由線條圍成的形狀內部';

  @override
  String get pluginsPaintFillOnLine => '請點按線條內側';

  @override
  String get pluginsPaintFillEmpty => '沒有可填色的形狀';

  @override
  String get pluginsPaintToolPen => '畫筆';

  @override
  String get pluginsPaintToolEraser => '橡皮擦';

  @override
  String get pluginsPaintToolLasso => '套索';

  @override
  String get pluginsPaintToolFill => '填色';

  @override
  String get pluginsPaintUndo => '復原';

  @override
  String get pluginsPaintRedo => '重做';

  @override
  String get pluginsPaintClear => '全部清除';

  @override
  String get pluginsPaintStabilizer => '防手震';

  @override
  String get pluginsPaintStabilizerOff => '關';

  @override
  String get pluginsPaintEraserCut => '切斷';

  @override
  String get pluginsPaintEraserWhole => '整條線';

  @override
  String get pluginsPaintLassoHint => '圈選（線條一半以上在圈內的）';

  @override
  String get pluginsPaintSelectionDelete => '刪除';

  @override
  String get pluginsPaintSelectionDuplicate => '複製';

  @override
  String get pluginsPaintSelectionRecolor => '變更顏色';

  @override
  String get pluginsPaintSelectionDeselect => '取消選取';

  @override
  String get pluginsPaintFillHint => '點按由線條圍成的形狀內部，會在線條下方填色';

  @override
  String pluginsPaintWidthSemantics(String width) {
    return '粗細 $width';
  }

  @override
  String pluginsPaintColorSemantics(String color) {
    return '顏色 $color';
  }

  @override
  String get pluginsPaintNibMili => '代針筆';

  @override
  String get pluginsPaintNibKabura => '卡布拉筆';

  @override
  String get pluginsPaintNibBrush => '毛筆筆尖';

  @override
  String get postThreadSortRelevance => '依關聯性';

  @override
  String get postThreadSortReactions => '回應數';

  @override
  String get postThreadSortKeyword => '依關鍵字';

  @override
  String get postThreadSortDefault => '預設';

  @override
  String get postThreadModeRenotes => '引用（轉貼）';

  @override
  String get postThreadModeRenotesShort => '引用';

  @override
  String get postThreadModeReplies => '回覆';

  @override
  String get postThreadModeRepliesShort => '回覆';

  @override
  String get postThreadModeReactions => '回應';

  @override
  String get postThreadModeReactionsShort => '回應';

  @override
  String get postThreadModeQuotes => '分享（引用貼文）';

  @override
  String get postThreadModeQuotesShort => '分享';

  @override
  String get postBookmarkClipTooltip => '加入便籤（長按）';

  @override
  String get postBookmarkRemoveTooltip => '移除書籤（長按加入便籤）';

  @override
  String get postBookmarkAddTooltip => '書籤（長按加入便籤）';

  @override
  String get postBookmarkUnsupported => '此服務沒有書籤功能。長按可加入便籤';

  @override
  String get postBookmarkRemoved => '已移除書籤';

  @override
  String get postBookmarkAdded => '已加入書籤';

  @override
  String postBookmarkError(String error) {
    return '無法加入書籤：$error';
  }

  @override
  String get postReactionsTitle => '回應';

  @override
  String get postReactionsTabReplies => '回覆';

  @override
  String get postReactionsTabQuotes => '引用';

  @override
  String get postReactionsTabReactions => '回應';

  @override
  String get postReactionsTabShares => '分享';

  @override
  String get postReactionsBookmarkTooltip => '書籤';

  @override
  String get postRepliesEmpty => '沒有回覆';

  @override
  String get postQuotesEmpty => '沒有引用貼文';

  @override
  String get postRepostersEmpty => '沒有轉貼或引用';

  @override
  String get postReactionsEmpty => '沒有回應';

  @override
  String get postReactionsMine => '你';

  @override
  String postDetailNotFoundOnAccount(String account) {
    return '在 $account 上找不到此貼文';
  }

  @override
  String get postDetailTitle => '貼文';

  @override
  String get postDetailOpenedAccount => '開啟時使用的帳號';

  @override
  String get postDetailNotFound => '貼文不存在';

  @override
  String get postReload => '重新載入';

  @override
  String get postDetailShowReactions => '顯示回應';

  @override
  String get postDetailShowMore => '顯示更多';

  @override
  String get postRenotesEmpty => '沒有轉貼';

  @override
  String get postShareAccountTooltip => '用於分享的帳號';

  @override
  String get postShareAccountFixedTooltip => '只能用接收到的帳號分享';

  @override
  String get postShareSemantics => '分享';

  @override
  String get postShareContentCopied => '已複製內容';

  @override
  String get postShareLinkCopied => '已複製連結';

  @override
  String get postShareDmTitle => '分享到私訊';

  @override
  String get postShareClose => '關閉';

  @override
  String get postShareDmNoRooms => '沒有私訊對象';

  @override
  String postShareAstellShared(String room) {
    return '已分享到「$room」';
  }

  @override
  String get postShareCopyContent => '複製內容';

  @override
  String get postShareCopyLink => '複製連結';

  @override
  String get postShareOtherAccount => '用其他帳號分享';

  @override
  String get postSharePluginsHeader => '分享到外掛';

  @override
  String get postShareAstellTitle => '分享到 ASTell';

  @override
  String postShareAstellSubtitle(String room) {
    return '將貼文傳送到正在參加的房間「$room」';
  }

  @override
  String get postSharePluginsEmpty => '支援分享的外掛會顯示在這裡';

  @override
  String get postSharePluginsEmptyDetail =>
      '宣告了 post.share 的外掛（以及正在參加的 ASTell）會顯示在這裡';

  @override
  String get postShareOtherHeader => '其他';

  @override
  String get postShareDmSubtitle => '將連結傳送到所選帳號的私訊';

  @override
  String get postShareOpenBrowser => '在瀏覽器中開啟';

  @override
  String get postMenuCopyLink => '複製連結';

  @override
  String get postMenuUnpin => '取消置頂';

  @override
  String get postMenuPin => '置頂';

  @override
  String get postMenuDetail => '詳細資料';

  @override
  String get postMenuShare => '分享';

  @override
  String get postMenuEditActionBar => '編輯動作列';

  @override
  String get postMenuUnfavorite => '取消最愛';

  @override
  String get postMenuFavorite => '加入最愛';

  @override
  String get postMenuAddToClip => '加入便籤';

  @override
  String get postMenuUnfollow => '取消追蹤';

  @override
  String get postMenuFollow => '追蹤';

  @override
  String get postMenuUnmute => '取消靜音';

  @override
  String get postMenuMute => '靜音';

  @override
  String get postMenuUnblock => '解除封鎖';

  @override
  String get postMenuBlock => '封鎖';

  @override
  String get postMenuReport => '檢舉';

  @override
  String get postMenuDelete => '刪除';

  @override
  String postBlockConfirmTitle(String name) {
    return '要封鎖 $name 嗎？';
  }

  @override
  String get postCancel => '取消';

  @override
  String get postReportConfirmTitle => '要檢舉此貼文嗎？';

  @override
  String get postReportConfirmMessage => '將向伺服器管理員檢舉。';

  @override
  String get postDeleteConfirmTitle => '要刪除貼文嗎？';

  @override
  String get postDeleteConfirmMessage => '此操作無法復原。';

  @override
  String postSaveMediaLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': '儲存影片',
      'other': '儲存圖片',
    });
    return '$_temp0';
  }

  @override
  String postSaveDestinationTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': '影片儲存位置',
      'other': '圖片儲存位置',
    });
    return '$_temp0';
  }

  @override
  String get postSaveToPhotosSubtitle => '會存入相簿「RASQ」';

  @override
  String get postSaveToFilesIosSubtitle =>
      '「檔案」App 的 我的 iPad（我的 iPhone）› RASQ › 保存';

  @override
  String get postSaveToFilesSubtitle => '選擇儲存位置';

  @override
  String get postSaveRememberTitle => '以後也使用此儲存位置';

  @override
  String get postSaveRememberSubtitle => '可在 設定 → App 外觀 →「圖片與影片的儲存位置」中變更';

  @override
  String postSaveFailed(String kind, String error) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': '無法儲存影片：$error',
      'other': '無法儲存圖片：$error',
    });
    return '$_temp0';
  }

  @override
  String get profileEditTitle => '更新個人檔案';

  @override
  String get profileEditSave => '確定';

  @override
  String get profileEditNotLoggedIn => '未登入 RASQ 帳號。';

  @override
  String get profileEditBannerRemove => '移除橫幅';

  @override
  String get profileEditBannerPick => '選擇橫幅';

  @override
  String get profileEditAvatarPick => '選擇頭像';

  @override
  String get profileEditAvatarRemove => '移除頭像';

  @override
  String get profileEditPickImage => '選擇圖片';

  @override
  String get profileEditNameHint => '輸入名稱…';

  @override
  String get profileEditBirthdayHint => '生日（YYYY-MM-DD / MM-DD）';

  @override
  String get profileEditBirthdayHintSns => '生日（YYYY-MM-DD）';

  @override
  String get profileEditHandleLabel => '帳號代稱（不含 @，a-z 0-9 _，3～32 個字元）';

  @override
  String get profileEditBioLabel => '自我介紹';

  @override
  String get profileEditBioHint => '自我介紹（最多 500 字）';

  @override
  String get profileEditLocationLabel => '所在地';

  @override
  String get profileEditLinksLabel => '連結';

  @override
  String get profileEditLinkRemove => '刪除';

  @override
  String get profileEditLinkCaptionHint => '標題';

  @override
  String get profileEditLinkAdd => '新增';

  @override
  String get profileEditReload => '重新載入';

  @override
  String get profileEditSnsTilesLabel => '在帳號頁面顯示的 SNS 帳號';

  @override
  String get profileEditSnsTilesCaption => '「自動」不會顯示鎖定帳號等。淡色的卡片表示目前未顯示。';

  @override
  String get profileEditSnsTilesCaptionDetail =>
      '「自動」不會顯示鎖定帳號，以及最近貼文的公開範圍以僅限追蹤者為主的帳號。淡色的卡片表示目前未顯示。變更會立即生效。';

  @override
  String profileEditSnsTileAuto(String state) {
    return '自動（$state）';
  }

  @override
  String get profileEditSnsTileShown => '顯示';

  @override
  String get profileEditSnsTileHidden => '隱藏';

  @override
  String profileEditVerified(String method) {
    return '已驗證所有者（$method）';
  }

  @override
  String get profileEditVerify => '驗證擁有者';

  @override
  String get profileEditShowOnSnsLabel => 'SNS 個人檔案';

  @override
  String get profileEditShowOnSnsTitle => '在 SNS 個人檔案中也顯示連結的帳號';

  @override
  String get profileEditShowOnSnsSubtitle =>
      '當有人在 RASQ 中查看你的 SNS 個人檔案時，顯示連結的帳號。';

  @override
  String get profileEditShowOnSnsDetail =>
      '當有人在 App 中查看你的 SNS 個人檔案時，顯示此 RASQ 帳號以及帳號頁面上顯示的其他帳號。自我介紹中已寫明的不會重複顯示。變更會立即生效。';

  @override
  String get profileEditKeybaseConnect => '連結 Keybase';

  @override
  String get profileEditKeybaseConnectSubtitle => '透過 Keybase 驗證身分，並顯示在帳號頁面';

  @override
  String get profileEditKeybaseLinkedSubtitle => '已驗證。將顯示在帳號頁面';

  @override
  String get profileEditNotice => '個人檔案會顯示在公開頁面和商店評論中。電子郵件和密碼請在「安全性」中設定。';

  @override
  String get profileEditNoticeDetail =>
      '個人檔案會顯示在 RASQ 的公開頁面和商店評論中。圖片會在伺服器上縮小後重新儲存（不會保留位置資訊等）。電子郵件地址和密碼請在「安全性」中設定。';

  @override
  String get profileEditErrorHandleTaken => '該帳號代稱已被使用';

  @override
  String get profileEditErrorHandle => '帳號代稱須為 3～32 個 a-z 0-9 _ 字元';

  @override
  String get profileEditErrorBirthday => '請以 YYYY-MM-DD 或 MM-DD 格式輸入生日';

  @override
  String get profileEditErrorLink => '連結須為標題（最多 40 字）與 http(s) URL 的組合（最多 8 組）';

  @override
  String get profileEditErrorImage =>
      '無法使用該圖片（PNG / JPEG / WebP / GIF，最大 8 MiB）';

  @override
  String get profileEditErrorBio => '自我介紹最多 500 字';

  @override
  String get profileEditErrorLocation => '所在地最多 60 字';

  @override
  String profileEditErrorFailed(String message) {
    return '更新失敗：$message';
  }

  @override
  String get profileEditSnsPostsWithdrawn => '已刪除託管的金鑰和取得的貼文';

  @override
  String profileEditSnsPostsWithdrawFailed(String message) {
    return '無法刪除：$message';
  }

  @override
  String get profileEditSnsPostsNoLogin => '此裝置上沒有該帳號的登入';

  @override
  String get profileEditSnsPostsNoDid => '無法得知此帳號的 DID。請重新登入';

  @override
  String get profileEditSnsPostsBlueskyConsentTitle => '在帳號頁面顯示 Bluesky 的貼文';

  @override
  String profileEditSnsPostsBlueskyConsentMessage(String account) {
    return 'RASQ 的伺服器將透過 Bluesky 的公開 API 讀取 $account 的貼文，使其**在 RASQ 帳號頁面上任何人都可查看**。\n\n• Bluesky 的貼文原本就是任何人都可閱讀的。不匯入回覆和轉發。\n• **不託管登入金鑰（App 密碼 / 工作階段）**。交給伺服器的只有此帳號的 DID 和帳號代稱。\n• 僅限已驗證所有者的帳號使用（以免顯示他人帳號的貼文）。\n• 關閉此開關後，取得的貼文將立即刪除。';
  }

  @override
  String get profileEditSnsPostsAgreeShow => '同意並顯示';

  @override
  String get profileEditCancel => '取消';

  @override
  String get profileEditSnsPostsTokenConsentTitle => '將登入金鑰託管給 RASQ';

  @override
  String profileEditSnsPostsTokenConsentMessage(String account) {
    return '為了在帳號頁面顯示 $account 的貼文，**將此 SNS 的登入金鑰（存取權杖）託管給 RASQ 的伺服器**。\n\n• 你的「公開」和「首頁（不公開列出）」貼文將**在 RASQ 帳號頁面上任何人都可查看**。「首頁」並非僅限追蹤者。\n• 僅限追蹤者 / 指定使用者·私訊 / 僅限本站 / 公開範圍不明的貼文不會匯入。\n• 金鑰僅用於讀取你的貼文。不會用於發文、追蹤等操作或其他目的。\n• 金鑰使用伺服器的金鑰加密儲存（RASQ 的伺服器可以解密）。不會傳回給 App 或其他人。\n• 關閉此開關後，託管的金鑰和取得的貼文將立即刪除。\n\n持有此金鑰即可操作該帳號。如有疑慮，託管後也可以在 SNS 端的設定中使此金鑰（權杖）失效。';
  }

  @override
  String get profileEditSnsPostsAgreeDeposit => '同意並託管';

  @override
  String profileEditSnsPostsFetched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已取得 $count 則貼文',
    );
    return '$_temp0';
  }

  @override
  String profileEditSnsPostsFetchFailed(String error) {
    return '已託管，但無法取得貼文（$error）';
  }

  @override
  String get profileEditSnsPostsUnsupported => '此伺服器暫不支援';

  @override
  String get profileEditSnsPostsVerifyFirst => '請先完成此帳號的「驗證所有者」';

  @override
  String profileEditSnsPostsDepositFailed(String message) {
    return '無法託管：$message';
  }

  @override
  String get profileEditSnsPostsSwitchTitle => '在帳號頁面也顯示貼文';

  @override
  String profileEditSnsPostsFetchError(String error) {
    return '取得失敗：$error';
  }

  @override
  String profileEditSnsPostsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則（公開 / 首頁貼文。每 30 分鐘更新）',
    );
    return '$_temp0';
  }

  @override
  String get profileEditSnsPostsBlueskySubtitle =>
      'RASQ 的伺服器讀取 Bluesky 的公開貼文（不託管金鑰）';

  @override
  String get profileEditSnsPostsTokenSubtitle =>
      '將 SNS 的登入金鑰託管給 RASQ（開啟時會進行確認）';

  @override
  String get profileEditSnsPostsCollectionsTitle => '也將此金鑰用於 RASQ 清單';

  @override
  String get profileEditSnsPostsCollectionsSubtitle => '用於取得開啟的 RASQ 清單及確認能否查看';

  @override
  String get profileEditSnsPostsCollectionsDetail =>
      '開啟 RASQ 清單或便籤時，用此金鑰向 SNS 查詢「是否追蹤清單中的人」，並取得其中成員的公開貼文。與為顯示貼文而託管金鑰的目的不同，因此需另外選擇（預設關閉，選擇 / 取消會記錄在同意紀錄中）。';

  @override
  String get profileEditSnsPostsCollectionsConsentTitle => '也將託管的金鑰用於 RASQ 清單';

  @override
  String get profileEditSnsPostsCollectionsConsentMessage =>
      '為顯示貼文而託管的金鑰，也將用於其他目的。\n\n• 開啟 RASQ 清單或便籤時，用此金鑰向 SNS 查詢「是否追蹤清單中的人」（確認能否查看）。\n• 用此金鑰取得清單中成員的公開 / 首頁貼文。\n• 不會用於發文、追蹤等操作。\n• 關閉此開關後，將立即停止使用。';

  @override
  String get profileEditSnsPostsCollectionsAgree => '同意並使用';

  @override
  String profileEditSnsPostsCollectionsFailed(String message) {
    return '無法變更：$message';
  }

  @override
  String get profileOwnershipWhereMisskey => '請將其貼到自我介紹或個人檔案的「附加資訊」中的任一處，然後儲存。';

  @override
  String get profileOwnershipWhereMastodon =>
      '請將其貼到自我介紹或個人檔案的「額外欄位」中的任一處，然後儲存。';

  @override
  String get profileOwnershipWhereBluesky => '請將其貼到自我介紹（個人檔案說明）中，然後儲存。';

  @override
  String get profileOwnershipWhereFields => '請將其貼到自我介紹或個人檔案的任一欄位中，然後儲存。';

  @override
  String get profileOwnershipWhereBio => '請將其貼到自我介紹中，然後儲存。';

  @override
  String get profileOwnershipErrorNotLinked => '此 SNS 帳號未連結至 RASQ 帳號';

  @override
  String get profileOwnershipErrorUnsupported => '此 SNS 尚不支援擁有者驗證';

  @override
  String get profileOwnershipErrorTooMany => '嘗試次數過多。請稍候再試';

  @override
  String get profileOwnershipErrorNotStarted => '尚未建立驗證文字，或已過期。請從「建立驗證文字」重新開始';

  @override
  String get profileOwnershipErrorCodeNotFound =>
      '未在個人檔案中找到驗證文字。請確認是否已儲存，以及是否顯示在公開的個人檔案中（反映可能需要一些時間）';

  @override
  String get profileOwnershipErrorProfileNotFound => '找不到該 SNS 帳號的公開個人檔案';

  @override
  String get profileOwnershipErrorReadFailed => '無法讀取該 SNS 的個人檔案。請稍候再試';

  @override
  String profileOwnershipErrorFailed(String message) {
    return '無法驗證：$message';
  }

  @override
  String get profileOwnershipKeybaseErrorUsername =>
      '請輸入 Keybase 使用者名稱（小寫英文字母、數字、_,2~16 個字元）';

  @override
  String get profileOwnershipKeybaseErrorSignature =>
      '無法讀取簽章。請將從 BEGIN KEYBASE SALTPACK SIGNED MESSAGE 到 END KEYBASE SALTPACK SIGNED MESSAGE. 的內容原樣貼上';

  @override
  String get profileOwnershipKeybaseErrorStatement => '簽署的文字不一致。請原樣使用上方的指令';

  @override
  String get profileOwnershipKeybaseErrorKey => '未使用該 Keybase 使用者的金鑰簽署';

  @override
  String get profileOwnershipKeybaseErrorNoUser => '找不到該 Keybase 使用者';

  @override
  String get profileOwnershipKeybaseErrorOtherAccount =>
      '該 Keybase 已連結至其他 RASQ 帳號';

  @override
  String get profileOwnershipKeybaseErrorExpired =>
      '文字已過期或尚未建立。請從「建立要簽署的文字」重新開始';

  @override
  String get profileOwnershipKeybaseErrorUnreachable => '無法連線至 Keybase。請稍候再試';

  @override
  String profileOwnershipKeybaseErrorFailed(String message) {
    return '無法確認：$message';
  }

  @override
  String get profileOwnershipVerifyTitle => '驗證擁有者';

  @override
  String get profileOwnershipNotLinked => '此 SNS 帳號未連結至 RASQ 帳號。';

  @override
  String profileOwnershipVerified(String method) {
    return '已驗證（$method）';
  }

  @override
  String get profileOwnershipJustVerified => '驗證成功。可以刪除貼在個人檔案中的文字了。';

  @override
  String get profileOwnershipVerifiedCaption => '帳號頁面和 SNS 個人檔案上會顯示已驗證標記。';

  @override
  String get profileOwnershipVerifiedCaptionDetail =>
      '帳號頁面以及 SNS 個人檔案中顯示的 RASQ 帳號欄會顯示已驗證標記。在解除此 SNS 帳號之前會一直保留。';

  @override
  String get profileOwnershipUnsupportedKind =>
      '此 SNS 尚不支援身分驗證（僅限 Misskey / Mastodon / Bluesky）。';

  @override
  String get profileOwnershipIntro => '驗證此 SNS 帳號是否屬於你。請將驗證文字暫時貼到個人檔案中。';

  @override
  String get profileOwnershipIntroDetail =>
      '驗證此 SNS 帳號是否屬於你。請將驗證文字暫時貼到該 SNS 的個人檔案中，RASQ 會讀取公開的個人檔案進行確認。';

  @override
  String get profileOwnershipEffect => '驗證後，將顯示已驗證標記。';

  @override
  String get profileOwnershipEffectDetail =>
      '驗證後，帳號頁面和 SNS 個人檔案的 RASQ 帳號欄會顯示已驗證標記。即使其他人也連結了同一 SNS 帳號，也以已驗證的人為準。';

  @override
  String get profileOwnershipStart => '建立驗證文字';

  @override
  String get profileOwnershipStep1 => '1. 複製此文字';

  @override
  String get profileOwnershipCopied => '已複製驗證文字';

  @override
  String get profileOwnershipCopy => '複製';

  @override
  String profileOwnershipValidUntil(String time) {
    return '有效期限至 $time';
  }

  @override
  String get profileOwnershipStep2 => '2. 貼到該 SNS 的個人檔案中';

  @override
  String get profileOwnershipNoRewrite => 'RASQ 不會修改你的個人檔案。請在該 SNS 上自行貼上。';

  @override
  String get profileOwnershipStep3 => '3. 貼上後點按「驗證」';

  @override
  String get profileOwnershipCheck => '驗證';

  @override
  String get profileOwnershipRestart => '重新建立文字';

  @override
  String get profileOwnershipKeybaseNoLinks => 'Keybase 證明中沒有已連結的 SNS 帳號。';

  @override
  String profileOwnershipKeybaseLinksVerified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '透過 Keybase 證明，$count 個已連結的 SNS 帳號也已驗證。',
    );
    return '$_temp0';
  }

  @override
  String profileOwnershipKeybaseLinked(String username, String links) {
    return '已連結 @$username。$links';
  }

  @override
  String get profileOwnershipKeybaseUnlinked =>
      '已解除 Keybase。透過 Keybase 證明驗證的 SNS 帳號將恢復為未驗證。';

  @override
  String profileOwnershipKeybaseVerifiedAt(String time) {
    return '於 $time 驗證';
  }

  @override
  String profileOwnershipKeybaseCaption(String username) {
    return '帳號頁面會顯示「Keybase: @$username」。';
  }

  @override
  String profileOwnershipKeybaseCaptionDetail(String username) {
    return '帳號頁面會顯示「Keybase: @$username」。在 Keybase 上新增 Mastodon 等證明後，透過「重新讀取證明」，已連結的 SNS 帳號也會被驗證。';
  }

  @override
  String get profileOwnershipKeybaseRefresh => '重新讀取證明';

  @override
  String get profileOwnershipKeybaseUnlink => '解除 Keybase';

  @override
  String get profileOwnershipKeybaseIntro =>
      '使用 Keybase 簽署，與此 RASQ 帳號連結。連結的 Keybase 將會公開。';

  @override
  String get profileOwnershipKeybaseIntroDetail =>
      '使用 Keybase 帳號簽署，與此 RASQ 帳號連結。連結的 Keybase 會顯示在帳號頁面上（與 Keybase 個人檔案一樣是公開的）。';

  @override
  String get profileOwnershipKeybaseUsername => 'Keybase 使用者名稱';

  @override
  String get profileOwnershipKeybaseStart => '建立要簽署的文字';

  @override
  String get profileOwnershipKeybaseStep1 => '1. 在安裝了 Keybase 的裝置上執行此指令';

  @override
  String get profileOwnershipKeybaseCopied => '已複製指令';

  @override
  String profileOwnershipKeybaseStatement(String statement) {
    return '要簽署的文字：$statement';
  }

  @override
  String get profileOwnershipKeybaseStep2 =>
      '2. 貼上產生的簽章，從 BEGIN 到 END … MESSAGE.';

  @override
  String get profileOwnershipKeybaseVerify => '確認';

  @override
  String profilePagePostLimit(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: '貼文最多 $limit 則。請刪除舊貼文後再發布',
    );
    return '$_temp0';
  }

  @override
  String get profilePageEdit => '編輯';

  @override
  String get profilePageCompose => '發布到 RASQ';

  @override
  String profilePageNotFound(String handle) {
    return '不存在名為 @$handle 的 RASQ 帳號';
  }

  @override
  String profilePageLoadFailed(String message) {
    return '無法載入：$message';
  }

  @override
  String get profilePageLoadFailedShort => '無法載入。';

  @override
  String get profilePageTabPosts => '貼文';

  @override
  String get profilePageTabMedia => '媒體';

  @override
  String get profilePageTabPages => '頁面';

  @override
  String get profilePageTabLists => '清單';

  @override
  String get profilePageTabClips => '便籤';

  @override
  String get profilePageTabPlugins => '外掛';

  @override
  String get profilePageTabReviews => '評論';

  @override
  String get profilePageTileNoDestination => '無法確定此帳號的目標位置';

  @override
  String profilePageOpenFailed(String url) {
    return '無法開啟：$url';
  }

  @override
  String get profilePageListsEmptyMine => '你公開的 RASQ 清單會顯示在這裡（可在清單畫面中建立）。';

  @override
  String get profilePageClipsEmptyMine => '你公開的 RASQ 便籤會顯示在這裡（在便籤頁面中選擇「公開」）。';

  @override
  String get profilePageListsEmpty => '沒有公開的清單。';

  @override
  String get profilePageClipsEmpty => '沒有公開的便籤。';

  @override
  String profilePageSince(String date) {
    return '自 $date 起';
  }

  @override
  String profilePagePinLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '最多只能置頂 $count 則',
    );
    return '$_temp0';
  }

  @override
  String profilePagePinFailed(String message) {
    return '無法置頂：$message';
  }

  @override
  String get profilePagePinned => '置頂貼文';

  @override
  String profilePagePostsNote(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: 'RASQ 貼文最多 $limit 則（$used / $limit）。託管登入金鑰後，SNS 貼文也會一起顯示。',
    );
    return '$_temp0';
  }

  @override
  String profilePagePostsNoteDetail(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          '以 RASQ 帳號發布的貼文目前最多 $limit 則（$used / $limit）。將 SNS 帳號的存取權杖託管給 RASQ 後，該帳號的貼文也會一起顯示在這裡。',
    );
    return '$_temp0';
  }

  @override
  String get profilePageSnsHintTitle => '已連結的 SNS 帳號的貼文尚未顯示在這裡。';

  @override
  String get profilePageSnsHint => '在編輯個人檔案中開啟「在帳號頁面也顯示貼文」後，就會顯示在這裡。';

  @override
  String get profilePageSnsHintDetail =>
      '在編輯個人檔案的「在帳號頁面顯示的 SNS 帳號」中，為每個帳號開啟「在帳號頁面也顯示貼文」（會將該 SNS 的存取權杖託管給 RASQ），其公開 / 首頁貼文就會顯示在這裡。';

  @override
  String get profilePageSnsHintOpen => '前往 SNS 貼文顯示設定';

  @override
  String get profilePageNoPostsYet => '還沒有貼文。';

  @override
  String get profilePageNoMediaYet => '還沒有媒體。';

  @override
  String get profilePageNoReviewsYet => '還沒有評論。';

  @override
  String get profilePageNoPluginsPublished => '沒有已發布的外掛。';

  @override
  String get profilePageImageUrlMissing => '未傳回圖片 URL';

  @override
  String get profilePageNotConnected => '未連線至 RASQ 伺服器';

  @override
  String get profilePagePackageTypeLabel => '外掛（.rspkg / .rasqpkg）';

  @override
  String get profilePageImage => '圖片';

  @override
  String profilePageImageAlt(String alt) {
    return '（圖片：$alt）';
  }

  @override
  String get profilePageMdFallbackTitle => '頁面';

  @override
  String get profilePageMdLoadFailed => '無法載入頁面';

  @override
  String get profilePageMdToolBold => '粗體';

  @override
  String get profilePageMdToolHeading => '標題';

  @override
  String get profilePageMdToolBullet => '項目符號';

  @override
  String get profilePageMdToolLink => '連結';

  @override
  String get profilePageMdToolCenter => '置中';

  @override
  String get profilePageMdToolBig => '放大';

  @override
  String get profilePageMdToolSmall => '縮小';

  @override
  String get profilePageMdToolSpin => '旋轉';

  @override
  String get profilePageMdToolJump => '跳動';

  @override
  String get profilePageMdToolColor => '顏色';

  @override
  String get profilePageMdToolRainbow => '彩虹';

  @override
  String get profilePageMdToolRuby => '注音';

  @override
  String get profilePageMdToolRubyReading => '讀音';

  @override
  String profilePageImageUploadFailed(String error) {
    return '無法上傳圖片：$error';
  }

  @override
  String get profilePageMdTitleRequired => '請輸入標題';

  @override
  String get profilePageMdLoginToPublish => '登入 RASQ 帳號後即可公開';

  @override
  String get profilePageMdPublished => '已公開';

  @override
  String profilePageMdPublishFailed(String error) {
    return '無法公開：$error';
  }

  @override
  String get profilePageMdDeleteTitle => '刪除頁面';

  @override
  String get profilePageMdDeleteDraft => '將刪除草稿。';

  @override
  String get profilePageMdDeletePublished => '將刪除已公開的頁面和草稿。此操作無法復原。';

  @override
  String get profilePageDeleteConfirm => '刪除';

  @override
  String get profilePageCancel => '取消';

  @override
  String profilePageMdDeleteFailed(String error) {
    return '無法刪除：$error';
  }

  @override
  String get profilePageMdEditTitle => '編輯頁面';

  @override
  String get profilePageMdDelete => '刪除';

  @override
  String get profilePageMdWrite => '撰寫';

  @override
  String get profilePageMdPreview => '預覽';

  @override
  String get profilePageMdPublish => '公開';

  @override
  String get profilePageMdTitleHint => '標題';

  @override
  String get profilePageMdBodyHint =>
      '使用 Markdown 撰寫。也可以使用 @提及 / #主題標籤 / :表情符號：/ <center> 等 MFM 標籤';

  @override
  String get profilePageMdDraftCaption => '草稿保留在此裝置上。點按「公開」即可發布到 RASQ 頁面';

  @override
  String get profilePageRasqAccount => 'RASQ 帳號';

  @override
  String profilePageViewingVerified(String method) {
    return '此帳號的擁有者已驗證（$method）';
  }

  @override
  String get profilePageVerifiedSemantics => '擁有者已驗證';

  @override
  String get profilePostLoginToUse => '登入 RASQ 帳號後即可使用';

  @override
  String get profilePostLoginToReply => '登入 RASQ 帳號後即可回覆';

  @override
  String get profilePostLoginToRebroad => '登入 RASQ 帳號後即可轉播';

  @override
  String get profilePostLoginToQueue => '登入 RASQ 帳號後即可 Queue';

  @override
  String get profilePostErrorInstallPack => '從商店安裝此素材包後，即可用這張圖片 Queue';

  @override
  String get profilePostErrorForbidden => '無法對此貼文執行此操作';

  @override
  String get profilePostErrorRebroadLimit => '此貼文已無法再轉播';

  @override
  String get profilePostErrorReplyLimit => '最多只能回覆 100 則。請刪除舊的回覆';

  @override
  String get profilePostErrorGone => '此貼文 / 圖片已不存在';

  @override
  String profilePostErrorFailed(String message) {
    return '失敗：$message';
  }

  @override
  String get profilePostMenuReactions => '查看回應';

  @override
  String get profilePostMenuCopyLink => '複製連結';

  @override
  String get profilePostMenuOpenBrowser => '在瀏覽器中開啟';

  @override
  String get profilePostMenuEditActions => '編輯動作列';

  @override
  String get profilePostMenuUnpin => '取消置頂';

  @override
  String get profilePostMenuPin => '置頂';

  @override
  String get profilePostMenuDelete => '刪除';

  @override
  String get profilePostLinkCopied => '已複製連結';

  @override
  String get profilePostDeleteTitle => '刪除貼文';

  @override
  String get profilePostDeleteMessage => '將刪除此貼文及其附加的圖片。此操作無法復原。';

  @override
  String get profilePostDeleteConfirm => '刪除';

  @override
  String get profilePostCancel => '取消';

  @override
  String get profilePostQuoteUnavailable => '無法查看被引用的貼文';

  @override
  String get profilePostReply => '回覆';

  @override
  String get profilePostRebroad => '轉播';

  @override
  String get profilePostRebroadUndo => '取消轉播';

  @override
  String get profilePostQuote => '引用';

  @override
  String get profilePostQueue => 'Queue';

  @override
  String get profilePostLike => '按讚';

  @override
  String get profilePostQuoteFollowersOnly => '無法引用僅限追蹤者的貼文';

  @override
  String profilePostRebroadedBy(String name) {
    return '$name 轉播了';
  }

  @override
  String get profilePostReplyToDeleted => '回覆已刪除的貼文';

  @override
  String get profilePostShare => '分享';

  @override
  String get profilePostCwHide => '隱藏';

  @override
  String get profilePostCwShow => '顯示更多';

  @override
  String get profilePostNoPacksTitle => '沒有素材包';

  @override
  String get profilePostNoPacksMessage => 'Queue 是使用從商店取得的素材包圖片進行的回應。';

  @override
  String get profilePostNoPacksStore => '在商店中尋找';

  @override
  String get profilePostClose => '關閉';

  @override
  String profilePostOverlayQueueTooltip(String label) {
    return '$label（長按選擇圖片）';
  }

  @override
  String get profilePostMenu => '選單';

  @override
  String get profilePostTitle => '貼文';

  @override
  String get profilePostGone => '此貼文已不存在';

  @override
  String profilePostLoadFailed(String message) {
    return '無法載入：$message';
  }

  @override
  String get profilePostParentDeleted => '原貼文已被刪除。';

  @override
  String profilePostRepliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '回覆 $count',
    );
    return '$_temp0';
  }

  @override
  String get profilePostNoRepliesYet => '還沒有回覆。';

  @override
  String get profilePostNoReplies => '沒有回覆';

  @override
  String get profilePostNoRebroads => '沒有轉播';

  @override
  String get profilePostNoQuotes => '沒有引用';

  @override
  String get profilePostNoQueues => '沒有 Queue';

  @override
  String get profilePostReactionsTitle => '回應';

  @override
  String get profilePostYou => '你';

  @override
  String get quickPickEmojiTitle => '快速表情符號';

  @override
  String get quickPickEmojiMore => '更多表情符號';

  @override
  String get quickPickSettingsCaption =>
      '長按回應按鈕或編輯器的表情符號按鈕，會在按鈕旁彈出面板，顯示這裡的表情符號和最近使用的表情符號。手指不離開螢幕滑動，放開時所在的表情符號會被加入（插入）。若不滑動直接放開，面板會保持開啟，可點按選擇。';

  @override
  String get quickPickSettingsAdd => '新增表情符號';

  @override
  String get quickPickSettingsReset => '恢復預設';

  @override
  String quickPickSettingsRemove(String name) {
    return '移除 $name';
  }

  @override
  String get quickPickSettingsEmpty => '沒有表情符號。面板中只會顯示最近使用的表情符號';

  @override
  String get raiModeInstruction => '指引';

  @override
  String get raiModeAssistant => '助理';

  @override
  String get raiGuideDefaultTitle => '引導';

  @override
  String raiHeldDeclined(String calls) {
    return '未執行（$calls）';
  }

  @override
  String raiAutoDeclined(String title) {
    return '了解。要透過引導進行「$title」時，請點按「依此步驟引導」';
  }

  @override
  String raiAutoProgress(int step, int total, String text) {
    return '正在自動進行（$step / $total）：$text';
  }

  @override
  String raiAutoAskingDetail(String label) {
    return '選擇$label';
  }

  @override
  String raiAutoAskDestination(String title) {
    return '「$title」要匯入到哪裡？';
  }

  @override
  String raiAutoAskWhich(String label) {
    return '要選哪個$label?';
  }

  @override
  String get raiAutoAskHint => '請從候選中選擇，或輸入其他詞語';

  @override
  String raiAutoNotFoundDetail(String label) {
    return '找不到$label';
  }

  @override
  String raiAutoNotFoundAsk(String label) {
    return '找不到$label。要搜尋其他$label嗎？';
  }

  @override
  String raiAutoAskWhichCount(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '要選哪個$label?（$count 個）',
    );
    return '$_temp0';
  }

  @override
  String raiAutoCancelled(String title) {
    return '已停止「$title」的自動化';
  }

  @override
  String raiAutoFailedAt(String title, int step, String detail) {
    return '「$title」在第 $step 步停止：$detail';
  }

  @override
  String raiAutoPartlyDone(int done, int step, String text) {
    String _temp0 = intl.Intl.pluralLogic(
      done,
      locale: localeName,
      other: '已用函式完成 $done 個步驟。從第 $step 步「$text」開始有需要點按的元件，將進行引導',
    );
    return '$_temp0';
  }

  @override
  String raiAutoDone(String title) {
    return '已用函式完成「$title」';
  }

  @override
  String get raiInstructionUnknown => '這是我還沒學會的操作。請試著問「發文」「登入」「分享」等。';

  @override
  String get raiAskChoice => '你指的是哪個？請從上方的選項中選擇';

  @override
  String get raiNoReply => '沒有回應';

  @override
  String raiFailureDevice(String message) {
    return '裝置端模型：$message';
  }

  @override
  String raiFailureFallUp(String message) {
    return '上行備援：$message';
  }

  @override
  String raiProposalReady(String title) {
    return '已準備好引導「$title」（可從下方的卡片開始）';
  }

  @override
  String raiProposalReadyStopAt(String title, int step) {
    return '已準備好將引導「$title」進行到第 $step 步（從下方的卡片開始）';
  }

  @override
  String raiHeldNote(String calls) {
    return '（基於取得的資訊進行的操作，將在確認後執行：$calls）';
  }

  @override
  String get raiNoReplyParen => '（沒有回應）';

  @override
  String raiRestartInjecting(String keys) {
    return '注入取得的資訊（$keys）並重新啟動模型';
  }

  @override
  String get raiAutoDetailReplaced => '由函式代替';

  @override
  String get raiAutoDetailNoFunction => '沒有對應的函式';

  @override
  String get raiAutoDetailGuideParts => '需點按的元件將進行引導';

  @override
  String get raiAutoDetailExplanationOnly => '僅說明';

  @override
  String raiAutoDescribeNoBound(String title) {
    return '「$title」沒有可用函式代替的步驟，將透過引導（指示）進行。';
  }

  @override
  String raiAutoDescribeHead(String title) {
    return '我將不顯示引導，用函式完成「$title」：';
  }

  @override
  String raiAutoDescribeGuideMark(String detail) {
    return '（從這裡開始引導：$detail）';
  }

  @override
  String get raiListSeparator => '、';

  @override
  String raiAutoDescribeFromQuestion(String inputs) {
    return '來自問題：$inputs';
  }

  @override
  String raiAutoDescribeEntrusted(String labels) {
    return '$labels將使用候選中的第一個（因為已交給我處理）';
  }

  @override
  String raiAutoDescribeAskLater(String labels) {
    return '$labels將在執行過程中由你選擇';
  }

  @override
  String get raiAutoDescribeConfirm => '如果可以，請點按「執行」。';

  @override
  String raiProposalHead(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '若是「$title」，將依此順序進行（$count 個步驟）',
    );
    return '$_temp0';
  }

  @override
  String raiProposalFunction(String function) {
    return '〔$function〕';
  }

  @override
  String raiProposalInputs(String inputs) {
    return ' 輸入：$inputs';
  }

  @override
  String raiProposalPresets(String presets) {
    return ' 固定：$presets';
  }

  @override
  String get raiModeSemantics => 'RAi 模式';

  @override
  String get raiAskButton => '提問';

  @override
  String get raiInputHint => '遇到困難時，我來幫你！';

  @override
  String raiInputPredicted(String prediction) {
    return '$prediction（按空白鍵輸入）';
  }

  @override
  String get raiCollapse => '收合';

  @override
  String get raiExpand => '展開';

  @override
  String get raiAskMore => '繼續提問';

  @override
  String get raiHistoryClose => '關閉歷史紀錄';

  @override
  String get raiHistory => '發言紀錄';

  @override
  String get raiClose => '關閉 RAi';

  @override
  String get raiNext => '下一步';

  @override
  String get raiDone => '知道了（關閉）';

  @override
  String get raiSpeechClose => '關閉';

  @override
  String get raiHistoryEmpty => '還沒有發言';

  @override
  String get raiCopy => '複製';

  @override
  String get raiCopied => '已複製';

  @override
  String raiChatSuspended(int step, int total) {
    return '引導已暫停（第 $step / $total 步）。返回後將繼續。';
  }

  @override
  String get raiChatResume => '繼續';

  @override
  String get raiChatHeadline => '巨集之類的就交給我吧！';

  @override
  String get raiChatIntro => '詢問操作方法後，RAi 會指向按鈕告訴你。';

  @override
  String get raiChatIntroDetail =>
      '指引：詢問操作方法後，RAi 會移動到按鈕處並指向它。\n助理：使用裝置端模型回答。可從列中的標籤選擇模型（巨集將在第二期推出）。';

  @override
  String get raiChatRecent => '最近的問題';

  @override
  String get raiChatRejectCandidates => '不是這個（排除候選後重新回答）';

  @override
  String raiChatProposalTitle(String title, int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$title · $steps 個步驟',
    );
    return '$_temp0';
  }

  @override
  String get raiChatSkip => '略過';

  @override
  String get raiChatGuide => '依此步驟引導';

  @override
  String raiChatGuideTitle(String title) {
    return '引導「$title」';
  }

  @override
  String get raiChatTrace => '流程';

  @override
  String get raiChatShowGraph => '以圖表檢視顯示';

  @override
  String get raiChatApproveHeld => '要執行此操作嗎？（這是根據取得的資訊得出的操作）';

  @override
  String get raiChatApprove => '交給 RAi 處理嗎？';

  @override
  String get raiChatDecline => '取消';

  @override
  String get raiChatRun => '執行';

  @override
  String get raiHomeSidebarSemantics => 'RAi 側邊欄';

  @override
  String get raiHomeClose => '關閉';

  @override
  String get raiHomeNewConversation => '新對話';

  @override
  String get raiHomeHistory => '對話紀錄';

  @override
  String raiHomeCurrentConversation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '目前對話 · $count 則',
    );
    return '$_temp0';
  }

  @override
  String raiHomeConversationSubtitle(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$when · $count 則',
    );
    return '$_temp0';
  }

  @override
  String get raiHomeDelete => '刪除';

  @override
  String get raiHomeHistoryEmpty => '還沒有。提問後，對話會儲存在這裡。';

  @override
  String get raiHomeOther => '其他';

  @override
  String get raiAchievementsTitle => '成就';

  @override
  String raiAchievementsProgress(int unlocked, int total) {
    return '已達成 $unlocked / $total';
  }

  @override
  String get raiHomeMacro => '巨集';

  @override
  String get raiHomeMacroSoon => '即將推出';

  @override
  String get raiBarSemantics => 'RAi 列';

  @override
  String get raiAskCancel => '取消';

  @override
  String raiAskInputHint(String label) {
    return '輸入$label';
  }

  @override
  String raiAskInputOtherHint(String label) {
    return '輸入其他$label';
  }

  @override
  String get raiAskDone => '確定';

  @override
  String raiAchievementsStats(
    int instructions,
    int assistant,
    int app,
    int completed,
    int repeated,
  ) {
    return '指引 $instructions 次 · 助理 $assistant 次（關於 App $app 次）· 完成 $completed 次 · 重複提問 $repeated 次';
  }

  @override
  String get raiAchievementAsk1Title => '第一個問題';

  @override
  String get raiAchievementAsk1Description => '詢問了 1 次指引';

  @override
  String get raiAchievementAsk10Title => '善於提問';

  @override
  String get raiAchievementAsk10Description => '詢問了 10 次指引';

  @override
  String get raiAchievementAsk50Title => 'RAi 常客';

  @override
  String get raiAchievementAsk50Description => '詢問了 50 次指引';

  @override
  String get raiAchievementApp5Title => 'App 通';

  @override
  String get raiAchievementApp5Description => '與助理聊了 5 次關於 App 的話題';

  @override
  String get raiAchievementChat20Title => '話匣子';

  @override
  String get raiAchievementChat20Description => '與助理對話了 20 次';

  @override
  String get raiAchievementDone1Title => '一次完成';

  @override
  String get raiAchievementDone1Description => '依引導完成到最後一步';

  @override
  String get raiAchievementDone10Title => '完成大師';

  @override
  String get raiAchievementDone10Description => '10 次依引導完成到最後';

  @override
  String get raiAchievementAgain3Title => '複習中';

  @override
  String get raiAchievementAgain3Description => '同一操作重複詢問了 3 次';

  @override
  String get raiAchievementAuto1Title => '全權交給 RAi';

  @override
  String get raiAchievementAuto1Description => '透過「略過」交給了 RAi';

  @override
  String get raiTracePortPrev => '上一步';

  @override
  String get raiTracePortState => '狀態';

  @override
  String get raiTracePortFunction => '函式';

  @override
  String get raiTracePortResult => '結果';

  @override
  String get raiTracePortNext => '下一步';

  @override
  String get raiTraceStatusDone => '已由函式完成';

  @override
  String get raiTraceStatusSkipped => '已收合';

  @override
  String get raiTraceStatusGuide => '轉為引導';

  @override
  String get raiTraceStatusFailed => '失敗';

  @override
  String get raiTraceStatusAsking => '等待選擇';

  @override
  String get raiTraceStatusRunning => '執行中';

  @override
  String get raiTraceStatusPending => '未執行';

  @override
  String raiTraceCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '流程 $count 個步驟',
    );
    return '$_temp0';
  }

  @override
  String get raiDiagTitle => '診斷（開發者模式）';

  @override
  String get raiDiag3dOn => '3D RAi:使用';

  @override
  String get raiDiag3dOff => '3D RAi:不使用（以 2D 顯示）';

  @override
  String get raiDiag3dOffAndroid =>
      '3D RAi:不使用(Android 預設為 2D。可在開發者模式的「試用 3D RAi(Android)」中開啟)';

  @override
  String raiDiag3dFailed(String reason) {
    return '3D RAi:失敗，已切換為 2D($reason)';
  }

  @override
  String raiDiagLlm(String phase, String message) {
    return '裝置端 LLM:$phase($message)';
  }

  @override
  String raiDiagEmbedding(String phase, String message) {
    return '嵌入模型：$phase($message)';
  }

  @override
  String get raiDiagEmpty => '沒有記錄的失敗';

  @override
  String get raiDiagRetry3d => '再次嘗試 3D';

  @override
  String raiFunctionsSettingMissing(String area, String key, String keys) {
    return '「$area」中沒有名為「$key」的設定（現有：$keys）';
  }

  @override
  String raiFunctionsSettingNotWritable(String key) {
    return '「$key」不是可以從畫面寫入的設定';
  }

  @override
  String raiFunctionsSettingNeedsPassword(String key) {
    return '「$key」需要密碼，因此 RAi 不會寫入';
  }

  @override
  String raiFunctionsSettingLocked(String key) {
    return '「$key」帶有禁止操作標籤，因此 RAi 不會寫入';
  }

  @override
  String raiFunctionsFoldEmpty(String head) {
    return '$head:無結果';
  }

  @override
  String raiFunctionsFoldHead(String head, int total, int shown) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$head（共 $total 筆，顯示 $shown 筆）：',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsUnsupported(String name) {
    return '此 SNS 不支援（$name）';
  }

  @override
  String raiFunctionsNotAutomatable(String name, String alt, String result) {
    return '$name 無法自動化（傳送需由使用者點按）。改為 $alt:$result';
  }

  @override
  String raiFunctionsUnknown(String name) {
    return '未知的函式：$name';
  }

  @override
  String raiFunctionsFailed(String name, String error) {
    return '$name 失敗：$error';
  }

  @override
  String get raiFunctionsNotLoggedInSns => '尚未登入 SNS';

  @override
  String raiFunctionsLineReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '（回應 $count）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsPostsNone => '沒有符合條件的貼文';

  @override
  String raiFunctionsPostsHead(int count, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '貼文 $count 筆（共 $total 筆）：',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsReferenceOperation(String title, String id, String steps) {
    return '操作「$title」($id):$steps';
  }

  @override
  String raiFunctionsReferenceFunction(String id, String does) {
    return '函式 $id:$does';
  }

  @override
  String raiFunctionsReferenceParams(String params) {
    return ' 參數：$params';
  }

  @override
  String get raiFunctionsReferenceParamInput => '輸入';

  @override
  String raiFunctionsReferenceParamFixed(String value) {
    return '固定=$value';
  }

  @override
  String raiFunctionsReferenceMissing(String id) {
    return '參考資料中沒有 $id';
  }

  @override
  String raiFunctionsActionMissing(String id) {
    return '沒有動作 $id';
  }

  @override
  String raiFunctionsActionNotAllowed(String label) {
    return '「$label」不允許自動化（RAi 不會執行）。請改為依步驟引導，或由使用者點按';
  }

  @override
  String raiFunctionsActionDone(String label, String state) {
    return '已執行 $label($state)';
  }

  @override
  String get raiFunctionsActionDoneYes => '已完成';

  @override
  String get raiFunctionsActionDoneNo => '未完成';

  @override
  String get raiFunctionsAstellNoRooms => '沒有 ASTell 房間';

  @override
  String raiFunctionsAstellRooms(String rooms) {
    return 'ASTell 房間：$rooms';
  }

  @override
  String get raiFunctionsAstellNoTitle => '沒有標題';

  @override
  String raiFunctionsAstellCreated(String title, String id) {
    return '已建立 ASTell「$title」[$id]';
  }

  @override
  String raiFunctionsNotifReaction(String who, String reaction) {
    return '$who 回應了$reaction';
  }

  @override
  String raiFunctionsNotifRepost(String who) {
    return '$who 轉貼了';
  }

  @override
  String raiFunctionsNotifQuote(String who) {
    return '$who 引用了';
  }

  @override
  String raiFunctionsNotifReply(String who) {
    return '$who 回覆了';
  }

  @override
  String raiFunctionsNotifMention(String who) {
    return '$who 提及了你';
  }

  @override
  String raiFunctionsNotifFollow(String who) {
    return '$who 追蹤了你';
  }

  @override
  String raiFunctionsNotifFollowRequest(String who) {
    return '$who 傳送了追蹤請求';
  }

  @override
  String raiFunctionsNotifFollowAccepted(String who) {
    return '$who 核准了追蹤請求';
  }

  @override
  String raiFunctionsNotifListAdded(String who) {
    return '$who 將你加入了清單';
  }

  @override
  String get raiFunctionsNotifPollEnded => '投票已結束';

  @override
  String get raiFunctionsNotifTimer => '計時通知';

  @override
  String get raiFunctionsNotifVc => 'ASTell 通知';

  @override
  String get raiFunctionsNotifSystem => '系統通知';

  @override
  String get raiFunctionsNotifOther => '其他通知';

  @override
  String get raiFunctionsUnreadMark => '（未讀）';

  @override
  String get raiFunctionsMissingPostId => '缺少貼文 id(id=)';

  @override
  String get raiFunctionsMissingPostArg => '缺少貼文 id(post=)';

  @override
  String raiFunctionsThreadReply(String line) {
    return '回覆：$line';
  }

  @override
  String get raiFunctionsHeadThread => '討論串';

  @override
  String get raiFunctionsHeadReactions => '回應';

  @override
  String get raiFunctionsHeadReposters => '轉貼的人';

  @override
  String get raiFunctionsHeadQuotes => '引用';

  @override
  String get raiFunctionsHeadFavorites => '最愛';

  @override
  String get raiFunctionsHeadReacted => '已回應';

  @override
  String raiFunctionsMe(String user, String plugin) {
    return '我：$user 外掛=$plugin';
  }

  @override
  String get raiFunctionsUserIdOrHandle => '請指定 id= 或 handle=';

  @override
  String get raiFunctionsNotFound => '找不到';

  @override
  String raiFunctionsUserCounts(String followers, String following) {
    return ' 追蹤者 $followers 追蹤中 $following';
  }

  @override
  String get raiFunctionsMissingUser => '缺少使用者 id(user=)';

  @override
  String raiFunctionsHeadUserPosts(String filter) {
    return '貼文（$filter）';
  }

  @override
  String get raiFunctionsMissingKeyword => '缺少 keyword';

  @override
  String raiFunctionsHeadUserSearch(String keyword) {
    return '使用者搜尋「$keyword」';
  }

  @override
  String get raiFunctionsHeadFollowing => '追蹤中';

  @override
  String get raiFunctionsHeadFollowers => '追蹤者';

  @override
  String get raiFunctionsRelFollowing => '追蹤中';

  @override
  String get raiFunctionsRelFollowedBy => '追蹤了你';

  @override
  String get raiFunctionsRelRequested => '請求中';

  @override
  String get raiFunctionsRelMuted => '已靜音';

  @override
  String get raiFunctionsRelBlocked => '已封鎖';

  @override
  String get raiFunctionsRelBlockedBy => '封鎖了你';

  @override
  String get raiFunctionsRelNone => '無';

  @override
  String raiFunctionsRelation(String flags) {
    return '關係：$flags';
  }

  @override
  String raiFunctionsRequestLine(String user, String id) {
    return '$user [請求 $id]';
  }

  @override
  String raiFunctionsHeadModeration(String kind) {
    return '管理（$kind）';
  }

  @override
  String raiFunctionsHeadNotifications(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '通知（未讀 $unread 則）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNotificationsRead => '已將通知標為已讀';

  @override
  String raiFunctionsTrendLine(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag（$count 人）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadTrends => '趨勢';

  @override
  String raiFunctionsListLine(String name, String id, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name [$id]（$count 人）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadLists => '清單';

  @override
  String get raiFunctionsMissingList => '缺少清單 id(list=)';

  @override
  String get raiFunctionsHeadListMembers => '清單成員';

  @override
  String raiFunctionsClipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '（$count 筆）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadClips => '便籤';

  @override
  String get raiFunctionsMissingClip => '缺少摘錄 id(clip=)';

  @override
  String get raiFunctionsHeadClipNotes => '便籤內容';

  @override
  String get raiFunctionsHeadFeeds => '動態';

  @override
  String raiFunctionsDmUnread(int count) {
    return '（未讀 $count）';
  }

  @override
  String raiFunctionsHeadEmoji(String keyword) {
    return '表情符號「$keyword」';
  }

  @override
  String get raiFunctionsUnfollowed => '已取消追蹤';

  @override
  String get raiFunctionsFollowRequested => '已傳送追蹤請求';

  @override
  String get raiFunctionsFollowed => '已追蹤';

  @override
  String get raiFunctionsListUserArgs => '請指定 list= 和 user=';

  @override
  String get raiFunctionsListAdded => '已加入清單';

  @override
  String get raiFunctionsListRemoved => '已從清單移除';

  @override
  String get raiFunctionsMissingName => '缺少名稱（name=）';

  @override
  String raiFunctionsListCreated(String name, String id) {
    return '已建立清單「$name」[$id]';
  }

  @override
  String get raiFunctionsClipPostArgs => '請指定 clip= 和 post=';

  @override
  String get raiFunctionsClipAdded => '已加入便籤';

  @override
  String get raiFunctionsClipRemoved => '已從便籤移除';

  @override
  String raiFunctionsClipCreated(String name, String id) {
    return '已建立便籤「$name」[$id]';
  }

  @override
  String get raiFunctionsAreaKeyArgs => '請指定 area= 和 key=';

  @override
  String raiFunctionsSettingsPageMissing(String area) {
    return '沒有設定頁面「$area」';
  }

  @override
  String get raiFunctionsAreaKeyValueArgs => '請指定 area=、key= 和 value=';

  @override
  String raiFunctionsSettingBadValue(String key, String value, String current) {
    return '無法將「$key」設為「$value」（目前的值：$current）';
  }

  @override
  String raiFunctionsSettingSet(String area, String key, String value) {
    return '已將 $area.$key 設為 $value';
  }

  @override
  String get raiFunctionsMissingText => '缺少內文（text=）';

  @override
  String get raiFunctionsMissingRoom => '缺少房間 id(room=)';

  @override
  String raiFunctionsDmRoomMissing(String id) {
    return '沒有 DM 房間 $id';
  }

  @override
  String raiFunctionsComposeFilled(String target) {
    return '已將$target的草稿放入編輯器（尚未傳送）';
  }

  @override
  String raiFunctionsFeedNotFound(String feed) {
    return '找不到動態「$feed」';
  }

  @override
  String raiFunctionsFeedSaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已儲存「$name」（已儲存 $count 個）',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsFeedUnsaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已取消儲存「$name」（已儲存 $count 個）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNoBluesky => '沒有 Bluesky 帳號（自訂動態僅限 Bluesky）';

  @override
  String raiFunctionsFeedAlreadyHome(String name) {
    return '「$name」已在首頁時間軸中';
  }

  @override
  String raiFunctionsFeedAddedHome(String name, String account) {
    return '已將「$name」（$account）加入首頁時間軸';
  }

  @override
  String get raiFunctionsNotLoggedInRasq => '尚未登入 RASQ 帳號';

  @override
  String get raiFunctionsRasqListMine => '自己的';

  @override
  String get raiFunctionsRasqListUnfetchable => '無法匯入';

  @override
  String get raiFunctionsRasqListFollowing => '追蹤中';

  @override
  String raiFunctionsRasqListLine(String name, int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name（$count 人 · $state）',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadRasqLists => 'RASQ 清單';

  @override
  String get raiFunctionsMissingListArg => '缺少清單（list=）';

  @override
  String raiFunctionsRasqListNotFound(String query) {
    return '找不到 RASQ 清單「$query」';
  }

  @override
  String get raiFunctionsMissingWord => '缺少關鍵字（word=）';

  @override
  String get raiFunctionsNotLoggedIn => '未登入';

  @override
  String raiFunctionsWordExcludeAlready(String word) {
    return '已在排除「$word」';
  }

  @override
  String raiFunctionsWordIncludeAlready(String word) {
    return '已在依「$word」篩選';
  }

  @override
  String raiFunctionsWordExcluded(String word, String scope) {
    return '已設定為從 $scope 時間軸中排除包含「$word」的貼文';
  }

  @override
  String raiFunctionsWordIncluded(String word, String scope) {
    return '已設定為 $scope 時間軸只顯示包含「$word」的貼文';
  }

  @override
  String get raiFunctionsFeedKindLabel => '動態';

  @override
  String get raiFunctionsHeadFeedTimeline => '動態時間軸';

  @override
  String raiFunctionsPageList(String name, String id) {
    return '清單 $name [$id]';
  }

  @override
  String raiFunctionsPageFeed(String name, String uri) {
    return '動態 $name [$uri]';
  }

  @override
  String get raiFunctionsHeadListsPage => '清單頁面';

  @override
  String get raiFunctionsHeadNotificationsPage => '通知';

  @override
  String get raiFunctionsHeadHomeTimeline => '首頁時間軸';

  @override
  String get raiFunctionsMissingSource => '缺少來源（source=）';

  @override
  String raiFunctionsSeedNoPosts(String label) {
    return '「$label」沒有貼文，無法擷取特徵詞';
  }

  @override
  String raiFunctionsSeedNoWords(String label) {
    return '無法從「$label」擷取特徵詞';
  }

  @override
  String get raiFunctionsSeedWordSeparator => '、';

  @override
  String raiFunctionsSeedAdded(String label, String words) {
    return '已將「$label」的特徵詞（$words）加入趨勢傾向（喜歡的類型）';
  }

  @override
  String get raiFunctionsMissingQuery => '缺少搜尋詞（q=）';

  @override
  String raiFunctionsHeadWeb(String query) {
    return '網頁「$query」';
  }

  @override
  String get raiFunctionsNotAutomatableMark => '（無法自動化）';

  @override
  String get raiFunctionsHeadActions => '動作';

  @override
  String get raiModelsTitle => '模型';

  @override
  String get raiModelsClose => '關閉';

  @override
  String get raiModelsRamUnknown => 'RAM:未知';

  @override
  String raiModelsRamFree(String gb) {
    return '（可用 $gb GB）';
  }

  @override
  String raiModelsCaption(String codename, String ram) {
    return '$codename = 在此裝置上執行的模型。$ram';
  }

  @override
  String raiModelsCaptionDetail(String codename, String label, String ram) {
    return '$codename = 裝置端執行的模型（$label）。$ram';
  }

  @override
  String get raiModelsSectionLocal => '本機';

  @override
  String get raiModelsSectionEmbedding => 'RAi 搜尋與貼文嵌入';

  @override
  String get raiModelsPostVisionReady => '關聯時間軸和時間軸演算法也會比較貼文的圖片';

  @override
  String get raiModelsPostVisionIdle => '關聯時間軸和時間軸演算法除了貼文內文外，還能比較圖片（請同時安裝文字模型）';

  @override
  String get raiModelsSectionEmoji => '表情符號圖片搜尋（兩個都需要）';

  @override
  String get raiModelsEmojiTextReady => '可以用輸入的文字搜尋表情符號圖片';

  @override
  String get raiModelsEmojiTextIdle => '可以依含義搜尋表情符號圖片（請同時安裝圖像模型）';

  @override
  String get raiModelsEmojiVisionReady => '在背景逐步讀取表情符號圖片（每個伺服器 1 次）';

  @override
  String get raiModelsEmojiVisionIdle => '即使表情符號名稱沒有意義，也能依圖片內容搜尋';

  @override
  String get raiModelsSectionCloud => '雲端（裝置無法回答時）';

  @override
  String get raiModelsCompletionCaption => '完成率 = 引導或回答順利進行到最後的比例。';

  @override
  String get raiModelsCompletionCaptionDetail =>
      '完成率 = 操作引導 / 回答成立到最後的比例彙總（僅統計小於 35B 的模型，示範中為「-%」）。';

  @override
  String get raiModelsRateExcluded => '不計入統計';

  @override
  String get raiModelsNotConnected => '未連線';

  @override
  String get raiModelsPhaseNotInstalled => '未下載';

  @override
  String raiModelsPhaseDownloading(int percent) {
    return '正在下載 $percent%';
  }

  @override
  String get raiModelsPhaseReady => '就緒';

  @override
  String get raiModelsPhaseReadyBundled => '就緒（內建）';

  @override
  String get raiModelsPhaseLoading => '正在載入';

  @override
  String get raiModelsPhaseGenerating => '正在產生';

  @override
  String get raiModelsPhaseUnavailable => '無法使用';

  @override
  String get raiModelsPillCloud => '雲端';

  @override
  String get raiModelsPillLocal => '本機';

  @override
  String raiModelsCloudLine(String label, String params) {
    return '$label · ${params}B · 雲端';
  }

  @override
  String raiModelsCompletionRate(String rate) {
    return '完成率 $rate';
  }

  @override
  String get raiModelsMemoryNotNeeded => '記憶體：不需裝置';

  @override
  String raiModelsMemory(String verdict) {
    return '記憶體：$verdict';
  }

  @override
  String get raiModelsUse => '使用';

  @override
  String get raiModelsExtract => '解壓縮（內建）';

  @override
  String get raiModelsDownload => '下載';

  @override
  String get raiModelsRelease => '釋放記憶體';

  @override
  String get raiModelsDeleteTitle => '要刪除模型嗎？';

  @override
  String raiModelsDeleteMessage(String file) {
    return '將從裝置中刪除 $file。';
  }

  @override
  String get raiModelsDelete => '刪除';

  @override
  String get raiModelsCancel => '取消';

  @override
  String raiModelsEmbeddingLine(String file, int size, int dims) {
    return 'onnxruntime · $file · 約 $size MB · $dims 維';
  }

  @override
  String get raiModelsSearchSemantic => '依語意相近程度搜尋';

  @override
  String raiModelsSearchSemanticDetail(String label) {
    return '搜尋：$label（依語意檢索）';
  }

  @override
  String get raiModelsSearchNgram => '目前依詞語比對搜尋。下載後對換句話說也更有效';

  @override
  String get raiModelsSearchNgramDetail => '搜尋：n-gram 替代（依詞語比對檢索。下載後對換句話說也更有效）';

  @override
  String get raiModelsServerTitle => '本機推論伺服器';

  @override
  String get raiModelsServerConfigured => '已設定';

  @override
  String get raiModelsServerNotConfigured => '未設定';

  @override
  String get raiModelsServerCaption => '裝置端模型無法回答時，將詢問這裡。';

  @override
  String get raiModelsServerCaptionDetail =>
      '相容 OpenAI 的聊天 API（llama-server / vLLM 等）。裝置端模型失敗 / 無回應時，會附上與問題相近的參考資料一併傳遞。';

  @override
  String get raiModelsServerModelHint => '模型名稱（選填）';

  @override
  String get raiModelsRamOk => '可執行';

  @override
  String get raiModelsRamTight => '勉強';

  @override
  String get raiModelsRamNo => '記憶體不足';

  @override
  String get raiModelsRamUnknownVerdict => '未知';

  @override
  String get raiModelsFallUpNotConnected => '上行備援目標（伺服器端）未連線';

  @override
  String raiModelsServerHttpError(int status) {
    return '推論伺服器 HTTP $status';
  }

  @override
  String get raiModelsServerNoReply => '推論伺服器沒有回應';

  @override
  String raiModelsServerUnreachable(String error) {
    return '無法連線至推論伺服器：$error';
  }

  @override
  String get raiModelsLlmUnavailableHere => '此環境中無法使用裝置端模型';

  @override
  String raiModelsLlamaFetching(String tag) {
    return '正在取得 llama.cpp 執行環境（$tag）';
  }

  @override
  String get raiModelsLlamaMissingIos =>
      '未嵌入 llama.cpp（請在 Runner 中加入 llama.xcframework）';

  @override
  String get raiModelsLlamaMissing => '缺少 llama.cpp 程式庫';

  @override
  String raiModelsLlamaFetchFailed(int status) {
    return '無法取得 llama.cpp 執行環境（HTTP $status）';
  }

  @override
  String raiModelsStateCheckFailed(String error) {
    return '無法確認模型狀態：$error';
  }

  @override
  String get raiModelsExtracting => '正在解壓縮內建模型';

  @override
  String get raiModelsExtractTooLarge => '此裝置無法解壓縮內建模型（請下載）';

  @override
  String raiModelsExtractFailed(String error) {
    return '解壓縮失敗：$error';
  }

  @override
  String raiModelsDownloadFailed(String error) {
    return '下載失敗：$error';
  }

  @override
  String raiModelsNotDownloaded(String codename) {
    return '裝置端模型（$codename）尚未下載';
  }

  @override
  String get raiModelsDeviceUnavailable => '無法使用裝置端模型';

  @override
  String raiModelsFileMissing(String path) {
    return '找不到模型檔案：$path';
  }

  @override
  String get raiModelsTimeoutFirstToken => '裝置端模型 30 秒內沒有回應';

  @override
  String get raiModelsTimeoutOverall => '裝置端模型的回應過長，已中斷';

  @override
  String get raiModelsOnlyThinking => '裝置端模型沒有回應（可能僅完成了思考）';

  @override
  String raiModelsGenerateFailed(String error) {
    return '產生失敗：$error';
  }

  @override
  String get raiModelsHintSystemPolicy =>
      '「system policy」= 被沙盒 / 程式庫驗證拒絕。請使用 Debug 的 entitlements（app-sandbox=false、disable-library-validation）重新建置';

  @override
  String get raiModelsHintGatekeeper =>
      '如果被 Gatekeeper 阻擋：請在「系統設定 > 隱私權與安全性」中允許，或對 Application Support/llama_cpp 中的 dylib 執行 xattr -dr com.apple.quarantine';

  @override
  String raiModelsLoadFailedLlama(String error) {
    return '無法載入模型（llama.cpp）：$error';
  }

  @override
  String raiModelsLoadFailed(String error) {
    return '無法載入模型：$error';
  }

  @override
  String get raiModelsEmbeddingRasqText => 'RASQ MiniLM（文字）';

  @override
  String get raiModelsEmbeddingMiniLmL12 => 'MiniLM-L12 多語言（paraphrase, int8）';

  @override
  String get raiModelsEmbeddingRasqVision => 'RASQ MobileNet（貼文圖片）';

  @override
  String get raiModelsEmbeddingSiglipText => 'SigLIP2 base（文字塔 · int8）';

  @override
  String get raiModelsEmbeddingSiglipVision => 'SigLIP2 base（圖像端 · int8）';

  @override
  String raiModelsEmbeddingFailed(String message) {
    return '失敗：$message';
  }

  @override
  String get raiModelsEmbeddingUnavailableHere => '此環境中無法使用裝置端嵌入模型';

  @override
  String get raiModelsChecksumMismatch => '模型檔案已損毀（sha256 不一致）';

  @override
  String get raiModelsSizeMismatch => '模型檔案不完整';

  @override
  String get raiModelsCentralNotConfigured => '尚未設定 RASQ 伺服器的連線位址';

  @override
  String raiModelsLoadFailedOnnx(String error) {
    return '無法載入模型（onnxruntime）：$error';
  }

  @override
  String get raiModelsWebDisabled => '網路搜尋尚無法使用';

  @override
  String get raiModelsWebNoKey => '未設定 Brave Search 的金鑰';

  @override
  String get raiModelsWebAnswerTitle => '網路答案';

  @override
  String raiModelsWebFailed(String error) {
    return '搜尋失敗：$error';
  }

  @override
  String get raiModelsNoteNotInstalled => '未下載';

  @override
  String get regionHeading => '居住地區';

  @override
  String get regionCaption => '請選擇您居住的國家或地區(自行申報)。如在美國,還需選擇所在的州。';

  @override
  String get regionChoose => '請選擇';

  @override
  String regionCountryAndState(String country, String state) {
    return '$country · $state';
  }

  @override
  String get regionPickerTitle => '選擇居住地區';

  @override
  String get regionStatePickerTitle => '選擇州';

  @override
  String get regionSearchHint => '依國家或地區名稱搜尋';

  @override
  String get regionStateSearchHint => '依州名搜尋';

  @override
  String get regionNoMatch => '找不到結果';

  @override
  String get regionUnavailableBadge => '暫未提供';

  @override
  String get regionUnavailableTitle => '您所在的地區目前尚未提供 RASQ';

  @override
  String get regionUnavailableBody =>
      'RASQ 目前僅在部分地區提供。您所在的地區無法建立 RASQ 帳號。提供服務的地區日後可能會有變動。';

  @override
  String regionUnavailableBodyWith(String region) {
    return 'RASQ 目前僅在部分地區提供。在$region無法建立 RASQ 帳號。提供服務的地區日後可能會有變動。';
  }

  @override
  String get regionUnavailableBack => '返回';

  @override
  String get regionRequiredError => '請先選擇居住地區,然後再試一次。';

  @override
  String get relationalPostTitle => '貼文';

  @override
  String relationalEventTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name +$count 人',
    );
    return '$_temp0';
  }

  @override
  String relationalEventCaption(int posts, int members) {
    String _temp0 = intl.Intl.pluralLogic(
      posts,
      locale: localeName,
      other: '$posts 則',
    );
    String _temp1 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members 人',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String relationalEventPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$_temp0';
  }

  @override
  String relationalDurationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小時',
    );
    return '$_temp0';
  }

  @override
  String relationalDurationHoursMinutes(int hours, int minutes) {
    return '$hours 小時 $minutes 分鐘';
  }

  @override
  String relationalDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分鐘',
    );
    return '$_temp0';
  }

  @override
  String relationalLookback(String duration) {
    return '正在顯示 $duration前為止的對話';
  }

  @override
  String get relationalLookbackReset => '還原';

  @override
  String get relationalHeader => '依對話分組顯示';

  @override
  String relationalHeaderDetail(int bias, int maxMinutes) {
    return '聚合度 $bias / 依對話節奏最長 $maxMinutes 分鐘後沉底';
  }

  @override
  String get relationalTuningTitle => '關聯時間軸調整';

  @override
  String get relationalRetry => '重新載入';

  @override
  String get relationalEmptyTitle => '目前沒有進行中的對話';

  @override
  String get relationalEmptyHint => '追蹤對象的對話會在這裡分組顯示。下拉還能查看過去的對話';

  @override
  String get relationalTuningCancel => '取消';

  @override
  String get relationalTuningConfirm => '確定';

  @override
  String get relationalAdvanced => '進階設定';

  @override
  String get relationalSectionLinking => '聚合判定';

  @override
  String get relationalCandidateWindow => '候選視窗';

  @override
  String get relationalCandidateWindowSubtitle => '搜尋父貼文候選的最近範圍';

  @override
  String relationalMinutesValue(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分鐘',
    );
    return '$_temp0';
  }

  @override
  String relationalSecondsValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds 秒',
    );
    return '$_temp0';
  }

  @override
  String get relationalSectionWeightsPlain => '權重（一般貼文）';

  @override
  String get relationalWeightContent => '內容相似度';

  @override
  String get relationalWeightEntity => '實體比對';

  @override
  String get relationalWeightTime => '時間衰減';

  @override
  String get relationalWeightAffinity => '雙方親密度';

  @override
  String get relationalWeightTurn => '輪流發言';

  @override
  String get relationalWeightAnchor => '錨點';

  @override
  String get relationalSectionFlatBonus => '固定加分';

  @override
  String get relationalWeightCommunityPrior => '社群先驗 ±';

  @override
  String get relationalSectionLifecycle => '生命週期';

  @override
  String get relationalTentativeHold => '暫定 ROOT 保留';

  @override
  String get relationalTentativeHoldSubtitle => '確認為新話題前的保留時間';

  @override
  String get relationalResetDefaults => '恢復預設';

  @override
  String get relationalLinkBias => '聚合度';

  @override
  String get relationalLinkBiasSubtitle => '越低聚合範圍越廣（門檻依社群自動調整）';

  @override
  String get relationalTauSubtitle => '越大，時間相隔較遠的貼文也越容易關聯（τ）';

  @override
  String get relationalSectionWeights => '權重';

  @override
  String get relationalSimilarity => '相似性';

  @override
  String get relationalSimilaritySubtitle => '內容相似度 + 實體比對（明細見進階設定）';

  @override
  String get relationalCloseness => '親密度';

  @override
  String get relationalClosenessSubtitle => '雙方親密度 + 輪流發言（明細見進階設定）';

  @override
  String get relationalSectionExtra => '附加判定';

  @override
  String get relationalHardAnchor => '強錨點（URL/引用對象）';

  @override
  String get relationalReactive => '反應表達（「真的」「懂」等）';

  @override
  String get relationalTtlSubtitle => '對話沉底前的時間。依發文間隔在此範圍內自動調整';

  @override
  String relationalTtlValue(int min, int max) {
    return '$min–$max 分鐘';
  }

  @override
  String get searchChildSafePostsBlocked => '監護人已停用貼文搜尋';

  @override
  String get searchChildSafeTrendBlocked => '監護人已停用趨勢';

  @override
  String get searchTrendSettings => '趨勢設定';

  @override
  String get searchTrendCustomize => '自訂趨勢頁面';

  @override
  String get searchTrendPage => '趨勢頁面';

  @override
  String get searchTrendMenu => '選單';

  @override
  String get searchHint => '搜尋';

  @override
  String get searchSettings => '搜尋設定';

  @override
  String get searchSettingsTendency => '搜尋結果的傾向/刺激程度';

  @override
  String get searchSettingsTrendPlugins => '趨勢外掛設定';

  @override
  String get searchSettingsCacheNetwork => '快取網路設定';

  @override
  String get searchSettingsComingSoon => '此設定正在準備中。';

  @override
  String get searchSortRelevance => '相關度';

  @override
  String get searchSortNewest => '最新';

  @override
  String get searchSortOldest => '最舊';

  @override
  String get searchSortReactions => '回應最多';

  @override
  String get searchPeriodAll => '全部';

  @override
  String get searchPeriodDay => '24小時';

  @override
  String get searchPeriodWeek => '1週';

  @override
  String get searchPeriodMonth => '1個月';

  @override
  String get searchPeriodChip => '期間';

  @override
  String get searchAgoJustNow => '剛剛';

  @override
  String searchAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分鐘前',
    );
    return '$_temp0';
  }

  @override
  String searchAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小時前',
    );
    return '$_temp0';
  }

  @override
  String searchAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String get serversOpen => '開啟伺服器';

  @override
  String serversUsers(String count) {
    return '$count 位使用者';
  }

  @override
  String serversPosts(String count) {
    return '$count 則貼文';
  }

  @override
  String get serversRegistrationOpen => '開放註冊';

  @override
  String get serversRegistrationClosed => '邀請制 / 停止註冊';

  @override
  String get serversStatsSeparator => ' · ';

  @override
  String get serversRaiTitle => 'RAi 分析的使用者傾向';

  @override
  String serversRaiSource(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '由雲端版 RAi 根據 $count 則公開貼文整理',
    );
    return '$_temp0';
  }

  @override
  String get serversInfoTitle => '伺服器資訊';

  @override
  String serversInfoUnavailable(String host) {
    return '$host 未提供伺服器資訊（可能是沒有實例的服務，或無法取得）';
  }

  @override
  String serversCountHundredMillions(String value) {
    return '$value億';
  }

  @override
  String serversCountTenThousands(String value) {
    return '$value萬';
  }

  @override
  String get sessionUnnamedDevice => '未命名裝置';

  @override
  String get sessionShareAskFirstTitle => '要共享存取權杖並一次登入 SNS 帳號嗎？';

  @override
  String sessionShareAskDeviceTitle(String device) {
    return '也要與新裝置（$device）共享 SNS 存取權杖嗎？';
  }

  @override
  String sessionShareAskFirstMessage(String devices) {
    return '有新裝置（$devices）登入了此 RASQ 帳號。選擇「是」後，SNS 存取權杖將在裝置之間以端對端加密（E2E）方式共享，新裝置也會登入 SNS 帳號。RASQ 的伺服器無法讀取內容。之後可在「帳號安全性」中變更。';
  }

  @override
  String sessionShareAskFirstMessageHandle(String devices, String handle) {
    return '有新裝置（$devices）登入了 RASQ 帳號 @$handle。選擇「是」後，SNS 存取權杖將在裝置之間以端對端加密（E2E）方式共享，新裝置也會登入 SNS 帳號。RASQ 的伺服器無法讀取內容。之後可在「帳號安全性」中變更。';
  }

  @override
  String get sessionShareAskDeviceMessage =>
      '有新裝置登入了此 RASQ 帳號。如果不是你本人操作，請選擇「否」，並在「帳號安全性」中將該裝置登出。';

  @override
  String sessionShareAskDeviceMessageHandle(String handle) {
    return '有新裝置登入了 RASQ 帳號 @$handle。如果不是你本人操作，請選擇「否」，並在「帳號安全性」中將該裝置登出。';
  }

  @override
  String get sessionDeviceListSeparator => '、';

  @override
  String get sessionShareYes => '是';

  @override
  String get sessionShareNo => '否';

  @override
  String sessionShareEmailApproved(String device) {
    return '已與透過電子郵件核准的裝置（$device）共享 SNS 存取權杖';
  }

  @override
  String sessionShareImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已使用共享的存取權杖一次登入 SNS 帳號（$count 個）',
    );
    return '$_temp0';
  }

  @override
  String get sessionLoginFailed => '登入失敗';

  @override
  String get sessionSanctionLight => '輕度限制';

  @override
  String get sessionSanctionModerate => '中度限制（發言需審查延遲）';

  @override
  String get sessionSanctionSevere => '重度限制（功能停用）';

  @override
  String get sessionSanctionPermanent => '永久凍結';

  @override
  String get sessionSanctionNone => '無限制';

  @override
  String sessionSanctionBlocked(String feature) {
    return '由於帳號處置，$feature無法使用。';
  }

  @override
  String sessionSanctionBlockedUntil(String feature, String until) {
    return '由於帳號處置，$feature無法使用（至 $until）。';
  }

  @override
  String get sessionFeatureAstellJoin => '加入 ASTell';

  @override
  String get sessionFeatureAstellCreate => '建立 ASTell 房間';

  @override
  String get sessionFeatureAstellShare => '在 ASTell 中分享和聊天';

  @override
  String get sessionFeatureAstellStream => 'ASTell 的螢幕分享和直播';

  @override
  String get sessionFeatureStoreReview => '發布商店評論';

  @override
  String get sessionFeatureAccountFollow => '追蹤 RASQ 帳號';

  @override
  String get sessionFeaturePost => '發文';

  @override
  String get sessionFeaturePostMedia => '發布附媒體的貼文';

  @override
  String get sessionFeatureDm => '私訊';

  @override
  String get sessionFeatureReaction => '回應';

  @override
  String get sessionCentralNotConfigured => '未設定 RASQ Central 的連線目標';

  @override
  String get sessionLogoutSnsHeading => '此 RASQ 帳號的 SNS 帳號';

  @override
  String get sessionLogoutSnsLogout => '同時登出 SNS 帳號';

  @override
  String get sessionLogoutSnsLogoutSubtitle => '從此裝置中刪除 SNS 登入資訊';

  @override
  String get sessionLogoutSnsMoveToLocal => '移至「僅限此裝置」';

  @override
  String get sessionLogoutSnsMoveToLocalSubtitle => '可以作為「僅限此裝置」的帳號繼續使用';

  @override
  String get sessionCancel => '取消';

  @override
  String get sessionChildSafeAddBlocked => '監護人已禁止新增 SNS 帳號';

  @override
  String get sessionAccountKindLocal => '僅限此裝置';

  @override
  String get sessionAccountKindCentral => 'RASQ Central';

  @override
  String get sessionCarryThisAccount => '此 RASQ 帳號';

  @override
  String get sessionCarrySemantics => '要新增此裝置的 SNS 帳號嗎？';

  @override
  String sessionCarryTitle(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '要將此裝置上開啟的 $count 個帳號新增至 $account 嗎？',
    );
    return '$_temp0';
  }

  @override
  String sessionCarryMessage(String account) {
    return '新增的帳號將成為 $account 的 SNS 帳號，也會顯示在其他裝置和 Web 主控台中。未新增的帳號保留在「僅限此裝置」中（之後用 $account 登入 SNS 時也會被新增）。';
  }

  @override
  String get sessionCarryInBundle => '（之前用此 RASQ 帳號連結過）';

  @override
  String get sessionCarryNone => '不新增';

  @override
  String sessionCarryAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新增所選的 $count 個',
    );
    return '$_temp0';
  }

  @override
  String get settingsActionBarTitle => '外掛按鈕';

  @override
  String get settingsActionBarBackTooltip => '返回';

  @override
  String get settingsActionBarBundleManual => '手動放置（從列上的 (+) 新增前不顯示）';

  @override
  String get settingsActionBarBundleAlone => '單獨放在末尾';

  @override
  String settingsActionBarBundleInto(String label, String percent) {
    return '併入「$label」的組合（$percent%）';
  }

  @override
  String get settingsActionBarAutoOnTitle => '開啟介面時自動開啟';

  @override
  String get settingsActionBarOn => '開';

  @override
  String get settingsActionBarOff => '關';

  @override
  String settingsActionBarAutoDefault(String state) {
    return '預設（$state）';
  }

  @override
  String settingsActionBarAutoDefaultDeclared(String state) {
    return '預設（$state，由外掛宣告）';
  }

  @override
  String settingsActionBarAutoOverridden(String state) {
    return '已在設定中覆寫（預設為 $state）';
  }

  @override
  String get settingsActionBarEmptyCaption => '從商店新增的外掛會顯示在這裡';

  @override
  String get settingsActionBarIntroCaption => '關閉開關後，所有帳號中都不再顯示。';

  @override
  String get settingsActionBarIntroDetail =>
      '開關是整個裝置的總開關（關閉時在所有帳號、所有介面中都不顯示，也不會自動執行）。「開啟介面時自動開啟」是開啟該介面那一刻的初始狀態（在介面內切換的值不會保留到下次）。';

  @override
  String get settingsActionBarPostTileHeader => '貼文卡片';

  @override
  String get settingsActionBarPostTileEmptyDetail =>
      '宣告了 post.action 的外掛會顯示在這裡（從商店新增）';

  @override
  String get settingsActionBarViewerHeader => '全螢幕';

  @override
  String get settingsActionBarViewerEmptyDetail =>
      '宣告了 viewer.overlay 的外掛（如 QR 碼偵測）會顯示在這裡';

  @override
  String get settingsActionBarViewerPlacement => '全螢幕動作列上的開 / 關按鈕';

  @override
  String get settingsActionBarMediaHeader => '編輯畫面';

  @override
  String get settingsActionBarMediaEmptyDetail =>
      '宣告了 composer.media 的外掛會顯示在這裡';

  @override
  String settingsActionBarFilterPlacement(String placement) {
    return '濾鏡 · $placement';
  }

  @override
  String get settingsActionBarComposerTextHeader => '編輯器內文';

  @override
  String get settingsActionBarComposerTextEmptyDetail =>
      '宣告了 composer.text 的外掛會顯示在這裡';

  @override
  String get settingsActionBarComposerTextPlacement =>
      '編輯器動作列上的開 / 關按鈕（長按進入設定）';

  @override
  String get settingsActionBarTransformHeader => '貼文加工（自動）';

  @override
  String get settingsActionBarTransformEmptyDetail =>
      '宣告了 post.transform 的外掛會顯示在這裡';

  @override
  String get settingsActionBarTransformPlacement => '顯示前加工內文（無按鈕）';

  @override
  String settingsActionBarThisAccountHeader(String account) {
    return '此帳號（$account）';
  }

  @override
  String get settingsActionBarNoAccount => '未選擇';

  @override
  String get settingsActionBarThisAccountEmptyCaption => '是否在此帳號中顯示';

  @override
  String get settingsActionBarThisAccountEmptyDetail => '是否在此帳號中顯示貼文卡片的按鈕';

  @override
  String settingsActionBarSlotSubtitle(String plugin, String tags) {
    return '$plugin · 標籤：$tags';
  }

  @override
  String get settingsActionBarThresholdTitle => '合併門檻';

  @override
  String get settingsActionBarThresholdSubtitle => '合併相似按鈕的程度';

  @override
  String get settingsActionBarThresholdDetail => '標籤相似度達到此值以上時，併入現有按鈕的組合';

  @override
  String get settingsActionBarEditButton => '編輯動作列';

  @override
  String get settingsBackendTitle => 'RASQ 伺服器';

  @override
  String get settingsBackendErrorUnparseable =>
      '無法解析連線位址。請依「http://192.168.3.14:8080」或「https://central.example」的格式輸入。';

  @override
  String get settingsBackendSaved => '已儲存';

  @override
  String get settingsBackendErrorEnterUrl =>
      '請輸入連線位址（例：http://192.168.3.14:8080）';

  @override
  String get settingsBackendCentralNotCentralHint =>
      '請在 Central 欄位中輸入 RASQ Central 的位址，而不是 ORGATE';

  @override
  String settingsBackendCentralConnectFailed(
    String url,
    String error,
    String hint,
  ) {
    return '無法連線（$url）— $error$hint';
  }

  @override
  String settingsBackendCentralOk(String algorithm, String keyHead) {
    return '連線正常 — 簽章金鑰 $algorithm $keyHead…';
  }

  @override
  String settingsBackendAccountLine(String handle, String displayName) {
    return 'RASQ 帳號：@$handle（$displayName）';
  }

  @override
  String get settingsBackendAccountNotCreatedLine =>
      'RASQ 帳號：未建立（可透過下方的「開啟 RASQ 帳號」建立）';

  @override
  String settingsBackendAccountLoadFailedLine(String error) {
    return '無法取得 RASQ 帳號 — $error';
  }

  @override
  String get settingsBackendOrgateNotConfiguredLine =>
      'ORGATE：未設定（無法登入 RASQ 帳號）';

  @override
  String settingsBackendOrgateOk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個',
    );
    return 'ORGATE：連線正常 — 權杖公開金鑰 $_temp0';
  }

  @override
  String settingsBackendOrgateNoKeys(String url) {
    return 'ORGATE：回應中沒有權杖公開金鑰（$url）';
  }

  @override
  String settingsBackendOrgateConnectFailed(String url, String error) {
    return '無法連線到 ORGATE（$url）— $error';
  }

  @override
  String get settingsBackendCaption => 'RASQ 帳號和商店所用伺服器的連線位址。SNS 的貼文和時間軸不經過這裡。';

  @override
  String get settingsBackendCaptionDetail =>
      'RASQ Central 是存放公開、共享內容（個人檔案、商店、ASTell、貼文、清單等）的伺服器；ORGATE 是存放僅本人可見資訊（登入、密碼、電子郵件地址）以及 Mastodon 等登入（OAuth 代理）的伺服器。RASQ 帳號的登入透過 ORGATE 進行，其權杖也用於 Central。SNS 的貼文和時間軸都不經過這兩者，由外掛直接連線各實例。';

  @override
  String get settingsBackendCentralLabel => 'RASQ Central 的連線位址（留空則沿用 ORGATE）';

  @override
  String get settingsBackendOrgateLabel => 'ORGATE（登入、僅本人資訊）的連線位址';

  @override
  String get settingsBackendSaveButton => '儲存';

  @override
  String get settingsBackendTestButton => '測試連線';

  @override
  String get settingsBackendCentralDisconnected => 'Central：未連線（無法建立 RASQ 帳號）';

  @override
  String get settingsBackendCentralDisconnectedDetail =>
      'Central：未連線 — 外掛商店僅有內建外掛，無法建立 RASQ 帳號（僅限此裝置）。';

  @override
  String get settingsBackendOrgateDisconnected => 'ORGATE：未連線（無法登入 RASQ 帳號）';

  @override
  String get settingsBackendTestEndpointsSection => '測試用連線位址';

  @override
  String get settingsBackendTestEndpointsTitle =>
      '使用模擬 SNS 和示範用 Central / ORGATE';

  @override
  String get settingsBackendTestEndpointsSubtitle => '用於錄製預覽';

  @override
  String settingsBackendTestEndpointsDetail(
    String misskeyHost,
    String mastodonHost,
    String blueskyHost,
    String centralPort,
    String orgatePort,
  ) {
    return '用於錄製預覽。將 Misskey / Mastodon / Bluesky 的 $misskeyHost / $mastodonHost / $blueskyHost 指向此位址的模擬服務，並同時切換 Central（:$centralPort）和 ORGATE（:$orgatePort）';
  }

  @override
  String get settingsBackendTestAddressLabel =>
      '模擬環境的位址（同一台機器為 127.0.0.1，其他機器則為其 IP）';

  @override
  String get settingsBackendTestCaption => '請在 SNS 登入畫面的伺服器欄位中輸入上方的主機名稱。';

  @override
  String get settingsBackendTestCaptionDetail =>
      '各 SNS 在其登入畫面的伺服器欄位中輸入上方的主機名稱（授權頁面會自動通過；Bluesky 的 ID / 密碼可任意填寫）。RASQ 帳號請從帳號登入進入。切換後，已登入的 SNS 會從下次載入起使用新的連線位址。';

  @override
  String get settingsBackendAccountSection => 'RASQ 帳號';

  @override
  String settingsBackendAccountLoadError(String error) {
    return '無法取得帳號：$error';
  }

  @override
  String get settingsBackendNoServer => '尚未設定連線位址。';

  @override
  String get settingsBackendAccountNotCreated => '尚未建立 RASQ 帳號。';

  @override
  String get settingsBackendOpenAccountButton => '開啟 RASQ 帳號';

  @override
  String get settingsBackendAccountDeviceOnly =>
      '此帳號僅在本裝置上有效。可在編輯個人檔案中變更帳號代稱和顯示名稱。';

  @override
  String get settingsBackendBundleSection => '帳號組合';

  @override
  String get settingsBackendBundleCaption =>
      '綁定時只傳送 SNS 帳號清單。僅在你選擇裝置間共享、網頁版或在帳號頁面顯示貼文時，才會傳送登入金鑰。';

  @override
  String get settingsBackendBundleCaptionDetail =>
      '綁定時傳送到伺服器的只有 SNS 類型、伺服器、帳號和顯示名稱。存取權杖僅在你選擇裝置間共享（端對端加密，伺服器無法讀取）、網頁版保管庫（以伺服器金鑰加密，伺服器可以解密）、在帳號頁面顯示貼文（同上）時才會傳送（隱私權政策第 4 條）。';

  @override
  String get settingsBackendNoSessions => '沒有已登入的帳號。';

  @override
  String get settingsColumnsTitle => '欄寬';

  @override
  String get settingsColumnsIntroCaption => '在平板或電腦等寬螢幕上，設定左右欄的寬度。';

  @override
  String get settingsColumnsIntroDetail =>
      '在寬螢幕（平板 / 桌面 / Web）上，設定小欄（搜尋或開啟頁面的一側）與大欄（開啟的頁面）的寬度比例。';

  @override
  String get settingsColumnsSplitHeader => '小欄 / 大欄比例';

  @override
  String settingsColumnsSplitDefault(String hint) {
    return '$hint（預設）';
  }

  @override
  String get settingsColumnsLargeWidthLabel => '大欄寬度';

  @override
  String get settingsColumnsSmallWidthLabel => '小欄寬度';

  @override
  String get settingsColumnsShrinkCaption => '螢幕放不下時會自動縮小。';

  @override
  String settingsColumnsShrinkDetail(String minWidth) {
    return '螢幕太窄放不下時，會保留另一欄至少 $minWidth px，並縮小到使小欄不寬於大欄。';
  }

  @override
  String get settingsColumnsSwingInColumnTitle => '在右欄中開啟 Swing';

  @override
  String get settingsColumnsSwingInColumnSubtitle =>
      '關閉時以全螢幕開啟（預設開啟。指定全螢幕的外掛的 Swing 一律全螢幕）';

  @override
  String get settingsColumnsCurrentHeader => '目前螢幕上的寬度';

  @override
  String settingsColumnsPreviewWidths(String small, String large) {
    return '小 $small px / 大 $large px';
  }

  @override
  String get settingsColumnsNarrowCaption => '目前螢幕較窄，因此只有一欄。';

  @override
  String settingsColumnsNarrowDetail(String breakpoint) {
    return '目前螢幕較窄，因此只顯示一欄（寬度達到 $breakpoint px 以上時分為小欄 / 大欄）。';
  }

  @override
  String get settingsColumnsPreviewSmall => '小';

  @override
  String get settingsColumnsPreviewLarge => '大';

  @override
  String get settingsCommonSeparator => ' · ';

  @override
  String settingsCommonBullet(String text) {
    return '• $text';
  }

  @override
  String settingsCommonRange(int min, int max) {
    return '$min–$max';
  }

  @override
  String get settingsComposerTitle => '貼文編輯器';

  @override
  String get settingsComposerAutoAccountTitle => '自動選擇發文帳號';

  @override
  String get settingsComposerAutoAccountSubtitle => '自動將發布目標切換為符合草稿的帳號';

  @override
  String get settingsComposerAutoAccountDetail =>
      '自動將發布目標切換為草稿內容符合發布目標篩選條件的帳號（手動選擇一律優先）';

  @override
  String get settingsComposerRasqLinkedTitle => '同時發布到 RASQ 帳號';

  @override
  String get settingsComposerRasqLinkedSubtitle => '向多個帳號發布時，也可以選擇 RASQ 帳號';

  @override
  String get settingsComposerRasqLinkedDetail =>
      '在多選模式下，也可以選擇 RASQ 帳號這一列（一般貼文 / 節點連動）。傳送方式與篩選在「自訂發布目標」的 RASQ 分頁中設定。超出 RASQ 上限（1000 字 / 6 個附件 / 6 個投票選項 / 3 則貼文）的貼文不會傳送到 RASQ';

  @override
  String get settingsEmomTitle => 'EmoM 閾值';

  @override
  String get settingsEmomBandLow => '保守 — 更早隱藏被營運方限制的趨勢';

  @override
  String get settingsEmomBandMiddle => '普通';

  @override
  String get settingsEmomBandHigh => '寬鬆 — 僅隱藏被營運方嚴格限制的趨勢';

  @override
  String get settingsEmomStatusSending => '正在傳送…';

  @override
  String get settingsEmomStatusNoAccount => '使用 RASQ 帳號登入後即可公開（在此裝置上仍可使用）';

  @override
  String get settingsEmomStatusFailed => '傳送失敗。下次開啟時（或重新載入趨勢時）將重新傳送';

  @override
  String settingsEmomStatusDisclosed(String value) {
    return '已公開（值 $value）';
  }

  @override
  String get settingsEmomStatusPending => '尚未送達';

  @override
  String get settingsEmomStatusNotDisclosed => '未公開';

  @override
  String get settingsEmomIntro =>
      'EmoM 是 RASQ 用於估算貼文與趨勢的情緒強度與刺激強度的模型（準備中）。目前，此閾值僅在 RASQ 營運方核實檢舉並限制趨勢時作為參考。';

  @override
  String get settingsEmomThresholdLabel => '閾值';

  @override
  String get settingsEmomScaleLow => '低（更容易隱藏）';

  @override
  String get settingsEmomScaleHigh => '高（不易隱藏）';

  @override
  String settingsEmomExplanation(String defaultValue) {
    return '閾值越高，越能接受刺激性強的話題，被營運方限制的趨勢越不容易被隱藏。閾值越低，越早隱藏被限制的趨勢。預設值為 $defaultValue。';
  }

  @override
  String get settingsEmomDiscloseTitle => '公開閾值（用作限制的參考）';

  @override
  String get settingsEmomDiscloseSubtitle =>
      '僅將數值傳送到 RASQ 的伺服器。營運方只使用已公開數值的彙總分布（每個數值有多少人），不會單獨查看你的數值。關閉後，將刪除已傳送的數值。';

  @override
  String get settingsEmomRestrictionExplanation =>
      '營運方以「N%」限制某個趨勢時，已公開閾值由低到高約 N% 的人將看不到該趨勢。即使不公開，也會以此裝置上的閾值進行同樣的判定（閾值儲存在此裝置上）。被設為「對所有人隱藏」的趨勢，無論閾值為何都不會顯示。被隱藏的趨勢只是不再出現在搜尋的趨勢列表中。';

  @override
  String get settingsHomeTitle => '所有設定';

  @override
  String get settingsHomeSearchHint => '搜尋設定與操作';

  @override
  String get settingsHomeSearchClear => '清除';

  @override
  String get settingsHomeSearchError => '無法搜尋設定';

  @override
  String get settingsHomeSearchEmpty => '找不到結果';

  @override
  String settingsHomeSearchEmptyHint(String query) {
    return '沒有符合「$query」的設定。請換個說法，或問問 RAi';
  }

  @override
  String get settingsHomeSearchOperations => '操作（由 RAi 引導）';

  @override
  String get settingsHomeOtherHeader => '其他設定';

  @override
  String get settingsHomeComposer => '貼文編輯器';

  @override
  String get settingsHomeComposerKeywords => '發文畫面，草稿';

  @override
  String get settingsHomeThemeKeywords => '主題，換膚，深色模式，淺色，顏色，字型';

  @override
  String get settingsHomeAccountImportant => '帳號重要設定';

  @override
  String get settingsHomeAccountImportantSubtitle => '變更密碼或刪除帳號請在網頁版進行';

  @override
  String get settingsHomeAccountImportantDetail => '重設密碼、刪除帳號等需要密碼的操作請在網頁版進行';

  @override
  String settingsHomeLogout(String handle) {
    return '登出 @$handle';
  }

  @override
  String get settingsHomeLogoutConfirmTitle => '要登出嗎？';

  @override
  String get settingsHomeLogoutConfirmMessage => '此帳號的外掛配置會保留在裝置上。';

  @override
  String get settingsHomeLogoutConfirm => '登出';

  @override
  String get settingsHomeCancel => '取消';

  @override
  String get settingsHomeOk => '確定';

  @override
  String get settingsHomeGenericTitle => '設定';

  @override
  String get settingsHomeUnknownSection => '未知的設定區段';

  @override
  String get settingsHomeThemeModeSystem => '系統';

  @override
  String get settingsHomeThemeModeLight => '淺色';

  @override
  String get settingsHomeThemeModeDark => '深色';

  @override
  String get settingsHomePlaceholder => '此設定正在準備中。';

  @override
  String get settingsHomePlaceholderDetail =>
      '此設定將在第二層級以下的規格確定後（M4：FOW/DSL 繪製）實作。';

  @override
  String get settingsHomePageMissing => '此頁面不存在';

  @override
  String get settingsHomePageMissingHint => '此帳號的 SNS 沒有這項設定。';

  @override
  String get settingsHomePageLoadError => '無法載入設定頁面';

  @override
  String get settingsHomeRemoteLoadError => '無法從伺服器取得設定';

  @override
  String get settingsHomeRemotePermissionHint =>
      '\n\nApp 的權限不足。登出後重新登入，即可授予新的權限。';

  @override
  String get settingsHomeSaveFailed => '無法儲存';

  @override
  String get settingsHomeChildLocked => '由於處於監護中，此處無法變更（敏感媒體一律隱藏）。';

  @override
  String get settingsHomeTargetAccount => '要設定的帳號';

  @override
  String settingsHomeMissingSnsPage(String area) {
    return 'SNS 外掛未提供設定頁面「$area」';
  }

  @override
  String get settingsLearningTitle => '為演算法和社群做出貢獻';

  @override
  String settingsLearningError(String error) {
    return '操作失敗 — $error';
  }

  @override
  String get settingsLearningGrantConfirmButton => '同意並參與';

  @override
  String get settingsLearningGrantPointOptional =>
      '此項為自願。即使拒絕或退出，RASQ 的功能和付費功能仍可照常使用';

  @override
  String get settingsLearningGrantPointScope => '僅包括你自己發布的公開貼文，以及這些貼文是否屬於同一段對話';

  @override
  String get settingsLearningGrantPointExcluded =>
      '不會傳送他人的貼文、私訊、限定公開的貼文、ASTell 的對話、RAi 的提問與回答';

  @override
  String get settingsLearningGrantPointVerifiedOnly => '僅接受已完成擁有者驗證的 SNS 帳號的貼文';

  @override
  String get settingsLearningGrantPointPurpose => '用於改善關聯時間軸彙整對話的方式';

  @override
  String get settingsLearningGrantPointDeletion => '退出時，會立即刪除已傳送的資料';

  @override
  String get settingsLearningGrantExtendedNotice =>
      '這是驗證用的設定。還會傳送對他人貼文的判定和 RAi 的對話。';

  @override
  String get settingsLearningGrantExtendedNoticeDetail =>
      'CENTRAL_LEARNING_SCOPE=extended(S-049 / S-050)。正式環境中不使用。';

  @override
  String get settingsLearningGrantScopeDetail =>
      'D-370 / S-051。從關聯 TL 的對話事件中，僅將自己的貼文（可確認為公開的貼文。Bluesky 全部為公開）傳送到 POST /me/learning/contributions（v2，self = 自己的 SNS 帳號）。Central 會確認擁有者驗證（sns_links.verified_at），以及所有貼文是否皆為 a=-1·vis=public。每次接收時都會重新確認年齡和監護人同意。內文中的 @提及和 URL 會被隱藏。';

  @override
  String get settingsLearningGrantReadFullButton => '閱讀完整說明';

  @override
  String get settingsLearningGrantAgreeCheckbox => '我已閱讀說明，並同意提供資料';

  @override
  String settingsLearningDocumentVersion(String version) {
    return '文件版本：$version';
  }

  @override
  String get settingsLearningAgeTitle => '申報年齡';

  @override
  String get settingsLearningAgeConfirmButton => '申報';

  @override
  String get settingsLearningGuardianConsent => '已取得監護人同意';

  @override
  String get settingsLearningAgeDeclared => '已申報年齡';

  @override
  String get settingsLearningCodeSheetTitle => '使用撤回碼撤回';

  @override
  String get settingsLearningCodeConfirmButton => '撤回';

  @override
  String get settingsLearningCodeSheetBody =>
      '請輸入同意時核發的撤回碼。即使無法登入提供資料的 RASQ 帳號，也可以撤回。';

  @override
  String get settingsLearningCodeHint => '撤回碼';

  @override
  String get settingsLearningWithdrawnByCode => '已退出。已傳送的資料將被刪除';

  @override
  String get settingsLearningReasonAgeRequired => '需要申報年齡';

  @override
  String get settingsLearningReasonUnder16 => '需年滿 16 歲才能參與';

  @override
  String get settingsLearningReasonGuardianRequired => '16～17 歲的使用者需要監護人同意';

  @override
  String get settingsLearningIntroNotice =>
      '你可以傳送自己發布的公開貼文，協助改善對話的彙整方式。此項為自願，可隨時退出。';

  @override
  String get settingsLearningIntroNoticeDetail =>
      'D-243 / D-363 / D-370。同意記錄在 Central 的 account_consents（kind = learning）中。預設範圍（own）下，僅將關聯 TL 對話中自己的公開貼文傳送到 POST /me/learning/contributions。正式環境中關閉接收（CENTRAL_LEARNING_OPEN=false）。';

  @override
  String get settingsLearningReadAboutTitle => '閱讀說明';

  @override
  String get settingsLearningReadAboutSubtitle => '傳送的內容、用途和保存期間';

  @override
  String get settingsLearningStatusSection => '狀態';

  @override
  String get settingsLearningServerNotConfiguredTitle => '尚未設定 RASQ 伺服器的連線位址';

  @override
  String get settingsLearningServerNotConfiguredSubtitle => '設定連線位址後即可查看';

  @override
  String get settingsLearningNoAccountTitle => '尚未建立 RASQ 帳號';

  @override
  String get settingsLearningNoAccountSubtitle => '資料提供依 RASQ 帳號記錄';

  @override
  String settingsLearningLoadError(String error) {
    return '無法取得：$error';
  }

  @override
  String get settingsLearningStatusTitle => '貢獻';

  @override
  String get settingsLearningStatusJoined => '參與中';

  @override
  String get settingsLearningStatusNotJoined => '未參與';

  @override
  String get settingsLearningSinceTitle => '同意日期';

  @override
  String get settingsLearningOpenTitle => '接收';

  @override
  String get settingsLearningOpenYes => '接收中';

  @override
  String get settingsLearningOpenNo => '尚未開始';

  @override
  String get settingsLearningAgeUndeclared => '未申報';

  @override
  String get settingsLearningSentTitle => '已傳送的資料';

  @override
  String settingsLearningSentValue(int relational, int rai) {
    String _temp0 = intl.Intl.pluralLogic(
      relational,
      locale: localeName,
      other: '$relational 筆',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rai,
      locale: localeName,
      other: '$rai 筆',
    );
    return '對話 $_temp0 · RAi $_temp1';
  }

  @override
  String get settingsLearningExamplesTitle => '雲端判定範例';

  @override
  String settingsLearningExamplesValue(int examples, int hardNegative) {
    String _temp0 = intl.Intl.pluralLogic(
      examples,
      locale: localeName,
      other: '$examples 筆',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hardNegative,
      locale: localeName,
      other: '$hardNegative 筆',
    );
    return '$_temp0(疑似但不同 $_temp1)';
  }

  @override
  String get settingsLearningPostsLabelsTitle => '貼文 / 標籤';

  @override
  String get settingsLearningModelsTitle => '使用這些資料的模型';

  @override
  String get settingsLearningModelsNone => '無';

  @override
  String get settingsLearningModelsSeparator => '、';

  @override
  String get settingsLearningWithdrawTitle => '停止貢獻';

  @override
  String get settingsLearningWithdrawMessage => '將立即停止傳送資料，並刪除已傳送的資料。';

  @override
  String get settingsLearningWithdrawConfirm => '停止';

  @override
  String get settingsLearningCancel => '取消';

  @override
  String get settingsLearningWithdrawn => '已撤回';

  @override
  String get settingsLearningDeclareAgeButton => '申報年齡';

  @override
  String get settingsLearningGranted => '已參與。請記下下方的撤回碼，即使無法登入也能退出';

  @override
  String get settingsLearningGrantButton => '確認內容並參與';

  @override
  String get settingsLearningGrantClosedButton => '接收尚未開始';

  @override
  String get settingsLearningCodeSection => '撤回碼';

  @override
  String get settingsLearningCodeSubtitle => '點按即可複製。即使無法登入，也可以用此碼退出';

  @override
  String get settingsLearningCodeCopied => '已複製撤回碼';

  @override
  String get settingsLearningCodeStoredOnGrantDevice => '撤回碼已儲存在同意時使用的裝置上。';

  @override
  String get settingsLearningOtherSection => '其他';

  @override
  String get settingsLearningByCodeTitle => '使用撤回碼退出';

  @override
  String get settingsLearningByCodeSubtitle => '無法登入時';

  @override
  String get settingsLearningDeletionCaption =>
      '刪除帳號時，已傳送的資料也會被刪除。任何人都無法查詢他人是否參與。';

  @override
  String get settingsLearningDeletionCaptionDetail =>
      '刪除 RASQ 帳號時，也會同時開始停止提供並刪除已提供的資料（learning_contributions 隨 accounts 的刪除而刪除）。任何人都無法查詢他人是否提供了資料（GET /me/learning 只回傳自己的狀態）。';

  @override
  String get settingsLearningKindsSection => '傳送的內容';

  @override
  String get settingsLearningKindRelationalTitle => '自己的公開貼文';

  @override
  String get settingsLearningKindRelationalSubtitleExtended => '在時間軸中彙整的對話';

  @override
  String get settingsLearningKindRelationalSubtitle => '在時間軸中彙整為對話的你的公開貼文';

  @override
  String get settingsLearningKindRelationalDetailExtended =>
      '對話事件（組）中的公開貼文。依作者判定是否允許用於學習，僅傳送已允許作者和自己的貼文。內文中的 @提及和 URL 會被隱藏。';

  @override
  String get settingsLearningKindRelationalDetail =>
      'D-370。對話事件中自己的貼文（可確認為公開的貼文），以及這些貼文屬於同一段對話這項資訊（關聯標籤）。他人的貼文僅傳送數量（參與者·貼文數）。';

  @override
  String get settingsLearningUnverifiedNotice =>
      '未完成擁有者驗證的 SNS 帳號的貼文未被接受。可在編輯個人檔案中進行驗證。';

  @override
  String get settingsLearningUnverifiedButton => '驗證';

  @override
  String get settingsLearningKindCloudTitle => '在雲端彙整';

  @override
  String get settingsLearningKindCloudSubtitle => '難以判斷的對話彙整由雲端 RAi 來決定';

  @override
  String get settingsLearningKindCloudDetail =>
      'D-367 / S-050。將裝置端引擎在閾值附近決定的關聯（貼文 → 對話）傳送到 POST /me/relational/judge，依雲端 LLM 的判定重新彙整。僅限作者已允許的組合。判定範例（疑似但不同 = hard_negative，分開但相同 = hard_positive）會保留用於學習，退出後刪除。';

  @override
  String get settingsLearningKindRaiSubtitle => '向 RAi 的提問與回答';

  @override
  String get settingsLearningKindRaiDetail =>
      '提問（@提及和 URL 會被隱藏）、回答、模式、使用的函式名稱、模型 id。不包含他人的貼文。';

  @override
  String get settingsLearningPreloadTitle => '預先載入裝置端模型';

  @override
  String get settingsLearningPreloadSubtitle => '加快判定的預檢（僅限已下載時）';

  @override
  String get settingsLearningPreloadDetail =>
      '在啟動後不久載入 RAi 的裝置端模型（預設 Qwen3.5 2B），用於作者的預檢。未下載時不會下載（僅依規則預檢）。';

  @override
  String get settingsLearningDebugSection => '開發者詳細資訊';

  @override
  String get settingsLearningDebugActiveTitle => '是否在收集';

  @override
  String get settingsLearningDebugActiveYes => '是';

  @override
  String get settingsLearningDebugActiveNo => '否（請確認同意、接收、監護狀態）';

  @override
  String get settingsLearningDebugScopeTitle => '接收範圍';

  @override
  String get settingsLearningDebugScopeExtended => 'extended（驗證用）';

  @override
  String get settingsLearningDebugScopeOwn => 'own（僅自己的公開貼文）';

  @override
  String get settingsLearningDebugPendingTitle => '等待傳送';

  @override
  String settingsLearningDebugPendingValue(String relational, String rai) {
    return '對話 $relational · RAi $rai';
  }

  @override
  String get settingsLearningDebugSentTitle => '本次啟動已傳送';

  @override
  String settingsLearningDebugSentValue(
    String relational,
    String rai,
    String skipped,
  ) {
    return '對話 $relational · RAi $rai · 略過 $skipped';
  }

  @override
  String settingsLearningDebugCloudValue(
    String decisions,
    String hardNegative,
    String hardPositive,
    String agree,
    String pending,
    String skipped,
  ) {
    return '判定 $decisions（疑似但不同 $hardNegative · 分開但相同 $hardPositive · 一致 $agree）· 等待 $pending · 略過 $skipped';
  }

  @override
  String get settingsLearningDebugCloudOff => '關';

  @override
  String get settingsLearningDebugModelTitle => '裝置端模型';

  @override
  String get settingsLearningDebugFlushing => '傳送中…';

  @override
  String get settingsLearningDebugFlushButton => '立即傳送';

  @override
  String get settingsLearningDebugVerdictsSection => '作者判定';

  @override
  String get settingsLearningDebugLogSection => '記錄';

  @override
  String get settingsLegalTitle => '說明與法律聲明';

  @override
  String get settingsLegalVersionTitle => '版本';

  @override
  String get settingsLegalHelpTitle => '說明';

  @override
  String get settingsLegalTourTitle => '再次查看 RASQ 使用導覽';

  @override
  String get settingsLegalCookiesTitle => '關於 Cookie';

  @override
  String get settingsLegalPluginTermsHeader => 'SNS 外掛條款';

  @override
  String get settingsLegalPluginNoTerms => '未提供條款';

  @override
  String get settingsLegalLicensesHeader => '授權';

  @override
  String get settingsLegalLicensesTitle => '開放原始碼授權';

  @override
  String get settingsLegalLicensesSubtitle => 'Flutter 及內建程式庫';

  @override
  String get settingsMuteBlockTitle => '靜音/封鎖';

  @override
  String get settingsMuteBlockBlockTab => '封鎖';

  @override
  String get settingsMuteBlockMuteTab => '靜音';

  @override
  String get settingsMuteBlockBlockedUsers => '已封鎖的使用者';

  @override
  String get settingsMuteBlockBlockedWords => '已封鎖的字詞';

  @override
  String get settingsMuteBlockBlockedLists => '已封鎖的清單';

  @override
  String get settingsMuteBlockComingSoonHint => '準備中';

  @override
  String get settingsMuteBlockComingSoonDetail => '字詞/清單封鎖預計於 M2 後半期推出';

  @override
  String get settingsMuteBlockRetryButton => '重新載入';

  @override
  String get settingsMuteBlockNoBlockedUsers => '沒有已封鎖的使用者';

  @override
  String get settingsMuteBlockNoMutedUsers => '沒有已靜音的使用者';

  @override
  String get settingsMuteBlockBlockButton => '封鎖';

  @override
  String get settingsMuteBlockMuteButton => '靜音';

  @override
  String get settingsMuteBlockBlockingButton => '已封鎖';

  @override
  String get settingsMuteBlockMutingButton => '已靜音';

  @override
  String get settingsNotifyTokenTitle => '僅用於通知的存取權杖';

  @override
  String settingsNotifyTokenError(String error) {
    return '操作失敗 — $error';
  }

  @override
  String get settingsNotifyTokenCaption => '僅用於接收通知的金鑰。無法發文或操作帳號。';

  @override
  String get settingsNotifyTokenCaptionDetail =>
      '通知權杖僅用於接收來自 RASQ 伺服器的通知（只能讀取寄給自己的通知收件匣，無法發文或操作帳號）。巨集 / ASTell 用的子權杖也在此發行。';

  @override
  String get settingsNotifyTokenStatusSection => '狀態';

  @override
  String get settingsNotifyTokenPushTitle => '推播';

  @override
  String get settingsNotifyTokenPushPending => '即將推出';

  @override
  String get settingsNotifyTokenPushPendingDetail => '虛擬（尚未連接 APNs / FCM）';

  @override
  String get settingsNotifyTokenServerNotConfiguredTitle =>
      '尚未設定 RASQ 伺服器的連線位址';

  @override
  String get settingsNotifyTokenServerNotConfiguredSubtitle => '輸入連線位址後即可發行';

  @override
  String get settingsNotifyTokenNoAccountTitle => '尚未建立 RASQ 帳號';

  @override
  String get settingsNotifyTokenNoAccountSubtitle => '建立後即可發行通知權杖';

  @override
  String settingsNotifyTokenLoadError(String error) {
    return '無法取得：$error';
  }

  @override
  String get settingsNotifyTokenLocalTokenTitle => '此裝置的權杖';

  @override
  String get settingsNotifyTokenLocalTokenActive => '有效';

  @override
  String get settingsNotifyTokenLocalTokenNone => '未發行';

  @override
  String get settingsNotifyTokenDevicesTitle => '已註冊推播的裝置';

  @override
  String settingsNotifyTokenDevicesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return '$_temp0';
  }

  @override
  String get settingsNotifyTokenTestNotFound => '已加入測試通知，但在收件匣中找不到';

  @override
  String settingsNotifyTokenTestFound(
    String title,
    String status,
    int devices,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      devices,
      locale: localeName,
      other: '$devices 台',
    );
    return '已在收件匣中確認：「$title」（$status，$_temp0裝置）';
  }

  @override
  String get settingsNotifyTokenTestButton => '傳送測試通知';

  @override
  String get settingsNotifyTokenLocalRevoked => '已撤銷此裝置的權杖';

  @override
  String get settingsNotifyTokenRevokeButton => '撤銷';

  @override
  String get settingsNotifyTokenEnabled => '已發行，並已為此裝置註冊推播';

  @override
  String get settingsNotifyTokenEnableButton => '發行通知權杖並註冊此裝置';

  @override
  String get settingsNotifyTokenTokensSection => '已發行的權杖';

  @override
  String get settingsNotifyTokenKindRoot => '通知權杖';

  @override
  String get settingsNotifyTokenKindChild => '子權杖';

  @override
  String settingsNotifyTokenLabelSuffix(String label) {
    return '（$label）';
  }

  @override
  String get settingsNotifyTokenThisDevice => '此裝置';

  @override
  String settingsNotifyTokenIssuedAt(String time) {
    return '發行於 $time';
  }

  @override
  String get settingsNotifyTokenUnused => '未使用';

  @override
  String settingsNotifyTokenLastUsedAt(String time) {
    return '最後使用 $time';
  }

  @override
  String get settingsNotifyTokenIssueChildTooltip => '發行子權杖（巨集 / ASTell 共用）';

  @override
  String get settingsNotifyTokenChildIssued => '已發行子權杖並複製到剪貼簿（原始值僅此時可見）';

  @override
  String get settingsNotifyTokenRevoked => '已撤銷';

  @override
  String get settingsNotifyTokenStorageCaption => '金鑰會安全地儲存在此裝置中。';

  @override
  String get settingsNotifyTokenStorageCaptionDetail =>
      '原始權杖僅在發行時接收，並儲存在裝置內的安全區域。伺服器上只保留雜湊值。撤銷父權杖時，其子權杖也會一併撤銷。';

  @override
  String get settingsPagesAboutCookiesTitle => '關於 Cookie';

  @override
  String get settingsPagesAboutCookiesSection1Title => 'Cookie';

  @override
  String get settingsPagesAboutCookiesText1 =>
      'iOS、Android 與桌面 App 與 RASQ 伺服器通訊時不使用 Cookie。與 RASQ 伺服器的通訊使用裝置權杖（Authorization 標頭），各 SNS 的存取權杖儲存在裝置內的安全區域。';

  @override
  String get settingsPagesAboutCookiesText2 =>
      'iOS 與 Android App 中的廣告（Google AdMob）使用裝置的廣告 ID，而非 Cookie。在首次顯示的 Google 同意畫面中，你可以選擇是否使用個人化廣告。';

  @override
  String get settingsPagesAboutCookiesText3 =>
      '在網頁版以及 RASQ 公開的個人檔案與貼文網頁上，Google 會為廣告（Google AdSense）使用 Cookie。廣告 Cookie 的處理遵循 Google 的政策。';

  @override
  String get settingsPagesAboutCookiesText4 =>
      '在 App 內瀏覽器中開啟 SNS 的網頁版或註冊頁面時，遵循該 SNS 對 Cookie 的處理方式。';

  @override
  String get settingsPagesAboutDeveloperTitle => '開發者模式';

  @override
  String get settingsPagesAboutDeveloperEnabledSubtitle =>
      '詳細顯示畫面說明，包括運作原理與傳送資料的格式';

  @override
  String get settingsPagesAboutDeveloperEnabledDetail =>
      '開啟期間，設定與同意畫面會顯示原始的詳細說明（儲存位置的 KV、傳送的 JSON 格式等），取代簡短的說明。只改變顯示，不改變行為。';

  @override
  String get settingsPagesAboutDeveloperNotice1 => '只改變顯示。設定與傳送的資料不會改變。';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseTitle => '試用螢幕讀取（iOS）';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseSubtitle =>
      '在 iPhone / iPad 的「尋找 SNS 服務」中顯示「在常用瀏覽器中瀏覽並尋找」';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseDetail =>
      '由於在部分裝置上，螢幕讀取的 Broadcast Upload Extension（ScreenGlimpseBroadcast）不會出現在螢幕錄影的選項中（尚未解決），iOS 上預設隱藏。開啟後會顯示入口。Android 上一律顯示。';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dTitle =>
      '試用 3D RAi(Android)';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dSubtitle =>
      '在 Android 上也以 3D 顯示 RAi 吉祥物';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dDetail =>
      '由於有回報指出 RAi 在 Android 上無法開啟，且懷疑是 3D 基礎（flutter_angle）的初始化問題，預設使用 2D。開啟後會嘗試 3D。若 20 秒後仍未顯示或失敗，會自動恢復為 2D，並在 RAi 側邊欄的「診斷」中記錄原因。iPhone / iPad / Mac 一律使用 3D。';

  @override
  String get settingsPagesAboutHelpTitle => '說明';

  @override
  String get settingsPagesAboutHelpSection1Title => '使用方法';

  @override
  String get settingsPagesAboutHelpText1 => '不知道如何操作時，請在側邊選單中詢問 RAi。';

  @override
  String get settingsPagesAboutHelpText1Detail =>
      '不知道如何操作時，請詢問 RAi。在側邊選單的 RAi 中，可以使用「指引」（引導至按鈕）與「助理」（以裝置端模型回答，透過函式代為操作）。';

  @override
  String get settingsPagesAboutHelpRaiTitle => '開啟 RAi';

  @override
  String get settingsPagesAboutHelpTourAgain1Title => '再次查看 RASQ 使用導覽';

  @override
  String get settingsPagesAboutHelpTourAgain1Subtitle =>
      '功能介紹（時間軸、趨勢、ASTell、RAi 等）';

  @override
  String get settingsPagesAboutHelpSection2Title => '遇到問題時';

  @override
  String get settingsPagesAboutHelpText2 => '無法登入或發文時，請確認權限並重新登入。';

  @override
  String get settingsPagesAboutHelpText2Detail =>
      '無法登入或貼文沒有送達時，請先在「SNS 外掛 → 安全性」中確認權限，然後登出一次再重新登入。';

  @override
  String get settingsPagesAboutHelpSettingsDslSnsSecurityTitle => '安全性（權限與權杖）';

  @override
  String get settingsPagesAboutHelpSettingsServerTitle => 'RASQ 伺服器連線目標';

  @override
  String get settingsPagesAboutSubscriptionTitle => '訂閱狀態';

  @override
  String get settingsPagesAboutSubscriptionSection1Title => 'RASQ 訂閱';

  @override
  String get settingsPagesAboutSubscriptionValueRow1Title => '方案';

  @override
  String get settingsPagesAboutSubscriptionValueRow1Value => '免費';

  @override
  String get settingsPagesAboutSubscriptionValueRow2Title => '外掛代理';

  @override
  String get settingsPagesAboutSubscriptionValueRow2Value => '未訂閱';

  @override
  String get settingsPagesAboutSubscriptionText1 => '付費方案準備中。';

  @override
  String get settingsPagesAboutSubscriptionText1Detail =>
      '方案：免費（目前沒有訂閱方案）。日後將提供與 RASQ 帳號綁定的付費方案。';

  @override
  String get settingsPagesAppearanceDisplayTitle => '介面顯示大小';

  @override
  String get settingsPagesAppearanceDisplaySection1Title => '顯示大小';

  @override
  String get settingsPagesAppearanceDisplayTextScaleTitle => '文字與 UI 大小';

  @override
  String get settingsPagesAppearanceDisplayTextScaleSubtitle =>
      '變更整個 App 的文字大小（立即生效）';

  @override
  String get settingsPagesAppearanceFabTitle => '＋ 按鈕的功能';

  @override
  String get settingsPagesAppearanceFabNotice1 =>
      '可以選擇按下 ＋ 時啟動的功能。周圍的按鈕（內圈最多 3 個、外圈最多 4 個）可以長按 ＋（滑鼠則懸停），再透過齒輪重新排列。';

  @override
  String get settingsPagesAppearanceFabNotice1Detail =>
      '區域 appearance.fab（<scope>Tap / <scope>Slots = 放置順序，最多 7 個）。';

  @override
  String get settingsPagesAppearanceFabSection1Title => '在首頁按下 ＋ 時';

  @override
  String get settingsPagesAppearanceFabHomeTapPostTitle => '發文';

  @override
  String get settingsPagesAppearanceFabHomeTapRasqTitle => '發布到 RASQ';

  @override
  String get settingsPagesAppearanceFabHomeTapSwingTitle => '建立 Swing';

  @override
  String get settingsPagesAppearanceFabHomeTapAstellTitle => '建立 ASTell';

  @override
  String get settingsPagesAppearanceFabSection2Title => '在趨勢中按下 ＋ 時';

  @override
  String get settingsPagesAppearanceFabSection3Title => '在 ASTell 中按下 ＋ 時';

  @override
  String get settingsPagesAppearanceMfmTitle => '自訂動態與動畫';

  @override
  String get settingsPagesAppearanceMfmSection1Title => 'MFM 動畫';

  @override
  String get settingsPagesAppearanceMfmAnimationsTitle => '播放動態裝飾';

  @override
  String get settingsPagesAppearanceMfmAnimationsSubtitle => '播放旋轉、彩虹色等動態裝飾';

  @override
  String get settingsPagesAppearanceMfmAnimationsDetail =>
      '讓 spin / jump / rainbow 等 MFM 動起來。關閉後顯示為靜止畫面（「減少動態效果」開啟時一律靜止）';

  @override
  String get settingsPagesAppearanceMfmSpeedTitle => '動畫速度';

  @override
  String get settingsPagesAppearanceMfmSpeedSubtitle => '100% 為標準。數值越大動得越快';

  @override
  String get settingsPagesAppearanceMfmSettingsDslAppearanceMotionTitle =>
      '減少動態效果';

  @override
  String get settingsPagesAppearanceMfmSettingsDslAppearanceMotionSubtitle =>
      '包括畫面切換在內一併減少';

  @override
  String get settingsPagesAppearanceMotionTitle => '減少動態效果';

  @override
  String get settingsPagesAppearanceMotionSection1Title => '動畫';

  @override
  String get settingsPagesAppearanceMotionReduceMotionTitle => '減少動態效果';

  @override
  String get settingsPagesAppearanceMotionReduceMotionSubtitle =>
      '停止動態裝飾，減少畫面動作';

  @override
  String get settingsPagesAppearanceMotionReduceMotionDetail =>
      '將 MFM 的 spin / rainbow 等動畫改為靜止畫面，並減少畫面切換的動作';

  @override
  String get settingsPagesAppearanceNotificationsTitle => '通知顯示樣式';

  @override
  String get settingsPagesAppearanceNotificationsSection1Title => '通知頁面';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabAllTitle =>
      '從「全部」開啟';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabFollowingTitle =>
      '從「追蹤中」開啟';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabFollowingSubtitle =>
      '優先查看來自你追蹤的人的通知';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersTitle =>
      '在頂端顯示 ASTell 開始通知的預定';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersSubtitle =>
      '在通知頁面頂端顯示已登記的開始通知';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersDetail =>
      '在通知頁面頂端顯示已登記的開始通知（裝置的本機通知）清單';

  @override
  String get settingsPagesAppearanceNotificationsText1 =>
      '要通知的類型請在「通知 → 設定檔」中選擇（儲存在裝置上）。';

  @override
  String get settingsPagesAppearanceTimelineTitle => '時間軸顯示';

  @override
  String get settingsPagesAppearanceTimelineSection1Title => '更新';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesTitle => '在時間軸上下顯示「載入貼文」';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesSubtitle =>
      '手機上預設不顯示（下拉重新整理）';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesDetail =>
      '顯示後會載入新貼文 / 更多貼文。預設在手機 App 中不顯示（下拉重新整理），在網頁版與電腦上顯示';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillTitle => '顯示新貼文提示';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillSubtitle =>
      '重新整理後有新貼文時，在標題列正下方顯示「新貼文」';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillDetail =>
      '顯示發文者的大頭貼（最多 3 人）與「新貼文」。點按可回到頂端。一段時間後或捲動到頂端時消失。標題列收起期間不顯示';

  @override
  String get settingsPagesAppearanceVideoTitle => '子母畫面';

  @override
  String get settingsPagesAppearanceVideoSection1Title => '影片';

  @override
  String get settingsPagesAppearanceVideoAutoplayTitle => '開啟後自動播放';

  @override
  String get settingsPagesAppearanceVideoAutoplaySubtitle => '在全螢幕與小視窗中立即播放';

  @override
  String get settingsPagesAppearanceVideoAutoplayDetail =>
      '在全螢幕檢視器與小視窗（PiP）中，準備就緒後立即播放';

  @override
  String get settingsPagesAppearanceVideoPipKeepPositionTitle =>
      '切換到小視窗時延續播放位置';

  @override
  String get settingsPagesAppearanceVideoPipKeepPositionSubtitle =>
      '在全螢幕中按下「在小視窗中播放」時，從目前位置繼續播放';

  @override
  String get settingsPagesAppearanceVideoSection2Title => '預設播放速度';

  @override
  String get settingsPagesAppearanceVideoDefaultSpeed10Title => '1.0×（標準）';

  @override
  String get settingsPagesAppearanceVideoText1 => '可以拖曳小視窗到任意位置。';

  @override
  String get settingsPagesAppearanceVideoText1Detail =>
      '小視窗是 FOW，可以拖曳到欄位或上下移動。';

  @override
  String get settingsPagesAstellBackgroundTitle => '螢幕關閉時的行為';

  @override
  String get settingsPagesAstellBackgroundSection1Title => '通話中關閉螢幕時';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffKeepTitle => '繼續通話';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffKeepSubtitle =>
      '音訊維持不變，只停止接收螢幕分享';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffMuteTitle => '將麥克風靜音並繼續';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffLeaveTitle => '離開房間';

  @override
  String get settingsPagesAstellBackgroundNotice1 =>
      '此設定準備中。目前 ASTell 僅在螢幕亮著時運作。';

  @override
  String get settingsPagesAstellBackgroundNotice1Detail =>
      '此設定會被儲存，但要在實作通話常駐（背景音訊）之後才會生效。目前 ASTell 僅在螢幕亮著時運作。';

  @override
  String get settingsPagesAstellSubscriptionTitle => '訂閱 ASTell 4U';

  @override
  String get settingsPagesAstellSubscriptionSection1Title => '狀態';

  @override
  String get settingsPagesAstellSubscriptionValueRow1Title => '訂閱';

  @override
  String get settingsPagesAstellSubscriptionValueRow1Value => '未訂閱';

  @override
  String get settingsPagesAstellSubscriptionValueRow2Title => '提供';

  @override
  String get settingsPagesAstellSubscriptionValueRow2Value => '即將推出';

  @override
  String get settingsPagesAstellSubscriptionText1 =>
      'ASTell 4U 是準備中的付費方案。推薦欄可以免費使用。';

  @override
  String get settingsPagesAstellSubscriptionText1Detail =>
      'ASTell 4U 是 ASTell 推薦（For You）推送以及伺服器端轉錄 / 摘要的付費方案，目前尚未提供。推薦欄由 RASQ 伺服器的免費推薦驅動。';

  @override
  String get settingsPagesAstellTilesTitle => 'Tell 卡片';

  @override
  String get settingsPagesAstellTilesSection1Title => '首頁標題列';

  @override
  String get settingsPagesAstellTilesHeaderStripTitle => '在標題列顯示追蹤中主持人的 ASTell';

  @override
  String get settingsPagesAstellTilesHeaderStripSubtitle => '在首頁上方排列正在進行的房間';

  @override
  String get settingsPagesAstellTilesHeaderStripDetail =>
      '在首頁標題列的圓角框中排列正在進行的房間';

  @override
  String get settingsPagesAstellTilesHeaderMaxTitle => '顯示數量';

  @override
  String get settingsPagesAstellTilesHeaderMaxUnit => '個';

  @override
  String get settingsPagesAstellTrendTitle => '推送到趨勢時間軸';

  @override
  String get settingsPagesAstellTrendSection1Title => 'ASTell 首頁欄目';

  @override
  String get settingsPagesAstellTrendShowRecommendedTitle => '顯示「推薦」';

  @override
  String get settingsPagesAstellTrendShowTrendingTitle => '顯示「趨勢」';

  @override
  String get settingsPagesAstellTrendShowTrendingSubtitle =>
      '在 ASTell 首頁排列趨勢房間';

  @override
  String get settingsPagesAstellTrendText1 => '要在搜尋首頁的趨勢中顯示房間，請在「自訂趨勢」中設定。';

  @override
  String get settingsPagesAstellTrendText1Detail =>
      '將房間插入趨勢時間軸（搜尋首頁）需在趨勢的節點（演算法）一側設定。';

  @override
  String get settingsPagesAstellTrendTlconfigTrendTitle => '自訂趨勢';

  @override
  String get settingsPagesMediaSaveTitle => '圖片與影片的儲存位置';

  @override
  String get settingsPagesMediaSaveSection1Title => '「儲存圖片」與「儲存影片」的儲存位置';

  @override
  String get settingsPagesMediaSaveDestinationAskTitle => '每次儲存時選擇';

  @override
  String get settingsPagesMediaSaveDestinationAskSubtitle => '每次詢問要儲存到照片還是檔案';

  @override
  String get settingsPagesMediaSaveDestinationAskDetail =>
      '每次詢問要儲存到照片還是檔案（只有一個可選位置的裝置不會詢問）';

  @override
  String get settingsPagesMediaSaveDestinationPhotosTitle => '照片（相簿）';

  @override
  String get settingsPagesMediaSaveDestinationPhotosSubtitle => '會存入相簿「RASQ」';

  @override
  String get settingsPagesMediaSaveDestinationPhotosDetail =>
      '存入 iPhone / iPad / Mac 的「照片」或 Android 圖庫中的「RASQ」相簿';

  @override
  String get settingsPagesMediaSaveDestinationFilesTitle => '檔案';

  @override
  String get settingsPagesMediaSaveDestinationFilesSubtitle =>
      '儲存到「檔案」App 或你選擇的位置';

  @override
  String get settingsPagesMediaSaveDestinationFilesDetail =>
      'iPhone / iPad 儲存在「檔案」App 的 我的 iPad（我的 iPhone）› RASQ › 保存。電腦上可選擇儲存位置。Android 則存入圖庫';

  @override
  String get settingsPagesPluginsAccountPickTitle => '用於分享 / 轉貼的帳號';

  @override
  String get settingsPagesPluginsAccountPickSection1Title => '同一貼文在多個帳號中可見時';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentTitle => '優先使用指定的帳號';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentSubtitle =>
      '關閉後，會選擇與對方互動最多的帳號';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentDetail =>
      '選擇某個 SNS 帳號查看時，會用該帳號分享 / 轉貼。關閉後，會根據最近的互動（回應 / 轉貼 / 回覆）預測並選擇與對方互動最多的帳號。用 RASQ 帳號統一查看時，一律透過預測選擇';

  @override
  String get settingsPagesPluginsComposerTitle => '發文外掛';

  @override
  String get settingsPagesPluginsComposerSection1Title => '編輯器';

  @override
  String get settingsPagesPluginsComposerEnabledTitle => '使用發文外掛';

  @override
  String get settingsPagesPluginsComposerEnabledSubtitle => '使用可加工貼文文字與圖片的外掛';

  @override
  String get settingsPagesPluginsComposerEnabledDetail =>
      '啟用編輯器的文字轉換（composer.text）與媒體編輯（composer.media）外掛';

  @override
  String get settingsPagesPluginsComposerText1 => '關閉後，編輯器與媒體編輯器中的外掛欄將為空。';

  @override
  String get settingsPagesPluginsComposerSettingsComposerTitle => '發文編輯器設定';

  @override
  String get settingsPagesPluginsComposerStoreTitle => '外掛商店';

  @override
  String get settingsPagesPluginsEmojiTitle => '表情符號搜尋';

  @override
  String get settingsPagesPluginsEmojiSection1Title => '表情符號選擇器搜尋';

  @override
  String get settingsPagesPluginsEmojiSemanticTitle => '也尋找含義相近的表情符號';

  @override
  String get settingsPagesPluginsEmojiSemanticSubtitle =>
      '即使名稱不符，也會顯示含義相近的表情符號。輸入的文字不會傳送到外部';

  @override
  String get settingsPagesPluginsEmojiSemanticDetail =>
      '即使名稱或別名中不包含輸入的文字，也會在後面列出含義相近的表情符號。僅在已安裝裝置端搜尋模型（RAi →「模型」→ 搜尋）時有效。運算只在裝置內進行，輸入的文字不會傳送到外部。首次開啟的伺服器在背景建立索引期間會顯示「準備中」';

  @override
  String get settingsPagesPluginsProxyTitle => 'RASQ 外掛代理訂閱';

  @override
  String get settingsPagesPluginsProxySection1Title => '狀態';

  @override
  String get settingsPagesPluginsProxyValueRow1Title => '訂閱';

  @override
  String get settingsPagesPluginsProxyValueRow1Value => '未訂閱';

  @override
  String get settingsPagesPluginsProxyValueRow2Title => '提供';

  @override
  String get settingsPagesPluginsProxyValueRow2Value => '即將推出';

  @override
  String get settingsPagesPluginsProxyText1 => '外掛代理準備中。目前外掛直接從裝置通訊。';

  @override
  String get settingsPagesPluginsProxyText1Detail =>
      '外掛代理是將 wasm 外掛的外部通訊統一經由 RASQ 伺服器的付費服務。由於尚未提供，外掛會直接從裝置與 SNS / 自架伺服器通訊。提供時間：與 RASQ 伺服器的計費平台同時。';

  @override
  String get settingsPagesPluginsProxySettingsServerTitle => 'RASQ 伺服器連線目標';

  @override
  String get settingsPagesPluginsProxySettingsServerSubtitle =>
      '開始提供後，將使用此處選擇的伺服器';

  @override
  String get settingsPagesPluginsReactionTitle => '回應預測';

  @override
  String get settingsPagesPluginsReactionSection1Title => '短按回應按鈕';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptyTitle =>
      '即使沒有人回應的貼文也進行預測';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptySubtitle =>
      '預測常用的表情符號，短按即可加上';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptyDetail =>
      '關閉時，對還沒有回應的貼文不進行預測，按下會開啟表情符號選擇器。開啟時，會將你常用的表情符號作為預測顯示，短按即可加上';

  @override
  String get settingsPagesPluginsTelemetryTitle => '檢舉可疑通訊';

  @override
  String get settingsPagesPluginsTelemetrySection1Title => '向商店檢舉外掛的可疑通訊';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesTitle => '檢舉可疑通訊';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesSubtitle =>
      '只將通訊的格式傳送給審核。不傳送內文、權杖等內容。預設關閉';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesDetail =>
      '只在本裝置首次看到時，將外掛通訊的「格式」（目標主機、方法、路徑模式、標頭名稱、傳送的 JSON 鍵結構）傳送一次到 RASQ 商店。權杖、內文、使用者名稱、URL 中的 ID 等值不會傳送。審核方會用它來重新審核核准後通訊格式有所變化的外掛。預設關閉。';

  @override
  String get settingsPagesPluginsTelemetryText1 => '相同的格式不會傳送第二次。關閉後，會記錄為撤回同意。';

  @override
  String settingsPagesPluginsTelemetryText1Detail(String example) {
    return '傳送的內容：例如 $example。不傳送的內容：值本身。相同的格式不會傳送第二次。同意也會記錄在商店的同意紀錄中，關閉後會記錄為撤回。';
  }

  @override
  String get settingsPagesPluginsTimelineTitle => '放置自訂時間軸';

  @override
  String get settingsPagesPluginsTimelineSection1Title => '時間軸外掛';

  @override
  String get settingsPagesPluginsTimelineEnabledTitle => '使用自訂時間軸';

  @override
  String get settingsPagesPluginsTimelineEnabledSubtitle => '將外掛的時間軸顯示為首頁的分頁';

  @override
  String get settingsPagesPluginsTimelineEnabledDetail =>
      '將 TL 外掛（tl）宣告的時間軸顯示在首頁的分頁與「自訂時間軸」的演算法中';

  @override
  String get settingsPagesPluginsTimelineText1 => '排列與匯入請透過首頁分頁列的齒輪（自訂時間軸）設定。';

  @override
  String get settingsPagesPluginsTimelineStoreTitle => '外掛商店';

  @override
  String get settingsPagesPluginsTrendTitle => '自訂趨勢發布';

  @override
  String get settingsPagesPluginsTrendSection1Title => '趨勢外掛';

  @override
  String get settingsPagesPluginsTrendEnabledTitle => '顯示趨勢外掛的候選';

  @override
  String get settingsPagesPluginsTrendEnabledSubtitle => '在搜尋首頁的趨勢欄中顯示外掛的候選';

  @override
  String get settingsPagesPluginsTrendEnabledDetail =>
      '在搜尋首頁的趨勢欄中顯示已安裝趨勢外掛（trend.suggest）的候選標籤';

  @override
  String get settingsPagesPluginsTrendText1 => '關閉後，外掛不會被呼叫（即使維持安裝也不會通訊）。';

  @override
  String get settingsPagesPluginsTrendStoreTitle => '外掛商店';

  @override
  String get settingsPagesPluginsTrendStoreSubtitle => '尋找 / 管理趨勢外掛';

  @override
  String get settingsPagesRaiTitle => 'RAi（助理）';

  @override
  String get settingsPagesRaiSection1Title => '自動化';

  @override
  String get settingsPagesRaiTraceGraphAutoTitle => '自動顯示流程圖';

  @override
  String get settingsPagesRaiTraceGraphAutoSubtitle => '以圖表顯示 3 個步驟以上的自動化';

  @override
  String get settingsPagesRaiTraceGraphAutoDetail =>
      '交給 RAi 的自動化有 3 個步驟以上時，會自動以節點圖顯示流程。關閉時會顯示「以圖表檢視顯示」按鈕';

  @override
  String get settingsPagesRaiText1 => 'AI 模型與網頁搜尋請透過 RAi 列的模型按鈕設定。';

  @override
  String get settingsPagesRaiText1Detail => '推論伺服器與網頁搜尋的金鑰請透過 RAi 列的模型標籤設定。';

  @override
  String get settingsPagesRelationalPluginsTitle => '外掛進階設定';

  @override
  String get settingsPagesRelationalPluginsSection1Title => '狀態';

  @override
  String get settingsPagesRelationalPluginsValueRow1Title => '外掛槽';

  @override
  String get settingsPagesRelationalPluginsValueRow1Value => '即將推出';

  @override
  String get settingsPagesRelationalPluginsText1 => '此畫面的外掛準備中。';

  @override
  String get settingsPagesRelationalPluginsText1Detail =>
      '契約 v0.7 中尚無用於關聯時間軸的外掛槽（替換聚合方式）。ML 相似度使用 RASQ 伺服器的 ML 閘道。外掛槽：未定義。';

  @override
  String get settingsPagesRelationalPluginsSettingsServerTitle =>
      'RASQ 伺服器連線目標';

  @override
  String get settingsPagesRelationalRelayTitle => 'Relay 卡片';

  @override
  String get settingsPagesRelationalRelaySection1Title => '狀態';

  @override
  String get settingsPagesRelationalRelayValueRow1Title => '提供';

  @override
  String get settingsPagesRelationalRelayValueRow1Value => '即將推出';

  @override
  String get settingsPagesRelationalRelayText1 =>
      'Relay 卡片準備中。目前可以在「貼文叢集」中變更對話的歸納方式。';

  @override
  String get settingsPagesRelationalRelayText1Detail =>
      'Relay 卡片會將話題跨對話事件傳遞的流程（接力）彙整到一張卡片中顯示。將在聚合方式確定後加入。目前可以透過調整「貼文叢集」來變更對話事件的聚合方式。提供時間：演算法確定後。';

  @override
  String get settingsPagesRelationalTrendTitle => '推送到趨勢時間軸';

  @override
  String get settingsPagesRelationalTrendSection1Title => '狀態';

  @override
  String get settingsPagesRelationalTrendValueRow1Title => '提供';

  @override
  String get settingsPagesRelationalTrendValueRow1Value => '即將推出';

  @override
  String get settingsPagesRelationalTrendText1 => '可以透過「自訂趨勢」將關聯時間軸推送到趨勢中。';

  @override
  String get settingsPagesRelationalTrendText1Detail =>
      '將關聯分頁的對話事件推送到趨勢時間軸，可以透過在趨勢一側的節點（演算法）中放置「關聯時間軸」節點來設定。提供時間：演算法確定後。';

  @override
  String get settingsPagesRelationalTrendTlconfigTrendTitle => '自訂趨勢';

  @override
  String get settingsPagesResourcesTitle => '資源與廣告';

  @override
  String get settingsPagesResourcesSection1Title => '廣告';

  @override
  String get settingsPagesResourcesShowAdsTitle => '顯示廣告';

  @override
  String get settingsPagesResourcesShowAdsSubtitle => '時間軸貼文之間與搜尋首頁上的廣告';

  @override
  String get settingsPagesResourcesShowAdsDetail =>
      '時間軸貼文之間（每 10 則一個，不會放在附內容警告或敏感內容的貼文旁邊）以及搜尋首頁的廣告欄位（AdMob，目前為測試廣告）。不顯示個人化廣告';

  @override
  String get settingsPagesResourcesSection2Title => '資源';

  @override
  String get settingsPagesResourcesValueRow1Title => '外掛通訊';

  @override
  String get settingsPagesResourcesValueRow1Value => '直接從裝置';

  @override
  String get settingsPagesResourcesValueRow2Title => '推論';

  @override
  String get settingsPagesResourcesValueRow2Value => '裝置端 + 所選伺服器';

  @override
  String get settingsPagesResourcesText1 => '各外掛是否有廣告及其價格，顯示在外掛商店的各個頁面上。';

  @override
  String get settingsPagesResourcesText1Detail =>
      '各外掛是否有廣告及其價格，顯示在外掛商店的各個頁面上。外掛通訊：直接從裝置（無代理）。推論：裝置端模型（RAi）+ 任選的推論伺服器。';

  @override
  String get settingsPagesResourcesStoreTitle => '外掛商店';

  @override
  String get settingsPagesTrendCdnTitle => '快取網路設定';

  @override
  String get settingsPagesTrendCdnSection1Title => '狀態';

  @override
  String get settingsPagesTrendCdnValueRow1Title => '快取網路';

  @override
  String get settingsPagesTrendCdnValueRow1Value => '即將推出';

  @override
  String get settingsPagesTrendCdnText1 => '準備中。目前直接從各 SNS 取得。';

  @override
  String get settingsPagesTrendCdnText1Detail =>
      '從 CDN（快取網路）讀取趨勢取得結果的機制，將與 RASQ 伺服器的發布平台同時推出。目前直接從各 SNS 取得。快取網路：未提供。';

  @override
  String get settingsSectionsPluginsTitle => '外掛配置';

  @override
  String get settingsSectionsPluginsProxyTitle => 'RASQ 外掛代理訂閱';

  @override
  String get settingsSectionsPluginsProxySubtitle => '即將推出';

  @override
  String get settingsSectionsPluginsProxyDetail => '未訂閱（第二期）';

  @override
  String get settingsSectionsPluginsActionBarTitle => '在貼文上放置外掛自動化';

  @override
  String get settingsSectionsPluginsActionBarSubtitle => '顯示在貼文下方的外掛按鈕';

  @override
  String get settingsSectionsPluginsActionBarDetail =>
      '顯示在貼文操作列中的外掛按鈕（總開關 / 自動開啟 / 位置）';

  @override
  String get settingsSectionsPluginsTrendTitle => '自訂趨勢發布';

  @override
  String get settingsSectionsPluginsComposerTitle => '發文外掛';

  @override
  String get settingsSectionsPluginsTimelineTitle => '放置自訂時間軸';

  @override
  String get settingsSectionsPluginsStoreTitle => '外掛進階設定';

  @override
  String get settingsSectionsPluginsStoreSubtitle => '外掛商店（管理已安裝的外掛）';

  @override
  String get settingsSectionsPluginsTelemetryTitle => '檢舉可疑通訊';

  @override
  String get settingsSectionsPluginsTelemetrySubtitle => '預設關閉';

  @override
  String get settingsSectionsPluginsTelemetryDetail =>
      '通訊形態回報：僅在首次發現時，將外掛的通訊形態（不含數值）傳送至商店。預設關閉';

  @override
  String get settingsSectionsSnsTitle => 'SNS 外掛';

  @override
  String get settingsSectionsSnsAccountTitle => '帳號';

  @override
  String get settingsSectionsSnsTimelineTitle => '時間軸';

  @override
  String get settingsSectionsSnsSecurityTitle => '安全性';

  @override
  String get settingsSectionsSnsSafetyTitle => '隱私與安全模式';

  @override
  String get settingsSectionsSnsChildSafeTitle => '兒童安全';

  @override
  String get settingsSectionsSnsChildSafeSubtitle => '監護人監護 / 兒童模式';

  @override
  String get settingsSectionsSnsChildSafeDetail => '以監護人身分看護 / 兒童模式（以監護人的代碼連線）';

  @override
  String get settingsSectionsSnsListsTitle => '清單';

  @override
  String get settingsSectionsSnsMuteBlockTitle => '靜音/封鎖';

  @override
  String get settingsSectionsSnsPluginButtonsTitle => '外掛按鈕';

  @override
  String get settingsSectionsSnsPluginButtonsSubtitle => '外掛按鈕的顯示方式';

  @override
  String get settingsSectionsSnsPluginButtonsDetail =>
      '各畫面的總開關與「開啟時自動啟用」、此帳號的啟用 / 停用以及合併門檻';

  @override
  String get settingsSectionsSnsEmojiSearchTitle => '表情符號搜尋';

  @override
  String get settingsSectionsSnsEmojiSearchSubtitle => '也尋找含義相近的表情符號';

  @override
  String get settingsSectionsSnsEmojiSearchDetail => '一併尋找意思相近的表情符號（裝置端模型）';

  @override
  String get settingsSectionsSnsReactionPredictTitle => '回應預測';

  @override
  String get settingsSectionsSnsReactionPredictSubtitle => '是否對尚無人回應的貼文也進行預測';

  @override
  String get settingsSectionsSnsQuickEmojiTitle => '快速表情符號';

  @override
  String get settingsSectionsSnsQuickEmojiSubtitle => '長按回應按鈕並滑動選擇的表情符號';

  @override
  String get settingsSectionsSnsAccountPickTitle => '用於分享 / 轉貼的帳號';

  @override
  String get settingsSectionsSnsAccountPickSubtitle => '同一則貼文在多個帳號中可見時';

  @override
  String get settingsSectionsSnsAccountPickDetail => '對在多個帳號中可見的貼文，要使用哪個帳號處理';

  @override
  String get settingsSectionsSnsMfmTitle => '自訂動態與動畫';

  @override
  String get settingsSectionsSnsResourcesTitle => '資源與廣告';

  @override
  String get settingsSectionsSnsLegalTitle => '說明與法律聲明';

  @override
  String get settingsSectionsSnsNote =>
      '帳號 / 時間軸 / 安全性 / 隱私權是由你使用的 SNS 外掛提供的頁面（外掛未提供的頁面不會顯示）。';

  @override
  String get settingsSectionsSnsNoteDetail =>
      '帳號 / 時間軸 / 安全性 / 隱私權是由所設定帳號的 SNS 外掛提供的設定頁面（sns.settingsPages。未宣告的頁面列不顯示，D-482）。';

  @override
  String get settingsSectionsAppearanceTitle => 'App 外觀';

  @override
  String get settingsSectionsAppearanceDisplayTitle => '介面顯示大小';

  @override
  String get settingsSectionsAppearanceThemeTitle => '字型與配色';

  @override
  String get settingsSectionsAppearanceThemeSubtitle => '主題（顏色、圖示、背景圖片）';

  @override
  String get settingsSectionsAppearanceColumnsTitle => '欄寬';

  @override
  String get settingsSectionsAppearanceColumnsSubtitle => '寬螢幕上左右欄的寬度';

  @override
  String get settingsSectionsAppearanceColumnsDetail =>
      '寬螢幕上小欄 / 大欄的比例（1:1 / 2:3 / 3:5 / 固定寬度）';

  @override
  String get settingsSectionsAppearanceMotionTitle => '減少動態效果';

  @override
  String get settingsSectionsAppearanceTimelineTitle => '時間軸顯示';

  @override
  String get settingsSectionsAppearanceTimelineSubtitle => '時間軸的「載入貼文」';

  @override
  String get settingsSectionsAppearanceTimelineDetail => '時間軸上下方的「載入貼文」';

  @override
  String get settingsSectionsAppearancePipTitle => '子母畫面';

  @override
  String get settingsSectionsAppearanceFabTitle => '＋ 按鈕的功能';

  @override
  String get settingsSectionsAppearanceFabSubtitle => '點按時開始的動作';

  @override
  String get settingsSectionsAppearanceMediaSaveTitle => '圖片與影片的儲存位置';

  @override
  String get settingsSectionsAppearanceMediaSaveSubtitle =>
      '照片（相簿）/ 檔案 / 每次儲存時選擇';

  @override
  String get settingsSectionsAppearanceNotificationsTitle => '通知顯示樣式';

  @override
  String get settingsSectionsAstellTitle => 'ASTell';

  @override
  String get settingsSectionsAstellSubscriptionTitle => '訂閱 ASTell 4U';

  @override
  String get settingsSectionsAstellSubscriptionSubtitle => '即將推出';

  @override
  String get settingsSectionsAstellSubscriptionDetail => '未訂閱（第二期）';

  @override
  String get settingsSectionsAstellTilesTitle => 'Tell 卡片';

  @override
  String get settingsSectionsAstellTrendTitle => '推送到趨勢時間軸';

  @override
  String get settingsSectionsAstellRoomButtonsTitle => '房間按鈕';

  @override
  String get settingsSectionsAstellRoomButtonsSubtitle => '輸入欄左側的按鈕';

  @override
  String get settingsSectionsAstellRoomButtonsDetail =>
      '房間底部、輸入欄左側的圓形按鈕排列（排序 / 顯示 / 隱藏 / 新增外掛按鈕）';

  @override
  String get settingsSectionsAstellStoreTitle => '外掛進階設定';

  @override
  String get settingsSectionsAstellStoreSubtitle => '在 ASTell 中使用的外掛';

  @override
  String get settingsSectionsAstellStoreDetail => 'ASTell 的動作外掛（商店）';

  @override
  String get settingsSectionsAstellBackgroundTitle => '螢幕關閉時的行為';

  @override
  String get settingsSectionsRelationalTitle => '關聯時間軸';

  @override
  String get settingsSectionsRelationalClusterTitle => '貼文叢集';

  @override
  String get settingsSectionsRelationalClusterSubtitle => '對話的歸併方式';

  @override
  String get settingsSectionsRelationalClusterDetail =>
      '對話事件的歸併方式（歸併難易度 / 權重 / 沉底所需時間）';

  @override
  String get settingsSectionsRelationalRelayTitle => 'Relay 卡片';

  @override
  String get settingsSectionsRelationalTrendTitle => '推送到趨勢時間軸';

  @override
  String get settingsSectionsRelationalPluginsTitle => '外掛進階設定';

  @override
  String get settingsSectionsRelationalSamplingTitle => '趨勢取樣等級';

  @override
  String get settingsSectionsRelationalSamplingSubtitle => '納入候選的時間範圍';

  @override
  String get settingsSectionsRelationalSamplingDetail => '納入候選的時間範圍（歸併判定的進階設定）';

  @override
  String get settingsSectionsRelationalNote => 'Relay 卡片與趨勢發布即將推出。';

  @override
  String get settingsSectionsRelationalNoteDetail =>
      'Relay 卡片與趨勢發布將在演算法確定後提供（D-011）。';

  @override
  String get settingsSectionsTrendTitle => '趨勢';

  @override
  String get settingsSectionsTrendGenresTitle => '類別';

  @override
  String get settingsSectionsTrendTendencyTitle => '趨勢的傾向/刺激程度';

  @override
  String get settingsSectionsTrendEmomTitle => 'EmoM 門檻';

  @override
  String get settingsSectionsTrendEmomSubtitle => '隱藏營運方限制的趨勢 / 公開門檻';

  @override
  String get settingsSectionsTrendEmomDetail =>
      'EmoM 門檻（0–100，預設 50）與「公開門檻」（預設關閉）。營運方限制分數高於此值的趨勢不會顯示在清單中（D-404）';

  @override
  String get settingsSectionsTrendPluginsTitle => '外掛進階設定';

  @override
  String get settingsSectionsTrendCdnTitle => '快取網路設定';

  @override
  String get settingsSectionsTrendCdnSubtitle => '即將推出';

  @override
  String get settingsSectionsTrendCdnDetail => '尚未提供（第二期）';

  @override
  String get settingsSectionsRaiTitle => 'RAi（助理）';

  @override
  String get settingsSectionsRaiGraphTitle => '自動顯示流程圖';

  @override
  String get settingsSectionsNotificationsTitle => '通知';

  @override
  String get settingsSectionsNotificationsProfileTitle => '設定檔';

  @override
  String get settingsSectionsNotificationsAccessTokenTitle => '存取權杖';

  @override
  String get settingsSectionsNotificationsAccessTokenSubtitle => '接收通知的設定';

  @override
  String get settingsSectionsNotificationsAccessTokenDetail =>
      '核發 / 撤銷通知專用權杖，裝置推播註冊';

  @override
  String get settingsSectionsNotificationsSecurityTitle => '安全性';

  @override
  String get settingsSectionsNotificationsSecuritySubtitle => 'SNS 權限與存取權杖';

  @override
  String get settingsSectionsAboutTitle => '關於 RASQ';

  @override
  String get settingsSectionsAboutServerTitle => 'RASQ 伺服器';

  @override
  String get settingsSectionsAboutServerSubtitle => '要連線的伺服器';

  @override
  String get settingsSectionsAboutServerDetail => '外掛商店 / RASQ 帳號 / 登入的連線目標';

  @override
  String get settingsSectionsAboutHelpTitle => '說明';

  @override
  String get settingsSectionsAboutTourTitle => '再次查看 RASQ 使用導覽';

  @override
  String get settingsSectionsAboutTourSubtitle => '功能介紹（時間軸、趨勢、ASTell、RAi 等）';

  @override
  String get settingsSectionsAboutSubscriptionTitle => '訂閱狀態';

  @override
  String get settingsSectionsAboutCookiesTitle => '關於 Cookie';

  @override
  String get settingsSectionsAboutPrivacyTitle => '隱私權政策';

  @override
  String get settingsSectionsAboutTermsTitle => '使用條款';

  @override
  String get settingsSectionsAboutLearningTitle => '為演算法和社群做出貢獻';

  @override
  String get settingsSectionsAboutLearningSubtitle => '選擇性。預設為「不提供」';

  @override
  String get settingsSectionsAboutAstellTermsTitle => 'ASTell 使用條款';

  @override
  String get settingsSectionsAboutRaiTermsTitle => 'RAi 使用條款';

  @override
  String get settingsSectionsAboutStoreTermsTitle => '外掛商店使用條款';

  @override
  String get settingsSectionsAboutDevTermsTitle => '外掛開發者上架與審核條款';

  @override
  String get settingsSectionsAboutDevTermsSubtitle => '含審核費';

  @override
  String get settingsSectionsAboutBillingTitle => '費用與點數條款';

  @override
  String get settingsSectionsAboutCommerceTitle => '依據《特定商業交易法》之標示';

  @override
  String get settingsSectionsAboutResourcesTitle => '資源與廣告';

  @override
  String get settingsSectionsAboutLegalTitle => '說明與法律聲明';

  @override
  String get settingsSectionsAboutDeveloperTitle => '開發者模式';

  @override
  String get settingsSectionsAboutDeveloperSubtitle => '顯示更詳細的畫面說明';

  @override
  String get settingsSecurityAgoJustNow => '剛剛';

  @override
  String settingsSecurityAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分鐘前',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小時前',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityCodeSentTo(String to) {
    return '已向 $to 傳送驗證碼';
  }

  @override
  String get settingsSecurityTitle => '帳號安全性';

  @override
  String get settingsSecurityNotSignedIn => '未登入 RASQ 帳號。';

  @override
  String get settingsSecurityToLoginTitle => '登入現有的 RASQ 帳號';

  @override
  String get settingsSecurityToLoginSubtitle => '帳號代稱（或電子郵件）和密碼';

  @override
  String get settingsSecurityEmailHeader => '電子郵件地址';

  @override
  String get settingsSecurityEmailCaption => '用於忘記密碼時的重設，以及登入的第二步驗證。其他人看不到。';

  @override
  String get settingsSecurityEmailDetail =>
      '註冊後，可用於忘記密碼時的重設、從其他裝置登入時的第二步驗證（輸入密碼後再輸入郵件驗證碼），以及重要操作的確認和通知。如果未驗證電子郵件，忘記密碼時將無法重設。其他人看不到。';

  @override
  String get settingsSecurityEmailCurrentTitle => '目前的電子郵件';

  @override
  String get settingsSecurityEmailUnregistered => '未註冊';

  @override
  String get settingsSecurityEmailNewHint => '新的電子郵件地址';

  @override
  String get settingsSecurityEmailHint => '電子郵件地址';

  @override
  String get settingsSecuritySendCodeButton => '傳送驗證碼';

  @override
  String get settingsSecurityEmailChangeNeedsPasswordOrCode =>
      '更換時，需要目前的密碼或傳送到目前電子郵件的驗證碼。';

  @override
  String get settingsSecurityEmailChangeNeedsCode => '更換時，需要傳送到目前電子郵件的驗證碼。';

  @override
  String get settingsSecurityCurrentPasswordHint => '目前的密碼';

  @override
  String get settingsSecurityEmailSendCodeToCurrentButton => '傳送驗證碼到目前的電子郵件';

  @override
  String get settingsSecurityEmailNeedsPassword => '已設定密碼的帳號，新增電子郵件地址時需要目前的密碼。';

  @override
  String settingsSecurityEmailPendingCaption(String email) {
    return '請輸入傳送到 $email 的驗證碼（15 分鐘後失效）。';
  }

  @override
  String get settingsSecurityEmailVerified => '電子郵件地址已驗證';

  @override
  String get settingsSecurityVerifyButton => '驗證';

  @override
  String get settingsSecurityEmailRemoveTitle => '移除電子郵件地址';

  @override
  String get settingsSecurityEmailRemoveSubtitle => '需要驗證碼';

  @override
  String get settingsSecurityPasswordHeader => '密碼';

  @override
  String get settingsSecurityPasswordChangeCaption =>
      '變更後，其他裝置將被登出。需要目前的密碼或郵件驗證碼。';

  @override
  String get settingsSecurityPasswordNoneCaption =>
      '沒有密碼時，無法從其他裝置登入（只能在此裝置上使用）。設定後，可在其他裝置上用帳號代稱（或電子郵件）和密碼登入同一帳號。';

  @override
  String get settingsSecurityPasswordNewHint => '新密碼（8 個字元以上）';

  @override
  String get settingsSecurityPasswordHint => '密碼（8 個字元以上）';

  @override
  String get settingsSecurityPasswordChanged => '密碼已變更';

  @override
  String get settingsSecurityPasswordSet => '密碼已設定';

  @override
  String get settingsSecurityPasswordChangeButton => '變更密碼';

  @override
  String get settingsSecurityPasswordSetButton => '設定密碼';

  @override
  String get settingsSecurityPasswordByCodeButton => '用郵件驗證碼變更';

  @override
  String get settingsSecurityPasswordResetWarning => '如果「重設」密碼，將無法讀取已同步的設定。';

  @override
  String get settingsSecurityPasswordResetWarningDetail =>
      '密碼也用於加密已同步的設定。如果進行「重設密碼」（登入畫面），用舊密碼加密的資料將無法解密。';

  @override
  String get settingsSecuritySecondFactorHeader => '登入的第二步驗證';

  @override
  String get settingsSecuritySecondFactorNeedsEmailCaption =>
      '驗證電子郵件地址後，從其他裝置登入時，輸入密碼後還需要輸入郵件驗證碼（預設開啟）。';

  @override
  String get settingsSecuritySecondFactorActiveCaption =>
      '從其他裝置登入時，輸入密碼後還需要輸入傳送到電子郵件的驗證碼（10 分鐘內有效）。';

  @override
  String get settingsSecuritySecondFactorOffCaption => '已關閉。其他裝置僅憑密碼即可登入。';

  @override
  String get settingsSecuritySecondFactorTitle => '同時要求郵件驗證碼';

  @override
  String get settingsSecuritySecondFactorNeedsEmailSubtitle => '需要驗證電子郵件地址';

  @override
  String get settingsSecuritySecondFactorEnabled => '已開啟登入的第二步驗證';

  @override
  String get settingsSecuritySecondFactorDisableNeedsPasswordOrCode =>
      '關閉時，需要目前的密碼或傳送到電子郵件的驗證碼。';

  @override
  String get settingsSecuritySecondFactorDisableNeedsCode =>
      '關閉時，需要傳送到電子郵件的驗證碼。';

  @override
  String get settingsSecuritySendCodeToEmailButton => '傳送驗證碼到電子郵件';

  @override
  String get settingsSecurityCancelButton => '取消';

  @override
  String get settingsSecuritySecondFactorDisabled => '已關閉登入的第二步驗證';

  @override
  String get settingsSecuritySecondFactorDisableButton => '關閉第二步驗證';

  @override
  String get settingsSecuritySessionsHeader => '已登入的裝置';

  @override
  String settingsSecuritySessionsRevokedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台裝置',
    );
    return '已將其他 $_temp0登出';
  }

  @override
  String get settingsSecuritySessionsRevokeOthersButton => '登出所有其他裝置';

  @override
  String get settingsSecuritySessionUnnamed => '未命名裝置';

  @override
  String get settingsSecurityThisDeviceSuffix => '（此裝置）';

  @override
  String settingsSecuritySessionLastUsed(String ago) {
    return '上次使用：$ago';
  }

  @override
  String settingsSecuritySessionExpires(String date) {
    return '到期 $date';
  }

  @override
  String get settingsSecuritySessionRevoked => '已登出';

  @override
  String get settingsSecuritySessionLogoutButton => '登出';

  @override
  String get settingsSecurityConfirmDeleteHeader => '確認刪除帳號';

  @override
  String get settingsSecurityConfirmEmailRemoveHeader => '確認移除電子郵件地址';

  @override
  String settingsSecurityConfirmCodeCaption(String to) {
    return '請輸入傳送到 $to 的驗證碼。';
  }

  @override
  String get settingsSecurityDeleteButton => '刪除';

  @override
  String get settingsSecurityRemoveButton => '移除';

  @override
  String get settingsSecurityDeleteHeader => '刪除帳號';

  @override
  String get settingsSecurityDeleteTitle => '刪除 RASQ 帳號';

  @override
  String get settingsSecurityDeleteSubtitleWithEmail => '需要郵件驗證碼。此操作無法復原';

  @override
  String get settingsSecurityDeleteSubtitle => '此操作無法復原';

  @override
  String get settingsSecurityRolesHeader => '角色';

  @override
  String get settingsSecurityRolesTitle => '此帳號的角色';

  @override
  String get settingsSecurityRoleDeveloper => '開發者';

  @override
  String get settingsSecurityRoleReviewer => '審核員';

  @override
  String get settingsSecurityEmailReplaceNeedsPasswordOrCodeError =>
      '請輸入目前的密碼，或用傳送到目前電子郵件的驗證碼進行確認';

  @override
  String get settingsSecurityEmailReplaceNeedsCodeError =>
      '請用傳送到目前電子郵件的驗證碼進行確認';

  @override
  String get settingsSecurityEnterCurrentPasswordError => '請輸入目前的密碼';

  @override
  String get settingsSecurityCodeSent => '已傳送驗證碼';

  @override
  String get settingsSecurityDeleteConfirmMessage =>
      '將刪除伺服器上的個人檔案、帳號組合、已同步的設定、評論和書籤、ASTell 的房間和分享、通知權杖以及同意紀錄。此操作無法復原。';

  @override
  String get settingsSecuritySendConfirmCodeButton => '傳送驗證碼';

  @override
  String get settingsSecurityDeleted => '已刪除 RASQ 帳號';

  @override
  String get settingsSecurityEmailRemoved => '已移除電子郵件地址';

  @override
  String get settingsSecurityCodeHint => '驗證碼（例如 3mJr7-AoUXx）';

  @override
  String get settingsSecurityCodeHelper => '也可以貼上郵件中的連結進行驗證';

  @override
  String get settingsSecurityLoginFailedHelp =>
      '帳號代稱（電子郵件）或密碼不正確。\n未設定密碼的 RASQ 帳號無法從其他裝置登入。請在建立該帳號的裝置（目前仍已登入的裝置）上，透過「設定 → 帳號安全性」設定密碼後，再重新登入。';

  @override
  String get settingsSecurityServerNotConfiguredError => '尚未設定 RASQ 伺服器的連線位址';

  @override
  String get settingsSecurityLoginFailed => '無法登入';

  @override
  String settingsSecurityLoggedInAs(String handle) {
    return '已登入 @$handle';
  }

  @override
  String get settingsSecurityLoginEnterCredentialsError => '請輸入帳號代稱（或電子郵件）和密碼';

  @override
  String get settingsSecurityVerifiedEmailFallback => '已驗證的電子郵件';

  @override
  String get settingsSecurityLoginTitle => '登入 RASQ 帳號';

  @override
  String get settingsSecurityLoginCaption => '使用帳號代稱（可省略 @）或已驗證的電子郵件地址，以及密碼登入。';

  @override
  String get settingsSecurityLoginDetail =>
      '使用帳號代稱（可省略 @）或已驗證的電子郵件地址，以及密碼登入。擁有已驗證電子郵件的帳號，之後還需輸入傳送到電子郵件的驗證碼（第二步驗證）。';

  @override
  String get settingsSecurityLoginIdentifierHint => '帳號代稱或電子郵件地址';

  @override
  String get settingsSecurityLoginPasswordHint => '密碼';

  @override
  String get settingsSecurityLoginButton => '登入';

  @override
  String get settingsSecurityLoginForgotButton => '忘記密碼';

  @override
  String get settingsSecurityLoginNoPasswordHint =>
      '未設定密碼的帳號無法從其他裝置登入（只能在建立它的裝置上使用）。請在該裝置的「設定 → 帳號安全性」中設定密碼。';

  @override
  String get settingsSecurityLoginCodeHeader => '驗證碼';

  @override
  String settingsSecurityLoginChallengeCaption(String email, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分鐘內有效',
    );
    return '已向 $email 傳送驗證碼($_temp0，僅限一次)。請輸入收到的驗證碼。';
  }

  @override
  String get settingsSecurityVerifiedEmailAddressFallback => '已驗證的電子郵件地址';

  @override
  String get settingsSecurityLoginConfirmButton => '驗證並登入';

  @override
  String get settingsSecurityLoginResendButton => '重新傳送驗證碼';

  @override
  String get settingsSecurityLoginBackButton => '返回帳號代稱 / 密碼';

  @override
  String get settingsSecurityLoginNoMailHint =>
      '如果沒有收到郵件，請同時查看垃圾郵件資料夾。如果收到了你沒有進行過的登入郵件，請變更密碼。';

  @override
  String get settingsSecurityLoginChildHeader => '兒童帳號';

  @override
  String get settingsSecurityLoginChildTitle => '使用監護人提供的代碼登入';

  @override
  String get settingsSecurityLoginChildSubtitle => '登入監護人建立的孩子帳號';

  @override
  String get settingsSecurityResetEnterEmailError => '請輸入已驗證的電子郵件地址';

  @override
  String get settingsSecurityResetCodeSent =>
      '如果存在已驗證該電子郵件地址的帳號，驗證碼已傳送（10 分鐘內有效）';

  @override
  String settingsSecurityResetDoneKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return '密碼已重設。已將其他 $_temp0裝置登出';
  }

  @override
  String settingsSecurityResetDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return '密碼已重設(已將 $_temp0裝置登出)。請使用新密碼登入';
  }

  @override
  String get settingsSecurityResetTitle => '重設密碼';

  @override
  String get settingsSecurityResetCaption =>
      '將向已驗證的電子郵件地址傳送驗證碼（10 分鐘內有效，僅限一次），然後設定新密碼。其他所有裝置都將被登出。';

  @override
  String get settingsSecurityResetNoEmailWarning => '未驗證電子郵件地址的帳號無法重設密碼。';

  @override
  String get settingsSecurityResetNoEmailDetail =>
      '請在建立該帳號的裝置（目前仍已登入的裝置）上，透過「設定 → 帳號安全性」設定新密碼。如果連該裝置也沒有，將無法恢復帳號。';

  @override
  String get settingsSecurityResetEmailHint => '已驗證的電子郵件地址';

  @override
  String get settingsSecurityResendButton => '重新傳送';

  @override
  String settingsSecurityResetNewPasswordHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個字元以上',
    );
    return '新密碼($_temp0)';
  }

  @override
  String get settingsSecurityResetConfirmPasswordHint => '新密碼（確認）';

  @override
  String get settingsSecurityResetMismatchError => '不一致';

  @override
  String get settingsSecurityResetKeepTitle => '保留此裝置的登入狀態';

  @override
  String get settingsSecurityResetKeepSubtitle => '僅在重設此裝置目前登入的帳號時保留';

  @override
  String get settingsSecurityResetSyncWarning => '重設後，將無法讀取已同步的設定。';

  @override
  String get settingsSecurityResetSyncWarningDetail =>
      '密碼也用於加密已同步的設定。用舊密碼加密的資料將無法解密。';

  @override
  String get settingsSecurityResetSubmitButton => '重設密碼';

  @override
  String get settingsSnsShareConflictError => '其他裝置已先行變更。請再試一次';

  @override
  String get settingsSnsShareOffConfirmTitle => '要停止共用 SNS 登入嗎？';

  @override
  String get settingsSnsShareOffConfirmMessage =>
      '將刪除共用的資料和所有裝置的金鑰。各裝置的 SNS 登入將維持不變。';

  @override
  String get settingsSnsShareOffConfirmDetail =>
      '將刪除 RASQ Central 上的共用內容（已加密）以及所有裝置的金鑰。各裝置的 SNS 登入將維持不變。';

  @override
  String get settingsSnsShareOffConfirmButton => '停止';

  @override
  String get settingsSnsShareCancelButton => '取消';

  @override
  String get settingsSnsShareStopped => '已停止共用';

  @override
  String get settingsSnsShareSubtitleLoading => '載入中…';

  @override
  String get settingsSnsShareSubtitleUnsupported => '此裝置的登入不支援共用。請重新登入';

  @override
  String get settingsSnsShareSubtitleOffAsk => '關閉（在其他裝置登入時詢問）';

  @override
  String get settingsSnsShareSubtitleOff => '關閉';

  @override
  String get settingsSnsShareSubtitleOnHolding => '開啟 · 此裝置正在共用';

  @override
  String get settingsSnsShareSubtitleOnWaiting => '開啟 · 正在等待共用裝置的核准';

  @override
  String get settingsSnsShareSubtitleOnNotYet => '開啟 · 此裝置尚未共用';

  @override
  String get settingsSnsShareHeader => '在裝置間共用 SNS 登入';

  @override
  String get settingsSnsShareCaption => '在新裝置上也能自動登入 SNS。內容經過加密，RASQ 的伺服器無法讀取。';

  @override
  String get settingsSnsShareDetail =>
      '在已登入此 RASQ 帳號的裝置之間，以端對端加密（E2E）方式共用 SNS 存取權杖。在新裝置上登入後，經共用裝置核准，該裝置也會一併登入 SNS 帳號。RASQ 的伺服器無法讀取內容。';

  @override
  String get settingsSnsShareSwitchTitle => '與其他裝置共用 SNS 登入';

  @override
  String get settingsSnsShareRequestTitle => '請求共用到此裝置';

  @override
  String get settingsSnsShareRequestSubtitle => '共用裝置上會顯示核准請求';

  @override
  String get settingsSnsShareRequested => '已向共用裝置請求核准';

  @override
  String get settingsSnsShareDevicesLabel => '裝置';

  @override
  String get settingsSnsShareThisDeviceSuffix => '（此裝置）';

  @override
  String get settingsSnsShareDeviceShared => '共用中';

  @override
  String get settingsSnsShareDeviceWaiting => '等待核准';

  @override
  String get settingsSnsShareDeviceNotShared => '未共用';

  @override
  String settingsSnsShareApproved(String name) {
    return '已共用給 $name';
  }

  @override
  String get settingsSnsShareApproveButton => '共用';

  @override
  String get settingsSnsShareDeclineButton => '拒絕';

  @override
  String settingsSnsShareRemoved(String name) {
    return '已將 $name 移出共用';
  }

  @override
  String get settingsSnsShareRemoveButton => '移除';

  @override
  String get settingsSnsShareRemovedCaption =>
      '被移除的裝置仍保有先前的登入。若不認得該裝置，請同時在 SNS 端登出。';

  @override
  String get settingsSnsShareRemovedDetail =>
      '在「已登入的裝置」中讓該裝置登出，該裝置的金鑰也會被刪除。被移除的裝置仍持有先前收到的存取權杖（若不認得該裝置，請同時在 SNS 端登出）。';

  @override
  String get shellColumnSplitSmallFixedLabel => '固定小欄寬度';

  @override
  String get shellColumnSplitLargeFixedLabel => '固定大欄寬度';

  @override
  String get shellColumnSplitEvenHint => '等寬';

  @override
  String get shellColumnSplitTwoThreeHint => '小 2 : 大 3';

  @override
  String get shellColumnSplitThreeFiveHint => '小 3 : 大 5';

  @override
  String get shellColumnSplitSmallFixedHint => '小欄使用固定寬度，其餘給大欄';

  @override
  String get shellColumnSplitLargeFixedHint => '大欄使用固定寬度，其餘給小欄';

  @override
  String get shellColumnWidthErrorEmpty => '請輸入寬度';

  @override
  String get shellColumnWidthErrorNotInteger => '請輸入整數';

  @override
  String shellColumnWidthErrorRange(String min, String max) {
    return '請輸入 $min～$max px 之間的值';
  }

  @override
  String get shellColumnThirdEmptySearch => '搜尋';

  @override
  String get shellColumnThirdEmptyNotifications => '通知';

  @override
  String get shellColumnThirdEmptyNone => '不顯示';

  @override
  String get shellColumnThirdSettingsTooltip => '第三欄設定';

  @override
  String get shellColumnThirdCloseTooltip => '關閉';

  @override
  String get shellColumnThirdEmptyTitle => '第三欄';

  @override
  String get shellColumnThirdEmptyHint => '可以將開啟的畫面移到這裡';

  @override
  String get shellColumnThirdEmptyHintDetail => '可以將 FOW 移到這裡（M5c）';

  @override
  String get shellNavHome => '首頁';

  @override
  String get shellNavSearch => '搜尋';

  @override
  String get shellNavNotifications => '通知';

  @override
  String get shellHeaderTimelineSwitchTooltip => '切換時間軸';

  @override
  String get shellHeaderExpandTooltip => '還原標題列';

  @override
  String get shellHeaderScrollToTopTooltip => '回到頂端';

  @override
  String get shellHeaderSearchHint => '搜尋';

  @override
  String get shellHeaderBackTooltip => '返回';

  @override
  String get shellHeaderCloseButton => '關閉';

  @override
  String get shellHeaderMenuTooltip => '選單';

  @override
  String get shellHeaderOpenSidebarSemantics => '開啟側邊欄';

  @override
  String get shellSidebarSemantics => '側邊欄';

  @override
  String shellSidebarSwitchToAccountTooltip(String name) {
    return '切換到 $name';
  }

  @override
  String get shellSidebarRasqAccountTooltip => 'RASQ 帳號';

  @override
  String get shellSidebarHideAccountsTooltip => '隱藏帳號清單';

  @override
  String get shellSidebarShowAccountsTooltip => '顯示帳號清單';

  @override
  String get shellSidebarAccountSettingsButton => '帳號設定';

  @override
  String get shellSidebarBookmarks => '書籤';

  @override
  String get shellSidebarLists => '清單';

  @override
  String get shellSidebarPlugins => '外掛';

  @override
  String get shellSidebarCustomPlugins => '自訂外掛';

  @override
  String get shellSidebarAllSettings => '所有設定';

  @override
  String get shellSidebarHelp => '說明';

  @override
  String get shellSidebarDevCatalog => '元件目錄 (dev)';

  @override
  String get shellSidebarDevWasmPlugin => 'WASM 外掛測試（dev）';

  @override
  String get shellSidebarWebConsole => 'Web 主控台';

  @override
  String get shellSidebarAccountActionsTooltip => '帳號操作';

  @override
  String get shellSidebarShowAccountMenu => '查看此帳號';

  @override
  String get shellSidebarLogoutMenu => '登出';

  @override
  String get shellAccountHeaderPickTooltip => '選擇帳號';

  @override
  String shellAccountHeaderReadingAsTooltip(String account) {
    return '正在以 $account 瀏覽';
  }

  @override
  String get shellAccountHeaderSwitchSemantics => '切換帳號';

  @override
  String get shellAccountHeaderAvatarSemantics => '帳號';

  @override
  String get shellAccountPickerSemantics => '選擇帳號';

  @override
  String get shellAccountPickerCloseTooltip => '關閉';

  @override
  String get shellAccountFowTitle => 'RASQ 帳號';

  @override
  String get shellAccountFowCloseButton => '關閉';

  @override
  String get shellAccountAppealSheetTitle => '申請解除處置';

  @override
  String get shellAccountAppealCaption => '營運方負責人會閱讀你的申請，若受理，處置將會解除。';

  @override
  String get shellAccountAppealCaptionDetail =>
      '營運方（rasq-judge）負責人會閱讀你的申請，若受理，處置將會解除。不經過自動判定。';

  @override
  String get shellAccountAppealReasonHint => '申請理由（必填）';

  @override
  String shellAccountAppealFailedError(String error) {
    return '無法提出申請：$error';
  }

  @override
  String get shellAccountAppealSubmitButton => '提出申請';

  @override
  String get shellAccountAppealSentSnack => '已提出解除申請。負責人將會確認';

  @override
  String get shellAccountLocalDisplayName => '此裝置';

  @override
  String get shellAccountMenuAddSns => '新增 SNS 帳號';

  @override
  String get shellAccountMenuAllSettings => '設定';

  @override
  String get shellAccountMenuAccountPage => '帳號頁面';

  @override
  String get shellAccountMenuEditProfile => '編輯個人檔案';

  @override
  String get shellAccountMenuAccountSettings => '帳號設定';

  @override
  String get shellAccountMenuNotificationSettings => '通知設定';

  @override
  String get shellAccountMenuSecurity => '安全性（電子郵件 / 密碼 / 裝置）';

  @override
  String get shellAccountMenuLogout => '登出';

  @override
  String get shellAccountMenuDelete => '刪除 RASQ 帳號';

  @override
  String get shellAccountLogoutTitle => '登出 RASQ 帳號';

  @override
  String get shellAccountLogoutMessage => '將從此裝置移除 RASQ 帳號。';

  @override
  String get shellAccountLogoutConfirmButton => '登出';

  @override
  String get shellAccountLoggedOutWithSnsSnack => '已登出 RASQ 帳號及其 SNS 帳號';

  @override
  String get shellAccountLoggedOutKeptSnsSnack =>
      '已登出 RASQ 帳號。SNS 帳號已移至「僅限此裝置」';

  @override
  String get shellAccountDeleteReloginRequiredError => '請重新登入此帳號後再刪除';

  @override
  String get shellAccountDeleteNeedsEmailCodeSnack =>
      '刪除需要電子郵件驗證碼。請從「刪除帳號」繼續操作';

  @override
  String get shellAccountDeleteTitle => '刪除 RASQ 帳號';

  @override
  String get shellAccountDeleteMessage =>
      '將刪除伺服器上的個人檔案、帳號組合、已同步的設定、評論與書籤、ASTell 的房間與分享、通知權杖，以及同意紀錄。若你曾同意「為演算法和社群做出貢獻」，也將同時停止提供並開始刪除已提供的資料。\n此操作無法復原。各 SNS 上的帳號與貼文不會被刪除。';

  @override
  String get shellAccountDeleteConfirmButton => '刪除';

  @override
  String get shellAccountDeletedSnack => '已刪除 RASQ 帳號';

  @override
  String shellAccountDeleteFailedError(String error) {
    return '無法刪除：$error';
  }

  @override
  String shellAccountCreatedSnack(String handle) {
    return '已建立 RASQ 帳號 @$handle';
  }

  @override
  String shellAccountSanctionActive(String level) {
    return '此帳號已受到處置：$level';
  }

  @override
  String shellAccountSanctionRestrictedFeatures(String features) {
    return '已停用的功能：$features';
  }

  @override
  String shellAccountSanctionReviewDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '每次發言都會有 $seconds 秒的審查延遲',
    );
    return '$_temp0';
  }

  @override
  String shellAccountSanctionStaffNote(String note) {
    return '營運方留言：$note';
  }

  @override
  String get shellAccountSanctionNoExpiry => '期限：無';

  @override
  String shellAccountSanctionExpiry(String expiresAt) {
    return '期限：$expiresAt';
  }

  @override
  String shellAccountSanctionAppealButton(String category, String level) {
    return '申請解除（$category / $level）';
  }

  @override
  String shellAccountSanctionAppealPending(String category) {
    return '申請中（$category）';
  }

  @override
  String get shellAccountEmpty => '尚無 RASQ 帳號。';

  @override
  String shellAccountRowSubtitle(String kind, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個',
    );
    return '$kind · SNS $_temp0';
  }

  @override
  String get shellAccountRowInUseSuffix => ' · 使用中';

  @override
  String get shellAccountRowNeedsLoginSuffix => ' · 需要登入';

  @override
  String get shellAccountCollapseActionsTooltip => '收合操作';

  @override
  String get shellAccountActionsTooltip => '帳號操作';

  @override
  String shellAccountReloginSnack(String handle) {
    return '請重新登入 @$handle';
  }

  @override
  String get shellAccountChildSafeButton => '兒童安全';

  @override
  String get shellAccountCreateButton => '建立新帳號';

  @override
  String get shellAccountLoginButton => '登入';

  @override
  String get shellAccountServerNotConfigured => '尚未設定 RASQ 伺服器的連線位址';

  @override
  String get shellAccountConfigureServerButton => '設定連線目標';

  @override
  String get shellAccountProfileSheetTitle => '編輯個人檔案';

  @override
  String get shellAccountProfileSaveButton => '儲存';

  @override
  String get shellAccountProfileDisplayNameLabel => '顯示名稱';

  @override
  String get shellAccountProfileDisplayNameHint => '顯示名稱';

  @override
  String get shellAccountProfileHandleLabel => '帳號代稱（不含 @,a-z 0-9 _）';

  @override
  String get shellAccountProfileCentralCaption => '將更新 RASQ 伺服器上的個人檔案。';

  @override
  String get shellAccountProfileLocalCaption =>
      '這是僅存在於此裝置的帳號。建立 RASQ 帳號後才會分配帳號代稱。';

  @override
  String get shellAccountProfileSavedSnack => '已儲存個人檔案';

  @override
  String shellAccountProfileSaveFailedError(String error) {
    return '無法儲存：$error';
  }

  @override
  String get shellAccountTileMenuTooltip => 'RASQ 帳號';

  @override
  String get shellTermsSheetTitle => '同意使用條款';

  @override
  String get shellTermsAgreeButton => '同意';

  @override
  String get shellTermsNotice =>
      '要繼續使用 RASQ 帳號，需要同意目前的使用條款和隱私權政策。在同意之前，無法使用 ASTell、購買和資料託管。';

  @override
  String shellTermsNoticeDetail(String endpoints) {
    return 'D-371 / S-053。在與伺服器的 CENTRAL_TERMS_VERSION / CENTRAL_PRIVACY_VERSION 相同版本的同意全部記錄之前，狀態為「等待同意」。PUT /me/consents/$endpoints。';
  }

  @override
  String get shellTermsReadTermsButton => '閱讀使用條款';

  @override
  String get shellTermsReadPrivacyButton => '閱讀隱私權政策';

  @override
  String get shellTermsAgeHeader => '年齡';

  @override
  String get shellTermsGuardianConsentCheck => '已取得監護人同意';

  @override
  String get shellTermsAgreeCheck => '我已閱讀並同意使用條款和隱私權政策';

  @override
  String shellTermsVersionCaption(String termsVersion, String privacyVersion) {
    return '版本：使用條款 $termsVersion · 隱私權政策 $privacyVersion';
  }

  @override
  String get shellTermsAcceptedSnack => '已同意使用條款';

  @override
  String get shellTermsOutdatedError => '使用條款已更新。請先更新 App 再同意';

  @override
  String shellTermsRecordFailedError(String error) {
    return '無法記錄同意：$error';
  }

  @override
  String get shellTermsBannerText => '需要同意使用條款。在同意之前，無法使用 ASTell、購買等功能。';

  @override
  String get shellTermsBannerOpenButton => '查看';

  @override
  String get storeStatusInReview => '審核中';

  @override
  String get storeStatusPublished => '已發布';

  @override
  String get storeStatusUpdateAvailable => '有更新';

  @override
  String get storeStatusWarning => '警告';

  @override
  String get storeStatusSuspended => '已停止';

  @override
  String get storeStatusWithdrawn => '已撤下';

  @override
  String get storeStatusUnlisted => '非公開';

  @override
  String get storeStatusBeta => '測試版';

  @override
  String get storeStatusRevoked => '已失效';

  @override
  String get storeOriginOfficial => '官方';

  @override
  String get storeOriginVerified => '已驗證';

  @override
  String get storeOriginCommunity => '社群';

  @override
  String get storeTypeComposer => '發文';

  @override
  String get storeTypePost => '貼文';

  @override
  String get storeTypeViewer => '全螢幕顯示';

  @override
  String get storeTypeTimeline => '時間軸';

  @override
  String get storeTypeTrend => '趨勢';

  @override
  String get storeTypeTheme => '主題';

  @override
  String get storeTypeAssets => '貼圖 / 素材';

  @override
  String get storeTypeCustom => '自訂';

  @override
  String get storeTypeOther => '其他';

  @override
  String get storeFilterFree => '免費';

  @override
  String get storeFilterNoAds => '無廣告';

  @override
  String get storeFilterOfficial => '官方';

  @override
  String get storeFilterVerified => '已認證';

  @override
  String get storeFilterRecent => '30 天內';

  @override
  String get storeFilterLightweight => '輕量（小於 5MB）';

  @override
  String get storeFilterOffline => '離線';

  @override
  String get storePermNetwork => '網路';

  @override
  String get storePermNetworkDescription => '對外通訊';

  @override
  String get storePermStorage => '儲存空間';

  @override
  String get storePermStorageDescription => '裝置內的儲存空間';

  @override
  String get storePermFiles => '檔案';

  @override
  String get storePermFilesDescription => '讀寫使用者選擇的檔案';

  @override
  String get storePermSns => '貼文和帳號';

  @override
  String get storePermSnsDescription => '使用 SNS 帳號進行的操作';

  @override
  String get storePermDm => '私訊';

  @override
  String get storePermDmDescription => '讀寫私訊';

  @override
  String get storePermGpuMl => 'GPU / 機器學習';

  @override
  String get storePermGpuMlDescription => 'GPU 執行、模型推論';

  @override
  String get storePermClipboard => '剪貼簿';

  @override
  String get storePermClipboardDescription => '讀寫複製的內容';

  @override
  String get storePermBackground => '背景執行';

  @override
  String get storePermBackgroundDescription => '關閉畫面後仍會執行';

  @override
  String get storePermUi => '畫面與配置';

  @override
  String get storePermUiDescription => '畫面顯示和按鈕配置';

  @override
  String get storePermOther => '其他';

  @override
  String get storeReviewSortHelpful => '相關度';

  @override
  String get storeReviewSortRecent => '最新';

  @override
  String get storeReviewSortRatingHigh => '評分最高';

  @override
  String get storeReviewSortRatingLow => '評分最低';

  @override
  String storeScopePermission(String permission) {
    return '權限 $permission';
  }

  @override
  String storeScopeHost(String host) {
    return '連線目標 $host';
  }

  @override
  String get storeScopeInstance => '連線目標 登入的實例';

  @override
  String storeScopeSlot(String slot) {
    return '使用位置 $slot';
  }

  @override
  String storeScopeReason(String permission, String reason) {
    return '用途 $permission — $reason';
  }

  @override
  String storeScopeDataHandling(String text) {
    return '資料處理 — $text';
  }

  @override
  String storeNeedsOrgate(String feature) {
    return '連線 ORGATE-Server 後即可使用$feature（尚未設定連線位址）';
  }

  @override
  String get storeFeaturePurchase => '購買';

  @override
  String get storeFeaturePoints => '點數';

  @override
  String get storeFeatureReview => '評論';

  @override
  String storeSessionPluginMismatch(String actual, String expected) {
    return '配置中的外掛（$actual）與請求的（$expected）不同';
  }

  @override
  String storeSessionVersionMismatch(String actual, String expected) {
    return '配置的版本（$actual）與請求的版本（$expected）不同';
  }

  @override
  String get storeNoBundle => '沒有發布套件';

  @override
  String get storeListSeparator => '、';

  @override
  String get storeDotSeparator => ' · ';

  @override
  String get storeVerifyHashOnly => 'SHA-512 比對 OK（無簽章）';

  @override
  String get storeVerifyFull => 'SHA-512 + ed25519 簽章驗證 OK';

  @override
  String get storeVerifyHashMismatch => '完整性驗證失敗（SHA-512 不一致）。請稍後重新取得';

  @override
  String get storeVerifyKeyMismatch => '商店的簽章金鑰與 App 內建的金鑰不一致。請檢查連線位址';

  @override
  String get storeVerifyUnsigned => '發布套件沒有簽章（此版本僅允許已簽章的商店）';

  @override
  String get storeVerifyBadSignature => '發布套件的簽章不正確。已中止安裝';

  @override
  String storeVerifyError(String error) {
    return '無法驗證簽章：$error';
  }

  @override
  String get storeWidenedNoRecord => '因為沒有上次允許內容的紀錄（請在管理外掛中確認後安裝）';

  @override
  String storeWidenedOver(String items) {
    return '因為超出了上次允許的內容（$items）';
  }

  @override
  String get storeManifestUnavailable => '無法取得配置（資訊清單）';

  @override
  String storeManifestVersionNotFound(String version) {
    return '找不到 Ver.$version 的配置';
  }

  @override
  String storeConsentChanged(String version) {
    return '商店的配置與你確認的內容（Ver.$version）有所不同。請再次確認';
  }

  @override
  String storePackageInvalid(String error) {
    return '無法驗證發布套件的內容：$error';
  }

  @override
  String storePackageMismatch(String actual, String expected) {
    return '發布套件的內容（$actual）與商店上架資訊（$expected）不同';
  }

  @override
  String storePackageRequires(String plugins) {
    return '此外掛需要 $plugins（尚不支援，無法安裝）';
  }

  @override
  String storeThemeSaveFailed(String error) {
    return '無法儲存主題：$error';
  }

  @override
  String storeAssetsSaveFailed(String error) {
    return '無法儲存素材包：$error';
  }

  @override
  String get storeSlotRegisterFailed => '無法註冊到插槽';

  @override
  String storeVersionBundleChanged(String version) {
    return 'Ver.$version 的發布套件與安裝時不同，因此不會載入（請重新安裝）';
  }

  @override
  String storeVersionLoadFailed(String version, String error) {
    return '無法載入 Ver.$version：$error';
  }

  @override
  String get storeVersionNoScopeRecord => '沒有此版本允許內容的紀錄（重新安裝即可確認）';

  @override
  String storeVersionNotInstalled(String version) {
    return '未安裝 Ver.$version';
  }

  @override
  String get storeNotInstalled => '未安裝';

  @override
  String storeVersionInUse(String version) {
    return 'Ver.$version 正在使用中（請先取消預設 / 帳號的指定）';
  }

  @override
  String get storeManageTitle => '管理外掛';

  @override
  String get storeManageUpdatesHeader => '更新';

  @override
  String get storeManageUpdateSettingsTitle => '更新設定';

  @override
  String get storeManageUpdateSettingsSubtitle => '是否自動更新 · 更新紀錄';

  @override
  String get storeManageUpdateSettingsDetail =>
      '依 SNS / 操作 / 檢視分別選擇：自動、僅安裝、手動 · 更新紀錄';

  @override
  String get storeManagePointsTitle => '點數';

  @override
  String get storeManagePointsDisabled => '公開測試中無法使用';

  @override
  String storeManagePointsBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '點數 $count',
    );
    return '$_temp0';
  }

  @override
  String get storeManagePointsSignIn => '登入 RASQ 帳號後即可使用';

  @override
  String get storeManagePointsBuyInConsole => '可在網頁主控台購買（發放後 1 個月失效）';

  @override
  String storeManagePointsExpiring(int month, int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 點將於 $month/$day 失效 · 在網頁主控台購買',
    );
    return '$_temp0';
  }

  @override
  String get storeNoInstalledPlugins => '沒有已安裝的外掛';

  @override
  String get storeManageImportTitle => '匯入外掛';

  @override
  String get storeManageImportSubtitle => '安裝開發中的外掛（審核前）';

  @override
  String get storeManageImportDetail => '安裝開發中的 wasm / .rasqpkg（未經審核）';

  @override
  String get storeManageHomeHeader => '首頁顯示';

  @override
  String get storeManageShowInstalledTitle => '在首頁也顯示已安裝的外掛';

  @override
  String get storeManageShowInstalledSubtitle => '在本週趨勢 / 新上架欄中也列出已安裝的外掛';

  @override
  String get storeBookmarksTitle => '書籤';

  @override
  String storeManageSwitchTo(String version) {
    return '切換到 $version';
  }

  @override
  String storeVersionMadeDefault(String version) {
    return '已將 $version 設為預設版本';
  }

  @override
  String storeManageUpdateTo(String version) {
    return '更新到 $version';
  }

  @override
  String get storeManageOffline => '無法連線到商店';

  @override
  String get storeManageUpToDate => '已是最新';

  @override
  String get storeManageDeployedVersion => '已部署的版本';

  @override
  String get storeAccountVersionsTitle => '依帳號設定版本';

  @override
  String storeManageAccountVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '依帳號（已指定 $count 個）',
    );
    return '$_temp0';
  }

  @override
  String get storePluginNotFound => '找不到此外掛';

  @override
  String storeInstallFailed(String error) {
    return '無法安裝：$error';
  }

  @override
  String get storeHasAds => '含廣告';

  @override
  String get storeBuyDisabled => '公開測試中無法購買';

  @override
  String get storeTileGet => '取得';

  @override
  String get storeTileUpdate => '更新';

  @override
  String get storeOpen => '開啟';

  @override
  String get storeTileUnavailable => '已停止';

  @override
  String storeDownloadsTenThousands(String value) {
    return '$value萬';
  }

  @override
  String storeNotAssetPack(String id) {
    return '不是素材包：$id';
  }

  @override
  String get storeUpdatesNoneApplied => '沒有自動安裝的更新';

  @override
  String get storeUpdateSettingsTitle => '更新/部署設定';

  @override
  String get storeUpdateSettingsModeHeader => '更新/部署';

  @override
  String get storeUpdateSettingsPopup => '更新後啟動時顯示彈出視窗';

  @override
  String get storeUpdateLogTitle => '更新紀錄';

  @override
  String get storeUpdateSettingsCheckNow => '立即檢查';

  @override
  String get storeUpdateSettingsCaption => '擴大已允許內容的版本和付費版本不會自動安裝';

  @override
  String get storeUpdateSettingsCaptionDetail =>
      '權限、連線目標、使用位置、用途超出上次允許內容的版本（包括無法確認的版本），以及未購買的付費版本，在任何模式下都不會自動開始使用（原因會記錄在更新紀錄中）。每次啟動時檢查一次。';

  @override
  String get storeUpdateLogEmpty => '尚無';

  @override
  String get storeUpdateLogEmptyHint => '更新後會記錄在這裡';

  @override
  String get storeInstalledTitle => '已安裝';

  @override
  String get storeInstalledEmptyHint => '可以從商店加入';

  @override
  String storeInstalledItemSubtitle(String version, String id) {
    return 'v$version · $id';
  }

  @override
  String get storeUnknown => '未知';

  @override
  String get storeInstalledMissingHint => '已被刪除，或是在其他裝置上安裝的';

  @override
  String get storeInstalledSourceSnapshot => '安裝時上架資訊的副本。';

  @override
  String get storeInstalledSourceManifest => '外掛自身的宣告（僅權限 id）。';

  @override
  String get storeInstalledRemoveTitle => '要刪除嗎？';

  @override
  String storeInstalledRemoveMessage(String name) {
    return '將從裝置中刪除 $name。';
  }

  @override
  String get storeRemove => '刪除';

  @override
  String get storeCancel => '取消';

  @override
  String get storeInstalledOffline => '無法連線到商店，因此顯示本機資訊。';

  @override
  String get storeInstalledUnlisted => '找不到商店上架資訊（可能已被撤下）。可以繼續使用，也可以刪除。';

  @override
  String get storeInstalledVersionHeader => '已安裝的版本';

  @override
  String storeInstalledAt(String date) {
    return '安裝：$date';
  }

  @override
  String storeInstalledAtVerified(String date, String sha512) {
    return '安裝：$date · 已驗證 SHA-512 $sha512';
  }

  @override
  String storeInstalledNewerTitle(String version) {
    return '商店中有 v$version';
  }

  @override
  String get storeInstalledNewerSubtitle => '可以從商店頁面重新安裝';

  @override
  String storeInstalledSlots(String slots) {
    return '執行位置：$slots';
  }

  @override
  String get storeInstalledOpenStore => '開啟商店頁面';

  @override
  String get storePrivacyHeader => '隱私權和所需權限';

  @override
  String get storeVersionsInstalledHeader => '已安裝的版本';

  @override
  String get storeVersionsDefault => '預設版本';

  @override
  String storeVersionsUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個帳號正在使用',
    );
    return '$_temp0';
  }

  @override
  String storeVersionsInstalledOn(int year, int month, int day) {
    return '安裝於 $year/$month/$day';
  }

  @override
  String get storeMenu => '選單';

  @override
  String get storeVersionsMakeDefault => '設為預設版本';

  @override
  String get storeVersionsRemove => '刪除此版本';

  @override
  String storeVersionsRemoved(String version) {
    return '已刪除 $version';
  }

  @override
  String get storeVersionsOthersHeader => '安裝其他版本';

  @override
  String get storeVersionsMorePermissions => '權限會增加';

  @override
  String get storeVersionsInstall => '安裝';

  @override
  String get storeVersionsPerAccountHeader => '依帳號';

  @override
  String get storeVersionsPerAccountCaption => '可以為每個帳號選擇使用的版本';

  @override
  String get storeVersionsPerAccountDetail => '使用該帳號期間，插槽外掛和節點排序將以此處選擇的版本執行。';

  @override
  String storeVersionsFollowDefault(String version) {
    return '跟隨預設（$version）';
  }

  @override
  String storeVersionsAccountFollows(String account) {
    return '$account 跟隨預設版本';
  }

  @override
  String storeVersionsAccountUses(String account, String version) {
    return '$account 使用 $version';
  }

  @override
  String storeVersionsDefaultShort(String version) {
    return '預設（$version）';
  }

  @override
  String get storeVersionsPackNote => '主題 / 貼圖·素材在整個裝置上使用同一個版本（預設版本）。';

  @override
  String get storeUpdateModeAuto => '全自動';

  @override
  String get storeUpdateModeAutoDescription => '安裝新版本並設為預設版本（依帳號指定的版本維持不變）';

  @override
  String get storeUpdateModeInstallOnly => '僅自動安裝';

  @override
  String get storeUpdateModeInstallOnlyDescription => '僅安裝新版本，不變更使用的版本';

  @override
  String get storeUpdateModeManual => '全部手動配置';

  @override
  String get storeUpdateModeManualDescription => '不自動進行任何操作（從管理外掛安裝）';

  @override
  String get storeUpdateGroupSns => 'SNS 外掛';

  @override
  String get storeUpdateGroupAction => '操作外掛';

  @override
  String get storeUpdateGroupView => '檢視外掛';

  @override
  String storeUpdateLogActivated(String from, String to) {
    return '$from → $to（已設為預設版本）';
  }

  @override
  String storeUpdateLogInstalled(String from, String to) {
    return '已安裝 $to（使用的版本仍為 $from）';
  }

  @override
  String storeUpdateLogSwitched(String from, String to) {
    return '$from → $to（將已安裝的版本設為預設）';
  }

  @override
  String storeUpdateLogSkipped(String to) {
    return '$to 不會自動安裝';
  }

  @override
  String storeUpdateLogSkippedNote(String to, String note) {
    return '$to 不會自動安裝（$note）';
  }

  @override
  String storeUpdateLogFailed(String to) {
    return '無法安裝 $to';
  }

  @override
  String storeUpdateLogFailedNote(String to, String note) {
    return '無法安裝 $to（$note）';
  }

  @override
  String get storeUpdatePopupTitle => '外掛已更新';

  @override
  String get storeClose => '關閉';

  @override
  String get storeReviewsTitle => '評論';

  @override
  String get storeReviewsLoadFailed => '無法取得評論';

  @override
  String get storeReviewWrite => '撰寫評論';

  @override
  String get storeReviewsEmpty => '尚無評論';

  @override
  String get storeReviewsEmptyHint => '點擊右下角的 + 撰寫第一則評論';

  @override
  String get storeCopyLink => '複製連結';

  @override
  String get storeReviewReport => '檢舉評論';

  @override
  String get storeReviewLinkCopied => '已複製評論連結';

  @override
  String get storeReviewReportUnavailable => '檢舉評論功能準備中';

  @override
  String storeReloadFailed(String error) {
    return '無法重新載入：$error';
  }

  @override
  String get storeNoNewPlugins => '沒有新發布的外掛';

  @override
  String storeNewPluginsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已加入 $count 個新發布的外掛',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchTitle => '搜尋外掛';

  @override
  String get storeSearchRecentPick => '根據最近的貼文內容推薦';

  @override
  String get storeSearchFailed => '無法搜尋';

  @override
  String get storeSearchNoRecentPosts => '找不到最近的貼文';

  @override
  String get storeSearchNoRecentPostsHint => '使用 SNS 帳號發文後，將推薦與內容相近的外掛';

  @override
  String storeSearchRecentCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '依與最近 $count 則貼文內容的接近程度排序（在裝置內選出）',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchNoRecentMatches => '找不到與最近貼文相近的外掛';

  @override
  String get storeSearchNoResults => '找不到結果';

  @override
  String get storeSearchNoResultsHint => '請嘗試更換關鍵字或篩選條件';

  @override
  String get storeHomeTitle => '外掛商店';

  @override
  String get storeConnectFailed => '無法連線到商店';

  @override
  String get storeHomeOffline => '未連線到 RASQ 伺服器。僅顯示 App 內建的外掛';

  @override
  String get storeHomeOfflineDetail =>
      '未連線 Central：僅顯示內建的實物（Misskey 連接器和插槽範例）。評分 / 下載數 / 評論 / 購買在連線伺服器後顯示。';

  @override
  String get storeHomeTrending => '本週趨勢';

  @override
  String get storeHomeRecent => '新上架';

  @override
  String get storeHomeReviewedOnly => '僅上架已審核的外掛';

  @override
  String get storeHomeReviewedOnlyDetail =>
      '開發中的外掛可在開發者模式下，透過右上角的齒輪 → 管理外掛 →「匯入外掛」安裝。';

  @override
  String get storeRowEmpty => '目前沒有可顯示的外掛';

  @override
  String get storeInstallManifestUnavailable => '無法取得配置';

  @override
  String storeInstallSheetTitle(String name, String version) {
    return '安裝 $name $version';
  }

  @override
  String get storeInstallPermissionsHeader => '此外掛使用的權限';

  @override
  String get storeInstallHostsHeader => '連線目標';

  @override
  String get storeInstallLoginInstance => '登入的實例';

  @override
  String get storeInstallScopeNoRecord => '允許的內容（沒有先前安裝時的紀錄）';

  @override
  String get storeInstallScopeWidened => '超出上次允許內容的部分';

  @override
  String get storeInstallPermissionsAdded => '比上一版本增加的權限';

  @override
  String storeInstallBundleSummary(String size, String signature) {
    return '${size}MB · $signature';
  }

  @override
  String get storeInstallSignedShort => '有商店簽章';

  @override
  String get storeInstallUnsignedShort => '無商店簽章';

  @override
  String storeInstallBundleDetail(
    String size,
    String sha512,
    String signature,
  ) {
    return '發布套件：${size}MB · SHA-512 $sha512… · $signature';
  }

  @override
  String get storeInstallSignedDetail => '附商店簽章（ed25519）';

  @override
  String get storeInstallUnsignedDetail => '無商店簽章（僅雜湊比對）';

  @override
  String get storeInstallConfirm => '安裝';

  @override
  String storeInstallThemeDarkOnly(String name) {
    return '將使用 $name。在深色模式下生效';
  }

  @override
  String storeInstallThemeLightOnly(String name) {
    return '將使用 $name。在淺色模式下生效';
  }

  @override
  String storeInstallThemeApplied(String name) {
    return '將使用 $name';
  }

  @override
  String storeInstallDone(String name, String version) {
    return '已安裝 $name $version';
  }

  @override
  String storeVersionScopeTitle(String version) {
    return 'Ver.$version 將擴大允許的內容';
  }

  @override
  String get storeVersionScopeConfirm => '允許並使用';

  @override
  String get storeVersionScopeCancel => '取消';

  @override
  String storePurchasePointsFailed(String error) {
    return '無法確認點數（是否已登入 RASQ 帳號？）：$error';
  }

  @override
  String storePurchaseTitle(String name) {
    return '購買 $name';
  }

  @override
  String storePurchasePrice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 點',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩餘 $count 點',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalanceExpiring(int count, String date, int expiring) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩餘 $count 點 · $expiring 點將於 $date 失效',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseCaption => '購買的外掛在同一帳號的任何裝置上都可以使用';

  @override
  String get storePurchaseCaptionDetail =>
      '購買的外掛在同一 RASQ 帳號的任何裝置上都可以安裝。點數從最接近到期的開始使用。';

  @override
  String storePurchaseBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '用 $count 點購買',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '點數不足（還差 $count 點）',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseConsole => '在網頁主控台購買點數';

  @override
  String get storePurchaseFailed => '無法購買';

  @override
  String storeReleaseNotesSemantics(String version) {
    return '版本資訊 $version';
  }

  @override
  String get storeReleaseBeta => '預覽版（β）';

  @override
  String get storeReleaseStable => '穩定版';

  @override
  String storeReleasePublishedOn(int year, int month, int day) {
    return '$year/$month/$day 發布';
  }

  @override
  String get storeReleaseCurrentListing => '目前上架版本';

  @override
  String get storeReleaseInstalled => '已安裝';

  @override
  String get storeReleaseNoNotes => '此版本沒有版本資訊。';

  @override
  String get storeReleasePermissionsAdded => '此版本增加的權限';

  @override
  String get storeReleasePermissionsNote => '增加權限的更新不會自動進行。請確認內容後再安裝。';

  @override
  String storeReleaseAlreadyInstalled(String version) {
    return 'Ver.$version 已安裝';
  }

  @override
  String storeReleaseBlocked(String status) {
    return '因$status而無法安裝';
  }

  @override
  String storeReleaseInstall(String version) {
    return '安裝 Ver.$version';
  }

  @override
  String storeReleaseReplaces(String version) {
    return '目前已安裝 v$version。將替換為此版本。';
  }

  @override
  String get storeReviewNoVotes => '尚無評分';

  @override
  String storeReviewHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人認為有幫助。',
    );
    return '$_temp0';
  }

  @override
  String get storeShare => '分享';

  @override
  String get storeReviewHelpful => '有幫助';

  @override
  String get storeReviewNotHelpful => '沒有幫助';

  @override
  String get storeReviewAnonymous => '匿名';

  @override
  String get storeReviewVerifiedUse => '已實際使用';

  @override
  String storeReviewDeveloperReply(String reply) {
    return '開發者回覆：$reply';
  }

  @override
  String get storeReviewNoBody => '（無內文）';

  @override
  String get storeReviewComposeTitle => '撰寫評論';

  @override
  String get storeReviewSend => '傳送';

  @override
  String get storeRatingLabel => '評分';

  @override
  String get storeReviewTitleHint => '標題（選填）';

  @override
  String get storeReviewBodyHint => '請輸入使用感受或在意的地方';

  @override
  String storeReviewUsedVersion(String version) {
    return '使用版本：v$version';
  }

  @override
  String get storeReviewPickRating => '請選擇 ★';

  @override
  String get storeReviewSent => '已傳送評論';

  @override
  String storeReviewSendFailed(String error) {
    return '無法傳送評論：$error';
  }

  @override
  String get storeReviewNeedsInstall => '只能評論已安裝的外掛';

  @override
  String get storeReviewNeedsInstallServer => '只能評論已安裝的外掛。在登入狀態下重新安裝（或更新）後即可評論';

  @override
  String get storeSafetyNoPermissions => '所需權限：無';

  @override
  String get storeSafetyExternalHeader => '外部通訊與資料';

  @override
  String get storeSafetyNoHosts => '外部通訊目標：無';

  @override
  String storeSafetyHosts(String hosts) {
    return '外部通訊目標：$hosts';
  }

  @override
  String storeSafetyDataHandling(String text) {
    return '資料處理：$text';
  }

  @override
  String storeSafetySdks(String sdks) {
    return '外部 SDK：$sdks';
  }

  @override
  String get storeSafetyRuntimeHeader => '執行環境';

  @override
  String storeSafetyCrashFree(String rate) {
    return '正常啟動率 $rate%';
  }

  @override
  String get storeSafetyBackground => '有背景執行';

  @override
  String get storeSafetyNoBackground => '無背景執行';

  @override
  String get storeSafetyGpu => '使用 GPU';

  @override
  String get storeSafetyNoGpu => '不使用 GPU';

  @override
  String get storeSafetyNoAds => '無廣告';

  @override
  String storeSafetyAds(String placements) {
    return '含廣告（$placements）';
  }

  @override
  String get storePageMenuPostReview => '發布評論';

  @override
  String get storePageMenuReport => '檢舉外掛';

  @override
  String get storePageLinkCopied => '已複製商店頁面連結';

  @override
  String get storePageTitle => '外掛';

  @override
  String get storePageMaybeWithdrawn => '可能已被撤下';

  @override
  String get storePageOpenInstalled => '查看已安裝的資訊';

  @override
  String get storePageRequiresPrefix => '要使用此外掛，需要安裝 ';

  @override
  String get storePageRequiresSuffix => '。';

  @override
  String storePageInstalledVersion(String version) {
    return '已安裝 v$version';
  }

  @override
  String storePageInstalledVersionVerified(String version) {
    return '已安裝 v$version（SHA-512 已驗證）';
  }

  @override
  String get storeFree => '免費';

  @override
  String storePriceYen(String amount) {
    return '¥$amount';
  }

  @override
  String get storePageInstall => '安裝';

  @override
  String storePageBuy(String amount) {
    return '以 ¥$amount 購買';
  }

  @override
  String get storePageThemeInUse => '使用中';

  @override
  String get storePageThemeUse => '使用';

  @override
  String get storePageUnknownDeveloper => '提供者不明';

  @override
  String storePageRatingDownloads(String rating, String downloads) {
    return '★$rating · $downloads 次下載';
  }

  @override
  String storePageStatus(String status) {
    return '狀態：$status';
  }

  @override
  String get storePagePreview => '預覽';

  @override
  String get storePageDownloadsLastMonth => '上月下載數';

  @override
  String storePageReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$_temp0';
  }

  @override
  String get storePageReviewsEmptyBody => '來寫第一則評論吧。';

  @override
  String get storePageUpdatesHeader => '更新與版本';

  @override
  String get storePageNoReleaseNotes => '尚無版本資訊。';

  @override
  String get storeInUse => '使用中';

  @override
  String storePermissionsAddedList(String permissions) {
    return '新增權限：$permissions';
  }

  @override
  String get storePagePermissionsHeader => '權限';

  @override
  String get storePageNoPermissions => '此外掛不需要額外的權限。';

  @override
  String get storePageCompatibilityHeader => '相容性';

  @override
  String storePageRuntimes(String runtimes) {
    return '執行環境：$runtimes';
  }

  @override
  String storePageRequiredPlugins(String plugins) {
    return '所需外掛：$plugins';
  }

  @override
  String storePageConflicts(String plugins) {
    return '衝突：$plugins';
  }

  @override
  String storePageRasqFeatures(String features) {
    return '使用的 RASQ 功能：$features';
  }

  @override
  String get storePageVersionsTitle => '版本';

  @override
  String storePageNoPreview(String name) {
    return '$name 尚無預覽圖';
  }

  @override
  String get storePageBookmarkRemove => '移除書籤';

  @override
  String get storePageBookmarkAdd => '加入書籤';

  @override
  String storePageBookmarkFailed(String error) {
    return '無法更新書籤：$error';
  }

  @override
  String storeNeedsServer(String feature) {
    return '連線 RASQ 伺服器後即可使用$feature';
  }

  @override
  String get storeNoListing => '沒有上架資訊';

  @override
  String get storeCatalogMisskeyName => 'Misskey 連接器';

  @override
  String get storeCatalogMisskeySummary =>
      '將 Misskey 接入 RASQ 的 SNS 外掛（wasm 範例）。涵蓋取得時間軸、發文、回應、表情符號和貼文加工。';

  @override
  String get storeCatalogMisskeyDescription =>
      'rasq-sdk-sample 中以 Rust 撰寫的 wasm 外掛。實作了 sns.login / sns.timeline / post.transform / tl.sort 等契約（PROTOCOL.md），並以 RRL 卡片繪製時間軸。沒有節點定義的貼文加工會在傳給取得節點之前套用。';

  @override
  String get storeCatalogFeatureTimelineRrl => '時間軸繪製 (RRL)';

  @override
  String get storeCatalogFeatureNodeGraph => '節點圖 (tl.sort)';

  @override
  String get storeCatalogMisskeyPerm1 => '用於呼叫 Misskey 實例的 API（僅連線至登入時指定的主機）';

  @override
  String get storeCatalogMisskeyPerm2 => '儲存工作階段權杖和時間軸設定';

  @override
  String get storeCatalogMisskeyHost => '<已登入的 Misskey 實例>';

  @override
  String get storeCatalogMisskeyDataHandling =>
      '貼文和權杖僅儲存在裝置內（storage.safe）。不會傳送給開發者。';

  @override
  String get storeCatalogSampleDataHandling => '處理完全在裝置內的 wasm 中完成，不會向外部傳送。';

  @override
  String get storeCatalogAstellName => 'ASTell 音效與特效畫面';

  @override
  String get storeCatalogAstellSummary => '透過 ASTell 的外掛動作播放音效、產生的特效畫面和固定文字。';

  @override
  String get storeCatalogAstellDescription =>
      '插槽 `astell.action`。點按房間下方由本外掛宣告的按鈕即可開啟 FOW，分享系統音效（叮咚 / 點擊）、產生的彩帶、煙火、鼓掌 PNG 以及固定文字。也會顯示透過「分享到 ASTell」收到的貼文。';

  @override
  String get storeCatalogFeatureAstellAction => 'ASTell 外掛動作';

  @override
  String get storeCatalogAstellPerm1 => '用於顯示操作面板（FOW）';

  @override
  String get storeCatalogAstellPerm2 => '儲存特效的使用次數';

  @override
  String get storeCatalogComposerMediaName => '媒體加工';

  @override
  String get storeCatalogComposerMediaSummary => '對附加圖片進行 Gamma 校正、旋轉、色相調整和裁切。';

  @override
  String get storeCatalogComposerMediaDescription =>
      '插槽 `composer.media`。在編輯器的附件卡片中點按「用外掛加工」即可開啟 FOW，邊看預覽邊套用。處理僅在裝置內的 wasm 中完成。';

  @override
  String get storeCatalogFeatureMediaComposer => '媒體編輯器';

  @override
  String get storeCatalogComposerMediaPerm1 => '用於顯示加工面板（FOW）';

  @override
  String get storeCatalogComposerMediaPerm2 => '儲存上次的設定';

  @override
  String get storeCatalogComposerTextName => '主題標籤建議';

  @override
  String get storeCatalogComposerTextSummary => '在內文中輸入 # 即顯示建議，點按即可插入。';

  @override
  String get storeCatalogComposerTextDescription =>
      '插槽 `composer.text`。接收內文的變化，當游標前是 #… 時顯示建議 FOW（最近使用的標籤 + 詞典）。';

  @override
  String get storeCatalogFeatureTextComposer => '文字編輯器';

  @override
  String get storeCatalogComposerTextPerm1 => '用於顯示建議面板（FOW）';

  @override
  String get storeCatalogComposerTextPerm2 => '儲存最近使用的標籤';

  @override
  String get storeCatalogMediaFullscreenName => 'QR 碼偵測';

  @override
  String get storeCatalogMediaFullscreenSummary =>
      '在全螢幕顯示的圖片中尋找 QR 碼並標出外框，點按即可開啟連結。';

  @override
  String get storeCatalogMediaFullscreenDescription =>
      '插槽 `viewer.overlay`。接收全螢幕檢視器中的圖片並偵測 QR 碼，疊加邊界框。點按後顯示連結 FOW（複製 / 在瀏覽器中開啟 / 加入靜音字詞）。';

  @override
  String get storeCatalogFeatureViewerPlugin => '全螢幕顯示外掛';

  @override
  String get storeCatalogMediaFullscreenPerm1 => '用於顯示連結面板（FOW）';

  @override
  String get storeCatalogMediaFullscreenPerm2 => '用於透過「將此連結設為靜音」加入靜音字詞（每次都會確認）';

  @override
  String get storeCatalogPostProcessName => '相對日期轉為日期';

  @override
  String get storeCatalogPostProcessSummary => '將「今天」「昨天」「明天」替換為以發文日期為基準的日期。';

  @override
  String get storeCatalogPostProcessDescription =>
      '插槽 `post.transform`。在所有時間軸顯示之前，將內文中的相對日期改寫為「9/10（今天）」這樣的形式（JST）。不會改動 URL 內的內容。';

  @override
  String get storeCatalogFeaturePostTransform => '貼文加工 (post.transform)';

  @override
  String get storeCatalogTimelineName => 'Unicode 升冪時間軸';

  @override
  String get storeCatalogTimelineSummary => '在首頁新增依內文 Unicode 順序排列的分頁。';

  @override
  String get storeCatalogTimelineDescription =>
      '插槽 `tl`。接收基礎時間軸（首頁），顯示依內文 Unicode 碼位升冪重新排列的自訂分頁。';

  @override
  String get storeCatalogFeatureTimelineSort => '時間軸 (tl.sort)';

  @override
  String get storeCatalogPostShareName => '分享範本';

  @override
  String get storeCatalogPostShareSummary =>
      '在分享 FOW 中以範本（連結 / 引用 / 提及作者）整理貼文並送到編輯器。';

  @override
  String get storeCatalogPostShareDescription =>
      '插槽 `post.share`。自動排列在貼文分享 FOW 的「外掛」區段，點按後在內嵌 FOW 中選擇文案，並傳給編輯器 / 複製 / 瀏覽器 / ASTell。';

  @override
  String get storeCatalogFeaturePostShare => '貼文分享 (post.share)';

  @override
  String get storeCatalogPostSharePerm1 => '用於顯示範本選擇面板（FOW）';

  @override
  String get storeCatalogPostSharePerm2 => '儲存上次的範本';

  @override
  String get storeCatalogMediaTransformName => '變形控點';

  @override
  String get storeCatalogMediaTransformSummary => '在圖片上疊加旋轉 / 裁切控點進行編輯。';

  @override
  String get storeCatalogMediaTransformDescription =>
      '插槽 `composer.media`（變形）。在媒體編輯器的預覽上以 RRL 疊加層（契約 v0.5 `composer.media.overlay`）繪製控點，用手指拖曳來決定旋轉角度或裁切範圍。';

  @override
  String get storeCatalogFeatureOverlay => '疊加層 (overlay)';

  @override
  String get storeCatalogMediaTransformPerm1 => '用於顯示面板（FOW）';

  @override
  String get storeCatalogMediaProcessName => '加工（臉部模糊 / 貼圖）';

  @override
  String get storeCatalogMediaProcessSummary =>
      '偵測並模糊臉部，將貼圖作為物件貼上（移動 / 縮放 / 旋轉 / 刪除 / 複製）。';

  @override
  String get storeCatalogMediaProcessDescription =>
      '插槽 `composer.media`（加工）。臉部偵測在裝置內的 wasm（rustface）中進行，不會向外部傳送。貼圖可以透過疊加層的外框和控點移動。';

  @override
  String get storeCatalogMediaProcessPerm1 => '用於顯示貼圖選擇面板（FOW）';

  @override
  String get storeCatalogMediaDrawName => '繪圖（畫筆 / 圖形）';

  @override
  String get storeCatalogMediaDrawSummary => '以樣條曲線繪製畫筆軌跡，並可新增和編輯矩形 / 圓形。';

  @override
  String get storeCatalogMediaDrawDescription =>
      '插槽 `composer.media`（繪圖）。畫筆以 Catmull-Rom 樣條曲線平滑手指軌跡後繪製。圖形作為物件可以移動 / 縮放 / 刪除 / 複製。';

  @override
  String get storeCatalogMediaDrawPerm1 => '用於顯示畫筆粗細 / 顏色面板（FOW）';

  @override
  String get storeCatalogMediaDrawPerm2 => '儲存畫筆設定';

  @override
  String get storeCatalogPostActionName => '貼文按鈕';

  @override
  String get storeCatalogPostActionSummary =>
      '稍後閱讀 / 複製內文 / 引用草稿 — 依標籤加入現有按鈕組。';

  @override
  String get storeCatalogPostActionDescription =>
      '插槽 `post.action`。如果資訊清單中的標籤（期望插槽）與現有動作按鈕相近，會自動加入該按鈕組的最底層。在「編輯動作清單」中可依帳號變更啟用 / 停用和閾值。';

  @override
  String get storeCatalogFeaturePostAction => '貼文動作按鈕 (post.action)';

  @override
  String get storeCatalogPostActionPerm1 => '用於顯示稍後閱讀清單（FOW）';

  @override
  String get storeCatalogPostActionPerm2 => '儲存稍後閱讀';

  @override
  String get storeCatalogThemeStarryName => '主題「星空」';

  @override
  String get storeCatalogThemeStarrySummary => '夜空背景、點綴星光的貼文卡片、星星按讚。';

  @override
  String get storeCatalogThemeStarryDescription =>
      '主題（`kind: \"theme\"`，契約 v0.16）。不含程式碼的發布物，宣告顏色、圖示替換，以及畫面、貼文卡片、FOW、按鈕背景的圖片圖層。安裝後在 設定 → App 外觀 → 字型和配色 中選擇（在深色模式下生效）。';

  @override
  String get storeCatalogFeatureTheme => '主題';

  @override
  String get storeCatalogThemeRasqName => '主題「RASQ」';

  @override
  String get storeCatalogThemeRasqSummary =>
      '貼文上方帶有深藍色漸層條和淡淡的 RASQ 標誌，FOW 為綠色漸層。';

  @override
  String get storeCatalogThemeRasqDescription =>
      '主題（`kind: \"theme\"`，契約 v0.17）。貼文卡片上緣有從 #1F1E33 漸層融入貼文背景色的條帶，背景帶有淡淡的 RASQ 標誌，FOW 背景為由上到下 #02775C → #178178 的漸層（文字為白色）。淺色 / 深色模式皆生效。';

  @override
  String get storeCatalogPaintName => '大家一起塗鴉';

  @override
  String get storeCatalogPaintSummary =>
      '每人一格塗鴉，在限定時間內互相展示。可在 ASTell 房間或個人檔案中使用。';

  @override
  String get storeCatalogPaintDescription =>
      '自訂外掛（插槽 `page`，契約 v0.23）。將 3:4 的格子排成 2 欄（每個人看到的順序隨機），點按自己的格子即可在媒體編輯畫面的 SVG 模式中塗鴉（以 zstd 壓縮後傳送儲存）。顯示期限由各人選擇，管理員（工作階段擁有者）決定預設值和上限。到期後由 Central 刪除。管理員可以刪除他人的塗鴉。';

  @override
  String get storeCatalogFeatureCustomPage => '自訂外掛 (page)';

  @override
  String get storeCatalogFeatureSvgPaint => 'SVG 塗鴉';

  @override
  String get storeCatalogFeatureDisplayPeriod => '顯示期限';

  @override
  String get storeCatalogFeatureProfile => '個人檔案';

  @override
  String get storeCatalogPaintPerm1 => '用於顯示塗鴉格子並開啟編輯畫面';

  @override
  String get storeCatalogPaintPerm2 => '用於在限定時間內分享大家的塗鴉和管理員的設定';

  @override
  String get storeCatalogBoardName => '大家的看板';

  @override
  String get storeCatalogBoardSummary =>
      '計數器、投票、留言牆、🎉。在 ASTell 房間或個人檔案中，大家可以使用同一個看板。';

  @override
  String get storeCatalogBoardDescription =>
      '自訂外掛（插槽 `page`，契約 v0.18）。新增一個頁面，在共享工作階段中透過伺服器變數（計數器 / 投票 / 留言牆）和伺服器函式（向所有人傳送 🎉）共享同一畫面。沒有工作階段時僅在裝置內運作。';

  @override
  String get storeCatalogBoardPerm1 => '用於繪製頁面';

  @override
  String get storeCatalogBoardPerm2 => '用於分享大家的數值（計數器 / 投票 / 留言牆）';

  @override
  String get storeCatalogBoardPerm3 => '單人使用時儲存看板';

  @override
  String get storeCatalogTrendName => '趨勢建議';

  @override
  String get storeCatalogTrendSummary => '根據目前的趨勢字詞，以本機規則推薦相關標籤。';

  @override
  String get storeCatalogTrendDescription =>
      '插槽 `trend.suggest`。顯示在時間軸節點（取得趨勢 / Today / 建議標籤）和搜尋首頁的「搜尋建議」中。使用無需伺服器的共現詞典 + 前綴比對。';

  @override
  String get storeCatalogFeatureTrendSuggest => '趨勢 (trend.suggest)';

  @override
  String storePkgMissingPlugin(String id) {
    return '發布包中缺少 $id';
  }

  @override
  String get storePkgNotPackage => '發布包不是 .rasqpkg(zstd)';

  @override
  String storePkgUnpack(String error) {
    return '無法解壓縮發布包（已損毀或過大）：$error';
  }

  @override
  String storePkgTar(String error) {
    return '無法讀取發布包的 tar:$error';
  }

  @override
  String get storePkgTooManyFiles => '發布包中的檔案過多';

  @override
  String storePkgNotRegularFile(String path) {
    return '發布包中含有非一般檔案：$path';
  }

  @override
  String storePkgDuplicatePath(String path) {
    return '發布包內的路徑重複：$path';
  }

  @override
  String get storePkgBundleFirst => '發布包的開頭不是 bundle.json';

  @override
  String storePkgBundleRead(String error) {
    return '無法讀取 bundle.json:$error';
  }

  @override
  String storePkgBundleSchema(String schema) {
    return 'bundle.json 的 schema 不是 rasq.bundle/1:$schema';
  }

  @override
  String storePkgFileShape(String what) {
    return 'bundle.json:$what 的 wasm / file 格式不正確';
  }

  @override
  String storePkgNoPath(String what) {
    return 'bundle.json:$what 缺少 path';
  }

  @override
  String storePkgSizeMismatch(String path) {
    return '$path:大小與目錄不符';
  }

  @override
  String storePkgHashMismatch(String path) {
    return '$path:SHA-512 與目錄不符';
  }

  @override
  String storePkgNoSha512(String what) {
    return 'bundle.json:$what 缺少 sha512';
  }

  @override
  String storePkgNotWasm(String path) {
    return '$path:不是 wasm';
  }

  @override
  String storePkgPluginShape(String what) {
    return 'bundle.json:$what 的格式不正確';
  }

  @override
  String storePkgBadId(String what, String id) {
    return 'bundle.json:$what 的 id 無效：$id';
  }

  @override
  String storePkgBadVersion(String id, String version) {
    return 'bundle.json:$id 的 version 無效：$version';
  }

  @override
  String storePkgBadKind(String id, String kind) {
    return 'bundle.json:$id 的 kind 無效：$kind';
  }

  @override
  String storePkgNoManifest(String id) {
    return 'bundle.json:$id 缺少 manifest';
  }

  @override
  String storePkgManifestRead(String path, String error) {
    return '無法讀取 $path:$error';
  }

  @override
  String storePkgManifestMismatch(
    String path,
    String id,
    String version,
    String kind,
  ) {
    return '$path:id / version / kind 與目錄（$id $version $kind）不符';
  }

  @override
  String storePkgChildPackKind(String id, String kind) {
    return 'bundle.json:子項 $id 不能為 kind = $kind';
  }

  @override
  String storePkgPackHasWasm(String kind, String id) {
    return 'bundle.json:$kind $id 包含 wasm';
  }

  @override
  String storePkgMissingKey(String key) {
    return 'bundle.json:缺少 $key';
  }

  @override
  String get storePkgChildrenNotSns => 'bundle.json:sns 以外的 root 不能有 children';

  @override
  String storePkgChildPrefix(String id, String root) {
    return 'bundle.json:子項 $id 的 id 不是以 $root. 開頭';
  }

  @override
  String storePkgChildSns(String id) {
    return 'bundle.json:子項 $id 不能為 kind = sns';
  }

  @override
  String get storePkgDuplicateId => 'bundle.json:外掛 id 重複';

  @override
  String get storePkgLibsShape => 'bundle.json:libs 的格式不正確';

  @override
  String get storePkgAssetsShape => 'bundle.json:assets 的格式不正確';

  @override
  String get storePkgPackExtras =>
      'bundle.json:素材包 / 主題不能有 children / libs / models';

  @override
  String get storePkgPackWasm => '素材包 / 主題中包含 wasm';

  @override
  String storePkgPackImageCount(int max, int count) {
    return '素材包的圖片數量須為 1~$max 張：$count';
  }

  @override
  String storePkgNotImage(String path) {
    return '$path:不是圖片（PNG / JPEG / WebP / GIF）';
  }

  @override
  String storePkgImageTooLarge(String path, int mib) {
    return '$path:過大（每張最多 $mib MiB）';
  }

  @override
  String storePkgAssetNotListed(String path) {
    return 'manifest.assets 中的 $path 不在發布包的目錄中';
  }

  @override
  String get storePkgModelsShape => 'bundle.json:models 的格式不正確';

  @override
  String get storePkgRequiresShape => 'bundle.json:requires 的格式不正確';

  @override
  String get storePkgNoSums => '缺少 SHA512SUMS';

  @override
  String storePkgSumsMissingFile(String path) {
    return '$path:列在 SHA512SUMS 中但不在包內';
  }

  @override
  String storePkgSumsMismatch(String path) {
    return '$path:與 SHA512SUMS 不符';
  }

  @override
  String storePkgUnlisted(String path) {
    return '$path:存在未列入目錄的檔案';
  }

  @override
  String get storePkgThemeMissing => '主題的資訊清單中缺少 theme';

  @override
  String storePkgThemeAsset(String where, String id) {
    return 'theme.$where 的圖片 $id 不在 assets（use: theme）中';
  }

  @override
  String storePkgThemeSurface(String surface) {
    return 'theme.surfaces 中不能使用 $surface(app / postTile / fow / actionButton)';
  }

  @override
  String storePkgThemeLayer(String surface) {
    return 'theme.surfaces.$surface.layers:請只填寫 asset 或 gradient 其中之一';
  }

  @override
  String storePkgThemeColors(String surface) {
    return 'theme.surfaces.$surface.layers:gradient.colors 須為 2~8 種顏色';
  }

  @override
  String storePkgThemeStops(String surface) {
    return 'theme.surfaces.$surface.layers:gradient.stops 的數量須與 colors 相同';
  }

  @override
  String storePkgBadPath(String path) {
    return '不能用作發布包內的路徑：$path';
  }

  @override
  String storePkgSigAlg(String alg) {
    return '簽章的 alg 不是 ed25519:$alg';
  }

  @override
  String get storePkgSigDigest => 'sig.json 的 digest 與發布包不符（發布包已被替換）';

  @override
  String get storePkgSigRead => '無法讀取 sig.json 的 publicKey / signature';

  @override
  String get storePkgSigLength => 'sig.json 中金鑰 / 簽章的長度不正確';

  @override
  String get storePkgSigInvalid => '開發者金鑰的簽章不符';

  @override
  String storePkgFileMissing(String path) {
    return '$path:列在目錄中但不在包內';
  }

  @override
  String storePkgTwice(String path) {
    return 'bundle.json:$path 出現了 2 次';
  }

  @override
  String get storePkgKindTheme => '主題';

  @override
  String get storePkgKindAssets => '素材包';

  @override
  String swingActionFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get swingReplyHint => '傳送回覆…';

  @override
  String swingReplyToHint(String handle) {
    return '回覆 @$handle…';
  }

  @override
  String swingReplyCount(int count) {
    return '回覆 $count';
  }

  @override
  String get swingQueueTooltip => '佇列（長按選擇圖片）';

  @override
  String get swingThreadBackReply => '返回上一則回覆';

  @override
  String get swingThreadBackSwing => '返回 Swing 的回覆';

  @override
  String swingRepliesTo(String handle, int count) {
    return '對 @$handle 的回覆 $count';
  }

  @override
  String get swingThreadClose => '收合回覆';

  @override
  String swingLoadFailed(String error) {
    return '無法載入：$error';
  }

  @override
  String get swingNoReplies => '還沒有回覆。';

  @override
  String swingViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '查看 $_temp0回覆';
  }

  @override
  String swingAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個',
    );
    return '附件 $_temp0';
  }

  @override
  String get swingPoll => '投票';

  @override
  String swingReplyOf(String name) {
    return '$name 的回覆';
  }

  @override
  String get swingImageSwing => '圖片 Swing';

  @override
  String get swingVideoSwing => '影片 Swing';

  @override
  String get swingPluginSwing => '外掛 Swing';

  @override
  String swingOf(String name) {
    return '$name 的 Swing';
  }

  @override
  String get swingBarSemantics => 'Swing 的回覆與進度列';

  @override
  String swingReportIntro(String name) {
    return '檢舉 $name 的 Swing。RASQ 將進行審核。';
  }

  @override
  String get swingReported => '已檢舉。將進行審核';

  @override
  String swingReportFailed(String error) {
    return '無法檢舉：$error';
  }

  @override
  String get swingDeleteTitle => '刪除 Swing';

  @override
  String get swingDeleteMessage => '將刪除此 Swing 及其回覆。此操作無法復原。';

  @override
  String get swingDeleteConfirm => '刪除';

  @override
  String get swingCancel => '取消';

  @override
  String swingDeleteFailed(String error) {
    return '無法刪除：$error';
  }

  @override
  String get swingDeleted => '已刪除 Swing';

  @override
  String get swingViewerEmptyMine => '你沒有發布中的 Swing';

  @override
  String get swingViewerEmptyMineHint => '將 ＋ 向上滑動即可建立 Swing';

  @override
  String get swingViewerEmpty => '沒有 Swing';

  @override
  String get swingViewerEmptyHint => '你追蹤的人以及將你加入 RASQ 清單的人的 Swing 會顯示在這裡';

  @override
  String get swingClose => '關閉';

  @override
  String swingRemainingHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小時',
    );
    return '剩餘 $_temp0';
  }

  @override
  String swingRemainingMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分鐘',
    );
    return '剩餘 $_temp0';
  }

  @override
  String get swingRemainingSoon => '即將消失';

  @override
  String swingRemainingAndPosition(String remaining, String position) {
    return '$remaining · $position';
  }

  @override
  String swingViewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0看過';
  }

  @override
  String get swingReport => '檢舉';

  @override
  String get swingMenu => '選單';

  @override
  String get swingDelete => '刪除';

  @override
  String get swingSensitive => '敏感內容';

  @override
  String get swingReveal => '顯示';

  @override
  String swingPluginJoinNote(String name) {
    return '大家一起進入 $name 的頁面。無需安裝，僅在觀看此 Swing 期間執行。';
  }

  @override
  String get swingPluginJoin => '加入';

  @override
  String get swingPluginConsent => '這是未經審核的外掛。將在無法連網的狀態下，僅在觀看此 Swing 期間執行。';

  @override
  String get swingPluginConsentDetail =>
      '受限模式（network / storage.unsafe / interstitial·system 的 FOW / 開啟 URL 等均關閉，GPU 可用）。僅限沒有子外掛的單一外掛。';

  @override
  String get swingPluginRun => '執行';

  @override
  String swingPluginNeedsInstall(String name) {
    return '安裝 $name 後即可查看';
  }

  @override
  String get swingPluginNeedsInstallHint => '這是外掛 Swing。請從商店安裝';

  @override
  String get swingViewInStore => '在商店中查看';

  @override
  String get swingPluginOpenFailed => '無法開啟';

  @override
  String get swingPluginTapToExpand => '點擊返回全螢幕';

  @override
  String get swingPluginSwipeHint => '左右或上下滑動查看下一個 Swing';

  @override
  String get swingPluginShrink => '結束全螢幕';

  @override
  String get swingAd => '廣告';

  @override
  String get swingAdSwipeHint => '滑動查看下一個 Swing';

  @override
  String get swingKindText => '文字';

  @override
  String get swingKindImage => '圖片';

  @override
  String get swingKindVideo => '影片';

  @override
  String get swingKindPlugin => '外掛';

  @override
  String swingKindSwing(String kind) {
    return '$kind Swing';
  }

  @override
  String swingBannerNew(int count) {
    return '新 $count';
  }

  @override
  String swingBannerTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$_temp0';
  }

  @override
  String get swingComposerPluginShared => '大家一起用：觀看者會進入你建立的同一個頁面';

  @override
  String get swingComposerPluginFullscreen => '在觀看者的裝置上全螢幕執行';

  @override
  String get swingComposerPluginPage => '在觀看者的裝置上作為頁面執行';

  @override
  String swingTtlLabel(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小時後消失',
    );
    return '$_temp0';
  }

  @override
  String get swingTtl => '消失時間';

  @override
  String swingTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小時',
    );
    return '$_temp0';
  }

  @override
  String get swingBackgroundImage => '以圖片作為背景';

  @override
  String get swingBackgroundVideo => '以影片作為背景';

  @override
  String get swingPickVideoFile => '請選擇影片檔案';

  @override
  String get swingPickImageFile => '請選擇圖片檔案';

  @override
  String get swingChangeBackground => '更換背景';

  @override
  String get swingAudience => '傳送對象';

  @override
  String get swingLoadFailedShort => '無法載入';

  @override
  String swingSent(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小時後消失',
    );
    return '已發布 Swing（$_temp0）';
  }

  @override
  String get swingErrorLimit => '同時最多只能發出 20 個 Swing';

  @override
  String swingSendFailed(String error) {
    return '無法發布：$error';
  }

  @override
  String get swingComposerTitle => '建立 Swing';

  @override
  String get swingNext => '下一步';

  @override
  String get swingSend => '發布';

  @override
  String get swingNeedsAccount => '需要 RASQ 帳號';

  @override
  String get swingNeedsAccountHint => 'Swing 透過 RASQ 帳號發布。請從側邊欄登入';

  @override
  String swingUnreviewed(String name) {
    return '$name（未審核）';
  }

  @override
  String swingTtlRemaining(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 小時後消失',
    );
    return '$_temp0';
  }

  @override
  String get swingRepick => '重新選擇';

  @override
  String get swingReedit => '重新編輯';

  @override
  String swingCwTooLong(int max) {
    return 'CW 最多 $max 個字';
  }

  @override
  String get swingCwHint => 'CW 文字';

  @override
  String get swingCwOff => '移除 CW';

  @override
  String get swingCwOn => '加上 CW（敏感內容）';

  @override
  String get swingPluginSection => '要分發的外掛';

  @override
  String get swingPluginNone =>
      '未安裝可透過 Swing 分發的自訂外掛。可從商店安裝，或透過下方的「從檔案」分發你自己的外掛。';

  @override
  String get swingPluginNoneDetail =>
      '頁面型（自訂外掛）中，與其他外掛沒有父子關係的外掛（solo / shared 皆可）。';

  @override
  String get swingFromFile => '從檔案（未審核）';

  @override
  String get swingFromFileSubtitle => '分發你自己製作的 .rspkg / .rasqpkg / .wasm';

  @override
  String get swingFromFileDetail =>
      '未經審核的外掛會在觀看者的裝置上以無法連網的狀態執行（可使用 GPU）。以其他外掛為基礎的子外掛無法分發。';

  @override
  String get swingAudienceEmpty => '請至少選擇一個傳送對象';

  @override
  String get swingAudienceFollowers => '追蹤者';

  @override
  String get swingAudienceFollowersSubtitle => '追蹤你 RASQ 帳號的人';

  @override
  String get swingAudienceList => 'RASQ 清單';

  @override
  String get swingAudienceNoLists => '建立 RASQ 清單後，也可以傳送給清單中的人';

  @override
  String swingPackageFetchFailed(int status) {
    return '無法取得外掛（HTTP $status）';
  }

  @override
  String get swingNotLoggedIn => '尚未登入 RASQ 帳號';

  @override
  String get swingUnreadable => '無法讀取 Swing';

  @override
  String themeNotAThemePack(String id) {
    return '不是主題包：$id';
  }

  @override
  String get themePickerLabel => '主題（.rspkg / .rasqpkg）';

  @override
  String themeNotATheme(String id, String kind) {
    return '不是主題（kind: theme）：$id（$kind）';
  }

  @override
  String themeLoadFailed(String error) {
    return '無法載入：$error';
  }

  @override
  String get themeTitle => '字型與配色';

  @override
  String get themeCaption => '可變更顏色、圖示和背景。同時只能使用一個';

  @override
  String get themeCaptionDetail =>
      '主題是變更顏色、圖示以及畫面 / 貼文卡片 / FOW / 按鈕背景的套件。不會執行程式碼。同時只能使用一個。';

  @override
  String get themeColorScheme => '配色方案';

  @override
  String get themeModeSystem => '跟隨系統';

  @override
  String get themeModeLight => '淺色';

  @override
  String get themeModeDark => '深色';

  @override
  String get themePacks => '主題';

  @override
  String get themeNone => '不使用主題（預設）';

  @override
  String get themeDarkOnly => '在深色模式下生效';

  @override
  String get themeLightOnly => '在淺色模式下生效';

  @override
  String get themeSideloaded => '從檔案載入（未審核）';

  @override
  String get themeSeparator => ' · ';

  @override
  String get themeRemove => '刪除';

  @override
  String themeDarkOnlyNotice(String name) {
    return '「$name」在深色模式下生效。目前為淺色模式。';
  }

  @override
  String themeLightOnlyNotice(String name) {
    return '「$name」在淺色模式下生效。目前為深色模式。';
  }

  @override
  String get themeSwitchToDark => '切換至深色模式';

  @override
  String get themeSwitchToLight => '切換至淺色模式';

  @override
  String get themeEmpty => '尚未安裝主題。';

  @override
  String get themeFindInStore => '在商店中尋找主題';

  @override
  String get themeImport => '從檔案載入（.rspkg / .rasqpkg）';

  @override
  String get themeImportSubtitle => '載入自己製作的主題';

  @override
  String get themeImportDetail => '用 rasq build 製作的主題套件。不含程式碼，因此即使未經審核也可直接使用';

  @override
  String get trendTitle => '趨勢';

  @override
  String get trendTabNotes => '貼文';

  @override
  String get trendTabFollowing => '追蹤中';

  @override
  String get trendTabUsers => '使用者';

  @override
  String get trendBackToHome => '返回趨勢首頁';

  @override
  String get trendSourceAccountMark => '提供此趨勢的帳號';

  @override
  String get trendSettingsTooltip => '趨勢設定';

  @override
  String get trendCustomizeTooltip => '自訂趨勢時間軸';

  @override
  String get trendReload => '重新載入';

  @override
  String get trendEmptyTitle => '這裡什麼都沒有';

  @override
  String get trendEmptyHint => '變更關鍵字或篩選條件也許能找到';

  @override
  String get trendFollowingEmptyTitle => '沒有追蹤對象的貼文';

  @override
  String get trendFollowingEmptyHint => '你追蹤的人還沒有發布有關此關鍵字的貼文';

  @override
  String get trendUsersBlocked => '監護人已停用使用者搜尋';

  @override
  String get trendUsersEmpty => '沒有使用者';

  @override
  String trendUserReactions(int count) {
    return '回應 $count';
  }

  @override
  String get trendMenuOpenAs => '以其他帳號開啟';

  @override
  String get trendMenuReport => '檢舉';

  @override
  String trendMenuAccountSourced(String account) {
    return '$account（提供此趨勢的帳號）';
  }

  @override
  String get trendReportTitle => '檢舉';

  @override
  String trendReportMessage(String tag) {
    return '檢舉趨勢「$tag」。RASQ 將進行審核。已檢舉的趨勢將不再顯示於趨勢列表中。';
  }

  @override
  String trendReportMessageWithServer(String tag, String server) {
    return '檢舉趨勢「$tag」($server)。RASQ 將進行審核。已檢舉的趨勢將不再顯示於趨勢列表中。';
  }

  @override
  String get trendReportNoteHint => '補充說明（選填）';

  @override
  String get trendReportSend => '檢舉';

  @override
  String get trendReportSent => '已檢舉。RASQ 將進行審核';

  @override
  String get trendReportStored => '已儲存在此裝置上。連接到 RASQ 帳號後將傳送';

  @override
  String get trendReportFailed => '傳送失敗，已儲存在此裝置上（稍後將重新傳送）';

  @override
  String get trendReportUnhide => '恢復顯示';

  @override
  String get trendPluginFallbackName => '趨勢外掛';

  @override
  String get trendPluginLoadFailed => '無法載入';

  @override
  String get trendPluginNoWords => '還沒有候選關鍵字';

  @override
  String trendPluginWordQuoted(String word) {
    return '「$word」';
  }

  @override
  String trendPluginTodayEmpty(String words) {
    return '還沒有關於$words的貼文';
  }

  @override
  String trendPluginTodayHeading(String words) {
    return '關於$words的貼文';
  }

  @override
  String get trendEmotionJoy => '喜悅';

  @override
  String get trendEmotionTrust => '信任';

  @override
  String get trendEmotionFear => '恐懼';

  @override
  String get trendEmotionSurprise => '驚訝';

  @override
  String get trendEmotionSadness => '悲傷';

  @override
  String get trendEmotionDisgust => '厭惡';

  @override
  String get trendEmotionAnger => '憤怒';

  @override
  String get trendEmotionAnticipation => '期待';

  @override
  String get trendExamplesNoCandidates => '沒有候選';

  @override
  String get trendExamplesAllow => '喜歡';

  @override
  String get trendExamplesDeny => '不喜歡';

  @override
  String get trendExamplesDecide => '確定';

  @override
  String trendExamplesLoadFailed(String source, String error) {
    return '無法載入$source：$error';
  }

  @override
  String get trendExamplesAllSeen => '已全部看完';

  @override
  String trendExamplesAllSeenHint(
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
  ) {
    return '$allowLabel $allow / $denyLabel $deny。點選確定即可儲存';
  }

  @override
  String trendExamplesIntro(String allowLabel, String denyLabel) {
    return '檢視內容後，用下方的「$allowLabel」/「$denyLabel」（也可右滑 / 左滑）將其設為範例。新內容會依據與範例的接近程度進行分類。';
  }

  @override
  String trendExamplesSummary(
    String intro,
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
    int remaining,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining 項',
    );
    return '$intro（$allowLabel $allow / $denyLabel $deny · 剩餘 $_temp0）';
  }

  @override
  String get trendExamplesSearch => '搜尋';

  @override
  String get trendExamplesSkip => '略過';

  @override
  String trendExamplesMorePosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '+$_temp0';
  }

  @override
  String get trendExamplesPostsUnreadable => '無法讀取貼文（將依名稱和說明進行比較）';

  @override
  String trendExamplesOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 項',
    );
    return '另外 $_temp0';
  }

  @override
  String get trendExamplesSourceActions => '最近的動作';

  @override
  String get trendExamplesSourceActionsEmpty => '沒有最近的動作';

  @override
  String get trendExamplesSourceActionsEmptyHint => '回應或加入書籤後，即可在這裡選擇';

  @override
  String get trendExamplesSourcePlugins => '外掛';

  @override
  String get trendExamplesSourcePluginsEmpty => '未安裝外掛';

  @override
  String get trendExamplesSourceClips => '便籤';

  @override
  String get trendExamplesSourceClipsEmpty => '沒有便籤';

  @override
  String get trendExamplesSourceLists => '清單';

  @override
  String get trendExamplesSourceListsEmpty => '沒有清單';

  @override
  String get trendExamplesSourceStore => '商店';

  @override
  String get trendExamplesSourceStoreHint => '搜尋商店（留空 = 全部）';

  @override
  String get trendExamplesSourceStoreEmpty => '找不到結果';

  @override
  String get trendExamplesKindPlugin => '外掛';

  @override
  String get trendExamplesKindClip => '便籤';

  @override
  String get trendExamplesKindList => '清單';

  @override
  String get trendExamplesKindPost => '貼文';

  @override
  String get trendExamplesKindText => '文字';

  @override
  String get trendProfileSheetTitle => '趨勢設定檔設定';

  @override
  String get trendProfileClose => '關閉';

  @override
  String get trendProfileDecide => '確定';

  @override
  String get trendProfileGenres => '喜歡的類型/方向';

  @override
  String get trendProfileGenresSnsDefault => '喜歡的類型/方向（交給 SNS 的設定）';

  @override
  String get trendProfileGenresAuto => '喜歡的類型/方向（從操作中自動擷取）';

  @override
  String get trendProfileAddGenrePill => '+ 新增類型';

  @override
  String get trendProfileEdit => '編輯';

  @override
  String get trendProfileTendencyTitle => '趨勢的傾向/刺激程度';

  @override
  String trendProfileTendencySummary(String directivity, String stimulus) {
    return '傾向 $directivity · 刺激程度 $stimulus';
  }

  @override
  String get trendProfilePluginsTitle => '趨勢外掛設定';

  @override
  String get trendProfilePluginsSubtitle => '時間軸節點 / 搜尋建議';

  @override
  String get trendProfilePluginsDetail =>
      'trend.suggest 外掛。用於時間軸自訂的節點（取得趨勢 / Today / 自訂）與搜尋建議';

  @override
  String get trendProfileCacheNetworkTitle => '快取網路設定';

  @override
  String get trendProfileComingSoon => '即將推出';

  @override
  String get trendProfileAlgorithmTitle => '編輯演算法（節點）';

  @override
  String get trendProfileAlgorithmSubtitle => '編輯趨勢的收集與排序方式';

  @override
  String get trendProfileAlgorithmDetail => '趨勢取得與排序的鏈（ml.tendency 節點可使用此設定檔）';

  @override
  String get trendProfileSharedCaption => '此設定由推薦 / 趨勢 / 關聯時間軸共用。';

  @override
  String get trendProfileSharedCaptionDetail =>
      '此設定檔儲存在 storage.safe（trend.profile）中，推薦 / 趨勢 / 關聯時間軸的預設以及節點編輯器的「傾向/刺激程度」節點都會讀取它。';

  @override
  String get trendProfileDirNarrow => '窄';

  @override
  String get trendProfileDirWide => '寬';

  @override
  String get trendProfileDirNormal => '普通';

  @override
  String get trendProfileStimNone => '無限制';

  @override
  String trendProfileStimCapped(String emotions) {
    return '抑制$emotions';
  }

  @override
  String get trendProfileListSeparator => '、';

  @override
  String get trendProfileDirectivityTitle => '趨勢的傾向';

  @override
  String get trendProfileDirectivitySubtitle => '越窄，越不會顯示偏離喜歡類型的貼文。';

  @override
  String get trendProfileDirectivityDetail =>
      '與喜歡的類型/方向接近程度的門檻（窄 ⇄ 寬）。越窄，越會剔除偏離的貼文。';

  @override
  String get trendProfileShareTitle => '共用設定';

  @override
  String get trendProfileShareSubtitle => '將此設定用於推薦 / 趨勢 / 關聯時間軸';

  @override
  String get trendProfileShareDetail => '關閉後將停止作為時間軸預設套用（在節點中明確指定的部分仍然有效）';

  @override
  String get trendProfileStimulusTitle => '趨勢的刺激程度';

  @override
  String get trendProfileStimulusCaption => '各種情緒的上限。越靠近中心，抑制越強';

  @override
  String get trendProfileStimulusReset => '重設刺激程度';

  @override
  String get trendProfileEchoChamberWarning => '加強趨勢的傾向/刺激程度，可能更容易受到同溫層效應的影響。';

  @override
  String get trendProfileStimulusEstimate => '刺激程度目前是根據用詞傾向推測的。';

  @override
  String get trendProfileStimulusEstimateDetail => '刺激程度透過詞彙規則推測。';

  @override
  String get trendProfileTendencySaved => '已儲存趨勢的傾向/刺激程度';

  @override
  String get trendProfileSnsDefaultTitle => '交給 SNS 的設定';

  @override
  String get trendProfileSnsDefaultSubtitle => '開啟期間，裝置端不進行篩選';

  @override
  String get trendProfileAutoGenreTitle => '從你的操作中自動擷取';

  @override
  String get trendProfileAutoGenreSubtitle => '將你回應過的貼文中的特徵詞加入喜歡的類型';

  @override
  String get trendProfilePickFromActions => '從最近的操作中選擇喜歡的內容';

  @override
  String get trendProfileGenresTapToRemove => '喜歡的類型/方向（點按移除）';

  @override
  String get trendProfileNoneYet => '尚無';

  @override
  String get trendProfileAddGenreHint => '新增類型/關鍵字';

  @override
  String get trendProfileAddGenre => '新增類型';

  @override
  String trendProfileExamplesLabel(int allow, int deny) {
    return '範例（喜歡 $allow / 不喜歡 $deny，點按移除）';
  }

  @override
  String trendProfileExampleAllow(String label) {
    return '喜歡：$label';
  }

  @override
  String trendProfileExampleDeny(String label) {
    return '不喜歡：$label';
  }

  @override
  String get trendProfileDislikedTapToRemove => '不喜歡（點按移除）';

  @override
  String get trendProfileGenresSaved => '已儲存喜歡的類型/方向';

  @override
  String get trendProfilePickTitle => '從操作中選擇類型';

  @override
  String get trendProfilePickIntro =>
      '最近的操作依話題分組顯示。選擇卡片並歸入「喜歡」/「不喜歡」（也可向右/向左滑動）。';

  @override
  String trendProfilePickIntroDetail(int perPage) {
    String _temp0 = intl.Intl.pluralLogic(
      perPage,
      locale: localeName,
      other: '$perPage 則',
    );
    return '將最近的操作依相似話題歸類，從話題性最強的開始每次顯示 $_temp0（也可透過上方的標籤從外掛 / 便籤 / 清單選取）。點按卡片進行選擇，選好候選類型後點下方的「喜歡」/「不喜歡」（也可向右/向左滑動）。';
  }

  @override
  String userPageViewTitle(String tab) {
    return '$tab的顯示';
  }

  @override
  String get userPageViewClose => '關閉';

  @override
  String userPageViewSearchHint(String tab) {
    return '在此使用者的$tab中搜尋';
  }

  @override
  String get userPageViewSortLabel => '排序';

  @override
  String get userPageViewSortNewest => '最新優先';

  @override
  String get userPageViewSortOldest => '最舊優先';

  @override
  String get userPageViewSortReactions => '回應數';

  @override
  String get userPageViewSortTendency => '最符合傾向';

  @override
  String get userPageViewShowLabel => '顯示';

  @override
  String get userPageViewShowPinned => '置頂';

  @override
  String get userPageViewShowRenotes => '轉貼';

  @override
  String get userPageViewShowQuotes => '引用貼文';

  @override
  String get userPageViewShowDigest => '摘要';

  @override
  String get userPageViewTendencyLabel => '傾向 / 刺激程度';

  @override
  String get userPageViewDirectivityTitle => '傾向';

  @override
  String get userPageViewDirectivityNoGenres => '設定喜歡的類型後生效';

  @override
  String get userPageViewStimulusTitle => '刺激程度';

  @override
  String get userPageViewReset => '重設';

  @override
  String userPageViewCount(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total 則中顯示 $shown 則',
    );
    return '$_temp0';
  }

  @override
  String get userPageViewEmptyTitle => '沒有符合條件的貼文';

  @override
  String get userPageViewEmptyHint => '再次點擊分頁，變更或重設顯示設定';

  @override
  String get usersImageViewerBack => '返回';

  @override
  String get usersFollowRequestsTabRelevance => '相關性';

  @override
  String get usersFollowRequestsTabFollowing => '追蹤中';

  @override
  String get usersFollowRequestsTabOther => '其他';

  @override
  String get usersFollowRequestsTitle => '追蹤請求';

  @override
  String get usersReload => '重新載入';

  @override
  String get usersFollowRequestsEmpty => '沒有追蹤請求';

  @override
  String get usersFollowRequestsEmptyOther => '無';

  @override
  String get usersFollowRequestAccept => '允許';

  @override
  String get usersFollowRequestReject => '拒絕';

  @override
  String get usersFollowsTabFollowing => '追蹤中';

  @override
  String get usersFollowsTabFollowers => '追蹤者';

  @override
  String get usersFollowsTitle => '追蹤/追蹤者';

  @override
  String get usersFollowersEmpty => '沒有追蹤者';

  @override
  String get usersFollowingEmpty => '沒有追蹤中的使用者';

  @override
  String get usersPageTabNotes => '貼文';

  @override
  String get usersPageTabReplies => '回覆';

  @override
  String get usersPageTabQuotes => '引用';

  @override
  String get usersPageTabMedia => '媒體';

  @override
  String get usersPageTabClips => '便籤/Play';

  @override
  String get usersRestrictedTitle => '這是受限制的使用者';

  @override
  String get usersRestrictedHint => '點按「顯示」以顯示內容';

  @override
  String get usersMenuCopyLink => '複製連結';

  @override
  String get usersMenuAddToRasqList => '加入 RASQ 清單';

  @override
  String get usersMenuServerInfo => '伺服器資訊';

  @override
  String get usersMenuUnmute => '取消靜音';

  @override
  String get usersMenuMute => '靜音';

  @override
  String get usersMenuUnblock => '解除封鎖';

  @override
  String get usersMenuBlock => '封鎖';

  @override
  String get usersMenuReport => '檢舉';

  @override
  String usersBlockConfirmTitle(String name) {
    return '要封鎖 $name 嗎？';
  }

  @override
  String get usersBlockConfirmMessage => '將不再收到對方的追蹤、回應和回覆。';

  @override
  String get usersCancel => '取消';

  @override
  String usersReportConfirmTitle(String name) {
    return '要檢舉 $name 嗎？';
  }

  @override
  String get usersReportConfirmMessage => '將向伺服器管理員檢舉。';

  @override
  String get usersPostsEmpty => '沒有貼文';

  @override
  String get usersPinnedBadge => '置頂';

  @override
  String get usersClipsUnsupportedTitle => '便籤 / Play';

  @override
  String get usersClipsUnsupportedHint => '此 SNS 不支援便籤和 Play';

  @override
  String get usersClipsEmpty => '沒有公開的便籤或 Play';

  @override
  String get usersClipsHeader => '便籤';

  @override
  String usersClipNoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則',
    );
    return '$_temp0';
  }

  @override
  String get usersClipSubtitleSeparator => ' · ';

  @override
  String get usersNotFound => '該使用者似乎不存在。';

  @override
  String get vcSectionInvited => '邀請';

  @override
  String get vcSectionRecommended => '推薦';

  @override
  String get vcSectionUpcoming => '即將舉行';

  @override
  String get vcSectionTrending => '趨勢';

  @override
  String get vcSectionFollowing => '追蹤中';

  @override
  String vcSectionSettingsTooltip(String title) {
    return '$title設定';
  }

  @override
  String get vcSearchHint => '搜尋 ASTell / Swing';

  @override
  String get vcSearchRefineHint => '進一步篩選';

  @override
  String vcSearchTermChip(String term) {
    return '「$term」 ×';
  }

  @override
  String get vcSearchClear => '清除';

  @override
  String get vcCreateTooltip => '建立 ASTell';

  @override
  String get vcHomeLoadError => '無法取得 ASTell';

  @override
  String vcJoinedRoom(String title) {
    return '參與中：$title';
  }

  @override
  String vcJoinedPeers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人 · 點按開啟',
    );
    return '$_temp0';
  }

  @override
  String get vcConnecting => '正在連線…';

  @override
  String vcInvitedBy(String name) {
    return '$name 邀請了你 · 點按查看';
  }

  @override
  String get vcInviteDecline => '婉拒';

  @override
  String get vcRecommendedEmpty => '還沒有推薦的 ASTell';

  @override
  String get vcTrendingEmpty => '還沒有趨勢中的 ASTell';

  @override
  String get vcFollowingEmpty => '沒有追蹤使用者的 ASTell';

  @override
  String get vcSearchNoResults => '找不到';

  @override
  String get vcSearchNoResultsInSection => '此區塊中沒有';

  @override
  String vcSearchNoResultsFor(String query) {
    return '沒有符合「$query」的 ASTell / Swing';
  }

  @override
  String get vcTileOpen => '查看';

  @override
  String get vcBookmarkRemove => '從書籤中移除';

  @override
  String get vcBookmarkSave => '儲存到書籤';

  @override
  String get vcRemindCancel => '取消開始通知';

  @override
  String get vcRemindSet => '開始時通知';

  @override
  String get vcMenuTooltip => '選單';

  @override
  String vcScheduledAt(String when) {
    return '預定於 $when';
  }

  @override
  String get vcSummaryPrivate => '摘要不公開。';

  @override
  String get vcTileStripEmpty => '還沒有 ASTell';

  @override
  String get vcLinkCopied => '已複製連結';

  @override
  String get vcBookmarkSaved => '已儲存到書籤';

  @override
  String get vcBookmarkRemoved => '已從書籤中移除';

  @override
  String vcRemindRegistered(String when) {
    return '將在 $when 通知你';
  }

  @override
  String get vcRemindRemoved => '已取消通知';

  @override
  String get vcRemindUnavailable => '無法在此裝置上設定通知';

  @override
  String get vcRemindNotScheduled => '此房間沒有預定時間';

  @override
  String get vcMenuShareAsPost => '以貼文分享';

  @override
  String get vcMenuCopyLink => '複製連結';

  @override
  String get vcMenuStartNow => '立即開始';

  @override
  String get vcMenuBackToRoom => '返回房間';

  @override
  String get vcMenuJoin => '加入';

  @override
  String get vcMenuClose => '結束';

  @override
  String get vcMenuUnfollowHost => '取消追蹤主持人';

  @override
  String get vcMenuFollowHost => '追蹤主持人';

  @override
  String get vcMenuMute => '靜音';

  @override
  String get vcMenuReport => '檢舉';

  @override
  String vcUnfollowed(String name) {
    return '已取消追蹤 $name';
  }

  @override
  String vcFollowed(String name) {
    return '已追蹤 $name';
  }

  @override
  String vcReportWhatRoom(String title) {
    return '房間「$title」';
  }

  @override
  String vcMenuNotYet(String title, String action) {
    return '「$title」的操作（$action）將在 M5 後期推出';
  }

  @override
  String get vcCloseRoomTitle => '結束房間';

  @override
  String vcCloseScheduledBody(String title) {
    return '將取消「$title」的預定。已加入書籤或設定開始通知的人不會收到通知。';
  }

  @override
  String vcCloseRoomBody(String title) {
    return '將結束「$title」。參與中的成員將退出。';
  }

  @override
  String vcClosedScheduled(String title) {
    return '已取消「$title」的預定';
  }

  @override
  String vcClosedRoom(String title) {
    return '已結束「$title」';
  }

  @override
  String vcCloseFailed(String error) {
    return '無法結束：$error';
  }

  @override
  String get vcTileBack => '返回';

  @override
  String get vcReminderNotificationTitle => '已加入書籤的 ASTell 即將開始！';

  @override
  String vcReminderNotificationBody(String host, String title) {
    return '$host 的「$title」';
  }

  @override
  String vcShareTextScheduled(String title, String when) {
    return '「$title」將於 $when 舉行';
  }

  @override
  String vcShareTextOpen(String title) {
    return '「$title」正在進行中';
  }

  @override
  String get vcViewerPluginsTooltip => '全螢幕顯示外掛（準備中）';

  @override
  String vcViewerSharedBy(String name) {
    return '$name 分享';
  }

  @override
  String get vcViewerSave => '儲存';

  @override
  String get vcViewerSaveNotYet => '儲存功能準備中';

  @override
  String get vcViewerShare => '分享';

  @override
  String get vcViewerShareNotYet => '分享功能準備中';

  @override
  String get vcBarSpeaker => '揚聲器';

  @override
  String get vcBarMic => '麥克風';

  @override
  String get vcBarScreen => '螢幕分享';

  @override
  String get vcBarFullscreen => '全螢幕（分享框中有畫面時）';

  @override
  String get vcBarCaptions => '字幕（語音轉文字）';

  @override
  String vcCallConnectFailed(String error) {
    return '通話連線失敗：$error';
  }

  @override
  String get vcOpenNotFound => '找不到此房間（可能已結束，或連結有誤）';

  @override
  String get vcOpenFailed => '無法開啟房間';

  @override
  String get vcOpenGoHome => '前往 ASTell 首頁';

  @override
  String vcOpenHost(String name, String handle) {
    return '主持人：$name(@$handle)';
  }

  @override
  String get vcOpenRoom => '開啟房間';

  @override
  String get vcShareBlockDirect => '私訊貼文無法分享到 ASTell';

  @override
  String get vcShareBlockLocalOnly => '僅限本地的貼文無法分享到 ASTell';

  @override
  String get vcShareBlockUnknownVisibility => '無法確定公開範圍的貼文無法分享到 ASTell';

  @override
  String get vcShareBlockLimited => '限制了公開範圍的貼文無法分享到 ASTell';

  @override
  String get vcShares => '分享';

  @override
  String vcSharesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '分享 ($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcSharesShowAll => '查看全部分享';

  @override
  String get vcSharesEmpty => '在聊天中 📌 的內容會顯示在這裡。';

  @override
  String get vcShareActions => '分享操作';

  @override
  String get vcShareTranscriptSource => 'RASQ · 文字紀錄';

  @override
  String get vcUnpin => '取消置頂';

  @override
  String get vcYou => '你';

  @override
  String get vcNoDescription => '沒有說明。';

  @override
  String get vcReportReasonSpam => '垃圾訊息';

  @override
  String get vcReportReasonHarassment => '騷擾 / 辱罵';

  @override
  String get vcReportReasonIllegal => '違法 / 危險內容';

  @override
  String get vcReportReasonOther => '其他';

  @override
  String get vcJoinPolicyAnyone => '任何人';

  @override
  String get vcJoinPolicyAnyoneHint => '公開房間任何人都可以加入';

  @override
  String get vcJoinPolicyFollowers => '僅追蹤者';

  @override
  String get vcJoinPolicyFollowersHint => '用 RASQ 帳號追蹤你（主持人）的人';

  @override
  String get vcJoinPolicyFollowing => '僅你追蹤的人';

  @override
  String get vcJoinPolicyFollowingHint => '你追蹤的人';

  @override
  String get vcJoinPolicyMutual => '僅互相追蹤';

  @override
  String get vcJoinPolicyMutualHint => '與你互相追蹤的人';

  @override
  String get vcSharePolicyEveryone => '所有人';

  @override
  String get vcSharePolicyModerators => '僅版主';

  @override
  String vcShareContentWarning(String warning) {
    return '⚠ $warning（敏感內容）';
  }

  @override
  String vcSharePluginWant(String name) {
    return '想使用「$name」';
  }

  @override
  String get vcKindPost => '貼文';

  @override
  String get vcKindMedia => '媒體';

  @override
  String get vcKindVideo => '影片';

  @override
  String get vcKindLink => '連結';

  @override
  String get vcKindText => '文字';

  @override
  String get vcKindPlugin => '外掛';

  @override
  String get vcMediaInsecureContext => '網頁版通話僅在透過 https 開啟時可用';

  @override
  String get vcMediaPermissionDenied => '沒有麥克風（相機）權限。請在裝置設定中允許';

  @override
  String get vcMediaNoDevice => '找不到麥克風（相機）';

  @override
  String get vcMediaUnsupported => '此裝置無法使用';

  @override
  String vcMediaUnsupportedDetail(String detail) {
    return '此裝置無法使用（$detail）';
  }

  @override
  String get vcMediaMicClosed => '無法開啟已結束通話的麥克風';

  @override
  String get vcStreamNotConnected => '未連線至直播伺服器';

  @override
  String get vcStreamPublishFailed => '無法將影像上傳到直播伺服器';

  @override
  String get vcScreenSharingNotification => '正在分享螢幕';

  @override
  String get vcScreenPickTitle => '選擇要分享的畫面';

  @override
  String get vcScreenPickScreen => '整個螢幕';

  @override
  String get vcScreenPickWindow => '視窗';

  @override
  String get vcScreenPickCancel => '取消';

  @override
  String get vcScreenPickShare => '分享';

  @override
  String get vcNoticeAudioBlocked => '聲音已停止。點按螢幕即可播放';

  @override
  String vcNoticeCallFull(int cap) {
    return '通話已滿（最多 $cap 人）。如有直播，可透過直播收聽';
  }

  @override
  String get vcNoticeHoldWaiting => '請等待開始。正在播放等待音樂';

  @override
  String get vcNoticeStarted => '已開始';

  @override
  String get vcNoticeHoldIdle => '因為很安靜，正在播放等待音樂';

  @override
  String get vcShareClassImage => '圖片';

  @override
  String get vcShareClassFile => '檔案';

  @override
  String get vcShareClassTranscript => '文字紀錄';

  @override
  String get vcShareStyleCards => '卡片（橫向滑動）';

  @override
  String get vcShareStyleList => '列表（舊版）';

  @override
  String get vcTermsRequired => '需要同意使用條款（可在 ASTell 頂部的提示中同意）';

  @override
  String get vcClosedByModeration => '房間已被營運方關閉';

  @override
  String get vcClosedByHost => '主持人已結束房間';

  @override
  String get vcKickedBanned => '你已被此房間封鎖';

  @override
  String get vcKickedSanctioned => '由於帳號處置，你已被移出';

  @override
  String get vcKickedByModerator => '版主已將你移出房間';

  @override
  String vcShareHeld(String seconds) {
    return '審查中：將在 $seconds 秒後判定並傳送（帳號處置）';
  }

  @override
  String vcShareRejected(String source) {
    return '審查未通過（$source）。此發言未被傳送';
  }

  @override
  String get vcNotInRoom => '你不在房間中';

  @override
  String vcStreamReceiveFailed(String error) {
    return '無法接收影像：$error';
  }

  @override
  String get vcStreamBlockedByScreenShare => '螢幕分享期間無法開始直播（請先停止分享）';

  @override
  String vcStreamStartFailed(String error) {
    return '無法開始直播：$error';
  }

  @override
  String vcStreamClearFailed(String error) {
    return '無法清除直播標記：$error';
  }

  @override
  String get vcScreenShareBlockedByStream => '直播期間無法開始螢幕分享（請先停止直播）';

  @override
  String vcScreenShareStartFailed(String error) {
    return '無法開始螢幕分享：$error';
  }

  @override
  String get vcStreamUnavailable => '直播尚無法使用（未設定直播伺服器）';

  @override
  String vcStreamForbidden(String message) {
    return '不允許（$message）';
  }

  @override
  String get vcTtsNotConfigured => '未設定朗讀後端（CENTRAL_TTS_URL）';

  @override
  String get vcLoginRequired => '請登入 RASQ 帳號';

  @override
  String vcCreateUninvite(String name) {
    return '取消邀請 $name';
  }

  @override
  String vcCreateInvite(String name) {
    return '邀請 $name';
  }

  @override
  String get vcCreateCancel => '取消';

  @override
  String get vcCreateShareAfterOn => '建立後發文分享（開）';

  @override
  String get vcCreateShareAfter => '建立後發文分享';

  @override
  String vcCreateScheduled(String title, String when) {
    return '已將「$title」預約在 $when';
  }

  @override
  String get vcCreateScheduleInPast => '預定時間必須晚於目前時間';

  @override
  String vcCreateGenresMax(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '最多可新增 $max 個類型',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateTitleRequired => '請輸入標題';

  @override
  String vcCreateInviteFailed(String error) {
    return '無法傳送邀請：$error';
  }

  @override
  String vcCreateFailed(String error) {
    return '無法建立：$error';
  }

  @override
  String get vcCreateSearchAdd => '搜尋並新增';

  @override
  String get vcCreateHandleHint => '@handle（RASQ 帳號）';

  @override
  String vcCreateHandleNotFound(String handle) {
    return '找不到：$handle';
  }

  @override
  String get vcCreateAddInvitee => '加入邀請';

  @override
  String get vcCreateTitleHint => '標題';

  @override
  String get vcCreateInviteFollowers => '邀請追蹤者';

  @override
  String vcCreateInviteFollowersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '邀請追蹤者（$count）',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateWelcomeToggle => '加入時顯示歡迎訊息';

  @override
  String get vcCreateWelcomeHint => '設定歡迎訊息..';

  @override
  String vcCreateGenresLabel(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '選擇類型（最多 $max 個）',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateGenreHint => '輸入類型';

  @override
  String get vcCreateGenreAdd => '新增類型';

  @override
  String get vcCreateSchedule => '預約開始時間';

  @override
  String get vcCreateScheduleCaption => '預約期間，在你進入之前其他人無法進入。';

  @override
  String get vcCreateScheduleCaptionDetail =>
      '預約期間，在你（或管理員）進入之前其他人無法參加。可從「即將開始」區塊和分享連結訂閱開始通知。';

  @override
  String get vcCreateSummaryHint => '簡要概述（選填；留空則自動產生）';

  @override
  String get vcCreateMicAfterCreate => '麥克風（建立後切換）';

  @override
  String get vcCreateScheduleButton => '預約';

  @override
  String get vcCreateButton => '建立';

  @override
  String get vcRoomHostPresent => '在場';

  @override
  String get vcRoomHostBeforeStart => '未開始';

  @override
  String get vcRoomHostAbsent => '不在';

  @override
  String vcRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 人參與',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomMembersHostOnly => '除了主持人以外還沒有其他人';

  @override
  String get vcRoomMembersNone => '還沒有人';

  @override
  String vcRoomMembersRest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '等 $count 人',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomScreenShown => '正在分享框中顯示';

  @override
  String get vcRoomScreenShow => '顯示螢幕分享';

  @override
  String vcRoomNotYet(String what) {
    return '$what正在準備中';
  }

  @override
  String get vcRoomDeviceSettingsTitle => 'ASTell 設定（此裝置）';

  @override
  String get vcRoomEditBar => '編輯底部按鈕排列';

  @override
  String get vcRoomEditBarSubtitle => '排序 / 顯示 / 隱藏 / 新增外掛按鈕';

  @override
  String get vcRoomAutoShareLabel => '自動將聊天內容顯示在分享欄中（即使未置頂）';

  @override
  String get vcRoomShareStyleLabel => '分享欄顯示方式';

  @override
  String get vcRoomAutoPlayLabel => '自動播放';

  @override
  String get vcRoomAutoPlayScreen => '螢幕分享開始時顯示在分享框中';

  @override
  String get vcRoomHoldMusicLabel => '等待音樂';

  @override
  String get vcRoomHoldMusicDevice => '播放等待音樂（此裝置）';

  @override
  String get vcRoomHoldMusicSourceLabel => '等待音樂的音源';

  @override
  String get vcRoomHoldMusicSourceAstronomies =>
      'We：Astronomies on the Blue Planet';

  @override
  String get vcRoomHoldMusicSourceClassic => '經典等待音樂';

  @override
  String get vcRoomHoldMusicVolume => '等待音樂音量';

  @override
  String vcRoomHoldMusicVolumeValue(int percent) {
    return '$percent%';
  }

  @override
  String get vcRoomDeviceSettingsCaption => '房間設定可在加入後透過房間的齒輪變更（房主）。';

  @override
  String get vcRoomDeviceSettingsCaptionDetail =>
      '每個房間的設定（可加入的人、朗讀等）可在加入後透過房間的齒輪變更（房主）。';

  @override
  String get vcRoomClose => '關閉';

  @override
  String get vcRoomShare => '分享';

  @override
  String get vcRoomHost => '主持人';

  @override
  String get vcRoomMembers => '參與成員';

  @override
  String get vcRoomLocked => '營運方已停止新的進入。';

  @override
  String get vcRoomLockedDetail => '營運方已停止新進入（D-151）。';

  @override
  String get vcRoomRemindOn => '將在開始時通知你';

  @override
  String get vcRoomWaitForHost => '主持人開始之前無法加入';

  @override
  String get vcRoomRemindOff => '取消通知';

  @override
  String get vcRoomSummary => '摘要';

  @override
  String get vcRoomSummaryPrivate => '此房間未公開摘要。';

  @override
  String vcRoomWelcome(String message) {
    return '歡迎：$message';
  }

  @override
  String get vcRoomMicAfterJoin => '麥克風（加入後切換）';

  @override
  String get vcRoomCaptions => '字幕';

  @override
  String get vcRoomJoin => '加入';

  @override
  String get vcRoomSettings => '設定';

  @override
  String get vcRoomTabHome => '首頁';

  @override
  String get vcRoomTabChat => '聊天';

  @override
  String get vcRoomTabToc => '目錄';

  @override
  String get vcRoomTabRoom => '房間';

  @override
  String get vcRoomLeft => '已退出';

  @override
  String get vcRoomLeave => '退出';

  @override
  String get vcRoomStreamingScreen => '正在直播螢幕';

  @override
  String get vcRoomStreamingCamera => '正在用相機直播';

  @override
  String get vcRoomStopSharing => '停止分享';

  @override
  String get vcRoomStopStream => '停止直播';

  @override
  String get vcRoomSpeakerUnmute => '取消揚聲器靜音';

  @override
  String get vcRoomSpeakerMute => '揚聲器靜音';

  @override
  String get vcRoomMutedByModerator => '已被版主靜音';

  @override
  String get vcRoomMicOpening => '正在準備麥克風（點按取消）';

  @override
  String get vcRoomMicOff => '關閉麥克風';

  @override
  String get vcRoomMicOn => '開啟麥克風';

  @override
  String get vcRoomScreenShareOff => '關閉螢幕分享';

  @override
  String get vcRoomFullscreen => '全螢幕';

  @override
  String get vcRoomCaptionsOff => '關閉字幕';

  @override
  String get vcRoomCaptionsOn => '開啟字幕';

  @override
  String get vcRoomShareAsLinkLimited => '此貼文限制了公開範圍，將以連結形式分享';

  @override
  String vcRoomShareAsLinkFailed(String error) {
    return '無法取得貼文，將以連結形式分享：$error';
  }

  @override
  String vcRoomPickFileFailed(String error) {
    return '無法選擇檔案：$error';
  }

  @override
  String get vcRoomStream => '直播';

  @override
  String vcRoomLiveCardTitle(String kind, String title) {
    return '$kind:$title';
  }

  @override
  String vcRoomPeerScreen(String name) {
    return '$name 的螢幕';
  }

  @override
  String vcRoomPeerScreenTitled(String name, String title) {
    return '$name 的螢幕 — $title';
  }

  @override
  String get vcRoomAllShares => '全部分享';

  @override
  String get vcRoomSettingsTitle => 'ASTell 設定';

  @override
  String get vcRoomModerationLabel => '管理（房主）';

  @override
  String get vcRoomJoinPolicyLabel => '可以加入的人';

  @override
  String get vcRoomSharePolicyLabel => '可以分享（在聊天中發布）的人';

  @override
  String vcRoomModeratorsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '版主（$count）— 從成員的「…」中新增',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomRemoveModerator => '移除版主';

  @override
  String get vcRoomTendencyLabel => '發言傾向';

  @override
  String get vcRoomTendencyFilter => '拒絕搗亂者進入（測試中）';

  @override
  String get vcRoomTendencyCaption => '開啟後，被判定為有敵意的人將無法進入。判定仍為暫時性的。';

  @override
  String get vcRoomTendencyCaptionDetail =>
      '正式版將使用 rasq-judge 的 GoEmotion（發言的情緒傾向），由於需要訓練，目前使用伺服器的模擬判定（僅顯示名稱中含有 hostile 或日語中意為「搗亂者」的詞的人被視為有敵意）。開啟後，被判定為有敵意的人將無法進入。可從成員列的「…」中查看判定結果。';

  @override
  String get vcRoomHostStreamLabel => '直播（主持人）';

  @override
  String get vcRoomStreamCamera => '用相機直播';

  @override
  String get vcRoomStreamScreen => '直播螢幕';

  @override
  String get vcRoomStreamScreenIos => 'iPhone / iPad 僅限此 App 的畫面（不會顯示其他 App）';

  @override
  String get vcRoomHostStreamCaption => '直播影像和聲音。無法加入通話的人也可以透過直播收聽。';

  @override
  String vcRoomHostStreamCaptionDetail(int cap) {
    return '將影像和麥克風上傳到直播伺服器（LiveKit）。參與者在保持通話聲音的同時可觀看影像，無法加入通話的人（第 $cap 人之後）透過直播收聽你的聲音。';
  }

  @override
  String get vcRoomHoldMusicRoom => '允許在此房間播放等待音樂（房主）';

  @override
  String get vcRoomHoldMusicCaption => '在等待開始期間，或一段時間沒人說話時播放。';

  @override
  String vcRoomHoldMusicCaptionDetail(int minutes) {
    return '在等待預定開始期間，以及所有人都關閉麥克風（且沒有螢幕分享 / 直播）、聊天 $minutes 分鐘以上沒有動靜時播放。有人開始說話或聊天有新訊息時停止。';
  }

  @override
  String get vcRoomTts => '朗讀';

  @override
  String get vcRoomTtsUnavailable => '朗讀（無法使用）';

  @override
  String vcRoomTtsDetail(String model) {
    return '朗讀（$model，預設語音）';
  }

  @override
  String vcRoomTtsDetailUnavailable(String model) {
    return '朗讀（$model，預設語音）— 伺服器未設定';
  }

  @override
  String get vcRoomTtsNone => '不朗讀';

  @override
  String get vcRoomTtsCaptionOwner => '朗讀語音在伺服器上產生（App 內播放準備中）。';

  @override
  String get vcRoomTtsCaptionGuest => '朗讀語音由主持人選擇。';

  @override
  String get vcRoomTtsCaptionOwnerDetail =>
      '聊天和分享的朗讀在 Central 端合成（裝置端播放將在日後支援）。';

  @override
  String get vcRoomDiagnosticsLabel => '連線狀態（開發者用）';

  @override
  String get vcRoomDiagnosticsOpen => '查看通話 / 直播連線';

  @override
  String get vcRoomDiagnosticsOpenSubtitle => 'ICE 狀態、候選、收發量、接收中的軌道';

  @override
  String get vcRoomDiagnosticsTitle => '連線狀態';

  @override
  String vcRoomHostStreamTitle(String name) {
    return '$name 的直播';
  }

  @override
  String get vcRoomPostViewNotYet => '顯示此貼文（未安裝對應的 SNS 外掛）';

  @override
  String get vcRoomOpen => '開啟';

  @override
  String get vcRoomDelete => '刪除';

  @override
  String get vcRoomCopied => '已複製';

  @override
  String vcRoomReportWhatShare(String headline) {
    return '分享「$headline」';
  }

  @override
  String get vcRoomPinToFrame => '在分享框中顯示';

  @override
  String get vcRoomUnfollow => '取消追蹤';

  @override
  String get vcRoomFollow => '追蹤';

  @override
  String get vcRoomUnmute => '取消靜音';

  @override
  String get vcRoomModUnmute => '取消對所有人的靜音';

  @override
  String get vcRoomModMute => '對所有人靜音';

  @override
  String get vcRoomKick => '踢出';

  @override
  String get vcRoomMakeModerator => '設為版主';

  @override
  String get vcRoomShowTendency => '查看發言傾向（測試中）';

  @override
  String get vcRoomUnblock => '解除封鎖';

  @override
  String get vcRoomBlock => '封鎖';

  @override
  String get vcRoomReport => '檢舉';

  @override
  String vcRoomTendencyResult(String name, String source, String summary) {
    return '$name 的發言傾向（$source）：$summary';
  }

  @override
  String vcRoomTendencyResultHostile(
    String name,
    String source,
    String summary,
  ) {
    return '$name 的發言傾向（$source）：$summary — 有敵意';
  }

  @override
  String vcRoomUnblocked(String name) {
    return '已解除封鎖 $name';
  }

  @override
  String vcRoomBlocked(String name) {
    return '已封鎖 $name（隱藏其發言，且無法進入你的房間）';
  }

  @override
  String vcRoomActionFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get vcRoomPinToShares => '置頂到分享欄';

  @override
  String vcRoomReportWhatChat(String name) {
    return '$name 的發言';
  }

  @override
  String get vcRoomShowSummary => '在預覽中顯示摘要';

  @override
  String get vcRoomAutoGenre => '自動選擇類型';

  @override
  String get vcRoomEditAutoGenres => '編輯自動選擇的類型';

  @override
  String get vcRoomGenres => '類型';

  @override
  String get vcRoomChatEmpty => '說話內容的文字紀錄以及聊天、分享會顯示在這裡。';

  @override
  String vcRoomChatHiddenBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已隱藏 $count 則來自已封鎖使用者的發言',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomTyping => '正在輸入…';

  @override
  String get vcRoomDraft => '草稿';

  @override
  String get vcRoomTypingLabel => '正在輸入';

  @override
  String get vcRoomChatActions => '聊天操作';

  @override
  String vcRoomTocStart(String title) {
    return '開始：$title';
  }

  @override
  String vcRoomTocShared(String name, String kind, String headline) {
    return '$name 分享了 $kind:$headline';
  }

  @override
  String get vcRoomTocCaption => '分享和文字紀錄的分隔。';

  @override
  String vcRoomMembersWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '參與成員（$count）',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomModerator => '版主';

  @override
  String get vcRoomCustomPlugins => '自訂外掛';

  @override
  String vcRoomUpdateFailed(String error) {
    return '無法更新設定：$error';
  }

  @override
  String get vcRoomShareAction => '分享';

  @override
  String get vcRoomSendDone => '完成傳送';

  @override
  String vcRoomPeerScreenTap(String name) {
    return '$name 的螢幕（點按全螢幕）';
  }

  @override
  String get vcRoomPinnedSharesEmpty => '置頂的分享會顯示在這裡';

  @override
  String vcRoomCompactShare(String headline) {
    return '分享：$headline';
  }

  @override
  String get vcRoomNoTranscripts => '還沒有文字紀錄';

  @override
  String get vcRoomTranscriptsDisabled => '文字紀錄已停用（摘要不公開）';

  @override
  String get vcRoomSharesCollapse => '收合分享';

  @override
  String get vcRoomSharesExpand => '顯示全部分享';

  @override
  String vcRoomSharedByPinned(String name) {
    return '$name 分享 · 📌';
  }

  @override
  String vcRoomSharedByAuto(String name) {
    return '$name 分享 · 自動顯示';
  }

  @override
  String vcRoomTranscriptMetaPinned(String name, String time) {
    return '$name · $time · 📌';
  }

  @override
  String vcRoomTranscriptMetaAuto(String name, String time) {
    return '$name · $time · 自動顯示';
  }

  @override
  String get vcRoomMuted => '已靜音';

  @override
  String get vcRoomScreenFrameActions => '分享框操作';

  @override
  String vcRoomMemberSelf(String name) {
    return '$name（你）';
  }

  @override
  String get vcRoomForceMuted => '強制靜音';

  @override
  String get vcRoomMemberActions => '成員操作';

  @override
  String get vcRoomDiagnosticsLogHint =>
      '也會以「astell call:」「astell stream:」輸出到瀏覽器 / Xcode 的記錄中。';

  @override
  String get vcRoomCopy => '複製';

  @override
  String vcRoomBansLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '封鎖（$count）— 從成員列的「…」中操作',
    );
    return '$_temp0';
  }

  @override
  String vcRoomBansLoadFailed(String error) {
    return '無法讀取封鎖列表：$error';
  }

  @override
  String get vcRoomUnban => '解除封鎖';

  @override
  String vcRoomReportBody(String what) {
    return '檢舉$what。RASQ 將進行審核。';
  }

  @override
  String get vcRoomReportNoteHint => '補充說明（選填）';

  @override
  String vcRoomReportFailed(String error) {
    return '無法檢舉：$error';
  }

  @override
  String get vcRoomReportSubmit => '檢舉';

  @override
  String get vcRoomReported => '已檢舉。將進行審核';

  @override
  String vcRoomLiveBy(String name, String kind) {
    return '$name 正在$kind';
  }
}
