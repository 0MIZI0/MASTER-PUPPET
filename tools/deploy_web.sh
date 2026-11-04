#!/usr/bin/env bash
# Web export -> 검증 -> gh-pages 배포 (GitHub Pages).
# 사용: tools/deploy_web.sh [--no-push] [--wait-remote <sha>]
#   --wait-remote: 원격 main이 <sha>가 될 때까지 대기 후 배포 (pre-push 훅용)
# 환경변수: GODOT_BIN(기본 /usr/local/bin/godot), DEPLOY_REMOTE(기본 origin)
set -euo pipefail

# 훅 내부 실행 시 상속되는 git 환경 제거 (임시 저장소 오염 방지)
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT_BIN:-/usr/local/bin/godot}"
REMOTE="${DEPLOY_REMOTE:-origin}"
PRESET="Web"
OUT_DIR="build/web"
PUSH=1
WAIT_SHA=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--no-push) PUSH=0; shift ;;
		--wait-remote) WAIT_SHA="${2:?sha 필요}"; shift 2 ;;
		*) echo "알 수 없는 인자: $1" >&2; exit 2 ;;
	esac
done

log() { printf '\033[36m[deploy]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[deploy] %s\033[0m\n' "$*" >&2; exit 1; }

[[ -x "$GODOT" ]] || die "Godot 실행 파일 없음: $GODOT"

if [[ -n "$WAIT_SHA" ]]; then
	log "원격 main 반영 대기 (${WAIT_SHA:0:7})"
	for _ in $(seq 1 60); do
		[[ "$(git ls-remote "$REMOTE" refs/heads/main | cut -f1)" == "$WAIT_SHA" ]] && break
		sleep 2
	done
	[[ "$(git ls-remote "$REMOTE" refs/heads/main | cut -f1)" == "$WAIT_SHA" ]] || die "main push가 반영되지 않아 배포 취소"
	[[ "$(git rev-parse HEAD)" == "$WAIT_SHA" ]] || die "HEAD가 바뀌어 배포 취소"
fi

# 커밋된 상태만 배포 (추적 파일 미커밋 변경 시 중단)
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
	die "커밋되지 않은 변경이 있습니다. 커밋 후 다시 실행하세요."
fi
SHA="$(git rev-parse --short HEAD)"
REMOTE_URL="$(git remote get-url "$REMOTE")"

LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

log "리소스 import ($SHA)"
timeout 300 "$GODOT" --headless --path . --import >"$LOG_DIR/import.log" 2>&1 || true

log "스크립트 검증 (headless 실행)"
timeout 60 "$GODOT" --headless --path . --quit-after 120 >"$LOG_DIR/run.log" 2>&1 || true
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG_DIR/run.log"; then
	grep -E -A3 "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG_DIR/run.log" | head -40 >&2
	die "스크립트 오류로 배포 중단"
fi

log "Web export"
mkdir -p "$OUT_DIR"
touch build/.gdignore
rm -f "$OUT_DIR"/index.*
if ! timeout 600 "$GODOT" --headless --path . --export-release "$PRESET" "$OUT_DIR/index.html" >"$LOG_DIR/export.log" 2>&1; then
	tail -30 "$LOG_DIR/export.log" >&2
	die "export 실패"
fi
for f in index.html index.js index.wasm index.pck; do
	[[ -s "$OUT_DIR/$f" ]] || { tail -30 "$LOG_DIR/export.log" >&2; die "export 산출물 누락: $f"; }
done
log "산출물: $(du -sh "$OUT_DIR" | cut -f1)"

if [[ $PUSH -eq 0 ]]; then
	log "--no-push: 배포 생략"
	exit 0
fi

# gh-pages: 빌드 결과물만 담은 단일 커밋으로 강제 갱신 (wasm 누적 방지)
STAGE="$LOG_DIR/pages"
mkdir -p "$STAGE"
cp "$OUT_DIR"/index.* "$STAGE/"
touch "$STAGE/.nojekyll"
git -C "$STAGE" init -q -b gh-pages
git -C "$STAGE" config user.name "$(git config user.name)"
git -C "$STAGE" config user.email "$(git config user.email)"
git -C "$STAGE" add -A
git -C "$STAGE" commit -q -m "Deploy web build $SHA"
log "gh-pages push → $REMOTE_URL"
git -C "$STAGE" push -q --force "$REMOTE_URL" gh-pages
log "완료: https://0mizi0.github.io/MASTER-PUPPET/ (반영까지 약 1분)"
