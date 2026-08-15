module mog

import os

const illegal_key_chars = [
	'"',
	"'",
	'.',
	'!',
	'@',
	'#',
	'$',
	'%',
	'^',
	'&',
	'*',
	'-',
	'+',
	'(',
	')',
	'{',
	'}',
	'[',
	']',
	'|',
	'<',
	'>',
	'?',
	'.',
	',',
	'/',
	'\\',
	':',
	';',
	'~',
	'`',
	'\n',
]
const illegal_key_start_characters = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']

pub fn read_env_file(path string, env_file_path string) {
	if env_file_path.len > 0 {
		env_file := os.read_file('${path}/${env_file_path}') or {
			eprint('Failed to read env file\n')
			exit(1)
		}
		parse_env_file(env_file)
	}
}

struct EnvParser {
	text string
mut:
	current_char string
	pos          int
	eof          bool
}

fn parse_env_file(file string) {
	mut e := EnvParser{
		text:         file
		current_char: file[0].ascii_str()
	}
	mut env_vars := map[string]string{}
	for !e.eof {
		key, value := e.eat()
		if key.len > 0 {
			env_vars[key] = value
		}
	}
	for key, value in env_vars {
		os.setenv(key, value, true)
	}
}

fn (mut e EnvParser) next_char() {
	e.pos += 1
	if e.text.len < e.pos + 1 {
		e.eof = true
		e.current_char = ''
		return
	}
	e.current_char = e.text[e.pos].ascii_str()
}

fn (mut e EnvParser) peek(options PeekOptions) string {
	mut peek_pos := e.pos + options.num
	if options.skip_whitespace {
		for peek_pos < e.text.len - 1 && e.text[peek_pos].ascii_str() == ' '
			&& e.text[peek_pos].ascii_str() != '\n' {
			peek_pos += 1
		}
		return e.text[peek_pos].ascii_str()
	}
	if peek_pos > e.text.len - 1 {
		return ''
	}
	return e.text[peek_pos].ascii_str()
}

fn (mut e EnvParser) eat_till(characters ...string) string {
	mut word := ''
	for e.current_char !in characters && !e.eof {
		word += e.current_char
		e.next_char()
	}
	return word
}

fn (mut e EnvParser) eat_key() string {
	for e.current_char == '\n' {
		e.next_char()
	}
	for e.current_char == comment {
		e.skip_comment()
	}
	word := e.eat_till('=').trim_space()
	for c in illegal_key_chars {
		if word.contains(c) {
			eprintln('Key cannot contain character (${c}) Key: ${word}')
			exit(3)
		}
	}
	for c in illegal_key_start_characters {
		if word.starts_with(c) {
			eprint('Key cannot start with (${c})')
			exit(3)
		}
	}
	return word
}

fn (mut e EnvParser) eat_escape() string {
	e.next_char()
	ch := e.current_char
	e.next_char()
	if ch == '\n' {
		return ''
	}
	if ch == 't' {
		return '\t'
	}
	return ch
}

fn (mut e EnvParser) leave_escape() string {
	mut ch := e.current_char
	e.next_char()
	ch += e.current_char
	e.next_char()
	return ch
}

fn (mut e EnvParser) eat_string() string {
	mut quote := "'"
	mut word := ''

	if e.current_char == '"' {
		quote = '"'
	}

	e.next_char()

	for e.current_char != quote && !e.eof {
		if e.current_char == escape {
			if e.peek() in quotes {
				word += e.leave_escape()
			} else {
				word += e.eat_escape()
			}
			continue
		}

		word += e.current_char
		e.next_char()
	}

	if e.current_char == quote {
		e.next_char()
	}

	return word
}

fn (mut e EnvParser) eat_value() string {
	if e.current_char == '=' {
		e.next_char()
	}
	mut word := ''
	for e.current_char !in ['\n', comment] && !e.eof {
		if e.current_char in quotes {
			word = e.eat_string()
			break
		}
		if e.current_char == escape && e.peek() == '\n' {
			e.next_char()
		}
		word += e.current_char
		e.next_char()
	}
	for e.current_char == comment || e.current_char == ' ' {
		if e.current_char == comment {
			e.skip_comment()
		}
		if e.current_char == ' ' {
			e.eat_till('\n')
		}
	}
	return word
}

fn (mut e EnvParser) skip_comment() {
	e.eat_till('\n')
	e.next_char()
}

fn (mut e EnvParser) eat() (string, string) {
	for e.current_char == comment {
		e.skip_comment()
	}
	return e.eat_key(), e.eat_value()
}
