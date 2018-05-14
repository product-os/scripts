# Resin.io Scripts

This is a collection of scripts for running standard development and CI
workflows. By contributing scripts here and consuming scripts from this
repository, you can ensure that you're running things like tests and linting in
the same way that our CI system will run them.

## Structure

The scripts are organized by associated project type, or `shared` for
general-purpose scripts. An example is the `electron/electron-builder.sh`
script. This script will build electron projects, and handle things like
checking dependencies and outputting all the different sort of artifacts you
might want.

## Contributing

If you have common tasks you perform and would like to share with the rest of
the company or the CI pipelines, we encourage submitting new scripts here.

### Contribution Guidelines

* Any and all secrets consumed in a script should be read from the environment,
  and never exposed via debugging output, including use of the `set -x` flag. If
  you want to output the commands being run, just ensure you put a `set +x`
  before any sensitive commands.
* Ensure that all paths to other scripts are relative to the file, and don't
  depend on where the working directory is set in the calling process.
* All scripts should run in `bash`, and check their dependencies prior to using
  them. There's a script at `shared/check-dependency.sh` for checking
  dependencies. See the electron builder script for an example of usage.

