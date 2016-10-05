# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [2.3.0] - 2016-10-05

### Added

- Implement `imagefs.listDirectory()`.

## [2.2.0] - 2016-10-03

### Added

- Implement `imagefs.readFile()`.
- Implement `imagefs.writeFile()`.

## [2.1.2] - 2015-12-04

### Changed

- Reduce package size by omitting tests in NPM.

## [2.1.1] - 2015-10-13

### Changed

- Close drive file descriptor after any operation.

## [2.1.0] - 2015-07-28

### Added

- Implement `imagefs.replace()` function.

## [2.0.1] - 2015-07-27

### Changed

- Fix documentation issues.

### Removed

- FAT file touch workaround before write.

## [2.0.0] - 2015-07-23

### Changed

- Use object path definitions instead of `image:(partition):/path` device paths.

### Removed

- Local file read/write support.

[2.3.0]: https://github.com/resin-io/resin-image-fs/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/resin-io/resin-image-fs/compare/v2.1.2...v2.2.0
[2.1.2]: https://github.com/resin-io/resin-image-fs/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/resin-io/resin-image-fs/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/resin-io/resin-image-fs/compare/v2.0.1...v2.1.0
[2.0.1]: https://github.com/resin-io/resin-image-fs/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/resin-io/resin-image-fs/compare/v1.0.0...v2.0.0
