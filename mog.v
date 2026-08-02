module mog

import os

pub const config_path = os.expand_tilde_to_home('~/.config/mog')
pub const config_file_path = '${config_path}/config'

pub struct Config {
pub mut:
	shell_path              string = '/bin/bash'
	source_file             string
	no_cd                   bool
	exit_on_error           bool
	error_on_undefined_vars bool
	print_commands          bool
	exit_on_pipe_failures   bool
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

pub fn (mut m Mog) execute_task(task_name string, verbose bool, prepend string) {
	mut body := interpolate(m, task_name)
	mut source := ''
	config := m.get_config_from_task(task_name)
	if config.source_file.len > 0 {
		source = '. ${config.source_file}\n'
	}
	if config.no_cd {
		body = '${source}${body}'
	} else {
		body = '${prepend}${source}${body}'
	}
	body = '${add_option_flags(config)}\n${body}'
	body = "${config.shell_path} -c '${body}'"
	if verbose {
		println('Executing the following commands:\n')
		println(body)
		println('${built_in_vars['\$normal']}\n---\n')
	}
	exit_code := os.system(body)
	if exit_code == 2 {
		eprint('\nBODY:\n${body}\n')
	}
	println('${built_in_vars['\$normal']}\nExit Code: ${exit_code}')
	exit(exit_code)
}

fn add_option_flags(config Config) string {
	mut result := 'set -'
	if config.exit_on_error {
		result += 'e'
	}
	if config.error_on_undefined_vars {
		result += 'u'
	}
	if config.print_commands {
		result += 'x'
	}
	if config.exit_on_pipe_failures {
		result += 'o pipefail'
	}
	return result
}

@[params]
pub struct ParseConfigOptions {
	contents string
mut:
	config Config
}

pub fn parse_config(p ParseConfigOptions) !Config {
	mut file_contents := ''
	if p.contents.len == 0 {
		file_contents = os.read_file(config_file_path) or {
			''
		}
	} else {
		file_contents = p.contents
	}
	mut config := Config{
		shell_path:  p.config.shell_path
		source_file: p.config.source_file
	}
	for line in file_contents.split_into_lines() {
		mut parts := line.split('=')
		if parts.len < 2 {
			parts << ''
		}
		key := parts[0].trim_space()
		value := parts[1].trim_space()
		if key == 'shell_path' {
			config.shell_path = value
		}
		if key == 'source_file' {
			config.source_file = value
		}
		if key == 'no_cd' {
			config.no_cd = value == 'true'
		}
		if key == 'exit_on_error' {
			config.exit_on_error = value == 'true'
		}
		if key == 'error_on_undefined_vars' {
			config.error_on_undefined_vars = value == 'true'
		}
		if key == 'print_commands' {
			config.print_commands = value == 'true'
		}
		if key == 'exit_on_pipe_failures' {
			config.exit_on_pipe_failures = value == 'true'
		}
	}
	return config
}
