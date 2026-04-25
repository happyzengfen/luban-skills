# Security Policy

## Reporting security issues

Please do not disclose security issues in public issues if they include secrets, credentials, private webhook URLs, or other sensitive data.

Open a private report through the hosting platform's security advisory flow when available, or contact the repository maintainer through a private channel.

## Secret handling

Never commit:

- `.env` files
- real `FEISHU_WEBHOOK_URL` values
- API keys or bearer tokens
- passwords or private credentials
- private keys or certificates
- private workspace paths that expose internal systems or personal data

Use environment variables or local `.env` files for private configuration. This repository's `.gitignore` excludes `.env` and `.env.*` files by default.

## Feishu webhook configuration

`luban-skills` can send Feishu webhook notifications through `FEISHU_WEBHOOK_URL`. Keep real webhook URLs local. Documentation and examples should use placeholders or fake URLs such as `https://example.com/dryrun` only.

## Supported versions

Security fixes target the current main branch unless a separate release branch is explicitly maintained.
