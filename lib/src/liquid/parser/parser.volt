// Copyright © 2015-2018, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module liquid.parser.parser;

import watt.conv : toDouble;
import watt.text.source : Source;
import watt.text.utf : encode;
import watt.text.sink : StringSink;
import watt.text.ascii : isAlpha, isAlphaNum, isWhite, isDigit;
import watt.text.string : stripRight;
import watt.text.format;

import ir = liquid.ir;

import liquid.util.build : bFile, bText, bPrint, bIf, bFor, bAssign, bInclude,
	bAccess, bIdent, bFilter, bStringLiteral, bBoolLiteral, bClosingTagNode,
	bNumberLiteral, bBinOp, bIndex;
import liquid.util.sink : NodeSink;
import liquid.eval.engine;
import liquid.parser.errors;


class Parser
{
public:
	enum State
	{
		Text,
		Print,
		Statement,
		End,
	}


public:
	state: State;
	src: Source;
	sink: StringSink;
	/*!
	 * A description of an error for the user's consumption.
	 *
	 * This should only be set if the function in question
	 * is actually encountering the error in question.
	 * That is to say, parseStatement should say if it sees
	 * 'four' instead of 'for', but a function calling parseStatement
	 * should not set the error message if parseStatement fails.
	 *
	 * Just a field for now, but in the future this could
	 * become a property that adds to a list of messages.
	 */
	errorMessage: string;
	raw: bool;


public:
	this(src: Source)
	{
		this.state = State.Text;
		this.src = src;
	}

	//! Given a state in which we expect a two char string, skip it.
	fn eatSequence(s: string) Status
	{
		assert(s.length == 2);
		if (src.front != s[0] && src.following != s[1]) {
			return this.errorExpected(s, format("%s%s", src.front, src.following));
		}
		src.popFrontN(2);
		return Status.Ok;
	}

	//! Parse an identifier name into sink.
	fn eatIdent()
	{
		while (!src.eof && isIdentName(src.front)) {
			dchar c = src.front;
			src.popFront();
			sink.sink(encode(c));
		}
	}

	/*!
	 * If the parser is at the given word, return true.
	 * No characters are consumed.
	 */
	fn atWord(s: string) bool
	{
		eof: bool;
		size_t i;
		while (src.lookahead(i, out eof).isWhite()) {
			i++;
		}
		foreach (j, c: dchar; s) {
			if (src.lookahead(i++, out eof) != c) {
				return false;
			}
		}
		return true;
	}

	//! Parse a include name into sink.
	fn eatIncludeName()
	{
		while (!src.eof && isIncludeName(src.front)) {
			dchar c = src.front;
			src.popFront();
			sink.sink(encode(c));
		}
	}

	//! Get the contents of the sink, and then reset it.
	fn getSink() string
	{
		s := sink.toString();
		sink.reset();
		return s;
	}
}

enum Status
{
	Ok = 0,
	Error = -1,
}

fn parse(src: Source, e: Engine) ir.File
{
	// This is a file.
	file: ir.File;

	p := new Parser(src);
	if (err := p.parseFile(out file)) {
		str := format("%s: syntax error%s", p.src.loc.toString(),
			p.errorMessage.length > 0 ? ": " ~ p.errorMessage : "");
		e.handleError(str);  //!< @todo Actual errors.
	}

	return file;
}

//! Parse a liquid file.
fn parseFile(p: Parser, out file: ir.File) Status
{
	dummy: string;
	file = bFile();
	return p.parseNodesUntilTag(out file.nodes, out dummy, cast(string[])null);
}

/*!
 * Parse nodes until we hit a {% <name> %}.
 * If name is 'elsif', the If node will be placed at the end of nodes.
 */
fn parseNodesUntilTag(p: Parser, out nodes: ir.Node[], out nameThatEnded: string, names: string[]...) Status
{
	ns: NodeSink;

	lookingForElsif := false;
	foreach (name; names) {
		if (name == "elsif") {
			lookingForElsif = true;
			break;
		}
	}

	while (!p.src.eof) {
		// Try to parse a node.
		node: ir.Node;
		if (err := p.parseNode(out node)) {
			return err;
		}

		// Text might return null on empty text.
		if (node is null) {
			continue;
		}

		if (lookingForElsif) {
			ifn := cast(ir.If)node;
			if (ifn !is null && ifn.elsif) {
				ns.push(node);
				nameThatEnded = "elsif";
				nodes = ns.takeArray();
				return Status.Ok;
			}
		}

		// Is this a closing tag.
		ctn := cast(ir.ClosingTagNode)node;
		if (ctn is null) {
			ns.push(node);
			continue;
		}

		// Is the closing tag in the names we are looking for?
		foreach (name; names) {
			if (name != ctn.name) {
				continue;
			}

			nameThatEnded = name;
			nodes = ns.takeArray();
			return Status.Ok;
		}

		// A stray closing tag node, error.
		return p.errorUnmatchedClosingTag(ctn.name);
	}

	// Not looking for end tags.
	if (names.length == 0) {
		nodes = ns.takeArray();
		return Status.Ok;
	}

	// We are now at end of file and have not found the end node, error.
	return p.errorMissingTagEOF(names);
}

//! Parse the individual elements of the file until we run out of file.
fn parseNode(p: Parser, out node: ir.Node) Status
{
	final switch (p.state) with (Parser.State) {
	case Text:
		return p.parseText(out node);
	case Print:
		return p.parsePrint(out node);
	case Statement:
		return p.parseStatement(out node);
	case End:
		break;
	}

	return Status.Ok;
}

// Returns true if the next tag parsed will be {% endraw %}
fn atEndRaw(p: Parser) bool
{
	if (p.src.front != '%') {
		return false;
	}
	i: size_t = 1;
	eof: bool;
	if (p.src.lookahead(i, out eof) == '-') {
		i++;
	}
	while (p.src.lookahead(i, out eof).isWhite()) {
		i++;
	}
	endrawstr := "endraw";
	foreach (c: dchar; endrawstr) {
		if (p.src.lookahead(i++, out eof) != c) {
			return false;
		}
	}
	while (p.src.lookahead(i, out eof).isWhite()) {
		i++;
	}
	if (p.src.lookahead(i, out eof) == '-') {
		i++;
	}
	if (p.src.lookahead(i++, out eof) != '%') {
		return false;
	}
	return p.src.lookahead(i++, out eof) == '}';
}

//! Parse regular text until we find a tag, or run out of text.
fn parseText(p: Parser, out text: ir.Node) Status
{
	while (!p.src.eof) {
		dchar c = p.src.front;
		p.src.popFront();

		// Keep consuming text until we find a '{'.
		if (c != '{' || (p.raw && !p.atEndRaw())) {
			p.sink.sink(encode(c));
			continue;
		}

		// Consume.
		c = p.src.front;
		p.src.popFront();

		// Is this really a directive.
		switch (c) {
		case '{':
			p.state = Parser.State.Print;
			break;
		case '%':
			p.state = Parser.State.Statement;
			break;
		default:
			// We didn't add this before so add it here.
			p.sink.sink(encode('{'));
			p.sink.sink(encode(c));
			continue;
		}

		// Get the text we have accumulated.
		txt := p.getSink();

		// Does this end with a hyphen, like '{{-' and '{%-'?
		if (p.ifAndSkip('-')) {
			txt = stripRight(txt);
		}

		// If there is no text no need to create a text node.
		if (txt.length > 0) {
			text = bText(txt);
		}

		return Status.Ok;
	}

	// Get the text we have accumulated.
	txt := p.getSink();
	if (txt.length > 0) {
		text = bText(txt);
	}

	// Setup state.
	p.state = Parser.State.End;
	return Status.Ok;
}

//! Parse {{ ... }}.
fn parsePrint(p: Parser, out print: ir.Node) Status
{
	// This is a print.
	exp: ir.Exp;

	// {{ 'exp' }}
	if (err := p.parseExp(out exp)) {
		return err;
	}

	// We're done with the expression, parse the closing }}, and hyphen.
	if (err := p.parseClosePrint()) {
		return err;
	}

	print = bPrint(exp);
	return Status.Ok;
}


/*
 *
 * Expression parsing functions.
 *
 */

//! Parse an entire Exp expression.
fn parseExp(p: Parser, out exp: ir.Exp, justOneExpression: bool = false) Status
{
	// Advance to the next character.
	p.src.skipWhitespace();

	fn atExpEnd() bool
	{
		return p.atWord("%}") || p.atWord("-%}") || p.atWord("}}") || p.atWord("-}}");
	}

	first := true;
	do {
		p.src.skipWhitespace();
		if (first) {
			first = false;
		} else {
			switch (p.src.front) {
			case '.':
				// Eat the character and parse a expression.
				p.src.popFront();
				if (err := p.parseAccess(exp, out exp)) {
					return err;
				}
				continue;
			case '[':
				p.src.popFront();
				index: ir.Exp;
				if (err := p.parseExp(out index, true)) {
					return err;
				}
				p.src.skipWhitespace();
				if (p.src.front != ']') {
					return p.errorExpected(']', p.src.front);
				}
				p.src.popFront();
				exp = bIndex(exp, index);
				continue;
			case '|':
				// Filter matches to outer most expression.
				if (justOneExpression) {
					break;
				}

				// Eat the character and parse a expression.
				p.src.popFront();
				if (err := p.parseFilter(exp, out exp)) {
					return err;
				}
				continue;
			case '=', '!':
				if (justOneExpression) {
					break;
				}

				firstChar := p.src.front;
				p.src.popFront();
				if (p.src.front != '=') {
					return p.errorExpected("=", encode(p.src.front));
				}
				p.src.popFront();
				p.src.skipWhitespace();
				r: ir.Exp;
				if (err := p.parseExp(out r, true)) {
					return err;
				}
				assert(r !is null);
				exp = bBinOp(firstChar == '=' ? ir.BinOp.Type.Equal : ir.BinOp.Type.NotEqual,
					exp, r);
				continue;
			case '<', '>':
				if (justOneExpression) {
					break;
				}

				firstChar := p.src.front;
				p.src.popFront();
				equals := p.src.front == '=';
				type: ir.BinOp.Type;
				if (firstChar == '<') {
					type = equals ? ir.BinOp.Type.LessThanOrEqual :
						ir.BinOp.Type.LessThan;
				} else {
					type = equals ? ir.BinOp.Type.GreaterThanOrEqual :
						ir.BinOp.Type.GreaterThan;
				}
				if (equals) {
					p.src.popFront();
				}
				r: ir.Exp;
				if (err := p.parseExp(out r, true)) {
					return err;
				}
				exp = bBinOp(type, exp, r);
				break;
			default:
				break;
			}
		}

		if (atExpEnd()) {
			break;
		}

		word: string;
		if (p.src.front == '"' || p.src.front == '\'') {
			if (err := p.parseStringLiteral(out exp)) {
				return err;
			}
		} else if (p.src.front == '-' || p.src.front == '.' || isDigit(p.src.front)) {
			if (err := p.parseNumberLiteral(out exp)) {
				return err;
			}
			p.src.skipWhitespace();
		} else {
			p.eatIdent();
			word = p.getSink();
			if (word.length == 0) {
				return p.errorExpectedIdentifier();
			}
		}

		if ((word == "or" || word == "and" || word == "contains") && !justOneExpression) {
			r: ir.Exp;
			if (err := p.parseExp(out r, false)) {
				return err;
			}
			t: ir.BinOp.Type;
			switch (word) {
			case "or": t = ir.BinOp.Type.Or; break;
			case "and": t = ir.BinOp.Type.And; break;
			case "contains": t = ir.BinOp.Type.Contains; break;
			default: assert(false);
			}
			exp = bBinOp(t, exp, r);
		} else if (word.length > 0) {
			// This is a ident or a BoolLiteral.
			exp = word.makeIdentOrBool();
		}

		// Advance to the next character for the while loop.
		p.src.skipWhitespace();
	} while (!p.src.eof && (!justOneExpression || p.src.front == '.') && !atExpEnd());
	return Status.Ok;
}

fn parseNumberLiteral(p: Parser, out exp: ir.Exp) Status
{
	if (p.src.front == '-') {
		p.sink.sink("-");
		p.src.popFront();
	}
	integer := true;
	while (!p.src.eof && (isDigit(p.src.front) || p.src.front == '.')) {
		if (p.src.front == '.') {
			integer = false;
		}
		p.sink.sink(encode(p.src.front));
		p.src.popFront();
	}

	val := toDouble(p.getSink());
	exp = bNumberLiteral(val, integer);
	return Status.Ok;
}

fn parseStringLiteral(p: Parser, out exp: ir.Exp) Status
{
	terminator := p.src.front;
	p.src.popFront();
	while (!p.src.eof && p.src.front != terminator) {
		p.sink.sink(encode(p.src.front));
		p.src.popFront();
	}
	p.src.popFront();

	// Zero length string literals are okay, no need to check.
	exp = bStringLiteral(p.getSink());
	return Status.Ok;
}

//! Parse an Access expression.
fn parseAccess(p: Parser, child: ir.Exp, out exp: ir.Exp) Status
{
	// This is a ident expression.
	ident: string;

	// 'ident'
	if (err := p.parseIdent(out ident)) {
		return err;
	}

	exp = bAccess(child, ident);
	return Status.Ok;
}

//! Parse a Filter expression.
fn parseFilter(p: Parser, child: ir.Exp, out exp: ir.Exp) Status
{
	// This is a filter expression.
	ident: string;
	args: ir.Exp[];

	// | 'ident': args
	if (err := p.parseIdent(out ident)) {
		return err;
	}

	// | ident': args'
	if (err := p.parseFilterArgs(out args)) {
		return err;
	}

	exp = bFilter(child, ident, args);
	return Status.Ok;
}

//! Parse Filter arguments (if any).
fn parseFilterArgs(p: Parser, out args: ir.Exp[]) Status
{
	p.src.skipWhitespace();

	if (!p.ifAndSkip(':')) {
		return Status.Ok;
	}

	do {
		exp: ir.Exp;
		if (err := parseExp(p:p, exp:out exp, justOneExpression:true)) {
			return err;
		}
		args ~= exp;

		p.src.skipWhitespace();
	} while (p.ifAndSkip(','));

	return Status.Ok;
}


/*
 *
 * Statement parsing functions.
 *
 */

//! Parse a statement.
fn parseStatement(p: Parser, out node: ir.Node) Status
{
	name: string;

	// Parse the starting ident.
	if (err := p.parseIdent(out name)) {
		return err;
	}

	switch (name) {
	case "assign":
		return p.parseAssign(out node);
	case "include":
		return p.parseInclude(out node);
	case "comment":
		return parseComment(p);
	case "if":
		return parseIf(p:p, invert:false, node:out node);
	case "elsif":
		return parseElsIf(p:p, node:out node);
	case "unless":
		return parseIf(p:p, invert:true, node:out node);
	case "for":
		return p.parseFor(out node);
	case "raw":
		return p.parseRaw(out node);
	case "endif", "else", "endfor", "endunless", "endraw":
		node = bClosingTagNode(name);
		return p.parseCloseStatement();
	default:
		return p.errorUnknownStatement(name);
	}
}

fn parseAssign(p: Parser, out node: ir.Node) Status
{
	// This is Assign.
	ident: string;
	exp: ir.Exp;

	// assign 'ident' = exp
	if (err := p.parseIdent(out ident)) {
		return err;
	}

	// assign ident '=' exp
	if (err := p.matchAndSkip('=')) {
		return err;
	}

	// assign ident = 'exp'
	if (err := p.parseExp(out exp)) {
		return err;
	}

	// Parse the close bracket, also handles hyphen.
	if (err := p.parseCloseStatement()) {
		return err;
	}

	node = bAssign(ident, exp);
	return Status.Ok;
}

fn parseInclude(p: Parser, out node: ir.Node) Status
{
	// This is a include.
	name: string;
	assigns: ir.Assign[];

	// include 'file.html' var=exp
	if (err := p.parseIncludeName(out name)) {
		return err;
	}

	// Advance to the next none whitespace char.
	p.src.skipWhitespace();

	// include file.html 'var=exp'
	while (isAlpha(p.src.front)) {
		exp: ir.Exp;
		ident: string;

		// assign 'ident' = exp
		if (err := p.parseIdent(out ident)) {
			return err;
		}

		// assign ident '=' exp
		if (err := p.matchAndSkip('=')) {
			return err;
		}

		// assign ident = 'exp'
		if (err := p.parseExp(out exp, true)) {
			return err;
		}

		assigns ~= bAssign(ident, exp);

		// Need to advance to the next none whitespace char.
		p.src.skipWhitespace();
	}

	// Parse the close bracket, also handles hyphen.
	if (err := p.parseCloseStatement()) {
		return err;
	}

	node = bInclude(name, assigns);
	return Status.Ok;
}

fn parseElsIf(p: Parser, out node: ir.Node) Status
{
	parseIf(p, false, out node);
	ifn := cast(ir.If)node;
	ifn.elsif = true;
	return Status.Ok;
}

fn parseIf(p: Parser, invert: bool, out node: ir.Node) Status
{
	// This is a if.
	exp: ir.Exp;
	thenNodes: ir.Node[];
	elseNodes: ir.Node[];

	// if 'exp'
	if (err := p.parseExp(out exp)) {
		return err;
	}

	// Parse the close bracket, also handles hyphen.
	if (err := p.parseCloseStatement()) {
		return err;
	}

	endingTag := invert ? "endunless" : "endif";

	// Parse the nodes in the else body.
	nameThatEnded: string;
	if (err := p.parseNodesUntilTag(out thenNodes, out nameThatEnded, endingTag, "else", "elsif")) {
		return err;
	}

	if (nameThatEnded == "elsif") {
		node = bIf(invert, exp, thenNodes[0 .. $-1], thenNodes[$-1 .. $]);
		return Status.Ok;
	}

	// If endif, we are done.
	if (nameThatEnded == endingTag) {
		node = bIf(invert, exp, thenNodes, elseNodes);
		return Status.Ok;
	}

	// If the then nodes was closed with 'else' also parse else nodes.
	if (err := p.parseNodesUntilTag(out elseNodes, out nameThatEnded, endingTag)) {
		return err;
	}

	node = bIf(invert, exp, thenNodes, elseNodes);
	return Status.Ok;
}

fn parseRaw(p: Parser, out node: ir.Node) Status
{
	// Parse the %}
	if (err := p.parseCloseStatement()) {
		return err;
	}

	// Parse until we hit the endraw tag.
	p.raw = true;
	nameThatEnded: string;
	nodes: ir.Node[];
	if (err := p.parseNodesUntilTag(out nodes, out nameThatEnded, "endraw")) {
		return err;
	}
	p.raw = false;

	if (nodes.length != 1) {
		p.errorMessage = "{% raw %} parsing failure";
		return Status.Error;
	}

	node = nodes[0];
	return Status.Ok;
}

fn parseFor(p: Parser, out node: ir.Node) Status
{
	// This is a for loop.
	name: string;
	exp: ir.Exp;
	nodes: ir.Node[];

	// for 'name' in exp
	if (err := p.parseIdent(out name)) {
		return err;
	}

	// for name 'in' exp
	p.src.skipWhitespace();
	p.eatIdent();
	inWord := p.getSink();
	if (inWord != "in") {
		return p.errorExpected("in", inWord);
	}

	// for name in 'exp'
	if (err := p.parseExp(out exp)) {
		return err;
	}

	// Parse the close bracket, also handles hyphen.
	if (err := p.parseCloseStatement()) {
		return err;
	}

	// Parse children nodes.
	nameThatEnded: string;
	if (err := p.parseNodesUntilTag(out nodes, out nameThatEnded, "endfor")) {
		return err;
	}

	node = bFor(name, exp, nodes);
	return Status.Ok;
}

fn parseComment(p: Parser) Status
{
	p.src.skipWhitespace();

	// No effect, but allowed.
	p.ifAndSkip('-');

	// Close the bracket.
	if (err := p.eatSequence("%}")) {
		return err;
	}

	while (!p.src.eof) {
		if (!p.ifAndSkip('{')) {
			// Need to advance.
			p.src.popFront();
			continue;
		}

		if (!p.ifAndSkip('%')) {
			// Should not advance, consider '{{%'.
			continue;
		}

		// No effect, but allowed.
		p.ifAndSkip('-');

		// We are very generous here with what we allow.
		p.src.skipWhitespace();
		p.eatIdent();
		word := p.getSink();
		if (word != "endcomment") {
			continue;
		}

		// Parse the close bracket, also handles hyphen.
		return p.parseCloseStatement();
	}

	// Ran out of file but the comment wasn't closed, error.
	return p.errorExpectedEndComment();
}


/*
 *
 * Small parser helpers.
 *
 */

/*!
 * This function parses a ident.
 *
 * Include name must start with a alpha or '_' and may contain alpha, '_', or -.
 */
fn parseIdent(p: Parser, out name: string) Status
{
	p.src.skipWhitespace();

	p.eatIdent();
	name = p.getSink();
	if (name.length == 0) {
		return p.errorExpectedIdentifier();
	}

	return Status.Ok;
}

/*!
 * This function parser a include name.
 *
 * Include name must start with a ident or number, may contain alpha numerical,
 * '.' and '/'.
 */
fn parseIncludeName(p: Parser, out name: string) Status
{
	p.src.skipWhitespace();

	p.eatIncludeName();
	name = p.getSink();
	if (name.length == 0) {
		return p.errorExpectedIncludeName();
	}

	return Status.Ok;
}

/*!
 * Parses close statements '%}', handles hyphens.
 */
fn parseCloseStatement(p: Parser) Status
{
	p.src.skipWhitespace();

	// Skip any hyphen.
	hyphen := p.ifAndSkip('-');

	// Check for the closing brackets.
	if (err := p.eatSequence("%}")) {
		return err;
	}

	// If hyphen skip whitespace.
	if (hyphen) {
		p.src.skipWhitespace();
	}

	// Setup state.
	p.state = p.src.eof ? Parser.State.End : Parser.State.Text;
	return Status.Ok;
}

/*!
 * Parses close statements '%}', handles hyphens.
 */
fn parseClosePrint(p: Parser) Status
{
	p.src.skipWhitespace();

	// Skip any hyphen.
	hyphen := p.ifAndSkip('-');

	// Check for the closing brackets.
	if (err := p.eatSequence("}}")) {
		return err;
	}

	// If hyphen skip whitespace.
	if (hyphen) {
		p.src.skipWhitespace();
	}

	// Setup state.
	p.state = p.src.eof ? Parser.State.End : Parser.State.Text;
	return Status.Ok;
}


/*
 *
 * Error raising helpers.
 *
 */

//! Matches and skips a single char from the source, sets error msg.
fn matchAndSkip(p: Parser, c: dchar) Status
{
	p.src.skipWhitespace();

	if (p.ifAndSkip(c)) {
		return Status.Ok;
	}

	return p.errorExpected(c, p.src.front);
}


/*
 *
 * Misc helpers.
 *
 */

//! Returns either a ir.Ident or ir.BoolLiteral.
fn makeIdentOrBool(word: string) ir.Exp
{
	switch (word) {
	case "true": return bBoolLiteral(true);
	case "false": return bBoolLiteral(false);
	default: return bIdent(word);
	}
}

//! Returns true if current character is c and skip it.
fn ifAndSkip(p: Parser, c: dchar) bool
{
	if (p.src.front == c) {
		p.src.popFront();
		return true;
	}
	return false;
}

//! Is the given char a valid character for a include name.
fn isIncludeName(c: dchar) bool
{
	return isAlpha(c) || c == '_' || c == '/' || c == '.';
}

//! Is the given char a valid character for a variable name.
fn isIdentName(c: dchar) bool
{
	return isAlphaNum(c) || c == '_' || c == '-';
}
