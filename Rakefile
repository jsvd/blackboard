require 'rubygems'
require 'rake'
require 'rake/clean'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'spec/rake/spectask'

require 'fileutils'
require 'metric_fu'
include FileUtils

MetricFu::Configuration.run do |config|
  #define which metrics you want to use
  config.metrics  = [:churn, :saikuro, :coverage, :flog]
  config.churn    = {:scm => :git }
#  config.coverage = { :test_files => ['test/**/test_*.rb'] }
  config.flog     = { :dirs_to_flog => ['lib']  }
#  config.flay     = { :dirs_to_flay => ['cms/app', 'cms/lib']  }  
  config.saikuro  = {"--input_directory" => 'lib'}
end

CLEAN.include ['coverage', 'pkg', '**/.*.sw?', '*.gem', '.config']

task :default => [:spec]

Spec::Rake::SpecTask.new do |t|
  t.rcov = true
  t.warning = false
end

task :cruise => [ "metrics:flog", "metrics:churn", "metrics:coverage", "metrics:saikuro" ]
