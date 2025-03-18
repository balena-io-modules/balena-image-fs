import { deepEqual, notEqual } from 'assert';
import { FileDisk, withOpenFile } from 'file-disk';
import * as Fs from 'fs';
import * as Path from 'path';
import * as tmp from 'tmp';
import * as partitioninfo from 'partitioninfo';

function assertExists(v: unknown): asserts v is NonNullable<typeof v> {
	notEqual(v, undefined);
	notEqual(v, null);
}

import * as imagefs from '../lib';

const RASPBERRYPI = Path.join(__dirname, 'images', 'raspberrypi.img');
const GPT_FAT16 = Path.join(
	__dirname,
	'images',
	'balenaos-minimal-gpt-fat16.img',
);

async function tmpFile(): Promise<{ path: string; cleanup: () => void }> {
	return await new Promise((resolve, reject) => {
		tmp.file(
			{ discardDescriptor: true },
			(error: Error | null, path: string, _fd: number, cleanup: () => void) => {
				if (error != null) {
					reject(error);
				} else {
					resolve({ path, cleanup });
				}
			},
		);
	});
}

async function withFileCopy<T>(
	filePath: string,
	fn: (tmpFilePath: string) => Promise<T>,
): Promise<T> {
	const { path, cleanup } = await tmpFile();
	await Fs.promises.copyFile(filePath, path);
	try {
		return await fn(path);
	} finally {
		cleanup();
	}
}

function testWithFileCopy(
	title: string,
	file: string,
	fn: (fileCopy: string) => Promise<void>,
) {
	it(title, async () => {
		await withFileCopy(file, async (fileCopy: string) => {
			await fn(fileCopy);
		});
	});
}

function testFileDisk(
	title: string,
	image: string,
	fn: (
		disk: FileDisk,
		partitions: partitioninfo.GetPartitionsResult,
	) => Promise<void>,
) {
	testWithFileCopy(`${title} (filedisk)`, image, async (fileCopy: string) => {
		await withOpenFile(fileCopy, 'r+', async (handle) => {
			const disk = new FileDisk(handle);
			const partitions = await partitioninfo.getPartitions(disk, {
				includeExtended: false,
				getLogical: true,
			});
			await fn(disk, partitions);
		});
	});
}

testFileDisk(
	'should find boot partition in MBR with FAT16 (0xB) partition',
	RASPBERRYPI,
	async (disk: FileDisk, partitions: partitioninfo.GetPartitionsResult) => {
		const result = await imagefs.findPartition(disk, partitions, [
			'RESIN-BOOT',
		]);
		assertExists(result);
		deepEqual(result.name, 'RESIN-BOOT');
	},
);

testFileDisk(
	'should find rootA partition in GPT',
	GPT_FAT16,
	async (disk: FileDisk, partitions: partitioninfo.GetPartitionsResult) => {
		const result = await imagefs.findPartition(disk, partitions, [
			'resin-rootA',
		]);
		assertExists(result);
		deepEqual(result.name, 'resin-rootA');
	},
);

testFileDisk(
	'should fail to find "xyz" partition in GPT',
	GPT_FAT16,
	async (disk: FileDisk, partitions: partitioninfo.GetPartitionsResult) => {
		const result = await imagefs.findPartition(disk, partitions, ['xyz']);
		deepEqual(result, undefined);
	},
);
