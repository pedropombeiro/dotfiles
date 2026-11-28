#!/usr/bin/env zsh

# Verify that readeck post --expect matches phrases wrapped across HTML line
# breaks, inline tags, and HTML entities while still matching raw HTML (such as
# link attributes) and rejecting absent or whitespace-only text.
emulate -LR zsh
setopt err_exit
scripts=${0:A:h:h}
home_root=${scripts:h:h:h}
helper="$home_root/.agents/skills/readeck/scripts/readeck"
source "$scripts/tests/lib/test-helpers.zsh"
test_sandbox bash jq perl python3
trap test_cleanup EXIT

test_stub curl <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

state_dir="${READECK_TEST_STATE_DIR:?}"
mkdir -p "$state_dir"

method=GET
output=""
dump_header=""
write_out=""
url=""

while (($# > 0)); do
  case "$1" in
  --config)
    if [[ ${2:-} == "-" ]]; then
      cat >/dev/null
    fi
    shift 2
    ;;
  --request)
    method=$2
    shift 2
    ;;
  --output)
    output=$2
    shift 2
    ;;
  --dump-header)
    dump_header=$2
    shift 2
    ;;
  --write-out)
    write_out=$2
    shift 2
    ;;
  --header | --connect-timeout | --max-time | --data-binary | --form | --form-string)
    shift 2
    ;;
  --silent | --show-error)
    shift
    ;;
  http://* | https://*)
    url=$1
    shift
    ;;
  *)
    shift
    ;;
  esac
done

path=${url#http*://*/}
path="/$path"
printf '%s %s\n' "$method" "$path" >> "$state_dir/requests.log"

status=200
case "$method $path" in
"GET /api/bookmarks?site="*)
  if [[ -n $dump_header ]]; then
    printf 'HTTP/1.1 200 OK\r\nTotal-Count: 0\r\n\r\n' > "$dump_header"
  fi
  printf '[]\n' > "$output"
  ;;
"GET /api/bookmarks?limit=100")
  printf '[]\n' > "$output"
  ;;
"POST /api/bookmarks")
  status=202
  if [[ -n $dump_header ]]; then
    printf 'HTTP/1.1 202 Accepted\r\nBookmark-Id: bmTest123\r\n\r\n' > "$dump_header"
  fi
  printf '{"status":202}\n' > "$output"
  ;;
"GET /api/bookmarks/bmTest123")
  cat > "$output" <<'JSON'
{
  "id": "bmTest123",
  "loaded": true,
  "has_article": true,
  "errors": [],
  "url": "https://example.com/doc",
  "title": "Synthetic Test Article",
  "authors": ["Test Author"],
  "lang": "en",
  "labels": [],
  "is_archived": false,
  "is_marked": false,
  "resources": {}
}
JSON
  ;;
"GET /api/bookmarks/bmTest123/article")
  cp "$state_dir/article.html" "$output"
  ;;
"DELETE /api/bookmarks/bmTest123")
  status=204
  printf '%s\n' "$path" >> "$state_dir/deleted.log"
  : > "$output"
  ;;
*)
  status=404
  printf '{"message":"Not Found"}\n' > "$output"
  ;;
esac

if [[ -n $write_out ]]; then
  printf '%s' "$status"
fi
SCRIPT

export READECK_TEST_STATE_DIR="$TEST_SANDBOX/readeck-state"
mkdir -p "$READECK_TEST_STATE_DIR"

env_file="$TEST_SANDBOX/credentials.env"
auth_key="READECK_""TOKEN"
printf 'READECK_URL=%s\n%s=%s\n' 'https://readeck.example.com' "$auth_key" 'stub' > "$env_file"
chmod 600 "$env_file"

input_html="$TEST_SANDBOX/input.html"
cat > "$input_html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head><title>Synthetic Test Article</title></head>
<body>
<article>
<p>The expected phrase
continues here across a line break.</p>
<p>Tom &amp; <em>Jerry</em><br>went&nbsp;&nbsp;home.</p>
<p><a href="https://youtube.com/watch?v=abc&amp;t=123s">02:03</a></p>
<script>const hidden = "secret\nscript phrase";</script>
</article>
</body>
</html>
HTML
cp "$input_html" "$READECK_TEST_STATE_DIR/article.html"

run_post() {
  local label=$1 expected_status=$2 expect_phrase=$3
  rm -f "$READECK_TEST_STATE_DIR/requests.log" "$READECK_TEST_STATE_DIR/deleted.log"
  test_expect_status "$label" "$expected_status" \
    "$helper" post \
    --env-file "$env_file" \
    --url https://example.com/doc \
    --title 'Synthetic Test Article' \
    --author 'Test Author' \
    --expect "$expect_phrase" \
    "$input_html"
}

# Case 1: Expected phrase wraps across an HTML line break.
run_post 'wrapped HTML phrase' 0 'The expected phrase continues here across a line break.'
output=$(<"$TEST_SANDBOX/output")
[[ $output == *'validation=passed'* ]] || test_fail "expected validation=passed, got: $output"
[[ ! -e "$READECK_TEST_STATE_DIR/deleted.log" ]] || test_fail 'wrapped phrase should not delete bookmark'
print 'PASS: matches phrase split across an HTML line break'

# Case 2: Expected phrase spans inline tags, HTML entities, <br>, and non-breaking spaces.
run_post 'inline tags and entities' 0 'Tom & Jerry went home.'
output=$(<"$TEST_SANDBOX/output")
[[ $output == *'validation=passed'* ]] || test_fail "expected validation=passed, got: $output"
[[ ! -e "$READECK_TEST_STATE_DIR/deleted.log" ]] || test_fail 'inline/entity phrase should not delete bookmark'
print 'PASS: matches phrase across inline tags, entities, and whitespace'

# Case 3: Expected text is in a raw HTML attribute (used by video-takeaways for t=123s).
run_post 'raw HTML attribute match' 0 't=123s'
output=$(<"$TEST_SANDBOX/output")
[[ $output == *'validation=passed'* ]] || test_fail "expected validation=passed, got: $output"
[[ ! -e "$READECK_TEST_STATE_DIR/deleted.log" ]] || test_fail 'attribute match should not delete bookmark'
print 'PASS: matches expected text in raw HTML attributes'

# Case 4: Expected text is absent from the stored article.
run_post 'absent expected phrase' 1 'This phrase is not in the article.'
output=$(<"$TEST_SANDBOX/output")
[[ $output == *"the stored article doesn't contain the expected text"* ]] ||
  test_fail "expected missing-text error, got: $output"
[[ -e "$READECK_TEST_STATE_DIR/deleted.log" ]] || test_fail 'absent phrase must delete the new bookmark'
print 'PASS: rejects absent phrase and deletes the new bookmark'

# Case 5: Whitespace-only --expect or text inside <script> must not match.
run_post 'whitespace-only expect' 1 '   '
[[ -e "$READECK_TEST_STATE_DIR/deleted.log" ]] || test_fail 'whitespace-only expect must delete the new bookmark'
run_post 'script-only text' 1 'secret script phrase'
[[ -e "$READECK_TEST_STATE_DIR/deleted.log" ]] || test_fail 'script-only text must delete the new bookmark'
print 'PASS: rejects whitespace-only and script-only matches'
