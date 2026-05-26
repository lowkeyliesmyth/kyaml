require "./comment"

# :nodoc:
module KYAML::CommentScanner
  extend self

  private enum State
    # Regular YAML content outside of any special context
    Normal
    # Inside a single-quoted scalar ('...')
    SingleQuoted
    # Inside a double-quoted scalar ("...")
    DoubleQuoted
    # Inside a YAML comment (# ...)
    Comment
    # Inside a literal or folded block scalar (| or >)
    BlockScalar
  end

  def scan(text : String) : Array(KYAML::Comment)
    # Accumulates the final list of parsed comments to return
    result = [] of KYAML::Comment
    # Iterates over each character in the input text
    reader = Char::Reader.new(text)
    # Tracks the current lexer state (normal, quoted, comment, etc.)
    state = State::Normal
    # Tracks the current line number in the input
    line = 1
    # Tracks the current column number in the input
    column = 1
    # Tracks nesting depth of flow collection types
    flow_depth = 0
    # track if previous char state was whitespace, used to validate comment start
    prev_was_ws = true
    # track if a block scalar indicator (|, >) was just seen and not yet entered
    pending_block_scalar = false
    # Column of the block scalar marker, used to detect when the block scalar ends
    block_scalar_marker_col = 0
    # Line number where the current comment started
    comment_start_line = 0
    # Column number where the current comment started
    comment_start_column = 0
    # Buffers the text content of the comment currently being scanned
    comment_buffer = String::Builder.new

    reader = Char::Reader.new(text)
    while reader.has_next?
      char = reader.current_char

      case state
      in State::Normal
        case char
        when '#'
          if prev_was_ws || column == 1
            state = State::Comment
            comment_start_line = line
            comment_start_column = column
            comment_buffer = String::Builder.new
            column += 1
            prev_was_ws = false
          else
            column += 1
            prev_was_ws = false
          end
        when '\n'
          line += 1
          column = 1
          prev_was_ws = true
        when ' ', '\t'
          column += 1
          prev_was_ws = true
        else
          column += 1
          prev_was_ws = false
        end
      in State::Comment
        case char
        when '\n'
          result << KYAML::Comment.new(comment_buffer.to_s, comment_start_line, comment_start_column)
          state = State::Normal
          line += 1
          column = 1
          prev_was_ws = true
        else
          comment_buffer << char
          column += 1
        end
      in State::SingleQuoted
      in State::DoubleQuoted
      in State::BlockScalar
      end

      reader.next_char
    end

    # Flush any trailing comment that ended at EOF without a newline
    if state == State::Comment
      result << KYAML::Comment.new(comment_buffer.to_s, comment_start_line, comment_start_column)
    end

    result
  end
end
