#!/usr/bin/env bash
# Analyze prompt complexity and suggest appropriate effort level
# Used as UserPromptSubmit hook - must complete quickly (< 100ms)
set -euo pipefail

# --- Read input ---

# jq is required for JSON parsing
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty')

# --- Early exits ---

# Empty or very short prompt
[[ ${#PROMPT} -lt 5 ]] && exit 0

# Slash commands
[[ "$PROMPT" =~ ^/ ]] && exit 0

# Trim whitespace for single-word checks
trimmed=$(printf '%s' "$PROMPT" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Single-word confirmations
if [[ "$trimmed" =~ ^(y|n|yes|no|ok|OK|はい|いいえ|うん|おk)$ ]]; then
    exit 0
fi

# Conversational patterns (no task complexity signal)
prompt_lower=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')
if [[ "$prompt_lower" =~ ^(ありがとう|thanks|thank\ you|thx) ]] ||
   [[ "$prompt_lower" =~ ^(了解|わかった|わかりました|okay|sure|got\ it) ]] ||
   [[ "$prompt_lower" =~ ^(続けて|continue|go\ ahead|proceed) ]] ||
   [[ "$prompt_lower" =~ ^(いいね|いいよ|good|great|nice|perfect|lgtm) ]] ||
   [[ "$prompt_lower" =~ ^(なるほど|i\ see|makes\ sense) ]]; then
    exit 0
fi

# --- Scoring ---

COMPLEX_SCORE=0
SIMPLE_SCORE=0

# Complex patterns (+3)
if [[ "$prompt_lower" =~ (設計|アーキテクチャ|architecture|design|redesign) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 3))
fi
if [[ "$prompt_lower" =~ (リファクタ|refactor|restructure|rewrite) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 3))
fi

# Complex patterns (+2)
if [[ "$prompt_lower" =~ (全体|全ファイル|across\ all|entire|comprehensive) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 2))
fi
if [[ "$prompt_lower" =~ (セキュリティ|security|vulnerability|脆弱性|認証|auth) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 2))
fi
if [[ "$prompt_lower" =~ (パフォーマンス|performance|最適化|optimize) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 2))
fi
if [[ "$prompt_lower" =~ (原因調査|root\ cause|intermittent|race\ condition) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 2))
fi
if [[ "$prompt_lower" =~ (計画|plan|分析|analyze|調査|investigate) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 2))
fi
if [[ "$prompt_lower" =~ (マイグレーション|migration|移行|upgrade) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 2))
fi

# Complex patterns (+1)
if [[ "$prompt_lower" =~ (テスト戦略|test\ strategy|テストカバレッジ|coverage) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 1))
fi
if [[ "$prompt_lower" =~ (複数|multiple\ files|several|各ファイル) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 1))
fi
if [[ "$prompt_lower" =~ (新規|from\ scratch|ゼロから|new\ project) ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 1))
fi

# Simple patterns (+3)
if [[ "$prompt_lower" =~ (typo|タイポ|誤字|スペルミス) ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 3))
fi
if [[ "$prompt_lower" =~ (フォーマット|format|indent|インデント) ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 3))
fi

# Simple patterns (+2)
if [[ "$prompt_lower" =~ (リネーム|rename|名前変更|変数名を) ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 2))
fi
if [[ "$prompt_lower" =~ (コメント追加|add\ comment|コメント修正) ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 2))
fi
if [[ "$prompt_lower" =~ (説明して|explain|教えて|what\ is|what\'s|何ですか) ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 2))
fi
if [[ "$prompt_lower" =~ (見せて|show|表示|一覧|list|確認して) ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 2))
fi
if [[ "$prompt_lower" =~ (バージョン|version|ステータス|status) ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 2))
fi

# Simple patterns (+1)
if [[ "$prompt_lower" =~ (追加して|add\ a|import追加|行追加) ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 1))
fi
if [[ "$prompt_lower" =~ (削除して|remove|delete) ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 1))
fi

# --- Length bonus ---

prompt_len=${#PROMPT}
if [[ $prompt_len -lt 20 && $SIMPLE_SCORE -gt 0 ]]; then
    SIMPLE_SCORE=$((SIMPLE_SCORE + 1))
fi
if [[ $prompt_len -ge 200 && $COMPLEX_SCORE -gt 0 ]]; then
    COMPLEX_SCORE=$((COMPLEX_SCORE + 1))
fi

# --- Decision ---

THRESHOLD=3

if [[ $COMPLEX_SCORE -ge $THRESHOLD && $COMPLEX_SCORE -gt $SIMPLE_SCORE ]]; then
    MSG="[effort-hint] 複雑なタスクの可能性があります。effortがlow/mediumの場合、/model でhigh以上への変更を検討してください。"
elif [[ $SIMPLE_SCORE -ge $THRESHOLD && $SIMPLE_SCORE -gt $COMPLEX_SCORE ]]; then
    MSG="[effort-hint] 単純なタスクの可能性があります。effortがhigh/maxの場合、/model でmedium以下への変更を検討してください。"
else
    exit 0
fi

# --- Output ---

jq -n --arg msg "$MSG" '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": $msg
  }
}'
