#!/usr/bin/env bash
#
# download_logos.sh
# -----------------
# Downloads each CTF machine logo into assets/Posts/<Machine>/logo.png
#
# - Edit the MACHINES map below to add/replace source URLs.
# - Existing logos are backed up once to logo.placeholder.png before overwriting.
# - Only valid image responses (HTTP 200 + PNG/JPEG magic bytes) are written,
#   so a broken/404 URL never clobbers a good file.
# - Entries whose URL is empty or starts with "TODO" are skipped and reported.
#
# Re-run any time after editing URLs:  bash tools/download_logos.sh
#
set -uo pipefail

# Resolve repo root (this script lives in <repo>/tools/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$REPO_ROOT/assets/Posts"

# Machine asset-folder | logo source URL   (one per line, pipe-separated)
# HTB avatars come from HackTheBox's public machine-avatar CDN.
# TryHackMe rooms: paste the room-icon URL from the room page
#   (right-click the room logo on tryhackme.com -> "Copy image address").
# Portable format (works on macOS bash 3.2 — no associative arrays).
# The data list is fed directly into the while loop's heredoc at the bottom.

ok=0; skipped=0; failed=0
tmp="$(mktemp)"

while IFS='|' read -r machine url; do
  [[ -z "$machine" ]] && continue
  dir="$ASSETS/$machine"
  dest="$dir/logo.png"

  if [[ -z "$url" || "$url" == TODO* ]]; then
    printf '  SKIP   %-20s (no URL set)\n' "$machine"
    ((skipped++)); continue
  fi

  mkdir -p "$dir"
  code="$(curl -sS -L --max-time 30 -o "$tmp" -w '%{http_code}' "$url" 2>/dev/null)"
  kind="$(file -b --mime-type "$tmp" 2>/dev/null)"

  if [[ "$code" != "200" ]]; then
    printf '  FAIL   %-20s HTTP %s\n' "$machine" "$code"
    ((failed++)); continue
  fi
  if [[ "$kind" != image/png && "$kind" != image/jpeg ]]; then
    printf '  FAIL   %-20s not an image (%s)\n' "$machine" "$kind"
    ((failed++)); continue
  fi

  # Back up an existing (placeholder) logo once, then install the real one.
  if [[ -f "$dest" && ! -f "$dir/logo.placeholder.png" ]]; then
    cp "$dest" "$dir/logo.placeholder.png"
  fi
  cp "$tmp" "$dest"
  printf '  OK     %-20s %s bytes (%s)\n' "$machine" "$(wc -c < "$dest" | tr -d ' ')" "$kind"
  ((ok++))
done <<'LIST'
Lame|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d7-a3c6-4bf5-944f-b6d62ba830bb.png
Legacy|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d7-a094-4d19-acb4-e24b7ae44f57.png
Devel|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d7-9cce-4bed-82d5-bd5f4bf2ab77.png
Bashed|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d6-f64a-49bf-9082-06f7269225c7.png
Cap|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d2-73c7-4da0-a15f-662bbc048868.png
OpenAdmin|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d4-871a-4692-976e-297a3e39400f.png
BountyHunter|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d2-5e54-4ac2-83de-6663cdbe4307.png
Jarvis|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d5-160c-4570-be60-c1895351b9a2.png
Doctor|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d3-26ff-43d8-af7c-73c79e7bee4a.png
Jeeves|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d7-0cc5-49c3-be2b-06b1946db205.png
Paper|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d0-d8d8-47f2-b1f9-09f3fa5abef2.png
Forest|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d4-b56c-4328-a5c3-0b326d506afe.png
Active|https://cdn.services-k8s.prod.aws.htb.systems/content/machines/avatar/9e4d90d5-dc8f-4276-afba-e99d3da016d3.png
AttacktiveDirectory|https://tryhackme.com/room/activedirectoryhardening
PickleRick|https://cdn-images.tryhackme.com/room-icons/47d2d3ade1795f81a155d0aca6e4da96.jpeg
LIST

rm -f "$tmp"
echo "-----------------------------------------------"
echo "Done: $ok downloaded, $skipped skipped, $failed failed."
