# 开发流程纪律

所有迭代必须遵循，无例外。流程为单人 + AI 协作设计。产品领域语言见 [CONTEXT.md](./CONTEXT.md)，架构决策见 [docs/adr/](./docs/adr/)。

## 变更路径

- 一切变更走 PR 进 main，禁止直推（分支保护强制，对管理员同样生效）。
- 一个 PR 只做一件事。
- 分支命名 `type/short-desc`（英文），如 `feat/hover-icon`、`fix/ax-timeout`。
- 仅 squash merge，合并后分支自动删除；PR 标题即 main 上的永久提交信息。

## 提交规范（= PR 标题规范）

- 全英文 Conventional Commits：`type(scope): description`。
- type 限定：`feat` `fix` `refactor` `docs` `build` `chore` `ci`（需要时再扩 `perf` `test`）。
- scope 用 `extension` 或 `macos`；跨两端或仓库级变更省略。
- 语言分工：PR 标题英文；PR 正文、Issue、CONTEXT.md、ADR 用中文（工作语言）。

## Issue 纪律

- Issue 是项目的外置记忆：当下不做的想法、顺手发现的 bug，必须当场记成 Issue，不许留在脑子里或代码 TODO 注释里。
- `feat` 必须先有规格 Issue：写清需求与验收标准（「做完的样子」清单），PR 用 `Closes #N` 关联，验收逐项核销后才算完。
- 其余类型（`fix`/`refactor`/`docs`/`chore`/`build`/`ci`）不强制关联 Issue。

## PR 纪律

- 按模板填「背景」与「验证」；UI 变更附截图或 GIF。
- 每个 PR 自查两问：
  1. 本次变更引入/改变了领域术语吗？是 → 更新 CONTEXT.md。
  2. 做了难以逆转、事后费解的取舍吗？是 → 补一条 docs/adr/。
- CI 绿才能合：extension 跑 `pnpm compile` + `pnpm build`，macos 跑 `swift build`，按路径过滤。

## 明确不做的事（及触发条件）

- **不设发布流程**，版本号冻结，main 即产品。触发条件：出现真实分发渠道（上架 Chrome Web Store 或公证的 macOS 安装包）之日，那次迭代建立发布纪律。
- **不设 lint 与测试门禁**。各自作为独立迭代引入，引入之日加入 CI。
- **不写 CONTRIBUTING.md**。触发条件：出现外部贡献者时从本文件提炼。
