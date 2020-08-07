# middleman
ralias bemar='bundle exec middleman article'
ralias bemid='bundle exec middleman'
ralias bemse='bundle exec middleman server'

# rails
ralias beraic='bundle exec rails console'
ralias berais='bundle exec rails server'

# rake
ralias berak='bundle exec rake'
ralias berakdm='bundle exec rake db:migrate'

# rspec
ralias bersp='bundle exec rspec'

# torquebox
ralias betde='bundle exec torquebox deploy'
ralias betru='bundle exec torquebox run'

# bundler
ralias bexec='bundle exec'
ralias binst='bundle install'
ralias bupda='bundle update'
ralias busou='bundle update --source'

# rb runs ruby code from the command line
rb () {
  [[ $1 == -l ]] && shift
  case $? in
    0 ) ruby -e "STDIN.each_line { |l| puts l.chomp.instance_eval(&eval('Proc.new { $@ }')) }";;
    * ) ruby -e "puts STDIN.each_line.instance_eval(&eval('Proc.new { $@ }'))"                ;;
  esac
}