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

/// Helper alias to make typing easier.
alias tk = TokenKind;

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

	/**
	 * Returns the current token.
	 *
	 * Side-effects:
	 *   None.
	 */
	final @property Token front()
	{
		return mTokens[mIndex];
	}

	/**
	 * Returns the following token.
	 *
	 * Side-effects:
	 *   None.
	 */
	final @property Token following()
	{
		return lookahead(1);
	}

	/**
	 * Advances the stream by one, will clamp to the last token.
	 *
	 * Side-effects:
	 *   Icrements mIndex.
	 */
	void popFront()
	{
		mIndex++;
		if (mIndex >= mTokens.length) {
			mIndex = mTokens.length - 1;
		}
	}

	/**
	 * Returns the token n steps into the stream, will clamp to length.
	 *
	 * Side-effects:
	 *   None.
	 */
	final Token lookahead(size_t n)
	{
		size_t i = mIndex + n;
		if (i >= mTokens.length) {
			return mTokens[$ - 1];
		}
		return mTokens[i];
	}
}

Status parseFile(Parser p, out ir.File file)
{
	if (p.front != tk.Begin) {
		return Status.Error;
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
		return Status.Error;
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
		return Status.Error;
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
		return Status.Error;
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
		return Status.Error;
	}
	ident = p.front.value;
	p.popFront();

	// for ident 'in' something.exp
	if (p.front != tk.In) {
		return Status.Error;
	}
	p.popFront();

	auto s1 = parseExp(p, out exp);
	if (s1 != Status.Ok) {
		return s1;
	}

	// Check the end.
	if (p.front != tk.CloseStatement) {
		return Status.Error;
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
		return Status.Error;
	}

	// Pop {% endfor
	p.popFront();
	p.popFront();

	// Check for %}
	if (p.front != tk.CloseStatement) {
		return Status.Error;
	}

	p.popFront();

	node = bFor(ident, exp, nodes);
	return Status.Ok;
}

Status parseExp(Parser p, out ir.Exp exp)
{
	if (p.front != tk.Identifier) {
		return Status.Error;
	}

	exp = bIdent(p.front.value);
	p.popFront();

	while (true) {
		switch (p.front.kind) with (TokenKind) {
		case Dot:
			p.popFront();
			if (p.front != tk.Identifier) {
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
