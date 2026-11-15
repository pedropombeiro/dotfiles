# Tokenize strings before comments so URLs and comment-like string values survive.
# Preserve whitespace so separate primitive tokens cannot merge into valid JSON.
[scan("\"(?:[^\"\\\\]|\\\\.)*\"|//[^\r\n]*|/\\*[\\s\\S]*?\\*/|\\s+|[^\\s]")
 | if startswith("//") or startswith("/*") then " " else . end]
| . as $tokens
# JSONC permits a comma immediately before a closing array or object delimiter.
| [range(length) as $i
   | if $tokens[$i] == "," then
       ([$tokens[$i + 1:][] | select(test("^\\s+$") | not)][0]) as $next
       | select($next != "]" and $next != "}")
       | $tokens[$i]
     else $tokens[$i] end]
| join("")
| fromjson
| empty
