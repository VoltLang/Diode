// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.driver;

import watt.io;
import watt.path;
import watt.text.sink;

import ir = diode.ir;
import diode.eval;
import diode.errors;
import diode.interfaces;
import diode.parser : parse;


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
		auto ext = extension(base);

		if (ext is null) {
			throw makeNoExtension(base);
		}

		if (ext != ".html") {
			throw makeExtensionNotSupported(base);
		}

		// Remove the extension.
		base = base[0 .. $ - ext.length];

		auto f = new File();
		f.file = parse(source, filename);

		mLayouts[base] = f;
	}

	override void renderFile(string source, string filename)
	{
		string layout = settings.layoutDefault;

		auto l = layout in mLayouts;
		if (l is null) {
			throw makeLayoutNotFound(filename, layout);
		}

		auto f = new File();
		f.file = parse(source, filename);
		f.layout = mLayouts[layout];

		renderFile(f);
	}

protected:
	void renderFile(File f)
	{
		auto e = new Engine(mRoot);
		// For layout we modify the enviroment.
		Set env = mRoot;

		while (f.layout !is null) {
			auto c = new Contents();
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

private:
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
	File layout;
	ir.File file;
}

/**
 * Special Value for 
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
