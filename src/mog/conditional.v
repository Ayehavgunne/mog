module mog

import os

struct Conditional {
	blocks    map[string]string
	task_name string
	mog       Mog
}

fn (c Conditional) evaluate() string {
	for check, block in c.blocks {
		if c.check(check) {
			return block
		}
	}
	return ''
}

fn (c Conditional) check(condition string) bool {
	mut words := []string{}
	mut results := []string{}
	mut word := ''
	mut in_str := false
	for character in condition {
		if character.ascii_str() == ' ' && !in_str {
			if word.len > 0 {
				words << word.trim_space()
			}
			word = ''
		}
		if !in_str && character.ascii_str() in ['"', "'"]{
			in_str = true
		}
		if in_str && character.ascii_str() in ['"', "'"] {
			in_str = false
		}
		word += character.ascii_str()
	}
	words << word.trim_space()
	for part in words {
		if part.starts_with(open_replacement) && part.ends_with(close_replacement) {
			results << replace_mog_arg(part#[1..-1], c.mog.args)
		} else {
			results << part
		}
	}
	print('WORDS ${results}')
	return false
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
