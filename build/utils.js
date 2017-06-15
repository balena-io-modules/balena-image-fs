var Promise, assert, chalk, util;

Promise = require('bluebird');

assert = require('assert');

util = require('util');

chalk = require('chalk');

exports.expect = function(input, output) {
  return assert.deepEqual(input, output, chalk.red("Expected " + (util.inspect(input)) + " to equal " + (util.inspect(output))));
};

exports.extract = function(stream) {
  return new Promise(function(resolve, reject) {
    var chunks;
    chunks = [];
    stream.on('error', reject);
    stream.on('data', function(chunk) {
      return chunks.push(chunk);
    });
    return stream.on('end', function() {
      return resolve(chunks.join(''));
    });
  });
};

exports.waitStream = function(stream) {
  return new Promise(function(resolve, reject) {
    stream.on('error', reject);
    return stream.on('close', resolve);
  });
};