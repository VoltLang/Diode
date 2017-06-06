---
layout: page
title: JSON Output
---

# JSON Output

The Volt compiler can be instructed to output info about the modules it compiled. Simply use the `-jo` switch when invoking the compiler:

    volt -jo outputfile.json main.volt

The above will compile `main.volt` as usual, but will output information in the file `outputfile.json`, structured as a [JSON](http://www.json.org) object. The purpose of this document is to briefly overview the structure of the file.

## Structure

No matter how many modules (`.volt` files) are compiled, all of the information will be contained in a JSON object. This object will have two fields: `target` and `modules`. The `target` field contains an object that describes the platform that these modules were being compiled for, while the `modules` field contains an array of objects containing data about each module compiled.

## Target

The target is the system that is being compiled for. This does not have to match the system that the code was compiling it (the 'host').

	// An example of the target object.
	"target": {
		"arch": "x86_64",
		"platform": "msvc",
		"isP64": true,
		"ptrSize": 8,
		"alignment": {
			"int1": 1,
			"int8": 1,
			"int16": 2,
			"int32": 4,
			"int64": 8,
			"float32": 4,
			"float64": 8,
			"ptr": 8,
			"aggregate": 8
		}
	}

`arch` is a string that denotes the CPU architecture of the target.
**Some Possible Values**:
	`"x86"`:  The 32 bit Intel x86 architecture.
	`"x86_64"`: The 64 bit Intel x86 architecture. Often known as `amd64`.

`platform` is the operating environment of the target.
**Some Possible Values**
    `"mingw"`: Windows, using the `MinGW` compiler suite as a linker.
    `"msvc"`: Windows, using the Microsoft VisualC++ linker.
    `"linux"`: Linux.
    `"osx"`: Mac OS X.
    `"metal"`: A Swedish progrock OS. You've probably never heard of it.

`isP64` is a boolean value that if present means pointers are 64 bits in size.

`ptrSize` is the size of a pointer, in bytes.

`alignment` is an object containing [alignment information](https://en.wikipedia.org/wiki/Data_structure_alignment) for the target.
`int1` through `int64` contain the alignment of their respective integer values. `float32` and `float64` contain the alignment of 32 bit floating point values, and 64 bit doubles, respectively. `ptr` is the alignment of pointer values, and `aggregate` is the alignment of `struct`s.

## Common Fields

These fields appear in most objects, and serve the same purpose in each. If these fields appear in the examples of an object, it means that they can appear in that object, and their purpose will not be documented redundantly.

`kind` is a string that each object has that 'tags' the language structure that that object is documenting. For each type the specific string will be in its example.

`name` is the user displayable name of the given object. For user defined types, it will be the name of that type, etc.

`mangledName` is the 'mangled' name that is used in object files and the like.

If `doc` is present, it contains a string with the raw doccomment attached to that language structure. This string will contain comment notation, newlines, etc, and will need to be cleaned if it is to be displayed.

If `children` is present, it is a list of child language structures. A Modules `children` would contain a struct that was in that module, and that struct's `children` would contain the variables that make up its fields, and so on.

`access` is the access level of the given language structure. This can be `"public"`, `"private"`, or `"protected"`.

## Modules

    {
	    "kind": "module",
		"name": "...",
		"children": [{...}]
	}

### Struct

    {
        "kind": "struct",
        "name": "...",
        "mangledName": "...",
        "doc": "...",
        "access": "...",
        "children": [{...}]
    }

### Union

    {
        "kind": "union",
        "name": "...",
        "mangledName": "...",
        "doc": "...",
        "access": "...",
        "children": [{...}]
    }

### Class

    {
        "kind": "class",
        "name": "...",
        "mangledName": "...",
        "parent": "...",
        "parentFull": "...",
        "interfaces": ["..."],
        "interfacesFull": ["..."],
        "doc": "...",
        "access": "...",
        "isAbstract": true,
        "isFinal": true,
        "children": [{...}]
    }

If present, `parent` is a string containing the name of this classes parent class. `parentFull` is the same, but the fully qualified name.

If present, `interfaces` is an array of strings of interfaces this class implements. `interfacesFull` is the same, but the fully qualified names.

`isAbstract` is a `boolean` value that is present when the given class is an `abstract` class.

`isFinal` is a `boolean` value that is present when the given class is an `final` class.

### Interface

    {
        "kind": "interface",
        "name": "...",
        "mangledName": "...",
        "parents": ["..."],
        "parentsFull": ["..."],
        "doc": "...",
        "access": "...",
        "children": [{...}]
    }

If present, `parents` is a list string containing the name of this interface's parent interfaces. `parentsFull` is the same, but the fully qualified names.

### Alias

    {
        "kind": "alias",
        "name": "...",
        "doc": "...",
        "type": "..."
    }

`type` is a `string` of the name of the type that this alias points to.

### Import

    {
        "kind": "import",
        "access": "...",
        "isStatic": true,
        "name": "...",
        "bind": "...",
        "aliases" [[...]]
    }

This object corresponds to an `import` statement.

A `public` import will have its access value set to `"public"`.

`isStatic` is a `boolean` value that is present if the given import is a static import.

`bind` is a string that corresponds to the left-hand-side of an import bind:
    import <bind> = package.mod;

`aliases` is a list of lists of strings. Each element corresponds to an import alias. Given the statement

    import mod : a = b, c

would result in the following `aliases` array:

    `[["a", "b"], ["c"]]`

### Function

    {
        "kind": "...",  // See comments below.
        "name": "...",
        "mangledName": "...",
        "doc": "...",
        "linkage": "...",
        "args": [{...}],
        "hasBody": true,
        "access": "...",
        "isScope": true,
        "isOverride": true,
        "isAbstract": true,
        "isFinal": true,
        "forceLabel": true
    }

`kind` is either `"fn"` for a regular function, `"member"` for a member function, `"ctor"` for a constructor, or `"dtor"` for a destructor.

`linkage` is either `"c"`, `"c++"`, `"d"`, `"volt"`, `"pascal"`, or `"windows"`, denoting what the linkage of this function is.

`args` is a list of objects that document the types and names of the arguments to this function.

`isScope` is present if this function is scoped.

`isOverride` is present if this function is overriding another function.

`isAbstract` is present if this function is marked as an abstract function.

`isFinal` is present if this function marked as final.

`forceLabel` is present if this function must be called with explicit parameter labels.

`hasBody` is present if this function has a defined body.

### Variable

    {
        "kind": "var",
        "name": "...",
        "mangledName": "...",
        "type": "...",
        "doc": "...",
        "access": "...",
        "linkage": "...",
        "storage": "...",
        "isExtern": true
    }

`type` is a string with the type of this variable.

`linkage` is either `"c"`, `"c++"`, `"d"`, `"volt"`, `"pascal"`, or `"windows"`, denoting how this variable is mangled.

`storage` is either `"field"`, `"function"`, `"nested"`, `"local"`, or `"global"`, depending on where this variable exists.

`isExtern` is present if the variable is marked as `extern`.

### Enum

    {
        "kind": "enum",
        "name": "...",
        "mangledName": "...",
        "doc": "...",
        "access": "...",
        "children": [{...}]
    }

### Enum Declaration

    {
        "kind": "enumdecl",
        "name": "...",
        "type": "...",
        "doc": "...",
        "value": "...",
        "access": "...",
        "isStandalone": true
    }
    
`value`, if present, contains a string containing the value of this enum.

`isStandalone` is present if this is a standalone enum, and not the child of a regular enum. (e.g., it is of the form `enum Name = 32;`)
    
