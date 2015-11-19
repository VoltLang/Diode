// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.token.lexer;

import watt.text.ascii : isAlpha, isDigit;
import watt.io;
import diode.token.token;
import diode.token.source;
import diode.token.stream;


Token[] lex(string text)
{
	auto src = new Source(text);
	auto tw = new TokenStream();

	tw.pushToken(TokenKind.Begin, "BEGIN");

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

	tw.pushToken(TokenKind.End, "END");

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
		if (src.lookahead() != '}') {
			return Status.Error;
		}
		tw.pushToken(TokenKind.ClosePrint, "}}");
		src.popFront();
		src.popFront();
		return Status.Text;
	case '%':
		if (src.lookahead() != '}') {
			return Status.Error;
		}
		tw.pushToken(TokenKind.CloseStatement, "%}");
		src.popFront();
		src.popFront();
		return Status.Text;
	case '.':
		tw.pushToken(TokenKind.Dot, ".");
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
	auto mark = src.save();
	src.popFront();
	while (src.front.isAlpha() ||
	       src.front.isDigit() ||
	       src.front == '_') {
		src.popFront();
	}
	auto v = src.sliceFrom(mark);
	tw.pushToken(identifierKind(v), v);
	return status;
}

Status lexText(Source src, TokenStream tw)
{
	size_t mark = src.save();
	while (!src.eof) {
		if (src.front == '{' &&
		    (src.lookahead() == '{' ||
		     src.lookahead() == '%')) {
			break;
		}
		src.popFront();
	}

	tw.pushToken(TokenKind.Text, src.sliceFrom(mark));

	if (src.eof) {
		return Status.End;
	}

	src.popFront();
	scope (success) {
		src.popFront();
	}

	switch (src.front) with (TokenKind) {
	case '%':
		tw.pushToken(OpenStatement, "{%");
		return Status.Statement;
	case '{':
		tw.pushToken(OpenPrint, "{{");
		return Status.Exp;
	default:
	}
	assert(false);
}
