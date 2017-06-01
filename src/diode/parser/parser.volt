// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.parser.parser;

import watt.text.source;
import watt.text.string : stripLeft, stripRight;

import ir = diode.ir;
import diode.ir.build : bFile, bText, bPrint, bIf, bFor, bAssign, bInclude,
	bAccess, bIdent, bFilter;

import diode.errors;
import diode.token.lexer : lex;
import diode.token.token : Token, TokenKind;
import diode.parser.writer;
import diode.parser.header;


fn parse(src: Source) ir.File
{
	tokens := lex(src);
	p := new Parser(tokens);
	file: ir.File;
	s := parseFile(p, out file);

	if (s != Status.Ok) {
		throw p.makeException();
	}

	return file;
}

private:

//! Helper alias to make typing easier.
alias tk = TokenKind;

enum Status
{
	Ok = 0,
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
	mErrorToken: Token;

public:
	this(tokens: Token[])
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

fn parseFile(p: Parser, out file: ir.File) Status
{
	if (p.front != tk.Begin) {
		return p.error();
	}
	p.popFront();

	s: Status;
	nodes: ir.Node[];
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

fn parseNode(p: Parser, ref nodes: ir.Node[]) Status
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

fn match(p: Parser, t: TokenKind) Status
{
	if (p.front != t) {
		return p.error();
	}
	p.popFront();
	return Status.Ok;
}

fn match(p: Parser, str: string) Status
{
	if (p.front.value != str) {
		return p.error();
	}
	p.popFront();
	return Status.Ok;
}

fn matchAndGet(p: Parser, out str: string) Status
{
	if (p.front != tk.Identifier) {
		return p.error();
	}
	str = p.front.value;
	p.popFront();
	return Status.Ok;
}

fn matchAssert(p: Parser, t: TokenKind)
{
	assert(p.front == t);
	p.popFront();
}

import watt.io : error;

fn parseText(p: Parser, out node: ir.Node) Status
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

fn parsePrint(p: Parser, out node: ir.Node) Status
{
	// Check for {{
	p.matchAssert(tk.OpenPrint);

	// {{ <exp> }}
	exp: ir.Exp;
	if (err := parseExp(p, out exp)) {
		return err;
	}

	// Check for }}
	if (err := p.match(tk.ClosePrint)) {
		return err;
	}

	node = bPrint(exp);
	return Status.Ok;
}

fn parseStatement(p: Parser, out node: ir.Node) Status
{
	// We use identifiers instead of special tokens for statements.
	switch (p.following.value) {
	case "for": return parseFor(p, out node);
	case "assign": return parseAssign(p, out node);
	case "include": return parseInclude(p, out node);
	case "unless", "if": return parseIfUnless(p, out node);
	default: return p.error();
	}
}

fn parseInclude(p: Parser, out node: ir.Node) Status
{
	// Check for {%
	p.matchAssert(tk.OpenStatement);

	// This is a for.
	base: string;
	ext: string;
	exp: ir.Exp;
	assigns: ir.Assign[];

	// 'include' base.ext
	assert(p.front == "include");
	p.popFront();

	// include 'base'.ext
	if (err := p.matchAndGet(out base)) {
		return err;
	}

	// include base'.'ext
	if (err := p.match(tk.Dot)) {
		return err;
	}

	// include base.'ext'
	if (err := p.matchAndGet(out ext)) {
		return err;
	}

	while (p.front == tk.Identifier) {
		ident: string;

		// assign 'ident' = exp
		if (err := p.matchAndGet(out ident)) {
			return err;
		}

		// assign ident '=' exp
		if (err := p.match(tk.Assign)) {
			return err;
		}

		// assign ident = 'exp'
		if (err := parseExp(p, out exp)) {
			return err;
		}

		assigns ~= bAssign(ident, exp);
	}

	// Check for %}
	if (err := p.match(tk.CloseStatement)) {
		return err;
	}

	node = bInclude(base ~ "." ~ ext, assigns);
	return Status.Ok;
}

fn parseIfUnless(p: Parser, out node: ir.Node, elsif: bool = false) Status
{
	// Check for {%
	p.matchAssert(tk.OpenStatement);

	// This is a if or unless.
	invert: bool;
	exp: ir.Exp;
	thenNodes: ir.Node[];
	elseNodes: ir.Node[];

	// ['if'|'unless'] something.ident
	if (elsif) {
		assert(p.front == "elsif");
	} else {
		assert(p.front == "if" || p.front == "unless");
	}
	invert = p.front == "unless";
	p.popFront();

	if (err := p.parseExp(out exp)) {
		return err;
	}

	// Check the end.
	if (err := p.match(tk.CloseStatement)) {
		return err;
	}

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
		s2: Status;
		if (p.front == tk.OpenStatement &&
			p.following == "elsif") {
			elsifNode: ir.Node;
			s2 = parseIfUnless(p, out elsifNode, true);
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

	if (!elsif) {
		if (p.front == tk.End) {
			return p.error();
		}

		// Pop {% endif
		p.popFront();
		p.popFront();

		// Check for %}
		if (err := p.match(tk.CloseStatement)) {
			return err;
		}
	}

	node = bIf(invert, exp, thenNodes, elseNodes);
	return Status.Ok;
}

fn parseFor(p: Parser, out node: ir.Node) Status
{
	// Check for {%
	p.matchAssert(tk.OpenStatement);

	// This is a for.
	ident: string;
	exp: ir.Exp;
	nodes: ir.Node[];

	// 'for' ident in something.exp
	assert(p.front == "for");
	p.popFront();

	// for 'ident' in something.exp
	if (err := p.matchAndGet(out ident)) {
		return err;
	}

	// for ident 'in' something.exp
	if (p.front != "in") {
		return p.error();
	}
	p.popFront();

	if (err := parseExp(p, out exp)) {
		return err;
	}

	// Check the end.
	if (err := p.match(tk.CloseStatement)) {
		return err;
	}

	while (p.front != tk.End) {
		if (p.front == tk.OpenStatement &&
		    p.following == "endfor") {
			break;
		}
		if (err := parseNode(p, ref nodes)) {
			return err;
		}
	}

	if (p.front == tk.End) {
		return p.error();
	}

	// Pop {% endfor
	p.popFront();
	p.popFront();

	// Check for %}
	if (p.match(tk.CloseStatement)) {
		return p.error();
	}

	node = bFor(ident, exp, nodes);
	return Status.Ok;
}

fn parseAssign(p: Parser, out node: ir.Node) Status
{
	// Check for {%
	p.matchAssert(tk.OpenStatement);

	// This is a assign.
	ident: string;
	exp: ir.Exp;

	// 'assign' ident = exp
	if (err := p.match("assign")) {
		return err;
	}

	// assign 'ident' = exp
	if (err := p.matchAndGet(out ident)) {
		return err;
	}

	// assign ident '=' exp
	if (err := p.match(tk.Assign)) {
		return err;
	}

	// assign ident = 'exp'
	if (err := parseExp(p, out exp)) {
		return err;
	}

	// Check the end.
	if (err := p.match(tk.CloseStatement)) {
		return err;
	}

	node = bAssign(ident, exp);
	return Status.Ok;
}

fn parseExp(p: Parser, out exp: ir.Exp) Status
{
	v: string;
	if (err := p.matchAndGet(out v)) {
		return err;
	}

	exp = bIdent(v);

	while (true) {
		switch (p.front.kind) with (TokenKind) {
		case Dot:
			p.popFront();

			if (err := p.matchAndGet(out v)) {
				return err;
			}
			exp = bAccess(exp, v);
			break;
		case Pipe:
			p.popFront();

			if (err := p.matchAndGet(out v)) {
				return err;
			}

			exp = bFilter(exp, v, null);

			if (p.front != tk.Colon) {
				break;
			}

			// TODO filter arguments.
			return p.error();
		default:
			return Status.Ok;
		}
	}
	return Status.Ok;
}

//! Returns true if any hyphen was found.
fn stripAnyHyphen(p: Parser) bool
{
	hyphen := false;
	while (p.front == tk.Hyphen) {
		hyphen = true;
		p.popFront();
	}
	return hyphen;
}
