module mog

pub struct Shell {
pub:
	name                         string
	interpreting_flag            string = '-c'
	exit_on_error_flag           string = 'e'
	error_on_undefined_vars_flag string = 'u'
	print_commands_flag          string = 'x'
	exit_on_pipe_failures_flag   string = 'o pipefail'
	supports_cd                  bool   = true
	supports_sourcing            bool   = true
pub mut:
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

pub const bash = Shell{
	name: 'bash'
	path: '/bin/bash'
}

pub const zsh = Shell{
	name: 'zsh'
	path: '/bin/zsh'
}

pub const python = Shell{
	name:                         'python'
	path:                         '/user/bin/python'
	exit_on_error_flag:           ''
	error_on_undefined_vars_flag: ''
	print_commands_flag:          ''
	exit_on_pipe_failures_flag:   ''
	supports_cd:                  false
	supports_sourcing:            false
}

pub const shell_map = {
	'bash':    bash
	'zsh':     zsh
	'python':  python
	'python3': python
}
