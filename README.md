# Mog

A simple task runner

Define your tasks in a `.mog` file and run them with the `mog` command. Indentation is done with the tab character or 4 spaces. Define a task named 'default' to be ran when `mog` is called without a task name. The biggest difference between mog and other task runners is that they all run each line in a seperate shell by default. Mog however will run the commands for a given task in the same shell instance which really helps with stuff like sourcing nvm. You don't have to add '&&\' to every command and put '. ~/.nmv/nvm.sh' everywhere over and over.


## Features

- variables (just strings)
- shell eval with `[]` for setting variables
- interpolation of variables using `{}` (unless the `{` has a `$` in front, in which case it is left alone for the shell to interpret)
- escape the `[` and `{` characters with `\`
- additional cli arguments are passed to the task being ran
- task descriptions with `@desc()` decorator
- task options with `@options()` decorator
- single line comments with `#`
- mog specific `if` statements to avoid having to use bash's confusing syntax
- importing other `.mog` files and using the tasks or variables with dot syntax
- call another task in the middle of a task


# Installation

```bash
curl -fsSL https://raw.githubusercontent.com/ayehavgunne/mog/main/get_mog.sh | bash
```

Then add it to your path or run `mog --symlink` to automatically create a symbolic link from it's current location to `~/.local/bin/mog`


## What does it look like?

```
# a comment

# an import block
import (
	path/to/other/dir/with/.mog/file
	path/to/another/dir as my_alias
)

# variable declarations
py_version = 3.13
py = python{py_version} # variable string interpolation
v_path = [which v] # storing a shell eval into a variable

# the default task which is executed when calling a bare 'mog' with no arguments
default:
    {run}

@desc(run my project) # description to show up when running 'mog -l'
run:
	echo ${EDITOR} # task body is plain shell scripting
	{py} my_script.py # with mog string interpolation on top
    {my_alias.some_task} arg1 arg2 "quoted arg" # reference imported tasks and even pass different arguments to them

@desc(for testing)
test:
	echo {v_path}
	sleep 2
	echo {$1} # just like bash scripts or functions
	echo {$2} # you can pass any extra cli arguments exactly
	echo {$@} # where you need to with these special variables
	echo {$"@"} # they behave exatly the same as bash's equivalents
	echo {$*}
	echo {$"*"}
	echo {$#}

test_ifs:
	@if $(uname -s | tr "[:upper:]" "[:lower:]") == darwin
		echo using MacOS
	@elif $(uname -s | tr "[:upper:]" "[:lower:]") == linux
		echo using Linux
	@else
        echo using something else
    @fi
...
```

## Options/Config

An optional config file lives at `~/.config/mog/config` and it will apply globaly to all tasks run by the current user. To set up a config file just run `mog --init-config` and one will be created in the correct spot with all the default values. The contents of the config file are key value pairs delimeted by `=`. Use the command line flag `--config-path [your_path]` to provide a config file from another location.

```
shell_path=/bin/bash          # the shell you would like your tasks executed by
source_file=                  # if you would like to source an external file to reference functions, env vars, etc. in your tasks
no_cd=false                   # Don't change cwd when running a mog file from another directory with '-p'
exit_on_error=false           # Sets the `e` shell flag via `set -e` at the begining of task
error_on_undefined_vars=false # Sets the `u` shell flag via `set -u` at the begining of task
exit_on_pipe_failures=false   # Sets the `o pipefail` shell flag via `set -o pipefail` at the begining of task
print_commands=false          # Sets the `x` shell flag via `set -x` at the begining of task
```

Any of these options can be overridden per task by using the `options` decorator.

```
@options(
    shell_path=/bin/zsh
    exit_on_error=true
)
my_task:
    echo $0 # should output /bin/zsh
    ls this_path_does_not_exist # should exit here instead of continuing
    echo done
```

## Examples

See this projects various .mog files


## Help

Just run `mog -h|--help`


## TODO

- test on Windows?
- add boolean operators for `if` statements
