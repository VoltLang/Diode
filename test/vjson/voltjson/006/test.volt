//T run:volta -o %t -jo %t.json %s
//T run:%t %t.json
module test;

import watt.io.file;
import watt.json;

enum Enum
{
	A,
	B,
	C
}

enum D = 32;
private enum E = 33;

fn runTests(jsonFile: string)
{
	tests := [
		// name: we're testing it
		"D": true,
		"A": true,
		"E": true
	];

	jsonSrc := cast(string)read(jsonFile);
	root := parse(jsonSrc);
	modules := root.lookupObjectKey("modules").array();
	assert(modules.length == 1);
	children := modules[0].lookupObjectKey("children").array();
	testChildren(tests, children);
}

fn testChildren(tests: bool[string], children: Value[])
{
	foreach (child; children) {
		testp: bool*;
		name: string;
		if (child.hasObjectKey("name")) {
			name = child.lookupObjectKey("name").str();
			testp = name in tests;
		}
		if (testp is null) {
			if (child.hasObjectKey("children")) {
				testChildren(tests, child.lookupObjectKey("children").array());
			}
			continue;
		}

		switch (name) {
		case "D":
			assert(child.lookupObjectKey("isStandalone").boolean());
			assert(child.lookupObjectKey("access").str() == "public");
			break;
		case "A":
			assert(!child.hasObjectKey("isStandalone"));
			assert(!child.hasObjectKey("access"));
			break;
		case "E":
			assert(child.lookupObjectKey("access").str() == "private");
			break;
		default: assert(false);
		}
	}
}

fn main(args: string[]) i32
{
	runTests(args[1]);
	return 0;
}
