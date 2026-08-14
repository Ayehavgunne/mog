module mog

import os

pub struct Shell {
pub:
	aliases                      []string
	interpreting_flag            string = '-c'
	exit_on_error_flag           string = 'e'
	error_on_undefined_vars_flag string = 'u'
	print_commands_flag          string = 'x'
	exit_on_pipe_failures_flag   string = 'o pipefail'
	supports_cd                  bool   = true
	supports_sourcing            bool   = true
	std_out_cmd                  string = 'echo '
	preserv_indentation          bool
	supports_mog_conditionals    bool = true
	supports_mog_replacement     bool = true
pub mut:
	name string
	path string
}

fn (s Shell) to_str() string {
	mut out := 'Shell{\n'
	$for field in Shell.fields {
		value := s.$(field.name)
		out += '    ${field.name}=${value}\n'
	}
	out += '}'
	return out
}

fn (s Shell) execute(body string) string {
	if s.std_out_cmd.ends_with('(') {
		return os.execute("${s.path} ${s.interpreting_flag} '${s.std_out_cmd}${body})'").output.trim_space()
	} else {
		return os.execute("${s.path} ${s.interpreting_flag} '${s.std_out_cmd}${body}'").output.trim_space()
	}
}

fn (s Shell) eval(body string) string {
	return os.execute("${s.path} ${s.interpreting_flag} '${body}'").output.trim_space()
}

fn (mut s Shell) set_path() bool {
	result := os.execute("\${SHELL-bash} -c 'which ${s.name}'")
	if result.output.contains('aliased to') {
		result2 := os.execute("\${SHELL-bash} -c 'which ${result.output.split(' ').last()}'")
		if result2.exit_code == 0 {
			s.path = result2.output.trim_space()
			return true
		}
	}
	if result.output.contains('not found') {
		for alias in s.aliases {
			result_n := os.execute("\${SHELL-bash} -c 'which ${alias}'")
			if result_n.exit_code == 0 {
				s.path = result_n.output.trim_space()
				return true
			}
		}
	}
	if result.exit_code == 0 {
		s.path = result.output.trim_space()
		return true
	}
	return false
}

fn (s Shell) run(body string, config Config, verbose bool, path string) int {
	mut script := body
	mut source := ''
	mut relax_flags := 'set +euo pipefail\n'
	option_flags := s.add_option_flags(config)

	if config.source_file.len > 0 {
		source = '. ${config.source_file}\n'
	}
	if source.len == 0 || option_flags.len == 0 {
		relax_flags = ''
	}

	if !config.no_cd && s.supports_cd && path != '.' {
		script = '${relax_flags}cd ${path}\n${source}${option_flags}\n${script}'
	} else {
		script = '${relax_flags}${source}${option_flags}\n${script}'
	}

	if verbose {
		println('${config.to_str()}\n')
		println('Executing the following commands:\n')
		println(script)
		println('${built_in_vars['\$normal']}\n---\n')
	}

	if !config.new_shell_per_line {
		return os.system("${s.path} ${s.interpreting_flag} '${script}'")
	} else {
		mut exit_code := 0
		for line in script.split_into_lines() {
			exit_code = os.system("${s.path} ${s.interpreting_flag} '${line}'")
			if config.exit_on_error && exit_code != 0 {
				return exit_code
			}
		}
		return exit_code
	}
}

fn (s Shell) add_option_flags(config Config) string {
	mut result := ''
	if config.exit_on_error {
		result += s.exit_on_error_flag
	}
	if config.error_on_undefined_vars {
		result += s.error_on_undefined_vars_flag
	}
	if config.print_commands {
		result += s.print_commands_flag
	}
	if config.exit_on_pipe_failures {
		result += s.exit_on_pipe_failures_flag
	}
	if result.len > 0 {
		return 'set -${result}'
	} else {
		return ''
	}
}

@[params]
pub struct ParseShellOptions {
pub:
	contents   string
	shell_path string
mut:
	shell Shell
}

pub fn parse_shell(p ParseShellOptions) Shell {
	mut file_contents := ''
	if p.contents.len == 0 {
		file_contents = os.read_file(p.shell_path) or { '' }
	} else {
		file_contents = p.contents
	}
	mut shell_map := map[string]string{}
	for line in file_contents.split_into_lines() {
		mut key, mut value := line.split_once('=') or {
			eprint('Failed parsing shell file. Expected = in (${line})')
			exit(1)
		}
		key = key.trim_space()
		value = value.trim_space()
		shell_map[key] = value
	}
	mut shell := Shell{}
	$for field in Shell.fields {
		if field.name in shell_map {
			$if field.typ is bool {
				shell.$(field.name) = shell_map[field.name] == 'true'
			} $else $if field.typ is string {
				shell.$(field.name) = shell_map[field.name]
			} $else $if field.typ is []string {
				shell.$(field.name) = shell_map[field.name].split(',').map(it.trim_space())
			} $else {
				eprint('Unaccounted for type in Shell struct (${field.typ}) on field ${field.name}\n')
				exit(2)
			}
		}
	}
	return shell
}

pub const bash = Shell{
	name: 'bash'
	path: '/bin/bash'
}

pub const sh = Shell{
	name: 'sh'
	path: '/bin/sh'
}

pub const zsh = Shell{
	name: 'zsh'
	path: '/bin/zsh'
}

pub const python = Shell{
	name:                         'python'
	path:                         'python3'
	aliases:                      ['python3', 'python2', 'python']
	exit_on_error_flag:           ''
	error_on_undefined_vars_flag: ''
	print_commands_flag:          ''
	exit_on_pipe_failures_flag:   ''
	supports_cd:                  false
	supports_sourcing:            false
	std_out_cmd:                  'print('
	preserv_indentation:          true
	supports_mog_conditionals:    false
}

pub const node = Shell{
	name:                         'node'
	path:                         'node'
	interpreting_flag:            '-e'
	exit_on_error_flag:           ''
	error_on_undefined_vars_flag: ''
	print_commands_flag:          ''
	exit_on_pipe_failures_flag:   ''
	supports_cd:                  false
	supports_sourcing:            false
	std_out_cmd:                  'console.log('
	supports_mog_conditionals:    false
	supports_mog_replacement:     false
}

// pub const shells = {
// 	'bash':    bash
// 	'sh':      sh
// 	'zsh':     zsh
// 	'python':  python
// 	'python3': python
// 	'node':    node
// 	'nodejs':  node
// }
