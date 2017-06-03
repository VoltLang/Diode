//T default:no
//T run:volta -o %t -jo %t.json %s
//T run:%t %t.json
module test;

#nodoc

public import watt.io.file;
import json = watt.text.json : parse, VVValue = Value;

/*!
 * HIHIHIHI
 */
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
	jsonSrc := cast(string)read(jsonFile);
	root := json.parse(jsonSrc);
	modules := root.lookupObjectKey("modules").array();
	assert(modules.length == 1);
	children := modules[0].lookupObjectKey("children").array();
	testChildren(children);
}

fn testChildren(children: json.VVValue[])
{
	foreach (child; children) {
		assert(!child.hasObjectKey("doc"));
		if (child.hasObjectKey("children")) {
			testChildren(child.lookupObjectKey("children").array());
		}
	}
}

fn main(args: string[]) i32
{
	runTests(args[1]);
	return 0;
}
