# Mog

A simple task runner

Define your tasks in a `.mog` file and run them with the `mog` command. Indentation is done with the tab character or 4 spaces. Define a task named 'default' to be ran when `mog` is called without a task name. The biggest difference between mog and other task runners is that they all run each line in a seperate shell by default. Mog however will run the commands for a given task in the same shell instance which really helps with stuff like sourcing nvm. You don't have to add '&&\' to every command and put '. ~/.nmv/nvm.sh' everywhere over and over.


## Features

- variables (just strings)
- shell eval with `[]` for setting variables
- interpolation of variables using `{}` (unless the `{` has a `$` in front, in which case it is left alone for the shell to interpret)
- escape mog special characters with `\`
- additional cli arguments are passed to the task being ran
- task descriptions with `@desc()` decorator
- task options with `@options()` decorator
- single line comments with `#`
- mog specific `if` statements to avoid having to use bash's confusing syntax
- importing other `.mog` files and using the tasks or variables with dot syntax
- call another task in the middle of a task
- automatically load env files 


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
# an options block
options (
    print_commands=true
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

An optional config file lives at `~/.config/mog/config` and it will apply globaly to all tasks run by the current user. To set up a config file just run `mog --init-config` and one will be created in the correct path with all the default values. The contents of the config file are key value pairs delimeted by `=`. Use the command line flag `--config-path [your_path]` to provide a config file from another location.

```
shell=bash                     # The shell you would like to execute tasks. For common shells this can just be the name or it can just be the path to a specific shell
source_file=                   # If you would like to source an external file to reference functions, env vars, etc. in your tasks
env_files=./.env, ./.env.local # Comma seperated list. Provide any env files to load before executing a task. Leading and trailing whitespace is insignificant
no_cd=false                    # Don't change cwd when running a mog file from another directory with '-p'
exit_on_error=false            # Exit as soon as a command returns a non-zero status
error_on_undefined_vars=false  # Errors if the shell encounters an undefined variable
exit_on_pipe_failures=false    # The return value of a pipeline is the value of the last command to exit with a non-zero status
print_commands=false           # The shell will echo each command source before executing
hide_exit_code_output=false    # Silences the extra mog outputs like the exit code
new_shell_per_line=false       # Run each line in a task with a new shell instance
```

Any of these options can be overridden per mog file with the options block.

```
options (
    shell=zsh
    exit_on_error=true
)
```

They can also be overridden per task by using the `options` decorator.

```
@options(
    shell=zsh
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
- named arguments?
