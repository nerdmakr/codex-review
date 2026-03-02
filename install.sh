#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Codex Review — Claude Code ↔ Codex 독립 리뷰 스킬 설치 스크립트
#
# 사용법: curl -fsSL <URL> | bash
#   또는: bash install.sh
# ─────────────────────────────────────────────

CLAUDE_DIR="$HOME/.claude"
SKILL_DIR="$CLAUDE_DIR/skills/codex-review"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║   Codex Review for Claude Code           ║"
echo "║   독립적 AI 코드 리뷰 스킬 설치          ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ─── 1. 사전 요구사항 확인 ───

info "사전 요구사항 확인 중..."

# Node.js
if ! command -v node &>/dev/null; then
  fail "Node.js가 설치되어 있지 않습니다. https://nodejs.org 에서 설치해주세요."
fi
ok "Node.js $(node -v)"

# npm
if ! command -v npm &>/dev/null; then
  fail "npm이 설치되어 있지 않습니다."
fi
ok "npm $(npm -v)"

# Claude Code CLI
if ! command -v claude &>/dev/null; then
  fail "Claude Code CLI가 설치되어 있지 않습니다. npm install -g @anthropic-ai/claude-code"
fi
ok "Claude Code CLI 확인"

# ─── 2. Codex CLI 설치 ───

echo ""
if command -v codex &>/dev/null; then
  ok "Codex CLI 이미 설치됨 ($(codex --version 2>/dev/null || echo 'version unknown'))"
else
  info "Codex CLI 설치 중..."
  npm install -g @openai/codex
  if command -v codex &>/dev/null; then
    ok "Codex CLI 설치 완료"
  else
    fail "Codex CLI 설치 실패"
  fi
fi

# ─── 3. Codex OAuth 로그인 ───

echo ""
info "Codex 인증 상태 확인 중..."

# codex auth 상태 확인 — config 파일 존재 여부로 판단
CODEX_CONFIG="$HOME/.codex/config.toml"
if [ -f "$CODEX_CONFIG" ]; then
  ok "Codex 설정 파일 존재 ($CODEX_CONFIG)"
else
  warn "Codex 인증이 필요합니다."
  echo -e "  ${CYAN}아래 명령으로 OAuth 로그인을 진행하세요:${NC}"
  echo ""
  echo -e "    ${BOLD}codex --full-setup${NC}"
  echo ""
  read -rp "지금 로그인을 진행할까요? (Y/n) " answer
  answer="${answer:-Y}"
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    codex --full-setup
    ok "Codex 인증 완료"
  else
    warn "나중에 'codex --full-setup'으로 인증해주세요."
  fi
fi

# ─── 4. MCP 서버 등록 ───

echo ""
info "Codex MCP 브릿지 서버 등록 중..."

CLAUDE_JSON="$HOME/.claude.json"

# 이미 등록되어 있는지 확인
if [ -f "$CLAUDE_JSON" ] && grep -q '"codex-bridge"' "$CLAUDE_JSON" 2>/dev/null; then
  ok "codex-bridge MCP 서버 이미 등록됨"
else
  claude mcp add -s user codex-bridge -- codex mcp-server
  ok "codex-bridge MCP 서버 등록 완료"
fi

# ─── 5. 권한 설정 ───

echo ""
info "Claude Code 권한 설정 중..."

mkdir -p "$CLAUDE_DIR"

TOOL_1="mcp__codex-bridge__codex"
TOOL_2="mcp__codex-bridge__codex-reply"

if [ ! -f "$SETTINGS_FILE" ]; then
  # settings.json이 없으면 새로 생성
  cat > "$SETTINGS_FILE" << 'SETTINGS'
{
  "permissions": {
    "allow": [
      "mcp__codex-bridge__codex",
      "mcp__codex-bridge__codex-reply"
    ]
  }
}
SETTINGS
  ok "settings.json 생성 완료"
else
  # 이미 존재하면 권한 추가
  needs_update=false

  if ! grep -q "$TOOL_1" "$SETTINGS_FILE" 2>/dev/null; then
    needs_update=true
  fi
  if ! grep -q "$TOOL_2" "$SETTINGS_FILE" 2>/dev/null; then
    needs_update=true
  fi

  if [ "$needs_update" = true ]; then
    # node로 JSON 안전하게 수정
    node -e "
      const fs = require('fs');
      const settings = JSON.parse(fs.readFileSync('$SETTINGS_FILE', 'utf8'));
      if (!settings.permissions) settings.permissions = {};
      if (!settings.permissions.allow) settings.permissions.allow = [];
      const tools = ['$TOOL_1', '$TOOL_2'];
      for (const t of tools) {
        if (!settings.permissions.allow.includes(t)) {
          settings.permissions.allow.push(t);
        }
      }
      fs.writeFileSync('$SETTINGS_FILE', JSON.stringify(settings, null, 2) + '\n');
    "
    ok "권한 추가 완료"
  else
    ok "권한 이미 설정됨"
  fi
fi

# ─── 6. 스킬 파일 생성 ───

echo ""
info "codex-review 스킬 파일 생성 중..."

mkdir -p "$SKILL_DIR"

SKILL_FILE="$SKILL_DIR/SKILL.md"

if [ -f "$SKILL_FILE" ]; then
  ok "SKILL.md 이미 존재함 — 덮어쓰기 건너뜀"
  echo -e "  ${YELLOW}강제 재설치: rm \"$SKILL_FILE\" 후 다시 실행${NC}"
else
  cat > "$SKILL_FILE" << 'SKILLMD'
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
SKILLMD
  ok "SKILL.md 생성 완료"
fi

# ─── 완료 ───

echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║   설치 완료!                             ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}사용법:${NC}"
echo -e "    ${CYAN}/codex-review${NC}            기본 코드 리뷰"
echo -e "    ${CYAN}/codex-review deep${NC}       심층 리뷰"
echo -e "    ${CYAN}/codex-review ask ...${NC}    후속 질문"
echo ""
echo -e "  ${BOLD}작동 원리:${NC}"
echo -e "    Claude Code에서 코드 작성 → /codex-review 실행"
echo -e "    → Codex(GPT 계열)가 독립적으로 리뷰 → 결과를 한국어로 요약"
echo ""
echo -e "  ${YELLOW}참고: Claude Code를 재시작해야 MCP 서버가 로드됩니다.${NC}"
