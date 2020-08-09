# middleman
Ralias bemar='bundle exec middleman article'
Ralias bemid='bundle exec middleman'
Ralias bemse='bundle exec middleman server'

# rails
Ralias beraic='bundle exec rails console'
Ralias berais='bundle exec rails server'

# rake
Ralias berak='bundle exec rake'
Ralias berakdm='bundle exec rake db:migrate'

# rspec
Ralias bersp='bundle exec rspec'

# torquebox
Ralias betde='bundle exec torquebox deploy'
Ralias betru='bundle exec torquebox run'

# bundler
Ralias bexec='bundle exec'
Ralias binst='bundle install'
Ralias bupda='bundle update'
Ralias busou='bundle update --source'

# rb runs ruby code from the command line
rb () {
  [[ $1 == -l ]] && shift
  case $? in
    0 ) ruby -e "STDIN.each_line { |l| puts l.chomp.instance_eval(&eval('Proc.new { $@ }')) }";;
    * ) ruby -e "puts STDIN.each_line.instance_eval(&eval('Proc.new { $@ }'))"                ;;
  esac
}
