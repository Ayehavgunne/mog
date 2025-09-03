# Mog

A simple task runner

Define your tasks in a `.mog` file and run them with the `mog` command. Indentation is done with the tab character. Define a task named 'default' to be ran when `mog` is called without a task name.

## Features
- variables (just strings)
- shell eval with `[]`
- interpolation of variables using `{}` (unless the `{` has a `$` in front, in which case it is left alone for the shell to interpret)
- escape the `[` and `{` characters with `\`
- additional cli arguments are passed to the task being ran
- task dependencies
- task descriptions
- single line comments with #
- SOON: importing other `.mog` files

## Example
See this projects .mog file

## TODO
- add imports
