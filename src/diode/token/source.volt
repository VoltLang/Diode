// Copyright © 2010-2015, Bernard Helyer.  All rights reserved.
// Copyright © 2012-2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module diode.token.source;

import watt.text.utf : decode;
import watt.text.ascii : isWhite;

import diode.token.location;


final class Source
{
public:
	/// Source code, validated utf8 by constructors.
	string source;
	/// The location of the current character @p mChar.
	Location loc;
	/// Have we reached EOF, if we have current = dchar.init.
	bool eof = false;

private:
	/// The current unicode character.
	dchar mChar;
	/// Pointer into the string for the next character.
	size_t mNextIndex;
	/// The index for mChar
	size_t mLastIndex;

public:
	/**
	 * Sets the source to string and the current location
	 * and validate it as a utf8 source.
	 *
	 * Side-effects:
	 *   Puts all the other fields into known good states.
	 *
	 * Throws:
	 *   UtfException if the source is not valid utf8.
	 */
	this(string s, string filename)
	{
		source = s;

		popFront();

		loc.filename = filename;
		loc.line = 1;
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
	 * Returns the following utf8 char after front.
	 *
	 * Side-effects:
	 *   None.
	 */
	@property dchar following()
	{
		bool dummy;
		return lookahead(1, out dummy);
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
		if (mChar == '\n') {
			loc.line++;
			loc.column = 0;
		}

		mLastIndex = mNextIndex;
		mChar = decodeChar(ref mNextIndex);
		if (mChar == dchar.init) {
			eof = true;
			mNextIndex = source.length;
			mLastIndex = source.length;
		}

		loc.column++;
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

	/**
	 * Return the unicode character @p n chars forwards.
	 * @p lookaheadEOF set to true if we reached EOF, otherwise false.
	 *
	 * Throws:
	 *   UtfException if the source is not valid utf8.
	 *
	 * Side-effects:
	 *   None.
	 *
	 * Returns:
	 *   Unicode char at @p n or @p dchar.init at EOF.
	 */
	dchar lookahead(size_t n, out bool lookaheadEOF)
	{
		if (n == 0) {
			lookaheadEOF = eof;
			return mChar;
		}

		dchar c;
		auto index = mNextIndex;
		for (size_t i; i < n; i++) {
			c = decodeChar(ref index);
			if (c == dchar.init) {
				lookaheadEOF = true;
				return dchar.init;
			}
		}
		return c;
	}

	size_t save()
	{
		return mLastIndex;
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
