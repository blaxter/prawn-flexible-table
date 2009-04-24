# encoding: utf-8

puts "Prawn specs: Running on Ruby Version: #{RUBY_VERSION}"

require "rubygems"
require "test/spec"                                                
require "mocha"
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib') 

require "prawn"
require "prawn/layout"
$LOAD_PATH << File.join(Prawn::BASEDIR, 'vendor','pdf-inspector','lib')

Prawn.debug = true

gem 'pdf-reader', ">=0.7.3"
require "pdf/reader"          
require "pdf/inspector"

def create_pdf(klass=Prawn::Document)
  @pdf = klass.new(:left_margin   => 0,
                   :right_margin  => 0,
                   :top_margin    => 0,
                   :bottom_margin => 0)
end    

def width_table_for( pdf, hpad, fs, cells )
  cells.inject( 2 * cells.size * hpad ) do |ret, cell|
    ret + pdf.width_of( cell, :size => fs ).ceil
  end
end
