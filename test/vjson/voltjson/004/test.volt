//T default:no
//T run:volta -o %t -jo %t.json %s
//T run:%t %t.json
module test;

import watt.io.file;
import watt.text.json;

global a: i32;
local b: i32;

fn runTests(jsonFile: string)
{
	tests := [
		// name: storage
		"a": "global",
		"b": "local",
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
		assert(child.lookupObjectKey("storage").str() == *testp);
	}
}

fn main(args: string[]) i32
{
	runTests(args[1]);
	return 0;
}
