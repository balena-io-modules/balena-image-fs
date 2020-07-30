import * as Bluebird from 'bluebird';
import { FileDisk, withOpenFile } from 'file-disk';
import * as fs from 'fs';
import * as path from 'path';
import * as wary from 'wary';
import * as assert from 'assert';
import * as util from 'util';
import * as chalk from 'chalk';

import * as imagefs from '../lib';
import * as FILES from './images/files.json';

const RASPBERRYPI = path.join(__dirname, 'images', 'raspberrypi.img');
const EDISON = path.join(__dirname, 'images', 'edison-config.img');
const RAW_EXT2 = path.join(__dirname, 'images', 'ext2.img');
const LOREM = path.join(__dirname, 'images', 'lorem.txt');
const LOREM_CONTENT = fs.readFileSync(LOREM, 'utf8');
const GPT = path.join(__dirname, 'images', 'gpt.img');
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

async function waitStream(stream: NodeJS.ReadableStream): Promise<void> {
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

function expect(input: any, output: any) {
	assert.deepEqual(
		input,
		output,
		chalk.red(
			`Expected ${util.inspect(input)} to equal ${util.inspect(output)}`,
		),
	);
}

function testFilename<T>(
	title: string,
	fn: (fs: any) => Promise<T>,
	image: { image: string; partition?: number },
) {
	wary.it(
		title,
		{ file: image.image },
		async (tmpFilenames: { [filename: string]: string }) => {
			await imagefs.interact(
				tmpFilenames.file,
				image.partition,
				async ($fs: any) => {
					await fn(Bluebird.promisifyAll($fs));
				},
			);
		},
	);
}

function testFileDisk<T>(
	title: string,
	fn: (fs: any) => Promise<T>,
	image: { image: string; partition?: number },
) {
	wary.it(
		`${title} (filedisk)`,
		{ file: image.image },
		async (tmpFilenames: { [filename: string]: string }) => {
			await withOpenFile(tmpFilenames.file, 'r+', async (handle) => {
				const disk = new FileDisk(handle);
				await imagefs.interact(disk, image.partition, async ($fs: any) => {
					await fn(Bluebird.promisifyAll($fs));
				});
			});
		},
	);
}

async function testBoth<T>(
	title: string,
	fn: (fs: any) => Promise<T>,
	image: { image: string; partition?: number },
) {
	await Promise.all([
		testFilename(title, fn, image),
		testFileDisk(title, fn, image),
	]);
}

wary.it(
	'should throw an error when the partition number is 0',
	{ file: RASPBERRYPI },
	async (tmpFilenames: { [filename: string]: string }) => {
		try {
			await imagefs.interact(tmpFilenames.file, 0, async (_fs: any) => {
				// noop
			});
			// this should not work
			expect(false, true);
		} catch (e) {
			expect(e.message, 'The partition number must be at least 1.');
		}
	},
);

testBoth(
	'should list files from a fat partition in a raspberrypi image',
	async ($fs: any) => {
		const contents = await $fs.readdirAsync('/overlays');
		expect(contents, [
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
		]);
	},
	{
		image: RASPBERRYPI,
		partition: 1,
	},
);

testBoth(
	'should list files from an ext4 partition in a raspberrypi image',
	async ($fs: any) => {
		const contents = await $fs.readdirAsync('/');
		expect(contents, ['lost+found', '1']);
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
		expect(
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
	async ($fs: any) => {
		const contents = await $fs.readFileAsync('/config.json');
		expect(JSON.parse(contents), FILES.raspberrypi['config.json']);
	},
	{
		image: RASPBERRYPI,
		partition: 5,
	},
);

testBoth(
	'should fail cleanly trying to read a missing file on a raspberrypi',
	async ($fs: any) => {
		try {
			const stream = $fs.createReadStream('/non-existent-file.txt');
			await extract(stream);
			throw new Error(
				'Should not successfully return contents for a missing file!',
			);
		} catch (e) {
			expect(e.code, 'NOENT');
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
		const inputStream = fs.createReadStream(LOREM);
		const outputStream = $fs.createWriteStream(output);
		inputStream.pipe(outputStream);
		await waitStream(outputStream);
		const contents = await $fs.readFileAsync(output, { encoding: 'utf8' });
		expect(contents, LOREM_CONTENT);
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
		const inputStream = fs.createReadStream(LOREM);
		const outputStream = $fs.createWriteStream(output);
		inputStream.pipe(outputStream);
		await waitStream(outputStream);
		const contents = await $fs.readFileAsync(output, { encoding: 'utf8' });
		expect(contents, LOREM_CONTENT);
	},
	{
		image: RASPBERRYPI,
		partition: 6,
	},
);

testBoth(
	'should copy text to a raspberry pi partition using writeFile',
	async ($fs) => {
		const output = '/lorem.txt';
		await $fs.writeFileAsync(output, LOREM_CONTENT);
		const contents = await $fs.readFileAsync(output, { encoding: 'utf8' });
		expect(contents, LOREM_CONTENT);
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
		const inputStream = fs.createReadStream(LOREM);
		const outputStream = $fs.createWriteStream(output);
		inputStream.pipe(outputStream);
		await waitStream(outputStream);
		const contents = await $fs.readFileAsync(output, { encoding: 'utf8' });
		expect(contents, LOREM_CONTENT);
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
		expect(JSON.parse(contents.toString('utf8')), FILES.edison['config.json']);
	},
	{
		image: EDISON,
	},
);

testBoth(
	'should return a node fs like interface for fat partitions',
	async ($fs) => {
		const files = await $fs.readdirAsync('/');
		expect(files, RASPBERRY_FIRST_PARTITION_FILES);
	},
	{
		image: RASPBERRYPI,
		partition: 1,
	},
);

testBoth(
	'should return a node fs like interface for ext partitions',
	async ($fs) => {
		const files = await $fs.readdirAsync('/');
		expect(files, ['lost+found', '1']);
	},
	{
		image: RASPBERRYPI,
		partition: 6,
	},
);

testBoth(
	'should return a node fs like interface for raw ext partitions',
	async ($fs) => {
		const files = await $fs.readdirAsync('/');
		expect(files, ['lost+found', '1']);
	},
	{
		image: RAW_EXT2,
	},
);

testBoth(
	'should return a node fs like interface for raw fat partitions',
	async ($fs) => {
		const files = await $fs.readdirAsync('/');
		expect(files, ['config.json']);
	},
	{
		image: EDISON,
	},
);

testBoth(
	'should return a node fs like interface for fat partitions held in gpt typed images',
	async ($fs) => {
		const files = await $fs.readdirAsync('/');
		expect(files, ['fat.file']);
	},
	{
		image: GPT,
		partition: 1,
	},
);

testBoth(
	'should return a node fs like interface for ext partitions held in gpt typed images',
	async ($fs) => {
		const files = await $fs.readdirAsync('/');
		expect(files, ['lost+found', 'ext4.file']);
	},
	{
		image: GPT,
		partition: 2,
	},
);

async function main() {
	try {
		await wary.run();
	} catch (error) {
		console.error(error, error.stack);
		process.exitCode = 1;
	}
}

main();
