///|
struct Replacement {
  start_line : Int
  start_column : Int
  end_line : Int
  end_column : Int
  replacement : String
  unit : PosUnit
} derive(Eq)

///|
impl Compare for Replacement with compare(self, other) {
  match self.start_line.compare(other.start_line) {
    0 =>
      match self.start_column.compare(other.start_column) {
        0 => 0
        x => x
      }
    x => x
  }
}

///|
pub(all) enum PosUnit {
  Unicode
} derive(Eq, Compare)

///|
priv struct OffsetReplacement {
  start_offset : Int
  end_offset : Int
  replacement : String
}

///|
/// Creates a `Replacement` for a single point in the text, referring to the left side of the character.
/// 
/// # Parameters
/// - `line`: The line number (0-based, in Unicode characters) where the replacement occurs.
/// - `column`: The column number (0-based, in Unicode characters) where the replacement occurs.
/// - `replacement`: The string to insert at the specified position.
pub fn point(
  line : Int,
  column : Int,
  replacement : String,
  unit? : PosUnit = Unicode,
) -> Replacement {
  {
    start_line: line,
    end_line: line,
    start_column: column,
    end_column: column - 1,
    replacement,
    unit,
  }
}

///|
/// Creates a `Replacement` for a char in the text.
/// 
/// # Parameters
/// - `line`: The line number (0-based, in Unicode characters) where the replacement occurs.
/// - `column`: The column number (0-based, in Unicode characters) where the replacement occurs.
/// - `replacement`: The string to insert at the specified point.
pub fn char_at(
  line : Int,
  column : Int,
  replacement : String,
  unit? : PosUnit = Unicode,
) -> Replacement {
  {
    start_line: line,
    end_line: line,
    start_column: column,
    end_column: column,
    replacement,
    unit,
  }
}

///|
/// Creates a `Replacement` for a range in a single line.
/// 
/// # Parameters
/// - `line`: The line number (0-based, in Unicode characters) where the replacement occurs.
/// - `start_column`: The starting column number (0-based, in Unicode characters) of the range.
/// - `end_column`: The ending column number (0-based, in Unicode characters, inclusive) of the range.
/// - `replacement`: The string to replace the specified range.
pub fn range(
  line : Int,
  start_column : Int,
  end_column : Int,
  replacement : String,
  unit? : PosUnit = PosUnit::Unicode,
) -> Replacement {
  {
    start_line: line,
    end_line: line,
    start_column,
    end_column,
    replacement,
    unit,
  }
}

///|
/// Creates a `Replacement` for a range that spans multiple lines.
/// 
/// # Parameters
/// - `start`: A tuple `(line, column)` representing the start of the range (0-based, in Unicode characters).
/// - `end`: A tuple `(line, column)` representing the end of the range (0-based, in Unicode characters, inclusive).
/// - `replacement`: The string to replace the specified range.
/// 
pub fn multiline(
  start : (Int, Int),
  end : (Int, Int),
  replacement : String,
  unit? : PosUnit = PosUnit::Unicode,
) -> Replacement {
  {
    start_line: start.0,
    end_line: end.0,
    start_column: start.1,
    end_column: end.1,
    replacement,
    unit,
  }
}

///|
test {
  let template =
    #|fn get(🐰){
    #| ...
    #| ...
    #| h($)
    #|}
  inspect(
    splice(template, [
      char_at(3, 3, "1001"),
      range(0, 7, 7, "x : Int"),
      point(0, 9, " -> Int "),
      multiline((1, 1), (2, 3), "f(x)\n g()"),
    ]),
    content=(
      #|fn get(x : Int) -> Int {
      #| f(x)
      #| g()
      #| h(1001)
      #|}
    ),
  )
}

///|
/// Splices substrings in `template` at the specified ranges with the given replacements.
/// 
/// The replacement ranges must not overlap.
/// 
/// # Parameters
/// 
/// - `template`: The original string to perform splicing on.
/// - `replacements`: An array of `Replacement` structs specifying the ranges and their replacements.
///           
/// # Returns
/// - The modified string after applying all replacements.
/// 
/// # Exceptions
/// - Raises an Error if any of the specified ranges are invalid or out of bounds.
/// 
/// # Examples
/// ```
/// let template =
///   #|fn get(🐰){
///   #| ...
///   #| ...
///   #| h($)
///   #|}
/// inspect(
///   splice(template, [
///     multiline((1, 1), (2, 3), "f(x)\n g()"),
///     range(0, 7, 7, "x : Int"),
///     point(0, 9, " -> Int "),
///     char_at(3, 3, "1001"),
///   ]),
///   content=(
///     #|fn get(x : Int) -> Int {
///     #| f(x)
///     #| g()
///     #| h(1001)
///     #|}
///   ),
/// )
/// ```
pub fn splice(
  template : StringView,
  replacements : Array[Replacement],
) -> String {
  replacements.sort()
  let mut last_offset = 0
  let buf = StringBuilder::new()
  let (chars, replacements) = get_utf16_codeunit_index(template, replacements)
  for subst in replacements {
    buf
    ..write_iter(chars[last_offset:subst.start_offset].iter())
    ..write_string(subst.replacement)
    last_offset = subst.end_offset + 1
  }
  buf.write_iter(chars[last_offset:].iter())
  buf.to_string()
}

///|
fn get_utf16_codeunit_index(
  s : StringView,
  xs : Array[Replacement],
) -> (Array[Char], Array[OffsetReplacement]) {
  let line_offsets = [0]
  let chars = s.to_array()
  for i, c in s {
    if c == '\n' {
      line_offsets.push(i + 1)
    }
  }
  let xs = xs.map(fn(x) {
    OffsetReplacement::{
      start_offset: line_offsets[x.start_line] + x.start_column,
      end_offset: line_offsets[x.end_line] + x.end_column,
      replacement: x.replacement,
    }
  })
  (chars, xs)
}
