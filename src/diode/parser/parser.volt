// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.parser.parser;

import ir = diode.ir;
import diode.ir.build : bFile, bText, bPrint, bFor, bAccess, bIdent;

import diode.token.lexer : lex;
import diode.token.token : Token, TokenKind;
import diode.parser.writer;


ir.File parse(string text, string filename)
{
	auto tokens = lex(text, filename);
	auto p = new Parser(tokens);
	ir.File file;
	auto s = parseFile(p, out file);

	if (s != Status.Ok) {
		throw p.makeException();
	}

	return file;
}

private:

/// Helper alias to make typing easier.
alias tk = TokenKind;

enum Status {
	Ok,
	Error = -1,
}

class LexerError : Exception
{
public:
	this(Token t, string msg)
	{
		msg = t.loc.toString() ~ " error: " ~ msg;
		super(msg);
	}
}

class Parser : Writer
{
protected:
	Token mErrorToken;

public:
	this(Token[] tokens)
	{
		super(tokens);
	}

	Status error()
	{
		mErrorToken = front;
		return Status.Error;
	}

	Exception makeException()
	{
		return new LexerError(mErrorToken, "syntax error");
	}
}

Status parseFile(Parser p, out ir.File file)
{
	if (p.front != tk.Begin) {
		return p.error();
	}
	p.popFront();

	Status s;
	ir.Node node;
	ir.Node[] nodes;
	while (p.front != tk.End &&
	       (s = parseNode(p, out node)) == Status.Ok) {
		nodes ~= node;
	}

	file = bFile();
	file.nodes = nodes;
	return s;
}

Status parseNode(Parser p, out ir.Node node)
{
	auto t = p.front;
	switch (t.kind) with (TokenKind) {
	case Text:
		return parseText(p, out node);
	case OpenPrint:
		return parsePrint(p, out node);
	case OpenStatement:
		return parseStatement(p, out node);
	default:
		return p.error();
	}
}

Status parseText(Parser p, out ir.Node node)
{
	assert(p.front == tk.Text);
	node = bText(p.front.value);
	p.popFront();
	return Status.Ok;
}

Status parsePrint(Parser p, out ir.Node node)
{
	assert(p.front == tk.OpenPrint);
	p.popFront();

	ir.Exp exp;
	auto s = parseExp(p, out exp);
	if (s != Status.Ok ||
	    p.front != tk.ClosePrint) {
		return p.error();
	}

	p.popFront();

	node = bPrint(exp);
	return Status.Ok;
}

Status parseStatement(Parser p, out ir.Node node)
{
	assert(p.front == tk.OpenStatement);

	// We only support for statements for now.
	if (p.following != tk.For) {
		return p.error();
	}
	return parseFor(p, out node);
}

Status parseFor(Parser p, out ir.Node node)
{
	assert(p.front == tk.OpenStatement);
	p.popFront();

	// This is a for.
	string ident;
	ir.Exp exp;
	ir.Node[] nodes;

	// 'for' ident in something.exp
	assert(p.front == tk.For);
	p.popFront();

	// for 'ident' in something.exp
	if (p.front != tk.Identifier) {
		return p.error();
	}
	ident = p.front.value;
	p.popFront();

	// for ident 'in' something.exp
	if (p.front != tk.In) {
		return p.error();
	}
	p.popFront();

	auto s1 = parseExp(p, out exp);
	if (s1 != Status.Ok) {
		return s1;
	}

	// Check the end.
	if (p.front != tk.CloseStatement) {
		return p.error();
	}
	p.popFront();

	while (p.front != tk.End) {
		if (p.front == tk.OpenStatement &&
		    p.following == tk.EndFor) {
			break;
		}
		ir.Node n;
		auto s2 = parseNode(p, out n);
		if (s2 != Status.Ok) {
			return s2;
		}

		nodes ~= n;
	}

	if (p.front == tk.End) {
		return p.error();
	}

	// Pop {% endfor
	p.popFront();
	p.popFront();

	// Check for %}
	if (p.front != tk.CloseStatement) {
		return p.error();
	}

	p.popFront();

	node = bFor(ident, exp, nodes);
	return Status.Ok;
}

Status parseExp(Parser p, out ir.Exp exp)
{
	if (p.front != tk.Identifier) {
		return p.error();
	}

	exp = bIdent(p.front.value);
	p.popFront();

	while (true) {
		switch (p.front.kind) with (TokenKind) {
		case Dot:
			p.popFront();
			if (p.front != tk.Identifier) {
				return p.error();
			}
			exp = bAccess(exp, p.front.value);
			p.popFront();
			break;
		default:
			return Status.Ok;
		}
	}
	return Status.Ok;
}
