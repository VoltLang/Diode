// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.driver;

import core.varargs;

import watt.io;
import watt.io.streams;
import watt.path;
import watt.conv;
import watt.text.sink;
import watt.text.source;
import watt.text.string : startsWith;
import watt.markdown;
import watt.text.format : format;

import json = watt.json;
import ir = liquid.ir;

import liquid.eval;
import liquid.eval.json : jsonToValue = toValue, jsonToSet = toSet;
import liquid.parser : parseFile = parse;

import diode.errors;
import diode.interfaces;
import diode.parser.frontmatter : Header, parseHeader = parse;
import diode.vdoc;
import diode.vdoc.parser;
import diode.vdoc.filter;
import diode.vdoc.as_code;
import diode.vdoc.processor;


/*!
 * Main focal point of Diode.
 */
class DiodeDriver : Driver
{
protected:
	mLayouts: File[string];
	mRoot: Set;
	mSite: Set;
	mVdoc: VdocRoot;
	mModules: Array;
	mEngine: DriverEngine;
	mDocGroup: File;
	mDocModule: File;
	mDocModules: File;
	mVerbose: bool;
	mSiteSettings: json.Value;
	mPrintUndocumented: bool;


private:
	//! Counter for tagging of vdoc objects.
	mTagCounter: u64;


public:
	this(settings: Settings)
	{
		super(settings);
		buildRootEnv();

		mEngine = new DriverEngine(this, mRoot);
	}

	override fn setConfig(source: string, filename: string)
	{
		verbose("reading config from '%s'", filename);

		root := json.parse(source);
		foreach (k; root.keys()) {
			v := root.lookupObjectKey(k);

			switch (k) {
			case "url":
				// If this is already set from the command line.
				if (settings.urlFromCommandLine) {
					warning("key '%s' from '%s' overwritten from command line, skipping.", k, filename);
					continue;
				}
				mSite.ctx["url"] = new Text(v.str());
			case "baseurl":
				// If this is already set from the command line.
				if (settings.baseurlFromCommandLine) {
					warning("key '%s' from '%s' overwritten from command line, skipping.", k, filename);
					continue;
				}
				mSite.ctx["baseurl"] = new Text(v.str());
				continue;
			case "time", "pages", "posts", "related_posts",
			     "static_files", "html_pages", "collection",
			     "data", "documents", "categories", "tags":
				warning("key '%s' from '%s' is reserved, skipping.", k, filename);
				continue;
			case "guru_hack_suffix":
				settings.guruHackSuffix = v.str();
				continue;
			case "vdoc":
				if (v.type() == json.DomType.Object) {
					mVdoc.set = v.jsonToSet();
					continue;
				}
				warning("key '%s' from '%s' is not a object, skipping.", k, filename);
				continue;
			default:
			}

			mSite.ctx[k] = v.jsonToValue();
		}
	}

	override fn addBuiltins()
	{
		f: string;

		// Add default includes.
		f = getName("_include", "footer.html");
		addInclude(import("_include/footer.html"), f);

		f = getName("_include", "head.html");
		addInclude(import("_include/head.html"), f);

		f = getName("_include", "head_css.html");
		addInclude(import("_include/head_css.html"), f);

		f = getName("_include", "header.html");
		addInclude(import("_include/header.html"), f);

		f = getName("_include", "vdoc_child.html");
		addInclude(import("_include/vdoc_child.html"), f);

		f = getName("_include", "vdoc_table.html");
		addInclude(import("_include/vdoc_table.html"), f);

		f = getName("_include", "vdoc_ingroup.html");
		addInclude(import("_include/vdoc_ingroup.html"), f);

		// Add default layouts.
		f = getName("_layout", "page.html");
		addLayout(import("_layout/page.html"), f);

		f = getName("_layout", "default.html");
		addLayout(import("_layout/default.html"), f);

		// Add default vdoc templates.
		f = getName("_vdoc", "group.html");
		addDocTemplate(import("_vdoc/group.html"), f);

		f = getName("_vdoc", "module.html");
		addDocTemplate(import("_vdoc/module.html"), f);

		f = getName("_vdoc", "modules.html");
		addDocTemplate(import("_vdoc/modules.html"), f);
	}

	override fn processDoc()
	{
		// If modules are processed skip mDocModules as well.
		if (mDocModule is null) {
			return;
		}

		fullUrl := settings.url ~ settings.baseurl;
		if (settings.guruHackSuffix !is null) {
			fullUrl ~= settings.guruHackSuffix;
		}

		mods := mVdoc.modules;
		prev: Value;
		foreach (mod; mods) {
			mod.url = format("%s/vdoc/mod_%s.html", fullUrl, mod.name);
			tag(mod, mod, prev);
			prev = mod;
		}

		groups := mVdoc.groups;
		foreach (group; groups) {
			group.url = format("%s/vdoc/%s.html", fullUrl, group.search);
		}

		// Process all of the raw comments.
		process(mVdoc);

		// Do not generate any vdoc files.
		if (settings.guruHackSuffix !is null) {
			return;
		}

		dir := format("%s%svdoc%s", settings.outputDir,
			dirSeparator, dirSeparator);

		// Make sure the directory excists.
		mkdirP(dir);

		if (mDocModules !is null) {
			filename := format("%s%s", dir, "modules.html");
			mVdoc.current = null;
			renderFileTo(mDocModules, filename);
		}

		if (mDocModule is null) {
			return;
		}

		foreach (mod; mods) {
			filename := format("%smod_%s.html", dir, mod.name);
			mVdoc.current = mod;
			renderFileTo(mDocModule, filename);
		}

		foreach (group; groups) {
			filename := format("%s%s.html", dir, group.search);
			mVdoc.current = group;
			renderFileTo(mDocGroup, filename);
		}

		mVdoc.current = null;
	}

	override fn addLayout(source: string, filename: string)
	{
		verbose("adding layout '%s'", filename);

		f := createFile(source, filename);
		mLayouts[f.filename] = f;
	}

	override fn addInclude(source: string, filename: string)
	{
		verbose("adding include '%s'", filename);

		file := createFile(source, filename);
		mEngine.addInclude(file, filename);
	}

	override fn renderFile(source: string, filename: string, output: string)
	{
		renderFileTo(createFile(source, filename), output);
	}

	override fn addDoc(source: string, filename: string)
	{
		verbose("adding vdoc source '%s'", filename);

		parse(mVdoc, source);
	}

	override fn addDocTemplate(source: string, filename: string)
	{
		file := createFile(source, filename);
		addDocTemplate(file, filename);
	}

	override fn verbose(fmt: string, ...)
	{
		if (!mVerbose) {
			return;
		}

		vl: va_list;
		va_start(vl);
		error.vwritefln(fmt, ref _typeids, ref vl);
		error.flush();
		va_end(vl);
	}

	override fn info(fmt: string, ...)
	{
		vl: va_list;
		va_start(vl);
		error.vwritefln(fmt, ref _typeids, ref vl);
		error.flush();
		va_end(vl);
	}

	override fn warning(fmt: string, ...)
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
		verbose("adding include '%s'", filename);
		mEngine.addInclude(file, filename);
	}

	fn addLayout(file: File, filename: string)
	{
		verbose("adding layout '%s'", filename);
		mLayouts[file.filename] = file;
	}

	fn addDocTemplate(file: File, filename: string)
	{
		verbose("adding vdoc template '%s'", filename);

		switch (file.filename) {
		case "group": mDocGroup = file; break;
		case "module": mDocModule = file; break;
		case "modules": mDocModules = file; break;
		default: warning("unknown vdoc template '%s' from file '%s'", file.filename, filename);
		}
	}

	fn renderFileTo(file: File, output: string)
	{
		verbose("rendering '%s' to '%s'", file.fullName, output);

		o := new OutputFileStream(output);
		mEngine.renderFile(file, o.write);
		o.flush();
		o.close();
	}


protected:
	fn tag(val: Value, parentWithUrl: Parent, prev: Value)
	{
		named := cast(Named)val;
		if (named is null) {
			return;
		}

		// If the named has a url always process it and it's children.
		// Skip objects without doccoment if mPrintUndocumented is not set.
		if (named.url is null &&
		    named.raw is null &&
		    !mPrintUndocumented) {
			return;
		}

		prevNamed := cast(Named)prev;
		if (prevNamed !is null &&
		    prevNamed.name == named.name &&
		    prevNamed.raw == named.raw) {
			named.tag = prevNamed.tag;
		} else {
			named.tag = getTag(named.name);
		}

		// Check if this value is a parent.
		parent := cast(Parent)val;
		if (parent is null) {
			// Set the url only after we know this is not a parent.
			setUrl(named, parentWithUrl);
			return;
		}

		parentToUse := parent.url !is null ? parent : parentWithUrl;
		p: Value;
		foreach (child; parent.children) {
			tag(child, parentToUse, p);
			p = child;
		}

		// Set the url after we are done with children.
		setUrl(named, parentWithUrl);
	}

	fn setUrl(named: Named, parentWithUrl: Named)
	{
		if (named.url is null) {
			named.url = getUrl(named, parentWithUrl);
		}
	}

	fn getTag(base: string) string
	{
		return format("%s%s", base, mTagCounter++);
	}

	fn getUrl(named: Named, parentWithUrl: Named) string
	{
		return format("%s#%s", parentWithUrl.url, named.tag);
	}

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
		f.header = parseHeader(src, mEngine.handleError);
		f.file = parseFile(src, mEngine);
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

		warning("can not find layout '%s' for file '%s'");

		return null;
	}

	fn buildRootEnv()
	{
		mVdoc = new VdocRoot();
		mRoot = new Set();
		mSite = new Set();
		mModules = new Array(cast(Value)null);

		mRoot.ctx["doc"] = mVdoc;
		mRoot.ctx["vdoc"] = mVdoc;
		mRoot.ctx["site"] = mSite;
		mSite.ctx["url"] = new Text(settings.url);
		mSite.ctx["baseurl"] = new Text(settings.baseurl);
	}
}

//! Implementation of relative_url filter, appends baseurl.
fn filterRelativeUrl(drv: Driver, str: string) string
{
	if (!str.startsWith("/")) {
		return drv.settings.baseurl ~ "/" ~ str;
	} else {
		return drv.settings.baseurl ~ str;
	}
}

//! Implementation of absolute_url filter, appends url and baseurl.
fn filterAbsoluteUrl(drv: Driver, str: string) string
{
	return drv.settings.url ~ filterRelativeUrl(drv, str);
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

	override fn handleFilter(n: ir.Node, ident: string,
		child: Value, args: Value[], sink: Sink)
	{
		fn valueToString(v: Value) string {
			s: StringSink;
			v.toText(n, s.sink);
			return s.toString();
		}

		fn getArg(i: size_t) string {
			if (args.length <= i) {
				handleError(format("expected at least %s argument to '%s' filter.", i+1, ident));
			}
			return valueToString(args[i]);
		}

		fn getArgOrDefault(def: string) string {
			if (args.length < 1) {
				return def;
			}
			return valueToString(args[0]);
		}

		fn vdocFindOrNil() Value {
			name := valueToString(child);
			if (ret := mDrv.mVdoc.findNamed(name)) {
				return ret;
			}
			return new Nil();
		}

		fn vdocFindOrError() Value {
			name := valueToString(child);
			if (ret := mDrv.mVdoc.findNamed(name)) {
				return ret;
			}
			err := format("could not find vdoc object '%s'", name);
			handleError(err);
			return null;
		}

		switch (ident) {
		case "relative_url":
			txt := valueToString(child);
			v = new Text(filterRelativeUrl(mDrv, txt));
			break;
		case "absolute_url":
			txt := valueToString(child);
			v = new Text(filterAbsoluteUrl(mDrv, txt));
			break;
		case "vdoc_find":
			v = vdocFindOrNil();
			break;
		case "vdoc_find_url":
			v = vdocFindOrNil().ident(n, "url");
			break;
		case "vdoc_find_full", "vdoc_find_brief",  "vdoc_find_proto", "vdoc_find_content":
			child = vdocFindOrError();
			goto case "vdoc_full";
		case "vdoc_full", "vdoc_brief", "vdoc_proto", "vdoc_content":
			type := getArgOrDefault("html");
			v = handleDocCommentFilter(mDrv, this, mDrv.mVdoc, child, ident, type);
			break;
		case "vdoc_find_as_code":
			child = vdocFindOrError();
			goto case "vdoc_as_code";
		case "vdoc_as_code":
			type := getArgOrDefault("brief");
			v = new FormatAsCode(mDrv, this, mDrv.mVdoc, child, type);
			break;
		default:
			super.handleFilter(n, ident, child, args, sink);
			break;
		}
	}

	override fn handleInclude(p: ir.Include, e: Set, sink: Sink)
	{
		ret := p.filename in mIncludes;
		if (ret is null) {
			mDrv.warning("no such include '%s'", p.filename);
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
