module mog

import os

const open_replacement = '{'
const close_replacement = '}'
const open_eval = '['
const close_eval = ']'
const escape = '\\'
const mog_var_char = '$'

pub struct Task {
pub mut:
	deps []string
	desc string
	body []string
}

struct Import {
	path        string
	identifiers []string
}

pub struct Mog {
pub:
	tasks   map[string]Task
	imports []Import
pub mut:
	vars map[string]string
}

fn (m Mog) get_deps(deps []string, options InterpolateOptions) []string {
	mut new_deps := []string{}

	for dep in deps {
		dep_command := m.tasks[dep]
		sub_deps := m.get_deps(dep_command.deps)
		new_deps << sub_deps
		new_deps << m.interpolate_command(dep_command, options)
	}

	return new_deps
}

fn (m Mog) interpolate_command(task Task, options InterpolateOptions) string {
	mut new_body := []string{}

	for line in task.body {
		mut new_line := m.interpolate(InterpolateOptions{ value: line, args: options.args })
		new_body << new_line.trim_space()
	}
	return new_body.join('\n')
}

fn replace_mog_var(replacement string, args []string) string {
	for index, arg in args {
		if replacement == '$${index + 1}' {
			return arg
		}
	}
	if replacement == '$#' {
		return '${args.len}'
	}
	if replacement in ['$@', '$*'] {
		return args.join(' ')
	}
	if replacement == '$"@"' {
		return '"${args.join('" "')}"'
	}
	if replacement == '$"*"' {
		return '"${args.join(' ')}"'
	}
	return ''
}

@[params]
struct InterpolateOptions {
	value  string
	is_var bool
	args   []string
}

fn (m Mog) interpolate(options InterpolateOptions) string {
	mut replacement := ''
	mut in_replacement := false
	mut in_eval := false
	mut is_escape := false
	mut new_value := ''
	mut saw_dollarsign := false

	for character in options.value {
		if character.ascii_str() == escape && !is_escape {
			is_escape = true
			continue
		}
		if is_escape && character.ascii_str() == escape {
			is_escape = false
		}
		if character.ascii_str() == '$' && !in_replacement {
			saw_dollarsign = true
		}
		if character.ascii_str() == open_replacement && !saw_dollarsign && !is_escape {
			in_replacement = true
			continue
		}
		if character.ascii_str() == close_replacement && in_replacement {
			in_replacement = false
			if replacement.starts_with(mog_var_char) {
				new_value += replace_mog_var(replacement, options.args)
			} else {
				new_value += m.vars[replacement]
			}
			replacement = ''
			saw_dollarsign = false
			continue
		}
		if options.is_var && character.ascii_str() == open_eval && !in_eval && !is_escape {
			in_eval = true
			continue
		}
		if options.is_var && character.ascii_str() == close_eval && in_eval {
			in_eval = false
			new_value += os.execute(replacement).output
			replacement = ''
			saw_dollarsign = false
			continue
		}
		if in_replacement || in_eval {
			replacement += character.ascii_str()
		} else {
			new_value += character.ascii_str()
		}
		if is_escape && character.ascii_str() != escape {
			is_escape = true
		}
	}
	return new_value
}

pub fn (mut m Mog) execute(task Task, args []string) {
	mut new_vars := map[string]string{}
	for key, var in m.vars {
		new_vars[key] = m.interpolate(InterpolateOptions{ value: var, is_var: true })
	}
	m.vars = new_vars.move()
	deps := m.get_deps(task.deps)
	mut new_body := m.interpolate_command(task, InterpolateOptions{ args: args })
	if deps.len > 0 {
		if new_body.len > 0 {
			new_body = '${deps.join('\n')}\n${new_body}'
		} else {
			new_body = deps.join('\n')
		}
	}
	debug('${task}')
	debug(new_body)
	exit_code := os.system(new_body)
	println('\nExit Code: ${exit_code}')
}
