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

module cl4d.sampler;

import derelict.opencl.cl;
import cl4d.context;
import cl4d.error;
import cl4d.wrapper;

/**
 *	A sampler object describes how to sample an image when the image is read in the kernel
 *
 *	The built-in functions to read from an image in a kernel take a sampler as an argument.
 *	The sampler arguments to the image read function can be sampler objects created using OpenCL functions
 *	and passed as argument values to the kernel or can be samplers declared inside a kernel.
 */
struct CLSampler
{
	mixin(CLWrapper("cl_sampler", "clGetSamplerInfo"));

public:
	/**
	 *	creates a sampler object
	 *
	 *	Params:
	 *		normalizedCoords= determines if the image coordinates specified are normalized
	 *		addressingMode	= specifies how out-of-range image coordinates are handled when reading from an image
	 *		filterMode		= specifies the type of filter that must be applied when reading an image
	 */
	this(CLContext context, cl_bool normalizedCoords, cl_addressing_mode addressingMode, cl_filter_mode filterMode)
	{
		cl_errcode res;
		this(clCreateSampler(context.cptr, normalizedCoords, addressingMode, filterMode, &res));
		
		mixin(exceptionHandling(
			["CL_INVALID_CONTEXT",		""],
			["CL_INVALID_VALUE",		"addressingMode, filterMode, normalizedCoords or combination of these argument values are not valid"],
			["CL_INVALID_OPERATION",	"images are not supported by any device associated with context"],
			["CL_OUT_OF_RESOURCES",		""],
			["CL_OUT_OF_HOST_MEMORY",	""]
		));
	}

	@property
	{
		//! the context specified when the sampler was created
		CLContext context()
		{
			return CLContext(getInfo!cl_context(CL_SAMPLER_CONTEXT));
		}

		//!
		cl_bool normalizedCoords()
		{
			return getInfo!cl_bool(CL_SAMPLER_NORMALIZED_COORDS);
		}

		//!
		cl_addressing_mode addressingMode()
		{
			return getInfo!cl_addressing_mode(CL_SAMPLER_ADDRESSING_MODE); 
		}

		//!
		cl_filter_mode filterMode()
		{
			return getInfo!cl_filter_mode(CL_SAMPLER_FILTER_MODE); 
		}
	} // of @property
}
