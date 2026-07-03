#!/usr/bin/env bash
# ai-workspace 日常同步腳本（WSL / SSH / Linux）
#
# 用法:
#   sync.sh                                   pull + symlink 校驗
#   sync.sh push                              pull（防覆蓋）→ commit → push
#   sync.sh link-project <path> <name> [--backup|--force]
#                                              建立/更新 projects/<name>.md 對應到 <path>/CLAUDE.md 的 symlink
#                                              （若 <path>/CLAUDE.md 已是真實檔案，預設拒絕覆蓋，
#                                               需明確加 --backup 備份後取代，或 --force 直接覆蓋）
#   sync.sh link-skill <project> <skill>      建立 skills/projects/<project>/<skill>/ symlink 到 <path>/.claude/skills/<skill>/
#   sync.sh remove-project <name> [--paths=projects,rules,mem,skills] [--unlink-cwd]
#                                              清除 ai-workspace 內某專案的殘留檔案（不互動，由呼叫方先決定好
#                                              要刪哪些類別；預設四類全刪。--unlink-cwd 會順便清掉「目前所在
#                                              目錄」若剛好連結到這個專案的 CLAUDE.md / CLAUDE.local.md）
set -euo pipefail

AI_WORKSPACE="${AI_WORKSPACE:-$HOME/.ai-workspace}"
CLAUDE_HOME="$HOME/.claude"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
ok()    { echo -e "${GREEN}[OK]     ${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]   ${NC} $*"; }
info()  { echo -e "${CYAN}[INFO]   ${NC} $*"; }
err()   { echo -e "${RED}[ERROR]  ${NC} $*" >&2; }

cmd="${1:-sync}"

# ── 子指令：sync（預設，無參數）────────────────────────
do_sync() {
    cd "$AI_WORKSPACE"

    info "git pull ..."
    git pull --ff-only
    ok "pull 完成，目前 commit: $(git rev-parse --short HEAD)"

    echo ""
    info "symlink 校驗 ..."

    # 1) 斷鍊檢查：~/.claude/skills/<name> 等是否指向已不存在的路徑
    local dangling=0
    for link in "$CLAUDE_HOME/CLAUDE.md" "$CLAUDE_HOME/statusline.sh" \
                "$HOME/.gemini/GEMINI.md" "$HOME/.codex/AGENTS.md"; do
        if [ -L "$link" ] && [ ! -e "$link" ]; then
            warn "斷鍊: $link -> $(readlink "$link")"
            dangling=$((dangling+1))
        fi
    done
    if [ -d "$CLAUDE_HOME/skills" ]; then
        for link in "$CLAUDE_HOME/skills"/*/; do
            [ -L "${link%/}" ] || continue
            if [ ! -e "${link%/}" ]; then
                warn "斷鍊: ${link%/} -> $(readlink "${link%/}")"
                dangling=$((dangling+1))
            fi
        done
    fi
    [ "$dangling" -eq 0 ] && ok "無斷鍊"

    # 2) repo 有新 skill 但本機未建 symlink
    local missing=()
    if [ -d "$AI_WORKSPACE/skills/global" ]; then
        for d in "$AI_WORKSPACE/skills/global"/*/; do
            [ -d "$d" ] || continue
            name="$(basename "$d")"
            [ -e "$CLAUDE_HOME/skills/$name" ] || missing+=("$name")
        done
    fi
    if [ "${#missing[@]}" -gt 0 ]; then
        warn "發現 ${#missing[@]} 個尚未連結的 skill: ${missing[*]}"
        read -rp "    現在建立 symlink？[Y/n]: " ans
        if [[ "${ans,,}" != "n" ]]; then
            mkdir -p "$CLAUDE_HOME/skills"
            for name in "${missing[@]}"; do
                ln -sf "$AI_WORKSPACE/skills/global/$name" "$CLAUDE_HOME/skills/$name"
                ok "已連結: $name"
            done
        fi
    else
        ok "skill symlink 齊全"
    fi

    # 3) 本機孤兒 symlink：指向 ai-workspace/skills/global/ 但來源已被刪除
    local orphans=()
    if [ -d "$CLAUDE_HOME/skills" ]; then
        for link in "$CLAUDE_HOME/skills"/*/; do
            [ -L "${link%/}" ] || continue
            target="$(readlink "${link%/}")"
            case "$target" in
                "$AI_WORKSPACE/skills/global/"*)
                    [ -e "$target" ] || orphans+=("${link%/}")
                    ;;
            esac
        done
    fi
    if [ "${#orphans[@]}" -gt 0 ]; then
        warn "發現孤兒 symlink（來源已從 repo 刪除）:"
        for o in "${orphans[@]}"; do echo "    $o"; done
        read -rp "    清除？[y/N]: " ans
        if [[ "${ans,,}" == "y" ]]; then
            for o in "${orphans[@]}"; do rm "$o"; ok "已清除: $o"; done
        fi
    else
        ok "無孤兒 symlink"
    fi

    echo ""
    ok "同步完成 — commit: $(git rev-parse --short HEAD)（$(git log -1 --format=%cd --date=short)）"
}

# ── 子指令：push ───────────────────────────────────────
do_push() {
    cd "$AI_WORKSPACE"

    info "push 前先 pull（避免覆蓋其他主機的變更）..."
    if ! git pull --ff-only; then
        err "git pull 失敗（可能有衝突），請手動處理後再執行 sync.sh push："
        err "  cd \"$AI_WORKSPACE\" && git status"
        exit 1
    fi

    if [ -z "$(git status --porcelain)" ]; then
        info "沒有變更可 push。"
        return
    fi

    git add -A
    git commit
    git push
    ok "push 完成 — commit: $(git rev-parse --short HEAD)"
}

# ── 子指令：link-project ───────────────────────────────
do_link_project() {
    local project_path="${1:?用法: sync.sh link-project <path> <name> [--backup|--force]}"
    local name="${2:?用法: sync.sh link-project <path> <name> [--backup|--force]}"
    local mode="${3:-}"

    local body="$AI_WORKSPACE/projects/$name.md"
    if [ ! -f "$body" ]; then
        err "本體不存在: $body（請先用 /init-project-md 或手動建立）"
        exit 1
    fi

    local target_link="$project_path/CLAUDE.md"
    if [ -e "$target_link" ] && [ ! -L "$target_link" ]; then
        case "$mode" in
            --backup)
                local bak="${target_link}.bak-$(date +%Y%m%d-%H%M%S)"
                mv "$target_link" "$bak"
                ok "已備份: $bak"
                ;;
            --force)
                warn "直接覆蓋（未備份）: $target_link"
                ;;
            *)
                err "$target_link 是真實檔案（非 symlink），內容不會自動保留，為避免誤刪不會自動覆蓋。"
                err "確認內容可以捨棄後，重跑並加上 --backup（備份後取代）或 --force（直接覆蓋）"
                exit 1
                ;;
        esac
    fi

    ln -sf "$body" "$target_link"
    ok "已連結: $target_link -> $body"

    # CLAUDE.local.md：純 import stub，指向 rules/mem
    local local_md="$project_path/CLAUDE.local.md"
    if [ ! -e "$local_md" ]; then
        {
            echo "@$AI_WORKSPACE/rules/global.md"
            [ -f "$AI_WORKSPACE/rules/projects/$name/general.md" ] && \
                echo "@$AI_WORKSPACE/rules/projects/$name/general.md"
            echo "@$AI_WORKSPACE/mem/global.md"
            [ -f "$AI_WORKSPACE/mem/projects/$name.md" ] && \
                echo "@$AI_WORKSPACE/mem/projects/$name.md"
        } > "$local_md"
        ok "已建立: $local_md"
    else
        info "$local_md 已存在，未覆寫（手動確認 import 行是否齊全）"
    fi
}

# ── 子指令：remove-project ──────────────────────────────
# 不互動：由呼叫方（人工或 AI agent 先在對話裡問過使用者）決定好要刪哪些類別，
# 用旗標指定，避免腳本內建 read -rp 在非 TTY（例如 AI agent 直接呼叫）環境卡住。
do_remove_project() {
    local name="${1:?用法: sync.sh remove-project <name> [--paths=projects,rules,mem,skills] [--unlink-cwd]}"
    shift

    local paths_arg="projects,rules,mem,skills"
    local unlink_cwd=0
    for arg in "$@"; do
        case "$arg" in
            --paths=*)    paths_arg="${arg#--paths=}" ;;
            --unlink-cwd) unlink_cwd=1 ;;
            *) err "未知參數: $arg"; exit 1 ;;
        esac
    done

    declare -A path_map=(
        [projects]="$AI_WORKSPACE/projects/$name.md"
        [rules]="$AI_WORKSPACE/rules/projects/$name"
        [mem]="$AI_WORKSPACE/mem/projects/$name.md"
        [skills]="$AI_WORKSPACE/skills/projects/$name"
    )

    IFS=',' read -ra want <<< "$paths_arg"
    for key in "${want[@]}"; do
        local p="${path_map[$key]:-}"
        if [ -z "$p" ]; then
            err "未知的 --paths 項目: $key（可用: projects,rules,mem,skills）"
            exit 1
        fi
        if [ -e "$p" ]; then
            rm -rf "$p"
            ok "已刪除: $p"
        else
            info "不存在，略過: $p"
        fi
    done

    if [ "$unlink_cwd" -eq 1 ]; then
        local cwd_link="$PWD/CLAUDE.md"
        if [ -L "$cwd_link" ] && [ "$(readlink "$cwd_link")" = "$AI_WORKSPACE/projects/$name.md" ]; then
            rm -f "$cwd_link" "$PWD/CLAUDE.local.md"
            ok "已移除本目錄連結: $cwd_link（含 CLAUDE.local.md，若存在）"
        else
            info "目前目錄的 CLAUDE.md 未連結到 $name，略過 --unlink-cwd"
        fi
    fi

    echo ""
    ok "清理完成，記得執行 sync.sh push 同步給其他主機。"
    warn "其他主機上（若有連結過）的 CLAUDE.md / CLAUDE.local.md 不在 ai-workspace 管轄範圍，"
    warn "不會自動清除，需要你自行到那些主機上手動刪除。"
}

# ── 子指令：link-skill ─────────────────────────────────
do_link_skill() {
    local project="${1:?用法: sync.sh link-skill <project> <skill>}"
    local skill="${2:?用法: sync.sh link-skill <project> <skill>}"

    local body="$AI_WORKSPACE/skills/projects/$project/$skill"
    if [ ! -d "$body" ]; then
        err "本體不存在: $body（請先建立 SKILL.md）"
        exit 1
    fi

    read -rp "專案目錄路徑（含 .claude/skills/ 的那個 repo 根目錄）: " project_root
    mkdir -p "$project_root/.claude/skills"
    ln -sf "$body" "$project_root/.claude/skills/$skill"
    ok "已連結: $project_root/.claude/skills/$skill -> $body"
}

case "$cmd" in
    sync)            do_sync ;;
    push)            do_push ;;
    link-project)    shift; do_link_project "$@" ;;
    link-skill)      shift; do_link_skill "$@" ;;
    remove-project)  shift; do_remove_project "$@" ;;
    *)
        err "未知指令: $cmd"
        echo "用法: sync.sh [sync|push|link-project <path> <name> [--backup|--force]|link-skill <project> <skill>|remove-project <name> [--paths=...] [--unlink-cwd]]"
        exit 1
        ;;
esac
