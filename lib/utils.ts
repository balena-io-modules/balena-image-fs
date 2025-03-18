import type { FileDisk } from 'file-disk';
import type {
	GetPartitionsResult,
	GPTPartition,
	MBRPartition,
} from 'partitioninfo';
import { getFsLabel, LabelNotFound } from './fsLabel';

/**
 * Summarizes the partition found by findPartition().
 */
export type FindPartitionResult = {
	index: number;
	/** partition name for GPT, or filesystem label for MBR */
	name: string;
}

/**
 * @summary Find the partition on the provided disk with a name that matches one
 * of the provided names.
 *
 * Matches on partition name for GPT partitions or on filesystem label for MBR
 * partitions.
 *
 * @returns A FindPartitionResult with the found index and name/label; otherwise
 * undefined
 */
export async function findPartition(
	fileDisk: FileDisk,
	partitionInfo: GetPartitionsResult,
	names: string[],
): Promise<FindPartitionResult|undefined> {
	const { partitions } = partitionInfo;
	const isGPT = (
		partsInfo: GetPartitionsResult,
		_parts: Array<GPTPartition | MBRPartition>,
	): _parts is GPTPartition[] => partsInfo.type === 'gpt';

	if (isGPT(partitionInfo, partitions)) {
		const partition = partitions.find((gptPartInfo: GPTPartition) =>
			names.includes(gptPartInfo.name),
		);
		if (partition && typeof partition.index === 'number') {
			return {
				index: partition.index,
				name: partition.name,
			};
		}
	} else {
		// MBR
		for (const partition of partitions) {
			try {
				const label = await getFsLabel(fileDisk, partition);
				if (names.includes(label) && typeof partition.index === 'number') {
					return {
						index: partition.index,
						name: label,
					};
				}
			} catch (e) {
				// LabelNotFound is expected and not fatal.
				if (!(e instanceof LabelNotFound)) {
					throw e;
				}
			}
		}
	}
}

