# Privacy page follow-up for version 1.2

The supplied [privacy page](https://apps.transfinite.us/ai-assistant/privacy-policy) returned HTTP 200 on October 12, 2026. Its AI processing section and summary describe Ari as using on-device AI only. Version 1.2 also offers explicitly enabled Apple Private Cloud Compute. The website is outside this app repository and has not been edited.

Suggested replacement for the Ari AI processing section:

> Ari uses Apple's Foundation Models framework. AI runs on your device by default. If you enable “Use Private Cloud Compute” in Ari's Settings, future chats, output transformations, and library summaries use Apple's Private Cloud Compute instead. Your request, relevant recent conversation context, and any attached or selected source text used for that request are sent to Apple for processing. This requires an internet connection and is subject to Apple's separate usage limits.
>
> The processing choice is saved on the device where you make it. Enabling it on one device does not enable it on your other devices. You can turn it off in Ari's Settings to use on-device AI for future requests. Ari does not silently send requests to Private Cloud Compute when on-device processing is unavailable.
>
> Imported PDFs and images are processed on-device to extract text. If you use that text in an AI request while Private Cloud Compute is enabled, the relevant extracted text is included in the request sent to Apple. Ari does not use OpenAI, Anthropic, Google, or another third-party AI provider for inference.

Also update the summary and app-specific appendix entries that currently say AI processing is on-device only. Suggested wording: “AI runs on-device by default, with optional Apple Private Cloud Compute when explicitly enabled in Ari's Settings.” Preserve the separate CloudKit storage/sync and StoreKit purchase disclosures.

This draft describes the implemented data flow. It does not verify a live PCC request, alter the website, or make claims about Apple's retention or security guarantees.
