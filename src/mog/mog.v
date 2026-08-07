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
	exit_on_pipe_failures   bool
	print_commands          bool
	hide_exit_code_output   bool
}

fn (c Config) to_str() string {
	mut out := 'Config{\n'
	$for field in Config.fields {
		value := c.$(field.name)
		out += '    ${field.name}=${value}\n'
	}
	out += '}'
	return out
}

pub fn (c Config) defaults() string {
	mut out := ''
	$for field in Config.fields {
		value := c.$(field.name)
		out += '${field.name}=${value}\n'
	}
	return out
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

pub fn (mut m Mog) execute_task(task_name string, verbose bool, prepend string, no_exit_code bool) {
	mut body := interpolate(m, task_name)
	mut source := ''
	config := m.get_config_from_task(task_name)
	mut relax_flags := 'set +euo pipefail\n'

	if config.source_file.len > 0 {
		source = '. ${config.source_file}\n'
	}
	if source.len == 0 {
		relax_flags = ''
	}

	if config.no_cd {
		body = '${relax_flags}${source}${add_option_flags(config)}\n${body}'
	} else {
		body = '${prepend}${relax_flags}${source}${add_option_flags(config)}\n${body}'
	}

	body = "${config.shell_path} -c '${body}'"

	if verbose {
		println('${config.to_str()}\n')
		println('Executing the following commands:\n')
		println(body)
		println('${built_in_vars['\$normal']}\n---\n')
	}

	exit_code := os.system(body)
	if !config.hide_exit_code_output && !no_exit_code {
		println('${built_in_vars['\$normal']}\nExit Code: ${exit_code}')
	}
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
pub:
	contents    string
	config_path string = config_file_path
mut:
	config Config
}

pub fn parse_config(p ParseConfigOptions) !Config {
	mut file_contents := ''
	if p.contents.len == 0 {
		file_contents = os.read_file(p.config_path) or { '' }
	} else {
		file_contents = p.contents
	}
	mut config_map := map[string]string{}
	for line in file_contents.split_into_lines() {
		mut parts := line.split('=')
		if parts.len < 2 {
			parts << ''
		}
		key := parts[0].trim_space()
		value := parts[1].trim_space()
		config_map[key] = value
	}
	mut config := Config{}
	$for field in Config.fields {
		if field.name in config_map {
			$if field.typ is bool {
				config.$(field.name) = config_map[field.name] == 'true'
			}
			$if field.typ is string {
				config.$(field.name) = config_map[field.name]
			}
		} else {
			config.$(field.name) = p.config.$(field.name)
		}
	}
	return config
}
