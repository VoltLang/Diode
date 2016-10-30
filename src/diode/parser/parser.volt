// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.parser.parser;

import watt.text.source;
import watt.text.string : stripLeft, stripRight;

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
	nodes : ir.Node[];
	while (p.front != tk.End) {
		s = parseNode(p, ref nodes);
		if (s != Status.Ok) {
			return s;
		}
	}

	file = bFile();
	file.nodes = nodes;
	return s;
}

fn parseNode(p : Parser, ref nodes : ir.Node[]) Status
{
	s: Status;
	node: ir.Node;
	t := p.front;
	switch (t.kind) with (TokenKind) {
	case Text:
	case Hyphen:
		s = parseText(p, out node); break;
	case OpenPrint:
		s = parsePrint(p, out node); break;
	case OpenStatement:
		s = parseStatement(p, out node); break;
	default:
		s = p.error();
	}

	if (node !is null) {
		nodes ~= node;
	}
	return s;
}

import watt.io : error;

fn parseText(p : Parser, out node : ir.Node) Status
{
	hyphen := stripAnyHyphen(p);

	// Handle {{ bar -}}{{- foo }}
	if (p.front != tk.Text) {
		assert(hyphen);
		return Status.Ok;
	}

	// Get the text.
	assert(p.front == tk.Text);
	text := p.front.value;

	// Strip whitespace if there was a preceding hyphen.
	if (hyphen) {
		text = stripLeft(text);
	}

	p.popFront();

	hyphen = stripAnyHyphen(p);

	// Strip whitespace if there was a following hyphen.
	if (hyphen) {
		text = stripRight(text);
	}

	if (text.length > 0) {
		node = bText(text);
	}
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
	case "for": return parseFor(p, out node);
	case "assign": return parseAssign(p, out node);
	case "unless", "if": return parseIfUnless(p, out node);
	default: return p.error();
	}
}

fn parseIfUnless(p : Parser, out node : ir.Node) Status
{
	assert(p.front == tk.OpenStatement);
	p.popFront();

	// This is a if or unless.
	invert : bool;
	exp : ir.Exp;
	thenNodes : ir.Node[];
	elseNodes : ir.Node[];

	// ['if'|'unless'] something.ident
	assert(p.front == "if" || p.front == "unless");
	invert = p.front == "unless";
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

	elseBlock := false;
	while (p.front != tk.End) {
		if (p.front == tk.OpenStatement &&
		    p.following == "endif") {
			break;
		}
		if (p.front == tk.OpenStatement &&
			p.following == "else") {
			// Pop {% else %}
			p.popFront();
			p.popFront();
			// Check for %}
			if (p.front != tk.CloseStatement) {
				return p.error();
			}
			p.popFront();
			elseBlock = true;
		}
		s2 : Status;
		if (p.front == tk.OpenStatement &&
			p.following == "elsif") {
			elsifNode: ir.Node;
			s2 = parseElsIf(p, ref elsifNode);
			if (elsifNode !is null) {
				elseNodes ~= elsifNode;
			}
		} else if (!elseBlock) {
			s2 = parseNode(p, ref thenNodes);
		} else {
			s2 = parseNode(p, ref elseNodes);
		}
		if (s2 != Status.Ok) {
			return s2;
		}
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

	node = bIf(invert, exp, thenNodes, elseNodes);
	return Status.Ok;
}

fn parseElsIf(p : Parser, ref node : ir.Node) Status
{
	assert(p.front == tk.OpenStatement);
	p.popFront();

	exp : ir.Exp;
	thenNodes : ir.Node[];
	elseNodes : ir.Node[];

	// ['if'|'unless'] something.ident
	assert(p.front == "elsif");
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

	elseBlock := false;
	while (p.front != tk.End) {
		if (p.front == tk.OpenStatement &&
		    p.following == "endif") {
			break;
		}
		if (p.front == tk.OpenStatement &&
			p.following == "else") {
			// Pop {% else %}
			p.popFront();
			p.popFront();
			// Check for %}
			if (p.front != tk.CloseStatement) {
				return p.error();
			}
			p.popFront();
			elseBlock = true;
		}
		s2 : Status;
		if (!elseBlock) {
			s2 = parseNode(p, ref thenNodes);
		} else {
			s2 = parseNode(p, ref elseNodes);
		}
		if (s2 != Status.Ok) {
			return s2;
		}
	}

	node = bIf(false, exp, thenNodes, elseNodes);
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
		s2 := parseNode(p, ref nodes);
		if (s2 != Status.Ok) {
			return s2;
		}
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

/// Returns true if any hyphen was found.
fn stripAnyHyphen(p : Parser) bool
{
	hyphen := false;
	while (p.front == tk.Hyphen) {
		hyphen = true;
		p.popFront();
	}
	return hyphen;
}
