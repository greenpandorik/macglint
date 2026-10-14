# Contributing to MacGlint

MacGlint is a personal, AI-assisted project with a buildable native preview. An Apple-notarized public release is still pending. Feedback in **English or Russian** is welcome.

## Useful feedback right now

- A real monitoring problem you want to solve on your Mac.
- A confusing label, interaction, or layout in a specific mockup.
- Evidence about reliable Safari tab-to-process attribution, with a reproducible example and macOS/Safari versions.

Use [Issues](https://github.com/greenpandorik/macglint/issues/new/choose) and describe the problem before proposing a feature. Check existing issues to avoid duplicates. Keep each suggestion focused on one topic.

## Documentation changes

Small corrections can be sent as pull requests. Keep the English and Russian READMEs consistent when changing product scope or status. Verify relative links and clearly label concepts, assumptions, and verified behavior.

For code changes, run `swift test` and `./scripts/build-app.sh` on macOS. Explain validation and meaningful limitations in your pull request. Discuss larger feature or architecture changes before implementing them. Follow [AGENTS.md](AGENTS.md), especially process identity checks and privacy.

## Data and AI assistance

Use synthetic examples. Do not post private browsing URLs, tokens, unredacted process dumps, or other people's data.

AI-assisted contributions are welcome. Describe what changed and how it was checked. Generated output still needs human-readable reasoning and verification; do not present a planned feature as implemented.

---

По-русски: сейчас особенно полезны конкретные сценарии использования, замечания к макетам и проверяемые сведения о Safari. Пишите в Issues на удобном языке. Для больших изменений сначала обсудим задачу; небольшие исправления документации можно присылать сразу.
