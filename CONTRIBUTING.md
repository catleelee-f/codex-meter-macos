# Contributing

Issues and pull requests are welcome.

Before opening a pull request:

1. Keep changes focused and avoid unrelated refactors.
2. Run `./scripts/build.sh`.
3. Run `./scripts/test-parser.sh` when local Codex session logs are available.
4. Do not commit Codex logs, authentication files, tokens, or other personal data.

When changing the JSONL parser, preserve compatibility with missing, single, and multiple rate-limit windows.
