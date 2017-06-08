// Copyright © 2012-2017, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/licence.volt (BOOST ver 1.0).
module diode.ir.sink;

import diode.ir.node;


/*!
 * Used as a sink for functions that return multiple nodes.
 */
struct NodeSink
{
private:
	Node[32] mInlineStorage;
	Node[] mArray;
	size_t mNum;


public:
	fn push(n: Node) void
	{
		if (mArray.length == 0) {
			mArray = mInlineStorage[..];
		}

		if (mNum < mArray.length) {
			mArray[mNum++] = n;
			return;
		}

		allocSize := mArray.length;
		while (allocSize < mNum + 1) {
			allocSize += 32;
		}

		arr := new Node[](allocSize);
		arr[0 .. mNum] = mArray[0 .. mNum];
		arr[mNum++] = n;
		mArray = arr;
	}

	Node[] takeArray()
	{
		ret: Node[];

		if (mArray.length <= mInlineStorage.length) {
			ret = new mArray[0 .. mNum];
		} else {
			ret = mArray[0 .. mNum];
		}

		mArray = mInlineStorage[..];
		mNum = 0;

		return ret;
	}
}
