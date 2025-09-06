module mog

import os

const open_replacement = '{'
const close_replacement = '}'
const open_eval = '['
const close_eval = ']'
const escape = '\\'
const mog_var_char = '$'
const import_namespace_delimiter = '.'

pub struct Task {
pub mut:
	deps []string
	desc string
	body []string
	mog  Mog
}

pub struct Mog {
pub:
	tasks map[string]Task
	path  string
pub mut:
	vars    map[string]string
	imports map[string]Mog
	args    []string
}

fn get_deps(m Mog, deps []string, options InterpolateOptions) []string {
	mut new_deps := []string{}

	for dep in deps {
		mut this_mog := m
		mut dep_command := Task{}
		if dep.contains(import_namespace_delimiter)
			&& dep.split(import_namespace_delimiter).first() in m.imports.keys() {
			dep_parts := dep.split(import_namespace_delimiter)
			this_mog = m.imports[dep_parts.first()]
			dep_command = this_mog.tasks[dep_parts.last()]
		} else {
			dep_command = m.tasks[dep]
		}
		sub_deps := get_deps(this_mog, dep_command.deps)
		new_deps << sub_deps
		new_deps << 'cd ${this_mog.path}'
		new_deps << interpolate_task(m, mut dep_command, options)
		new_deps << 'cd - > /dev/null 2>&1'
	}

	return new_deps
}

fn interpolate_task(m Mog, mut task Task, options InterpolateOptions) string {
	mut new_body := []string{}

	for line in task.body {
		mut new_line := m.interpolate(InterpolateOptions{
			value: line
		})
		new_body << new_line.trim_space()
	}
	task.body = new_body
	task.mog = m
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
	if replacement == '\$clear' {
		return '\ec'
	}
	if replacement == '\$normal' {
		return '\e[0m'
	}
	if replacement == '\$bold' {
		return '\e[1m'
	}
	if replacement == '\$dim' {
		return '\e[2m'
	}
	if replacement == '\$italic' {
		return '\e[3m'
	}
	if replacement == '\$underline' {
		return '\e[4m'
	}
	if replacement == '\$invert' {
		return '\e[7m'
	}
	if replacement == '\$strikethrough' {
		return '\e[9m'
	}
	if replacement == '\$normal_intensity' {
		return '\e[22m'
	}
	if replacement == '\$black' {
		return '\e[30m'
	}
	if replacement == '\$red' {
		return '\e[31m'
	}
	if replacement == '\$green' {
		return '\e[32m'
	}
	if replacement == '\$yellow' {
		return '\e[33m'
	}
	if replacement == '\$blue' {
		return '\e[34m'
	}
	if replacement == '\$magenta' {
		return '\e[35m'
	}
	if replacement == '\$cyan' {
		return '\e[36m'
	}
	if replacement == '\$white' {
		return '\e[37m'
	}
	if replacement == '\$bg_black' {
		return '\e[40m'
	}
	if replacement == '\$bg_red' {
		return '\e[41m'
	}
	if replacement == '\$bg_green' {
		return '\e[42m'
	}
	if replacement == '\$bg_yellow' {
		return '\e[43m'
	}
	if replacement == '\$bg_blue' {
		return '\e[44m'
	}
	if replacement == '\$bg_magenta' {
		return '\e[45m'
	}
	if replacement == '\$bg_cyan' {
		return '\e[46m'
	}
	if replacement == '\$bg_white' {
		return '\e[47m'
	}
	return ''
}

@[params]
struct InterpolateOptions {
	value  string
	is_var bool
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
				new_value += replace_mog_var(replacement, m.args)
			} else if replacement.contains(import_namespace_delimiter)
				&& replacement.split(import_namespace_delimiter).first() in m.imports.keys() {
				replacement_parts := replacement.split(import_namespace_delimiter)
				import_m := m.imports[replacement_parts.first()]
				if replacement_parts.last() in import_m.vars {
					new_value += import_m.vars[replacement_parts.last()]
				} else if replacement_parts.last() in import_m.tasks {
					new_value += 'cd ${import_m.path}\n'
					new_value += import_m.tasks[replacement_parts.last()].body.join('\n')
					new_value += '\ncd - > /dev/null 2>&1\n'
					imported_deps := get_deps(import_m, import_m.tasks[replacement_parts.last()].deps,
						options)
					new_value += imported_deps.join('\n')
				}
			} else {
				if replacement in m.vars {
					new_value += m.vars[replacement]
				} else if replacement in m.tasks {
					new_value += m.tasks[replacement].body.join('\n')
				}
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
			new_value += os.execute(replacement).output.trim_space()
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

pub fn (m Mog) get_task(name string) ?Task {
	if name in m.tasks {
		return m.tasks[name]
	} else if name.contains(import_namespace_delimiter) {
		mut name_parts := name.split(import_namespace_delimiter)
		if name_parts.first() in m.imports {
			new_name := name_parts.first().clone()
			name_parts = name_parts[1..].clone()
			return m.imports[new_name].get_task(name_parts.join(import_namespace_delimiter))
		}
	}
	return none
}

pub fn (mut t Task) execute() {
	deps := get_deps(t.mog, t.deps)
	mut new_body := interpolate_task(t.mog, mut t)
	if deps.len > 0 {
		if new_body.len > 0 {
			new_body = '${deps.join('\n')}\n${new_body}'
		} else {
			new_body = deps.join('\n')
		}
	}
	debug('${t}')
	debug(new_body)
	exit_code := os.system(new_body)
	println('\nExit Code: ${exit_code}')
}
