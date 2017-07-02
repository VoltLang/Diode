// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.vdoc.parser;

import io = watt.io;
import json = watt.text.json;
import vdoc = watt.text.vdoc;

import diode.eval;
import diode.vdoc;


//! Parse the given @p data and add the @p vdocRoot.
fn parse(vdocRoot: VdocRoot, data: string)
{
	root := json.parse(data);
	moduleRoot := root.lookupObjectKey("modules");
	globalsRoot := root.lookupObjectKey("globalDocComments");

	children: Value[];

	fromArray(ref children, ref moduleRoot);
	parseGlobals(ref children, ref globalsRoot);

	vdocRoot.setChildren(children);
}


private:

//! Parse the global doccomments.
fn parseGlobals(ref arr: Value[], ref v: json.Value)
{
	name, title: string;
	def := new DocCommentDefGroup();

	foreach (ref e; v.array()) {
		raw := e.str();

		def.parseRaw(raw, out name, out title);

		if (name is null) {
			continue;
		}

		g := new Parent();
		g.kind = Kind.Group;
		g.raw = raw;
		g.name = title;
		g.search = name;

		arr ~= g;
	}
}

/*!
 * Used to collect information during parsing.
 */
struct Info
{
public:
	kind: Kind;
	name: string;
	bind: string;
	doc: string;
	type: string;
	typeFull: string;
	hasBody: bool;
	linkage: string;
	value: string;
	children: Value[];
	rets: Value[];
	args: Value[];
	access: Access;
	storage: Storage;
	mangledName: string;
	isScope: bool;
	isFinal: bool;
	isStatic: bool;
	isExtern: bool;
	isProperty: bool;
	isAbstract: bool;
	isOverride: bool;
	isStandalone: bool;


public:
	fn getFields(ref e: json.Value)
	{
		foreach (k; e.keys()) {
			v := e.lookupObjectKey(k);
			switch (k) {
			case "doc": this.doc = v.str(); break;
			case "args": args.fromArray(ref v, Kind.Arg); break;
			case "rets": rets.fromArray(ref v, Kind.Return); break;
			case "name": this.name = v.str(); break;
			case "type": this.type = v.str(); break;
			case "bind": this.bind = v.str(); break;
			case "kind": this.kind = getKindFromString(v.str()); break;
			case "value": this.value = v.str(); break;
			case "access": this.access = getAccessFromString(v.str()); break;
			case "parent": break; // TODO
			case "aliases": break; // TODO
			case "storage": this.storage = getStorageFromString(v.str()); break;
			case "isScope": this.isScope = v.boolean(); break;
			case "isFinal": this.isFinal = v.boolean(); break;
			case "linkage": this.linkage = v.str(); break;
			case "hasBody": this.hasBody = v.boolean(); break;
			case "typeFull": this.typeFull = v.str(); break;
			case "children": children.fromArray(ref v); break;
			case "isExtern": this.isExtern = v.boolean(); break;
			case "isStatic": this.isStatic = v.boolean(); break;
			case "isProperty": this.isProperty = v.boolean(); break;
			case "isAbstract": this.isAbstract = v.boolean(); break;
			case "parentFull": break; // TODO
			case "forceLabel": break; // TODO
			case "interfaces": break; // TODO
			case "isOverride": this.isOverride = v.boolean(); break;
			case "mangledName": this.mangledName = v.str(); break;
			case "isStandalone": this.isStandalone = v.boolean(); break;
			case "interfacesFull": break; // TODO
			default:
				io.error.writefln("unknown key '" ~ k ~ "'");
				io.error.flush();
			}
		}
	}

	fn copyToBase(b: Base)
	{
		b.kind = kind;
	}

	fn copyToNamed(b: Named)
	{
		copyToBase(b);
		b.name = name;
		b.raw = doc;
		b.access = access;
	}

	fn copyToParent(b: Parent)
	{
		copyToNamed(b);
		b.children = children;
	}

	fn toNamed() Named
	{
		b := new Named();
		copyToNamed(b);
		return b;
	}

	fn toImport() Import
	{
		b := new Import();
		copyToNamed(b);
		b.bind = bind;
		return b;
	}

	fn toParent() Parent
	{
		b := new Parent();
		copyToParent(b);
		return b;
	}

	fn toEnum() Parent
	{
		e := new Parent();
		copyToParent(e);
		return e;
	}

	fn toEnumDecl() EnumDecl
	{
		ed := new EnumDecl();
		copyToNamed(ed);
		ed.isStandalone = isStandalone;
		return ed;
	}

	fn toArg() Arg
	{
		b := new Arg();
		copyToBase(b);
		b.name = name;
		b.type = type;
		b.typeFull = typeFull;
		return b;
	}

	fn toReturn() Return
	{
		b := new Return();
		copyToBase(b);
		b.type = type;
		b.typeFull = typeFull;
		return b;
	}

	fn toVariable() Variable
	{
		b := new Variable();
		copyToNamed(b);
		b.type = type;
		b.typeFull = typeFull;
		b.storage = storage;
		return b;
	}

	fn toFunction() Function
	{
		b := new Function();
		copyToNamed(b);
		b.args = args;
		b.rets = rets;
		b.hasBody = hasBody;
		b.linkage = linkage;
		switch (kind) with (Kind) {
		case Destructor: b.name = "~this"; break;
		case Constructor: b.name = "this"; break;
		default:
		}
		return b;
	}
}

fn fromArray(ref arr: Value[], ref v: json.Value, defKind: Kind = Kind.Invalid)
{
	foreach (ref e; v.array()) {
		info: Info;
		info.kind = defKind;
		info.getFields(ref e);
		final switch (info.kind) with (Kind) {
		case Invalid:
			io.error.writefln("kind not specified");
			io.error.flush();
			break;
		case Arg: arr ~= info.toArg(); break;
		case Enum: arr ~= info.toEnum(); break;
		case Alias: break; // TODO Add alias
		case Group: break; // Handled somewhere else.
		case EnumDecl: arr ~= info.toEnumDecl(); break;
		case Class: arr ~= info.toParent(); break;
		case Union: arr ~= info.toParent(); break;
		case Import: arr ~= info.toImport(); break;
		case Return: arr ~= info.toReturn(); break;
		case Struct: arr ~= info.toParent(); break;
		case Module: arr ~= info.toParent(); break;
		case Member: arr ~= info.toFunction(); break;
		case Variable: arr ~= info.toVariable(); break;
		case Function: arr ~= info.toFunction(); break;
		case Interface: arr ~= info.toParent(); break;
		case Destructor: arr ~= info.toFunction(); break;
		case Constructor: arr ~= info.toFunction(); break;
		}
	}
}

fn getKindFromString(str: string) Kind
{
	switch (str) with (Kind) {
	case "fn": return Function;
	case "var": return Variable;
	case "ctor": return Constructor;
	case "dtor": return Destructor;
	case "enum": return Enum;
	case "enumdecl": return EnumDecl;
	case "alias": return Alias;
	case "class": return Class;
	case "union": return Union;
	case "import": return Import;
	case "struct": return Struct;
	case "module": return Module;
	case "member": return Member;
	case "interface": return Interface;
	default:
		io.error.writefln("unknown kind '%s'", str);
		io.error.flush();
		return Invalid;
	}
}

fn getAccessFromString(str: string) Access
{
	switch (str) with (Access) {
	case "public": return Public;
	case "protected": return Protected;
	case "private": return Private;
	case "(invalid)": return Public; // Temporary work-around.
	default:
		io.error.writefln("unknown access '%s'", str);
		io.error.flush();
		return Public;
	}
}

fn getStorageFromString(str: string) Storage
{
	switch (str) with (Storage) {
	case "field": return Field;
	case "global": return Global;
	case "local": return Local;
	default:
		io.error.writefln("unknown storage '%s'", str);
		io.error.flush();
		return Global;
	}
}

//! Parser for getting defgroup name and title.
public class DocCommentDefGroup : vdoc.DocSink
{
public:
	groupName: string;
	groupTitle: string;


public:
	final fn parseRaw(raw: string, out defgroup: string, out title: string)
	{
		groupName = null;
		groupTitle = null;

		vdoc.parse(raw, this, null);

		defgroup = this.groupName;
		title = this.groupTitle;
	}

	override fn defgroup(sink: Sink, group: string, text: string)
	{
		groupName = group;
		groupTitle = strip(text);
	}

	override fn start(sink: Sink) { }
	override fn end(sink: Sink) { }
	override fn briefStart(sink: Sink) { }
	override fn briefEnd(sink: Sink) { }
	override fn saStart(sink: Sink) { }
	override fn saEnd(sink: Sink) { }
	override fn paramStart(sink: Sink, direction: string, arg: string) { }
	override fn paramEnd(sink: Sink) { }
	override fn returnStart(sink: Sink) { }
	override fn returnEnd(sink: Sink) { }

	override fn p(sink: Sink, state: vdoc.DocState, d: string) { }
	override fn link(sink: Sink, state: vdoc.DocState, target: string, text: string) { }
	override fn content(sink: Sink, state: vdoc.DocState, cnt: string) { }

	override fn ingroup(sink: Sink, group: string) { }
}
