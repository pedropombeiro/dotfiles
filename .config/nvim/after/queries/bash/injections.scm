; extends

((comment) @injection.content
  (#match? @injection.content "^#MISE ")
  (#set! injection.language "toml")
  (#offset! @injection.content 0 6 0 0))

((comment) @injection.content
  (#match? @injection.content "^#\[MISE\] ")
  (#set! injection.language "toml")
  (#offset! @injection.content 0 8 0 0))

((comment) @injection.content
  (#match? @injection.content "^# \[MISE\] ")
  (#set! injection.language "toml")
  (#offset! @injection.content 0 9 0 0))

((comment) @injection.content
  (#match? @injection.content "^#USAGE ")
  (#set! injection.language "kdl")
  (#set! injection.combined)
  (#offset! @injection.content 0 7 0 0))

((comment) @injection.content
  (#match? @injection.content "^#\[USAGE\] ")
  (#set! injection.language "kdl")
  (#set! injection.combined)
  (#offset! @injection.content 0 9 0 0))

((comment) @injection.content
  (#match? @injection.content "^# \[USAGE\] ")
  (#set! injection.language "kdl")
  (#set! injection.combined)
  (#offset! @injection.content 0 10 0 0))
