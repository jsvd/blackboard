spec = Gem::Specification.new do |s|
	s.name              = "blackboard"
	s.version           = "0.2.3"
	s.platform          = Gem::Platform::RUBY
	s.has_rdoc          = false
	s.extra_rdoc_files  = ["README", "ChangeLog"]
#	s.rdoc_options     = RDOC_OPTS + ['--exclude', '^(examples|extras)/']
	s.summary           = ""
	s.description       = ""
	s.author            = "João Duarte"
	s.email             = "jsvduarte@gmail.com"
	s.executables       = %w(  )
	s.bindir            = "bin"
	s.require_path      = "lib"
	s.test_files        = Dir["test/test_*.rb"]

	s.add_dependency('memcache-client', '>=1.4.0')
	s.required_ruby_version = '>= 1.8.5'

	s.files = %w(README ChangeLog Rakefile) +
		Dir.glob("{bin,doc,spec,test,lib,templates,generator,extras,website,script}/**/*") + 
		Dir.glob("ext/**/*.{h,c,rb}") +
		Dir.glob("examples/**/*.rb") +
		Dir.glob("tools/*.rb")

	#s.extensions = FileList["ext/**/extconf.rb"].to_a
end
