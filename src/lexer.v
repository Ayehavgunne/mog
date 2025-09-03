module mog

const comment = '#'
const decorator = '@'
const mog_import = 'import'
const command_delimeter = ':'
const var_delimiter = '='
const block_start = '('
const block_end = ')'
const indent = '\t'

@[if trace_logs ?]
pub fn debug(s string) {
	println('DEBUG: ${s}')
}

enum TokenType {
	var
	value
	keyword
	command_name
	command_body
	end_block
	decorator
	new_line
	eof
}

struct Token {
pub:
	token_type TokenType
	value      string
	line       int
	column     int
}

enum LexerContext {
	root
	command_block
	decorator_block
	import_block
	var_declaration
}

struct Lexer {
mut:
	text         string
	pos          int
	line         int
	column       int
	word         string
	context      LexerContext
	current_char string
	eof          bool
}

fn lex(file string) ![]Token {
	mut l := Lexer{
		text:         file
		pos:          0
		line:         1
		column:       1
		word:         ''
		context:      .root
		current_char: file[0].ascii_str()
	}
	mut tokens := []Token{}
	for !l.eof {
		token := l.get_next_token() or { return error('Syntax error: ${err}') }
		debug('${token}')
		tokens << token
	}
	if tokens.last().token_type == .eof {
		tokens.pop()
	}
	debug('END LEX\n')
	return tokens
}

fn (l Lexer) make_token(token_type TokenType, value string) Token {
	return Token{
		token_type: token_type
		value:      value
		line:       l.line
		column:     l.column
	}
}

fn (mut l Lexer) next_char() {
	if l.pos < l.text.len - 1 {
		l.pos += 1
		l.column += 1
		l.current_char = l.text[l.pos].ascii_str()
	} else {
		l.end_of_file()
	}
}

@[params]
struct PeekOptions {
	num             int = 1
	skip_whitespace bool
}

fn (mut l Lexer) peek(options PeekOptions) string {
	mut peek_pos := l.pos + options.num
	if options.skip_whitespace {
		for peek_pos < l.text.len - 1 && l.text[peek_pos].ascii_str() == ' '
			&& l.text[peek_pos].ascii_str() != '\n' {
			peek_pos += 1
		}
		return l.text[peek_pos].ascii_str()
	}
	if peek_pos > l.text.len - 1 {
		return ''
	}
	return l.text[peek_pos].ascii_str()
}

fn (mut l Lexer) eat_char() string {
	character := l.current_char
	l.next_char()
	return character
}

fn (mut l Lexer) end_of_file() {
	l.current_char = ''
	l.eof = true
}

fn (mut l Lexer) eat_decorator() Token {
	l.add_to_word([block_start])
	l.context = .decorator_block
	l.next_char()
	return l.make_token(.decorator, l.reset_word())
}

fn (mut l Lexer) eat_word() !Token {
	l.add_to_word([' ', command_delimeter, var_delimiter])
	if l.word == mog_import {
		t := l.make_token(.keyword, l.reset_word())
		if l.word == mog_import {
			l.context = .import_block
		}
		l.skip_whitespace()
		if l.current_char != block_start {
			return error('Missing opening bracket at line ${l.line} : col ${l.column}')
		}
		l.eat_newline() or { return err }
		return t
	}
	if l.current_char == command_delimeter {
		t := l.make_token(.command_name, l.reset_word())
		l.context = .command_block
		l.next_char()
		l.eat_newline() or { return err }
		return t
	}
	if l.current_char == var_delimiter
		|| l.peek(PeekOptions{ skip_whitespace: true }) == var_delimiter {
		return l.eat_var()
	}
	return error('Unkown syntax error at line ${l.line} : col ${l.column}')
}

fn (mut l Lexer) eat_command() !Token {
	if l.current_char == '' || l.peek() == '' {
		l.end_of_file()
		return l.make_token(.eof, 'EOF')
	}
	if l.current_char == '\n' {
		if l.peek() == '\n' || l.peek() != indent {
			l.context = .root
		}
		return l.eat_newline()
	}
	if l.current_char != indent {
		return error('Missing indent at line ${l.line} : col ${l.column}')
	}
	l.skip_whitespace()
	l.add_to_word(['\n', ''])
	return l.make_token(.command_body, l.reset_word())
}

fn (mut l Lexer) eat_var() Token {
	l.context = .var_declaration
	t := l.make_token(.var, l.reset_word())
	l.skip_whitespace()
	if l.current_char == var_delimiter {
		l.next_char()
		l.skip_whitespace()
	}
	return t
}

fn (mut l Lexer) add_to_word(stop_chars []string) {
	for l.current_char !in stop_chars {
		l.word += l.eat_char()
	}
}

fn (mut l Lexer) eat_value() Token {
	mut stop_chars := ['\n', block_end, comment]
	if l.context != .var_declaration {
		stop_chars << ' '
	}
	l.add_to_word(stop_chars)
	if l.current_char == comment {
		l.skip_comment()
	}
	t := l.make_token(.value, l.reset_word())
	if l.context == .var_declaration {
		l.context = .root
		l.word = l.word.trim_space()
	}
	if l.current_char == block_end {
		l.context = .root
	}
	return t
}

fn (mut l Lexer) eat_keyword() Token {
	t := l.make_token(.keyword, l.word)
	return t
}

fn (mut l Lexer) reset_word() string {
	old_word := l.word
	l.word = ''
	return old_word
}

fn (mut l Lexer) new_line() {
	l.column = 1
	l.line += 1
	l.reset_word()
}

fn (mut l Lexer) eat_newline() !Token {
	if l.current_char != '\n' {
		return error('New line character not found at line ${l.line} : col ${l.column}')
	}
	l.reset_word()
	l.next_char()
	t := l.make_token(.new_line, '\n')
	l.new_line()
	return t
}

fn (mut l Lexer) skip_comment() {
	for l.current_char != '\n' {
		l.next_char()
	}
}

fn (mut l Lexer) skip_whitespace() {
	for l.current_char == ' ' || l.current_char == '\t' {
		l.next_char()
		l.reset_word()
	}
}

fn (mut l Lexer) get_next_token() ![]Token {
	if l.current_char == '' {
		l.end_of_file()
		return [l.make_token(.eof, 'EOF')]
	}

	if l.current_char == ' ' {
		l.skip_whitespace()
	}

	if l.current_char == comment {
		l.skip_comment()
	}

	if l.current_char == decorator {
		l.next_char()
		return [l.eat_decorator()]
	}

	if l.current_char == block_end {
		l.next_char()
		l.skip_whitespace()
		l.context = .root
		return [l.make_token(.end_block, 'END_BLOCK')]
	}

	if l.context == .var_declaration {
		return [l.eat_value()]
	}

	if l.context == .decorator_block {
		mut tokens := []Token{}
		if l.current_char == '\n' {
			tokens << l.eat_newline()!
		}
		tokens << l.eat_value()
		return tokens
	}

	if l.context == .command_block {
		mut tokens := []Token{}
		if l.current_char == '\n' {
			tokens << l.eat_newline()!
		}
		if l.peek() == '\n' || l.peek() == '' {
			l.context = .root
			l.next_char()
			l.next_char()
			return [l.make_token(.end_block, 'END_BLOCK')]
		}
		tokens << l.eat_command()!
		return tokens
	}

	if l.current_char == '\n' {
		return [l.eat_newline()!]
	}

	return [l.eat_word()!]
}
