import { readFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";

// The vocabulary and pre-tokenization pattern are the exact data shipped by
// @anthropic-ai/tokenizer 0.0.4. See TOKENIZER-LICENSE for its MIT license.

class Tokenizer {
	ranks = new Map();
	previous = new Int32Array(256);
	next = new Int32Array(256);
	ends = new Int32Array(256);
	heapRanks = [];
	heapStarts = [];
	heapEnds = [];
	heapSize = 0;

	constructor() {
		const compressed = readFileSync(new URL("./tokenizer-vocabulary.json.gz", import.meta.url)),
			vocabulary = JSON.parse(gunzipSync(compressed).toString("utf8"));

		let rank = 0,
			readRank = false;

		for (const match of vocabulary.bpe_ranks.matchAll(/\S+/g)) {
			if (match[0] === "!") {
				readRank = true;
			} else if (readRank) {
				rank = Number(match[0]);
				readRank = false;
			} else {
				this.ranks.set(Buffer.from(match[0], "base64").toString("latin1"), rank++);
			}
		}

		// Rust's regex uses Unicode White_Space; JavaScript's \s differs for NEL/BOM.
		const pattern = vocabulary.pat_str.replaceAll("\\s", "\\p{White_Space}").replaceAll("\\S", "\\P{White_Space}");

		this.pieces = new RegExp(pattern, "gu");

		const escaped = Object.keys(vocabulary.special_tokens).map((token) => token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));

		this.specials = new RegExp(escaped.join("|"), "g");
	}

	count(text) {
		const normalized = text.normalize("NFKC").toWellFormed();

		let count = 0,
			start = 0;

		this.specials.lastIndex = 0;

		let special;

		while ((special = this.specials.exec(normalized)) !== null) {
			count += this.countOrdinary(normalized.slice(start, special.index)) + 1;
			start = this.specials.lastIndex;
		}

		return count + this.countOrdinary(normalized.slice(start));
	}

	countOrdinary(text) {
		let count = 0;

		this.pieces.lastIndex = 0;

		let match;

		while ((match = this.pieces.exec(text)) !== null) {
			// Latin-1 keys preserve every UTF-8 byte, including incomplete code points.
			const bytes = Buffer.from(match[0], "utf8").toString("latin1");

			count += this.ranks.has(bytes) ? 1 : this.countPiece(bytes);
		}

		return count;
	}

	countPiece(bytes) {
		const length = bytes.length;

		if (length > this.next.length) {
			const capacity = Math.max(length, this.next.length * 2);

			this.previous = new Int32Array(capacity);
			this.next = new Int32Array(capacity);
			this.ends = new Int32Array(capacity);
		}

		// Reuse the linked-list and heap buffers between synchronous counts. A heap
		// avoids quadratic scans for large unbroken tool outputs and identifiers.
		this.heapSize = 0;

		for (let index = 0; index < length; index++) {
			this.previous[index] = index - 1;
			this.next[index] = index + 1 < length ? index + 1 : -1;
			this.ends[index] = index + 1;
		}

		for (let index = 0; index < length - 1; index++) {
			this.enqueue(bytes, index);
		}

		let count = length;

		while (this.heapSize > 0) {
			const start = this.heapStarts[0],
				end = this.heapEnds[0];

			this.pop();

			const right = this.next[start];

			if (right < 0 || this.ends[right] !== end) {
				continue;
			}

			const after = this.next[right];

			this.ends[start] = end;
			this.next[start] = after;
			this.next[right] = -1;

			if (after >= 0) {
				this.previous[after] = start;
			}

			count--;

			if (this.previous[start] >= 0) {
				this.enqueue(bytes, this.previous[start]);
			}

			if (after >= 0) {
				this.enqueue(bytes, start);
			}
		}

		return count;
	}

	enqueue(bytes, start) {
		const end = this.ends[this.next[start]],
			rank = this.ranks.get(bytes.slice(start, end));

		if (rank === undefined) {
			return;
		}

		let index = this.heapSize++;

		while (index > 0) {
			const parent = (index - 1) >>> 1,
				parentRank = this.heapRanks[parent];

			if (parentRank < rank || (parentRank === rank && this.heapStarts[parent] <= start)) {
				break;
			}

			this.copyHeapEntry(parent, index);
			index = parent;
		}

		this.heapRanks[index] = rank;
		this.heapStarts[index] = start;
		this.heapEnds[index] = end;
	}

	pop() {
		const last = --this.heapSize;

		if (last === 0) {
			return;
		}

		const rank = this.heapRanks[last],
			start = this.heapStarts[last],
			end = this.heapEnds[last];

		let index = 0;

		while (index * 2 + 1 < last) {
			let child = index * 2 + 1;

			const right = child + 1;

			if (right < last && this.less(right, child)) {
				child = right;
			}

			const childRank = this.heapRanks[child];

			if (rank < childRank || (rank === childRank && start <= this.heapStarts[child])) {
				break;
			}

			this.copyHeapEntry(child, index);
			index = child;
		}

		this.heapRanks[index] = rank;
		this.heapStarts[index] = start;
		this.heapEnds[index] = end;
	}

	less(left, right) {
		const leftRank = this.heapRanks[left],
			rightRank = this.heapRanks[right];

		return leftRank < rightRank || (leftRank === rightRank && this.heapStarts[left] < this.heapStarts[right]);
	}

	copyHeapEntry(source, target) {
		this.heapRanks[target] = this.heapRanks[source];
		this.heapStarts[target] = this.heapStarts[source];
		this.heapEnds[target] = this.heapEnds[source];
	}
}

let tokenizer;

export function countTokens(text) {
	tokenizer ??= new Tokenizer();

	return tokenizer.count(text);
}
