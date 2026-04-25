# Contributing

Thanks for your interest in improving `luban-skills`.

## Development setup

This repository is script-first. The main requirements are:

- Bash
- Python 3.10+
- `pytest` for tests

Run checks from the repository root:

```bash
python3 -m pytest luban-skills/tests
```

Run skill self-checks:

```bash
cd luban-skills
bash scripts/doctor.sh
bash scripts/run_min_demo.sh
```

## Pull request checklist

Before opening a pull request, confirm that:

- tests pass
- `bash scripts/doctor.sh` passes
- examples use placeholders rather than private absolute paths
- no `.env` files are included
- no real webhook URLs, tokens, passwords, API keys, or credentials are included
- generated demo assets do not contain private prompts, local-only paths, or personal data

## Documentation style

Prefer concrete examples and small, verifiable workflows. When a command depends on a local workspace, use placeholders such as `<workspace>` or `/path/to/workspace`.

## Demo assets

Generated assets under `image/` may be contributed when they are useful examples and can be released under the repository MIT License. Include enough context for readers to understand what the assets demonstrate.
