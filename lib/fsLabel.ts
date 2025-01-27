import { Disk } from 'file-disk';
import { GPTPartition, MBRPartition } from 'partitioninfo';
import { TypedError } from 'typed-error';

// GPT partition GUIDs
// https://en.wikipedia.org/wiki/GUID_Partition_Table#Partition_type_GUIDs
const GUID_EFI_SYSTEM = 'C12A7328-F81F-11D2-BA4B-00A0C93EC93B';
const GUID_MS_BASIC_DATA = 'EBD0A0A2-B9E5-4433-87C0-68B6B72699C7';
const GUID_LINUX_NATIVE = '0FC63DAF-8483-4772-8E79-3D69D8477DE4';

// Maximum length to read among various filesystem metadata. Change as needed
// to support additional filesystems.
const FS_METADATA_MAXLEN = 0x100;
// MBR partition type IDs
// https://en.wikipedia.org/wiki/Partition_type
const PARTID_FAT32_CHS = 0xB;
const PARTID_FAT32_LBA = 0xC;
const PARTID_FAT16_LBA = 0xE;
const PARTID_LINUX_NATIVE = 0x83;
// FAT constants
// https://en.wikipedia.org/wiki/Design_of_the_FAT_file_system#Extended_BIOS_Parameter_Block
// https://en.wikipedia.org/wiki/Design_of_the_FAT_file_system#FAT32_Extended_BIOS_Parameter_Block
const FAT_LABEL_MAXLEN = 11;
const FAT_MAGIC_VALUE = 0x29;
const FAT16_MAGIC_OFFSET = 0x26;
const FAT16_LABEL_OFFSET = 0x2B;
const FAT32_MAGIC_OFFSET = 0x42;
const FAT32_LABEL_OFFSET = 0x47;
// EXT4 constants
// https://www.kernel.org/doc/html/latest/filesystems/ext4/index.html
const EXT4_SUPERBLOCK_OFFSET = 0x400;
const EXT4_MAGIC_OFFSET = 0x38;
const EXT4_MAGIC_VALUE_LE = 0xEF53;
const EXT4_LABEL_OFFSET = 0x78;
const EXT4_LABEL_MAXLEN = 16;

/**
 * @summary An error to describe why getFsLabel() failed to find a filesystem label.
 */
export class LabelNotFound extends TypedError {
	constructor(partitionIndex: number, description: string) {
		super(`Label not found: ${partitionIndex}; ${description}`);
	}
}

/**
 * @summary Returns the label encoded in the filesystem for a given partition,
 * or throws LabelNotFound if can't determine label location.
 *
 * This function focuses on balenaOS devices and does not attempt to read the
 * many possible filesystem types.
 *
 * @example
 *
 * await filedisk.withOpenFile('/foo/bar.img', 'r', async (handle) => {
 *     const disk = new filedisk.FileDisk(handle);
 *     const info = partitioninfo.getPartitions(disk);
 *     for (const partition of info.partitions) {
 *         const label = await getFsLabel(disk, partition);
 *         console.log(`${partition.index}: ${label}`);
 *     }
 * }
 */
export async function getFsLabel(
	disk: Disk,
	partition: GPTPartition | MBRPartition,
): Promise<string> {
	const isGpt = 'guid' in partition;
	const isMbr = !isGpt

	// Use a buffer capable of reading any filesystem metadata. Defer actual
	// read until select filesystem.
	const buf = Buffer.alloc(FS_METADATA_MAXLEN);

	let labelOffset: number | undefined;
	let maxLength: number | undefined;
	// A filesystem places the label in a certain position in its metadata. So
	// we must determine the type of filesystem. We first narrow the possibilities
	// by checking the partition type (MBR) or GUID (GPT) for the containing partition.
	// There are two broad categories of filesystem -- FAT types and Linux native
	// types. Finally we confirm the presence of signature bytes within the filesystem
	// metadata.
	// FAT types
	const mbrFatTypes = [PARTID_FAT32_CHS, PARTID_FAT32_LBA, PARTID_FAT16_LBA];
	const gptFatTypes = [GUID_EFI_SYSTEM, GUID_MS_BASIC_DATA];
	if (isMbr && mbrFatTypes.includes(partition.type)
		|| isGpt && gptFatTypes.includes(partition.type)
	) {
		maxLength = FAT_LABEL_MAXLEN;
		await disk.read(buf, 0, buf.length, partition.offset);
		// FAT16
		if (buf.readUInt8(FAT16_MAGIC_OFFSET) === FAT_MAGIC_VALUE) {
			labelOffset = FAT16_LABEL_OFFSET;
		// FAT32
		} else if (buf.readUInt8(FAT32_MAGIC_OFFSET) === FAT_MAGIC_VALUE) {
			labelOffset = FAT32_LABEL_OFFSET;
		}
	}

	// Linux filesytem of some kind; expecting ext2+
	const gptLinuxTypes = [GUID_LINUX_NATIVE, GUID_MS_BASIC_DATA];
	if (labelOffset == null && (
			(isMbr && partition.type === PARTID_LINUX_NATIVE)
			|| (isGpt && gptLinuxTypes.includes(partition.type))
		)
	) {
		maxLength = EXT4_LABEL_MAXLEN;
		// ext2+; reload buffer within superblock
		await disk.read(buf, 0, buf.length, partition.offset + EXT4_SUPERBLOCK_OFFSET);
		if (buf.readUInt16LE(EXT4_MAGIC_OFFSET) === EXT4_MAGIC_VALUE_LE) {
			labelOffset = EXT4_LABEL_OFFSET;
		}
	}

	// Fail on unexpected partition/filesystem
	// If max length for a label not defined, then implicitly we have not even
	// found a partition type.
	if (maxLength == null) {
		throw new LabelNotFound(partition.index, 'unexpected partition type');
	}
	if (labelOffset == null) {
		throw new LabelNotFound(partition.index, 'can\'t read filesystem');
	}

	// Exclude trailing /0 bytes to stringify.
	let zeroBytePosition: number | undefined;
	for (let i = 0; i < maxLength; i++) {
		if (buf.readUInt8(labelOffset + i) === 0) {
			zeroBytePosition = i;
			break;
		}
	}
	// Didn't find a /0 byte; must be max length.
	zeroBytePosition ??= maxLength;

	return buf.toString('utf8', labelOffset, labelOffset + zeroBytePosition).trim();
}
