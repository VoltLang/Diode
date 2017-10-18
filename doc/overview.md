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

