// Copyright © 2015-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
/**
 * Small testing harness.
 *
 * Accessible through the --test <src> <cmp> flag.
 */
module diode.tester;

import watt.text.sink : StringSink;
import watt.text.source : Source;
import watt.io.file : read, isFile;
import io = watt.io;

import diode.eval;
import diode.parser : parse;


fn runTest(args: string[]) i32
{
	if (args.length != 4) {
		io.error.writefln("invalid number of test arguments");
		io.error.flush();
		return 2;
	}

	srcFile := args[2];
	cmpFile := args[3];

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

	src := new Source(srcText, srcFile);
	file := parse(src);
	root := getTestEnv();
	e := new Engine(root);

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
	test := new Set();
	test.ctx["world"] = new Text("World");
	test.ctx["nil"] = new Nil();
	test.ctx["true"] = new Bool(true);
	test.ctx["false"] = new Bool(false);

	root := new Set();
	root.ctx["test"] = test;
	return root;
}