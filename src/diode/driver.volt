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
import diode.vdoc;


/**
 * Main focal point of Diode.
 */
class DiodeDriver : Driver
{
protected:
	mLayouts: File[string];
	mRoot: Set;
	mSite: Set;
	mDoc: Set;
	mModules: Array;
	mEngine: DriverEngine;


public:
	this(settings: Settings)
	{
		super(settings);
		buildRootEnv();

		mEngine = new DriverEngine(this, mRoot);
	}

	override fn addLayout(source: string, filename: string)
	{
		f := createFile(source, filename);
		mLayouts[f.filename] = f;
	}

	override fn addInclude(source: string, filename: string)
	{
		mEngine.addInclude(createFile(source, filename), filename);
	}

	override fn renderFile(source: string, filename: string) string
	{
		s: StringSink;
		f := createFile(source, filename);
		mEngine.renderFile(f, s.sink);
		return s.toString();
	}

	override fn addDoc(source: string, filename: string)
	{
		mModules.vals ~= parse(source);
	}

	override fn info(fmt: string, ...)
	{
		vl: va_list;
		va_start(vl);
		error.vwritefln(fmt, ref _typeids, ref vl);
		error.flush();
		va_end(vl);
	}


protected:
	fn createFile(source: string, filename: string) File
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

		return f;
	}

	fn getLayoutForFile(f: File) File
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

	fn selectType(layout: File, contents: File) Contents
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

	fn getAndCheckExt(ref base: string) File.Ext
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

	fn getLayout(key: string) File
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
 *
 */
class DriverEngine : Engine
{
private:
	mDrv: DiodeDriver;
	mRoot: Set;
	mIncludes: File[string];


public:
	this(d: DiodeDriver, root: Set)
	{
		super(root);

		mDrv = d;
		mRoot = root;
	}

	fn addInclude(f: File, filename: string)
	{
		base := baseName(filename);
		mIncludes[base] = f;
	}

	fn renderFile(f: File, sink: Sink)
	{
		// We always create a new env for each file.
		env := new Set();
		env.parent = mRoot;

		while (f.layout !is null) {
			c := mDrv.selectType(f.layout, f);
			c.engine = this;
			c.file = f.file;
			c.env = env;

			env = new Set();
			env.parent = mRoot;
			env.ctx["content"] = c;

			f = f.layout;
		}

		// Update the enviroment.
		this.env = env;

		f.file.accept(this, sink);
	}

	override fn visit(p: ir.Include, sink: Sink) Status
	{
		ret := p.filename in mIncludes;
		if (ret is null) {
			mDrv.info("no such include '%s'", p.filename);
			return Continue;
		}

		f := *ret;


		include := new Set();
		foreach (a; p.assigns) {
			a.exp.accept(this, sink);
			include.ctx[a.ident] = this.v;
			v = null;
		}

		old := env;

		env = new Set();
		env.parent = mRoot;
		env.ctx["include"] = include;

		f.file.accept(this, sink);

		env = old;
		return Continue;
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

	filename: string;
	layout: File;
	header: Header;
	file: ir.File;
	ext: Ext;


public:
	fn getOption(key: string, def: string = null) string
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
class Contents: Value
{
public:
	engine: Engine;
	file: ir.File;
	env: Set;


public:
	override fn toText(n: ir.Node, sink: Sink)
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
	override fn toText(n: ir.Node, sink: Sink)
	{
		// Save the old enviroment.
		old := engine.env;
		engine.env = env;

		dst: StringSink;
		file.accept(engine, dst.sink);

		// Restor old enviroment.
		engine.env = old;

		filterMarkdown(sink, dst.toString());
	}
}
