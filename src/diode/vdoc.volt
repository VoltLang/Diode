// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.vdoc;

import core.exception;
import watt.io.file;
import io = watt.io;
import json = watt.text.json;
import watt.text.vdoc;

import diode.errors;
import diode.eval;


/**
 * Type of doc object.
 */
enum Kind
{
	Invalid,
	Arg,
	Enum,
	EnumDecl,
	Alias,
	Class,
	Union,
	Import,
	Return,
	Struct,
	Module,
	Member,
	Function,
	Variable,
	Interface,
	Destructor,
	Constructor,
}

/// Access of a symbool.
enum Access
{
	Public,
	Protected,
	Private,
}

/// Storage of a variable.
enum Storage
{
	Field,
	Global,
	Local,
}

/**
 * Base class for all doc objects.
 */
class Base : Value
{
	kind: Kind;
}

/**
 * Base class for all doc objects that can have names.
 */
class Named : Base
{
public:
	/// Name of this object.
	name: string;
	/// Access of this named object.
	access: Access;
	/// Raw doccomment string.
	raw: string;


public:
	override fn ident(n: ir.Node, key: string) Value
	{
		switch (key) {
		case "name": return new Text(name);
		case "doc": return makeNilOrText(rawToFull(raw));
		case "brief": return makeNilOrText(rawToBrief(raw));
		case "access": return new Text(accessToString(access));
		default: throw makeNoField(n, key);
		}
	}
}

/**
 * A single freestanding enum or value part of a enum.
 */
class EnumDecl : Named
{
public:
	/// Is this a enum 
	isStandalone: bool;


public:
	override fn ident(n: ir.Node, key: string) Value
	{
		switch (key) {
		case "isStandalone": return new Bool(isStandalone);
		default: return super.ident(n, key);
		}
	}
}

/**
 * Base class for things with children, like Module, Class, Structs.
 */
class Parent : Named
{
public:
	children: Value[];


public:
	override fn ident(n: ir.Node, key: string) Value
	{
		c := Collection.make(children, key);
		if (c !is null) {
			return c;
		}

		return super.ident(n, key);
	}
}

/**
 * Argument to a function.
 */
class Arg : Base
{
public:
	name: string;
	type: string;
	typeFull: string;


public:
	override fn ident(n: ir.Node,  key: string) Value
	{
		switch (key) {
		case "name": return new Text(name);
		case "type": return new Text(type);
		case "typeFull": return new Text(typeFull);
		default: throw makeNoField(n, key);
		}
	}
}

/**
 * Return from a function.
 */
class Return : Base
{
public:
	type: string;
	typeFull: string;


public:
	override fn ident(n: ir.Node,  key: string) Value
	{
		switch (key) {
		case "type": return new Text(type);
		case "typeFull": return new Text(typeFull);
		default: throw makeNoField(n, key);
		}
	}
}

/**
 * A variable or field on a aggregate.
 */
class Variable : Named
{
public:
	type: string;
	typeFull: string;


public:
	override fn ident(n: ir.Node,  key: string) Value
	{
		switch (key) {
		case "type": return makeNilOrText(type);
		case "typeFull": return makeNilOrText(typeFull);
		default: return super.ident(n, key);
		}
	}
}

/**
 * A function or constructor, destructor or method on a aggreegate.
 */
class Function : Named
{
public:
	args: Value[];
	rets: Value[];
	linkage: string;
	hasBody: bool;
	forceLabel: bool;

	isFinal: bool;
	isScope: bool;
	isAbstract: bool;
	isProperty: bool;
	isOverride: bool;


public:
	override fn ident(n: ir.Node,  key: string) Value
	{
		switch (key) {
		case "args": return makeNilOrArray(args);
		case "rets": return makeNilOrArray(rets);
		case "linkage": return makeNilOrText(linkage);
		case "hasBody": return new Bool(hasBody);
		case "isFinal": return new Bool(isFinal);
		case "isScope": return new Bool(isScope);
		case "isAbstract": return new Bool(isAbstract);
		case "isProperty": return new Bool(isProperty);
		case "isOverride": return new Bool(isOverride);
		default: return super.ident(n, key);
		}
	}
}

/**
 * A special array that you can access fields on to filter the members.
 */
class Collection : Array
{
public:
	this(vals: Value[])
	{
		super(vals);
	}

	static fn make(vals: Value[], key: string) Value
	{
		kind: Kind;
		switch (key) with (Kind) {
		case "all":
			if (vals.length > 0) {
				return new Collection(vals);
			} else {
				return new Nil();
			}
		case "enums": kind = Enum; break;
		case "classes": kind = Class; break;
		case "unions": kind = Union; break;
		case "structs": kind = Struct; break;
		case "modules": kind = Module; break;
		case "enumdecls": kind = EnumDecl; break;
		case "functions": kind = Function; break;
		case "variables": kind = Variable; break;
		case "destructors": kind = Destructor; break;
		case "constructors": kind = Constructor; break;
		case "members", "methods": kind = Member; break;
		default: return null;
		}

		num: size_t;
		ret := new Value[](vals.length);
		foreach (v; vals) {
			b := cast(Base)v;
			if (b is null || b.kind != kind) {
				continue;
			}

			ret[num++] = v;
		}

		if (num > 0) {
			return new Collection(ret[0 .. num]);
		} else {
			return new Nil();
		}
	}

	override fn ident(n: ir.Node, key: string) Value
	{
		c := make(vals, key);
		if (c is null) {
			throw makeNoField(n, key);
		} else {
			return c;
		}
	}
}

/**
 * Create a text Value, nil if string is empty.
 */
fn makeNilOrText(text: string) Value
{
	if (text.length == 0) {
		return new Nil();
	} else {
		return new Text(text);
	}
}

/**
 * Create a array Value, nil if string is empty.
 */
fn makeNilOrArray(array: Value[]) Value
{
	if (array.length == 0) {
		return new Nil();
	} else {
		return new Array(array);
	}
}


/**
 * Used to collect information during parsing.
 */
struct Info
{
public:
	kind: Kind;
	name: string;
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
			case "rets": rets.fromArray(ref v, Kind.Arg); break;
			case "name": this.name = v.str(); break;
			case "type": this.type = v.str(); break;
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
			case "isOverride": this.isOverride = v.boolean(); break;
			case "mangledName": this.mangledName = v.str(); break;
			case "isStandalone": this.isStandalone = v.boolean(); break;
			default: io.writefln("unknown key '" ~ k ~ "'");
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
		case Invalid: throw new Exception("kind not specified");
		case Arg: arr ~= info.toArg(); break;
		case Enum: arr ~= info.toEnum(); break;
		case Alias: break; // TODO Add alias
		case EnumDecl: arr ~= info.toEnumDecl(); break;
		case Class: arr ~= info.toParent(); break;
		case Union: arr ~= info.toParent(); break;
		case Import: break; // TODO Add import
		case Return: arr ~= info.toReturn(); break;
		case Struct: arr ~= info.toParent(); break;
		case Module: arr ~= info.toParent(); break;
		case Member: arr ~= info.toFunction(); break;
		case Variable: arr ~= info.toVariable(); break;
		case Function: arr ~= info.toFunction(); break;
		case Interface: break; // TODO Add interface
		case Destructor: arr ~= info.toFunction(); break;
		case Constructor: arr ~= info.toFunction(); break;
		}
	}
}

fn accessToString(access: Access) string
{
	final switch (access) with (Access) {
	case Public: return "public";
	case Protected: return "protected";
	case Private: return "private";
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
	default: throw new Exception("unknown kind '" ~ str ~ "'");
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

fn parse(data: string) Value[]
{
	root := json.parse(data);
	moduleRoot := root.lookupObjectKey("modules");

	mods: Value[];
	mods.fromArray(ref moduleRoot);

	return mods;
}
