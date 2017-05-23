// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.token.lexer;

import watt.text.ascii : isAlpha, isDigit;
import watt.text.source : Source;
import watt.io;

import diode.errors;
import diode.token.token;
import diode.token.writer;


fn lex(src: Source) Token[]
{
	tw := new Writer();

	tw.pushToken(ref src.loc, TokenKind.Begin, "BEGIN");

	s: Status;
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

	return tw.takeTokens();
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

fn lexToken(src: Source, tw: Writer, status: Status) Status
{
	assert(status != Status.Text);

	hyphen := false;
	mark := src.save();
	src.skipWhitespace();
	if (src.eof) {
		return Status.End;
	}

	switch (src.front) {
	case '-':
		src.popFront();
		if (src.front == '}') {
			hyphen = true;
			goto case '}';
		} else if (src.front == '%') {
			hyphen = true;
			goto case '%';
		} else {
			return Status.Error;
		}
		assert(false);
	case '}':
		if (src.following != '}') {
			return Status.Error;
		}
		tw.pushToken(ref src.loc, TokenKind.ClosePrint, "}}");
		// Add the hyphen token after the ClosePrint token.
		if (hyphen) {
			tw.pushToken(ref src.loc, TokenKind.Hyphen, "-");
		}
		src.popFront();
		src.popFront();
		return Status.Text;
	case '%':
		if (src.following != '}') {
			return Status.Error;
		}
		tw.pushToken(ref src.loc, TokenKind.CloseStatement, "%}");
		// Add the hyphen token after the CloseStatement token.
		if (hyphen) {
			tw.pushToken(ref src.loc, TokenKind.Hyphen, "-");
		}
		src.popFront();
		src.popFront();
		return Status.Text;
	case '.':
		tw.pushToken(ref src.loc, TokenKind.Dot, ".");
		src.popFront();
		return status;
	case ':':
		tw.pushToken(ref src.loc, TokenKind.Colon, ":");
		src.popFront();
		return status;
	case '|':
		tw.pushToken(ref src.loc, TokenKind.Pipe, "|");
		src.popFront();
		return status;
	case ',':
		tw.pushToken(ref src.loc, TokenKind.Comma, ",");
		src.popFront();
		return status;
	case '=':
		tw.pushToken(ref src.loc, TokenKind.Assign, "=");
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

fn lexIdent(src: Source, tw: Writer, status: Status) Status
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

fn lexText(src: Source, tw: Writer) Status
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

	text := src.sliceFrom(mark);
	if (text.length > 0) {
		tw.pushToken(ref loc, TokenKind.Text, text);
	}

	if (src.eof) {
		return Status.End;
	}

	f := src.following;
	src.popFront();
	src.popFront();

	// Add the hyphen before the Open[Statement|Print] token.
	if (src.front == '-') {
		tw.pushToken(ref src.loc, TokenKind.Hyphen, "-");
		src.popFront();
	}

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
