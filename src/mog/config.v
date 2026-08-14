module mog

import os

pub struct Config {
pub mut:
	shell                   Shell = bash
	source_file             string
	env_files               []string
	no_cd                   bool
	exit_on_error           bool
	error_on_undefined_vars bool
	exit_on_pipe_failures   bool
	print_commands          bool
	hide_exit_code_output   bool
	new_shell_per_line      bool
}

fn (c Config) to_str() string {
	mut out := 'Config{\n'
	$for field in Config.fields {
		value := c.$(field.name)
		$if field.typ is Shell {
			out += '    ${field.name}=Shell{\n'
			$for shell_field in Shell.fields {
				shell_value := c.shell.$(shell_field.name)
				out += '        ${shell_field.name}=${shell_value}\n'
			}
			out += '    }\n'
		} $else $if field.typ is []string {
			out += '    ${field.name}=${value.join(', ')}\n'
		} $else {
			out += '    ${field.name}=${value}\n'
		}
	}
	out += '}'
	return out
}

pub fn (c Config) defaults() string {
	mut out := ''
	$for field in Config.fields {
		value := c.$(field.name)
		$if field.typ is string {
			out += '${field.name}=${value}\n'
		}
		$if field.typ is Shell {
			out += '${field.name}=${value.name}\n'
		}
		$if field.typ is []string {
			out += '${field.name}=${value.join(', ')}\n'
		}
		$if field.typ is bool {
			out += '${field.name}=${value}\n'
		}
	}
	return out
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
			$if field.typ is []string {
				config.$(field.name) = config_map[field.name].split(',').map(it.trim_space())
			}
			$if field.typ is Shell {
				config.$(field.name) = shell_map[config_map[field.name]] or {
					mut shell := shell_map[config_map[field.name].split('/').last()]
					shell.path = config_map[field.name]
					shell
				}
			}
		} else {
			config.$(field.name) = p.config.$(field.name)
		}
	}
	if !config.shell.supports_sourcing {
		config.source_file = ''
	}
	return config
}
