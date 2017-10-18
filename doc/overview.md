---
layout: page
title: Volt Documentation Overview
---

# Volt Documentation Overview

This document is intended for people writing software in Volt, documenting the various pieces of the Volt documentation system. The pieces are not contained in a single project, so this should hopefully provide some clarity to those that are confused.

As mentioned, the documentation system is made up of several pieces. Broadly, those pieces are as follows:

- Documentation Comments
- Volta JSON Output
- VDoc Syntax Parsing
- The Diode Documentation Generation Tool

Volt's official documentation uses these tools, and is split up over several repositories:

- [VoltLang/Website](https://github.com/VoltLang/Website) contains the volt-lang.org main website templates, to be generated with Diode.
- [VoltLang/Docs](https://github.com/VoltLang/Docs) contains the 'Documentation' page of the volt-lang.org website, and is also to be generated with Diode.
- [VoltLang/Guru](https://github.com/VoltLang/Guru) contains the template for the volt.guru documentation website, and is generated with Diode, and the JSON output of various Volt libraries (Watt etc).

## Documentation Comments

Documentation comments are started by the character sequences `//!`, `/*!`, or `/+!`. If the `!` character is immediately followed by `<`, the documentation comment is associated with the previous declaration, otherwise it applies to the next declaration.

	aVariable: i32;  //!< This documents `aVariable`.
	/*! This documents `bVariable`. */
	bVariable: i32;

The contents of the documentation comments will be output as a string with the field `"doc"` in the [JSON output](jsonoutput.html). This is where the compiler's concern about documentation comments ends. The VDoc syntax is all handled by the `watt.text.vdoc` module, but nothing is stopping people from using their own syntax and parsers on the JSON output.

## Volta JSON Output

The JSON output contains information on the types and functions in a module, and is documented [here](jsonoutput.html).

## VDoc Syntax

The `watt.text.vdoc` module provides a parsing interface for parsing VDoc code. You likely want to go through Diode rather than use this directly, but this is the code responsible for parsing it.

## Diode

Diode uses a combination of the VDoc parser, and an implementation of the [Liquid Template Language](https://shopify.github.io/liquid/basics/introduction/) to generate a website.
