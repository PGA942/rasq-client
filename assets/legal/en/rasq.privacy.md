> **Reference translation.** This is a reference translation provided for convenience. The Japanese version is the official text, and if there is any difference between them, the Japanese version governs.

Document ID: `rasq.privacy` / Version: ［official version number］ / Effective date: ［date］

### 1. Operator and Scope

Mikihisa Goho (the "Operator") handles information as described below in the RASQ app, RASQ accounts, ASTell, RAi, Swing, the Plugin Store, public web pages, and other features provided by the Operator. For the time being, the Operator runs the service as an individual.

- Operator: Mikihisa Goho (individual)
- Address: 〒530-0001 大阪府大阪市北区梅田1丁目2番2号 大阪駅前第2ビル12-12
- Contact for personal information: ［email address or form URL］
- List of external recipients and contractors: ［public URL］ (contains the same content as the table in Section 8, together with the date of update)

The Operator runs two kinds of servers with different roles.

| Server | Main role |
|---|---|
| RASQ public server (Central) | Public pages for profiles and posts, ASTell, Swing, the Plugin Store, RAi cloud processing, onboarding search, receipt of reports |
| RASQ personal server (ORGATE) | Login, email and device management, custody of SNS login information and the vault, sync, notifications, payments and points |

Where this policy says "RASQ servers," it refers to both. Information handled by only one of them is identified by that server's name. Only the information necessary for identity verification and the provision of features is exchanged between the two servers.

The handling of information by connected SNSs, third-party plugins, and operators of inference servers specified by users is also subject to their respective policies. What RASQ sends to them is explained in this policy and on the confirmation screen of each feature. If you change the server RASQ connects to, please check the operator and the policy of that server.

### 2. Purposes of Handling Information

The Operator handles information to the extent necessary for the following purposes.

1. Login, identity verification, device management, saving settings, and providing the integration and sharing features chosen by users.
2. Providing posting, calls, sharing, search, notifications, assistive features, and the Plugin Store.
3. Purchases, granting usage rights, payment reconciliation, refunds, responding to inquiries, and managing records required for accounting and by law.
4. Responding to unauthorized access, violations of the terms, and infringement of rights, reviewing appeals, and ensuring the safety of the service.
5. Protecting minor users and providing monitoring features for Guardians.
6. Detecting and investigating failures, and maintaining performance and quality.
7. Displaying advertisements to cover the costs of the parts provided free of charge (Section 8-2).

Private conversations and limited-visibility posts are not used for ad targeting. Processing that uses information for a model's answers or classification is distinguished from processing that accumulates information as training data for a model. Providing data for training is governed by Section 10.

### 3. Information Stored on the Device

In the native versions, SNS login information, settings, drafts, RAi conversation history and achievements, Timeline customizations, muted ads, aggregates used to display posting tendencies, and similar data are stored on the device. SNS login information is stored in the secure storage area of the OS (Keychain on iOS and macOS, encrypted storage on Android).

The following processing is performed only on the device, and its results are not sent to RASQ servers: detection of duplicate posts, estimation of interests for each Account, prediction of Reactions and ordering, RAi usage statistics, and classification and summarization by on-device models.

For features in which the user sends or syncs data, features that use server processing, and the login information vault of the web version, the information described in the following sections is sent off the device. Not all information on the device uses the same encryption method or the same storage location.

Data on the device can be managed by deleting history in the app, logging out, and similar actions. Deleting an account and deleting local data on each device are separate operations. Data included in OS backups is also subject to how those backups are managed.

### 4. SNS Credentials and Account Integration

An SNS access token is a credential used to perform operations on an SNS. RASQ distinguishes the following routes.

| Feature / condition of use | Recipient and handling | Stopping / revoking |
|---|---|---|
| Ordinary SNS use | The content and credentials necessary for posting, viewing, Reactions, following, etc. on the selected SNS are sent directly from the device to that SNS | Log out of or disconnect the SNS. Posts and other content already sent to the SNS are managed by the SNS |
| Mastodon authentication brokering | The RASQ personal server registers the RASQ app with the destination server, exchanges the authorization code for a token, and returns it to the app. Tokens are not stored solely because of this brokering | Cancel authentication, or revoke the integration on the SNS side. Temporary records of the authentication process are deleted after 1 day |
| Sharing SNS login information between devices (optional) | Login information encrypted on the device is stored on the RASQ personal server so that it can be shared among approved devices. The shared content is decrypted with the keys of approved devices, and the Operator cannot decrypt it | Stop sharing and manage devices from "Account security." Tokens already passed to another device before stopping are not automatically invalidated on the SNS side |
| Login information vault of the web version | When you log in to your RASQ account and use an SNS in the web version, login information is sent to the vault on the RASQ personal server and read back when needed. It is encrypted with the server's key when stored. This method allows the Operator's server to decrypt it | Log out of the SNS in the web version, delete the vault, or delete the RASQ account |
| Displaying SNS posts on the account page (optional) | For SNSs you consented to on the confirmation screen, the RASQ personal server receives the access token and stores it encrypted with the server's key. Your posts eligible for display are retrieved from the target SNS and displayed on your public RASQ account page. For Bluesky, only the account identifier is held instead of a token, and the information is retrieved from public information | Revoke the custody for post display, disconnect the SNS, or delete the RASQ account |
| Retrieval for RASQ lists and clips (optional) | You can separately choose to also use the token held for post display to retrieve the profiles and posts of accounts you have added to RASQ lists or clips, and to check follow relationships | Stop this use on the Settings screen, or revoke the custody |

Custody for post display is a choice separate from sharing between devices and the web version vault. With this feature, posts on the selected SNS that correspond to "Public" and "Home / Unlisted" are made **viewable by anyone on the RASQ account page**. Followers-only posts, direct/DM posts, local-only posts, and posts whose Visibility cannot be confirmed are not included. "Home / Unlisted" does not mean followers-only.

Held tokens are not used for write operations such as posting or following. They are also not used for any purpose other than those chosen in the table above.

**Bundled account display:** The type of SNS being linked, the server, the account identifier, display information, and the result of ownership verification are used. For ownership verification, the RASQ public server reads the public profile on that SNS and checks whether the verification string is present. If you choose verification via Keybase, Keybase's public information is also read. By default, linked SNS accounts are displayed on your RASQ profile, making it possible to find your RASQ account from your SNS accounts. You can choose not to display them on the profile editing screen.

### 5. Main Information Stored on RASQ Servers

| Information | Storage location | Purpose of use / scope of display |
|---|---|---|
| Handle, display name, images, bio, birthday (if entered in the public profile), location, links, posts, visibility settings, linked accounts | Public server | Providing account, profile, and posting features. Displayed to other users and on public web pages according to visibility settings |
| Password hash, email address, two-factor authentication settings, device identifier and name, last-used IP address, User-Agent, login date and time | Personal server | Authentication, account protection, device list, login notifications, identity verification |
| Type of consent, document version, date and time, age range, and record of guardian consent | Public server | Confirming terms of use and choices made, restricting features, responding to inquiries |
| Settings chosen for sync, plugin installation information, customizations, data for sharing | Personal server | Saving, restoring, and sharing between devices. The encryption method is indicated for each feature |
| Lists, clips, Bookmarks, Store reviews, and the profiles and posts (up to 200) of other accounts added to lists | Public server | Providing the features and displaying them with the selected visibility |
| Swing posts, images and videos, view counts, read records | Public server | Providing Swing (Section 6) |
| Notification destinations (including Android notification tokens), notification settings, notification titles and bodies | Personal server | Delivering notifications enabled by the user. With notification tokens issued for macros or ASTell, you can receive notifications addressed to yourself from other features |
| Product and order identifiers, price and currency, purchase date and time, payment status, payment provider transaction identifiers, granting, use, and expiration of points, usage rights, records of refunds, cancellations, and inquiries | Personal server | Payment processing, preventing duplicate grants, restoring purchases, refunds, accounting, preventing fraudulent use |
| Reports and appeals, related posts and shared content, results of handling | Public server | Investigating and re-reviewing violations of the terms, infringement of rights, and safety issues |
| Intensity threshold (if you chose to make it public), trend restrictions imposed by the Operator | Public server | Displaying posting tendencies and restricting display |
| Developer application details, signing keys, distributions and source code submitted for review, records of review fees | Public server and personal server | Review, distribution, and settlement of plugins (Section 6) |

**Payments:** During the public test period, purchases of points, paid plugins, and paid offerings of ASTell and the plugin proxy are not provided. The only payments during this period are review fees paid by plugin developers. Stripe is used for payments. Payment information such as card numbers is entered on Stripe's screen, and the Operator does not receive it. The Operator sends Stripe the amount, the type of product, and an identifier for reconciling the order. The Operator receives the payment status and the transaction identifier from Stripe.

### 6. ASTell, RAi, Swing, Plugins, Monitoring, Onboarding

**ASTell:** Room information, participation information, shared posts, text, and files, transcriptions, etc. are used to provide the selected features. The destinations of audio and video connections, the destinations to which transcription data is sent, and the scope visible to participants are set out in the ASTell terms of use. Turning off caption display is distinguished from stopping the sending and processing for transcription. For safety management and investigation of reports, authorized operations staff may review shared content and other information to the extent necessary.

In rooms where the host has enabled "Refuse entry to trolls," the Operator's judgment system analyzes, for a person trying to enter, their bio on RASQ, Store reviews, shares and transcriptions in ASTell (up to 200 items), and thumbnails of images (up to 50 items), and decides whether to allow entry. Content shared in ASTell by a person subject to usage restrictions is checked by the same system before it is displayed. When the judgment system is unavailable, checking switches to a word list.

**RAi:** Processing by on-device models, the inference server for answers, the embedding server for search, and web search are each separate transmission routes. When external processing is used, the recipient, purpose, and target data are shown in advance. Questions, operation references, retrieval results necessary for answers, and similar information may be subject to processing. If you do not permit external transmission, you can use the features available on the device. On-device models are downloaded from Hugging Face, GitHub, or the RASQ public server. The device's IP address and similar information are disclosed to the download source.

**Swing:** Posts that disappear after 1 to 24 hours. Posts, images and videos, view counts, and records of who viewed them are stored on the RASQ public server and deleted when the time limit is reached.

**Plugins:** The information used by a plugin and its external communications can be checked in the permission descriptions and the developer's policy. The handling of features provided by the RASQ Operator and the handling by plugin developers are displayed separately. Deleting a plugin does not necessarily delete, at the same time, information already sent to the developer's server. Deletion methods follow each policy.

For plugins in which multiple users use the same screen (shared sessions), the plugin's state and the values written by participants are stored on the RASQ public server and distributed to participants. If you enable the optional diagnosis of the shape of a plugin's communications, the destination host, path, and field names are sent. Values are not sent.

**Monitoring (Child Safe):** A feature that allows a Guardian to monitor a child's use. To verify the Guardian, identity verification by the Digital Agency using a My Number Card is used. The Operator receives only whether the person is 18 or older, the country of residence, the verification method, and a hash of an identifier created from the identity verification. The card number, name, and address are not received. For a monitored child, the daily number of uses and topic headlines are delivered to the Guardian. The body text of posts is not delivered. A Guardian may also create a child's account.

**Onboarding (initial guidance):** Even before creating a RASQ account, you can use the feature to find SNS servers and people that may suit you. With this feature, the following information is sent to the RASQ public server.

- Selected images, the body text (up to 4,000 characters) and URL of a page opened in the in-app browser, and the text of consultations with RAi.
- If you permit screen reading: images of the screen for about 3 seconds after starting (up to 6 images). Screen reading takes place only when you choose to start it on the OS permission screen, and stops when finished.

The RASQ public server analyzes this information with cloud AI and, when looking for people, searches with Brave Search. Images and consultation text are kept in memory only during processing and are not stored. Screen images remaining on the device are deleted after they are sent. IP addresses are stored for 1 day to enforce usage limits.

### 7. Reports, Safety Management, and Automated Processing

In handling reports and appeals, we may review the content concerned, related times, rooms, and account information, posts made within 2 hours before and after the report, and past results of handling. To assist processing, we use classification of text and images, analysis along 8 axes of emotion, analysis of changes in posting tendencies, summaries of similar situations, and generation of proposed actions by AI. This is inference processing for the purpose of safety management of the service, and is distinguished from the optional provision of training data under Section 10.

This processing is performed by a judgment system managed by the Operator (running on a computer managed by the Operator). The judgment system retrieves the necessary information from the RASQ public server, processes it, and stores processing records on that computer. The retention period is set out in Section 9. Actions proposed by AI are applied after a human approves them. However, if the Operator has enabled automatic application, temporary restrictions with high confidence may be applied automatically. Permanent suspensions are not applied automatically.

If you report an SNS post, the report is sent to the administrator of the SNS server. The RASQ Operator does not receive that report.

Persons who can handle this information are limited to those who need it for their duties. When processing is entrusted to a contractor, the contractor, the information sent, the retention period, etc. are shown in a list. The role of automated processing and how to check the reasons for and appeal usage restrictions are set out in the Terms of Use.

### 8. External Services, Handling Outside Japan, and Security Management

The Operator uses the following external services. The countries or regions where information is processed and stored and links to each policy are published in the ［list of external recipients and contractors］.

| Provider / service | Information sent | Purpose |
|---|---|---|
| SAKURA internet (Sakura Cloud) | Information handled by RASQ servers in general | Server operation |
| Cloudflare | Communication content and IP addresses | Relaying and protecting communications |
| Google (AdMob, AdSense) | Advertising ID, IP address, device and browser information, cookies (web) | Displaying advertisements (Section 8-2) |
| Google (Firebase Cloud Messaging) | Android notification tokens, notification titles and bodies | Delivering notifications to Android |
| Google (STUN) | IP addresses of call participants | Connecting ASTell calls |
| LiveKit (streaming server set up by the Operator) ［location］ | Audio and video of streams and screen sharing, account identifiers and display names | ASTell streaming |
| ［TURN server provider］ | Call audio and IP addresses | Relaying when devices cannot connect directly |
| Servers for transcription, text-to-speech, and AI inference ［provider or set up by the Operator］ | Audio to be transcribed, text to be read aloud, RAi questions, onboarding images and text, public posts used for training eligibility checks (Section 10) | Providing each feature |
| Brave Search | Search terms | RAi web search (off by default), finding people in onboarding, checking the meaning of words in the judgment system |
| Keybase | Keybase username | Verifying ownership of SNS accounts (optional) |
| Digital Agency (identity verification using My Number Card) | Result of identity verification | Verifying Guardians for monitoring |
| Stripe | Amount, type of product, order identifier | Payments |
| Google (Cloud Firestore of Firebase and the email sending extension firestore-send-email) | Email address, email body | Confirmation and notification emails |
| Hugging Face, GitHub, jsDelivr | Device IP address | Downloading models and runtime environments |
| OpenAI (Codex) | Distributions and source code submitted by developers | Plugin review |
| Servers of connected SNSs | Retrieval of public information by the RASQ public server (server information, public profiles, public posts) | Introducing servers, verifying ownership, sharing posts to ASTell |

We do not describe the recipients collectively as "domestic only." Some of the services in the table above are provided by businesses outside Japan and process information outside Japan. For SNSs and inference servers specified by users, please also check how their administrators handle information.

The Operator implements access restrictions appropriate to the information, protection of communications, protection of credentials, supervision of staff and contractors, management of deletion, and other measures. Even for information stored in encrypted form, we distinguish between information decrypted with the Operator's keys and information decrypted only on the user's device. Except where permitted by law or in similar cases, personal data is not provided to third parties without the consent of the person concerned.

### 8-2. Advertising

RASQ covers part of the costs of the parts provided free of charge through advertising.

- **iOS and Android apps:** Using Google's AdMob, ads are displayed on the Timeline, replies, lists, clips, related Timelines, user pages, and search screens, between Swing items, and while waiting for RAi cloud processing. Google's consent screen is shown the first time, and you can choose whether to use personalized ads.
- **Web version and public web pages:** Google's AdSense is used. AdSense uses cookies. Ads are also displayed on public web pages (RASQ profile and post pages).
- **Desktop version (macOS and Linux):** Google ads are not displayed. Ads configured by the server of the connected SNS may be displayed.

Ads are not placed before or after the following content: reported posts, posts with a content warning (CW) or marked as sensitive, displays of plugins before review, and posts held by the Operator for review.

The Operator does not send DMs, limited-visibility posts, or ASTell conversations to advertising providers.

### 9. Retention Period and Deletion

Information is retained only for the period necessary for its purpose, and upon expiry of that period or a valid request for deletion, it is deleted or made unable to identify individuals. When we say anonymization, we distinguish it from processing that merely replaces identifiers.

| Category | End of retention / how to revoke |
|---|---|
| Ordinary account, integration, and sync data | The period necessary while in use. Deletion begins upon individual revocation or deletion, or upon deletion of the RASQ account |
| Tokens for post display and retrieved posts | Use stops and deletion occurs upon revocation of custody or disconnection of the SNS. Completion deadline, including retrieval and caches in progress: 7 days |
| Web version vault and sharing between devices | The scope of deletion upon logout, stopping sharing, etc. is shown on the confirmation screen. Records of approval for sharing between devices: 1 day; history of login renewals: 30 days |
| Login sessions (including IP address and User-Agent) | Expire and are deleted 180 days after last use or 365 days after starting |
| Login attempts, verification codes, temporary authentication processing (including IP addresses) | 1 day |
| Operational logs | 90 days. The type and path of requests are recorded; bodies and URL query strings are not recorded. Records of entering and leaving ASTell and shared sessions include handles |
| Notification content | 30 days. Up to 3 days while awaiting transfer from the RASQ public server to the personal server |
| ASTell shares, transcriptions, and uploads | Displayed to participants for 10 days from creation; stored internally for 30 days from creation. Deleted within 1 day after expiry. Information requiring individual preservation follows the exceptions below |
| Records of closed ASTell rooms | 30 days from closure. The time limits for shares, transcriptions, and uploads are not extended based on the room's closing date |
| Swing | 1 to 24 hours as selected at the time of posting. Images and videos not used in a post: 1 day |
| Images not used in a post | 1 day |
| Shared session values | 30 days from the end of the session |
| Daily monitoring reports | 60 days. Records of monitoring operations: 1 year |
| IP addresses used for onboarding usage limits | 1 day. Images and consultation text are not stored |
| Reports, appeals, and handling records (including processing records of the judgment system) | 1 year from the conclusion of handling. If extended due to disputes, etc., the necessary scope and end conditions are managed. Even if the reporter deletes their account, the report is retained to the extent necessary for handling |
| Contract, payment, refund, and accounting records, and records of review fees | 8 years from the end of the fiscal year of the transaction. After account deletion, retained with identifiers replaced by ones not linked to the account, and the point balance is set to 0 |
| Records of consent and withdrawal | 3 years from account deletion. Used only to prove consent and to respond to inquiries |
| Deletion records and information for preventing evasion of suspensions | 3 years. The latter is limited to the handles of permanently suspended accounts and hashes of the identifiers of devices banned from use |
| Records of training eligibility checks (Section 10) | 90 days from the check |
| Backups | Up to 35 days. The status of deletions and withdrawals is also reflected upon restoration |

You can delete your RASQ account from account management in the app or at ［deletion procedure URL］. If you cannot access the app, please contact the contact point. Upon deletion, use of ordinary data linked to the account is stopped and deletion processing is carried out. Provision of data for training is also withdrawn at the same time, and deletion of data already provided begins. The minimum information necessary for payments, refunds, legal compliance, protection of rights in pending disputes, and prevention of fraudulent use may be retained separately within the scope of the table above.

Information recorded or reshared by other users, accounts and posts on connected SNSs, and users' devices and backups are not erased merely by deleting the RASQ account. Deletion processing on the RASQ side is not an operation that deletes accounts or posts on each SNS.

### 9-2. Information about Persons Who Are Not RASQ Users

In addition to posts viewed by RASQ users on SNSs, the Operator may handle information about persons who are not RASQ users in the following situations.

- Public profiles and public posts of SNS accounts that users have added to RASQ lists or clips. These are displayed according to the visibility of the list.
- Public profiles and portions of public posts, used in the provision of data for training (Section 10) to check whether the author of a post has declined use for training.
- Search results when finding people during onboarding.

Regarding the handling of your own information, you can request deletion or suspension of use through the contact point in Section 11. Posts by persons who indicate in their SNS profile that their content is "not to be used for AI training," or who have set themselves to be excluded from search or collection, are not used for training.

### 10. Provision of Data for Training

Provision of data for training is an optional choice separate from use of RASQ. Detailed conditions are set out in "About Contributing to Algorithms and the Community." The default is "Do not provide," and you can use the ordinary features even if you decline. Acceptance is closed until the Operator announces its start.

### 11. Age, Rights of the Data Subject, and Changes

RASQ is intended for persons aged 13 or older, and minors must use it with the consent of a guardian. This is a condition of use of RASQ. We handle the information necessary to confirm age range, guardian consent, and the like. If additional identity verification is carried out, the information to be obtained, the provider, and the retention period will be explained before it is obtained.

You may request disclosure, correction, suspension of use or erasure, cessation of provision to third parties, etc. of retained personal data through the contact point. The method of identity verification, required documents, the amount of any fee, and the procedure are set out at ［request procedure URL］. If we cannot comply on the basis of law, we will explain the reason.

If the handling is changed, we will notify you of the changes and the effective date. Changes that require renewed consent or choices, such as expanding the purposes of use or the scope of optional transmissions, will be confirmed before the change. Past versions of the document will also remain available for review.
