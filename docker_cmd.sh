gem build vimamsa.gemspec 
sudo gem install --local vimamsa-0.1.*.gem
cp /usr/local/bundle/gems/vimamsa-0.1.23/ext/vmaext/vmaext.so .
cp /usr/local/bundle/gems/vimamsa-0.1.23/ext/vmaext/vmaext.so lib/
# xvfb-run -a bundle exec ruby exe/run_tests.rb --test tests/test_basic_editing.rb
xvfb-run -a bundle exec ruby run_tests.rb

