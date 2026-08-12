module mog

import os

pub const config_path = os.expand_tilde_to_home('~/.config/mog')
pub const config_file_path = '${config_path}/config'

@[params]
pub struct DebugOptions {
pub:
	s                string
	replace_newlines bool = true
}

@[if debug ? || debug_parser ? || debug_lexer ? || debug_interpolator ?]
pub fn debug(o DebugOptions) {
	if o.replace_newlines {
		println("DEBUG: '${o.s}'".replace('\n', '\\n'))
	} else {
		println("DEBUG: '${o.s}'")
	}
}

pub struct Task {
pub mut:
	desc   string
	config ?Config
	body   []string
}

pub struct Mog {
pub:
	tasks map[string]Task
	path  string
pub mut:
	vars           map[string]string
	imports        map[string]Mog
	args           []string
	config         Config
	shell_override ?Shell
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

pub fn (m Mog) get_config_from_task(task_name string) Config {
	if task := m.get_task(task_name) {
		mut config := task.config or { m.config }
		if shell := m.shell_override {
			config.shell = shell
		}
		return config
	}
	return m.config
}

pub fn (m Mog) get_shell_from_task(task_name string) Shell {
	if shell := m.shell_override {
		return shell
	}
	if task := m.get_task(task_name) {
		config := task.config or { m.config }
		return config.shell
	}
	return m.config.shell
}

pub fn (mut m Mog) execute_task(task_name string, verbose bool) {
	body := interpolate(m, task_name)
	config := m.get_config_from_task(task_name)

	for env_file in config.env_files {
		read_env_file(m.path, env_file)
	}

	exit_code := config.shell.run(body, config, verbose, m.path)

	if !config.hide_exit_code_output {
		println('${built_in_vars['\$normal']}\nExit Code: ${exit_code}')
	}

	exit(exit_code)
}
