require "prawn/flexible-table/cell"
require "prawn/errors"

module Prawn; end

class Prawn::Document

  # Builds and renders a Document::FlexibleTable object from raw data.
  # For details on the options that can be passed, see
  # Document::FlexibleTable.new
  #
  #   data = [["Gregory","Brown"],["James","Healy"],["Jia","Wu"]]
  #
  #   Prawn::Document.generate("table.pdf") do
  #
  #     # Default table, without headers
  #     flexible_table(data)
  #
  #     # Default flexible table with headers
  #     flexible_table data, :headers => ["First Name", "Last Name"]
  #
  #     # Very close to PDF::Writer's default SimpleTable output
  #     flexible_table data,
  #       :headers            => ["First Name", "Last Name"],
  #       :font_size          => 10,
  #       :vertical_padding   => 2,
  #       :horizontal_padding => 5,
  #       :position           => :center,
  #       :row_colors         => :pdf_writer,
  #
  #     # Grid border style with explicit column widths.
  #     flexible_table data,
  #       :border_style  => :grid,
  #       :column_widths => { 0 => 100, 1 => 150 }
  #
  #   end
  #
  #   Will raise <tt>Prawn::Errors::EmptyTable</tt> given
  #   a nil or empty <tt>data</tt> paramater.
  #
  def flexible_table(data, options={})
    if data.nil? || data.empty?
      raise Prawn::Errors::EmptyTable,
        "data must be a non-empty, non-nil, two dimensional array of Prawn::Cells or strings"
    end
    Prawn::FlexibleTable.new(data,self,options).draw
  end
end


# This class implements simple PDF flexible table generation.
#
# Prawn tables have the following features:
#
#   * Can be generated with or without headers
#   * Can tweak horizontal and vertical padding of text
#   * Minimal styling support (borders / row background colors)
#   * Can be positioned by bounding boxes (left/center aligned) or an
#     absolute x position
#   * Automated page-breaking as needed
#   * Column widths can be calculated automatically or defined explictly on a
#     column by column basis
#   * Text alignment can be set for the whole table or by column
#   * Cells can have both rowspan and colspan attributes
#
# The current implementation is a bit barebones, but covers most of the
# basic needs for PDF table generation.  If you have feature requests,
# please share them at: http://groups.google.com/group/prawn-ruby
#
class Prawn::FlexibleTable

  include Prawn::Configurable

  attr_reader :column_widths # :nodoc:

  NUMBER_PATTERN = /^-?(?:0|[1-9]\d*)(?:\.\d+(?:[eE][+-]?\d+)?)?$/ #:nodoc:

  # Creates a new Document::FlexibleTable object. This is generally called
  # indirectly through Document#flexible_table but can also be used explictly.
  #
  # The <tt>data</tt> argument is a two dimensional array of either string,
  # FlexibleTable::Cell or hashes (with the options to create a Cell object),
  # organized by row, e.g.:
  #
  #    [["r1-col1","r1-col2"],["r2-col2","r2-col2"]]
  #
  #    [ [ {:text => "r1-2 col1-2", :rowspan => 2, :colspan => 2}, "r1-col3"],
  #      [ {:text => "r2 col 3", :text_color => "EEAAFF" } ],
  #      [ "r3 col1", "r3 col2", "r3 col3" ] ]
  #
  #
  # As with all Prawn text drawing operations, strings must be UTF-8 encoded.
  #
  # The following options are available for customizing your tables, with
  # defaults shown in [] at the end of each description.
  #
  # <tt>:headers</tt>:: An array of table headers, either strings or Cells. [Empty]
  # <tt>:align_headers</tt>:: Alignment of header text.  Specify for entire header (<tt>:left</tt>) or by column (<tt>{ 0 => :right, 1 => :left}</tt>). If omitted, the header alignment is the same as the column alignment.
  # <tt>:header_text_color</tt>:: Sets the text color of the headers
  # <tt>:header_color</tt>:: Manually sets the header color
  # <tt>:font_size</tt>:: The font size for the text cells . [12]
  # <tt>:horizontal_padding</tt>:: The horizontal cell padding in PDF points [5]
  # <tt>:vertical_padding</tt>:: The vertical cell padding in PDF points [5]
  # <tt>:padding</tt>:: Horizontal and vertical cell padding (overrides both)
  # <tt>:border_width</tt>:: With of border lines in PDF points [1]
  # <tt>:border_style</tt>:: If set to :grid, fills in all borders. If set to :underline_header, underline header only. Otherwise, borders are drawn on columns only, not rows
  # <tt>:border_color</tt>:: Sets the color of the borders.
  # <tt>:position</tt>:: One of <tt>:left</tt>, <tt>:center</tt> or <tt>n</tt>, where <tt>n</tt> is an x-offset from the left edge of the current bounding box
  # <tt>:width:</tt>:: A set width for the table, defaults to the sum of all column widths
  # <tt>:column_widths:</tt>:: A hash of indices and widths in PDF points.  E.g. <tt>{ 0 => 50, 1 => 100 }</tt>
  # <tt>:row_colors</tt>:: An array of row background colors which are used cyclicly.
  # <tt>:align</tt>:: Alignment of text in columns, for entire table (<tt>:center</tt>) or by column (<tt>{ 0 => :left, 1 => :center}</tt>)
  #
  # Row colors are specified as html encoded values, e.g.
  # ["ffffff","aaaaaa","ccaaff"].  You can also specify
  # <tt>:row_colors => :pdf_writer</tt> if you wish to use the default color
  # scheme from the PDF::Writer library.
  #
  # See Document#flexible_table for typical usage, as directly using this class is
  # not recommended unless you know why you want to do it.
  #
  def initialize(data, document, options={})
    unless data.all? { |e| Array === e }
      raise Prawn::Errors::InvalidTableData,
        "data must be a two dimensional array of Prawn::Cells or strings"
    end

    @data     = data
    @document = document

    Prawn.verify_options [:font_size,:border_style, :border_width,
     :position, :headers, :row_colors, :align, :align_headers,
     :header_text_color, :border_color, :horizontal_padding,
     :vertical_padding, :padding, :column_widths, :width, :header_color ],
     options

    configuration.update(options)

    if padding = options[:padding]
      C(:horizontal_padding => padding, :vertical_padding => padding)
    end

    if options[:row_colors] == :pdf_writer
      C(:row_colors => ["ffffff","cccccc"])
    end

    if options[:row_colors]
      C(:original_row_colors => C(:row_colors))
    end

    # Once we have all configuration setted...
    normalize_data
    check_rows_lengths
    calculate_column_widths(options[:column_widths], options[:width])
  end

  attr_reader :column_widths #:nodoc:

  # Width of the table in PDF points
  #
  def width
     @column_widths.inject(0) { |s,r| s + r }
  end

  # Draws the table onto the PDF document
  #
  def draw
    @parent_bounds = @document.bounds
    case C(:position)
    when :center
      x = (@document.bounds.width - width) / 2.0
      dy = @document.bounds.absolute_top - @document.y
      @document.bounding_box [x, @parent_bounds.top], :width => width do
        @document.move_down(dy)
        generate_table
      end
    when Numeric
      x, y = C(:position), @document.y - @document.bounds.absolute_bottom
      @document.bounding_box([x,y], :width => width) { generate_table }
    else
      generate_table
    end
  end

  private

  def default_configuration
    { :font_size           => 12,
      :border_width        => 1,
      :position            => :left,
      :horizontal_padding  => 5,
      :vertical_padding    => 5 }
  end

  # Check that all rows are well formed with the same length.
  #
  # Will raise an <tt>Prawn::Errors::InvalidTableData</tt> exception
  # in case that a bad formed row is found
  def check_rows_lengths
    tables_width = nil
    actual_row   = 0
    old_index    = -1
    check_last_row = lambda {
      tables_width ||= old_index # only setted the first time
      if tables_width != nil && tables_width != old_index
        raise Prawn::Errors::InvalidTableData,
          "The row #{actual_row} has a length of #{old_index + 1}, " +
          "it should be of #{tables_width + 1} according to the previous rows"
      end
    }
    each_cell_with_index do |cell, i, n_row|
      if actual_row != n_row # is new row
        check_last_row.call
        actual_row = n_row
      end
      old_index = i + cell.colspan - 1
    end
    check_last_row.call
  end

  # An iterator method around renderable_data method.
  #
  # The issue using renderable_data is that in each iteration you don't know
  # the real index for that cell, due to colspan & rowspan values of the
  # previous cells.
  #
  # So this method yields every cell (Prawn::FlexibleTable::Cell) with its column
  # index.
  #
  # Example:
  #   +-----------+
  #   | A     | B |
  #   +-------+---+
  #   | C | D | E |
  #   +---+---+---+
  # The values in each iteration will be:
  #  * Cell A, 0, 0
  #  * Cell B, 2, 0
  #  * Cell C, 0, 1
  #  * Cell D, 1, 1
  #  * Cell E, 2, 1
  #
  def each_cell_with_index
    rowspan_cells = {}
    n_row = 0
    renderable_data.each do |row|
      index = 0
      rowspan_cells.each_value { |v|    v[:rowspan] -= 1 }
      rowspan_cells.delete_if  { |k, v| v[:rowspan] == 0 }
      row.each do |cell|
        while rowspan_cells[ index ] do
          index += rowspan_cells[ index ][:colspan]
        end

        yield cell, index, n_row

        if cell.rowspan > 1
          rowspan_cells[ index ] = { :rowspan => cell.rowspan,
                                     :colspan => cell.colspan }
        end
        index += cell.colspan
      end # row.each
      n_row += 1
    end # renderable_data.each
  end

  def cells_width( cell )
    width = 2 * C(:horizontal_padding) + cell.to_s.lines.map do |e|
      @document.width_of(e, :size => C(:font_size))
    end.max.to_f
    width.ceil
  end

  def calculate_column_widths(manual_widths=nil, width=nil)
    @column_widths = [0] * @data[0].inject(0){ |total, e| total + e.colspan }

    # Firstly, calculate column widths for cells without colspan attribute
    colspan_cell_to_proccess = []
    each_cell_with_index do |cell, index|
      if cell.colspan <= 1
        length = cells_width( cell )
        @column_widths[ index ] = length if length > @column_widths[ index ]
      else
        colspan_cell_to_proccess << [ cell, index ]
      end
    end

    # Secondly, calculate column width for cells with colspan attribute
    # and update @column_widths properly
    colspan_cell_to_proccess.each do |cell, index|
      current_colspan = cell.colspan
      calculate_width = @column_widths.slice( index, current_colspan ).
        inject( 0 ) { |t, w| t + w }
      length = cells_width( cell )
      if length > calculate_width
        # This is a little tricky, we have to increase each column
        # that the actual colspan cell use, by a proportional part
        # so the sum of these widths will be equal to the actual width
        # of our colspan cell
        difference  = length - calculate_width
        increase    = ( difference / current_colspan ).floor
        increase_by = [ increase ] * current_colspan
        # it's important to sum, in total, the difference, so if
        # difference is, e.g., 3 and current_colspan is 2, increase_by
        # will be [ 1, 1 ], but actually we want to be [ 2, 1 ]
        extra_dif   = difference - increase * current_colspan
        extra_dif.times { |n| increase_by[n] += 1 }
        current_colspan.times do |j|
          @column_widths[ index + j ] += increase_by[j]
        end
      end
    end

    # Thridly, establish manual column widths
    manual_width = 0
    manual_widths.each { |k,v|
      @column_widths[k] = v; manual_width += v } if manual_widths

    # Finally, ensures that the maximum width of the document is not exceeded.
    # Takes into consideration the manual widths specified (With full manual
    # widths specified, the width can exceed the document width as manual
    # widths are taken as gospel)
    max_width = width || @document.margin_box.width
    calculated_width = @column_widths.inject {|sum,e| sum += e }

    if calculated_width > max_width
      shrink_by = (max_width - manual_width).to_f /
        (calculated_width - manual_width)
      @column_widths.each_with_index { |c,i|
        @column_widths[i] = c * shrink_by if manual_widths.nil? ||
          manual_widths[i].nil?
      }
    elsif width && calculated_width < width
      grow_by = (width - manual_width).to_f /
        (calculated_width - manual_width)
      @column_widths.each_with_index { |c,i|
        @column_widths[i] = c * grow_by if manual_widths.nil? ||
          manual_widths[i].nil?
      }
    end
  end


  def renderable_data
    C(:headers) ? C(:headers) + @data : @data
  end

  # Transform all items from @data into Prawn::FlexibleTable::Cell objects
  def normalize_data
    normalize = lambda { |data|
      data.map do |row|
        row.map do |cell|
          unless cell.is_a?( Hash ) || cell.is_a?( Prawn::FlexibleTable::Cell )
            cell = { :text => cell.to_s }
          end
          if cell.is_a?( Hash )
            cell = Prawn::FlexibleTable::Cell.new( cell )
          end
          cell.document = @document
          cell
        end
      end
    }
    @data = normalize.call( @data )
    # C is an alias to configuration method, which is a wrapper around @config
    @config[:headers] = normalize.call( [ C(:headers) ] ) if C(:headers)

  end

  def generate_table
    page_contents = []
    y_pos = @document.y
    rowspan_cells = {}

    @document.font_size C(:font_size) do
      renderable_data.each_with_index do |row, index|
        c = Prawn::FlexibleTable::CellBlock.new(@document)

        rowspan_cells.each_value { |v|    v[:rowspan] -= 1 }
        rowspan_cells.delete_if  { |k, v| v[:rowspan] == 0 }

        col_index = 0
        row.each do |e|
          align = case C(:align)
            when Hash
              C(:align)[ col_index ]
            else
              C(:align)
          end
          align ||= e.to_s =~ NUMBER_PATTERN ? :right : :left

          while rowspan_cells[ col_index ] do
            c << rowspan_cells[ col_index ][:cell_fake]
            col_index += rowspan_cells[ col_index ][:colspan]
          end

          colspan = e.colspan
          rowspan = e.rowspan

          width = @column_widths.
            slice( col_index, colspan ).
            inject { |sum, width|  sum + width }

          e.width              = width
          e.horizontal_padding = C(:horizontal_padding)
          e.vertical_padding   = C(:vertical_padding)
          e.border_width       = C(:border_width)
          e.align            ||= align

          if rowspan > 1
            cell_fake = Prawn::FlexibleTable::CellFake.new( :width => width )
            rowspan_cells[ col_index ] = {
              :rowspan   => rowspan,
              :colspan   => colspan,
              :cell_fake => cell_fake
            }
          end
          c << e
          col_index += colspan
        end # row.each do |e|

        bbox = @parent_bounds.stretchy? ? @document.margin_box : @parent_bounds
        fit_in_current_page = c.height <= y_pos - bbox.absolute_bottom
        if ! fit_in_current_page then
          if C(:headers) && page_contents.length == 1
            @document.start_new_page
            y_pos = @document.y
          else
            draw_page(page_contents)
            @document.start_new_page
            if C(:headers) && page_contents.any?
              page_contents = [page_contents[0]]
              y_pos = @document.y - page_contents[0].height
            else
              page_contents = []
              y_pos = @document.y
            end
          end
        end

        page_contents << c

        y_pos -= c.height

        if index == renderable_data.length - 1
          draw_page(page_contents)
        end

      end
    end
  end

  def draw_page(contents)
    return if contents.empty?

    if C(:border_style) == :underline_header
      contents.each { |e| e.border_style = :none }
      contents.first.border_style = :bottom_only if C(:headers)
    elsif C(:border_style) == :grid || contents.length == 1
      contents.each { |e| e.border_style = :all }
    else
      contents.first.border_style = C(:headers) ? :all : :no_bottom
      contents.last.border_style = :no_top
    end

    if C(:headers)
      contents.first.cells.each_with_index do |e,i|
        if C(:align_headers)
          case C(:align_headers)
            when Hash
              align = C(:align_headers)[i]
            else
              align = C(:align_headers)
            end
        end
        e.align = align if align
        e.text_color = C(:header_text_color) if C(:header_text_color)
        e.background_color = C(:header_color) if C(:header_color)
      end
    end

    # modified the height of the cells with rowspan attribute
    contents.each_with_index do |x, i|
      x.cells.each do |cell|
        if cell.rowspan > 1
          heights_per_row ||= contents.map { |x| x.height }
          cell.height = heights_per_row.
              slice( i, cell.rowspan ).inject(0){ |sum, h| sum + h }
        end
      end
    end

    contents.each do |x|
      unless x.background_color
        x.background_color = next_row_color if C(:row_colors)
      end
      x.border_color = C(:border_color) if C(:border_color)

      x.draw
    end

    reset_row_colors
  end


  def next_row_color
    color = C(:row_colors).shift
    C(:row_colors).push(color)
    color
  end

  def reset_row_colors
    C(:row_colors => C(:original_row_colors).dup) if C(:row_colors)
  end

end
