NAME              = "blackboard"
AUTHOR            = "João Duarte"
EMAIL             = "jsvduarte@gmail.com"
DESCRIPTION       = ""
BIN_FILES         = %w(  )
VERS              = "0.2.3"
REV = File.read(".svn/entries")[/committed-rev="(d+)"/, 1] rescue nil
RDOC_OPTS = [
	'--title', "#{NAME} documentation",
	"--charset", "utf-8",
	"--opname", "index.html",
	"--line-numbers",
	"--main", "README",
	"--inline-source",
]

spec = Gem::Specification.new do |s|
	s.name              = NAME
	s.version           = VERS
	s.platform          = Gem::Platform::RUBY
	s.has_rdoc          = true
	s.extra_rdoc_files  = ["README", "ChangeLog"]
	s.rdoc_options     += RDOC_OPTS + ['--exclude', '^(examples|extras)/']
	s.summary           = DESCRIPTION
	s.description       = DESCRIPTION
	s.author            = AUTHOR
	s.email             = EMAIL
	s.executables       = BIN_FILES
	s.bindir            = "bin"
	s.require_path      = "lib"
	s.autorequire       = ""
	s.test_files        = Dir["test/test_*.rb"]

	s.add_dependency('memcache-client', '>=1.4.0')
	s.required_ruby_version = '>= 1.8.5'

	s.files = %w(README ChangeLog Rakefile) +
		Dir.glob("{bin,doc,spec,test,lib,templates,generator,extras,website,script}/**/*") + 
		Dir.glob("ext/**/*.{h,c,rb}") +
		Dir.glob("examples/**/*.rb") +
		Dir.glob("tools/*.rb")

	s.extensions = FileList["ext/**/extconf.rb"].to_a
end
