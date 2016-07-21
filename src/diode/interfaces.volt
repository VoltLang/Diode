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
	Settings settings;

public:
	this(Settings settings)
	{
		this.settings = settings;
	}

	abstract void addLayout(string source, string filename);
	abstract void addDoc(string source, string filename);
	abstract void renderFile(string source, string filename);
}

/**
 * Holds settings for Diode.
 */
class Settings
{
public:
	string workDir;
	string outputDir;
	string layoutDir;
	string includeDir;

	string titleDefault = "Title";
	string layoutDefault = "default";
	string url = "http://example.com";

	// These depend on workDir and are set with fillInDefaults.
	enum string workDirDefault = null;
	enum string outputDirDefault = "_site";
	enum string layoutDirDefault = "_layouts";
	enum string includeDirDefault = "_includes";

public:
	void fillInDefaults()
	{
		if (workDir is null) {
			removeTrailingSlashes(ref workDir);
		}

		processPath(ref outputDir, outputDirDefault);
		processPath(ref layoutDir, layoutDirDefault);
		processPath(ref includeDir, includeDirDefault);
	}

	void processPath(ref string val, string def)
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
