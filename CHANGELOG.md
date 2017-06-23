# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [4.0.1] - 2017-06-23

### Fixed

- Fixed creating files in ext partitions with paths that do not start with '/'.

## [4.0.0] - 2017-06-19

### Changed

- All methods that take a partition as a parameter now expect the partition number instead of {primary: X, logical: Y}.

## [3.0.0] - 2017-06-16

### Added

- Support for ext2, ext3 and ext4 filesystems.
- `imagefs.interact(disk, partition)` returns a disposer of a node fs like interface. Sync methods are not supported.

### Changed

- `imagefs.listDirectory()` lists all files, including those that start with a dot.
- `imagefs.write`, `imagefs.copy` and `imagefs.replace` now return a `Promise` instead of a `Promise<WriteStream>`.
- `imagefs.read` now returns a `disposer<ReadStream>` instead of a `Promise<ReadStream>`.
- All methods now accept `filedisk.Disk` instances as well as image paths.

### Fixed

- Logical partitions are now correctly handled.

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

[4.0.1]: https://github.com/resin-io/resin-image-fs/compare/v4.0.0...v4.0.1
[4.0.0]: https://github.com/resin-io/resin-image-fs/compare/v3.0.0...v4.0.0
[3.0.0]: https://github.com/resin-io/resin-image-fs/compare/v2.3.0...v3.0.0
[2.3.0]: https://github.com/resin-io/resin-image-fs/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/resin-io/resin-image-fs/compare/v2.1.2...v2.2.0
[2.1.2]: https://github.com/resin-io/resin-image-fs/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/resin-io/resin-image-fs/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/resin-io/resin-image-fs/compare/v2.0.1...v2.1.0
[2.0.1]: https://github.com/resin-io/resin-image-fs/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/resin-io/resin-image-fs/compare/v1.0.0...v2.0.0
