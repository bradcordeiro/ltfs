LTFS
====

A Ruby gem to help parse LTFS index schema files.
-------------------------------------------------

### Requirements
+ XmlSimple

This gem is in its infancy. I wrote most of this code while learning Ruby and Rails on a hobby project to keep a store of all of the files my company had stored on LTO5 tapes. Most LTFS software will allow you to save the index of all files and folders to your local disk in XML format. This gem is meant to help parse that XML into Ruby classes.

**Again I must stress that this is a hobby by a neophyte programmer and no warranty of safety or good design practice is implied.**

### New Classes:

**LTFSIndex**: Represents an LTFS index in its entirety, both data about a tape, and the files on it.

**LTFSTape**: Stores data about the overall tape itself.

**LTFSFile**: Stores data about an individual file on tape.

**LTFSExtentInfo**: Tapes written with bad practices (usually multiple simultaneous writes to a tape) cause some complexity in LTFS extent information, so this section of information on an LTFSFile has been abstracted to its own class to provide some sanity checks.
