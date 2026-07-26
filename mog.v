module mog

import os

pub struct Task {
pub mut:
	desc string
	body []string
}

pub struct Mog {
pub:
	tasks map[string]Task
	path  string
pub mut:
	vars       map[string]string
	imports    map[string]Mog
	args       []string
	shell_path string = '/bin/bash'
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

pub fn (mut m Mog) execute_task(task_name string, verbose bool, prepend string) {
	body := interpolate(m, task_name)
	debug(body)
	if verbose {
		println('Executing the following commands:\n')
		println(body)
		println('${built_in_vars['\$normal']}\n---\n')
	}
	exit_code := os.system("${m.shell_path} -c '${prepend}${body}'")
	println('${built_in_vars['\$normal']}\nExit Code: ${exit_code}')
}
