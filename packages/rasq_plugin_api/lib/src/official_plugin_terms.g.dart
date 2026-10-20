// 生成: tool/legal/build_legal.py(手で直さない)。正本は assets/legal/plugins/<pluginId>.md。
// 公式の SNS プラグインの規約(マニフェストの termsOfService、初回ログインの前に出す)。
// 参考訳は assets/legal/<言語>/plugins/<pluginId>.md → `<名前>TermsLocales`(マニフェストの locales、日本語が正本)。

import 'manifest_locales.dart';

/// `rasq.official.bluesky` の規約。
const officialBlueskyTerms = r'''
## Bluesky プラグインの規約

このプラグインは、RASQ の運営者が提供する公式プラグインです。RASQ から Bluesky（AT Protocol）のサーバーに接続するために使います。この規約は、RASQ の利用規約とプライバシーポリシーに加えて適用します。

### 第1条　接続先の規約

1. このプラグインで行う投稿、閲覧、フォロー、いいね、チャット等には、Bluesky と、アカウントがあるサーバー（PDS）の利用規約とポリシーが適用されます。接続先の規約を確認し、守って利用してください。
2. 接続先のサービスは、RASQ の運営者とは別の事業者が運営しています。RASQ の運営者は、接続先のサービスの継続、内容、データの扱いを保証しません。
3. このプラグインから行う通報は、Bluesky のモデレーションサービスに送られます。

### 第2条　ログインと権限

1. ログインには、ハンドル（またはメールアドレス）と、Bluesky の設定画面で作ったアプリパスワードを使います。アカウントのパスワードではなく、アプリパスワードを使ってください。
2. アプリパスワードは、ログインの手続（bsky.social またはアカウントのサーバー）に送るだけで、保存しません。ログインすると発行されるトークンを保存して、以後の操作に使います。
3. このプラグインは、タイムラインとフィードの閲覧、フィードの保存の設定、投稿の作成と削除、いいね、リポスト、フォロー、ブロック、ミュート、通知と既読、検索、画像と動画のアップロード、チャット（ダイレクトメッセージ）、通報を行います。
4. これらの操作は、利用者が RASQ の画面で操作したときに行います。RAi に操作を頼んだ場合も、状態を変える操作は、内容を示して利用者が確定してから行います。
5. アプリパスワードは、Bluesky の設定画面からいつでも削除できます。削除すると、このプラグインからそのアカウントを使えなくなります。

### 第3条　通信とデータ

1. このプラグインは、アカウントがあるサーバー（PDS）と、ログインのための bsky.social と通信します。チャットは Bluesky のチャットサービスを経由します。投稿、画像、動画、チャットの本文は、端末から接続先へ直接送ります。
2. トークンは、端末の OS の安全な保存領域に保存します。次の機能を利用者が選んだ場合に限り、トークンが RASQ のサーバーへ送られます。
   - 端末間の共有：端末で暗号化して送ります。RASQ の運営者は復号できません。
   - Web 版の保管庫：RASQ のサーバーの鍵で暗号化して保存します。
3. アカウントページへの投稿の表示を選んだ場合は、トークンではなく、アカウントの識別子（DID）とハンドルだけを RASQ のサーバーへ送ります。RASQ のサーバーは、公開の情報から投稿を取得します。
4. RASQ アカウントにログインしている場合、アカウントの束ね表示のために、SNS の種類、サーバー、ハンドル、表示名、アイコンの URL を RASQ のサーバーへ送ります。トークンは送りません。
5. プラグインの通信の形の診断を有効にした場合は、通信先のパスと項目名を RASQ のサーバーへ送ります。値は送りません。この診断は任意です。
6. 詳しい扱いは、RASQ のプライバシーポリシーの第4項に示します。

### 第4条　再配布

このプラグインは RASQ アプリの一部として提供します。プラグインのファイルを RASQ アプリから取り出して、単独で再配布することはできません。プラグインに含まれる第三者のソフトウェアは、それぞれのライセンスに従います。ライセンスは「ヘルプ、法的表示」の画面で確認できます。

### 第5条　変更

このプラグインの機能、権限、通信先を広げる変更をするときは、RASQ のプラグインストアの利用条件に従い、変更の内容を示して改めて確認します。
''';

/// `rasq.official.bluesky` の規約の参考訳(マニフェストの `locales.<言語>.termsOfService`)。
const officialBlueskyTermsLocales = ManifestLocales(byTag: {
  'en': {'termsOfService': r'''
> **Reference translation.** This is a reference translation provided for convenience. The Japanese version is the official text, and if there is any difference between them, the Japanese version governs.

## Bluesky Plugin Terms

This plugin is an official plugin provided by the Operator of RASQ. It is used to connect from RASQ to Bluesky (AT Protocol) servers. These terms apply in addition to the RASQ Terms of Use and Privacy Policy.

### Article 1　Terms of the Connected Service

1. Posting, viewing, following, likes, chat, and other activities performed with this plugin are subject to the terms of use and policies of Bluesky and of the server (PDS) where your account is hosted. Please check and comply with the terms of the connected service.
2. The connected service is operated by a business separate from the Operator of RASQ. The Operator of RASQ does not guarantee the continuity, content, or data handling of the connected service.
3. Reports made from this plugin are sent to Bluesky's moderation service.

### Article 2　Login and Permissions

1. To log in, use your handle (or email address) and an app password created on Bluesky's settings screen. Please use an app password, not your account password.
2. The app password is only sent to the login procedure (bsky.social or your account's server) and is not stored. The token issued upon login is stored and used for subsequent operations.
3. This plugin performs viewing of the Timeline and feeds, settings for saving feeds, creating and deleting posts, likes, reposts, following, blocking, muting, notifications and marking as read, search, uploading images and videos, chat (direct messages), and reporting.
4. These operations are performed when the user operates them on the RASQ screen. Even when you ask RAi to perform an operation, operations that change state are performed after the content is shown and the user confirms it.
5. You can delete the app password at any time from Bluesky's settings screen. Once deleted, that account can no longer be used from this plugin.

### Article 3　Communications and Data

1. This plugin communicates with the server (PDS) where your account is hosted and with bsky.social for login. Chat goes through Bluesky's chat service. The body text of posts, images, videos, and chats is sent directly from the device to the connected service.
2. Tokens are stored in the secure storage area of the device's OS. Only if the user chooses the following features are tokens sent to RASQ servers.
   - Sharing between devices: sent encrypted on the device. The Operator of RASQ cannot decrypt them.
   - Web version vault: stored encrypted with the key of the RASQ server.
3. If you choose to display posts on your account page, only the account identifier (DID) and handle, not the token, are sent to RASQ servers. RASQ servers retrieve posts from public information.
4. If you are logged in to a RASQ account, the type of SNS, server, handle, display name, and icon URL are sent to RASQ servers for the bundled account display. Tokens are not sent.
5. If you enable diagnosis of the shape of the plugin's communications, the destination paths and field names are sent to RASQ servers. Values are not sent. This diagnosis is optional.
6. Details of handling are set out in Section 4 of the RASQ Privacy Policy.

### Article 4　Redistribution

This plugin is provided as part of the RASQ app. You may not extract the plugin's files from the RASQ app and redistribute them on their own. Third-party software included in the plugin is subject to its respective licenses. The licenses can be checked on the "Help, Legal" screen.

### Article 5　Changes

When making changes that expand this plugin's features, permissions, or communication destinations, the Operator will follow the RASQ Plugin Store terms of use, show the details of the changes, and ask for confirmation again.
'''},
  'zh': {'termsOfService': r'''
> **参考译文。** 本文是为方便阅读而提供的参考译文。正式文本为日文版，如两者内容有任何出入，以日文版为准。

## Bluesky插件条款

本插件是由RASQ的运营者提供的官方插件，用于从RASQ连接到Bluesky（AT Protocol）的服务器。本条款在RASQ的使用条款和隐私政策之外另行适用。

### 第1条　连接对象的条款

1. 通过本插件进行的发帖、浏览、关注、点赞、聊天等，适用Bluesky以及账号所在服务器（PDS）的使用条款和政策。请确认并遵守连接对象的条款。
2. 连接对象的服务由不同于RASQ运营者的其他经营者运营。RASQ的运营者不保证连接对象服务的持续性、内容及数据的处理方式。
3. 通过本插件进行的举报，将发送至Bluesky的审核服务。

### 第2条　登录与权限

1. 登录时，使用用户名（或电子邮件地址）以及在Bluesky设置画面中创建的应用密码。请使用应用密码，而非账号的密码。
2. 应用密码仅发送至登录程序（bsky.social或账号所在的服务器），不予保存。保存登录后发行的令牌，并用于此后的操作。
3. 本插件进行以下操作：浏览时间线和信息流、设置信息流的保存、创建和删除帖子、点赞、转发、关注、屏蔽、静音、通知与已读、搜索、上传图片和视频、聊天（私信）、举报。
4. 上述操作在用户于RASQ画面中进行操作时执行。即使委托RAi进行操作，改变状态的操作也会在展示内容并由用户确定后才执行。
5. 应用密码可随时从Bluesky的设置画面中删除。删除后，将无法通过本插件使用该账号。

### 第3条　通信与数据

1. 本插件与账号所在的服务器（PDS）以及用于登录的bsky.social进行通信。聊天经由Bluesky的聊天服务。帖子、图片、视频、聊天的正文从设备直接发送至连接对象。
2. 令牌保存在设备操作系统的安全存储区域中。仅在用户选择以下功能时，令牌才会被发送至RASQ的服务器。
   - 设备间共享：在设备上加密后发送。RASQ的运营者无法解密。
   - 网页版保管库：以RASQ服务器的密钥加密后保存。
3. 选择在账号页面上显示帖子时，仅将账号的标识符（DID）和用户名发送至RASQ的服务器，而不发送令牌。RASQ的服务器从公开信息中获取帖子。
4. 登录RASQ账号时，为进行账号的合并显示，将SNS的种类、服务器、用户名、显示名称、头像的URL发送至RASQ的服务器。不发送令牌。
5. 启用插件通信形态的诊断时，将通信对象的路径和项目名称发送至RASQ的服务器。不发送值。此诊断为可选项。
6. 详细的处理方式见RASQ隐私政策第4项。

### 第4条　再分发

本插件作为RASQ应用的一部分提供。不得将插件文件从RASQ应用中取出并单独再分发。插件中包含的第三方软件遵从各自的许可证。许可证可在“帮助、法律声明”画面中确认。

### 第5条　变更

对本插件的功能、权限、通信对象进行扩大的变更时，将依照RASQ插件商店的使用条件，展示变更内容并重新进行确认。
'''},
  'zh-hant': {'termsOfService': r'''
> **參考譯文。** 本文是為方便閱讀而提供的參考譯文。正式文本為日文版，如兩者內容有任何出入，以日文版為準。

## Bluesky 外掛條款

本外掛是由 RASQ 營運者提供的官方外掛，用於從 RASQ 連線至 Bluesky（AT Protocol）的伺服器。本條款於 RASQ 使用條款及隱私權政策之外另行適用。

### 第1條　連線目標的條款

1. 透過本外掛進行的貼文、瀏覽、追蹤、喜歡、聊天等，適用 Bluesky 及帳號所在伺服器（PDS）的使用條款與政策。請確認並遵守連線目標的條款。
2. 連線目標的服務由不同於 RASQ 營運者的業者營運。RASQ 營運者不保證連線目標服務的持續性、內容及資料的處理方式。
3. 從本外掛提出的檢舉，會傳送至 Bluesky 的審核服務。

### 第2條　登入與權限

1. 登入時使用帳號代稱（或電子郵件地址），以及在 Bluesky 設定畫面中建立的應用程式密碼。請使用應用程式密碼，而非帳號的密碼。
2. 應用程式密碼僅傳送至登入程序（bsky.social 或帳號所在的伺服器），不予儲存。登入後會儲存所發行的權杖，並用於之後的操作。
3. 本外掛會進行時間軸與動態的瀏覽、動態的儲存設定、貼文的建立與刪除、喜歡、轉發、追蹤、封鎖、靜音、通知與已讀、搜尋、圖片與影片的上傳、聊天（私人訊息）、檢舉。
4. 上述操作於使用者在 RASQ 畫面上進行操作時執行。即使委託 RAi 進行操作，會改變狀態的操作也會在顯示內容並由使用者確定後才執行。
5. 應用程式密碼可隨時從 Bluesky 的設定畫面刪除。刪除後，即無法再透過本外掛使用該帳號。

### 第3條　通訊與資料

1. 本外掛與帳號所在的伺服器（PDS）及用於登入的 bsky.social 通訊。聊天經由 Bluesky 的聊天服務。貼文、圖片、影片、聊天的內文，從裝置直接傳送至連線目標。
2. 權杖儲存於裝置作業系統的安全儲存區。僅在使用者選擇下列功能時，權杖才會傳送至 RASQ 的伺服器。
   - 跨裝置共用：在裝置上加密後傳送。RASQ 營運者無法解密。
   - 網頁版的保管庫：以 RASQ 伺服器的金鑰加密後儲存。
3. 選擇在帳號頁面顯示貼文時，不傳送權杖，僅將帳號的識別碼（DID）與帳號代稱傳送至 RASQ 的伺服器。RASQ 的伺服器從公開資訊取得貼文。
4. 已登入 RASQ 帳號時，為了帳號的整合顯示，會將 SNS 的種類、伺服器、帳號代稱、顯示名稱、頭像的網址傳送至 RASQ 的伺服器。不傳送權杖。
5. 啟用外掛通訊形式的診斷時，會將通訊目標的路徑與項目名稱傳送至 RASQ 的伺服器，不傳送值。此診斷為選用。
6. 詳細的處理方式，載於 RASQ 隱私權政策第4項。

### 第4條　再散布

本外掛作為 RASQ 應用程式的一部分提供。不得將外掛的檔案從 RASQ 應用程式中取出並單獨再散布。外掛所包含的第三方軟體，依其各自的授權。授權可在「說明、法律聲明」畫面中確認。

### 第5條　變更

對本外掛進行擴大功能、權限、通訊目標的變更時，會依 RASQ 外掛商店的使用條件，顯示變更內容並重新確認。
'''},
  'ko': {'termsOfService': r'''
> **참고 번역.** 이 문서는 편의를 위해 제공하는 참고 번역입니다. 정식 문서는 일본어판이며, 내용에 차이가 있는 경우 일본어판이 우선합니다.

## Bluesky 플러그인 약관

이 플러그인은 RASQ의 운영자가 제공하는 공식 플러그인입니다. RASQ에서 Bluesky(AT Protocol) 서버에 접속하기 위해 사용합니다. 이 약관은 RASQ의 이용약관과 개인정보처리방침에 더하여 적용됩니다.

### 제1조　접속처의 약관

1. 이 플러그인으로 하는 게시, 열람, 팔로우, 좋아요, 채팅 등에는 Bluesky와 계정이 있는 서버(PDS)의 이용약관과 정책이 적용됩니다. 접속처의 약관을 확인하고 준수하여 이용해 주십시오.
2. 접속처의 서비스는 RASQ의 운영자와는 다른 사업자가 운영합니다. RASQ의 운영자는 접속처 서비스의 지속, 내용, 데이터 처리를 보증하지 않습니다.
3. 이 플러그인에서 하는 신고는 Bluesky의 모더레이션 서비스로 전송됩니다.

### 제2조　로그인과 권한

1. 로그인에는 핸들(또는 이메일 주소)과 Bluesky 설정 화면에서 만든 앱 비밀번호를 사용합니다. 계정 비밀번호가 아니라 앱 비밀번호를 사용해 주십시오.
2. 앱 비밀번호는 로그인 절차(bsky.social 또는 계정의 서버)에 전송할 뿐 저장하지 않습니다. 로그인하면 발행되는 토큰을 저장하여 이후의 조작에 사용합니다.
3. 이 플러그인은 타임라인과 피드 열람, 피드 저장 설정, 게시물 작성과 삭제, 좋아요, 리포스트, 팔로우, 차단, 뮤트, 알림과 읽음 처리, 검색, 이미지와 동영상 업로드, 채팅(다이렉트 메시지), 신고를 수행합니다.
4. 이러한 조작은 이용자가 RASQ 화면에서 조작했을 때 수행합니다. RAi에 조작을 요청한 경우에도 상태를 바꾸는 조작은 내용을 보여 드리고 이용자가 확정한 후에 수행합니다.
5. 앱 비밀번호는 Bluesky 설정 화면에서 언제든지 삭제할 수 있습니다. 삭제하면 이 플러그인에서 해당 계정을 사용할 수 없게 됩니다.

### 제3조　통신과 데이터

1. 이 플러그인은 계정이 있는 서버(PDS) 및 로그인을 위한 bsky.social과 통신합니다. 채팅은 Bluesky의 채팅 서비스를 경유합니다. 게시물, 이미지, 동영상, 채팅 본문은 단말기에서 접속처로 직접 전송합니다.
2. 토큰은 단말기 OS의 안전한 저장 영역에 저장합니다. 이용자가 다음 기능을 선택한 경우에 한하여 토큰이 RASQ 서버로 전송됩니다.
   - 단말기 간 공유: 단말기에서 암호화하여 전송합니다. RASQ의 운영자는 복호화할 수 없습니다.
   - 웹판 보관함: RASQ 서버의 키로 암호화하여 저장합니다.
3. 계정 페이지에 게시물 표시를 선택한 경우에는 토큰이 아니라 계정 식별자(DID)와 핸들만 RASQ 서버로 전송합니다. RASQ 서버는 공개된 정보에서 게시물을 가져옵니다.
4. RASQ 계정에 로그인한 경우, 계정 묶음 표시를 위해 SNS 종류, 서버, 핸들, 표시 이름, 아이콘 URL을 RASQ 서버로 전송합니다. 토큰은 전송하지 않습니다.
5. 플러그인 통신 형태 진단을 활성화한 경우에는 통신처의 경로와 항목 이름을 RASQ 서버로 전송합니다. 값은 전송하지 않습니다. 이 진단은 선택 사항입니다.
6. 자세한 처리는 RASQ 개인정보처리방침 제4항에 나와 있습니다.

### 제4조　재배포

이 플러그인은 RASQ 앱의 일부로 제공됩니다. 플러그인 파일을 RASQ 앱에서 추출하여 단독으로 재배포할 수 없습니다. 플러그인에 포함된 제3자의 소프트웨어는 각각의 라이선스를 따릅니다. 라이선스는 「도움말, 법적 고지」 화면에서 확인할 수 있습니다.

### 제5조　변경

이 플러그인의 기능, 권한, 통신처를 확대하는 변경을 할 때에는 RASQ 플러그인 스토어의 이용 조건에 따라 변경 내용을 보여 드리고 다시 확인합니다.
'''},
});

/// `rasq.official.mastodon` の規約。
const officialMastodonTerms = r'''
## Mastodon プラグインの規約

このプラグインは、RASQ の運営者が提供する公式プラグインです。RASQ から Mastodon のサーバー（Mastodon と互換のあるサーバーを含みます）に接続するために使います。この規約は、RASQ の利用規約とプライバシーポリシーに加えて適用します。

### 第1条　接続先の規約

1. このプラグインで行う投稿、閲覧、フォロー、お気に入り、ブースト、ダイレクトメッセージ等には、接続先の Mastodon サーバーの利用規約とポリシーが適用されます。接続先の規約を確認し、守って利用してください。
2. 接続先のサーバーは、RASQ の運営者とは別の管理者が運営しています。RASQ の運営者は、接続先のサーバーの継続、内容、データの扱いを保証しません。
3. このプラグインから行う通報は、接続先のサーバーの管理者に送られます。

### 第2条　ログインと権限

1. ログインには、Mastodon の認証方式（OAuth）を使います。RASQ のサーバーが、接続先のサーバーに「RASQ」というアプリを登録し、ブラウザで開いた認証画面で利用者が許可すると、認証コードをアクセストークンに交換してアプリへ返します。RASQ のサーバーは、この手続のためにアクセストークンを保存しません。
2. このプラグインは、読み取り（read）、書き込み（write）、フォロー（follow）の権限を求めます。
3. このプラグインは、タイムラインの閲覧、投稿の作成と削除、お気に入り、ブースト、ブックマーク、フォローとフォロー申請、ミュート、ブロック、リスト、通知と既読、検索、プロフィールの変更、画像のアップロード、ダイレクトメッセージ、通報を行います。
4. これらの操作は、利用者が RASQ の画面で操作したときに行います。RAi に操作を頼んだ場合も、状態を変える操作は、内容を示して利用者が確定してから行います。
5. 許可した権限は、接続先のサーバーの設定画面（認証済みアプリ）から取り消せます。取り消すと、このプラグインからそのアカウントを使えなくなります。

### 第3条　通信とデータ

1. このプラグインは、ログインの手続のほかは、利用者が選んだ接続先のサーバーとだけ通信します。投稿、画像、ダイレクトメッセージの本文は、端末から接続先のサーバーへ直接送ります。
2. アクセストークンは、端末の OS の安全な保存領域に保存します。次の機能を利用者が選んだ場合に限り、アクセストークンが RASQ のサーバーへ送られます。
   - 端末間の共有：端末で暗号化して送ります。RASQ の運営者は復号できません。
   - Web 版の保管庫：RASQ のサーバーの鍵で暗号化して保存します。
   - アカウントページへの投稿の表示：RASQ のサーバーの鍵で暗号化して保存し、公開の投稿の取得に使います。
3. RASQ アカウントにログインしている場合、アカウントの束ね表示のために、SNS の種類、サーバー、ハンドル、表示名、アイコンの URL を RASQ のサーバーへ送ります。アクセストークンは送りません。
4. プラグインの通信の形の診断を有効にした場合は、通信先のパスと項目名を RASQ のサーバーへ送ります。値は送りません。この診断は任意です。
5. 詳しい扱いは、RASQ のプライバシーポリシーの第4項に示します。

### 第4条　再配布

このプラグインは RASQ アプリの一部として提供します。プラグインのファイルを RASQ アプリから取り出して、単独で再配布することはできません。プラグインに含まれる第三者のソフトウェアは、それぞれのライセンスに従います。ライセンスは「ヘルプ、法的表示」の画面で確認できます。

### 第5条　変更

このプラグインの機能、権限、通信先を広げる変更をするときは、RASQ のプラグインストアの利用条件に従い、変更の内容を示して改めて確認します。
''';

/// `rasq.official.mastodon` の規約の参考訳(マニフェストの `locales.<言語>.termsOfService`)。
const officialMastodonTermsLocales = ManifestLocales(byTag: {
  'en': {'termsOfService': r'''
> **Reference translation.** This is a reference translation provided for convenience. The Japanese version is the official text, and if there is any difference between them, the Japanese version governs.

## Mastodon Plugin Terms

This plugin is an official plugin provided by the Operator of RASQ. It is used to connect from RASQ to Mastodon servers (including servers compatible with Mastodon). These terms apply in addition to the RASQ Terms of Use and Privacy Policy.

### Article 1　Terms of the Connected Server

1. Posting, viewing, following, Favorites, Boosts, direct messages, and other activities performed with this plugin are subject to the terms of use and policies of the connected Mastodon server. Please check and comply with the terms of the connected server.
2. The connected server is operated by an administrator separate from the Operator of RASQ. The Operator of RASQ does not guarantee the continuity, content, or data handling of the connected server.
3. Reports made from this plugin are sent to the administrator of the connected server.

### Article 2　Login and Permissions

1. Mastodon's authentication method (OAuth) is used to log in. The RASQ server registers an app named "RASQ" with the connected server, and when the user grants permission on the authentication screen opened in the browser, it exchanges the authorization code for an access token and returns it to the app. The RASQ server does not store access tokens for this procedure.
2. This plugin requests read, write, and follow permissions.
3. This plugin performs viewing of the Timeline, creating and deleting posts, Favorites, Boosts, Bookmarks, following and follow requests, muting, blocking, lists, notifications and marking as read, search, changing the profile, uploading images, direct messages, and reporting.
4. These operations are performed when the user operates them on the RASQ screen. Even when you ask RAi to perform an operation, operations that change state are performed after the content is shown and the user confirms it.
5. Granted permissions can be revoked from the settings screen of the connected server (authorized apps). Once revoked, that account can no longer be used from this plugin.

### Article 3　Communications and Data

1. Apart from the login procedure, this plugin communicates only with the connected server chosen by the user. The body text of posts, images, and direct messages is sent directly from the device to the connected server.
2. Access tokens are stored in the secure storage area of the device's OS. Only if the user chooses the following features are access tokens sent to RASQ servers.
   - Sharing between devices: sent encrypted on the device. The Operator of RASQ cannot decrypt them.
   - Web version vault: stored encrypted with the key of the RASQ server.
   - Displaying posts on the account page: stored encrypted with the key of the RASQ server and used to retrieve public posts.
3. If you are logged in to a RASQ account, the type of SNS, server, handle, display name, and icon URL are sent to RASQ servers for the bundled account display. Access tokens are not sent.
4. If you enable diagnosis of the shape of the plugin's communications, the destination paths and field names are sent to RASQ servers. Values are not sent. This diagnosis is optional.
5. Details of handling are set out in Section 4 of the RASQ Privacy Policy.

### Article 4　Redistribution

This plugin is provided as part of the RASQ app. You may not extract the plugin's files from the RASQ app and redistribute them on their own. Third-party software included in the plugin is subject to its respective licenses. The licenses can be checked on the "Help, Legal" screen.

### Article 5　Changes

When making changes that expand this plugin's features, permissions, or communication destinations, the Operator will follow the RASQ Plugin Store terms of use, show the details of the changes, and ask for confirmation again.
'''},
  'zh': {'termsOfService': r'''
> **参考译文。** 本文是为方便阅读而提供的参考译文。正式文本为日文版，如两者内容有任何出入，以日文版为准。

## Mastodon插件条款

本插件是由RASQ的运营者提供的官方插件，用于从RASQ连接到Mastodon的服务器（包括与Mastodon兼容的服务器）。本条款在RASQ的使用条款和隐私政策之外另行适用。

### 第1条　连接对象的条款

1. 通过本插件进行的发帖、浏览、关注、收藏、转嘟、私信等，适用连接对象Mastodon服务器的使用条款和政策。请确认并遵守连接对象的条款。
2. 连接对象的服务器由不同于RASQ运营者的其他管理员运营。RASQ的运营者不保证连接对象服务器的持续性、内容及数据的处理方式。
3. 通过本插件进行的举报，将发送给连接对象服务器的管理员。

### 第2条　登录与权限

1. 登录时，使用Mastodon的认证方式（OAuth）。RASQ的服务器在连接对象的服务器上注册名为“RASQ”的应用，用户在浏览器中打开的认证画面上予以许可后，RASQ的服务器将认证码交换为访问令牌并返回给应用。RASQ的服务器不会为此程序保存访问令牌。
2. 本插件请求读取（read）、写入（write）、关注（follow）的权限。
3. 本插件进行以下操作：浏览时间线、创建和删除帖子、收藏、转嘟、书签、关注与关注请求、静音、屏蔽、列表、通知与已读、搜索、更改个人资料、上传图片、私信、举报。
4. 上述操作在用户于RASQ画面中进行操作时执行。即使委托RAi进行操作，改变状态的操作也会在展示内容并由用户确定后才执行。
5. 已许可的权限可从连接对象服务器的设置画面（已授权的应用）中撤销。撤销后，将无法通过本插件使用该账号。

### 第3条　通信与数据

1. 除登录程序外，本插件仅与用户所选的连接对象服务器进行通信。帖子、图片、私信的正文从设备直接发送至连接对象的服务器。
2. 访问令牌保存在设备操作系统的安全存储区域中。仅在用户选择以下功能时，访问令牌才会被发送至RASQ的服务器。
   - 设备间共享：在设备上加密后发送。RASQ的运营者无法解密。
   - 网页版保管库：以RASQ服务器的密钥加密后保存。
   - 在账号页面上显示帖子：以RASQ服务器的密钥加密后保存，并用于获取公开帖子。
3. 登录RASQ账号时，为进行账号的合并显示，将SNS的种类、服务器、用户名、显示名称、头像的URL发送至RASQ的服务器。不发送访问令牌。
4. 启用插件通信形态的诊断时，将通信对象的路径和项目名称发送至RASQ的服务器。不发送值。此诊断为可选项。
5. 详细的处理方式见RASQ隐私政策第4项。

### 第4条　再分发

本插件作为RASQ应用的一部分提供。不得将插件文件从RASQ应用中取出并单独再分发。插件中包含的第三方软件遵从各自的许可证。许可证可在“帮助、法律声明”画面中确认。

### 第5条　变更

对本插件的功能、权限、通信对象进行扩大的变更时，将依照RASQ插件商店的使用条件，展示变更内容并重新进行确认。
'''},
  'zh-hant': {'termsOfService': r'''
> **參考譯文。** 本文是為方便閱讀而提供的參考譯文。正式文本為日文版，如兩者內容有任何出入，以日文版為準。

## Mastodon 外掛條款

本外掛是由 RASQ 營運者提供的官方外掛，用於從 RASQ 連線至 Mastodon 的伺服器（包含與 Mastodon 相容的伺服器）。本條款於 RASQ 使用條款及隱私權政策之外另行適用。

### 第1條　連線目標的條款

1. 透過本外掛進行的貼文、瀏覽、追蹤、最愛、轉推（Boost）、私人訊息等，適用連線目標 Mastodon 伺服器的使用條款與政策。請確認並遵守連線目標的條款。
2. 連線目標的伺服器由不同於 RASQ 營運者的管理者營運。RASQ 營運者不保證連線目標伺服器的持續性、內容及資料的處理方式。
3. 從本外掛提出的檢舉，會傳送至連線目標伺服器的管理者。

### 第2條　登入與權限

1. 登入時使用 Mastodon 的驗證方式（OAuth）。RASQ 的伺服器在連線目標伺服器上註冊名為「RASQ」的應用程式，使用者在以瀏覽器開啟的驗證畫面中允許後，將授權碼交換為存取權杖並回傳給應用程式。RASQ 的伺服器不會為此程序儲存存取權杖。
2. 本外掛要求讀取（read）、寫入（write）、追蹤（follow）的權限。
3. 本外掛會進行時間軸的瀏覽、貼文的建立與刪除、最愛、轉推（Boost）、書籤、追蹤與追蹤請求、靜音、封鎖、清單、通知與已讀、搜尋、個人檔案的變更、圖片的上傳、私人訊息、檢舉。
4. 上述操作於使用者在 RASQ 畫面上進行操作時執行。即使委託 RAi 進行操作，會改變狀態的操作也會在顯示內容並由使用者確定後才執行。
5. 已允許的權限，可從連線目標伺服器的設定畫面（已授權的應用程式）撤銷。撤銷後，即無法再透過本外掛使用該帳號。

### 第3條　通訊與資料

1. 除登入程序外，本外掛僅與使用者所選擇的連線目標伺服器通訊。貼文、圖片、私人訊息的內文，從裝置直接傳送至連線目標伺服器。
2. 存取權杖儲存於裝置作業系統的安全儲存區。僅在使用者選擇下列功能時，存取權杖才會傳送至 RASQ 的伺服器。
   - 跨裝置共用：在裝置上加密後傳送。RASQ 營運者無法解密。
   - 網頁版的保管庫：以 RASQ 伺服器的金鑰加密後儲存。
   - 在帳號頁面顯示貼文：以 RASQ 伺服器的金鑰加密後儲存，並用於取得公開貼文。
3. 已登入 RASQ 帳號時，為了帳號的整合顯示，會將 SNS 的種類、伺服器、帳號代稱、顯示名稱、頭像的網址傳送至 RASQ 的伺服器。不傳送存取權杖。
4. 啟用外掛通訊形式的診斷時，會將通訊目標的路徑與項目名稱傳送至 RASQ 的伺服器，不傳送值。此診斷為選用。
5. 詳細的處理方式，載於 RASQ 隱私權政策第4項。

### 第4條　再散布

本外掛作為 RASQ 應用程式的一部分提供。不得將外掛的檔案從 RASQ 應用程式中取出並單獨再散布。外掛所包含的第三方軟體，依其各自的授權。授權可在「說明、法律聲明」畫面中確認。

### 第5條　變更

對本外掛進行擴大功能、權限、通訊目標的變更時，會依 RASQ 外掛商店的使用條件，顯示變更內容並重新確認。
'''},
  'ko': {'termsOfService': r'''
> **참고 번역.** 이 문서는 편의를 위해 제공하는 참고 번역입니다. 정식 문서는 일본어판이며, 내용에 차이가 있는 경우 일본어판이 우선합니다.

## Mastodon 플러그인 약관

이 플러그인은 RASQ의 운영자가 제공하는 공식 플러그인입니다. RASQ에서 Mastodon 서버(Mastodon과 호환되는 서버를 포함합니다)에 접속하기 위해 사용합니다. 이 약관은 RASQ의 이용약관과 개인정보처리방침에 더하여 적용됩니다.

### 제1조　접속처의 약관

1. 이 플러그인으로 하는 게시, 열람, 팔로우, 즐겨찾기, 부스트, 다이렉트 메시지 등에는 접속처 Mastodon 서버의 이용약관과 정책이 적용됩니다. 접속처의 약관을 확인하고 준수하여 이용해 주십시오.
2. 접속처의 서버는 RASQ의 운영자와는 다른 관리자가 운영합니다. RASQ의 운영자는 접속처 서버의 지속, 내용, 데이터 처리를 보증하지 않습니다.
3. 이 플러그인에서 하는 신고는 접속처 서버의 관리자에게 전송됩니다.

### 제2조　로그인과 권한

1. 로그인에는 Mastodon의 인증 방식(OAuth)을 사용합니다. RASQ 서버가 접속처 서버에 「RASQ」라는 앱을 등록하고, 브라우저에서 연 인증 화면에서 이용자가 허가하면 인증 코드를 액세스 토큰으로 교환하여 앱에 반환합니다. RASQ 서버는 이 절차를 위해 액세스 토큰을 저장하지 않습니다.
2. 이 플러그인은 읽기(read), 쓰기(write), 팔로우(follow) 권한을 요청합니다.
3. 이 플러그인은 타임라인 열람, 게시물 작성과 삭제, 즐겨찾기, 부스트, 북마크, 팔로우와 팔로우 요청, 뮤트, 차단, 리스트, 알림과 읽음 처리, 검색, 프로필 변경, 이미지 업로드, 다이렉트 메시지, 신고를 수행합니다.
4. 이러한 조작은 이용자가 RASQ 화면에서 조작했을 때 수행합니다. RAi에 조작을 요청한 경우에도 상태를 바꾸는 조작은 내용을 보여 드리고 이용자가 확정한 후에 수행합니다.
5. 허가한 권한은 접속처 서버의 설정 화면(인증된 앱)에서 취소할 수 있습니다. 취소하면 이 플러그인에서 해당 계정을 사용할 수 없게 됩니다.

### 제3조　통신과 데이터

1. 이 플러그인은 로그인 절차 외에는 이용자가 선택한 접속처 서버와만 통신합니다. 게시물, 이미지, 다이렉트 메시지 본문은 단말기에서 접속처 서버로 직접 전송합니다.
2. 액세스 토큰은 단말기 OS의 안전한 저장 영역에 저장합니다. 이용자가 다음 기능을 선택한 경우에 한하여 액세스 토큰이 RASQ 서버로 전송됩니다.
   - 단말기 간 공유: 단말기에서 암호화하여 전송합니다. RASQ의 운영자는 복호화할 수 없습니다.
   - 웹판 보관함: RASQ 서버의 키로 암호화하여 저장합니다.
   - 계정 페이지에 게시물 표시: RASQ 서버의 키로 암호화하여 저장하고, 공개 게시물을 가져오는 데 사용합니다.
3. RASQ 계정에 로그인한 경우, 계정 묶음 표시를 위해 SNS 종류, 서버, 핸들, 표시 이름, 아이콘 URL을 RASQ 서버로 전송합니다. 액세스 토큰은 전송하지 않습니다.
4. 플러그인 통신 형태 진단을 활성화한 경우에는 통신처의 경로와 항목 이름을 RASQ 서버로 전송합니다. 값은 전송하지 않습니다. 이 진단은 선택 사항입니다.
5. 자세한 처리는 RASQ 개인정보처리방침 제4항에 나와 있습니다.

### 제4조　재배포

이 플러그인은 RASQ 앱의 일부로 제공됩니다. 플러그인 파일을 RASQ 앱에서 추출하여 단독으로 재배포할 수 없습니다. 플러그인에 포함된 제3자의 소프트웨어는 각각의 라이선스를 따릅니다. 라이선스는 「도움말, 법적 고지」 화면에서 확인할 수 있습니다.

### 제5조　변경

이 플러그인의 기능, 권한, 통신처를 확대하는 변경을 할 때에는 RASQ 플러그인 스토어의 이용 조건에 따라 변경 내용을 보여 드리고 다시 확인합니다.
'''},
});

/// `rasq.official.misskey` の規約。
const officialMisskeyTerms = r'''
## Misskey Plugin の規約

このプラグインは、RASQ の運営者が提供する公式プラグインです。RASQ から Misskey のサーバー（Misskey と互換のあるサーバーを含みます）に接続するために使います。この規約は、RASQ の利用規約とプライバシーポリシーに加えて適用します。

### 第1条　接続先の規約

1. このプラグインで行う投稿、閲覧、フォロー、リアクション、チャット等には、接続先の Misskey サーバーの利用規約とポリシーが適用されます。接続先の規約を確認し、守って利用してください。
2. 接続先のサーバーは、RASQ の運営者とは別の管理者が運営しています。RASQ の運営者は、接続先のサーバーの継続、内容、データの扱いを保証しません。
3. このプラグインから行う通報は、接続先のサーバーの管理者に送られます。

### 第2条　ログインと権限

1. ログインには、Misskey の認証方式（MiAuth）を使います。ブラウザで接続先のサーバーの認証画面を開き、RASQ にアクセスを許可すると、アクセストークンが発行されます。この手続に RASQ のサーバーは関わりません。
2. このプラグインは、次の権限を求めます：アカウントの情報の読み取りと変更、ノートの作成と削除、投票、通知の読み取りと既読、リアクション、フォローとフォロー申請、ブロック、ミュート、お気に入り、ドライブ（ファイルのアップロード）、ダイレクトメッセージ（メッセージとチャット）。
3. 求めた権限は、利用者が RASQ の画面で操作したときに使います。RAi に操作を頼んだ場合も、状態を変える操作は、内容を示して利用者が確定してから行います。
4. 許可した権限は、接続先のサーバーの設定画面（API・アプリの連携）から取り消せます。取り消すと、このプラグインからそのアカウントを使えなくなります。

### 第3条　通信とデータ

1. このプラグインは、利用者が選んだ接続先のサーバーとだけ通信します。投稿、画像、チャットの本文は、端末から接続先のサーバーへ直接送ります。
2. 接続先のサーバーが設定した広告を、タイムラインに表示することがあります。
3. アクセストークンは、端末の OS の安全な保存領域に保存します。次の機能を利用者が選んだ場合に限り、アクセストークンが RASQ のサーバーへ送られます。
   - 端末間の共有：端末で暗号化して送ります。RASQ の運営者は復号できません。
   - Web 版の保管庫：RASQ のサーバーの鍵で暗号化して保存します。
   - アカウントページへの投稿の表示：RASQ のサーバーの鍵で暗号化して保存し、公開の投稿の取得に使います。
4. RASQ アカウントにログインしている場合、アカウントの束ね表示のために、SNS の種類、サーバー、ハンドル、表示名、アイコンの URL を RASQ のサーバーへ送ります。アクセストークンは送りません。
5. プラグインの通信の形の診断を有効にした場合は、通信先のパスと項目名を RASQ のサーバーへ送ります。値は送りません。この診断は任意です。
6. 詳しい扱いは、RASQ のプライバシーポリシーの第4項に示します。

### 第4条　再配布

このプラグインは RASQ アプリの一部として提供します。プラグインのファイルを RASQ アプリから取り出して、単独で再配布することはできません。プラグインに含まれる第三者のソフトウェアは、それぞれのライセンスに従います。ライセンスは「ヘルプ、法的表示」の画面で確認できます。

### 第5条　変更

このプラグインの機能、権限、通信先を広げる変更をするときは、RASQ のプラグインストアの利用条件に従い、変更の内容を示して改めて確認します。
''';

/// `rasq.official.misskey` の規約の参考訳(マニフェストの `locales.<言語>.termsOfService`)。
const officialMisskeyTermsLocales = ManifestLocales(byTag: {
  'en': {'termsOfService': r'''
> **Reference translation.** This is a reference translation provided for convenience. The Japanese version is the official text, and if there is any difference between them, the Japanese version governs.

## Misskey Plugin Terms

This plugin is an official plugin provided by the Operator of RASQ. It is used to connect from RASQ to Misskey servers (including servers compatible with Misskey). These terms apply in addition to the RASQ Terms of Use and Privacy Policy.

### Article 1　Terms of the Connected Server

1. Posting, viewing, following, Reactions, chat, and other activities performed with this plugin are subject to the terms of use and policies of the connected Misskey server. Please check and comply with the terms of the connected server.
2. The connected server is operated by an administrator separate from the Operator of RASQ. The Operator of RASQ does not guarantee the continuity, content, or data handling of the connected server.
3. Reports made from this plugin are sent to the administrator of the connected server.

### Article 2　Login and Permissions

1. Misskey's authentication method (MiAuth) is used to log in. When you open the authentication screen of the connected server in the browser and allow RASQ access, an access token is issued. RASQ servers are not involved in this procedure.
2. This plugin requests the following permissions: reading and changing account information, creating and deleting Notes, voting, reading notifications and marking them as read, Reactions, following and follow requests, blocking, muting, favorites, Drive (uploading files), and direct messages (messages and chat).
3. The requested permissions are used when the user operates on the RASQ screen. Even when you ask RAi to perform an operation, operations that change state are performed after the content is shown and the user confirms it.
4. Granted permissions can be revoked from the settings screen of the connected server (API and app integrations). Once revoked, that account can no longer be used from this plugin.

### Article 3　Communications and Data

1. This plugin communicates only with the connected server chosen by the user. The body text of posts, images, and chats is sent directly from the device to the connected server.
2. Ads configured by the connected server may be displayed on the Timeline.
3. Access tokens are stored in the secure storage area of the device's OS. Only if the user chooses the following features are access tokens sent to RASQ servers.
   - Sharing between devices: sent encrypted on the device. The Operator of RASQ cannot decrypt them.
   - Web version vault: stored encrypted with the key of the RASQ server.
   - Displaying posts on the account page: stored encrypted with the key of the RASQ server and used to retrieve public posts.
4. If you are logged in to a RASQ account, the type of SNS, server, handle, display name, and icon URL are sent to RASQ servers for the bundled account display. Access tokens are not sent.
5. If you enable diagnosis of the shape of the plugin's communications, the destination paths and field names are sent to RASQ servers. Values are not sent. This diagnosis is optional.
6. Details of handling are set out in Section 4 of the RASQ Privacy Policy.

### Article 4　Redistribution

This plugin is provided as part of the RASQ app. You may not extract the plugin's files from the RASQ app and redistribute them on their own. Third-party software included in the plugin is subject to its respective licenses. The licenses can be checked on the "Help, Legal" screen.

### Article 5　Changes

When making changes that expand this plugin's features, permissions, or communication destinations, the Operator will follow the RASQ Plugin Store terms of use, show the details of the changes, and ask for confirmation again.
'''},
  'zh': {'termsOfService': r'''
> **参考译文。** 本文是为方便阅读而提供的参考译文。正式文本为日文版，如两者内容有任何出入，以日文版为准。

## Misskey插件条款

本插件是由RASQ的运营者提供的官方插件，用于从RASQ连接到Misskey的服务器（包括与Misskey兼容的服务器）。本条款在RASQ的使用条款和隐私政策之外另行适用。

### 第1条　连接对象的条款

1. 通过本插件进行的发帖、浏览、关注、回应、聊天等，适用连接对象Misskey服务器的使用条款和政策。请确认并遵守连接对象的条款。
2. 连接对象的服务器由不同于RASQ运营者的其他管理员运营。RASQ的运营者不保证连接对象服务器的持续性、内容及数据的处理方式。
3. 通过本插件进行的举报，将发送给连接对象服务器的管理员。

### 第2条　登录与权限

1. 登录时，使用Misskey的认证方式（MiAuth）。在浏览器中打开连接对象服务器的认证画面并允许RASQ访问后，即发行访问令牌。RASQ的服务器不参与此程序。
2. 本插件请求以下权限：读取和更改账号信息、创建和删除帖子、投票、读取通知与已读、回应、关注与关注请求、屏蔽、静音、收藏、网盘（上传文件）、私信（消息和聊天）。
3. 所请求的权限在用户于RASQ画面中进行操作时使用。即使委托RAi进行操作，改变状态的操作也会在展示内容并由用户确定后才执行。
4. 已许可的权限可从连接对象服务器的设置画面（API、应用联动）中撤销。撤销后，将无法通过本插件使用该账号。

### 第3条　通信与数据

1. 本插件仅与用户所选的连接对象服务器进行通信。帖子、图片、聊天的正文从设备直接发送至连接对象的服务器。
2. 可能会在时间线中展示连接对象服务器所设置的广告。
3. 访问令牌保存在设备操作系统的安全存储区域中。仅在用户选择以下功能时，访问令牌才会被发送至RASQ的服务器。
   - 设备间共享：在设备上加密后发送。RASQ的运营者无法解密。
   - 网页版保管库：以RASQ服务器的密钥加密后保存。
   - 在账号页面上显示帖子：以RASQ服务器的密钥加密后保存，并用于获取公开帖子。
4. 登录RASQ账号时，为进行账号的合并显示，将SNS的种类、服务器、用户名、显示名称、头像的URL发送至RASQ的服务器。不发送访问令牌。
5. 启用插件通信形态的诊断时，将通信对象的路径和项目名称发送至RASQ的服务器。不发送值。此诊断为可选项。
6. 详细的处理方式见RASQ隐私政策第4项。

### 第4条　再分发

本插件作为RASQ应用的一部分提供。不得将插件文件从RASQ应用中取出并单独再分发。插件中包含的第三方软件遵从各自的许可证。许可证可在“帮助、法律声明”画面中确认。

### 第5条　变更

对本插件的功能、权限、通信对象进行扩大的变更时，将依照RASQ插件商店的使用条件，展示变更内容并重新进行确认。
'''},
  'zh-hant': {'termsOfService': r'''
> **參考譯文。** 本文是為方便閱讀而提供的參考譯文。正式文本為日文版，如兩者內容有任何出入，以日文版為準。

## Misskey 外掛條款

本外掛是由 RASQ 營運者提供的官方外掛，用於從 RASQ 連線至 Misskey 的伺服器（包含與 Misskey 相容的伺服器）。本條款於 RASQ 使用條款及隱私權政策之外另行適用。

### 第1條　連線目標的條款

1. 透過本外掛進行的貼文、瀏覽、追蹤、回應、聊天等，適用連線目標 Misskey 伺服器的使用條款與政策。請確認並遵守連線目標的條款。
2. 連線目標的伺服器由不同於 RASQ 營運者的管理者營運。RASQ 營運者不保證連線目標伺服器的持續性、內容及資料的處理方式。
3. 從本外掛提出的檢舉，會傳送至連線目標伺服器的管理者。

### 第2條　登入與權限

1. 登入時使用 Misskey 的驗證方式（MiAuth）。以瀏覽器開啟連線目標伺服器的驗證畫面，並允許 RASQ 存取後，即會發行存取權杖。RASQ 的伺服器不參與此程序。
2. 本外掛要求下列權限：讀取與變更帳號資訊、建立與刪除貼文、投票、讀取通知與已讀、回應、追蹤與追蹤請求、封鎖、靜音、我的最愛、雲端硬碟（上傳檔案）、私人訊息（訊息與聊天）。
3. 所要求的權限，於使用者在 RASQ 畫面上進行操作時使用。即使委託 RAi 進行操作，會改變狀態的操作也會在顯示內容並由使用者確定後才執行。
4. 已允許的權限，可從連線目標伺服器的設定畫面（API、應用程式連動）撤銷。撤銷後，即無法再透過本外掛使用該帳號。

### 第3條　通訊與資料

1. 本外掛僅與使用者所選擇的連線目標伺服器通訊。貼文、圖片、聊天的內文，從裝置直接傳送至連線目標伺服器。
2. 連線目標伺服器所設定的廣告，可能會顯示於時間軸。
3. 存取權杖儲存於裝置作業系統的安全儲存區。僅在使用者選擇下列功能時，存取權杖才會傳送至 RASQ 的伺服器。
   - 跨裝置共用：在裝置上加密後傳送。RASQ 營運者無法解密。
   - 網頁版的保管庫：以 RASQ 伺服器的金鑰加密後儲存。
   - 在帳號頁面顯示貼文：以 RASQ 伺服器的金鑰加密後儲存，並用於取得公開貼文。
4. 已登入 RASQ 帳號時，為了帳號的整合顯示，會將 SNS 的種類、伺服器、帳號代稱、顯示名稱、頭像的網址傳送至 RASQ 的伺服器。不傳送存取權杖。
5. 啟用外掛通訊形式的診斷時，會將通訊目標的路徑與項目名稱傳送至 RASQ 的伺服器，不傳送值。此診斷為選用。
6. 詳細的處理方式，載於 RASQ 隱私權政策第4項。

### 第4條　再散布

本外掛作為 RASQ 應用程式的一部分提供。不得將外掛的檔案從 RASQ 應用程式中取出並單獨再散布。外掛所包含的第三方軟體，依其各自的授權。授權可在「說明、法律聲明」畫面中確認。

### 第5條　變更

對本外掛進行擴大功能、權限、通訊目標的變更時，會依 RASQ 外掛商店的使用條件，顯示變更內容並重新確認。
'''},
  'ko': {'termsOfService': r'''
> **참고 번역.** 이 문서는 편의를 위해 제공하는 참고 번역입니다. 정식 문서는 일본어판이며, 내용에 차이가 있는 경우 일본어판이 우선합니다.

## Misskey Plugin 약관

이 플러그인은 RASQ의 운영자가 제공하는 공식 플러그인입니다. RASQ에서 Misskey 서버(Misskey와 호환되는 서버를 포함합니다)에 접속하기 위해 사용합니다. 이 약관은 RASQ의 이용약관과 개인정보처리방침에 더하여 적용됩니다.

### 제1조　접속처의 약관

1. 이 플러그인으로 하는 게시, 열람, 팔로우, 리액션, 채팅 등에는 접속처 Misskey 서버의 이용약관과 정책이 적용됩니다. 접속처의 약관을 확인하고 준수하여 이용해 주십시오.
2. 접속처의 서버는 RASQ의 운영자와는 다른 관리자가 운영합니다. RASQ의 운영자는 접속처 서버의 지속, 내용, 데이터 처리를 보증하지 않습니다.
3. 이 플러그인에서 하는 신고는 접속처 서버의 관리자에게 전송됩니다.

### 제2조　로그인과 권한

1. 로그인에는 Misskey의 인증 방식(MiAuth)을 사용합니다. 브라우저에서 접속처 서버의 인증 화면을 열고 RASQ에 액세스를 허가하면 액세스 토큰이 발행됩니다. 이 절차에 RASQ 서버는 관여하지 않습니다.
2. 이 플러그인은 다음 권한을 요청합니다: 계정 정보의 읽기와 변경, 노트 작성과 삭제, 투표, 알림 읽기와 읽음 처리, 리액션, 팔로우와 팔로우 요청, 차단, 뮤트, 즐겨찾기, 드라이브(파일 업로드), 다이렉트 메시지(메시지와 채팅).
3. 요청한 권한은 이용자가 RASQ 화면에서 조작했을 때 사용합니다. RAi에 조작을 요청한 경우에도 상태를 바꾸는 조작은 내용을 보여 드리고 이용자가 확정한 후에 수행합니다.
4. 허가한 권한은 접속처 서버의 설정 화면(API·앱 연동)에서 취소할 수 있습니다. 취소하면 이 플러그인에서 해당 계정을 사용할 수 없게 됩니다.

### 제3조　통신과 데이터

1. 이 플러그인은 이용자가 선택한 접속처 서버와만 통신합니다. 게시물, 이미지, 채팅 본문은 단말기에서 접속처 서버로 직접 전송합니다.
2. 접속처 서버가 설정한 광고를 타임라인에 표시할 수 있습니다.
3. 액세스 토큰은 단말기 OS의 안전한 저장 영역에 저장합니다. 이용자가 다음 기능을 선택한 경우에 한하여 액세스 토큰이 RASQ 서버로 전송됩니다.
   - 단말기 간 공유: 단말기에서 암호화하여 전송합니다. RASQ의 운영자는 복호화할 수 없습니다.
   - 웹판 보관함: RASQ 서버의 키로 암호화하여 저장합니다.
   - 계정 페이지에 게시물 표시: RASQ 서버의 키로 암호화하여 저장하고, 공개 게시물을 가져오는 데 사용합니다.
4. RASQ 계정에 로그인한 경우, 계정 묶음 표시를 위해 SNS 종류, 서버, 핸들, 표시 이름, 아이콘 URL을 RASQ 서버로 전송합니다. 액세스 토큰은 전송하지 않습니다.
5. 플러그인 통신 형태 진단을 활성화한 경우에는 통신처의 경로와 항목 이름을 RASQ 서버로 전송합니다. 값은 전송하지 않습니다. 이 진단은 선택 사항입니다.
6. 자세한 처리는 RASQ 개인정보처리방침 제4항에 나와 있습니다.

### 제4조　재배포

이 플러그인은 RASQ 앱의 일부로 제공됩니다. 플러그인 파일을 RASQ 앱에서 추출하여 단독으로 재배포할 수 없습니다. 플러그인에 포함된 제3자의 소프트웨어는 각각의 라이선스를 따릅니다. 라이선스는 「도움말, 법적 고지」 화면에서 확인할 수 있습니다.

### 제5조　변경

이 플러그인의 기능, 권한, 통신처를 확대하는 변경을 할 때에는 RASQ 플러그인 스토어의 이용 조건에 따라 변경 내용을 보여 드리고 다시 확인합니다.
'''},
});

/// `rasq.official.mixi2` の規約。
const officialMixi2Terms = r'''
## mixi2 プラグイン（サンプル）の規約

このプラグインは、RASQ の運営者が提供する試験用のサンプルです。この規約は、RASQ の利用規約とプライバシーポリシーに加えて適用します。

### 第1条　サンプルであること

1. このプラグインは、mixi2 の公式の API の提供を受ける前の試験用です。株式会社MIXI が提供・承認したものではありません。
2. 現在は、サーバーに「dummy」を指定したときの試験用の動作（ダミーモード）だけを提供します。ダミーモードでは、mixi2 のサーバーと通信せず、端末の中だけで投稿や閲覧の流れを試します。ダミーモードの内容は、アプリを閉じると消えます。
3. 実際の mixi2 への接続は、まだ提供していません。提供を始めるときは、接続先、ログインの方式、権限、通信とデータの扱いをこの規約に書き加え、改めて確認します。

### 第2条　通信とデータ

1. ダミーモードでは、mixi2 のサーバーにも、RASQ のサーバーにも、投稿の内容を送りません。
2. RASQ アカウントにログインしている場合、アカウントの束ね表示のために、SNS の種類、サーバー、ハンドル、表示名を RASQ のサーバーへ送ることがあります。

### 第3条　再配布

このプラグインは RASQ アプリの一部として提供します。プラグインのファイルを RASQ アプリから取り出して、単独で再配布することはできません。プラグインに含まれる第三者のソフトウェアは、それぞれのライセンスに従います。
''';

/// `rasq.official.mixi2` の規約の参考訳(マニフェストの `locales.<言語>.termsOfService`)。
const officialMixi2TermsLocales = ManifestLocales(byTag: {
  'en': {'termsOfService': r'''
> **Reference translation.** This is a reference translation provided for convenience. The Japanese version is the official text, and if there is any difference between them, the Japanese version governs.

## mixi2 Plugin (Sample) Terms

This plugin is a sample for testing provided by the Operator of RASQ. These terms apply in addition to the RASQ Terms of Use and Privacy Policy.

### Article 1　Nature as a Sample

1. This plugin is for testing before receiving access to the official mixi2 API. It is not provided or approved by MIXI, Inc.
2. Currently, only test behavior when "dummy" is specified as the server (dummy mode) is provided. In dummy mode, the plugin does not communicate with mixi2 servers, and the flow of posting and viewing is tried out only on the device. The content of dummy mode disappears when the app is closed.
3. Connection to the actual mixi2 is not yet provided. When provision begins, the connection destination, login method, permissions, and handling of communications and data will be added to these terms, and confirmation will be requested again.

### Article 2　Communications and Data

1. In dummy mode, the content of posts is not sent to mixi2 servers or to RASQ servers.
2. If you are logged in to a RASQ account, the type of SNS, server, handle, and display name may be sent to RASQ servers for the bundled account display.

### Article 3　Redistribution

This plugin is provided as part of the RASQ app. You may not extract the plugin's files from the RASQ app and redistribute them on their own. Third-party software included in the plugin is subject to its respective licenses.
'''},
  'zh': {'termsOfService': r'''
> **参考译文。** 本文是为方便阅读而提供的参考译文。正式文本为日文版，如两者内容有任何出入，以日文版为准。

## mixi2插件（示例）条款

本插件是由RASQ的运营者提供的测试用示例。本条款在RASQ的使用条款和隐私政策之外另行适用。

### 第1条　关于示例

1. 本插件是在获得mixi2官方API提供之前的测试用插件。并非由MIXI, Inc.提供、批准。
2. 目前仅提供在服务器中指定“dummy”时的测试用运行（虚拟模式）。在虚拟模式下，不与mixi2的服务器通信，仅在设备内试用发帖和浏览的流程。虚拟模式的内容在关闭应用后即消失。
3. 尚未提供与实际mixi2的连接。开始提供时，将在本条款中补充连接对象、登录方式、权限、通信与数据的处理方式，并重新进行确认。

### 第2条　通信与数据

1. 在虚拟模式下，不向mixi2的服务器或RASQ的服务器发送帖子的内容。
2. 登录RASQ账号时，为进行账号的合并显示，可能会将SNS的种类、服务器、用户名、显示名称发送至RASQ的服务器。

### 第3条　再分发

本插件作为RASQ应用的一部分提供。不得将插件文件从RASQ应用中取出并单独再分发。插件中包含的第三方软件遵从各自的许可证。
'''},
  'zh-hant': {'termsOfService': r'''
> **參考譯文。** 本文是為方便閱讀而提供的參考譯文。正式文本為日文版，如兩者內容有任何出入，以日文版為準。

## mixi2 外掛（範例）條款

本外掛是由 RASQ 營運者提供的測試用範例。本條款於 RASQ 使用條款及隱私權政策之外另行適用。

### 第1條　本外掛為範例

1. 本外掛為在取得 mixi2 官方 API 提供之前的測試用外掛，並非由株式會社MIXI 提供或核准。
2. 目前僅提供在伺服器指定為「dummy」時的測試用動作（模擬模式）。在模擬模式中，不與 mixi2 的伺服器通訊，僅在裝置內試用貼文及瀏覽的流程。模擬模式的內容會在關閉應用程式後消失。
3. 尚未提供實際連線至 mixi2 的功能。開始提供時，會將連線目標、登入方式、權限、通訊與資料的處理方式增列於本條款，並重新確認。

### 第2條　通訊與資料

1. 在模擬模式中，不會將貼文內容傳送至 mixi2 的伺服器，亦不會傳送至 RASQ 的伺服器。
2. 已登入 RASQ 帳號時，為了帳號的整合顯示，可能會將 SNS 的種類、伺服器、帳號代稱、顯示名稱傳送至 RASQ 的伺服器。

### 第3條　再散布

本外掛作為 RASQ 應用程式的一部分提供。不得將外掛的檔案從 RASQ 應用程式中取出並單獨再散布。外掛所包含的第三方軟體，依其各自的授權。
'''},
  'ko': {'termsOfService': r'''
> **참고 번역.** 이 문서는 편의를 위해 제공하는 참고 번역입니다. 정식 문서는 일본어판이며, 내용에 차이가 있는 경우 일본어판이 우선합니다.

## mixi2 플러그인(샘플) 약관

이 플러그인은 RASQ의 운영자가 제공하는 시험용 샘플입니다. 이 약관은 RASQ의 이용약관과 개인정보처리방침에 더하여 적용됩니다.

### 제1조　샘플이라는 점

1. 이 플러그인은 mixi2의 공식 API를 제공받기 전의 시험용입니다. 주식회사 MIXI가 제공·승인한 것이 아닙니다.
2. 현재는 서버에 「dummy」를 지정했을 때의 시험용 동작(더미 모드)만 제공합니다. 더미 모드에서는 mixi2 서버와 통신하지 않고, 단말기 안에서만 게시와 열람의 흐름을 시험합니다. 더미 모드의 내용은 앱을 닫으면 사라집니다.
3. 실제 mixi2로의 접속은 아직 제공하지 않습니다. 제공을 시작할 때에는 접속처, 로그인 방식, 권한, 통신과 데이터 처리를 이 약관에 추가하고 다시 확인합니다.

### 제2조　통신과 데이터

1. 더미 모드에서는 mixi2 서버에도 RASQ 서버에도 게시물의 내용을 전송하지 않습니다.
2. RASQ 계정에 로그인한 경우, 계정 묶음 표시를 위해 SNS 종류, 서버, 핸들, 표시 이름을 RASQ 서버로 전송할 수 있습니다.

### 제3조　재배포

이 플러그인은 RASQ 앱의 일부로 제공됩니다. 플러그인 파일을 RASQ 앱에서 추출하여 단독으로 재배포할 수 없습니다. 플러그인에 포함된 제3자의 소프트웨어는 각각의 라이선스를 따릅니다.
'''},
});
