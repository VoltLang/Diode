// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.token.writer;

import watt.text.source : Location;
import diode.token.token;


final class Writer
{
protected:
	mTokens: Token[];
	mError: string;


public:
	fn pushToken(ref loc: const Location, kind: TokenKind, value: string)
	{
		t := new Token();
		t.kind = kind;
		t.value = value;
		t.loc = loc;
		t.loc.length = value.length;

		mTokens ~= t;
	}

	fn takeTokens() Token[]
	{
		ret := mTokens;
		mTokens = null;
		return ret;
	}

	@property fn errorMessage(msg: string)
	{
		mError = msg;
	}

	@property fn errorMessage() string
	{
		if (mError == "") {
			return "unknown error";
		} else {
			return mError;
		}
	}
}
