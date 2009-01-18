require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'rake/contrib/rubyforgepublisher'
require 'rake/contrib/sshpublisher'
require 'spec/rake/spectask'
require 'fileutils'
require 'metric_fu'
include FileUtils

MetricFu::CHURN_OPTIONS = {:scm => :git}
MetricFu::DIRECTORIES_TO_FLOG = ['lib']  
MetricFu::SAIKURO_OPTIONS = {"--input_directory" => 'lib'}

CLEAN.include ['**/.*.sw?', '*.gem', '.config']
task :default => [:test]
#task :package => [:clean]

Rake::TestTask.new("test") do |t|
	t.libs   << "test"
	t.pattern = "test/**/*_test.rb"
	t.verbose = true
end


desc "Run all examples with RCov"
Spec::Rake::SpecTask.new('examples_with_rcov') do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', 'examples']
end

task :cruise => [ "metrics:flog", "metrics:churn", "metrics:coverage", "metrics:saikuro" ]
