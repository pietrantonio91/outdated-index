# Outdated Index
Author: Alessandro Pietrantonio
Email: pietrantonio.alessandro@gmail.com
Website: https://alessandropietrantonio.it

## Description
This is a simple bash script that evaluates a project's outdated dependencies and generates an index based on the results.

## Usage
For a basic usage run `bash outdated.sh` inside the project's root directory.
You can also pass the path to the project's root directory as a flag, e.g. `bash outdated.sh -p /path/to/project`.
For more information run `bash outdated.sh -h`.

## Outdated Index
The index is calculated based on the following rules:
- 100 points for each major version behind
- 10 points for each minor version behind
- 1 point for each patch version behind

The index is calculated by summing the points of all outdated dependencies.