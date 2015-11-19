// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.token.lexer;

import watt.text.ascii : isAlpha, isDigit;
import watt.io;
import diode.token.token;
import diode.token.source;
import diode.token.stream;


Token[] lex(string text, string filename)
{
	auto src = new Source(text, filename);
	auto tw = new TokenStream();

	tw.pushToken(ref src.loc, TokenKind.Begin, "BEGIN");

	Status s;
	while (s != Status.End) {
		final switch (s) with (Status) {
		case Text:
			s = lexText(src, tw);
			break;
		case Exp, Statement:
			s = lexToken(src, tw, s);
			break;
		case End:
		case Error:
			throw new Exception("lexer error");
		}
	}

	tw.pushToken(ref src.loc, TokenKind.End, "END");

	return tw.mTokens;
}

private:
enum Status
{
	Text,
	Exp,
	Statement,
	End,
	Error = -1,
}

Status lexToken(Source src, TokenStream tw, Status status)
{
	assert(status != Status.Text);

	size_t mark = src.save();
	src.skipWhitespace();
	if (src.eof) {
		return Status.End;
	}

	switch (src.front) {
	case '}':
		if (src.following != '}') {
			return Status.Error;
		}
		tw.pushToken(ref src.loc, TokenKind.ClosePrint, "}}");
		src.popFront();
		src.popFront();
		return Status.Text;
	case '%':
		if (src.following != '}') {
			return Status.Error;
		}
		tw.pushToken(ref src.loc, TokenKind.CloseStatement, "%}");
		src.popFront();
		src.popFront();
		return Status.Text;
	case '.':
		tw.pushToken(ref src.loc, TokenKind.Dot, ".");
		src.popFront();
		return status;
	case '_':
		return lexIdent(src, tw, status);
	default:
		if (!isAlpha(src.front)) {
			return Status.Error;
		}
		return lexIdent(src, tw, status);
	}
}

Status lexIdent(Source src, TokenStream tw, Status status)
{
	auto loc = src.loc;
	auto mark = src.save();

	src.popFront();
	while (src.front.isAlpha() ||
	       src.front.isDigit() ||
	       src.front == '_') {
		src.popFront();
	}
	auto v = src.sliceFrom(mark);
	tw.pushToken(ref loc, identifierKind(v), v);
	return status;
}

Status lexText(Source src, TokenStream tw)
{
	auto loc = src.loc;
	size_t mark = src.save();

	while (!src.eof) {
		if (src.front == '{' &&
		    (src.following == '{' ||
		     src.following == '%')) {
			break;
		}
		src.popFront();
	}

	tw.pushToken(ref loc, TokenKind.Text, src.sliceFrom(mark));

	if (src.eof) {
		return Status.End;
	}

	src.popFront();
	scope (success) {
		src.popFront();
	}

	switch (src.front) with (TokenKind) {
	case '%':
		tw.pushToken(ref src.loc, OpenStatement, "{%");
		return Status.Statement;
	case '{':
		tw.pushToken(ref src.loc, OpenPrint, "{{");
		return Status.Exp;
	default:
	}
	assert(false);
}
