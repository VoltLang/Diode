// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.interfaces;

import watt.path : removeTrailingSlashes;


/**
 * Main class driving everything.
 */
abstract class Driver
{
public:
	settings : Settings;


public:
	this(settings : Settings)
	{
		this.settings = settings;
	}

	abstract fn addLayout(source : string, filename : string);
	abstract fn addDoc(source : string, filename : string);
	abstract fn renderFile(source : string, filename : string);
}

/**
 * Holds settings for Diode.
 */
class Settings
{
public:
	workDir : string;
	outputDir : string;
	layoutDir : string;
	includeDir : string;

	titleDefault : string = "Title";
	layoutDefault : string = "default";
	url : string = "http://example.com";

	// These depend on workDir and are set with fillInDefaults.
	enum string workDirDefault = null;
	enum string outputDirDefault = "_site";
	enum string layoutDirDefault = "_layouts";
	enum string includeDirDefault = "_includes";


public:
	fn fillInDefaults()
	{
		if (workDir is null) {
			removeTrailingSlashes(ref workDir);
		}

		processPath(ref outputDir, outputDirDefault);
		processPath(ref layoutDir, layoutDirDefault);
		processPath(ref includeDir, includeDirDefault);
	}

	fn processPath(ref val : string, def : string)
	{
		if (val is null) {
			val = def;
			if (workDir is null) {
				val = workDir ~ '/' ~ val;
			}
		}

		removeTrailingSlashes(ref val);
	}
}
