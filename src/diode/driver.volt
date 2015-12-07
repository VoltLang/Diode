// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
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


/**
 * Main focal point of Diode.
 */
class DiodeDriver : Driver
{
protected:
	File[string] mLayouts;
	Set mRoot;
	Set mSite;

public:
	this(Settings settings)
	{
		super(settings);
		buildRootEnv();
	}

	override void addLayout(string source, string filename)
	{
		auto base = baseName(filename);
		auto ext = getAndCheckExt(ref base);



		auto src = new Source(source, filename);
		auto f = new File();
		f.ext = ext;
		f.filename = base;
		f.header = parseHeader(src);
		f.file = parseFile(src);
		f.layout = getLayoutForFile(f);

		mLayouts[base] = f;
	}

	override void renderFile(string source, string filename)
	{
		auto base = baseName(filename);
		auto ext = getAndCheckExt(ref base);

		auto src = new Source(source, filename);
		auto f = new File();
		f.ext = ext;
		f.filename = base;
		f.header = parseHeader(src);
		f.file = parseFile(src);
		f.layout = getLayoutForFile(f);

		renderFile(f);
	}

protected:
	void renderFile(File f)
	{
		auto e = new Engine(mRoot);
		// For layout we modify the enviroment.
		Set env = mRoot;

		while (f.layout !is null) {
			auto c = selectType(f.layout, f);
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

		StringSink s;
		f.file.accept(e, s.sink);
		writefln("%s", s.toString());
	}

protected:
	File getLayoutForFile(File f)
	{
		assert(f !is null);
		bool must = false;

		auto key = f.getOption("layout");
		if (key is null) {
			key = settings.layoutDefault;
		} else {
			must = true;
		}

		assert(key !is null);

		auto l = getLayout(key);
		if (l is null && must) {
			throw makeLayoutNotFound(f.filename, key);
		}
		return l;
	}

	Contents selectType(File layout, File contents)
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

	File.Ext getAndCheckExt(ref string base)
	{
		auto ext = extension(base);
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

	File getLayout(string key)
	{
		auto ret = key in mLayouts;
		if (ret is null) {
			return null;
		} else {
			return *ret;
		}
	}

	void buildRootEnv()
	{
		mRoot = new Set();
		mSite = new Set();
		mRoot.ctx["site"] = mSite;
		mSite.ctx["baseurl"] = new Text(settings.url);

		hackInbuilt(mSite);
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

	string filename;
	File layout;
	Header header;
	ir.File file;
	Ext ext;

public:
	string getOption(string key, string def = null)
	{
		if (header is null) {
			return def;
		}

		auto ret = key in header.map;
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
	Engine engine;
	ir.File file;
	Set env;

public:
	override void toText(ir.Node n, Sink sink)
	{
		// Save the old enviroment.
		auto old = engine.env;
		engine.env = env;

		file.accept(engine, sink);

		// Restor old enviroment.
		engine.env = old;
	}
}

/**
 * Special Value for Markdown to HTML contents.
 */
class MarkdownContents : Contents
{
public:
	override void toText(ir.Node n, Sink sink)
	{
		// Save the old enviroment.
		auto old = engine.env;
		engine.env = env;

		StringSink dst;
		file.accept(engine, dst.sink);

		// Restor old enviroment.
		engine.env = old;

		filterMarkdown(sink, dst.toString());
	}
}

/**
 * Temporary hack.
 */
void hackInbuilt(Set site)
{
	auto p1 = new Set();
	p1.ctx["title"]   = new Text("The Title");
	p1.ctx["content"] = new Text("the content");
	auto p2 = new Set();
	p2.ctx["title"]   = new Text("Another Title");
	p2.ctx["content"] = new Text("the content");
	auto p3 = new Set();
	p3.ctx["title"]   = new Text("The last Title");
	p3.ctx["content"] = new Text("the content");
	site.ctx["posts"] = new Array(p1, p2, p3);
}
