// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.interfaces;

import watt.path : removeTrailingSlashes, dirSeparator;


/*!
 * Main class driving everything.
 */
abstract class Driver
{
public:
	settings: Settings;


public:
	this(settings: Settings)
	{
		this.settings = settings;
	}

	abstract fn addBuiltins();
	abstract fn processDoc();
	abstract fn setConfig(source: string, filename: string);
	abstract fn addLayout(source: string, filename: string);
	abstract fn addInclude(source: string, filename: string);
	abstract fn addDoc(source: string, filename: string);
	abstract fn addDocTemplate(source: string, filename: string);
	abstract fn renderFile(source: string, filename: string, output: string);

	abstract fn verbose(fmt: string, ...);
	abstract fn info(fmt: string, ...);
	abstract fn warning(fmt: string, ...);
}

/*!
 * Holds settings for Diode.
 */
class Settings
{
public:
	sourceDir: string;
	vdocDir: string;
	outputDir: string;
	layoutDir: string;
	includeDir: string;
	urlFromCommandLine: bool;
	url: string = "http://example.com";
	baseurlFromCommandLine: bool;
	baseurl: string = "/mybase";

	//! Temporary hack for guru untill we add vdoc cross-reference code.
	guruHackSuffix: string;

	// These depend on workDir and are set with fillInDefaults.
	enum string vdocDirDefault = "_vdoc";
	enum string outputDirDefault = "_site";
	enum string layoutDirDefault = "_layouts";
	enum string includeDirDefault = "_includes";


public:
	fn fillInDefaults()
	{
		if (sourceDir !is null) {
			removeTrailingSlashes(ref sourceDir);
			sourceDir ~= dirSeparator;
		}

		processPath(ref vdocDir, vdocDirDefault);
		processPath(ref outputDir, outputDirDefault);
		processPath(ref layoutDir, layoutDirDefault);
		processPath(ref includeDir, includeDirDefault);

		// Make sure that all dirs have the same form.
		if (sourceDir !is null) {
			removeTrailingSlashes(ref sourceDir);
		}
	}

	fn processPath(ref val: string, def: string)
	{
		if (val is null) {
			val = def;
			if (sourceDir !is null) {
				val = sourceDir ~ val;
			}
		}

		removeTrailingSlashes(ref val);
	}
}
