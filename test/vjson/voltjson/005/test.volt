//T default:no
//T run:volta -o %t -jo %t.json %s
//T run:%t %t.json
module test;

import watt.io.file;
import watt.json;

@property fn a() i32 { return 0; }
class b { override fn toString() string { return "hi"; } }
abstract class c { abstract fn d(); final fn e() {} }
@label fn f(i: i32) {}
final class g {}

fn runTests(jsonFile: string)
{
	tests := [
		// name: bool
		"a": "isProperty",
		"toString": "isOverride",
		"c": "isAbstract",
		"d": "isAbstract",
		"e": "isFinal",
		"f": "forceLabel",
		"g": "isFinal",
	];

	jsonSrc := cast(string)read(jsonFile);
	root := parse(jsonSrc);
	modules := root.lookupObjectKey("modules").array();
	assert(modules.length == 1);
	children := modules[0].lookupObjectKey("children").array();
	testChildren(tests, children);
}

fn testChildren(tests: string[string], children: Value[])
{
	foreach (child; children) {
		testp: string*;
		if (child.hasObjectKey("name")) {
			name := child.lookupObjectKey("name").str();
			testp = name in tests;
		}
		if (testp is null) {
			if (child.hasObjectKey("children")) {
				testChildren(tests, child.lookupObjectKey("children").array());
			}
			continue;
		}
		assert(child.lookupObjectKey(*testp).boolean());
	}
}

fn main(args: string[]) i32
{
	runTests(args[1]);
	return 0;
}
