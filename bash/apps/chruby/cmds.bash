# middleman
Alias bemar='bundle exec middleman article'
Alias bemid='bundle exec middleman'
Alias bemse='bundle exec middleman server'

# rails
Alias beraic='bundle exec rails console'
Alias berais='bundle exec rails server'

# rake
Alias berak='bundle exec rake'
Alias berakdm='bundle exec rake db:migrate'

# rspec
Alias bersp='bundle exec rspec'

# torquebox
Alias betde='bundle exec torquebox deploy'
Alias betru='bundle exec torquebox run'

# bundler
Alias bexec='bundle exec'
Alias binst='bundle install'
Alias bupda='bundle update'
Alias busou='bundle update --source'

# rb runs ruby code from the command line
rb () {
  [[ $1 == -l ]] && shift
  case $? in
    0 ) ruby -e "STDIN.each_line { |l| puts l.chomp.instance_eval(&eval('Proc.new { $@ }')) }";;
    * ) ruby -e "puts STDIN.each_line.instance_eval(&eval('Proc.new { $@ }'))"                ;;
  esac
}
