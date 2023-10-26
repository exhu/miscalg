#[derive(PartialEq, Debug)]
enum TokenKind {
    Unknown,
    Whitespace,
    Eol,
    Eof,
    Number { value: i32 },
    Mul,
    Sum,
}

struct TokenSpan {
    start: usize,
    /// end == start if empty
    /// for 1 char length end = start+1
    end: usize,
}

struct Token {
    kind: TokenKind,
    span: TokenSpan,
}

struct TokenParsingContext {
    /// utf8 converted to code points
    chars: Vec<char>,
    // positions in chars for line end chars
    //line_ends: Vec<usize>,
}

// syntax parsing
struct ParsingContext {
    cur_token: Token,
    next_token: Token,
}

fn is_number(c: char) -> bool {
    c.is_ascii_digit()
}

fn read_number(src: &[char], start: usize) -> Option<Token> {
    let mut chars_read = 0;
    for i in start..src.len() {
        let c = src[i];
        if !is_number(c) {
            break;
        }
        chars_read += 1;
    }

    let back_str: String = src[start..start + chars_read].iter().collect();
    let num = back_str.parse().ok()?;
    Some(Token {
        kind: TokenKind::Number { value: num },
        span: TokenSpan {
            start: start,
            end: start + chars_read,
        },
    })
}

fn read_whitespace(src: &[char], start: usize) -> Option<Token> {
    for i in start..src.len() {
        let c = src[i];
        if !c.is_ascii_whitespace() {
            if i == start {
                return None;
            }

            return Some(Token {
                kind: TokenKind::Whitespace,
                span: TokenSpan {
                    start: start,
                    end: i,
                },
            });
        }
    }

    return Some(Token {
        kind: TokenKind::Whitespace,
        span: TokenSpan {
            start: start,
            end: src.len(),
        },
    });
}

fn read_token(src: &[char], start: usize) -> Token {
    read_whitespace(src, start)
        .or_else(|| read_number(src, start))
        .or(Some(Token {
            kind: TokenKind::Eof,
            span: TokenSpan { start, end: start },
        }))
        .unwrap()
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
        assert_eq!(t.kind, TokenKind::Whitespace);
        let t = read_token(&chars, t.span.end);
        assert_eq!(t.kind, TokenKind::Number { value: 123 });
    }
}
