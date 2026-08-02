module main

import os
import v.vmod
import mog { Config, Mog, ParseConfigOptions, debug, parse, parse_config }

const default_task = 'default'
const value_arg_keys = ['-s', '--shell', '-p']
const default_configs = 'shell_path=/bin/bash\nexit_on_error=true\nerror_on_undefined_vars=true\nexit_on_pipe_failures=true'

fn main() {
	cur_dir := os.getwd()
	mut args := arguments()
	mog_file_name := args.pop_left().split('/').last()
	mut dash_args := []string{}

	if args.len > 0 && args.first() == '--symlink' {
		result := os.execute('ln -s ${cur_dir}/${mog_file_name} ${os.home_dir()}/.local/bin/mog')
		if result.exit_code == 0 {
			println('Linked ${cur_dir}/${mog_file_name} to ${os.home_dir()}/.local/bin/mog')
		} else {
			println(result.output)
		}
		exit(result.exit_code)
	}

	mut positional_args := []string{}
	mut value_args := map[string]string{}
	mut skip := false
	for index, arg in args {
		if arg in value_arg_keys {
			value_args[arg] = args[index + 1]
			skip = true
			continue
		}
		if !skip {
			if arg.starts_with('-') {
				dash_args << arg
			} else {
				positional_args << arg
			}
		} else {
			skip = false
			continue
		}
	}
	for _ in dash_args {
		args.pop_left()
	}
	for _ in value_args.keys() {
		args.pop_left()
		args.pop_left()
	}

	if '-V' in dash_args || '--version' in dash_args {
		print_version()
		exit(0)
	}

	if '--init-config' in dash_args {
		os.system("mkdir -p ${mog.config_path} && touch ${mog.config_file_path} && echo '${default_configs}' > ${mog.config_file_path}")
		exit(0)
	}

	mut mog_file_path := '.'
	if '--home' in dash_args {
		mog_file_path = os.home_dir()
		os.chdir(mog_file_path) or {
			println('Invalid path: ${mog_file_path}')
			exit(1)
		}
	} else if '-p' in value_args {
		mog_file_path = value_args['-p']
		mog_file_path = os.abs_path(cur_dir + '/' + mog_file_path)
		if !os.exists(mog_file_path) {
			println('Invalid path: ${mog_file_path}')
			exit(1)
		}
		os.chdir(mog_file_path) or {
			println('Invalid path: ${mog_file_path}')
			exit(1)
		}
	}

	mog_file := os.read_file('${mog_file_path}/.mog') or {
		if args.len != 0 && 'help' !in args && '-h' !in dash_args && '--help' !in dash_args {
			println('Failed to read file.')
			exit(1)
		}
		''
	}
	mut parse_args := []string{}

	if args.len > 0 {
		parse_args = args[1..].clone()
	}

	config := parse_config(ParseConfigOptions{}) or { Config{} }

	mut m := Mog{}

	if mog_file.len > 0 {
		m = parse(mog_file, parse_args, config) or {
			println('Failed to parse .mog file. ${err}')
			exit(1)
		}
		debug('${m}')
	}

	if '-s' in value_args {
		m.config.shell_path = value_args['-s']
	}
	if '--shell' in value_args {
		m.config.shell_path = value_args['--shell']
	}

	if '-l' in dash_args || '--list' in dash_args {
		print_commands(m)
		exit(0)
	}

	mut verbose := false
	if '-v' in dash_args || '--verbose' in dash_args {
		verbose = true
	}

	if '-h' in dash_args || '--help' in dash_args {
		if args.len > 0 {
			if args[0] == 'arguments' {
				print_arguments_help()
				exit(0)
			}
			if args[0] == 'variables' {
				print_builtin_vars_help()
				exit(0)
			}
		}
		print_help(m)
		exit(0)
	}

	if args.len == 0 && default_task in m.tasks {
		args << default_task
	}

	if args.len == 0 {
		if mog_file != '' {
			println("Add a task named '${default_task}' to the .mog file to have it run when no task is provided to the mog command\n")
		}
		print_version()
		println('')
		print_help(m)
		exit(0)
	}

	task_name := args.pop_left()
	mut prepend := ''
	if mog_file_path != '.' && '--no-cd' !in dash_args {
		prepend = 'cd ${mog_file_path}\n'
	}
	m.execute_task(task_name, verbose, prepend)
}

fn print_version() {
	vm := vmod.decode(@VMOD_FILE) or { panic(err) }
	println('${vm.name} ${vm.version}')
}

fn print_commands(m ?Mog) {
	definite_m := m or { return }
	println('Available tasks:')
	sub_print_commands(definite_m, '')
}

fn sub_print_commands(m Mog, mog_name string) {
	mut mut_mog_name := mog_name.clone()
	if mog_name.len > 0 {
		mut_mog_name += '.'
	}
	mut labels := m.tasks.keys()
	for mut label in labels {
		label = '  ${mut_mog_name}${label}:'
	}
	len := longest(labels)
	for name, task in m.tasks {
		just_name := ljust('  ${mut_mog_name}${name}:', len, ' ')
		if task.desc.len > 0 {
			println('${just_name}\t${task.desc}')
		} else {
			println('${just_name}')
		}
	}
	for import_mog_name, imported_mog in m.imports {
		sub_print_commands(imported_mog, '${mut_mog_name}${import_mog_name}')
	}
}

fn print_help(m ?Mog) {
	println('Mog is a tool for running common cli tasks from a .mog file\n')
	println('Usage:')
	println('  mog [options] [task] [arg1] [arg2] ...\n')
	print_options()
	println('')
	print_list_help_topics()
	println('')
	if definite_mog := m {
		if definite_mog.tasks.keys().len > 0 || definite_mog.imports.keys().len > 0 {
			print_commands(m)
		}
	}
}

fn print_list_help_topics() {
	println('Help topics (run "mog (-h|--help) [topic]"):')
	println('  arguments:\tShow information on using forwarded arguments from the cli to tasks')
	println('  variables:\tShow built in variables that can be used in your tasks')
}

fn print_options() {
	println('Options:')
	println('  -v | --verbose:\t\tShow the commands that will be executed before running them')
	println('  -s | --shell [shell_path]:\tRun the .mog file commands with a different shell. Default is /bin/bash')
	println('  --home:\t\t\tRun the .mog file that is in your home directory. Ignores -p option')
	println('  -p [path]:\t\t\tRun a .mog file from another location')
	println('')
	println("  --no-cd:\t\t\tDon't change cwd when running a mog file from another directory with '-p'")
	println('  --symlink:\t\t\tCreate a symlink for the mog command to ~/.local/bin')
	println('')
	println('  -l | --list:\t\t\tList available tasks')
	println('  -h | --help:\t\t\tShow the help output')
	println('  -V | --version:\t\tShow the version of mog')
}

fn print_arguments_help() {
	println('Mog argument access:\n')
	println('- Individual arguments are accessed using {$1} for the first argument, {$2} for the second, and so on')
	println('- {$#} holds the total count of positional arguments')
	println('- {$*} expands all positional parameters into a single string, separated by the a space')
	println('- {$"*"} becomes a single string, e.g., "arg1 arg2 arg3"')
	println('- {$@} expands positional parameters as separate quoted strings')
	println('- {$"@"} expands to "{$1}" "{$2}" "{$3}", treating each argument as a distinct entity')
	println('\nExample:\n')
	println('```')
	println('run:')
	println('\tpython my_script.py {$@} # this passes all cli arguments to the python script\n')
	println('```\n')
	println('In the cli:\n')
	println('$ mog run arg1 arg2')
}

fn print_builtin_vars_help() {
	println('Built in variables:\n')
	for key, value in mog.built_in_vars {
		mut val := value
		if value.starts_with('\e') {
			val = '\\e${value[1..]}'
		}
		println('- ${key} = "${val}"')
	}
}

fn ljust(str string, len int, fill string) string {
	if str.len >= len {
		return str
	}
	mut new_str := str
	mod := int(len - (str.len % len))
	new_str += fill.repeat(mod)
	return new_str
}

fn longest(strs []string) int {
	mut len := 0
	for str in strs {
		if str.len > len {
			len = str.len
		}
	}
	return len
}
