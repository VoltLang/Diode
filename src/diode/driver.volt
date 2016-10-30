// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.driver;

import watt.io;
import watt.path;
import watt.conv;
import watt.text.sink;
import watt.text.source;
import watt.text.markdown;

import ir = diode.ir;
import diode.eval;
import diode.errors;
import diode.interfaces;
import diode.parser : parseFile = parse;
import diode.parser.header : Header, parseHeader = parse;
import diode.doc.volt;


/**
 * Main focal point of Diode.
 */
class DiodeDriver : Driver
{
protected:
	mLayouts : File[string];
	mRoot : Set;
	mSite : Set;
	mDoc : Set;
	mModules : Array;


public:
	this(settings : Settings)
	{
		super(settings);
		buildRootEnv();
	}

	override fn addLayout(source : string, filename : string)
	{
		base := baseName(filename);
		ext := getAndCheckExt(ref base);

		src := new Source(source, filename);
		f := new File();
		f.ext = ext;
		f.filename = base;
		f.header = parseHeader(src);
		f.file = parseFile(src);
		f.layout = getLayoutForFile(f);

		mLayouts[base] = f;
	}

	override fn renderFile(source : string, filename : string)
	{
		base := baseName(filename);
		ext := getAndCheckExt(ref base);

		src := new Source(source, filename);
		f := new File();
		f.ext = ext;
		f.filename = base;
		f.header = parseHeader(src);
		f.file = parseFile(src);
		f.layout = getLayoutForFile(f);

		renderFile(f);
	}

	override fn addDoc(source : string, filename : string)
	{
		mModules.vals ~= parse(source);
	}

protected:
	fn renderFile(f : File)
	{
		e := new Engine(mRoot);
		// For layout we modify the enviroment.
		env := mRoot;

		while (f.layout !is null) {
			c := selectType(f.layout, f);
			c.engine = e;
			c.file = f.file;
			c.env = env;

			env = new Set();
			env.parent = mRoot;
			env.ctx["content"] = c;

			f = f.layout;
		}

		// Update the enviroment.
		e.env = env;

		s : StringSink;
		f.file.accept(e, s.sink);
		writefln("%s", s.toString());
	}

protected:
	fn getLayoutForFile(f : File) File
	{
		assert(f !is null);

		l: File;
		key := f.getOption("layout");
		if (key is null) {
			return null;
		}

		l = getLayout(key);
		if (l is null) {
			throw makeLayoutNotFound(f.filename, key);
		}

		return l;
	}

	fn selectType(layout : File, contents : File) Contents
	{
		if (layout.ext == File.Ext.HTML &&
		    contents.ext == File.Ext.Markdown) {
			return new MarkdownContents();

		} else if (layout.ext == File.Ext.HTML &&
		           contents.ext == File.Ext.HTML) {
			return new Contents();

		} else if (layout.ext == File.Ext.Markdown &&
		           contents.ext == File.Ext.Markdown) {
			return new Contents();
		}

		throw makeConversionNotSupported(layout.filename,
		                                 contents.filename);
	}

	fn getAndCheckExt(ref base : string) File.Ext
	{
		ext := extension(base);
		if (ext is null) {
			throw makeNoExtension(base);
		}

		// Remove the extension.
		base = base[0 .. $ - ext.length];

		switch (toLower(ext)) {
		case ".html":
			return File.Ext.HTML;
		case ".md":
			return File.Ext.Markdown;
		default:
			throw makeExtensionNotSupported(base);
		}
	}

	fn getLayout(key : string) File
	{
		ret := key in mLayouts;
		if (ret is null) {
			return null;
		} else {
			return *ret;
		}
	}

	fn buildRootEnv()
	{
		mDoc = new Set();
		mRoot = new Set();
		mSite = new Set();
		mModules = new Array(null);

		mRoot.ctx["doc"] = mDoc;
		mRoot.ctx["site"] = mSite;

		mDoc.ctx["modules"] = mModules;

		mSite.ctx["baseurl"] = new Text(settings.url);
	}
}

/**
 * A file to be rendered. Used for includes and layouts as well.
 */
class File
{
public:
	enum Ext
	{
		HTML,
		Markdown,
	}

	filename : string;
	layout : File;
	header : Header;
	file : ir.File;
	ext : Ext;


public:
	fn getOption(key : string, def : string = null) string
	{
		if (header is null) {
			return def;
		}

		ret := key in header.map;
		if (ret is null) {
			return def;
		} else {
			return *ret;
		}
	}
}

/**
 * Special Value for the contents value.
 */
class Contents : Value
{
public:
	engine : Engine;
	file : ir.File;
	env : Set;


public:
	override fn toText(n : ir.Node, sink : Sink)
	{
		// Save the old enviroment.
		old := engine.env;
		engine.env = env;

		file.accept(engine, sink);

		// Restore old enviroment.
		engine.env = old;
	}
}

/**
 * Special Value for Markdown to HTML contents.
 */
class MarkdownContents : Contents
{
public:
	override fn toText(n : ir.Node, sink : Sink)
	{
		// Save the old enviroment.
		old := engine.env;
		engine.env = env;

		dst : StringSink;
		file.accept(engine, dst.sink);

		// Restor old enviroment.
		engine.env = old;

		filterMarkdown(sink, dst.toString());
	}
}
