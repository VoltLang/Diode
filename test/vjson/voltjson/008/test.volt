//T default:no
//T run:volta -o %t -jo %t.json %s
//T run:%t %t.json
module test;

public import watt.io.file;
import json = watt.text.json : parse, VVValue = Value;

interface A
{
	fn a();
}

interface B
{
	fn b();
}

interface C : B
{
	fn c();
}

class CA
{
}

class CB : CA, A, C
{
	override fn a() {}
	override fn b() {}
	override fn c() {}
}

fn runTests(jsonFile: string)
{
	tests := [
		// name: we're testing it
		"CB": true,
		"C": true,
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
		case "CB":
			assert(child.lookupObjectKey("parent").str() == "CA");
			interfaces := child.lookupObjectKey("interfaces").array();
			assert(interfaces.length == 2);
			assert(interfaces[0].str() == "A");
			assert(interfaces[1].str() == "C");
			break;
		case "C":
			parents := child.lookupObjectKey("parents").array();
			assert(parents.length == 1);
			assert(parents[0].str() == "B");
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
