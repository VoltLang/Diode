// Copyright © 2015-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
/*!
 * Small testing harness.
 *
 * Accessible through the --test <src> <cmp> flag.
 */
module diode.tester;

import core.c.stdlib : exit;

import watt.text.sink : StringSink;
import watt.text.source : Source;
import watt.text.string : indexOf;
import watt.io.file : read, isFile;
import io = watt.io;

import diode.eval;
import diode.parser : parse;


//! Single test files are split with this marker.
enum Split = "#####";

class Tester : Engine
{
	this(env: Set)
	{
		super(env);
	}

	override fn handleError(str: string)
	{
		io.error.writefln("%s", str);
		io.error.flush();
		exit(2);
	}
}

fn runTest(args: string[]) i32
{
	if (args.length == 4) {
		return runTest(args[2], args[3]);
	} else if (args.length == 3) {
		return runTest(args[2]);
	} else {
		io.error.writefln("invalid number of test arguments");
		io.error.flush();
		return 2;
	}
}

fn runTest(srcFile: string) i32
{
	if (!srcFile.isFile()) {
		io.error.writefln("src file '%s' not found", srcFile);
		io.error.flush();
		return 2;
	}

	text := cast(string)read(srcFile);
	index := text.indexOf(Split);
	if (index < 0) {
		io.error.writefln("malformed test in '%s'", srcFile);
		io.error.flush();
		return 2;
	}

	text = text[cast(size_t)index + Split.length .. $];
	index = text.indexOf(Split);
	if (index < 0) {
		io.error.writefln("malformed test in '%s'", srcFile);
		io.error.flush();
		return 2; 
	}

	srcText := text[0 .. index];
	text = text[cast(size_t)index + Split.length .. $];

	index = text.indexOf(Split);
	if (index < 0) {
		io.error.writefln("malformed test in '%s'", srcFile);
		io.error.flush();
		return 2; 
	}
	cmpText := text[0 .. index];

	return compileAndCompare(srcText, cmpText, srcFile);
}

fn runTest(srcFile: string, cmpFile: string) i32
{
	if (!srcFile.isFile()) {
		io.error.writefln("src file '%s' not found", srcFile);
		io.error.flush();
		return 2;
	}

	if (!cmpFile.isFile()) {
		io.error.writefln("cmp file '%s' not found", cmpFile);
		io.error.flush();
		return 2;
	}

	srcText := cast(string)read(srcFile);
	cmpText := cast(string)read(cmpFile);

	return compileAndCompare(srcText, cmpText, srcFile);
}

fn compileAndCompare(srcText: string, cmpText: string, srcFile: string) i32
{
	src := new Source(srcText, srcFile);
	root := getTestEnv();
	e := new Tester(root);
	file := parse(src, e);

	s: StringSink;
	file.accept(e, s.sink);
	retText := s.toString();

	if (retText == cmpText) {
		return 0;
	}

	io.error.writefln("Error: \n### src ###\n%s\n### cmp ###\n%s\n### end ###\n", retText, cmpText);
	io.error.flush();
	return 1;
}

fn getTestEnv() Set
{
	vals: Value[] = [cast(Value)
		new Text("One"),
		new Text("Two"),
		new Text("Three")
	];


	test := new Set();
	test.ctx["world"] = new Text("World");
	test.ctx["nil"] = new Nil();
	test.ctx["boolTrue"] = new Bool(true);
	test.ctx["boolFalse"] = new Bool(false);
	test.ctx["arrayOneTwoThree"] = new Array(vals);

	root := new Set();
	root.ctx["test"] = test;
	return root;
}
