spec = Gem::Specification.new do |s|
	s.name              = "blackboard"
	s.version           = "0.2.3"
	s.platform          = Gem::Platform::RUBY
	s.has_rdoc          = false
	s.summary           = ""
	s.description       = ""
	s.author            = "João Duarte"
	s.email             = "jsvduarte@gmail.com"
	s.executables       = %w(  )
	s.bindir            = "bin"
	s.require_path      = "lib"

	s.add_dependency('memcache-client', '>=1.4.0')
	s.required_ruby_version = '>= 1.8.5'

  s.files = %w(
    test
    test/test_helper.rb
    test/blackboard_test.rb
    lib
    lib/blackboard.rb
    README
    spec
    spec/blackboard_spec.rb
    ChangeLog
    Rakefile
    blackboard.gemspec)

end
