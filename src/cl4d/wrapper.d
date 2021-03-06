// cl4d - a D wrapper for the Derelict OpenCL binding
// written in the D programming language
//
// Copyright: Andreas Hollandt 2009 - 2011,
//            MeinMein 2013-2014.
// License:   Boost License 1.0
//            (See accompanying file LICENSE_1_0.txt or copy at
//             http://www.boost.org/LICENSE_1_0.txt)
// Authors:   Andreas Hollandt,
//            Gerbrand Kamphuis (meinmein.com).

module cl4d.wrapper;

import cl4d.error;
import derelict.opencl.cl;
import cl4d.kernel;
import cl4d.memory;
import cl4d.platform;
import cl4d.device;
import cl4d.event;

import std.array;

package
{
	alias const(char) cchar; //!
	alias const(wchar) cwchar; //!
	alias const(dchar) cdchar; //!
	alias immutable(char) ichar; //!
	alias immutable(wchar) iwchar; //!
	alias immutable(dchar) idchar; //!
	alias const(char)[] cstring; //!
}

/**
 *	this function is used to mixin low level CL C object handling into all CL classes
 *	namely info retrieval and reference counting methods
 *
 *	It should be a template mixin, but unfortunately those can't add constructors to classes
 */ 
public string CLWrapper(string T, string classInfoFunction)
{
	//return "private:alias " ~ T ~ " T;\n" ~ q{
	return
"private:\n" ~
	"enum Tname = \"" ~ T ~ "\";\n" ~
	"alias " ~ T ~ " T;\n" ~ q{

	package T _object;
	//public alias _object this; // TODO any merit?
	package alias T CType; // remember the C type

public:
	//! wrap OpenCL C API object
	//! this doesn't change the reference count
	this(T obj)
	{
		_object = obj;

		// NOTE: cl_platform_id and cl_device_id aren't reference counted
		static if (Tname[$-3..$] != "_id")
		{
			debug writef("wrapped %s %X. Reference count is: %d\n", Tname, cast(void*) _object, referenceCount);
		}
	}

debug private import std.stdio;

	//! copy and increase reference count
	this(this)
	{
		// increment reference count
		retain();
	}

	//! release the object
	~this()
	{
		if (_object is null)
			return;

		release();
	}

	//! ensure that _object isn't null
	invariant()
	{
		// Workaround: cl_mem is nulled by release() in destructor, and invariant() is called at end of destructor
		// FIXME: seems broken in multiple ways..
		//assert(_object !is null || Tname == "cl_mem", Tname ~ " invariant violated: _object is null");
	}

package:
	// return the internal OpenCL C object
	// should only be used inside here so reference counting works
	final @property T cptr() const
	{
		return cast(void*)_object;
	}

	//! increments the object reference count
	void retain()
	{
		static if (Tname == "cl_device_id")
		{
			if(DerelictCL.loadedVersion >= CLVersion.CL12)
				clRetainDevice(_object);
		}

		// NOTE: cl_platform_id and cl_device_id aren't reference counted
		// Tname is compared instead of T itself so it also works with T being an alias
		// platform and device will have an empty retain() so it can be safely used in this()
		static if (Tname[$-3..$] != "_id")
		{
			mixin("cl_errcode res = clRetain" ~ toCamelCase(Tname[2..$]) ~ (Tname == "cl_mem" ? "Object" : "") ~ "(_object);");
			mixin(exceptionHandling(
				["CL_OUT_OF_RESOURCES",		""],
				["CL_OUT_OF_HOST_MEMORY",	""],
				["CL_INVALID" ~ toUpperCase(Tname[2..$] ~ (Tname == "cl_mem" ? "_Object" : "")), ""],
			));

			debug writef("copied %s %X. Reference count is: %d\n", Tname, cast(void*) _object, referenceCount);
		}
	}
	
	/**
	 *	decrements the context reference count
	 *	The object is deleted once the number of instances that are retained to it become zero
	 */
	package void release()
	{
		static if (Tname == "cl_device_id")
		{
			if(DerelictCL.loadedVersion >= CLVersion.CL12)
				clReleaseDevice(_object);
		}

		// NOTE: cl_platform_id and cl_device_id aren't reference counted
		static if (Tname[$-3..$] != "_id")
		{
			debug writef("released %s %X. Reference count is: %d\n", Tname, cast(void*) _object, referenceCount-1);

			mixin("cl_errcode res = clRelease" ~ toCamelCase(Tname[2..$]) ~ (Tname == "cl_mem" ? "Object" : "") ~ "(_object);");
			mixin(exceptionHandling(
				["CL_OUT_OF_RESOURCES",		""],
				["CL_OUT_OF_HOST_MEMORY",	""],
				["CL_INVALID" ~ toUpperCase(Tname[2..$] ~ (Tname == "cl_mem" ? "_Object" : "")), ""],
			));
		}
	}
	private import std.string;
	/**
	 *	Return the reference count
	 *
	 *	The reference count returned should be considered immediately stale. It is unsuitable for general use in 
	 *	applications. This feature is provided for identifying memory leaks
	 */
	public @property cl_uint referenceCount() const
	{
		static if (Tname[$-3..$] != "_id")
		{
			// HACK: not even toUpper works in CTFE anymore as of 2.054 *sigh*
			mixin("return getInfo!cl_uint(CL_" ~ (Tname == "cl_command_queue" ? "QUEUE" : (){char[] tmp = Tname[3..$].dup; toUpperInPlace(tmp); return tmp;}()) ~ "_REFERENCE_COUNT);");
		}
		else
			return 0;
	}

protected:
	/**
	 *	a wrapper around OpenCL's tedious clGet*Info info retrieval system
	 *	this version is used for all non-array types
	 *
	 *	USE WITH CAUTION!
	 *
	 *	Params:
	 *		U				= the return type of the information to be queried
	 *		infoFunction	= optionally specify a special info function to be used
	 *		infoname		= information op-code
	 *
	 *	Returns:
	 *		queried information
	 */
	// TODO: make infoname type-safe, not cl_uint (can vary for certain _object, see cl_mem)
	final U getInfo(U, alias infoFunction = }~classInfoFunction~q{)(cl_uint infoname) const
	{
		cl_errcode res;
		
		debug
		{
			size_t needed;

			// get amount of memory necessary
			res = infoFunction(cast(void*)_object, infoname, 0, null, &needed);
	
			// error checking
			if (res != CL_SUCCESS)
				throw new CLException(res);
			
			assert(needed == U.sizeof);
		}
		
		U info;

		// get actual data
		res = infoFunction(cast(void*)_object, infoname, U.sizeof, &info, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return info;
	}
	
	/**
	 *	this special version is only used for clGetProgramBuildInfo and clGetKernelWorkgroupInfo
	 *
	 *	See_Also:
	 *		getInfo
	 */
	U getInfo2(U, alias altFunction)( cl_device_id device, cl_uint infoname) const
	{
		cl_errcode res;
		
		debug
		{
			size_t needed;

			// get amount of memory necessary
			res = altFunction(cast(void*)_object, device, infoname, 0, null, &needed);
	
			// error checking
			if (res != CL_SUCCESS)
				throw new CLException(res);
			
			assert(needed == U.sizeof);
		}
		
		U info;

		// get actual data
		res = altFunction(cast(void*)_object, device, infoname, U.sizeof, &info, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return info;
	}

	/**
	 *	this version is used for all array return types
	 *
	 *	Params:
	 *		U	= array element type
	 *
	 *	See_Also:
	 *		getInfo
	 */
	// helper function for all OpenCL Get*Info functions
	// used for all array return types
	final U[] getArrayInfo(U, alias infoFunction = }~classInfoFunction~q{)(cl_uint infoname) const
	{
		size_t needed;
		cl_errcode res;

		// get amount of needed memory
		res = infoFunction(cast(void*)_object, infoname, 0, null, &needed);

		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);

		// e.g. CL_CONTEXT_PROPERTIES can return needed = 0
		if (needed == 0)
			return null;

		auto buffer = new U[needed/U.sizeof];

		// get actual data
		res = infoFunction(cast(void*)_object, infoname, needed, cast(void*)buffer.ptr, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return buffer;
	}
	
	/**
	 *	special version only used for clGetProgramBuildInfo and clGetKernelWorkgroupInfo
	 *
	 *	See_Also:
	 *		getArrayInfo
	 */
	U[] getArrayInfo2(U, alias altFunction)(cl_device_id device, cl_uint infoname) const
	{
		size_t needed;
		cl_errcode res;

		// get amount of needed memory
		res = altFunction(cast(void*)_object, device, infoname, 0, null, &needed);

		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);

		// e.g. CL_CONTEXT_PROPERTIES can return needed = 0
		if (needed == 0)
			return null;

		auto buffer = new U[needed/U.sizeof];

		// get actual data
		res = altFunction(cast(void*)_object, device, infoname, needed, cast(void*)buffer.ptr, null);
		
		// error checking
		if (res != CL_SUCCESS)
			throw new CLException(res);
		
		return buffer;
	}

	/**
	 *	convenience shortcut
	 *
	 *	See_Also:
	 *		getArrayInfo
	 */
	final string getStringInfo(alias infoFunction = }~classInfoFunction~q{)(cl_uint infoname) const
	{
		auto str = cast(string) getArrayInfo!(ichar, infoFunction)(infoname);
		return tr(str, "\0", "", "d");
	}

}; // return q{...}
} // of CLWrapper function

/**
 *	a collection of OpenCL objects returned by some methods
 *	Params:
 *		T = a cl4d object like CLKernel
 */
package struct CLObjectCollection(T)
{
	T[] _objects;
	alias _objects this;

	//! takes a list of cl4d CLObjects
	// Do not use variadic, messes everything up.
	this(T[] objects)
	in
	{
		assert(objects !is null);
	}
	body
	{
		// copy objects
		_objects = objects.dup;
	}

	//! takes a list of OpenCL C objects returned by some OpenCL functions like GetPlatformIDs
	this(T.CType[] objects)
	in
	{
		assert(objects !is null);
	}
	body
	{
		// we safely reinterpret cast here since T just wraps a T.CType
		_objects = cast(T[]) objects;
	}

	this(this)
	{
		_objects = _objects.dup; // calls postblits :)
	}

	//! release all objects
	~this()
	{
		foreach (object; _objects)
			object.release();
	}

	//!
	package @property auto ptr() const
	{
		return cast(const(T.CType)*) _objects.ptr;
	}
}
