#[derive(PartialEq, Debug)]
enum TokenKind {
    Unknown,
    Eol,
    Eof,
    Number { value: i32 },
    Mul,
    Sum,
}

struct TokenSpan {
    start: usize,
    end: usize,
}

struct Token {
    kind: TokenKind,
    span: TokenSpan,
}

struct TokenParsingContext {
    /// utf8 converted to code points
    chars: Vec<char>,
    /// positions in chars for line end chars
    line_ends: Vec<usize>,
}

// syntax parsing
struct ParsingContext {
    cur_token: Token,
    next_token: Token,
}

fn is_number(c: char) -> bool {
    c.is_ascii_digit()
}

fn read_number(src: &[char], start: usize) -> Token {
    let mut chars_read = 0;
    for i in start..src.len() {
        let c = src[i];
        if !is_number(c) {
            break;
        }
        chars_read += 1;
    }

    let back_str: String = src[start..start + chars_read].iter().collect();
    let num = back_str.parse().unwrap();
    Token {
        kind: TokenKind::Number { value: num },
        span: TokenSpan {
            start: start,
            end: start + chars_read - 1,
        },
    }
}

fn skip_whitespace(src: &[char], start: usize) -> usize {
    for i in start..src.len() {
        if !src[i].is_ascii_whitespace() {
            return i;
        }
    }
    return src.len() - 1;
}

fn read_token(src: &[char], start: usize) -> Token {
    let start = skip_whitespace(src, start);
    let c = src[start];
    if is_number(c) {
        read_number(src, start)
    } else {
        Token {
            kind: TokenKind::Eof,
            span: TokenSpan { start, end: start },
        }
    }
}

fn main() {
    println!("Hello, world!");
}

#[cfg(test)]
mod test {
    use crate::{read_token, TokenKind};

    #[test]
    fn test1() {
        let chars: Vec<char> = " 123".chars().collect();
        let t = read_token(&chars, 0);
        assert_eq!(t.kind, TokenKind::Number { value: 123 });
    }
}
