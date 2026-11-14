require "./any"
require "yaml"

# A comment captured from a parsed K/YAML source doc.
#
# Comments are sister sidecars that live adjacent to (but independent of) the main tree.
# They are only linked to their sibling nodes by source `line` and `column` position captured at parse time.
#
# - `text`: the comment body with leading `#` and trailing newline stripped
# - `line`: 1-based line number in the source doc (keyed on the `#` character position)
# - `column`: 1-based column number in the source doc (keyed on the `#` character position)
struct KYAML::Comment
  getter text : String
  getter line : Int32
  getter column : Int32

  def initialize(@text : String, @line : Int32, @column : Int32)
  end
end
