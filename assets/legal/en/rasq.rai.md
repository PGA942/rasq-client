> **Reference translation.** This is a reference translation provided for convenience. The Japanese version is the official text, and if there is any difference between them, the Japanese version governs.

### Article 1　Role of RAi

RAi provides guidance on operating RASQ, answers to questions, drafts of text, and assistance with operations specified by the user. Answers and suggestions may contain errors, inaccurate sources, or outdated information. Please check the content before executing, posting, or using it. For important decisions such as medical, legal, or investment matters, please also check with appropriate professionals or primary sources.

RAi's answers do not change RASQ's official terms or decisions by the Operator. The official conditions can be checked in the terms, on purchase screens, and in notices from the Operator.

### Article 2　On-Device Processing and Off-Device Processing

RAi generates answers and searches operations using the available on-device models. For off-device processing, there are the following independent settings.

| Setting | Content sent | When used |
|---|---|---|
| Generate answers on an inference server | Questions, instructions and operation references necessary to create answers, and reference information the user has confirmed for sending | When an answer cannot be generated on the device and the user has permitted this transmission |
| Search operations on a server | Questions and search terms, and short search information representing screens and operations | When the on-device search model is unavailable and this transmission has been permitted |
| Web search | Search terms or questions | When the user has enabled web search and has instructed or confirmed that search |

The inference server provided by the Operator (cloud RAi) runs on the RASQ public server. Brave Search is used for web search. Web search is off by default.

In the initial guidance (onboarding), cloud RAi is used to find servers and people that may suit you. Selected images, the body text of opened pages, the text of consultations, and, if you permit screen reading, images of the screen are sent. Before sending, the content is shown on that screen. Images and consultation text are not stored. Ads may be displayed while waiting for cloud RAi processing.

The name and connection destination of the recipient, the content sent, and the conditions regarding storage and use for training are displayed before the feature is enabled. If you specify an inference server yourself, please also check that provider's conditions. Even with a server on the same network or your own server, data may be sent off the device.

RAi will not switch to a recipient you have not approved solely because the on-device model has become unavailable. Before sending personal or confidential information contained in a question to an external party, please check the content to be sent. The ordinary license to use does not include permission to provide questions or conversations for training AI models.

### Article 3　Reference Information and Execution of Operations

To answer, RAi may retrieve SNS posts or information on the screen being displayed. When RAi uses that information for off-device inference, it shows the target data and the recipient and asks for confirmation. It cannot be used for operations that share information disclosed only to specific persons with persons who lack permission.

Operations that change state, such as changing settings, following, editing lists, and creating rooms, are performed to the extent the user chose to execute them, after showing the target account, the changes, and the necessary data transmission. If the target or the content of the operation changes partway through, confirmation is requested again. A plan created by RAi or text obtained from outside alone is not treated as the user's approval.

For posts, replies, and DMs, RAi creates only a draft before sending, and the user confirms the content and recipient on the sending screen to finalize it. Even if processing is canceled, changes already completed are not necessarily reverted automatically. Completed operations and failed or unexecuted operations are displayed on the results screen.

### Article 4　History, Models, and External Services

The history of RAi questions and answers is stored on the device in use and can be deleted from the history screen. Information already sent to off-device processing is subject to the storage and deletion conditions displayed for that processor. Deleting history alone does not necessarily delete information already sent to that processor.

On-device models are downloaded from Hugging Face, GitHub, or the RASQ public server. The device's IP address and similar information are disclosed to the download source. The name, provider, and license of each model can be checked on the "Licenses" screen. Downloading on-device models uses data traffic and storage capacity. Available features and device requirements are displayed on each screen. If you use inference or search services you have contracted for yourself, charges may arise from those services. Please choose enabling external inference and purchasing paid contracts for ASTell, plugins, etc. on their respective screens.
