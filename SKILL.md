---
name: codex-review
description: Claude Code 작업 후 Codex CLI에게 독립적 코드 리뷰를 요청한다. git diff를 수집하여 Codex MCP 서버로 전송하고 리뷰 결과를 한국어로 요약한다. Use when user says "코드 리뷰", "codex review", "리뷰 요청", or "/codex-review".
user-invocable: true
allowed-tools: Task
argument-hint: [deep|ask <질문>]
---

# Codex Review — Codex CLI 독립 코드 리뷰

`general-purpose` 서브에이전트에게 위임하여 현재 git 변경사항에 대한 Codex 독립 코드 리뷰를 수행한다.

## 사용법

- `/codex-review` — 기본 리뷰 (staged + unstaged 변경사항)
- `/codex-review deep` — 심층 리뷰 (아키텍처, 보안, 성능 관점 포함)
- `/codex-review ask <질문>` — 이전 리뷰에 대한 후속 질문

## 실행

`$ARGUMENTS`를 파싱하여 모드를 결정한 뒤, `Task` 도구로 `general-purpose` 에이전트를 호출한다.

### 기본 리뷰

```
Task(subagent_type=general-purpose, prompt=아래 지침 참고)
```

프롬프트:

```
Codex MCP 서버를 사용하여 현재 프로젝트의 코드 리뷰를 수행해줘.

1. git diff --cached && git diff 로 변경사항 수집
2. git rev-parse --show-toplevel && git log --oneline -5 로 프로젝트 컨텍스트 확인
3. 변경사항이 없으면 "변경사항 없음"이라고만 반환
4. ToolSearch로 "codex-bridge" MCP 도구를 로드한 뒤, mcp__codex-bridge__codex 도구를 호출하여 아래 프롬프트로 리뷰 요청:

---
You are a senior code reviewer. Review the following code changes thoroughly.

## Project Context
- Project: {프로젝트명}
- Recent commits: {최근 5커밋}

## Changes
{diff 전체}

## Review Checklist
1. Correctness: Logic errors, edge cases
2. Security: Input validation, injection risks
3. Performance: Unnecessary allocations, blocking calls
4. Maintainability: Naming, duplication, complexity
5. Best Practices: Language idioms, error handling

For each issue: Severity (🔴Critical/🟡Warning/🔵Suggestion), file+line, explanation, suggested fix.
End with overall assessment and top 3 priorities.
---

5. 결과를 한국어로 요약 정리하여 반환. threadId를 반드시 포함할 것.

출력 형식:
## Codex 코드 리뷰 결과
### 요약
{한국어 요약}
### 발견 사항
{심각도별 이슈}
### 우선 조치 사항
{Top 3}
🧵 threadId: {id}
```

### 심층 리뷰 (`deep`)

기본 리뷰와 동일하되, 리뷰 프롬프트에 추가:

```
Additionally review: Architecture (coupling), Testing (missing cases), Error Handling (failure modes), Concurrency (race conditions), API Design (backward compat). Provide architectural impact assessment.
```

또한 변경된 파일 전체를 Read로 읽어 diff와 함께 전송하라고 지시.

### 후속 질문 (`ask <질문>`)

이전 리뷰에서 받은 threadId가 있어야 한다. 없으면 먼저 `/codex-review`를 실행하라고 안내.

```
Task(subagent_type=general-purpose, prompt=아래 지침 참고)
```

프롬프트:

```
ToolSearch로 "codex-bridge" MCP 도구를 로드한 뒤, mcp__codex-bridge__codex-reply 도구를 호출해줘.
- thread_id: {이전 threadId}
- content: {유저 질문}
응답을 한국어로 정리하여 반환.
```

## 결과 표시

에이전트가 반환한 결과를 유저에게 그대로 표시한다. threadId를 기억해두고 후속 `ask` 호출에 사용한다.
