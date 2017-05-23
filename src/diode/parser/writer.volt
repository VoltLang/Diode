// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.parser.writer;

import diode.token.token;


class Writer
{
protected:
	mTokens: Token[];
	mIndex: size_t;


public:
	this(tokens: Token[])
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
	final @property fn front() Token
	{
		return mTokens[mIndex];
	}

	/**
	 * Returns the following token.
	 *
	 * Side-effects:
	 *   None.
	 */
	final @property fn following() Token
	{
		return lookahead(1);
	}

	/**
	 * Advances the stream by one, will clamp to the last token.
	 *
	 * Side-effects:
	 *   Icrements mIndex.
	 */
	fn popFront()
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
	final fn lookahead(n: size_t) Token
	{
		i := mIndex + n;
		if (i >= mTokens.length) {
			return mTokens[$ - 1];
		}
		return mTokens[i];
	}
}
