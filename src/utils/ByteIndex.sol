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
		bool recursionStart;
		bool ignoreCurrent;
		uint256 stop;
        uint8 bound;
	}

	function lookup(
		Index storage index,
		bytes32 key,
		function(bytes32, uint8) internal view returns (uint8) _search
	) internal returns (bool success, bytes32 found) {
		uint256 shift = (index.depth - 1) / 8;
		Locals memory locals;
		assembly {
			//preserve memory
			found := mload(FOUND_SLOT)
			mstore(FOUND_SLOT, 0x0)
		}
		for (uint256 i = 0; i < shift; i += 8) {
			bytes32 partialKey;
			assembly {
				let _found := mload(found_slot)
				partialKey := or(_found, shl(0xff, sub(shift, i)))
			}
			bytes32 mask = index.mask[partialKey];
			uint8 nextByte = uint8(key[i / 8]);
			/*
			 * exit conditions
			 * 1. if not recursing and mask returns a 0x0
			 * 2. if recursion has started and reached the stop
			 * 3. next byte is 0 and current search is ignored and mask isn't a top bit mask
			 */
			if (
				(!locals.recursing && mask == 0) ||
				(locals.recursionStart && locals.stop == i) ||
				(locals.ignoreCurrent && locals.nextByte == 0 && (mask & TOP == 0))
			) {
				assembly {
					mstore(FOUND_SLOT, found)
				}
				return (false, bytes32(0x0));
			}
			if (locals.recursing) {
				nextByte++;
				locals.recursing = false;
			}
            if(mask != TOP) {
                if()
            }
			uint8 result = _search(mask, nextByte);
			_append(shift + i, result);
		}
		assembly {
			//rewrite to memory
			let _found := mload(FOUND_SLOT)
			mstore(FOUND_SLOT, found)
			found := _found
		}
	}
}
