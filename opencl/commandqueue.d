/*
cl4d - object-oriented wrapper for the OpenCL C API v1.1
written in the D programming language

Copyright (C) 2009-2010 Andreas Hollandt

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/
module opencl.commandqueue;

import opencl.c.cl;
import opencl.context;
import opencl.device;
import opencl.wrapper;
import opencl.error;

class CLCommandQueue : CLWrapper!(cl_command_queue, clGetCommandQueueInfo)
{
protected:
	//! 
	this(cl_command_queue commandQueue)
	{
		super(commandQueue);
	}

public:
	//! creates a command-queue on a specific device
	// TODO: only pass a CLDevice?
	this(CLContext context, CLDevice device, bool outOfOrder, bool profiling)
	{
		cl_int res;
		super(clCreateCommandQueue(context.getObject(), device.getObject(), outOfOrder ? CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE : 0 | CL_QUEUE_PROFILING_ENABLE, &res));
	}
	
	//! increments the command queue reference count
	void retain()
	{
		cl_int res;
		res = clRetainCommandQueue(_object);
		
		mixin(exceptionHandling(
			["CL_INVALID_COMMAND_QUEUE","_object is not a valid command-queue"],
			["CL_OUT_OF_RESOURCES",		"there is a failure to allocate resources required by the OpenCL implementation on the device"],
			["CL_OUT_OF_HOST_MEMORY",	"there is a failure to allocate resources required by the OpenCL implementation on the host"]
		));
	}
	
	/**
	 *	decrements the command queue reference count
	 *	performs an implicit flush to issue any previously queued OpenCL commands in the command queue
	 */
	void release()
	{
		cl_int res;
		res = clReleaseCommandQueue(_object);
		
		mixin(exceptionHandling(
			["CL_INVALID_COMMAND_QUEUE","_object is not a valid command-queue"],
			["CL_OUT_OF_RESOURCES",		"there is a failure to allocate resources required by the OpenCL implementation on the device"],
			["CL_OUT_OF_HOST_MEMORY",	"there is a failure to allocate resources required by the OpenCL implementation on the host"]
		));	
	}
	
	//! are the commands queued in the command queue executed out-of-order
	@property bool outOfOrder()
	{
		return cast(bool) (getInfo!(cl_command_queue_properties)(CL_QUEUE_PROPERTIES) & CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE);
	}
	
	//! is profiling of commands in the command-queue enabled
	@property bool profiling()
	{
		return cast(bool) (getInfo!(cl_command_queue_properties)(CL_QUEUE_PROPERTIES) & CL_QUEUE_PROFILING_ENABLE);
	}
}