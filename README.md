balena-image-fs
--------------

[![npm version](https://badge.fury.io/js/balena-image-fs.svg)](http://badge.fury.io/js/balena-image-fs)
[![dependencies](https://david-dm.org/balena-io-modules/balena-image-fs.png)](https://david-dm.org/balena-io-modules/balena-image-fs.png)
[![Build Status](https://travis-ci.org/balena-io-modules/balena-image-fs.svg?branch=master)](https://travis-ci.org/balena-io-modules/balena-image-fs)
[![Build status](https://ci.appveyor.com/api/projects/status/86bot1jaepcg5xlv?svg=true)](https://ci.appveyor.com/project/balena-io-modules/balena-image-fs)

Balena.io image filesystem manipulation utilities.

Role
----

The intention of this module is to provide low level utilities to Balena.io operating system data partitions.

**THIS MODULE IS LOW LEVEL AND IS NOT MEANT TO BE USED BY END USERS DIRECTLY**.

Installation
------------

Install `balena-image-fs` by running:

```sh
$ npm install --save balena-image-fs
```

Documentation
-------------


* [imagefs](#module_imagefs)
    * [~interact()](#module_imagefs..interact)
    * [~explorePartition(imagePath, partitionNames, exploreFn)](#module_imagefs..explorePartition) ⇒ <code>T</code>

<a name="module_imagefs..interact"></a>

### imagefs~interact()
**Kind**: inner method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: Run a function with a node fs like interface for a partition  
**Example**  
```js
const contents = await interact('/foo/bar.img', 5, async (fs) => {
	return await promisify(fs.readFile)('/bar/qux');
});
console.log(contents);
```
<a name="module_imagefs..explorePartition"></a>

### imagefs~explorePartition(imagePath, partitionNames, exploreFn) ⇒ <code>T</code>
**Kind**: inner method of [<code>imagefs</code>](#module_imagefs)  
**Summary**: Allow a provided function to explore the contents of the
first found partition of an image  

| Param | Type | Description |
| --- | --- | --- |
| imagePath | <code>string</code> | pathname of image for search |
| partitionNames | <code>Array.&lt;string&gt;</code> | partitions to find |
| exploreFn | <code>function</code> | function for exploration |


Support
-------

If you're having any problem, please [raise an issue](https://github.com/balena-io-modules/balena-image-fs/issues/new) on GitHub and the Balena.io team will be happy to help.

Tests
-----

Run the test suite by doing:

```sh
$ npm test
```

Contribute
----------

- Issue Tracker: [github.com/balena-io-modules/balena-image-fs/issues](https://github.com/balena-io-modules/balena-image-fs/issues)
- Source Code: [github.com/balena-io-modules/balena-image-fs](https://github.com/balena-io-modules/balena-image-fs)

License
-------

The project is licensed under the Apache 2.0 license.
