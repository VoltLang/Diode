// Copyright © 2015-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
/**
 * Holds the main function and some small test code.
 */
module main;

import diode.tester;
import diode.license;
import diode.interfaces;


fn main(args : string[]) i32
{
	if (args.length > 1 && args[1] == "--test") {
		return runTest(args);
	}
	test();
	return 0;
}


/*
 *
 * A bunch of test code.
 *
 */

import watt.io;
import watt.io.streams;
import watt.io.file : read, exists, searchDir, isDir, isFile;
import watt.path : dirSeparator;
import watt.text.string : endsWith;
import watt.text.sink;

import diode.driver;
import diode.interfaces;


fn test()
{
	s := new Settings();
	s.sourceDir = "example";
	s.outputDir = "output";
	s.fillInDefaults();

	d := new DiodeDriver(s);
	d.addLayouts();
	d.addIncludes();
	d.addVdocs();

	d.renderFiles();
}

fn renderFiles(d: Driver)
{
	srcDir := d.settings.sourceDir;
	outDir := d.settings.outputDir;

	if (!isDir(srcDir)) {
		d.info("source dir not found '%s'", srcDir);
		return;
	}
	if (!isDir(outDir)) {
		d.info("output dir not found '%s'", outDir);
		return;
	}

	fn hit(file: string) {
		srcPath := srcDir ~ dirSeparator ~ file;
		outPath := outDir ~ dirSeparator ~ file;

		if (!isFile(srcPath)) {
			return;
		}

		if (endsWith(outPath, ".md")) {
			outPath = outPath[0 .. $ - 3] ~ ".html";
		}

		d.info("rendering '%s' to '%s'", srcPath, outPath);

		str := cast(string)read(srcPath);
		str = d.renderFile(str, srcPath);
		o := new OutputFileStream(outPath);
		o.writefln("%s", str);
		o.flush();
		o.close();
	}

	searchDir(srcDir, "*", hit);
}

fn addLayouts(d: Driver)
{
	dir := d.settings.layoutDir;
	if (!isDir(dir)) {
		d.info("dir not found '%s'", dir);
		return;
	}

	fn hit(file: string) {
		if (isDir(file)) {
			return;
		}
		fullpath := dir ~ dirSeparator ~ file;
		str := cast(string)read(fullpath);
		d.addLayout(str, file);

		d.info("added layout '%s'", fullpath);
	}

	searchDir(dir, "*.html", hit);
}

fn addIncludes(d: Driver)
{
	dir := d.settings.includeDir;
	if (!isDir(dir)) {
		d.info("dir not found '%s'", dir);
		return;
	}

	fn hit(file: string) {
		if (isDir(file)) {
			return;
		}
		fullpath := dir ~ dirSeparator ~ file;
		str := cast(string)read(fullpath);
		d.addInclude(str, file);

		d.info("added include '%s'", fullpath);
	}

	searchDir(dir, "*", hit);
}

fn addVdocs(d: Driver)
{
	dir := d.settings.vdocDir;
	if (!isDir(dir)) {
		d.info("dir not found '%s'", dir);
		return;
	}

	fn hit(file: string) {
		if (isDir(file)) {
			return;
		}
		fullpath := dir ~ dirSeparator ~ file;
		str := cast(string)read(fullpath);
		d.addDoc(str, file);

		d.info("added vdoc '%s'", fullpath);
	}

	searchDir(dir, "*.json", hit);
}
