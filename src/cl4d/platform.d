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

module cl4d.platform;

public import derelict.opencl.cl;
import cl4d.device;
import cl4d.error;
import cl4d.wrapper;

//! Platform collection
alias CLObjectCollection!CLPlatform CLPlatforms;

//! Platform class
struct CLPlatform
{
	mixin(CLWrapper("cl_platform_id", "clGetPlatformInfo"));

public:
	/// get the platform handle
	T handle()
	{
		 return _object;
	}

	/// get the platform name
	string name()
	{
		 return getStringInfo(CL_PLATFORM_NAME);
	}
	
	/// get platform vendor
	string vendor()
	{
		 return getStringInfo(CL_PLATFORM_VENDOR);
	}

	/// get platform version
	string clversion()
	{
		 return getStringInfo(CL_PLATFORM_VERSION);
	}

	/// get platform profile
	string profile()
	{
		 return getStringInfo(CL_PLATFORM_PROFILE);
	}

	/// get platform extensions
	string extensions()
	{
		 return getStringInfo(CL_PLATFORM_EXTENSIONS);
	}
	
	/// returns a list of all devices available on the platform matching deviceType
	package CLDevices getDevices(cl_device_type deviceType)
	{
		cl_uint numDevices;
		cl_errcode res;
		
		// get number of devices
		res = clGetDeviceIDs(this._object, deviceType, 0, null, &numDevices);
		
		mixin(exceptionHandling(
			["CL_INVALID_PLATFORM",		""],
			["CL_INVALID_DEVICE_TYPE",	"There's no such device type"],
			["CL_INVALID_VALUE",		""],
			["CL_DEVICE_NOT_FOUND",		"Couldn't find an OpenCL device matching the given type"],
			["CL_OUT_OF_RESOURCES",		""],
			["CL_OUT_OF_HOST_MEMORY",	""]
		));
		
		// get device IDs
		auto deviceIDs = new cl_device_id[numDevices];

		res = clGetDeviceIDs(this._object, deviceType, cast(cl_uint) deviceIDs.length, deviceIDs.ptr, null);
		if(res != CL_SUCCESS)
			throw new CLException(res);
		
		// create CLDevice array
		return CLDevices(deviceIDs);
	}
	
	/// returns a list of all devices
	CLDevices allDevices()	{return getDevices(CL_DEVICE_TYPE_ALL);}
	
	/// returns a list of all CPU devices
	CLDevices cpuDevices()	{return getDevices(CL_DEVICE_TYPE_CPU);}
	
	/// returns a list of all GPU devices
	CLDevices gpuDevices()	{return getDevices(CL_DEVICE_TYPE_GPU);}
	
	/// returns a list of all accelerator devices
	CLDevices accelDevices() {return getDevices(CL_DEVICE_TYPE_ACCELERATOR);}

	/**
	 * allows the implementation to release the resources allocated by the OpenCL compiler for
	 * platform. This is a hint from the application and does not guarantee that the compiler will not be
	 * used in the future or that the compiler will actually be unloaded by the implementation. Calls to
	 * clBuildProgram, clCompileProgram or clLinkProgram after clUnloadPlatformCompiler
	 * will reload the compiler, if necessary, to build the appropriate program executable
	 */
	void unloadCompiler()
	{
		if(DerelictCL.loadedVersion < CLVersion.CL12)
			throw new CLVersionException();

		clUnloadPlatformCompiler(_object);
	}
}
