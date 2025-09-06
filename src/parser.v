module mog

import os

const original_dir = os.getwd()

enum ParserContext {
	root
	command_block
	decorator_block
	import_block
	var_declaration
}

struct Parser {
	tokens []Token
mut:
	pos             int
	import_paths    map[string]string
	vars            map[string]string
	tasks           map[string]Task
	current_command Task
	current_token   Token
	context         ParserContext
	eof             bool
}

pub fn parse(file string, args []string) !Mog {
	tokens := lex(file)!
	mut p := Parser{
		tokens:        tokens
		current_token: tokens[0]
	}
	for !p.eof {
		p.process_next_token()!
	}
	mut m := Mog{
		vars:    p.vars
		tasks:   p.tasks
		path:    os.getwd()
		imports: do_import(p.import_paths, args)
		args:    args
	}
	mut new_vars := map[string]string{}
	for key, var in m.vars {
		new_vars[key] = m.interpolate(InterpolateOptions{
			value:  var
			is_var: true
		})
	}
	m.vars = new_vars.move()
	for _, mut task in m.tasks {
		interpolate_task(m, mut task)
	}
	os.chdir(original_dir) or { debug('failed to ge back to original dir') }
	return m
}

fn do_import(import_paths map[string]string, args []string) map[string]Mog {
	mut imported_mogs := map[string]Mog{}
	if import_paths.len > 0 {
		for alias, path in import_paths {
			new_path := os.abs_path(os.getwd() + '/' + path)
			if !os.exists(new_path) {
				println('Path not found: ${new_path}')
				exit(1)
			}
			os.chdir(new_path) or { debug('Failed to change cwd') }
			contents := os.read_file('.mog') or {
				println('Failed to read import: ${os.getwd()}/.mog')
				exit(1)
			}
			imported_mogs[alias] = parse(contents, args) or {
				println('Failed to parse import: ${os.getwd()}/.mog  ${err}')
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

fn (mut p Parser) process_next_token() ! {
	if p.current_token.token_type == .var {
		val := p.current_token.value
		p.move()
		if p.current_token.token_type != .value {
			return error('Missing variable value')
		}
		p.vars[val] = p.current_token.value
	}

	if p.current_token.token_type == .decorator {
		p.context = .decorator_block
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
		p.context = .root
		match decorator_name {
			'dep' {
				p.current_command.deps = values
			}
			'desc' {
				p.current_command.desc = values.join(' ')
			}
			else {
				return error('Unrecognized decorator type ${decorator_name}')
			}
		}
	}

	if p.current_token.token_type == .command_name {
		command_name := p.current_token.value
		p.move()
		for p.current_token.token_type == .command_body {
			if p.eof {
				break
			}
			p.current_command.body << p.current_token.value
			p.move()
			if p.current_token.token_type == .new_line {
				p.move()
			}
		}
		p.tasks[command_name] = p.current_command
		p.current_command = Task{}
		if p.current_token.token_type != .command_body {
			return
		}
	}

	if p.current_token.token_type == .keyword {
		if p.current_token.value == mog_import {
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
	}

	p.move()
}
