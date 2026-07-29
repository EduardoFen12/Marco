# Markstone — spec migrada para o GitHub Spec Kit

Este arquivo era a spec monolítica do projeto. Em 29/07/2026 o repo passou para
o layout do [GitHub Spec Kit](https://github.com/github/spec-kit) (v0.14.4) e o
conteúdo foi para:

| Antes (seção do SPEC.md) | Agora |
|---|---|
| 1, 3 — visão geral e funcionalidades | [`specs/001-markstone/spec.md`](specs/001-markstone/spec.md) |
| 2 — modelo de dados | [`specs/001-markstone/data-model.md`](specs/001-markstone/data-model.md) |
| 4 — stack técnico | [`specs/001-markstone/plan.md`](specs/001-markstone/plan.md) |
| 5 — processo de implementação (SDD) | [`.specify/memory/constitution.md`](.specify/memory/constitution.md) |
| 6 — tasks (T1–T43) | [`specs/001-markstone/tasks.md`](specs/001-markstone/tasks.md) |
| 7 — em aberto (decisões, achados, pendências) | [`specs/001-markstone/research.md`](specs/001-markstone/research.md) |

Trabalho novo entra como uma feature nova (`/speckit-specify` → `/speckit-plan`
→ `/speckit-tasks` → `/speckit-implement`), numerada `002-…` em diante. O
histórico completo deste arquivo continua no git.
