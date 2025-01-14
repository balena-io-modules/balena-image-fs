import { deepEqual } from 'assert';
import { FileDisk, withOpenFile } from 'file-disk';
import * as Fs from 'fs';
import * as Path from 'path';
import * as tmp from 'tmp';
import * as partitioninfo from 'partitioninfo';

import * as imagefs from '../lib';

const RASPBERRYPI = Path.join(__dirname, 'images', 'raspberrypi.img');
// GPT partition table that claims it has two Linux native filesystem partitions,
// with the first at offset 0x100000. However, there is no data at offset
// 0x100400, where we expect to find the ext4 superblock.
// Instead it has a fat32 filesystem at offset 0x100C00.
const GPT = Path.join(__dirname, 'images', 'gpt.img');
const MBR_FAT32 = Path.join(
	__dirname,
	'images',
	'balenaos-minimal-mbr-fat32.img',
);
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
	image: { image: string; partition: number },
	fn: (
		disk: FileDisk,
		partition: partitioninfo.GPTPartition | partitioninfo.MBRPartition,
	) => Promise<void>,
) {
	testWithFileCopy(
		`${title} (filedisk)`,
		image.image,
		async (fileCopy: string) => {
			await withOpenFile(fileCopy, 'r+', async (handle) => {
				const disk = new FileDisk(handle);
				const partition = await partitioninfo.get(disk, image.partition);
				await fn(disk, partition);
			});
		},
	);
}

testFileDisk(
	'should find label in MBR with FAT16 (0xB) partition',
	{
		image: RASPBERRYPI,
		partition: 1,
	},
	async (
		disk: FileDisk,
		partition: partitioninfo.GPTPartition | partitioninfo.MBRPartition,
	) => {
		const label = await imagefs.getFsLabel(disk, partition);
		deepEqual(label, 'RESIN-BOOT');
	},
);

testFileDisk(
	'should find label in MBR with FAT32 (0xC) partition',
	{
		image: MBR_FAT32,
		partition: 1,
	},
	async (
		disk: FileDisk,
		partition: partitioninfo.GPTPartition | partitioninfo.MBRPartition,
	) => {
		const label = await imagefs.getFsLabel(disk, partition);
		deepEqual(label, 'resin-boot');
	},
);

testFileDisk(
	'should find label in MBR with ext4 (0x83) partition',
	{
		image: MBR_FAT32,
		partition: 6,
	},
	async (
		disk: FileDisk,
		partition: partitioninfo.GPTPartition | partitioninfo.MBRPartition,
	) => {
		const label = await imagefs.getFsLabel(disk, partition);
		deepEqual(label, 'resin-data');
	},
);

testFileDisk(
	'should find label in MBR with max label length',
	{
		image: MBR_FAT32,
		partition: 2,
	},
	async (
		disk: FileDisk,
		partition: partitioninfo.GPTPartition | partitioninfo.MBRPartition,
	) => {
		const label = await imagefs.getFsLabel(disk, partition);
		// 11 chars
		deepEqual(label, 'resin-rootA');
	},
);

testFileDisk(
	'should find label in GPT with FAT16 boot partition',
	{
		image: GPT_FAT16,
		partition: 1,
	},
	async (
		disk: FileDisk,
		partition: partitioninfo.GPTPartition | partitioninfo.MBRPartition,
	) => {
		const label = await imagefs.getFsLabel(disk, partition);
		deepEqual(label, 'resin-boot');
	},
);

testFileDisk(
	'should find label in GPT with ext4 partition',
	{
		image: GPT_FAT16,
		partition: 5,
	},
	async (
		disk: FileDisk,
		partition: partitioninfo.GPTPartition | partitioninfo.MBRPartition,
	) => {
		const label = await imagefs.getFsLabel(disk, partition);
		deepEqual(label, 'resin-data');
	},
);

// See description above for this image. It does not have the expected ext4
// filesystem in partition 1, so the magic bytes are missing within the superblock
// offset.
testFileDisk(
	'should fail to find label in GPT with ext4 partition but missing filesystem data',
	{
		image: GPT,
		partition: 1,
	},
	async (
		disk: FileDisk,
		partition: partitioninfo.GPTPartition | partitioninfo.MBRPartition,
	) => {
		try {
			// throws LabelNotFound
			const label = await imagefs.getFsLabel(disk, partition);
			// never called
			deepEqual(label, 'never-called');
		} catch (e) {
			if (e instanceof String) {
				deepEqual(
					e.split('\n')[0],
					"LabelNotFound: Label not found: 1; can't read filesystem",
				);
			}
		}
	},
);
