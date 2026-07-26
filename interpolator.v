module mog

import os

const open_replacement = '{'
const close_replacement = '}'
const open_eval = '['
const close_eval = ']'
const escape = '\\'
const mog_var_char = '$'
const import_namespace_delimiter = '.'
pub const built_in_vars = {
	'\$clear':            '\ec'
	'\$normal':           '\e[0m'
	'\$bold':             '\e[1m'
	'\$dim':              '\e[2m'
	'\$italic':           '\e[3m'
	'\$underline':        '\e[4m'
	'\$invert':           '\e[7m'
	'\$strikethrough':    '\e[9m'
	'\$normal_intensity': '\e[22m'
	'\$black':            '\e[30m'
	'\$red':              '\e[31m'
	'\$green':            '\e[32m'
	'\$yellow':           '\e[33m'
	'\$blue':             '\e[34m'
	'\$magenta':          '\e[35m'
	'\$cyan':             '\e[36m'
	'\$white':            '\e[37m'
	'\$bg_black':         '\e[40m'
	'\$bg_red':           '\e[41m'
	'\$bg_green':         '\e[42m'
	'\$bg_yellow':        '\e[43m'
	'\$bg_blue':          '\e[44m'
	'\$bg_magenta':       '\e[45m'
	'\$bg_cyan':          '\e[46m'
	'\$bg_white':         '\e[47m'
	'\$silence_out':      ' > /dev/null '
	'\$silence_err':      ' 2> /dev/null '
	'\$silence_out_err':  ' > /dev/null 2>&1 '
}

fn replace_mog_arg(replacement string, args []string) string {
	for index, arg in args {
		if replacement == '$${index + 1}' {
			return arg
		}
	}
	match replacement {
		'$#' {
			return '${args.len}'
		}
		'$@' {
			return args.join(' ')
		}
		'$*' {
			return args.join(' ')
		}
		'$"@"' {
			return '"${args.join('" "')}"'
		}
		'$"*"' {
			return '"${args.join(' ')}"'
		}
		else {}
	}

	if replacement in built_in_vars {
		return built_in_vars[replacement]
	}
	return ''
}

struct Interpolator {
mut:
	mog          Mog
	line         string
	pos          int
	current_char string
	is_var       bool
	eof          bool
}

fn interpolate_var(m Mog, var string) string {
	mut i := Interpolator{
		mog:          m
		line:         var
		pos:          0
		current_char: var[0].ascii_str()
		is_var:       true
	}
	mut result := []string{}
	for !i.eof {
		word := i.get_next_word()
		result << word
	}
	return result.join(' ')
}

fn interpolate(m Mog, task_name string) string {
	task := m.get_task(task_name) or {
		eprint("No task named '${task_name}' found")
		exit(1)
	}
	mut lines := []string{}
	for line in task.body {
		mut i := Interpolator{
			mog:          m
			line:         line
			pos:          0
			current_char: line[0].ascii_str()
		}
		mut result := []string{}
		for !i.eof {
			word := i.get_next_word()
			result << word
		}
		lines << result.join(' ')
	}
	return lines.join('\n')
}

fn (mut i Interpolator) end_of_file() {
	i.current_char = ''
	i.eof = true
}

fn (mut i Interpolator) next_char() {
	if i.pos < i.line.len - 1 {
		i.pos += 1
		i.current_char = i.line[i.pos].ascii_str()
	} else {
		i.end_of_file()
	}
}

fn (mut i Interpolator) eat_rest_of_line() string {
	line := i.line[i.pos..]
	for _ in line {
		i.next_char()
	}
	i.end_of_file()
	return line
}

fn (mut i Interpolator) eat_replacement() string {
	i.next_char()
	if i.current_char == mog_var_char {
		return i.eat_arg()
	}
	word := i.eat_till_char([close_replacement])
	mut result := ''
	if word.contains(import_namespace_delimiter)
		&& word.split(import_namespace_delimiter).first() in i.mog.imports.keys() {
		word_parts := word.split(import_namespace_delimiter)
		mut import_m := i.mog.imports[word_parts.first()]
		if word_parts.last() in import_m.vars {
			result = import_m.vars[word_parts.last()]
		} else if word_parts.last() in import_m.tasks {
			if i.current_char != '\n' {
				args := i.eat_args()
				if args.len > 0 {
					import_m.args = args
				} else {
					import_m.args = i.mog.args
				}
				result = 'cd ${import_m.path}\n'
				result += interpolate(import_m, word_parts.last())
				result += '\ncd - > /dev/null 2>&1\n'
			}
		}
	} else {
		if word in i.mog.vars {
			result = i.mog.vars[word]
		} else {
			args := i.eat_args()
			old_args := i.mog.args
			if args.len > 0 {
				i.mog.args = args
			}
			result = interpolate(i.mog, word)
			i.mog.args = old_args
		}
	}
	return result
}

fn (mut i Interpolator) eat_eval() string {
	i.next_char()
	eval := i.eat_till_char([close_eval])
	return os.execute("${i.mog.shell_path} -c '${eval}'").output.trim_space()
}

fn (mut i Interpolator) eat_arg() string {
	word := i.eat_till_char([close_replacement])
	return replace_mog_arg(word, i.mog.args)
}

fn (mut i Interpolator) eat_args() []string {
	mut args := []string{}
	for i.current_char != '\n' && !i.eof {
		if i.current_char == '"' || i.current_char == "'" {
			args << i.eat_string()
		} else if i.current_char == ' ' {
			i.next_char()
		} else {
			args << i.eat_till_char(['\n', ' ', '"', "'"])
		}
	}
	return args
}

fn (mut i Interpolator) eat_string() string {
	mut quote := "'"
	if i.current_char == '"' {
		quote = '"'
	}
	i.next_char()
	return i.eat_till_char([quote])
}

fn (mut i Interpolator) eat_till_char(characters []string) string {
	mut word := ''
	for i.current_char !in characters && i.current_char != '' && i.current_char != '\n' && !i.eof {
		word += i.current_char
		i.next_char()
	}
	if i.current_char == '\n' && !i.eof {
		i.end_of_file()
	}
	i.next_char()
	return word
}

fn (mut i Interpolator) eat_word() string {
	return i.eat_till_char([' '])
}

fn (mut i Interpolator) get_next_word() string {
	if i.current_char == escape {
		i.next_char()
	}

	if i.current_char == '' || i.current_char == '\n' {
		i.end_of_file()
		return ''
	}

	if i.current_char == ' ' {
		i.next_char()
		return ' '
	}

	if i.current_char == open_replacement {
		return i.eat_replacement()
	}

	if i.current_char == open_eval {
		if i.is_var {
			return i.eat_eval()
		}
	}

	word := i.eat_word()
	if word != '' {
		return word
	}
	i.next_char()
	return ''
}
