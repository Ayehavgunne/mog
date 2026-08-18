module mog

import os

const original_dir = os.getwd()

@[if debug_parser ?]
fn parser_debug(on bool, p Parser, s string) {
	if on {
		println('DEBUG: token(${p.current_token}) | (${s})'.replace('\n', '\\n'))
	}
}

enum ParserContext {
	root
	task_block
	decorator_block
	import_block
	options_block
	var_declaration
}

struct Parser {
	tokens []Token
mut:
	pos           int
	import_paths  map[string]string
	vars          map[string]string
	tasks         map[string]Task
	current_task  Task
	config        Config
	current_token Token
	eof           bool
}

pub fn parse(file string, args []string, mog_file_path string, config Config) !Mog {
	tokens := lex(file)!
	mut p := Parser{
		tokens:        tokens
		current_token: tokens[0]
		config:        config
	}
	for !p.eof {
		p.process_next_token()!
	}
	mut m := Mog{
		vars:    p.vars
		tasks:   p.tasks
		path:    mog_file_path
		imports: do_import(p.import_paths, args, mog_file_path, config)
		args:    args
		config:  config
	}
	for key, var in m.vars {
		m.vars[key] = interpolate_var(m, var)
	}
	os.chdir(original_dir) or { debug(s: 'failed to get back to original dir') }
	return m
}

fn do_import(import_paths map[string]string, args []string, mog_file_path string, config Config) map[string]Mog {
	mut imported_mogs := map[string]Mog{}
	if import_paths.len > 0 {
		for alias, path in import_paths {
			new_path := os.abs_path(mog_file_path + '/' + path)
			if !os.exists(new_path) {
				eprint('Path not found: ${new_path}\n')
				exit(1)
			}
			os.chdir(new_path) or { debug(s: 'Failed to change cwd') }
			contents := os.read_file('.mog') or {
				eprint('Failed to read import: ${new_path}/.mog\n')
				exit(1)
			}
			imported_mogs[alias] = parse(contents, args, new_path, config) or {
				eprint('Failed to parse import: ${new_path}/.mog ${err}\n')
				exit(1)
			}
		}
	}
	return imported_mogs
}

fn (mut p Parser) move() {
	p.pos += 1
	if p.pos > p.tokens.len - 1 {
		p.eof = true
		return
	}
	p.current_token = p.tokens[p.pos]
}

fn (mut p Parser) peek(options PeekOptions) ?Token {
	mut peek_pos := p.pos + options.num
	if peek_pos > p.tokens.len - 1 {
		return none
	}
	return p.tokens[peek_pos]
}

fn (mut p Parser) eat_var() ! {
	val := p.current_token.value
	p.move()
	if p.current_token.token_type != .value {
		return error('Missing variable value')
	}
	p.vars[val] = p.current_token.value
}

fn (mut p Parser) eat_decorator() ! {
	decorator_name := p.current_token.value
	mut values := []string{}
	p.move()
	for p.current_token.token_type != .end_block {
		if p.current_token.value.trim_space().len > 0 {
			values << p.current_token.value.trim_space()
		}
		p.move()
		if p.current_token.token_type == .new_line {
			p.move()
		}
	}
	match decorator_name {
		'desc' {
			p.current_task.desc = values.join(' ')
		}
		'options' {
			p.current_task.config = parse_config(
				contents: values.join('\n')
				config:   p.config
			) or { return error('Failed to parse file level options') }
		}
		else {
			return error("Unrecognized decorator type '${decorator_name}'")
		}
	}
}

fn (mut p Parser) eat_task() ! {
	task_name := p.current_token.value
	p.move()
	mut body := ''
	mut preserv_indentation := false
	if config := p.current_task.config {
		preserv_indentation = config.shell.preserv_indentation
	}
	for p.current_token.token_type in [.task_body, .indent] {
		if p.eof {
			break
		}
		if preserv_indentation && p.current_token.token_type == .indent {
			body += p.current_token.value
		} else if p.current_token.token_type == .task_body {
			body += p.current_token.value
		}
		p.move()
		if p.current_token.token_type == .new_line {
			p.current_task.body << body
			body = ''
			p.move()
		}
	}
	p.current_task.body << body
	p.current_task.config = p.current_task.config or { p.config }

	p.tasks[task_name] = p.current_task
	p.current_task = Task{}
	if p.current_token.token_type != .task_body {
		return
	}
}

fn (mut p Parser) eat_import() ! {
	err_msg := 'Incorrect import syntax'
	p.move()
	for p.current_token.token_type != .end_block {
		mut count_down := 3
		mut path := ''
		mut alias := ''
		for p.current_token.token_type != .new_line {
			if count_down < 1 {
				return error(err_msg)
			}
			if count_down == 3 {
				path = p.current_token.value
				alias = path.split('/').last()
			}
			if count_down == 2 {
				if p.current_token.value != 'as' {
					return error(err_msg)
				}
			}
			if count_down == 1 {
				alias = p.current_token.value
			}
			p.move()
			count_down -= 1
		}
		if alias.contains(' ') {
			return error('Import name cannot contain a space')
		}
		p.import_paths[alias] = path
		p.move()
	}
}

fn (mut p Parser) eat_file_options() ! {
	p.move()
	mut values := []string{}
	for p.current_token.token_type != .end_block {
		if p.current_token.value.trim_space().len > 0 {
			values << p.current_token.value.trim_space()
		}
		p.move()
		if p.current_token.token_type == .new_line {
			p.move()
		}
	}
	p.config = parse_config(
		contents: values.join('\n')
		config:   p.config
	) or { return error('Failed to parse file level options') }
}

fn (mut p Parser) eat_keyword() ! {
	if p.current_token.value == mog_import {
		p.eat_import()!
	}
	if p.current_token.value == file_level_options {
		p.eat_file_options()!
	}
}

fn (mut p Parser) process_next_token() ! {
	if p.current_token.token_type == .var {
		p.eat_var()!
	}

	if p.current_token.token_type == .decorator {
		p.eat_decorator()!
	}

	if p.current_token.token_type == .task_name {
		p.eat_task()!
	}

	if p.current_token.token_type == .keyword {
		p.eat_keyword()!
	}

	p.move()
}
