import { deepEqual } from 'assert';
import { FileDisk, withOpenFile } from 'file-disk';
import * as Fs from 'fs';
import { promisify } from 'util';
import * as Path from 'path';
import * as tmp from 'tmp';

import * as imagefs from '../lib';
import * as FILES from './images/files.json';

const RASPBERRYPI = Path.join(__dirname, 'images', 'raspberrypi.img');
const EDISON = Path.join(__dirname, 'images', 'edison-config.img');
const RAW_EXT2 = Path.join(__dirname, 'images', 'ext2.img');
const LOREM = Path.join(__dirname, 'images', 'lorem.txt');
const LOREM_CONTENT = Fs.readFileSync(LOREM, 'utf8');
const GPT = Path.join(__dirname, 'images', 'gpt.img');
const RASPBERRY_FIRST_PARTITION_FILES = [
	'.Trashes',
	'._.Trashes',
	'._bcm2708-rpi-b-plus.dtb',
	'._bcm2708-rpi-b.dtb',
	'._bcm2709-rpi-2-b.dtb',
	'._bcm2835-bootfiles-20150206.stamp',
	'._bootcode.bin',
	'._cmdline.txt',
	'._config.txt',
	'._fixup.dat',
	'._fixup_cd.dat',
	'._fixup_x.dat',
	'._image-version-info',
	'._kernel7.img',
	'._overlays',
	'._start.elf',
	'._start_cd.elf',
	'._start_x.elf',
	'BOOTCODE.BIN',
	'CMDLINE.TXT',
	'CONFIG.TXT',
	'FIXUP.DAT',
	'FIXUP_CD.DAT',
	'FIXUP_X.DAT',
	'KERNEL7.IMG',
	'OVERLAYS',
	'START.ELF',
	'START_CD.ELF',
	'START_X.ELF',
	'bcm2708-rpi-b-plus.dtb',
	'bcm2708-rpi-b.dtb',
	'bcm2709-rpi-2-b.dtb',
	'bcm2835-bootfiles-20150206.stamp',
	'image-version-info',
];

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

async function waitStream(
	stream: NodeJS.ReadableStream | NodeJS.WritableStream,
): Promise<void> {
	await new Promise((resolve, reject) => {
		stream.on('error', reject);
		stream.on('close', resolve);
	});
}

async function extract(stream: NodeJS.ReadableStream): Promise<Buffer> {
	const chunks: Buffer[] = [];
	await new Promise(function (resolve, reject) {
		stream.on('error', reject);
		stream.on('end', resolve);
		stream.on('data', (chunk: Buffer) => {
			chunks.push(chunk);
		});
	});
	return Buffer.concat(chunks);
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
function testFilename<T>(
	title: string,
	fn: (fs: typeof Fs) => Promise<T>,
	image: { image: string; partition?: number },
) {
	testWithFileCopy(title, image.image, async (fileCopy: string) => {
		await imagefs.interact(
			fileCopy,
			image.partition,
			async ($fs: typeof Fs) => {
				await fn($fs);
			},
		);
	});
}

function testFileDisk<T>(
	title: string,
	fn: (fs: typeof Fs) => Promise<T>,
	image: { image: string; partition?: number },
) {
	testWithFileCopy(
		`${title} (filedisk)`,
		image.image,
		async (fileCopy: string) => {
			await withOpenFile(fileCopy, 'r+', async (handle) => {
				const disk = new FileDisk(handle);
				await imagefs.interact(
					disk,
					image.partition,
					async ($fs: typeof Fs) => {
						await fn($fs);
					},
				);
			});
		},
	);
}

function testBoth<T>(
	title: string,
	fn:
		| ((fs: typeof Fs) => Promise<T>)
		| {
				callback: (fs: typeof Fs) => Promise<T>;
				promises: (fs: typeof Fs) => Promise<T>;
		  },
	image: { image: string; partition?: number },
) {
	const variants =
		typeof fn === 'function' ? [['', fn] as const] : Object.entries(fn);
	for (const [titlePart, $fn] of variants) {
		const titleWithVariant =
			titlePart !== '' ? `${title} [${titlePart}]` : title;
		testFilename(titleWithVariant, $fn, image);
		testFileDisk(titleWithVariant, $fn, image);
	}
}

testWithFileCopy(
	'should throw an error when the partition number is 0',
	RASPBERRYPI,
	async (fileCopy: string) => {
		try {
			await imagefs.interact(fileCopy, 0, async (_fs: typeof Fs) => {
				// noop
			});
			// this should not work
			deepEqual(false, true);
		} catch (e: any) {
			deepEqual(e.message, 'The partition number must be at least 1.');
		}
	},
);

const overlaysContents = [
	'._ds1307-rtc-overlay.dtb',
	'._hifiberry-amp-overlay.dtb',
	'._hifiberry-dac-overlay.dtb',
	'._hifiberry-dacplus-overlay.dtb',
	'._hifiberry-digi-overlay.dtb',
	'._iqaudio-dac-overlay.dtb',
	'._iqaudio-dacplus-overlay.dtb',
	'._lirc-rpi-overlay.dtb',
	'._pcf8523-rtc-overlay.dtb',
	'._pps-gpio-overlay.dtb',
	'._w1-gpio-overlay.dtb',
	'._w1-gpio-pullup-overlay.dtb',
	'ds1307-rtc-overlay.dtb',
	'hifiberry-amp-overlay.dtb',
	'hifiberry-dac-overlay.dtb',
	'hifiberry-dacplus-overlay.dtb',
	'hifiberry-digi-overlay.dtb',
	'iqaudio-dac-overlay.dtb',
	'iqaudio-dacplus-overlay.dtb',
	'lirc-rpi-overlay.dtb',
	'pcf8523-rtc-overlay.dtb',
	'pps-gpio-overlay.dtb',
	'w1-gpio-overlay.dtb',
	'w1-gpio-pullup-overlay.dtb',
];

testBoth(
	'should list files from a fat partition in a raspberrypi image',
	{
		callback: async ($fs) => {
			const contents = await promisify($fs.readdir)('/overlays');
			deepEqual(contents, overlaysContents);
		},
		promises: async ($fs) => {
			const contents = await $fs.promises.readdir('/overlays');
			deepEqual(contents, overlaysContents);
		},
	},
	{
		image: RASPBERRYPI,
		partition: 1,
	},
);

testBoth(
	'should list files from an ext4 partition in a raspberrypi image',
	{
		callback: async ($fs) => {
			const contents = await promisify($fs.readdir)('/');
			deepEqual(contents, ['lost+found', '1']);
		},
		promises: async ($fs) => {
			const contents = await $fs.promises.readdir('/');
			deepEqual(contents, ['lost+found', '1']);
		},
	},
	{
		image: RASPBERRYPI,
		partition: 6,
	},
);

testBoth(
	'should read a config.json from a raspberrypi',
	async ($fs) => {
		const stream = $fs.createReadStream('/config.json');
		const contents = await extract(stream);
		deepEqual(
			JSON.parse(contents.toString('utf8')),
			FILES.raspberrypi['config.json'],
		);
	},
	{
		image: RASPBERRYPI,
		partition: 5,
	},
);

testBoth(
	'should read a config.json from a raspberrypi using readFile',
	{
		callback: async ($fs) => {
			const contents = await promisify($fs.readFile)('/config.json');
			// @ts-expect-error
			deepEqual(JSON.parse(contents), FILES.raspberrypi['config.json']);
		},
		promises: async ($fs) => {
			const contents = await $fs.promises.readFile('/config.json');
			// @ts-expect-error
			deepEqual(JSON.parse(contents), FILES.raspberrypi['config.json']);
		},
	},
	{
		image: RASPBERRYPI,
		partition: 5,
	},
);

testBoth(
	'should fail cleanly trying to read a missing file on a raspberrypi',
	async ($fs) => {
		try {
			const stream = $fs.createReadStream('/non-existent-file.txt');
			await extract(stream);
			throw new Error(
				'Should not successfully return contents for a missing file!',
			);
		} catch (e: any) {
			deepEqual(e.code, 'NOENT');
		}
	},
	{
		image: RASPBERRYPI,
		partition: 5,
	},
);

testBoth(
	'should copy a local file to a raspberry pi fat partition',
	async ($fs) => {
		const output = '/cmdline.txt';
		const inputStream = Fs.createReadStream(LOREM);
		const outputStream = $fs.createWriteStream(output);
		inputStream.pipe(outputStream);
		await waitStream(outputStream);
		const contents = await promisify($fs.readFile)(output, {
			encoding: 'utf8',
		});
		deepEqual(contents, LOREM_CONTENT);
	},
	{
		image: RASPBERRYPI,
		partition: 5,
	},
);

testBoth(
	'should copy a local file to a raspberry pi ext partition',
	async ($fs) => {
		const output = '/cmdline.txt';
		const inputStream = Fs.createReadStream(LOREM);
		const outputStream = $fs.createWriteStream(output);
		inputStream.pipe(outputStream);
		await waitStream(outputStream);
		const contents = await promisify($fs.readFile)(output, {
			encoding: 'utf8',
		});
		deepEqual(contents, LOREM_CONTENT);
	},
	{
		image: RASPBERRYPI,
		partition: 6,
	},
);

testBoth(
	'should copy text to a raspberry pi partition using writeFile',
	{
		callback: async ($fs) => {
			const output = '/lorem.txt';
			await promisify($fs.writeFile)(output, LOREM_CONTENT);
			const contents = await promisify($fs.readFile)(output, {
				encoding: 'utf8',
			});
			deepEqual(contents, LOREM_CONTENT);
		},
		promises: async ($fs) => {
			const output = '/lorem.txt';
			await $fs.promises.writeFile(output, LOREM_CONTENT);
			const contents = await $fs.promises.readFile(output, {
				encoding: 'utf8',
			});
			deepEqual(contents, LOREM_CONTENT);
		},
	},
	{
		image: RASPBERRYPI,
		partition: 5,
	},
);

testBoth(
	'should copy a local file to an edison config partition',
	async ($fs) => {
		const output = '/lorem.txt';
		const inputStream = Fs.createReadStream(LOREM);
		const outputStream = $fs.createWriteStream(output);
		inputStream.pipe(outputStream);
		await waitStream(outputStream);
		const contents = await promisify($fs.readFile)(output, {
			encoding: 'utf8',
		});
		deepEqual(contents, LOREM_CONTENT);
	},
	{
		image: EDISON,
	},
);

testBoth(
	'should read a config.json from a edison config partition',
	async ($fs) => {
		const stream = $fs.createReadStream('/config.json');
		const contents = await extract(stream);
		deepEqual(
			JSON.parse(contents.toString('utf8')),
			FILES.edison['config.json'],
		);
	},
	{
		image: EDISON,
	},
);

testBoth(
	'should return a node fs like interface for fat partitions',
	{
		callback: async ($fs) => {
			const files = await promisify($fs.readdir)('/');
			deepEqual(files, RASPBERRY_FIRST_PARTITION_FILES);
		},
		promises: async ($fs) => {
			const files = await $fs.promises.readdir('/');
			deepEqual(files, RASPBERRY_FIRST_PARTITION_FILES);
		},
	},
	{
		image: RASPBERRYPI,
		partition: 1,
	},
);

testBoth(
	'should return a node fs like interface for ext partitions',
	{
		callback: async ($fs) => {
			const files = await promisify($fs.readdir)('/');
			deepEqual(files, ['lost+found', '1']);
		},
		promises: async ($fs) => {
			const files = await $fs.promises.readdir('/');
			deepEqual(files, ['lost+found', '1']);
		},
	},
	{
		image: RASPBERRYPI,
		partition: 6,
	},
);

testBoth(
	'should return a node fs like interface for raw ext partitions',
	{
		callback: async ($fs) => {
			const files = await promisify($fs.readdir)('/');
			deepEqual(files, ['lost+found', '1']);
		},
		promises: async ($fs) => {
			const files = await $fs.promises.readdir('/');
			deepEqual(files, ['lost+found', '1']);
		},
	},
	{
		image: RAW_EXT2,
	},
);

testBoth(
	'should return a node fs like interface for raw ext partitions',
	{
		callback: async ($fs) => {
			const files = await promisify($fs.readdir)('/');
			deepEqual(files, ['lost+found', '1']);
		},
		promises: async ($fs) => {
			const files = await $fs.promises.readdir('/');
			deepEqual(files, ['lost+found', '1']);
		},
	},
	{
		image: RAW_EXT2,
	},
);

testBoth(
	'should return a node fs like interface for fat partitions held in gpt typed images',
	{
		callback: async ($fs) => {
			const files = await promisify($fs.readdir)('/');
			deepEqual(files, ['fat.file']);
		},
		promises: async ($fs) => {
			const files = await $fs.promises.readdir('/');
			deepEqual(files, ['fat.file']);
		},
	},
	{
		image: GPT,
		partition: 1,
	},
);

testBoth(
	'should return a node fs like interface for ext partitions held in gpt typed images',
	{
		callback: async ($fs) => {
			const files = await promisify($fs.readdir)('/');
			deepEqual(files, ['lost+found', 'ext4.file']);
		},
		promises: async ($fs) => {
			const files = await $fs.promises.readdir('/');
			deepEqual(files, ['lost+found', 'ext4.file']);
		},
	},
	{
		image: GPT,
		partition: 2,
	},
);
