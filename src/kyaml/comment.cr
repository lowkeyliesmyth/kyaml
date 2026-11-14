require "./any"
require "yaml"

# A comment captured from a parsed K/YAML source doc.
#
# A comment stores its text and the original one-based source line and column coordinates.
# These coordinates identify the original source position. But eventual comment placement is determined at emission time.
struct KYAML::Comment
  getter text : String
  getter line : Int32
  getter column : Int32

  def initialize(@text : String, @line : Int32, @column : Int32)
  end
end
