// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.driver;

import watt.io;
import watt.io.streams;
import watt.path;
import watt.conv;
import watt.text.sink;
import watt.text.source;
import watt.text.markdown;
import watt.text.format : format;

import ir = diode.ir;
import diode.eval;
import diode.errors;
import diode.interfaces;
import diode.parser : parseFile = parse;
import diode.parser.header : Header, parseHeader = parse;
import diode.vdoc;
import diode.vdoc.format;
import diode.vdoc.parser;


/*!
 * Main focal point of Diode.
 */
class DiodeDriver : Driver
{
protected:
	mLayouts: File[string];
	mRoot: Set;
	mSite: Set;
	mDoc: VdocRoot;
	mModules: Array;
	mEngine: DriverEngine;
	mDocModule: File;


public:
	this(settings: Settings)
	{
		super(settings);
		buildRootEnv();

		mEngine = new DriverEngine(this, mRoot);
	}

	override fn addBuiltins()
	{
		file := new File();
		file.file = new VodcModuleBrief();
		file.ext = File.Ext.Markdown;
		f := getName("_include", "vdoc_module_brief.md");
		addInclude(file, f);

		f = getName("_include", "vdoc_children_brief.md");
		addInclude(import("_include/vdoc_children_brief.md"), f);

		f = getName("_include", "vdoc_doc_brief.md");
		addInclude(import("_include/vdoc_doc_brief.md"), f);

		f = getName("_include", "vdoc_enumdecls.md");
		addInclude(import("_include/vdoc_enumdecls.md"), f);

		f = getName("_include", "vdoc_function_brief.md");
		addInclude(import("_include/vdoc_function_brief.md"), f);
	}

	override fn processDoc()
	{
		if (mDocModule is null) {
			return;
		}

		mods := mDoc.getModules();
		foreach (mod; mods) {
			mod.url = format("mod_%s.html", mod.name);
		}

		s: StringSink;

		foreach (mod; mods) {
			filename := format("%s%s%s", settings.outputDir, dirSeparator, mod.url);

			info("renderingFile '%s'", filename);

			s.reset();
			mDoc.current = mod;
			mEngine.renderFile(mDocModule, s.sink);
			o := new OutputFileStream(filename);
			o.writefln("%s", s.toString());
			o.flush();
			o.close();
		}
	}

	override fn addLayout(source: string, filename: string)
	{
		info("adding layout '%s'", filename);

		f := createFile(source, filename);
		mLayouts[f.filename] = f;
	}

	override fn addInclude(source: string, filename: string)
	{
		info("adding include '%s'", filename);

		file := createFile(source, filename);
		mEngine.addInclude(file, filename);
	}

	override fn renderFile(source: string, filename: string) string
	{
		info("renderingFile '%s'", filename);

		s: StringSink;
		f := createFile(source, filename);
		mEngine.renderFile(f, s.sink);
		return s.toString();
	}

	override fn addDoc(source: string, filename: string)
	{
		info("adding vdoc source '%s'", filename);

		parse(mDoc, source);
	}

	override fn addDocTemplate(source: string, filename: string)
	{
		file := createFile(source, filename);
		addDocTemplate(file, filename);
	}

	override fn info(fmt: string, ...)
	{
		vl: va_list;
		va_start(vl);
		error.vwritefln(fmt, ref _typeids, ref vl);
		error.flush();
		va_end(vl);
	}


	/*
	 *
	 * Additional helpers.
	 *
	 */

	fn addInclude(file: File, filename: string)
	{
		info("adding include '%s'", filename);
		mEngine.addInclude(file, filename);
	}

	fn addLayout(file: File, filename: string)
	{
		info("adding layout '%s'", filename);
		mLayouts[file.filename] = file;
	}

	fn addDocTemplate(file: File, filename: string)
	{
		info("adding vdoc template '%s'", filename);

		switch (file.filename) {
		case "module": mDocModule = file; break;
		default: info("unknown vdoc template '%s' from file '%s'", file.filename, filename);
		}
	}


protected:
	fn getName(dir: string, base: string) string
	{
		return format("<builtin>%s%s%s%s",
			dirSeparator, dir, dirSeparator, base);
	}

	fn createFile(source: string, filename: string) File
	{
		base := baseName(filename);
		ext := getAndCheckExt(ref base);

		src := new Source(source, filename);
		f := new File();
		f.fullName = filename;
		f.ext = ext;
		f.filename = base;
		f.header = parseHeader(src);
		f.file = parseFile(src);
		f.layout = f.getOption("layout");

		return f;
	}

	fn selectType(layout: File, contents: File) Contents
	{
		if (layout is null) {
			return new Contents();
		}

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

	fn getNeededLayout(file: File) File
	{
		// No need to warn on null.
		if (file.layout is null) {
			return null;
		}

		l := getLayout(file.layout);
		if (l !is null) {
			return l;
		}

		info("can not find layout '%s' for file '%s'");

		return null;
	}

	fn buildRootEnv()
	{
		mDoc = new VdocRoot();
		mRoot = new Set();
		mSite = new Set();
		mModules = new Array(null);

		mRoot.ctx["doc"] = mDoc;
		mRoot.ctx["site"] = mSite;
		mSite.ctx["baseurl"] = new Text(settings.url);
	}
}

/*!
 *
 */
class DriverEngine : Engine
{
public:
	file: File;


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

		do {
			// getNeededLayout might return null, but those
			// functions where is used handles that.
			l := mDrv.getNeededLayout(f);

			// Create the contents for this layout.
			c := mDrv.selectType(l, f);
			c.engine = this;
			c.file = f;
			c.env = env;

			// We are done here.
			if (l is null) {
				c.toText(f.file, sink);
				return;
			}

			// Setup the new env for the layout file.
			env = new Set();
			env.parent = mRoot;
			env.ctx["content"] = c;
			f = l;
		} while (true);
	}

	override fn handleInclude(p: ir.Include, e: Set, sink: Sink)
	{
		ret := p.filename in mIncludes;
		if (ret is null) {
			mDrv.info("no such include '%s'", p.filename);
			return;
		}

		f := *ret;

		e.parent = mRoot;
		// Get content to do any conversion needed.
		content := mDrv.selectType(file, f);
		content.env = e;
		content.file = f;
		content.engine = this;
		content.toText(p, sink);
	}
}

/*!
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
	fullName: string;
	layout: string;
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

/*!
 * Special Value for the contents value.
 */
class Contents: Value
{
public:
	engine: DriverEngine;
	file: File;
	env: Set;


public:
	override fn toText(n: ir.Node, sink: Sink)
	{
		// Save the old enviroment and file.
		oldEnv := engine.env;
		oldFile := engine.file;

		// Set new enviroment and file.
		engine.env = env;
		engine.file = file;

		file.file.accept(engine, sink);

		// Restore old enviroment and file.
		engine.file = oldFile;
		engine.env = oldEnv;
	}
}

/*!
 * Special Value for Markdown to HTML contents.
 */
class MarkdownContents : Contents
{
public:
	override fn toText(n: ir.Node, sink: Sink)
	{
		dst: StringSink;
		super.toText(n, dst.sink);
		filterMarkdown(sink, dst.toString());
	}
}
