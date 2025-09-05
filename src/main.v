module main

import os
import v.vmod
import mog { Mog, debug, parse }

const defualt_task = 'default'

fn main() {
	mut args := arguments()[1..]
	mut dash_args := []string{}

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
		println('Failed to read file.')
		exit(1)
	}

	mut m := parse(mog_file) or {
		println('Failed to parse .mog file. ${err}')
		exit(1)
	}
	debug('${m}')

	if '-l' in dash_args || '--list' in dash_args {
		print_commands(m)
		exit(0)
	}

	if '-h' in dash_args || '--help' in dash_args {
		print_help(m)
		exit(0)
	}

	if args.len == 0 && defualt_task in m.tasks.keys() {
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
	if task_name !in m.tasks.keys() {
		eprint("No task named '${task_name}' found")
		exit(1)
	}
	mut task := m.tasks[task_name]
	m.execute(mut task, args)
}

fn print_version() {
	vm := vmod.decode(@VMOD_FILE) or { panic(err) }
	println('${vm.name} ${vm.version}')
}

fn print_commands(m ?Mog) {
	definite_m := m or { return }
	println('Tasks available from the current .mog file:')
	mut labels := definite_m.tasks.keys()
	for mut label in labels {
		label = '  ${label}:'
	}
	len := longest(labels)
	for name, task in definite_m.tasks {
		just_name := ljust('  ${name}:', len, ' ')
		if task.desc.len > 0 {
			println('${just_name}\t${task.desc}')
		} else {
			println('${just_name}')
		}
	}
}

fn print_help(m ?Mog) {
	println('Mog is a tool for running tasks from a .mog file in the current directory\n')
	println('Usage:')
	println('  mog [options] [task] [arguments]\n')
	println('Any arguments passed after the task name will be forwarded to that task\n')
	println('Options:')
	println('  -l | --list:\tList available tasks')
	println('  -h | --help:\tShow this output')
	println('  -V | --version:\tShow the version of mog')
	println('')
	print_commands(m)
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
