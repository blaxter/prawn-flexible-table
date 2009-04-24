# encoding: utf-8
#
# Demonstrates the use of the :rowspan option when using Document#table
#
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', 'lib'))

require "rubygems"
gem 'prawn-core'
require "prawn"
require "prawn/layout"

Prawn::Document.generate "table_rowspan.pdf" do
  data = [ [ Prawn::Table::Cell.new( :rowspan => 10, :text => '01/01/2008' ),
             Prawn::Table::Cell.new( :rowspan => 5,  :text => 'John Doe'   ),
             '4.2', '125.00', '525.00' ],
           [ '4.2', '125.00', '525.00' ], 
           [ '4.2', '125.00', '525.00' ], 
           [ '4.2', '125.00', '525.00' ], 
           [ '4.2', '125.00', '525.00' ],
           [ Prawn::Table::Cell.new( :rowspan => 5, :text => 'Jane Doe' ),
             '3.2', '75.50', '241.60'  ],
           [ '3.2', '75.50', '241.60'  ],
           [ '3.2', '75.50', '241.60'  ],
           [ '3.2', '75.50', '241.60'  ],
           [ '3.2', '75.50', '241.60'  ] ]
  
 data << [{:text => 'Total', :colspan => 2}, '37.0', '1002.5', '3833']
  
  table data,
    :position => :center,
    :headers => ['Date', 'Employee', 'Hours', 'Rate', 'Total'],
    :border_style => :grid
end
