// Copyright © 2010-2015, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module diode.token.source;

import watt.text.utf : decode;
import watt.text.ascii : isWhite;


final class Source
{
public:
	string source;
	bool eof;

private:
	dchar mChar;
	size_t mNextIndex;
	size_t mLastIndex;

public:
	this(string source)
	{
		this.source = source;
		popFront();
	}

	/**
	 * Returns the current utf8 char.
	 *
	 * Side-effects:
	 *   None.
	 */
	@property dchar front()
	{
		return mChar;
	}

	/**
	 * Advance the source one character.
	 *
	 * Side-effects:
	 *   @p eof set to true if we have reached the EOF.
	 *   @p mChar is set to the returned character if not at EOF.
	 *   @p mIndex advanced to the end of the given character.
	 *
	 * Throws:
	 *   UtfException if the source is not valid utf8.
	 */
	void popFront()
	{
		mLastIndex = mNextIndex;
		mChar = decodeChar(ref mNextIndex);
		if (mChar == dchar.init) {
			eof = true;
			mNextIndex = source.length;
			mLastIndex = source.length;
		}
	}

	/**
	 * Used to skip whitespace in the source file,
	 * as defined by watt.text.ascii.isWhite.
	 *
	 * Side-effects:
	 *   @arg @see popFront
	 */
	void skipWhitespace()
	{
		while (isWhite(mChar) && !eof) {
			popFront();
		}
	}

	size_t save()
	{
		return mLastIndex;
	}

	dchar lookahead()
	{
		size_t tmpIndex = mNextIndex;
		return decodeChar(ref tmpIndex);
	}

	string sliceFrom(size_t mark)
	{
		return source[mark .. mLastIndex];
	}

	dchar decodeChar(ref size_t index)
	{
		if (mNextIndex >= source.length) {
			return dchar.init;
		}

		return decode(source, ref index);
	}
}
