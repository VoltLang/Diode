// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
//! Code to generate brief comments from full vdoc doccomments.
module diode.vdoc.brief;

import watt.text.sink : Sink, StringSink;
import watt.text.html : htmlEscape, htmlUnescape;
import watt.text.format : format;
import watt.text.source : SimpleSource;
import watt.text.ascii : isWhite;

import watt.markdown.ast;
import watt.markdown.parser;


fn generateAutoBrief(str: string) string
{
	sink: StringSink;
	doc := parse(str);
	// Default line limit is 70.
	bd := new PlainText(70);
	accept(doc, bd, sink.sink);
	return sink.toString();
}

/*!
 * A Markdown visitor that removes most of the special formating.
 *
 * Stops outputing after the first text paragraph has been
 * processed or any other block is encountred paragraph.
 */
class PlainText : Visitor
{
protected:
	//! Have we stopped processing text.
	mStopped: bool;
	//! Used to insert spaces between words and instead of softbreaks.
	mWriteSpace: bool;
	//! The current link that has not yet been flushed to the sink.
	mNewLink: Link;
	//! Link that has been flushed to the sink, and should be closed.
	mAppliedLink: Link;
	//! The current length of the line we are writing.
	mLineLength: size_t;
	//! Limit for the number of characters on a line.
	mLineLimit: size_t;


public:
	/*!
	 * @Param lineLimit The number of characters that we should limit the
	 *                  lines we write to the sink to.
	 */
	this(lineLimit: size_t)
	{
		mLineLimit = lineLimit;
	}

	override fn visit(n: Text, sink: Sink)
	{
		writeText(n.str, sink);
	}

	override fn visit(n: Code, sink: Sink)
	{
		writeText(n.str, sink);
	}

	override fn visit(n: Softbreak, sink: Sink)
	{	
		// Instead of newline write a space character.
		mWriteSpace = true;
	}

	override fn visit(n: Linebreak, sink: Sink)
	{
		if (mStopped) {
			return;
		}

		insertNewLine(sink);
	}

	override fn enter(n: Link, sink: Sink)
	{
		if (mStopped) {
			return;
		}

		assert(mNewLink is null);
		assert(mAppliedLink is null);
		mNewLink = n;
	}

	override fn leave(n: Link, sink: Sink)
	{
		if (mStopped) {
			return;
		}

		assert(mNewLink is n || mAppliedLink is n);
		if (mAppliedLink !is null) {
			sink("</a>");
		}

		mNewLink = null;
		mAppliedLink = null;
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

	override fn leave(n: Document, sink: Sink) { }
	override fn leave(n: Strong, sink: Sink) { }
	override fn leave(n: Emph, sink: Sink) { }
	override fn leave(n: Image, sink: Sink) { }
	override fn leave(n: Heading, sink: Sink) { }
	override fn leave(n: Item, sink: Sink) { }
	override fn leave(n: List, sink: Sink) { }
	override fn leave(n: BlockQuote, sink: Sink) { }

	override fn visit(n: HtmlBlock, sink: Sink) { }
	override fn visit(n: CodeBlock, sink: Sink) { }
	override fn visit(n: ThematicBreak, sink: Sink) { }
	override fn visit(n: HtmlInline, sink: Sink) { }


protected:
	/*!
	 * Write a string to the sink, will compact whitespace and insert
	 * newlines when the line will break the
	 * @ref diode.vdoc.brief.PlainText.mLineLimit.
	 */
	final fn writeText(str: string, sink: Sink)
	{
		if (mStopped) {
			return;
		}

		src: SimpleSource;
		src.source = str;

		// All this work so we can turn any whitespace
		// into a single space ` ` character.
		while (!src.empty) {

			// Eat all whitespace, if we have written make the
			// flushThings function output a space character.
			if (src.eatWhitespace() > 0 && mLineLength > 0) {
				mLineLength++;
				mWriteSpace = true;
			}

			// Get the word and insert a newline if the
			// line becomes too long.
			word := src.getNonWhite();
			if (mLineLength != 0 &&
			    mLineLength + word.length > mLineLimit) {
				insertNewLine(sink);
			}

			// Flush spaces and links.
			flushThings(sink);

			// Finaly write the word and increment line length.
			sink(word);
			mLineLength += word.length;
		}
	}

	//! Flushes spaces and links to the sink.
	final fn flushThings(sink: Sink)
	{
		if (mWriteSpace) {
			sink(" ");
			mWriteSpace = false;
		}

		if (mNewLink !is null) {
			url := htmlEscape(mNewLink.url);
			format(sink, "<a class=\"code\" href=\"%s\">", url);
			mAppliedLink = mNewLink;
			mNewLink = null;
		}
	}

	//! Inserts a newline and resets link.
	final fn insertNewLine(sink: Sink)
	{
		// If we have a link applied, stop it and
		// restart it on the next line.
		if (mAppliedLink !is null) {
			sink("</a>");
			mNewLink = mAppliedLink;
			mAppliedLink = null;
		}

		sink("\n");
		mWriteSpace = false;
		mLineLength = 0;
	}
}


private:

fn eatWhitespace(ref src: SimpleSource) size_t
{
	count: size_t;
	while (src.front.isWhite() && !src.empty) {
		count++;
		src.popFront();
	}
	return count;
}

fn getNonWhite(ref src: SimpleSource) string
{
	mark := src.save();

	while (!src.front.isWhite() && !src.empty) {
		src.popFront();
	}

	return src.sliceFrom(mark);
}
