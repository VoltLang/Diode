// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.token.lexer;

import watt.text.ascii : isAlpha, isDigit;
import watt.text.source : Source;
import watt.io;

import diode.errors;
import diode.token.token;
import diode.token.writer;


fn lex(src : Source) Token[]
{
	tw := new Writer();

	tw.pushToken(ref src.loc, TokenKind.Begin, "BEGIN");

	s : Status;
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
			throw new DiodeException("lexer error");
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

fn lexToken(src : Source, tw : Writer, status : Status) Status
{
	assert(status != Status.Text);

	mark := src.save();
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

fn lexIdent(src : Source, tw : Writer, status : Status) Status
{
	loc := src.loc;
	mark := src.save();

	src.popFront();
	while (src.front.isAlpha() ||
	       src.front.isDigit() ||
	       src.front == '_') {
		src.popFront();
	}
	v := src.sliceFrom(mark);
	tw.pushToken(ref loc, identifierKind(v), v);
	return status;
}

fn lexText(src : Source, tw : Writer) Status
{
	loc := src.loc;
	mark := src.save();

	while (!src.eof) {
		if (src.front == '{' &&
		    (src.following == '{' ||
		     src.following == '%')) {
			break;
		}
		src.popFront();
	}

	if (mark != src.save()) {
		tw.pushToken(ref loc, TokenKind.Text, src.sliceFrom(mark));
	}

	if (src.eof) {
		return Status.End;
	}

	f := src.following;
	src.popFront();
	src.popFront();

	switch (f) with (TokenKind) {
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
