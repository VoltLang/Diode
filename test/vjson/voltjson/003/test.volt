//T run:volta -o %t -jo %t.json %s
//T run:%t %t.json
module test;

import watt.io.file;
import watt.json;

global a: i32;
global extern (C) fn b() {}
global extern (C++) fn c() {}
global extern (Windows) fn e() {}
global extern (Pascal) fn f() {}
global extern (Volt) fn g() {}

fn runTests(jsonFile: string)
{
	tests := [
		// name: linkage
		"a": "volt",
		"b": "c",
		"c": "c++",
		"e": "windows",
		"f": "pascal",
		"g": "volt",
	];

	jsonSrc := cast(string)read(jsonFile);
	root := parse(jsonSrc);
	modules := root.lookupObjectKey("modules").array();
	assert(modules.length == 1);
	children := modules[0].lookupObjectKey("children").array();
	foreach (child; children) {
		name := child.lookupObjectKey("name").str();
		testp := name in tests;
		if (testp is null) {
			continue;
		}
		assert(child.lookupObjectKey("linkage").str() == *testp);
	}
}

fn main(args: string[]) i32
{
	runTests(args[1]);
	return 0;
}
