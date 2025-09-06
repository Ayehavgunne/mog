module main

import os
import v.vmod
import mog { Mog, debug, parse }

const defualt_task = 'default'

fn main() {
	mut args := arguments()[1..]
	mut dash_args := []string{}

	if args.len > 0 && args.first() == 'symlink' {
		result := os.execute('ln -s ${os.getwd()}/mog ${os.home_dir()}/.local/bin/mog')
		println(result.output)
		exit(result.exit_code)
	}

	for arg in args {
		if arg.starts_with('-') {
			dash_args << arg
		} else {
			break
		}
	}
	for _ in dash_args {
		args.pop_left()
	}

	if '-V' in dash_args || '--version' in dash_args {
		print_version()
		exit(0)
	}

	mog_file := os.read_file('.mog') or {
		if args.len == 0 || 'help' !in args {
			println('Failed to read file.')
			exit(1)
		}
		''
	}
	mut parse_args := []string{}

	if args.len > 0 {
		parse_args = args[1..].clone()
	}

	mut m := Mog{}

	if mog_file.len > 0 {
		m = parse(mog_file, parse_args) or {
			println('Failed to parse .mog file. ${err}')
			exit(1)
		}
		debug('${m}')
	}

	if '-l' in dash_args || '--list' in dash_args {
		print_commands(m)
		exit(0)
	}

	if '-h' in dash_args || '--help' in dash_args || (args.len > 0 && 'help' == args.first()) {
		if args.len > 1 && args[1] == 'arguments' {
			print_arguments_help()
			exit(0)
		}
		print_help(m)
		exit(0)
	}

	if args.len == 0 && defualt_task in m.tasks {
		args << defualt_task
	}

	if args.len == 0 {
		println("Add a task named '${defualt_task}' to the .mog file to have it run when no task is provided to the mog command\n")
		print_version()
		println('')
		print_help(m)
		exit(0)
	}

	task_name := args.pop_left()
	mut task := m.get_task(task_name) or {
		eprint("No task named '${task_name}' found")
		exit(1)
	}
	task.execute()
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
	println('Mog is a tool for running tasks from a .mog file in the current directory\n')
	println('Usage:')
	println('  mog [options] [task] [arguments]\n')
	println('Any arguments passed after the task name will be forwarded to that task if you use the bash like {$#} syntax. For more info run "mog help arguments"\n')
	print_options()
	println('')
	print_builtins_help()
	println('')
	print_commands(m)
}

fn print_options() {
	println('Options:')
	println('  -l | --list:\t\tList available tasks')
	println('  -h | --help:\t\tShow the help output')
	println('  -V | --version:\tShow the version of mog')
}

fn print_builtins_help() {
	println("Built in task names that shouldn't be used in a .mog file:")
	println('  help:\t\tShow the help output')
	println('  symlink:\tCreate a symlink for the mog command to ~/.local/bin')
}

fn print_arguments_help() {
	println('Mog argument access:\n')
	println('- Individual arguments are accessed using {$1} for the first argument, {$2} for the second, and so on')
	println('- {$#} holds the total count of positional arguments')
	println('- {$*} expands all positional parameters into a single string, separated by the a space')
	println('- {$"*"} becomes a single string, e.g., "arg1 arg2 arg3"')
	println('- {$@} expands positional parameters as separate quoted strings')
	println('- {$"@"} expands to "{$1}" "{$2}" "{$3}", treating each argument as a distinct entity')
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
