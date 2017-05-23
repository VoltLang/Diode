// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.token.token;

import watt.text.source : Location;


/**
 * Holds the kind, the actual string and location within the source file.
 */
final class Token
{
public:
	loc: Location;
	kind: TokenKind;
	value: string;


public:
	final fn opEquals(kind: TokenKind) bool
	{
		return this.kind == kind;
	}

	final fn opEquals(str: string) bool
	{
		return kind == TokenKind.Identifier && value == str;
	}
}

enum TokenKind
{
	None = 0,

	// Special
	Begin,
	End,

	// Control Tokens.
	Text,
	Hyphen,
	OpenPrint,
	ClosePrint,
	OpenStatement,
	CloseStatement,

	// Symbols
	Dot,
	Pipe,
	Comma,
	Assign,

	// Keywords
	Nil,
	True,
	False,
	Identifier,
}

fn identifierKind(ident: string) TokenKind
{
	switch (ident) with (TokenKind) {
	case "nil":   return Nil;
	case "true":  return True;
	case "false": return False;
	default:      return Identifier;
	}
}
