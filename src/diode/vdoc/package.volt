// Copyright © 2016-2017, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.vdoc;

import io = watt.io;
import watt.text.vdoc;

import diode.errors;
import diode.eval;


/*!
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
	Group,
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

//! Access of a symbool.
enum Access
{
	Public,
	Protected,
	Private,
}

fn accessToString(access: Access) string
{
	final switch (access) with (Access) {
	case Public: return "public";
	case Protected: return "protected";
	case Private: return "private";
	}
}

//! Storage of a variable.
enum Storage
{
	Field,
	Global,
	Local,
}

/*!
 * The object that templates accesses the rest of the documentation nodes from.
 */
class VdocRoot : Value
{
public:
	//! Current thing that a vdoc template is rendering.
	current: Value;
	//! Set holding config data.
	set: Set;


private:
	//! All loaded Named objects.
	mNamed: Named[string];
	//! All loaded modules.
	mModules: Parent[];
	//! All loaded groups.
	mGroups: Parent[];
	//! All children as a array.
	mChildren: Value[];


public:
	this()
	{
		set = new Set();
	}

	@property fn modules() Parent[]
	{
		return mModules;
	}

	@property fn groups() Parent[]
	{
		return mGroups;
	}

	override fn ident(n: ir.Node, key: string) Value
	{
		c := Collection.make(mChildren, key);
		if (c !is null) {
			return c;
		}

		switch (key) {
		case "current": return current is null ? new Nil() : current;
		case "name": return set.ident(n, key);
		default: return super.ident(n, key);
		}
	}

	//! Return a named object of the given name.
	fn findNamed(name: string) Named
	{
		// TODO this should be a lot smarter,
		// as it needs to search for children of modules.
		// pkg.mod.Class must work.
		if (r := name in mNamed) {
			return *r;
		}

		return null;
	}

	//! Add a group, mostly used to create groups implicitly.
	fn addGroup(name: string, title: string, raw: string) Parent
	{
		g := new Parent();
		g.kind = Kind.Group;
		g.raw = raw;
		g.name = title;
		g.search = name;

		mGroups ~= g;
		mNamed[name] = g;

		return g;
	}

	/*!
	 * Sets the children and does any upfront processing needed.
	 *
	 * Any old children are removed.
	 */
	fn setChildren(children: Value[])
	{
		mChildren = children;
		mModules = [];

		foreach (v; children) {
			p := cast(Parent)v;
			if (p is null) {
				continue;
			}

			switch (p.kind) with (Kind) {
			case Module: mModules ~= p; break;
			case Group: mGroups ~= p; break;
			default:
			}

			ident := p.search !is null ? p.search : p.name;
			mNamed[ident] = p;
		}
	}
}

/*!
 * Base class for all doc objects.
 */
class Base : Value
{
	kind: Kind;
}

/*!
 * Base class for all doc objects that can have names.
 */
class Named : Base
{
public:
	//! Printable name of this object.
	name: string;
	//! Ident for looking up this Named thing.
	search: string;
	//! Access of this named object.
	access: Access;
	//! Raw doccomment string.
	raw: string;
	//! Where to find the per thing documentation page, if any.
	url: string;
	//! A unique identifier for this object.
	tag: string;
	//! The full comment as markdown.
	mdFull: string;
	//! The brief in text form.
	brief: string;
	//! The groups this named is in.
	ingroup: Value[];


public:
	override fn ident(n: ir.Node, key: string) Value
	{
		switch (key) {
		case "name": return new Text(name);
		case "url": return makeNilOrText(url);
		case "raw": return new Text(raw);
		case "access": return new Text(accessToString(access));
		case "tag": return new Text(tag);
		case "ingroup":
			if (ingroup is null) {
				return new Nil();
			} else {
				return new Collection(ingroup);
			}
		default: return new Nil();
		}
	}
}

/*!
 * Regular imports and bound imports.
 */
class Import : Named
{
public:
	//! Is this import bound to a name.
	bind: string;


public:
	override fn ident(n: ir.Node,  key: string) Value
	{
		switch (key) {
		case "bind": return makeNilOrText(bind);
		default: return super.ident(n, key);
		}
	}
}

/*!
 * A single freestanding enum or value part of a enum.
 */
class EnumDecl : Named
{
public:
	//! Is this a enum 
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

/*!
 * Base class for things with children, like Module, Class, Structs.
 */
class Parent : Named
{
public:
	//! The children of this Named thing.
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

/*!
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

/*!
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

/*!
 * A variable or field on a aggregate.
 */
class Variable : Named
{
public:
	type: string;
	typeFull: string;
	storage: Storage;


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

/*!
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

/*!
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
		case "children":
		case "all":
			if (vals.length > 0) {
				return new Collection(vals);
			} else {
				return new Nil();
			}
		case "enums": kind = Enum; break;
		case "groups": kind = Group; break;
		case "classes": kind = Class; break;
		case "imports": kind = Import; break;
		case "unions": kind = Union; break;
		case "structs": kind = Struct; break;
		case "modules": kind = Module; break;
		case "enumdecls": kind = EnumDecl; break;
		case "functions": kind = Function; break;
		case "variables": kind = Variable; break;
		case "interfaces": kind = Interface; break;
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

/*!
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

/*!
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
