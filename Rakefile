require 'rubygems'
require 'rake'
require 'rake/testtask'
require "rake/rdoctask"
require "rake/gempackagetask"

PRAWN_FLEXIBLE_TABLE_VERSION = "0.1.2"

task :default => [:test]

desc "Run all tests, test-spec and mocha required"
Rake::TestTask.new do |test|
  test.libs << "spec"
  test.test_files = Dir[ "spec/*_spec.rb" ]
  test.verbose = true
end

desc "Show library's code statistics"
task :stats do
	require 'code_statistics'
	CodeStatistics.new( ["prawn-flexible-table", "lib"],
	                    ["Specs", "spec"] ).to_s
end

desc "genrates documentation"
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_files.include( "README", "lib/" )
  rdoc.main     = "README"
  rdoc.rdoc_dir = "doc/html"
  rdoc.title    = "Prawn Flexible Table Documentation"
end

desc "run all examples, and then diff them against reference PDFs"
task :examples do
  mkdir_p "output"
  examples = Dir["examples/**/*.rb"]
  t = Time.now
  puts "Running Examples"
  examples.each { |file| `ruby -Ilib #{file}` }
  puts "Ran in #{Time.now - t} s"
  `mv *.pdf output`
end

spec = Gem::Specification.new do |spec|
  spec.name = "prawn-flexible-table"
  spec.version = PRAWN_FLEXIBLE_TABLE_VERSION
  spec.platform = Gem::Platform::RUBY
  spec.summary = "An extension to Prawn that provides flexible table support"
  spec.files =  Dir.glob("{examples,lib,spec,vendor,data}/**/**/*") +
                      ["Rakefile"]
  spec.require_path = "lib"

  spec.test_files = Dir[ "test/*_test.rb" ]
  spec.has_rdoc = true
  spec.extra_rdoc_files = %w{README}
  spec.rdoc_options << '--title' << 'Prawn Documentation' <<
                       '--main'  << 'README' << '-q'
  spec.author = "Jesús García Sáez"
  spec.email = "blaxter@gmail.com"
  spec.rubyforge_project = "prawn"
  spec.homepage = "http://github.com/blaxter/prawn-flexible-table"
  spec.description = <<END_DESC
  An extension to Prawn that provides flexible table support, that means be able to create tables with rowspan and colspan attributes for each cell
END_DESC
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
