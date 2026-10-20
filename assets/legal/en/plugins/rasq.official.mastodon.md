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
