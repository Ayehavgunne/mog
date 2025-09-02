module mog

import os

const open_replacement = '{'
const close_replacement = '}'

pub struct Command {
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
	commands map[string]Command
	imports  []Import
pub mut:
	vars map[string]string
}

fn (m Mog) get_deps(deps []string) []string {
	mut new_deps := []string{}

	for dep in deps {
		dep_command := m.commands[dep]
		sub_deps := m.get_deps(dep_command.deps)
		new_deps << sub_deps
		new_deps << m.interpolate_command(dep_command)
	}

	return new_deps
}

fn (m Mog) interpolate(value string) string {
	mut replacement := ''
	mut in_replacement := false
	mut new_value := ''
	mut saw_dollarsign := false

	for character in value {
		if character.ascii_str() == '$' {
			saw_dollarsign = true
		}
		if character.ascii_str() == open_replacement && !saw_dollarsign {
			in_replacement = true
			continue
		}
		if character.ascii_str() == close_replacement && in_replacement {
			in_replacement = false
			new_value += m.vars[replacement]
			replacement = ''
			saw_dollarsign = false
			continue
		}
		if in_replacement {
			replacement += character.ascii_str()
		} else {
			new_value += character.ascii_str()
		}
	}
	return new_value
}

fn (m Mog) interpolate_command(command Command) string {
	mut new_body := []string{}

	for line in command.body {
		mut new_line := m.interpolate(line)
		new_body << new_line
	}
	return new_body.join(' && ')
}

pub fn (mut m Mog) execute(command Command, args []string) os.Result {
	mut new_vars := map[string]string{}
	for key, var in m.vars {
		new_vars[key] = m.interpolate(var)
	}
	m.vars = new_vars.move()
	deps := m.get_deps(command.deps)
	mut new_body := m.interpolate_command(command)
	if deps.len > 0 {
		new_body = deps.join(' && ') + ' && ' + new_body
	}
	if args.len > 0 {
		new_body += ' '
		new_body += args.join(' ')
	}
	return os.execute(new_body)
}
