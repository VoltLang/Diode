// Copyright © 2015-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
/*!
 * Holds the main function and some small test code.
 */
module main;

import diode.tester;
import diode.license;
import diode.interfaces;


fn main(args: string[]) i32
{
	if (args.length == 1) {
		io.error.writefln("Usage:");
		io.error.writefln("\t--test    <source.liquid> <result.txt>");
		io.error.writefln("\t-s        <sourceDir>");
		io.error.writefln("\t-d        <outputDir>");
		io.error.writefln("\t--baseurl <URL>");
		io.error.writefln("\t          http://example.com/mybase");
		io.error.flush();
		return 0;
	}

	if (args.length > 1 && args[1] == "--test") {
		return runTest(args);
	}
	return test(args);
}


/*
 *
 * A bunch of test code.
 *
 */

import io = watt.io;
import watt.io.streams;
import watt.io.file : read, exists, searchDir, isDir, isFile, SearchStatus;
import watt.path : dirSeparator;
import watt.text.string : endsWith, startsWith, join, indexOf;
import watt.text.sink;
import watt.text.format;
import watt.path : mkdirP;

import diode.driver;
import diode.interfaces;

enum ParseState
{
	Normal,
	Skip,
	OutputDir,
	SourceDir,
	Baseurl,
}

fn parseArgs(args: string[], s: Settings) string[]
{
	state := ParseState.Normal;
	files: string[];

	foreach (arg; args[1 .. $]) {
		final switch (state) with (ParseState) {
		case Skip: break;
		case Normal:
			switch (arg) {
			case "-s", "--source": state = SourceDir; break;
			case "-d", "--destination": state = OutputDir; break;
			case "--baseurl": state = Baseurl; break;
			case "--limit_posts", "--port", "--host":
				state = Skip;
				goto case;
			case "--safe", "-w", "--drafts", "--future",
			     "--unpublished", "--lsi", "--force_polling",
			     "-V",  "--verbose", "-q", "--quiet", "-I",
			     "--incremental", "--profile",
			     "--strict_front_matter", "-B", "--detach",
			     "--skip-initial-build", "--ssl-key", "--ssl-cert":
				io.error.writefln("skipping jekyll arg '%s'",arg);
				io.error.flush();
				break;
			default:
				if (arg.length > 0 && arg[0] == '-') {
					io.error.writefln("skipping unknown arg '%s'",arg);
					io.error.flush();
					break;
				}
				files ~= arg;
			}
			continue;
		case SourceDir: s.sourceDir = arg; break;
		case OutputDir: s.outputDir = arg; break;
		case Baseurl:
			server, address: string;
			if (!splitUrl(arg, out server, out address)) {
				io.error.writefln("invalid --baseurl '%s'", arg);
				io.error.flush();
				break;
			}
			s.urlFromCommandLine = true;
			s.baseurlFromCommandLine = true;
			s.url = server;
			s.baseurl = address;
			break;
		}
		state = ParseState.Normal;
	}

	return files;
}

fn splitUrl(str: string, out server: string, out address: string) bool
{
	offset: size_t;
	// Special case file://.
	if (str.startsWith("file://")) {
		server = str[0 .. 7u];
		address = str[7u .. $];
		return true;
	} else if (str.startsWith("http://")) {
		offset = 7u;
	} else if (str.startsWith("https://")) {
		offset = 8u;
	} else {
		return false;
	}

	index := str[offset .. $].indexOf("/");
	if (index >= 0) {
		offset += cast(size_t)index;
		server = str[0 .. offset];
		address = str[offset .. $];

		// The address is only one '/'
		if (address.length == 1) {
			address = null;
		}
	} else {
		server = str;
	}

	return true;
}

fn test(args: string[]) i32
{
	s := new Settings();
	s.sourceDir = "example";
	s.outputDir = "output";
	files := parseArgs(args, s);
	s.fillInDefaults();

	d := new DiodeDriver(s);
	d.addBuiltins();
	d.findConfig();
	d.addLayouts();
	d.addIncludes();
	d.addVdocTemplates();
	d.addFiles(files);
	d.processDoc();
	d.renderFiles();
	d.info("done");

	return 0;
}

fn findConfig(d: DiodeDriver)
{
	filename := format("%s%s%s", d.settings.sourceDir,
		dirSeparator, "_config.json");

	if (!isFile(filename)) {
		return;
	}

	str := cast(string)read(filename);
	d.setConfig(str, filename);
}

fn addFiles(d: DiodeDriver, files: string[])
{
	foreach (file; files) {
		if (!file.endsWith(".json")) {
			d.warning("unknown file type '%s'", file);
			continue;
		}

		if (!isFile(file)) {
			d.warning("file not found '%s'", file);
			continue;
		}

		str := cast(string)read(file);
		d.addDoc(str, file);
	}
}

fn renderFiles(d: Driver)
{
	srcDir := d.settings.sourceDir;
	outDir := d.settings.outputDir;

	if (!isDir(srcDir)) {
		d.warning("wanring: source dir '%s' not found", srcDir);
		return;
	}

	if (!isDir(outDir)) {
		if (exists(outDir)) {
			d.info("warning: output dir '%s' is not a directory", outDir);
			return;
		}
		mkdirP(outDir);
	}

	fn hit(file: string) SearchStatus {
		srcPath := srcDir ~ dirSeparator ~ file;
		outPath := outDir ~ dirSeparator ~ file;

		if (!isFile(srcPath)) {
			return SearchStatus.Continue;
		}

		// Skip files starting with '.' and '_'.
		if (file[0] == '.' || file[0] == '_') {
			return SearchStatus.Continue;
		}

		if (endsWith(outPath, ".md")) {
			outPath = outPath[0 .. $ - 3] ~ ".html";
		} else if (!endsWith(outPath, ".html")) {
			d.info("skipping file '%s'", srcPath);
			return SearchStatus.Continue;
		}

		str := cast(string)read(srcPath);
		d.renderFile(str, srcPath, outPath);
		return SearchStatus.Continue;
	}

	searchDir(srcDir, "*", hit);
}

fn addLayouts(d: Driver)
{
	dir := d.settings.layoutDir;
	if (!isDir(dir)) {
		return;
	}

	fn hit(file: string) SearchStatus {
		fullpath := dir ~ dirSeparator ~ file;
		if (!checkFileWarn(d, file, fullpath, ".html")) {
			return SearchStatus.Continue;
		}

		str := cast(string)read(fullpath);
		d.addLayout(str, fullpath);
		return SearchStatus.Continue;
	}

	searchDir(dir, "*", hit);
}

fn addIncludes(d: Driver)
{
	dir := d.settings.includeDir;
	if (!isDir(dir)) {
		return;
	}

	fn hit(file: string) SearchStatus {
		fullpath := dir ~ dirSeparator ~ file;
		if (!checkFileWarn(d, file, fullpath)) {
			return SearchStatus.Continue;
		}

		str := cast(string)read(fullpath);
		d.addInclude(str, fullpath);
		return SearchStatus.Continue;
	}

	// Add user provided includes, these can overwite the builtin ones.
	searchDir(dir, "*", hit);
}

fn addVdocTemplates(d: Driver)
{
	dir := d.settings.vdocDir;
	if (!isDir(dir)) {
		return;
	}

	fn hit(file: string) SearchStatus {
		fullpath := dir ~ dirSeparator ~ file;
		if (!checkFileWarn(d, file, fullpath, ".md", ".html")) {
			return SearchStatus.Continue;
		}

		str := cast(string)read(fullpath);
		d.addDocTemplate(str, fullpath);
		return SearchStatus.Continue;
	}

	searchDir(dir, "*", hit);
}


private:

fn checkFileWarn(d: Driver, file: string, fullpath: string, endings: scope string[]...) bool
{
	switch (file) {
	case ".", "..": return false;
	default:
	}

	if (isDir(fullpath)) {
		d.warning("skipping dir '%s'", fullpath);
		return false;
	}

	if (!isFile(fullpath)) {
		d.warning("'%s' is not a file", fullpath);
		return false;
	}

	if (endings.length > 0 && !endsWith(fullpath, endings)) {
		d.warning("file '%s' does not end with",
		          fullpath, join(endings, " "));
		return false;
	}

	return true;
}
