//T default:no
//T run:volta -o %t -jo %t.json %s
//T run:%t %t.json
module test;

import watt.io.file;
import watt.json : parse, bindTest = parse;

global a: i32;
global private b: i32;
global protected c: i32;
fn d() {}
private enum e = 32;
alias f = i32*;
class g {}
struct h {}
interface i {}
enum j {a}
protected union k {}

fn runTests(jsonFile: string)
{
	tests := [
		// name: access
		"watt.io.file": "private",
		"a": "public",
		"b": "private",
		"c": "protected",
		"d": "public",
		"e": "private",
		"f": "public",
		"g": "public",
		"h": "public",
		"i": "public",
		"j": "public",
		"k": "protected",
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
		assert(child.lookupObjectKey("access").str() == *testp);
	}
}

fn main(args: string[]) i32
{
	runTests(args[1]);
	return 0;
}
