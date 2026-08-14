module mog

import os

const open_replacement = '{'
const close_replacement = '}'
const open_eval = '['
const close_eval = ']'
const open_logic_group = '('
const close_logic_group = ')'
const control_flow_delimeter = '@'
const if_statement = '${control_flow_delimeter}if'
const elif_statement = '${control_flow_delimeter}elif'
const else_statement = '${control_flow_delimeter}else'
const close_if_statement = '${control_flow_delimeter}fi'
const bin_operators = ['==', '!=', '<', '<=', '>', '>=', 'in']
const unary_operators = ['file_exists', 'dir_exists', 'empty', 'not_empty']
const logical_operators = ['and', 'or', 'not']
const escape = '\\'
const mog_var_char = '$'
const import_namespace_delimiter = '.'
const quotes = ["'", '"']
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

@[if debug_interpolator ?]
fn interpolator_debug(on bool, i Interpolator, s ...string) {
	if on {
		println('DEBUG: char(${i.current_char}) POS (${i.pos}) | ${s}'.replace('\n', '\\n'))
	}
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

fn remove_surrounding_quotes(input string) string {
	mut a := input
	if a.starts_with('"') {
		a = a[1..]
		if a.ends_with('"') {
			a = a#[..-1]
		}
	} else if a.starts_with("'") {
		a = a[1..]
		if a.ends_with("'") {
			a = a#[..-1]
		}
	}
	return a
}

struct Interpolator {
mut:
	mog            Mog
	task_name      string
	line           string
	pos            int
	current_char   string
	dollar_seen    bool
	dollar_replace bool
	is_var         bool
	eof            bool
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
		result << i.eat()
	}
	interpolator_debug(false, i, result.join(''), '988')
	return result.join('')
}

fn interpolate(m Mog, task_name string) string {
	task := m.get_task(task_name) or {
		eprint("No task named '${task_name}' found\n")
		exit(1)
	}
	body := task.body.join('\n')
	mut parts := []string{}
	mut i := Interpolator{
		mog:          m
		task_name:    task_name
		line:         body
		pos:          0
		current_char: body[0].ascii_str()
	}
	for !i.eof {
		parts << i.eat()
	}
	return parts.join('')
}

fn (i Interpolator) get_shell() Shell {
	return i.mog.get_shell_from_task(i.task_name)
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
	if i.pos > 0 {
		i.dollar_seen = i.line[i.pos - 1].ascii_str() == '$'
	}
}

fn (mut i Interpolator) peek(options PeekOptions) string {
	mut peek_pos := i.pos + options.num
	if options.skip_whitespace {
		for peek_pos < i.line.len - 1 && i.line[peek_pos].ascii_str() == ' '
			&& i.line[peek_pos].ascii_str() != '\n' {
			peek_pos += 1
		}
		return i.line[peek_pos].ascii_str()
	}
	if peek_pos > i.line.len - 1 {
		return ''
	}
	return i.line[peek_pos].ascii_str()
}

fn (mut i Interpolator) peek_till(characters ...string) string {
	mut peek_pos := i.pos
	mut word := ''
	for i.line[peek_pos].ascii_str() !in characters && peek_pos < i.line.len - 1 {
		word += i.line[peek_pos].ascii_str()
		peek_pos += 1
	}
	return word
}

fn (mut i Interpolator) eat_replacement() string {
	if !i.get_shell().supports_mog_replacement {
		return '${i.eat_till(close_replacement)}}'
	}
	i.next_char()
	if i.current_char == mog_var_char {
		return i.eat_arg()
	}
	word := i.eat_till(close_replacement)
	i.next_char()
	mut result := ''
	if word.contains(import_namespace_delimiter)
		&& word.split(import_namespace_delimiter).first() in i.mog.imports.keys() {
		word_parts := word.split(import_namespace_delimiter)
		mut import_m := i.mog.imports[word_parts.first()]

		if word_parts.last() in import_m.vars {
			result = import_m.vars[word_parts.last()]
		} else if word_parts.last() in import_m.tasks {
			mut args := []string{}
			if i.current_char != '\n' {
				args = i.eat_args()
			}

			if args.len > 0 {
				import_m.args = args
			} else {
				import_m.args = i.mog.args
			}

			config := i.mog.get_config_from_task(i.task_name)
			no_cd := config.no_cd && !config.shell.supports_cd

			if !no_cd {
				result = 'cd ${import_m.path}\n'
			}

			result += interpolate(import_m, word_parts.last())

			if !no_cd {
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
	interpolator_debug(false, i, '2')
	eval := i.eat_till(close_eval)
	i.next_char()
	interpolator_debug(false, i, 'eval=${eval}', '3')
	shell := i.get_shell()
	return shell.eval(eval)
}

fn (mut i Interpolator) eat_arg() string {
	mut word := i.eat_till(close_replacement)
	i.next_char()
	return replace_mog_arg(word, i.mog.args)
}

fn (mut i Interpolator) eat_args() []string {
	mut args := []string{}
	for i.current_char != '\n' && !i.eof {
		if i.current_char in quotes {
			args << i.eat_string()
		} else if i.current_char != ' ' {
			args << i.eat_and_replace_till('\n', ' ', '"', "'")
			continue
		}
		i.next_char()
	}
	return args
}

fn (mut i Interpolator) eat_string() string {
	mut quote := "'"
	mut word := ''
	escape_single_quote := "'\\'"

	if i.current_char == '"' {
		quote = '"'
	}

	i.next_char()

	for i.current_char != quote && i.current_char != '' && i.current_char != '\n' && !i.eof {
		if i.current_char == "'" {
			word += escape_single_quote
		}

		if i.current_char == escape {
			if i.peek() in quotes {
				word += i.leave_escape()
			} else {
				word += i.eat_escape()
			}
			continue
		}

		if i.current_char == open_replacement && !i.dollar_seen {
			word += i.eat_replacement()
			continue
		}

		word += i.current_char
		i.next_char()
	}

	if quote == "'" {
		word = "${escape_single_quote}'${word}${escape_single_quote}'"
	} else {
		word = '${quote}${word}${quote}'
	}

	if i.current_char == quote {
		i.next_char()
	}

	return word
}

fn (mut i Interpolator) eat_till(end_words ...string) string {
	mut words := ['']
	interpolator_debug(false, i, 'end_words=(${end_words})', '431')
	for i.current_char !in end_words && i.current_char != '' && !i.eof {
		interpolator_debug(false, i, 'WORD=(${words.last()})', '432')
		mut found_word := false
		for end_word in end_words {
			if words.last().contains(end_word) {
				interpolator_debug(false, i, 'word contains end word', '433')
				found_word = true
				break
			}
		}
		if found_word {
			break
		}
		if i.current_char in quotes {
			mut last_word := words.pop()
			last_word += i.eat_string()
			words << last_word
			words << ''
			interpolator_debug(false, i, 'WORD=(${last_word})', '434')
			continue
		}
		mut last_word := words.pop()
		last_word += i.current_char
		words << last_word
		i.next_char()
		interpolator_debug(false, i, 'WORD=(${words.last()})', '435')
	}
	interpolator_debug(false, i, 'WORDS=(${words.join('')})', '436')
	return words.join('')
}

fn (mut i Interpolator) eat_and_replace_till(end_words ...string) string {
	mut word := ''
	interpolator_debug(false, i, 'end_words=${end_words}', '41')
	for i.current_char !in end_words && i.current_char != '' && !i.eof {
		mut found_word := false
		interpolator_debug(false, i, '${end_words}', '42')
		for end_word in end_words {
			if word.contains(end_word) {
				found_word = true
				end_word_len := end_word.len
				word = word.substr(0, word.len - end_word_len)
				i.pos = (i.pos - end_word_len) - 1
				if i.eof {
					i.eof = false
				}
				interpolator_debug(false, i, 'end_word=${end_word}', 'word=${word}', '43')
				i.next_char()
				break
			}
			interpolator_debug(false, i, 'end_words=${end_words}', 'word=${word}', '53')
		}
		if found_word {
			break
		}

		if word == if_statement {
			interpolator_debug(false, i, 'found if statement', '44')
			word = i.eat_if_blocks()
			interpolator_debug(false, i, word, '45')
		}

		if i.current_char in quotes {
			word += i.eat_string()
			interpolator_debug(false, i, 'word=${word}', '50')
			continue
		}

		if i.current_char == escape {
			if i.peek() in quotes {
				word += i.leave_escape()
				interpolator_debug(false, i, 'word=${word}', '51')
			} else {
				word += i.eat_escape()
				interpolator_debug(false, i, 'word=${word}', '52')
			}
			continue
		}

		if i.current_char == '$' {
			if i.peek() == '(' {
				word += i.eat_till(')')
				word += ')'
				i.next_char()
				interpolator_debug(false, i, 'word=${word}', '49')
			}
		}

		if i.current_char == open_replacement && !i.dollar_seen {
			word += i.eat_replacement()
			interpolator_debug(false, i, 'word=${word}', '48')
			continue
		}

		word += i.current_char
		interpolator_debug(false, i, 'word=${word}', '47')
		i.next_char()
	}
	for end_word in end_words {
		if word.contains(end_word) {
			end_word_len := end_word.len
			word = word.substr(0, word.len - end_word_len)
			i.pos = (i.pos - end_word_len) - 1
			if i.eof {
				i.eof = false
			}
			interpolator_debug(false, i, 'end_word=${end_word}', 'word=${word}', '55')
			i.next_char()
			i.next_char()
			break
		}
		interpolator_debug(false, i, 'end_words=${end_words}', 'word=${word}', '54')
	}
	interpolator_debug(false, i, 'word=${word}', '46')
	return word
}

fn (mut i Interpolator) eat_word() string {
	mut chars := [open_replacement, escape, control_flow_delimeter]
	if i.is_var {
		chars << open_eval
	}
	return i.eat_till(...chars)
}

fn (mut i Interpolator) eat_newline() string {
	i.next_char()
	return '\n'
}

fn (mut i Interpolator) eat_escape() string {
	i.next_char()
	ch := i.current_char
	i.next_char()
	interpolator_debug(false, i, 'ch=${ch}', '836')
	if ch == '\n' {
		return ''
	}
	if ch == 't' {
		return '\t'
	}
	return ch
}

fn (mut i Interpolator) leave_escape() string {
	mut ch := i.current_char
	i.next_char()
	ch += i.current_char
	i.next_char()
	return ch
}

fn (mut i Interpolator) eat_control_flow() string {
	mut lines := ''
	keyword := i.eat_till(' ')
	i.next_char()
	if keyword == if_statement {
		lines = i.eat_if_blocks()
	}
	i.next_char()
	return lines
}

interface Operation {
	block string
	evaluate() bool
}

enum UnaryOperator {
	file_exists
	dir_exists
	empty
	not_empty
}

struct UnaryOperation {
	operator UnaryOperator
	value    string
	block    string
}

fn (u UnaryOperation) evaluate() bool {
	match u.operator {
		.file_exists {
			return os.is_file(u.value)
		}
		.dir_exists {
			return os.is_dir(u.value)
		}
		.empty {
			if os.is_file(u.value) {
				return os.system('test -s ${u.value}') != 0
			} else if os.is_dir(u.value) {
				return os.is_dir_empty(u.value)
			} else {
				eprint("Syntax error. Path not recognised: '${u.value}'\n")
				exit(2)
			}
		}
		.not_empty {
			if os.is_file(u.value) {
				return os.system('test -s ${u.value}') == 0
			} else if os.is_dir(u.value) {
				return !os.is_dir_empty(u.value)
			} else {
				eprint("Syntax error. Path not recognised: '${u.value}'\n")
				exit(2)
			}
		}
	}
}

enum LogicalOperator {
	and
	or
	not
}

struct LogicalOperation {
	left     bool
	right    bool
	operator LogicalOperator = .and
	block    string
}

fn (l LogicalOperation) evaluate() bool {
	match l.operator {
		.and {
			return l.left && l.right
		}
		.or {
			return l.left || l.right
		}
		.not {
			return !l.left
		}
	}
}

enum BinaryOperator {
	eq
	neq
	lt
	lte
	gt
	gte
	in
}

struct BinaryOperation {
	left     string
	right    string
	operator BinaryOperator = .eq
	block    string
}

fn (b BinaryOperation) evaluate() bool {
	match b.operator {
		.eq {
			if b.left.is_int() && b.right.is_int() {
				return b.left.int() == b.right.int()
			}
			return remove_surrounding_quotes(b.left) == remove_surrounding_quotes(b.right)
		}
		.neq {
			if b.left.is_int() && b.right.is_int() {
				return b.left.int() != b.right.int()
			}
			return remove_surrounding_quotes(b.left) != remove_surrounding_quotes(b.right)
		}
		.lt {
			if b.left.is_int() && b.right.is_int() {
				return b.left.int() < b.right.int()
			} else if b.left.is_int() && !b.right.is_int() {
				eprint("Syntax error. Type mismatch '${b.left}' and '${b.right}'\n")
				exit(2)
			} else if !b.left.is_int() && b.right.is_int() {
				eprint("Syntax error. Type mismatch '${b.left}' and '${b.right}'\n")
				exit(2)
			}
			return remove_surrounding_quotes(b.left) < remove_surrounding_quotes(b.right)
		}
		.lte {
			if b.left.is_int() && b.right.is_int() {
				return b.left.int() <= b.right.int()
			} else if b.left.is_int() && !b.right.is_int() {
				eprint("Syntax error. Type mismatch '${b.left}' and '${b.right}'\n")
				exit(2)
			} else if !b.left.is_int() && b.right.is_int() {
				eprint("Syntax error. Type mismatch '${b.left}' and '${b.right}'\n")
				exit(2)
			}
			return remove_surrounding_quotes(b.left) <= remove_surrounding_quotes(b.right)
		}
		.gt {
			if b.left.is_int() && b.right.is_int() {
				return b.left.int() > b.right.int()
			} else if b.left.is_int() && !b.right.is_int() {
				eprint("Syntax error. Type mismatch '${b.left}' and '${b.right}'\n")
				exit(2)
			} else if !b.left.is_int() && b.right.is_int() {
				eprint("Syntax error. Type mismatch '${b.left}' and '${b.right}'\n")
				exit(2)
			}
			return remove_surrounding_quotes(b.left) > remove_surrounding_quotes(b.right)
		}
		.gte {
			if b.left.is_int() && b.right.is_int() {
				return b.left.int() >= b.right.int()
			} else if b.left.is_int() && !b.right.is_int() {
				eprint("Syntax error. Type mismatch '${b.left}' and '${b.right}'\n")
				exit(2)
			} else if !b.left.is_int() && b.right.is_int() {
				eprint("Syntax error. Type mismatch '${b.left}' and '${b.right}'\n")
				exit(2)
			}
			return remove_surrounding_quotes(b.left) >= remove_surrounding_quotes(b.right)
		}
		.in {
			return remove_surrounding_quotes(b.left) in b.right.replace_once('[', '').reverse().replace_once(']',
				'').reverse().split(',').map(it.trim_space()).map(remove_surrounding_quotes(it)).map(it.trim_space())
		}
	}
}

fn (mut i Interpolator) eat_if_condition() Operation {
	i.skip_whitespace()
	mut a := i.eat_and_replace_till('=', ' ').trim_space()
	if a.starts_with('$') {
		interpolator_debug(false, i, 'A ${a}', '522')
		a = i.get_shell().execute(a)
	}
	interpolator_debug(false, i, 'A ${a}', '523')
	i.skip_whitespace()
	if a in unary_operators {
		return i.eat_un_op(a)
	}
	return i.eat_bin_op(a)
}

fn (mut i Interpolator) eat_bin_op(a string) BinaryOperation {
	op := i.eat_bin_op_char()
	i.next_char()
	mut b := i.eat_and_replace_till('\n').trim_space()
	if b.starts_with('$') {
		b = i.get_shell().execute(b)
	}
	interpolator_debug(false, i, "B '${b}'", '524')
	// next_word := i.peek_till('a', 'o')
	// interpolator_debug(false, i, "next_word '${next_word}'", '526')
	if i.current_char != '\n' {
		interpolator_debug(false, i, a, b, '${op}', '525')
		eprint('Syntax error. Expected newline\n')
		exit(2)
	}
	if i.current_char == '\n' {
		i.next_char()
	}
	interpolator_debug(false, i, '111')
	return BinaryOperation{a, b, op, i.eat_and_replace_till(elif_statement, else_statement,
		close_if_statement)}
}

fn (mut i Interpolator) eat_bin_op_char() BinaryOperator {
	op := i.eat_till(' ').trim_space()
	if op == '==' {
		return .eq
	}
	if op == '!=' {
		return .neq
	}
	if op == '>' {
		return .gt
	}
	if op == '>=' {
		return .gte
	}
	if op == '<' {
		return .lt
	}
	if op == '<=' {
		return .lte
	}
	if op == 'in' {
		return .in
	}
	return .eq
}

fn (mut i Interpolator) eat_un_op(op_str string) UnaryOperation {
	op := str_to_un_op(op_str)
	i.skip_whitespace()
	b := i.eat_and_replace_till('\n').trim_space()
	if i.current_char != '\n' {
		eprint('Syntax error. Expected newline\n')
		exit(2)
	}
	if i.current_char == '\n' {
		i.next_char()
	}
	interpolator_debug(false, i, '112')
	return UnaryOperation{op, b, i.eat_and_replace_till(elif_statement, else_statement,
		close_if_statement)}
}

fn str_to_un_op(op string) UnaryOperator {
	if op == 'file_exists' {
		return .file_exists
	}
	if op == 'dir_exists' {
		return .dir_exists
	}
	if op == 'empty' {
		return .empty
	}
	if op == 'not_empty' {
		return .not_empty
	}
	return .not_empty
}

fn (mut i Interpolator) eat_fi() {
	fi_keyword := i.eat_till('\n').trim_space()
	interpolator_debug(false, i, fi_keyword, '741')
	if fi_keyword != close_if_statement {
		eprint("Syntax error. Missing closing of if statement with '${close_if_statement}'\n")
		exit(2)
	}
}

fn (mut i Interpolator) eat_if_blocks() string {
	interpolator_debug(false, i, '211')
	if_comparison := i.eat_if_condition()
	interpolator_debug(false, i, '${if_comparison}', '212')

	mut elif_comparisons := []Operation{}
	mut else_block := ''
	interpolator_debug(false, i, '645')
	mut else_keyword := i.eat_till(' ', '\n').trim_space()
	interpolator_debug(false, i, else_keyword, '644')

	i.next_char()
	for else_keyword == elif_statement {
		elif_comparisons << i.eat_if_condition()
		interpolator_debug(false, i, 'eof=${i.eof}', '${i.line[i.pos..]}', '646')
		else_keyword = i.eat_till(' ', '\n').trim_space()
		interpolator_debug(false, i, '${elif_comparisons.last()}', '${else_keyword}', '647')
	}

	if else_keyword == else_statement {
		else_block = i.eat_and_replace_till(close_if_statement)
		interpolator_debug(false, i, else_keyword, else_block, '642')
		i.eat_fi()
	} else if else_keyword != close_if_statement {
		interpolator_debug(false, i, else_keyword, else_block, '643')
		else_block = '${else_keyword} '
		i.eat_fi()
	}

	if if_comparison.evaluate() {
		return if_comparison.block
	}

	for comp in elif_comparisons {
		if comp.evaluate() {
			return comp.block
		}
	}

	return else_block
}

fn (mut i Interpolator) skip_whitespace() {
	for i.current_char == ' ' {
		i.next_char()
	}
}

fn (mut i Interpolator) eat() string {
	if i.current_char == escape {
		return i.eat_escape()
	}

	if i.current_char == '' {
		i.end_of_file()
		return ''
	}

	if i.current_char == '\n' {
		return i.eat_newline()
	}

	if i.dollar_replace {
		mut word := '{'
		word += i.eat_till(close_replacement)
		i.next_char()
		word += '}'
		i.dollar_replace = false
		return word
	}

	if i.current_char == control_flow_delimeter && i.get_shell().supports_mog_conditionals {
		return i.eat_control_flow()
	}

	if i.current_char == open_replacement && !i.dollar_seen {
		return i.eat_replacement()
	}
	if i.dollar_seen {
		i.dollar_replace = true
	}

	if i.current_char == open_eval && i.is_var {
		interpolator_debug(false, i, '876')
		return i.eat_eval()
	}

	word := i.eat_word()
	if word != '' {
		return word
	}
	i.next_char()
	return ''
}
