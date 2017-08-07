// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to generate brief comments from full vdoc doccomments.
module diode.vdoc.brief;

import watt.markdown.ast;
import watt.markdown.parser;
import watt.text.sink : Sink, StringSink;


fn generateAutoBrief(str: string) string
{
	sink: StringSink;
	doc := parse(str);
	bd := new PlainText();
	accept(doc, bd, sink.sink);
	return sink.toString();
}

/*!
 * A Markdown visitor that removes all special formating.
 *
 * Stops outputing after the first text paragraph has been
 * processed or any other block is encountred paragraph.
 */
class PlainText : Visitor
{
private:
	mStopped: bool;
	mSoftbreak: bool;


public:
	override fn visit(n: Text, sink: Sink)
	{
		if (mStopped) {
			return;
		}

		if (mSoftbreak) {
			sink(" ");
			mSoftbreak = false;
		}

		sink(n.str);
	}

	override fn visit(n: Softbreak, sink: Sink)
	{	
		mSoftbreak = true;
	}

	override fn visit(n: Linebreak, sink: Sink)
	{
		if (mStopped) {
			return;
		}

		mSoftbreak = false;
		sink("\n");
	}

	override fn enter(n: BlockQuote, sink: Sink) { mStopped = true; }
	override fn enter(n: Item, sink: Sink) { mStopped = true; }
	override fn enter(n: List, sink: Sink) { mStopped = true; }
	override fn enter(n: Heading, sink: Sink) { mStopped = true; }
	override fn leave(n: Paragraph, sink: Sink) { mStopped = true; }

	override fn enter(n: Document, sink: Sink) { }
	override fn enter(n: Image, sink: Sink) { }
	override fn enter(n: Paragraph, sink: Sink) { }
	override fn enter(n: Strong, sink: Sink) { }
	override fn enter(n: Emph, sink: Sink) { }
	override fn enter(n: Link, sink: Sink) { }

	override fn leave(n: Document, sink: Sink) { }
	override fn leave(n: Strong, sink: Sink) { }
	override fn leave(n: Emph, sink: Sink) { }
	override fn leave(n: Image, sink: Sink) { }
	override fn leave(n: Link, sink: Sink) { }
	override fn leave(n: Heading, sink: Sink) { }
	override fn leave(n: Item, sink: Sink) { }
	override fn leave(n: List, sink: Sink) { }
	override fn leave(n: BlockQuote, sink: Sink) { }

	override fn visit(n: HtmlBlock, sink: Sink) { }
	override fn visit(n: CodeBlock, sink: Sink) { }
	override fn visit(n: ThematicBreak, sink: Sink) { }
	
	override fn visit(n: Code, sink: Sink) { }
	override fn visit(n: HtmlInline, sink: Sink) { }
}
