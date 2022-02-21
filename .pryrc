if defined?(::Bundler)
  current_gemset = ENV['GEM_HOME']
  $LOAD_PATH.concat(Dir.glob("#{current_gemset}/gems/*/lib")) if current_gemset
end

require 'rb-readline'
require 'readline'

if defined?(RbReadline)
  def RbReadline.rl_reverse_search_history(sign, key)
    rl_insert_text `bat --language ruby --style plain --force-colorization ~/.pry_history | fzf --tac --no-sort --ansi | tr '\n' ' '`
  end
end
