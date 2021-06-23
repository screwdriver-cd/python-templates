# Utility templates

This directory contains the python-2104 release screwdriver templates used to
perform utility operations.

| Template                            | Description |
| ----------------------------------- | ----------- |
| [version](version.yaml)             | Generate a package version using the screwdrivercd_version utility and store the version in the pipeline metadata so it can be used by other jobs in the pipeline that require the package version |
| [documentation](documentation.yaml) | Generate documentation using sphinx or mkdocs and publish to github pages of the current repo |
