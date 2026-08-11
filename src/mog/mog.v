module mog

import os

pub const config_path = os.expand_tilde_to_home('~/.config/mog')
pub const config_file_path = '${config_path}/config'

@[if debug ?]
pub fn debug(s string) {
	println("DEBUG: '${s}'".replace('\n', '\\n'))
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
	vars    map[string]string
	imports map[string]Mog
	args    []string
	config  Config
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
		return task.config or { m.config }
	}
	return m.config
}

pub fn (m Mog) get_shell_from_task(task_name string) Shell {
	if task := m.get_task(task_name) {
		config := task.config or { m.config }
		return config.shell
	}
	return m.config.shell
}

pub fn (mut m Mog) execute_task(task_name string, verbose bool, prepend string, no_exit_code bool, mog_file_path string) {
	mut body := interpolate(m, task_name)
	mut source := ''
	config := m.get_config_from_task(task_name)

	for env_file in config.env_files {
		read_env_file('${mog_file_path}/${env_file}')
	}

	mut relax_flags := 'set +euo pipefail\n'
	option_flags := add_option_flags(config)

	if config.source_file.len > 0 {
		source = '. ${config.source_file}\n'
	}
	if source.len == 0 || option_flags.len == 0 {
		relax_flags = ''
	}

	if config.no_cd {
		body = '${relax_flags}${source}${option_flags}\n${body}'
	} else {
		body = '${prepend}${relax_flags}${source}${option_flags}\n${body}'
	}

	if !config.new_shell_per_line {
		body = "${config.shell.path} ${config.shell.interpreting_flag} '${body}'"
	}

	if verbose {
		println('${config.to_str()}\n')
		println('Executing the following commands:\n')
		println(body)
		println('${built_in_vars['\$normal']}\n---\n')
	}

	mut exit_code := 0
	if config.new_shell_per_line {
		for line in body.split_into_lines() {
			exit_code =
				os.system("${config.shell.path} ${config.shell.interpreting_flag} '${line}'")
			if config.exit_on_error && exit_code != 0 {
				break
			}
		}
	} else {
		exit_code = os.system(body)
	}

	if !config.hide_exit_code_output && !no_exit_code {
		println('${built_in_vars['\$normal']}\nExit Code: ${exit_code}')
	}

	exit(exit_code)
}

fn add_option_flags(config Config) string {
	mut result := ''
	if config.exit_on_error {
		result += config.shell.exit_on_error_flag
	}
	if config.error_on_undefined_vars {
		result += config.shell.error_on_undefined_vars_flag
	}
	if config.print_commands {
		result += config.shell.print_commands_flag
	}
	if config.exit_on_pipe_failures {
		result += config.shell.exit_on_pipe_failures_flag
	}
	if result.len > 0 {
		return 'set -${result}'
	} else {
		return ''
	}
}
