module main

import os
import v.vmod
import mog { Mog, parse }

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

	mog_file := os.read_file('.mog') or {
		println('Failed to read file.')
		exit(1)
	}

	mut m := parse(mog_file) or {
		println('Failed to parse .mog file. ${err}')
		exit(1)
	}

	if '-V' in dash_args || '--version' in dash_args {
		print_version()
		exit(0)
	}

	if '-l' in dash_args || '--list' in dash_args {
		print_commands(m)
		exit(0)
	}

	if '-h' in dash_args || '--help' in dash_args {
		print_help(m)
		exit(0)
	}

	if args.len == 0 {
		print_version()
		println('')
		print_help(m)
		exit(0)
	}

	command := m.commands[args.pop_left()]
	res := m.execute(command, args)
	println(res.output.trim_space())
	println('\nCode: ${res.exit_code}')
}

fn print_version() {
	vm := vmod.decode(@VMOD_FILE) or { panic(err) }
	println('${vm.name} ${vm.version}')
}

fn print_commands(m Mog) {
	println('Commands available from the current .mog file:')
	mut labels := m.commands.keys()
	for mut label in labels {
		label = '  ${label}:'
	}
	len := longest(labels)
	for name, command in m.commands {
		just_name := ljust('  ${name}:', len, ' ')
		if command.desc.len > 0 {
			println('${just_name}\t${command.desc}')
		} else {
			println('${just_name}')
		}
	}
}

fn print_help(m Mog) {
	println('Mog is a tool for running commands from a .mog file in the current directory\n')
	println('Usage:')
	println('  mog [options] [command] [arguments]\n')
	println('Any arguments passed after the command will be forwarded to that command\n')
	println('Options:')
	println('  -l | --list:\tList available commands')
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
