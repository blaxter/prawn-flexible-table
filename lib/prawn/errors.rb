module Prawn; end

module Prawn::Errors
 # This error is raised when table data is malformed
 InvalidTableData = Class.new(StandardError)

 # This error is raised when an empty or nil table is rendered
 EmptyTable = Class.new(StandardError)
end
