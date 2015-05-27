$:.push File.expand_path('../lib', __FILE__)
require 'rubygems'

require 'bundler/setup'

require 'rake/testtask'

namespace :gem do
  Bundler::GemHelper.install_tasks
end

Rake::TestTask.new :spec do |task|
  task.libs << 'spec'
  task.test_files = FileList['spec/**/*_spec.rb']
end
