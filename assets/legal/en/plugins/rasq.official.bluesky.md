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
