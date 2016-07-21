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
	loc : Location;
	kind : TokenKind;
	value : string;


public:
	final fn opEquals(kind : TokenKind) bool
	{
		return this.kind == kind;
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
	OpenPrint,
	ClosePrint,
	OpenStatement,
	CloseStatement,

	// Symbols
	Dot,
	Pipe,

	// Keywords
	In,
	For,
	EndFor,
	If,
	EndIf,
	Else,
	ElseIf,
	ElseFor,
	Identifier,
}

fn identifierKind(ident : string) TokenKind
{
	switch (ident) with (TokenKind) {
	case "in":      return In;
	case "for":     return For;
	case "endfor":  return EndFor;
	case "if":      return If;
	case "endif":   return EndIf;
	case "else":    return Else;
	case "elseif":  return ElseIf;
	case "elsefor": return ElseFor;
	default:        return Identifier;
	}
}
