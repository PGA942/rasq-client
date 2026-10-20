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
