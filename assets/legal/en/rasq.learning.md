> **Reference translation.** This is a reference translation provided for convenience. The Japanese version is the official text, and if there is any difference between them, the Japanese version governs.

**Acceptance of data provision for training is closed until the Operator announces its start.** Use of RASQ, use of ASTell, use of RAi, and purchase of plugins are not treated as consent to provide data for training. The default is "Do not provide." Declining or withdrawing does not change the conditions for using ordinary features or paid features.

### 1. Purpose

Provided data is used to improve the relevance determination, classification, and ranking of the Relational Timeline (a feature that arranges related posts as conversation groups), and the accuracy of RAi's operation guidance. It is not used for training RAi's general-purpose conversation, for evaluating emotions or persons, or for advertising. Training used for ASTell's emotion analysis and entry decisions is not included in this choice and is a separate choice.

### 2. Who Is Eligible

Persons aged 16 or older are eligible. Persons aged 16 and 17 also need the consent of a guardian. Age and guardian consent are also checked on the RASQ public server. Data is not sent from devices under monitoring (Child Safe).

### 3. Scope of Provision

There are two scopes of provision: "Standard" and "Extended." The Operator decides which scope is accepted and displays it on the consent screen. When accepting in the Extended scope, the Operator will announce this in advance and ask again for consent to the Extended scope. Data from persons who consented only to the Standard scope will not be used in the Extended scope.

**Standard scope**

- Public posts written by the consenting person themselves, and judgments of whether those posts are related to one another (correct labels).
- Limited to posts from SNS accounts confirmed to belong to that person. Posts from accounts whose ownership has not been verified are not accepted.

**Extended scope** (in addition to the Standard scope)

- Public posts by other persons that were placed in the same conversation group in the Relational Timeline.
- Your own questions to RAi and RAi's answers (operation steps and function names). Posts by other persons are not included.
- Results of judgments by the AI on the RASQ public server about links between posts that the device could not decide on (whether they are the same conversation or different conversations).

**Handling of posts by other persons (Extended scope):** Posts by other persons are accepted only after checking, for each author, whether they may be used for training.

1. They are not used if the author indicates in their profile that their content is "not to be used for AI training," if there is a marker such as #NoAI, or if the author has set themselves to be excluded from search or collection.
2. Otherwise, the author's bio, profile fields, and some of their public posts (up to 3) are passed to the AI on the RASQ public server, which determines whether an intention to refuse use for training can be read from them. If an intention to refuse can be read, or if no determination can be made, they are not used.
3. If a conversation group contains even one post by an author whose posts cannot be used, that group is not accepted.

This check is intended to exclude posts by persons who have indicated refusal. The absence of a refusal indication is not regarded as that person's affirmative consent. Authors of posts, even if they are not RASQ users, can contact the contact point to request exclusion and deletion of their posts. Judgment results are stored on the RASQ public server and are re-judged after 30 days or when the profile changes.

### 4. What Is Not Included

DMs, limited-visibility posts such as followers-only posts, ASTell conversations, quoted portions of other persons' posts, and reposted images are not included in either scope. A label linking two posts is used only when both posts meet the eligibility conditions.

### 5. Processing Before Sending

@mentions and URLs in the body text are masked on the device before sending. Even when masked, the data is managed as personal information while it remains linked to an SNS account. We do not describe it as "anonymized."

### 6. Retention Period and Models

| Subject | Retention period |
|---|---|
| Provided data and correct labels | Up to 5 years from the acquisition of each item of data. The acquisition date is not renewed by retraining |
| Records of judgments (checks on other persons' posts) | 90 days from the judgment |
| Records of which data was used for which model version | Until distribution of the corresponding model ends |

Trained models may be distributed to devices. The provided data itself is not distributed.

### 7. Withdrawal and Deletion

- You can withdraw at any time from the training screen. You can do so even while acceptance is closed. You can withdraw only the provision for training while keeping your RASQ account.
- A withdrawal code is issued when you consent. Even if you can no longer access your RASQ account, you can withdraw with this code.
- Upon accepting a withdrawal, new acceptance and input into training are stopped immediately, and data already provided is deleted. Evaluation and derived data are also deleted within 30 days.
- Existing models will be rebuilt from the data after exclusion at the next regular update. If a problem is found, such as personal information being reproduced, distribution will be stopped and the model replaced without waiting for an update. We cannot promise to recall all old models already distributed to devices.
- If you delete your RASQ account, provision for training is withdrawn at the same time, and the same deletion as above begins.
- You can check the status of your own provision on the training screen after identity verification.
