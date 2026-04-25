# luban-skills workspace

`luban-skills` is a complex-task execution coaching skill for turning vague, multi-step user requests into structured, trackable, and verifiable delivery workflows.

中文描述：鲁班 Skills 是面向普通用户的复杂任务执行教练，把一句模糊需求拆成可执行、可追踪、可验收的交付流程，让 AI 从“给建议”升级为“交付结果”。

荣誉：鲁班 Skills 获得企鹅线下虾友线下赛第一名。

The core idea is simple: define the deliverable first, build the smallest verifiable loop, then expand safely.

## Repository layout

```text
.
├── luban-skills/              # Main skill, scripts, references, examples, and tests
├── image/                     # Open-source demo image assets and validation metadata
├── luban-skills-share.html    # Static share/demo page
├── README.md                  # Repository overview
├── LICENSE                    # MIT License
├── CONTRIBUTING.md            # Contribution guide
├── SECURITY.md                # Security reporting and secret-handling policy
└── pyproject.toml             # Python test configuration
```

## What is luban-skills?

`luban-skills` helps AI agents handle tasks that require planning, staged execution, and final deliverables instead of one-shot answers.

Typical use cases include:

- writing emails, reports, plans, and announcements
- organizing notes, documents, and action items
- analyzing options, risks, or tables
- planning long-running multi-step work
- coordinating image-generation tasks that must produce actual files

## Quick start

```bash
cd luban-skills
bash scripts/doctor.sh
```

Run the minimal demo:

```bash
bash scripts/run_min_demo.sh
```

Run task classification:

```bash
bash scripts/classify_task.sh "帮我根据这份资料写一封沟通邮件"
```

Run tests from the repository root:

```bash
python3 -m pytest luban-skills/tests
```

## Using a task card

Copy the example task card and edit it for your workspace:

```bash
cd luban-skills
cp examples/task-card-example.yaml /tmp/my-task.yaml
bash scripts/dispatch_acp.sh start /tmp/my-task.yaml
```

Use placeholders such as `<workspace>` or local paths in your private task cards. Do not commit task cards that contain private data, webhook URLs, tokens, or credentials.

## Demo assets

The `image/` directory is included as open-source demo material. It contains generated images and validation metadata that illustrate multi-frame image delivery workflows. These files are not required for running the core scripts.

`luban-skills-share.html` is a static share/demo page for the project.

## Security and secrets

Do not commit:

- `.env` files
- real `FEISHU_WEBHOOK_URL` values
- API keys, tokens, passwords, or private credentials
- private workspace paths or personal data

See [SECURITY.md](SECURITY.md) for reporting and handling guidance.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and checks to run before opening a pull request.

## License

This repository is released under the [MIT License](LICENSE).
