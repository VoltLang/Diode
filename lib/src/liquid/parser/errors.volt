// Copyright © 2017-2018, Bernard Helyer.  All rights reserved.
// Copyright © 2015-2018, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module liquid.parser.errors;

import watt.text.sink;
import watt.text.format;

import liquid.parser.parser;


fn errorExpected(p: Parser, expected: dchar, found: dchar) Status
{
	p.errorMessage = format("expected '%s', found '%s'", expected, found);
	return Status.Error;
}

fn errorExpected(p: Parser, expected: string, found: string) Status
{
	p.errorMessage = format("expected '%s', found '%s'", expected, found);
	return Status.Error;
}

fn errorExpectedIdentifier(p: Parser) Status
{
	if (p.src.eof) {
		p.errorMessage = "expected a identifier not end of file";
	} else {
		p.errorMessage = format("expected a identifier not '%s'", p.src.front);
	}
	return Status.Error;
}

fn errorExpectedIncludeName(p: Parser) Status
{
	if (p.src.eof) {
		p.errorMessage = "expected a include name not end of file";
	} else {
		p.errorMessage = format("expected a include name not '%s'", p.src.front);
	}
	return Status.Error;
}

fn errorExpectedEndComment(p: Parser) Status
{
	p.errorMessage = "expected a endcomment tag to close comment not end of file";
	return Status.Error;
}

fn errorUnmatchedClosingTag(p: Parser, name: string) Status
{
	p.errorMessage = format("stray closing tag '%s' found", name);
	return Status.Error;
}

fn errorMissingTagEOF(p: Parser, tags: string[]) Status
{
	emsg: StringSink;
	emsg.sink("expected '");
	foreach (i, tag; tags) {
		emsg.sink(tag);
		emsg.sink("'");
		if (i < tags.length - 1) {
			emsg.sink(", or '");
		}
	}
	emsg.sink(" before the end of the file");
	p.errorMessage = emsg.toString();

	return Status.Error;
}

fn errorUnknownStatement(p: Parser, name: string) Status
{
	p.errorMessage = format("unknown statement '%s'", name);
	return Status.Error;
}
