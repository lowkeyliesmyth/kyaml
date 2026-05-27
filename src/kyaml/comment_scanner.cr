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
        when '\''
          state = State::SingleQuoted
          column += 1
          prev_was_ws = false
        when '"'
          state = State::DoubleQuoted
          column += 1
          prev_was_ws = false
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
      in State::SingleQuoted
        case char
        when '\''
          if reader.has_next? && reader.peek_next_char == '\''
            # escaped single quote (''), consume both chars and stay in SingleQuoted
            reader.next_char
            column += 2
          else
            # closing quote, go back to normal
            state = State::Normal
            column += 1
            prev_was_ws = false
          end
        when '\n'
          line += 1
          column = 1
        else
          column += 1
        end
      in State::DoubleQuoted
        case char
        when '\\'
          # backslash escape. consume the `\` and the following char as a single unit
          # escaped char _may_ be `\n` which resets line/column
          column += 1
          if reader.has_next?
            reader.next_char
            if reader.current_char == '\n'
              line += 1
              column = 1
            else
              column += 1
            end
          end
        when '"'
          state = State::Normal
          column += 1
          prev_was_ws = false
        when '\n'
          line += 1
          column = 1
        else
          column += 1
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
