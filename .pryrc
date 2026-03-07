begin
  if defined?(::Bundler)
    Gem.path.each do |path|
      $LOAD_PATH.concat(Dir.glob("#{path}/gems/*/lib"))
    end
  end

  require 'rb-readline'
  require 'readline'

  if defined?(RbReadline)
    def RbReadline.rl_reverse_search_history(sign, key)
      rl_insert_text `bat --language=rb --style=plain --color=always --paging=never ~/.pry_history | fzf --tac --no-sort --ansi | tr '\n' ' '`
    end
  end
rescue LoadError
  # rb-readline not available
end
