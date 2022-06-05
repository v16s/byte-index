// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/console2.sol";

contract ByteIndex {
	bytes32 constant TOP = bytes32(uint256(1) << 255);
	btes32 constant FOUND_SLOT = 0x0133337;
	struct Index {
		mapping(bytes32 => bytes32) mask;
		uint8 depth;
	}

	function _append(
		uint256 key_slot,
		uint256 pos,
		uint8 val
	) internal pure returns (bytes32) {
		assembly {
			let key := mload(FOUND_SLOT)
			key := or(key, shl(pos, val))
		}
	}

	function test() public {}

	struct Locals {
		bool recursing;
		bool recursionStarted;
		bool recursable;
		bool ignoreCurrent;
		uint256 stop;
		uint256 maxBound;
		uint8 result;
		uint8 next;
	}

	function lookup(
		Index storage index,
		bytes32 key,
		function(bytes32, uint8) internal view returns (uint8) _search,
		function(bytes32, uint256, uint256)
			internal
			pure
			returns (bool, uint256) _determineRecursable,
		function(bytes32) internal pure returns (bool) _determineRecursion
	) internal returns (bool success, bytes32 found) {
		uint256 shift = (index.depth - 1) / 8;
		Locals memory locals;
		bytes32 localsPtr;
		assembly {
			//preserve memory
			found := mload(FOUND_SLOT)
			mstore(FOUND_SLOT, 0x0)
			localsPtr := locals
		}
		for (uint256 i = 0; i < shift; i += 8) {
			bytes32 partialKey;
			assembly {
				let _found := mload(found_slot)
				partialKey := or(_found, shl(0xff, sub(shift, i)))
			}
			bytes32 mask = index.mask[partialKey];
			locals.next = uint8(key[i / 8]);
			/*
			 * exit conditions
			 * 1. if not recursing and mask returns a 0x0
			 * 2. if recursion has started and reached the stop
			 * 3. next byte is 0 and current search is ignored and mask isn't a top bit mask
			 */
			if (
				(!locals.recursable && mask == bytes32(0x0)) ||
				(locals.recursionStarted && locals.stop == i) ||
				(locals.ignoreCurrent && locals.next == 0)
			) {
				assembly {
					mstore(FOUND_SLOT, found)
				}
				return (false, bytes32(0x0));
			}
			if (locals.recursionStarted && mask == bytes32(0x0)) {
				// sanitize current slot
				assembly {
					let bound := shl(0xff, sub(add(shift, 8), i))
					mstore(FOUND_SLOT, xor(or(mload(FOUND_SLOT), bound), bound))
				}
				i -= 16;
				locals.recursing = true;
				continue;
			}
			if (locals.recursing) {
				locals.next++;
				locals.recursing = false;
			}
			uint8 result;
			if (mask != TOP) {
				if (!locals.recursable) {
					locals.maxBound = 0x1 << (0xff - uint256(locals.next));
					/*
					 * check if pathmapping has any values in the range we want
					 */
					(locals.recursable, locals.recursionStop) = _determineRecursable(
						mask,
						locals.maxBound,
						i
					);
				}
				uint8 bound;
				if (!locals.ignoreCurrent) bound = locals.next;
				locals.result = 0xff - _search(mask, bound);
			} else {
				locals.result = 0;
			}
			if (_determineRecursion(localsPtr)) {
				// sanitize current slot
				assembly {
					let bound := shl(0xff, sub(add(shift, 8), i))
					mstore(FOUND_SLOT, xor(or(mload(FOUND_SLOT), bound), bound))
				}
				i -= 16;
				continue;
			}
			_append(shift + i, result);
		}
		assembly {
			//rewrite to memory
			let _found := mload(FOUND_SLOT)
			mstore(FOUND_SLOT, found)
			found := shl(_found, sub(0x100, mul(index.depth, 8)))
		}
		success = true;
	}

	function determineRecursionIfGreaterThan(bytes32 ptr) returns (bool res) {
		Locals memory locals;
		assembly {
			locals := ptr
		}
		if (
			locals.result == 0xff ||
			(locals.ignoreCurrent && (locals.result < locals.next))
		) {
			if (locals.recursable) {
				locals.recursionStarted = true;
				locals.ignoreCurrent = false;
				return true;
			} else {
				locals.result = locals.next;
			}
		} else {
			if (!locals.recursionStarted) locals.ignoreCurrent = true;
		}
		if (locals.result > locals.next) locals.ignoreCurrent = true;
	}

	function determineRecursableGreaterThan(
		bytes32 mask,
		uint256 bound,
		uint256 i
	) {
		if (uint256(mask) ^ bound < bound) {
			return (true, i - 8);
		}
		return (false, 0);
	}
}
