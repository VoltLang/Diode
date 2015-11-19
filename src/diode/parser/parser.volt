// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.parser.parser;

import ir = diode.ir;
import diode.token.lexer : lex;
import diode.token.token : Token, TokenKind;
import diode.ir.build : bFile, bText, bPrint, bFor, bAccess, bIdent;


ir.File parse(string text, string filename)
{
	auto tokens = lex(text);
	auto p = new Parser(tokens);
	ir.File file;
	auto s = parseFile(p, out file);

	if (s != Status.Ok) {
		throw new Exception("parser error");
	}

	return file;
}

private:
enum Status {
	Ok,
	Error = -1,
}

class Parser
{
protected:
	Token[] mTokens;
	size_t mIndex;

public:
	this(Token[] tokens)
	{
		assert(tokens.length > 0);
		mTokens = tokens;
	}

	@property Token front()
	{
		return mTokens[mIndex];
	}

	void popFront()
	{
		mIndex++;
		if (mIndex >= mTokens.length) {
			mIndex = mTokens.length - 1;
		}
	}

	Token lookahead()
	{
		size_t i = mIndex + 1;
		if (i >= mTokens.length) {
			return mTokens[$ - 1];
		}
		return mTokens[i];
	}
}

Status parseFile(Parser p, out ir.File file)
{
	if (p.front.kind != TokenKind.Begin) {
		return Status.Error;
	}
	p.popFront();

	Status s;
	ir.Node node;
	ir.Node[] nodes;
	while (p.front.kind != TokenKind.End &&
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
		return Status.Error;
	}
}

Status parseText(Parser p, out ir.Node node)
{
	assert(p.front.kind == TokenKind.Text);
	node = bText(p.front.value);
	p.popFront();
	return Status.Ok;
}

Status parsePrint(Parser p, out ir.Node node)
{
	assert(p.front.kind == TokenKind.OpenPrint);
	p.popFront();

	ir.Exp exp;
	auto s = parseExp(p, out exp);
	if (s != Status.Ok ||
	    p.front.kind != TokenKind.ClosePrint) {
		return Status.Error;
	}

	p.popFront();

	node = bPrint(exp);
	return Status.Ok;
}

Status parseStatement(Parser p, out ir.Node node)
{
	assert(p.front.kind == TokenKind.OpenStatement);
	p.popFront();

	// We only support for statements for now.
	if (p.front.kind != TokenKind.For) {
		return Status.Error;
	}

	// This is a for.
	string ident;
	ir.Exp exp;
	ir.Node[] nodes;

	// 'for' ident in something.exp
	assert(p.front.kind == TokenKind.For);
	p.popFront();

	// for 'ident' in something.exp
	if (p.front.kind != TokenKind.Identifier) {
		return Status.Error;
	}
	ident = p.front.value;
	p.popFront();

	// for ident 'in' something.exp
	if (p.front.kind != TokenKind.In) {
		return Status.Error;
	}
	p.popFront();

	auto s1 = parseExp(p, out exp);
	if (s1 != Status.Ok) {
		return s1;
	}

	// Check the end.
	if (p.front.kind != TokenKind.CloseStatement) {
		return Status.Error;
	}
	p.popFront();

	while (p.front.kind != TokenKind.End) {
		if (p.front.kind == TokenKind.OpenStatement ||
		    p.lookahead().kind == TokenKind.EndFor) {
			break;
		}
		ir.Node n;
		auto s2 = parseNode(p, out n);
		if (s2 != Status.Ok) {
			return s2;
		}

		nodes ~= n;
	}

	if (p.front.kind == TokenKind.End) {
		return Status.Error;
	}

	// Pop {% endfor
	p.popFront();
	p.popFront();

	// Check for %}
	if (p.front.kind != TokenKind.CloseStatement) {
		return Status.Error;
	}

	p.popFront();

	node = bFor(ident, exp, nodes);
	return Status.Ok;
}

Status parseExp(Parser p, out ir.Exp exp)
{
	if (p.front.kind != TokenKind.Identifier) {
		return Status.Error;
	}

	exp = bIdent(p.front.value);
	p.popFront();

	while (true) {
		switch (p.front.kind) with (TokenKind) {
		case Dot:
			p.popFront();
			if (p.front.kind != TokenKind.Identifier) {
				return Status.Error;
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
