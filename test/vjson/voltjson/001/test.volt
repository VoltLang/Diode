//T default:no
//T run:volta -o %t -jo %t.json %s
//T run:%t %t.json
module test;

import watt.io.file;
import watt.json;

struct S
{
}

global a: i32 = 0;
global b: string = "hello";
global c: string[] = ["hello"];
global d: i32* = null;
global e: string* = null;
global f: string[]* = null;
global g: string[string];
global h: i32[i32];
global i: string[i32];
global j: i32[string];
global k: string[string]*;
global l: i32[32];
global m: string[32];
global n: string[32]*;
global o: S;
global p: S*;

fn runTests(jsonFile: string)
{
	tests := [
		// name: type, typeFull  (blank for not present)
		"a": ["i32", ""],
		"b": ["string", "immutable(char)[]"],
		"c": ["string[]", "immutable(char)[][]"],
		"d": ["i32*", ""],
		"e": ["string*", "immutable(char)[]*"],
		"f": ["string[]*", "immutable(char)[][]*"],
		"g": ["string[string]", "immutable(char)[][immutable(char)[]]"],
		"h": ["i32[i32]", ""],
		"i": ["string[i32]", "immutable(char)[][i32]"],
		"j": ["i32[string]", "i32[immutable(char)[]]"],
		"k": ["string[string]*", "immutable(char)[][immutable(char)[]]*"],
		"l": ["i32[32]", ""],
		"m": ["string[32]", "immutable(char)[][32]"],
		"n": ["string[32]*", "immutable(char)[][32]*"],
		"o": ["S", "test.S"],
		"p": ["S*", "test.S*"]
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
		type := (*testp)[0];
		typeFull := (*testp)[1];
		assert(type == child.lookupObjectKey("type").str());
		if (typeFull.length == 0) {
			assert(!child.hasObjectKey("typeFull"));
		} else {
			assert(typeFull == child.lookupObjectKey("typeFull").str());
		}
	}
}

fn main(args: string[]) i32
{
	runTests(args[1]);
	return 0;
}
