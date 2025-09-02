# Mog

A simple task runner

Define your tasks in a .mog file and run them with the `mog` command. Indents are done with the tab character

## Features
- variables (just strings)
- interpolation of variables using `{}` (unless the `{` has a `$` in front, in which case it is left alone for the shell to interpret)
- additional cli arguments are passed to the command being ran
- task dependancies
- task descriptions
- SOON: importing other .mog files
- single line comments with #

## Example
See this projects .mog file

## TODO
- add imports
