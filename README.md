# Mog

A simple task runner

Define your tasks in a `.mog` file and run them with the `mog` command. Indentation is done with the tab character. Define a task named 'default' to be ran when `mog` is called without a task name.


## Features

- variables (just strings)
- shell eval with `[]`
- interpolation of variables using `{}` (unless the `{` has a `$` in front, in which case it is left alone for the shell to interpret)
- escape the `[` and `{` characters with `\`
- additional cli arguments are passed to the task being ran
- task dependencies with `@dep()` decorator
- task descriptions with `@desc()` decorator
- single line comments with `#`
- importing other `.mog` files and using the tasks or variables with dot syntax
- call another task in the middle of a task
- execute an imported task directly from the cli `$ mog imported_mog.task_name`


# Installation

```bash
curl -fsSL https://raw.githubusercontent.com/ayehavgunne/mog/main/get_mog.sh | bash
```

Then add it to your path or run `mog symlink` to automatically create a symbolic link from it's current location to `~/.local/bin/mog`


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
@dep(run)
default:
# with a declared dependency and no body this is basically an alias

@dep( # defines dependencies that will be run before this task (in the same shell instance)
	build
	start
	my_alias.some_task_name
)
@desc(run my project) # description to show up when running 'mog -l'
run:
	echo ${EDITOR} # task body is plain shell scripting
	{py} my_script.py # with mog string interpolation on top

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

...
```


## Examples

See this projects various .mog files


## Help

Just run `mog -h` or `mog --help` or `mog help`


## TODO

- test on Windows?
