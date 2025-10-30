# --- Config (set once per session) ---
export BB_HOST='central-bitbucket.novomatic-tech.com'
export BB_USER='jpolanski'
export BB_PAT='YOUR_BITBUCKET_TOKEN_HERE'  # Replace with your actual token
export PR='590'  # change as needed
export BB_PROJECT='NLX'
export BB_REPO='nlx-attendant-menu'
export BB_REVIEW_DIR="/Users/jpolanski/Projects/scripts/tmp"

bb_base() { echo "https://${BB_HOST}/rest/api/1.0/projects/${BB_PROJECT}/repos/${BB_REPO}/pull-requests"; }
bb_curl() { curl -s -u "${BB_USER}:${BB_PAT}" "$@"; }

# --- Auth test ---
bb_auth() {
  local pr="${1:-${PR:-}}"; [ -z "$pr" ] && { echo "Usage: bb_auth <pr>"; return 2; }
  bb_curl "$(bb_base)/$pr" \
  | jq -r '
      if .errors then "ERROR: " + (.errors | map(.message) | join("; "))
      else "OK: PR \(.id) - \(.title) [\(.state)]"
      end'
}

# --- Activities TSV: id, author, file:line, text (AI Reviewer filtered) ---
bb_tsv() {
  local pr="${1:-${PR:-}}"; [ -z "$pr" ] && { echo "Usage: bb_tsv <pr>"; return 2; }
  bb_curl "$(bb_base)/$pr/activities?limit=1000" \
  | jq -r '
    if .values then
      .values
      | map(select(.comment != null))
      | map(. as $a
        | ($a.comment.author.user.displayName // $a.comment.author.displayName // $a.user.displayName // "") as $rawName
        | ($rawName | tostring | ascii_downcase) as $name
        | select($name | contains("ai reviewer") | not)
        | {
            id: $a.comment.id,
            author: $rawName,
            file: ($a.comment.anchor.path // $a.commentAnchor.path // "-"),
            line: (
              $a.comment.anchor.line // $a.comment.anchor.toLine // $a.comment.anchor.fromLine //
              $a.commentAnchor.line  // $a.commentAnchor.toLine  // $a.commentAnchor.fromLine  // "-"
            ),
            text: $a.comment.text
          })
      | .[]
      | "\(.id)\t\(.author)\t\(.file):\(.line)\n\(.text)\n---"
    else
      "ERROR: " + (.errors | map(.message) | join("; "))
    end'
}

# --- Generate tasks JSON and summary MD under /tmp (not in repo) ---
bb_tasks() {
  local pr="${1:-${PR:-}}"; [ -z "$pr" ] && { echo "Usage: bb_tasks <pr>"; return 2; }
  mkdir -p "$BB_REVIEW_DIR"
  local tmp_json="$BB_REVIEW_DIR/.tmp-activities-${pr}.json"
  local tasks_json="$BB_REVIEW_DIR/PR-${pr}-tasks.json"
  local summary_md="$BB_REVIEW_DIR/PR-${pr}-summary.md"

  # Fetch activities
  if ! bb_curl "$(bb_base)/$pr/activities?limit=1000" > "$tmp_json"; then
    echo "curl failed"; return 1
  fi

  # Build tasks array (filter out AI Reviewer)
  if ! jq -e '
  if .values then
    [ .values[]
      | select(.comment != null)
      | (. as $a
         | ($a.comment.author.user.displayName // $a.comment.author.displayName // $a.user.displayName // "") as $rawName
         | ($rawName | tostring | ascii_downcase) as $name
         | select($name | contains("ai reviewer") | not)
         | {
             id: $a.comment.id,
             author: $rawName,
             file: ($a.comment.anchor.path // $a.commentAnchor.path // null),
             line: (
               $a.comment.anchor.line // $a.comment.anchor.toLine // $a.comment.anchor.fromLine //
               $a.commentAnchor.line  // $a.commentAnchor.toLine  // $a.commentAnchor.fromLine  // null
             ),
             text: $a.comment.text
           }
      )
    ]
  else
    error("API error: " + (.errors | map(.message) | join("; ")))
  end
' "$tmp_json" > "$tasks_json.raw"; then
    echo "Failed to parse activities; see $tmp_json" >&2
    return 1
  fi

  # Enrich with workflow fields
  if ! jq -e '
    if type=="array" then
      map(
        if type=="object" then . + {status:"pending", decision:null, note:"", reply:""}
        else . end
      )
    else error("unexpected JSON type: " + (type|tostring)) end
  ' "$tasks_json.raw" > "$tasks_json"; then
    echo "Failed to build $tasks_json" >&2
    return 1
  fi
  rm -f "$tasks_json.raw"

  # Summary markdown
  {
    echo "# PR ${pr} review summary"
    echo "Host: ${BB_HOST}, Project: ${BB_PROJECT}, Repo: ${BB_REPO}"
    echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%SZ')"
    echo
    echo "## Items"
    jq -r '
      .[] | "- [ ] ID \(.id) — \(.author) — \(.file // "-"):\(.line // "-")\n\n    \(.text | gsub("\r"; "") | split("\n") | map("    " + .) | join("\n"))\n"
    ' "$tasks_json"
  } > "$summary_md"

  echo "Tasks:  $tasks_json"
  echo "Summary: $summary_md"
}

# --- Post a single reply (Polish ok) ---
bb_reply() {
  local pr="${1:-${PR:-}}"; shift || true
  local parentId="$1"; shift || true
  local message="$*"
  [ -z "$pr" ] || [ -z "$parentId" ] || [ -z "$message" ] && { echo "Usage: bb_reply <pr> <commentId> <message>  (or set PR env and use: bb_reply <commentId> <message>)"; return 2; }

  local payload
  payload=$(jq -n --arg text "$message" --arg id "$parentId" '{text: $text, parent: {id: ($id|tonumber)}}')

  bb_curl -H "Content-Type: application/json" -X POST \
    "$(bb_base)/$pr/comments" -d "$payload" \
  | jq -r 'if .errors then "ERROR: " + (.errors | map(.message) | join("; ")) else "OK: posted reply id \(.id)" end'
}

# --- Post replies for all items with non-empty .reply in tasks JSON ---
bb_reply_batch() {
  local pr="${1:-${PR:-}}"; shift || true
  local tasks="${1:-"$BB_REVIEW_DIR/PR-${pr}-tasks.json"}"
  [ -z "$pr" ] || [ ! -f "$tasks" ] && { echo "Usage: bb_reply_batch <pr> [tasks.json]  (or set PR env)"; return 2; }
  jq -c '.[] | select(.reply != null and (.reply|type=="string") and (.reply|length>0))' "$tasks" \
  | while IFS= read -r row; do
      id=$(jq -r '.id' <<<"$row")
      text=$(jq -r '.reply' <<<"$row")
      echo "Posting reply for comment $id..." >&2
      bb_reply "$pr" "$id" "$text"
    done
}