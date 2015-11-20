// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.token.writer;

import watt.text.source : Location;
import diode.token.token;


final class Writer
{
protected:
	Token[] mTokens;

public:
	void pushToken(ref const Location loc, TokenKind kind, string value)
	{
		auto t = new Token();
		t.kind = kind;
		t.value = value;
		t.loc = loc;
		t.loc.length = value.length;

		mTokens ~= t;
	}
}
