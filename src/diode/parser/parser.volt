// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.parser.parser;

import watt.text.source;

import ir = diode.ir;
import diode.ir.build : bFile, bText, bPrint, bIf, bFor, bAssign, bAccess, bIdent;

import diode.errors;
import diode.token.lexer : lex;
import diode.token.token : Token, TokenKind;
import diode.parser.writer;
import diode.parser.header;


fn parse(src : Source) ir.File
{
	tokens := lex(src);
	p := new Parser(tokens);
	file : ir.File;
	s := parseFile(p, out file);

	if (s != Status.Ok) {
		throw p.makeException();
	}

	return file;
}

private:

/// Helper alias to make typing easier.
alias tk = TokenKind;

enum Status
{
	Ok,
	Error = -1,
}

class LexerError : DiodeException
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
	mErrorToken : Token;

public:
	this(tokens : Token[])
	{
		super(tokens);
	}

	fn error() Status
	{
		mErrorToken = front;
		return Status.Error;
	}

	fn makeException() LexerError
	{
		return new LexerError(mErrorToken, "syntax error");
	}
}

fn parseFile(p : Parser, out file : ir.File) Status
{
	if (p.front != tk.Begin) {
		return p.error();
	}
	p.popFront();

	s : Status;
	node : ir.Node;
	nodes : ir.Node[];
	while (p.front != tk.End &&
	       (s = parseNode(p, out node)) == Status.Ok) {
		nodes ~= node;
	}

	file = bFile();
	file.nodes = nodes;
	return s;
}

fn parseNode(p : Parser, out node : ir.Node) Status
{
	t := p.front;
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

fn parseText(p : Parser, out node : ir.Node) Status
{
	assert(p.front == tk.Text);
	node = bText(p.front.value);
	p.popFront();
	return Status.Ok;
}

fn parsePrint(p : Parser, out node : ir.Node) Status
{
	assert(p.front == tk.OpenPrint);
	p.popFront();

	exp : ir.Exp;
	s := parseExp(p, out exp);
	if (s != Status.Ok ||
	    p.front != tk.ClosePrint) {
		return p.error();
	}

	p.popFront();

	node = bPrint(exp);
	return Status.Ok;
}

fn parseStatement(p : Parser, out node : ir.Node) Status
{
	assert(p.front == tk.OpenStatement);

	if (p.following != tk.Identifier) {
		p.error();
	}

	// We use identifiers instead of special tokens for statements.
	switch (p.following.value) {
	case "if": return parseIf(p, out node);
	case "for": return parseFor(p, out node);
	case "assign": return parseAssign(p, out node);
	default: return p.error();
	}
}

fn parseIf(p : Parser, out node : ir.Node) Status
{
	assert(p.front == tk.OpenStatement);
	p.popFront();

	// This is a if.
	exp : ir.Exp;
	nodes : ir.Node[];

	// 'if' something.ident
	assert(p.front == "if");
	p.popFront();

	s1 := parseExp(p, out exp);
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
		    p.following == "endif") {
			break;
		}
		n : ir.Node;
		s2 := parseNode(p, out n);
		if (s2 != Status.Ok) {
			return s2;
		}

		nodes ~= n;
	}

	if (p.front == tk.End) {
		return p.error();
	}

	// Pop {% endif
	p.popFront();
	p.popFront();

	// Check for %}
	if (p.front != tk.CloseStatement) {
		return p.error();
	}

	p.popFront();

	node = bIf(exp, nodes);
	return Status.Ok;
}

fn parseFor(p : Parser, out node : ir.Node) Status
{
	assert(p.front == tk.OpenStatement);
	p.popFront();

	// This is a for.
	ident : string;
	exp : ir.Exp;
	nodes : ir.Node[];

	// 'for' ident in something.exp
	assert(p.front == "for");
	p.popFront();

	// for 'ident' in something.exp
	if (p.front != tk.Identifier) {
		return p.error();
	}
	ident = p.front.value;
	p.popFront();

	// for ident 'in' something.exp
	if (p.front != "in") {
		return p.error();
	}
	p.popFront();

	s1 := parseExp(p, out exp);
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
		    p.following == "endfor") {
			break;
		}
		n : ir.Node;
		s2 := parseNode(p, out n);
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

fn parseAssign(p : Parser, out node : ir.Node) Status
{
	assert(p.front == tk.OpenStatement);
	p.popFront();

	// This is a assign.
	ident : string;
	exp : ir.Exp;

	// 'assign' ident = exp
	assert(p.front == "assign");
	p.popFront();

	// assign 'ident' = exp
	if (p.front != tk.Identifier) {
		return p.error();
	}
	ident = p.front.value;
	p.popFront();

	// assign ident '=' exp
	if (p.front != tk.Assign) {
		return p.error();
	}
	p.popFront();

	// assign ident = 'exp'
	s1 := parseExp(p, out exp);
	if (s1 != Status.Ok) {
		return s1;
	}

	// Check the end.
	if (p.front != tk.CloseStatement) {
		return p.error();
	}
	p.popFront();

	node = bAssign(ident, exp);
	return Status.Ok;
}

fn parseExp(p : Parser, out exp : ir.Exp) Status
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
