require "./any"

# A comment captured from a parsed K/YAML source doc.
#
# Comments are sister sidecars that live adjacent to (but independent of) the main tree.
# They are only inked to their sibling nodes by source `line` and `column` position captured at parse time.
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

# A container holding both a parsed K/YAML doc tree and its sister sidecar comments.
#
# This is only useful for cases where comments must survive the parse -> emit process unmodified. Consumers who don't need/care about comments should use straight up `KYAML.parse` which produces a `KYAML::Any` tree without any comments and no scanner overhead.
#
# - `root`: the parsed K/YAML doc tree
# - `comments`: a flat list of comments in source order. Multi-doc streams partition on `---`, so each doc only owns its own comments.
struct KYAML::Document
  getter root : KYAML::Any
  getter comments : Array(KYAML::Comment)

  def initialize(@root : KYAML::Any, @comments : Array(KYAML::Comment))
  end
end
