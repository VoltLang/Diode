// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.token.stream;

import diode.token.token;


final class TokenStream
{
protected:
	Token[] mTokens;

public:
	void pushToken(TokenKind kind, string value = null)
	{
		auto t = new Token();
		t.kind = kind;
		t.value = value;

		mTokens ~= t;
	}
}
