import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart' show SnsKind;

import 'server_signup.dart' show ServerSignupTarget;

/// 登録 / ログインのページの「指差し」(D-414)。
///
/// アプリの中の WebView(Android / iOS / macOS)のページに JavaScript を差して、RAi の案内のいまの手順で触るべき入力欄 /
/// ボタンを**ページの中で**見つけ、枠(outline + 脈打つ影、注入した CSS)を付けて `scrollIntoView` する。位置の計算は
/// Flutter 側ではしない(ページのスクロール / 拡大にそのまま付いてくる)。見つからなければ何もしない(SPA の Misskey は
/// 画面が後から出るので、0.5 秒おきに 10 秒まで探し直す)。外部のブラウザで開く端末(Linux / Windows / Web)では使わない。

/// ページに JavaScript を流す口(webview_flutter の `WebViewController` と同じ形。テストではフェイク)。
abstract interface class WebJsRunner {
  Future<void> runJavaScript(String javaScript);
  Future<Object> runJavaScriptReturningResult(String javaScript);
}

/// いまの手順で指すもの。
enum SignupPointIntent {
  /// 指さない(招待制の注意 / メールの確認 / 最後の「登録できた」)。
  none,

  /// Misskey 系: トップの「新規登録」。
  openSignup,

  /// Mastodon: サーバーのルールの「同意する」。
  rules,

  /// ユーザー名 / メール / パスワード / 送るボタン。
  accountFields,

  /// Misskey 系: メール / 招待コード / ロボットでないことの確認。
  extraFields,

  /// Misskey 系: ルール / 規約の同意。
  agreement,

  /// ログインのフォーム(メールの確認のあとに出るなど)。
  login,

  /// アプリの連携の許可(OAuth / MiAuth)。
  authorize,
}

/// 指す要素の見つけ方: CSS セレクタ(どれか)+ ボタン / リンク / ラベルの文字の正規表現(任意)。
@immutable
class SignupPointSpec {
  const SignupPointSpec({this.selectors = const [], this.text});
  final List<String> selectors;
  final String? text;

  Map<String, Object?> toJson() => {'selectors': selectors, 'text': ?text};
}

bool _isMastodon(ServerSignupTarget t) => t.software?.toLowerCase() == 'mastodon' || (t.software == null && t.kind == SnsKind.mastodon);

/// RAi の案内の手順([signupGuideSteps] の並び)と、いまのページの URL から、指すものを決める。
/// URL がログイン / 連携の許可のページならそちらが先(手順の文と関係なく、そのページのフォームを指す)。
SignupPointIntent signupPointIntent(ServerSignupTarget t, int step, int stepCount, {Uri? url}) {
  final mastodon = _isMastodon(t);
  if (url != null && url.host == t.host) {
    final p = url.path;
    if (mastodon && p.startsWith('/auth/sign_in')) return SignupPointIntent.login;
    if (p.startsWith('/oauth/authorize') || p.startsWith('/miauth/')) return SignupPointIntent.authorize;
  }
  if (step >= stepCount - 1) return SignupPointIntent.none;
  final i = step - (t.registrationOpen == false ? 1 : 0);
  if (i < 0) return SignupPointIntent.none;
  if (mastodon) {
    return switch (i) {
      0 => SignupPointIntent.rules,
      1 => SignupPointIntent.accountFields,
      _ => SignupPointIntent.none,
    };
  }
  return switch (i) {
    0 => SignupPointIntent.openSignup,
    1 => SignupPointIntent.accountFields,
    2 => SignupPointIntent.extraFields,
    3 => SignupPointIntent.agreement,
    _ => SignupPointIntent.none,
  };
}

/// SNS ごとの見つけ方(Mastodon はサーバーが出す HTML のフォームの name、Misskey 系は画面の `data-cy-*` の印)。
SignupPointSpec? signupPointSpec(ServerSignupTarget t, SignupPointIntent intent) {
  if (_isMastodon(t)) {
    return switch (intent) {
      SignupPointIntent.rules => const SignupPointSpec(
          selectors: ['a.button[href*="accept="]', '.stacked-actions .button', 'form[action*="/auth/sign_up"] .actions button'],
          text: r'^(同意する|同意して|Accept|I agree)', // l10n-ignore
        ),
      SignupPointIntent.accountFields => const SignupPointSpec(selectors: [
          'input[name="user[account_attributes][display_name]"]',
          'input[name="user[account_attributes][username]"]',
          'input[name="user[email]"]',
          'input[name="user[password]"]',
          'input[name="user[password_confirmation]"]',
          'input[name="user[agreement]"]',
          'form#new_user button[type="submit"]',
        ]),
      SignupPointIntent.login => const SignupPointSpec(selectors: [
          'form[action*="/auth/sign_in"] input[name="user[email]"]',
          'form[action*="/auth/sign_in"] input[name="user[password]"]',
          'form[action*="/auth/sign_in"] button[type="submit"]',
        ]),
      SignupPointIntent.authorize => const SignupPointSpec(selectors: ['form[action*="/oauth/authorize"] button[type="submit"]:not(.negative)'], text: r'^(承認|許可|Authorize)'), // l10n-ignore
      _ => null,
    };
  }
  return switch (intent) {
    SignupPointIntent.openSignup => const SignupPointSpec(selectors: ['[data-cy-signup]'], text: r'^(新規登録|アカウント作成|Sign ?up)'), // l10n-ignore
    SignupPointIntent.accountFields => const SignupPointSpec(selectors: [
        '[data-cy-signup-username] input',
        '[data-cy-signup-password] input',
        '[data-cy-signup-password-retype] input',
        '[data-cy-signup-submit]',
      ]),
    SignupPointIntent.extraFields => const SignupPointSpec(selectors: [
        '[data-cy-signup-email] input',
        '[data-cy-signup-invitation-code] input',
        '.h-captcha',
        '.g-recaptcha',
        '.cf-turnstile',
        'iframe[src*="captcha"]',
      ]),
    SignupPointIntent.agreement => const SignupPointSpec(selectors: ['[data-cy-signup-rules-notes-agree]', '[data-cy-signup-rules-continue]'], text: r'(同意する|Agree)'), // l10n-ignore
    SignupPointIntent.login => const SignupPointSpec(selectors: ['[data-cy-signin-username] input', '[data-cy-signin-password] input', '[data-cy-signin-page-input] input', '[data-cy-signin-page-password-continue]'], text: r'^(ログイン|Sign ?in)$'), // l10n-ignore
    SignupPointIntent.authorize => const SignupPointSpec(selectors: ['[data-cy-miauth-allow]'], text: r'^(許可|Allow|Accept)'), // l10n-ignore
    _ => null,
  };
}

/// ページに流す JavaScript。[spec] = null なら前の枠を消すだけ。
/// 返り値(ページの中): 見つけた数(0 なら、10 秒まで探し直す)。
String signupPointScript(SignupPointSpec? spec) => '''
(function(cfg){
  var CLS='__rasq_point';
  if(!document.getElementById('__rasq_point_style')){
    var st=document.createElement('style');st.id='__rasq_point_style';
    st.textContent='.__rasq_point{outline:3px solid #ff6b3d !important;outline-offset:3px !important;animation:__rasq_pulse 1.2s ease-in-out infinite !important}'+
      '@keyframes __rasq_pulse{0%,100%{box-shadow:0 0 0 0 rgba(255,107,61,.6)}50%{box-shadow:0 0 0 10px rgba(255,107,61,0)}}';
    (document.head||document.documentElement).appendChild(st);
  }
  if(window.__rasqPointTimer){clearInterval(window.__rasqPointTimer);window.__rasqPointTimer=null;}
  Array.prototype.forEach.call(document.querySelectorAll('.'+CLS),function(e){e.classList.remove(CLS);});
  if(!cfg) return 0;
  function visible(e){var r=e.getBoundingClientRect();return r.width>0&&r.height>0;}
  function find(){
    var out=[];
    (cfg.selectors||[]).forEach(function(s){try{Array.prototype.forEach.call(document.querySelectorAll(s),function(e){if(visible(e)&&out.indexOf(e)<0)out.push(e);});}catch(_){}});
    if(cfg.text){
      var re=new RegExp(cfg.text,'i');
      Array.prototype.forEach.call(document.querySelectorAll('button,a,[role="button"],label'),function(e){
        var t=(e.innerText||e.textContent||'').trim();
        if(t&&t.length<40&&re.test(t)&&visible(e)&&out.indexOf(e)<0)out.push(e);
      });
    }
    return out;
  }
  function mark(){
    var els=find();
    if(!els.length) return 0;
    els.forEach(function(e){e.classList.add(CLS);});
    try{els[0].scrollIntoView({block:'center',behavior:'smooth'});}catch(_){}
    return els.length;
  }
  var n=mark();
  if(n) return n;
  var tries=0;
  window.__rasqPointTimer=setInterval(function(){tries++;if(mark()||tries>=20){clearInterval(window.__rasqPointTimer);window.__rasqPointTimer=null;}},500);
  return 0;
})(${spec == null ? 'null' : jsonEncode(spec.toJson())});
''';

/// いまの手順 / ページで指す(見つからなくても、失敗しても何もしない)。
Future<void> pointSignupPage(WebJsRunner runner, ServerSignupTarget t, int step, int stepCount, {Uri? url}) async {
  final spec = signupPointSpec(t, signupPointIntent(t, step, stepCount, url: url));
  try {
    await runner.runJavaScript(signupPointScript(spec));
  } catch (e) {
    debugPrint('signup point: $e');
  }
}
