module mog

import os

// TODO: make fully compliant with env file spec
pub fn read_env_file(path string, env_file_path string) {
	if env_file_path.len > 0 {
		env_file := os.read_file('${path}/${env_file_path}') or {
			eprint('Failed to read env file\n')
			exit(1)
		}
		for line in env_file.split_into_lines() {
			if line.starts_with('#') {
				continue
			}
			parts := line.split('=')
			os.setenv(parts[0].trim_space(), parts[1].trim_space(), true)
		}
	}
}
