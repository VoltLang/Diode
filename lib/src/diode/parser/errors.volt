// Copyright © 2015-2018, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/diode/license.volt (BOOST ver. 1.0).
module diode.parser.errors;

import watt.text.source : Location;
import watt.text.format : format;

alias ErrorDg = dg(string);


fn makeBadHeader(ref loc: Location, err: ErrorDg)
{
	err(format("%s error: invalid header", loc.toString()));
}
