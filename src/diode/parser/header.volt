// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.parser.header;

import watt.text.ascii;
import watt.text.string;
import watt.text.source;

import diode.errors;


class Header
{
public:
	string[string] map;
}

Header parse(Source src)
{
	if (!src.isTrippleDash()) {
		return null;
	}
	// Skip the dashes and the rest of the line.
	src.skipEndOfLine();

	auto header = new Header();

	//writefln("DFD %s", src.mSrc.mLastIndex);

	while (!src.eof && !src.isTrippleDash()) {
		// If it is a empty line, just skip it.
		if (src.skipWhiteAndCheckIfEmptyLine()) {
			continue;
		}

		// We now know that this is not a tripple dash line
		// and the character that src is point on is not a
		// whitespace character.
		auto key = src.getIdent();
		src.skipWhiteTillAfterColon();
		auto val = src.getRestOfLine().strip();

		// Update the key in the header.
		header.map[key] = val;
	}

	// Skip the dashes and the rest of the line.
	src.skipEndOfLine();

	return header;
}

/**
 * Does not advance the source, just check if the next 3 chars are dashes.
 */
bool isTrippleDash(Source src)
{
	bool eof;

	return src.lookahead(0, out eof) == '-' &&
	       src.lookahead(1, out eof) == '-' &&
	       src.lookahead(2, out eof) == '-';
}

/**
 * Does what it says on the tin, yes I felt bad naming this function.
 */
bool skipWhiteAndCheckIfEmptyLine(Source src)
{
	dchar d = src.front;
	while (d != '\n' && d.isWhite() && !src.eof) {
		src.popFront();
		d == src.front;
	}

	if (d == '\n') {
		src.popFront();
		return true;
	} else {
		return false;
	}
}

void skipWhiteTillAfterColon(Source src)
{
	dchar d = src.front;
	while (d != ':' && !src.eof) {
		if (!src.front.isWhite()) {
			throw makeBadHeader(ref src.loc);
		}
		src.popFront();
		d = src.front;
	}
	if (d == ':') {
		src.popFront();
	}
}

string getIdent(Source src)
{
	auto mark = src.save();
	if (!src.front.isAlpha()) {
		throw makeBadHeader(ref src.loc);
	}

	src.popFront();
	while (src.front.isAlpha() ||
	       src.front.isDigit() ||
	       src.front == '_') {
		src.popFront();
	}
	return src.sliceFrom(mark);
}

string getRestOfLine(Source src)
{
	auto mark = src.save();
	dchar d = src.front;
	while (d != '\n' && !src.eof) {
		src.popFront();
		d = src.front;
	}
	auto ret = src.sliceFrom(mark);
	if (d == '\n') {
		src.popFront();
	}
	return ret;
}
