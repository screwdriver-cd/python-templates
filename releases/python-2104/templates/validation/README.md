# Validation templates

This directory contains the python-2104 release screwdriver templates used to validate Python code and packages.

| Template                                 | Description |
| ---------------------------------------- | ----------- |
| [validate_lint](code_lint.yaml)          | Perform linting (static code analysis on the code using the pylint tool |
| [validate_security](code_security.yaml)  | Perform code security analysis using the bandit tool                    |
| [validate_style](code_style.yaml)        | Check the code for compliance with the Python style guide using the pycodestyle tool |
| [validate_type](code_type.yaml)          | Perform type annotation check on code using the mypy tool                            |
| [validate_unittest](code_unit_test.yaml) | Run unit tests of the code using tox and pytest                                      |

