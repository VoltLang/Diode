//T default:no
//T run:volta -o %t -jo %t.json %s
//T run:%t %t.json
module test;

public import watt.io.file;
import json = watt.text.json : parse, VVValue = Value;

fn runTests(jsonFile: string)
{
	tests := [
		// name: we're testing it
		"watt.text.json": true,
		"watt.io.file": true,
	];

	jsonSrc := cast(string)read(jsonFile);
	root := json.parse(jsonSrc);
	modules := root.lookupObjectKey("modules").array();
	assert(modules.length == 1);
	children := modules[0].lookupObjectKey("children").array();
	testChildren(tests, children);
}

fn testChildren(tests: bool[string], children: json.VVValue[])
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
		case "watt.text.json":
			assert(child.lookupObjectKey("access").str() == "private");
			assert(child.lookupObjectKey("bind").str() == "json");
			aliases := child.lookupObjectKey("aliases").array();
			assert(aliases.length == 2);
			assert(aliases[0].array().length == 1);
			assert(aliases[1].array().length == 2);
			assert(aliases[0].array()[0].str() == "parse");
			assert(aliases[1].array()[0].str() == "VVValue");
			assert(aliases[1].array()[1].str() == "Value");
			break;
		case "watt.io.file":
			assert(child.lookupObjectKey("access").str() == "public");
			assert(!child.hasObjectKey("aliases"));
			assert(!child.hasObjectKey("bind"));
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
