# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2023-01-31

- Migrate to `:ssh_file.decode/2` usage. See #11 and #10.

## [0.2.1] - 2021-07-26

### Changes

- Misc. documentation changes. Fixes #8.

## [0.2.0] - 2021-01-14

### Changes

- Upgraded all dependencies used.
- Reformatted all source code via `mix format` command.
- Resolved a long standing issue with the `handler` configuration
  item.
- Modernization of the source code.

## [0.1.1] - 2019-11-11

### Changes

- Do not start sftp protocol by default. Fixes #4.
- Explicitly pass an empty passphrase to ssh-keygen. Fixes #3.

## [0.1.0] - 2017-07-17

* Initial public release.
