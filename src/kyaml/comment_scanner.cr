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
    # indent of block scalar's parent line (first non-ws column - 1)
    parent_indent = 0
    # true once a non-ws char is seen at column > parent_indent on the current line, confirming the line belongs to the block scalar
    # resets to false on newlines.
    # if a line reaches a non-ws char without being committed, the block scalar has ended.
    block_line_committed = false

    # column of first non-whitespace char on current line
    # resets on newlines, captures parent indent when |/> marker is seen
    line_first_nonws_col = 0
    # Line number where the current comment started
    comment_start_line = 0
    # Column number where the current comment started
    comment_start_column = 0
    # Buffers the text content of the comment currently being scanned
    comment_buffer = String::Builder.new

    reader = Char::Reader.new(text)
    while reader.has_next?
      char = reader.current_char
      # when true, the current character is processed again on the next loop iteration, but now under the new state
      reprocess = false

      case state
      in State::Normal
        if line_first_nonws_col == 0 && char != ' ' && char != '\t' && char != '\n'
          line_first_nonws_col = column
        end
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
          if pending_block_scalar
            state = State::BlockScalar
            pending_block_scalar = false
          end
          line += 1
          column = 1
          prev_was_ws = true
          line_first_nonws_col = 0
          block_line_committed = false
        when ' ', '\t'
          column += 1
          prev_was_ws = true
        when '[', '{'
          flow_depth += 1
          column += 1
          prev_was_ws = false
        when ']', '}'
          flow_depth -= 1 if flow_depth > 0
          column += 1
          prev_was_ws = false
        when '|', '>'
          if flow_depth == 0 && (column == 1 || prev_was_ws)
            pending_block_scalar = true
            parent_index = line_first_nonws_col - 1
          end
          column += 1
          prev_was_ws = false
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
          if pending_block_scalar
            state = State::BlockScalar
            pending_block_scalar = false
          else
            state = State::Normal
          end
          line += 1
          column = 1
          prev_was_ws = true
          line_first_nonws_col = 0
          block_line_committed = false
        else
          comment_buffer << char
          column += 1
        end
      in State::BlockScalar
        case char
        when ' ', '\t'
          column += 1
        when '\n'
          line += 1
          column = 1
          block_line_committed = false
          prev_was_ws = true
        else
          if block_line_committed
            column += 1
          elsif column - 1 <= parent_indent
            state = State::Normal
            reprocess = true
          else
            block_line_committed = true
            column += 1
          end
        end
      end

      reader.next_char unless reprocess
    end

    # Flush any trailing comment that ended at EOF without a newline
    if state == State::Comment
      result << KYAML::Comment.new(comment_buffer.to_s, comment_start_line, comment_start_column)
    end

    result
  end
end
