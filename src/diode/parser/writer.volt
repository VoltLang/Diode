// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.parser.writer;

import diode.token.token;


class Writer
{
protected:
	Token[] mTokens;
	size_t mIndex;

public:
	this(Token[] tokens)
	{
		assert(tokens.length > 0);
		mTokens = tokens;
	}

	/**
	 * Returns the current token.
	 *
	 * Side-effects:
	 *   None.
	 */
	final @property Token front()
	{
		return mTokens[mIndex];
	}

	/**
	 * Returns the following token.
	 *
	 * Side-effects:
	 *   None.
	 */
	final @property Token following()
	{
		return lookahead(1);
	}

	/**
	 * Advances the stream by one, will clamp to the last token.
	 *
	 * Side-effects:
	 *   Icrements mIndex.
	 */
	void popFront()
	{
		mIndex++;
		if (mIndex >= mTokens.length) {
			mIndex = mTokens.length - 1;
		}
	}

	/**
	 * Returns the token n steps into the stream, will clamp to length.
	 *
	 * Side-effects:
	 *   None.
	 */
	final Token lookahead(size_t n)
	{
		size_t i = mIndex + n;
		if (i >= mTokens.length) {
			return mTokens[$ - 1];
		}
		return mTokens[i];
	}
}
