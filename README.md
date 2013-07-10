SWFUpload
=========

SWFUpload - Fork from SWFUpload Build 2.2.1

Original Project at: http://code.google.com/p/swfupload/

LICENCE
-------

Copyright (C) 2006-2007 Lars Huring, Olov Nilzén and Mammon Media

Copyright (C) 2007-2008 Jake Roberts

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

INTRODUCTION
------------

SWFUpload is a JavaScript Library that wraps the Flash Player's upload function. It brings your uploads to the next level with Multiple File Selection, Upload Progress and Client-side File Size Checking.

Unlike other Flash upload tools, SWFUpload leaves the UI in the developer's hands. Using a set of event handlers developers can display upload progress and status to the user in their own HTML/CSS UI.

SWFUpload has been featured in such projects as YouTube and WordPress.

USE
---

This version of SWFUpload has some new cool features you can use on your own like Multipart Upload and Socket Upload. With this two new modes you can pass custom headers to the request and upload using chunks.

For Multipart:
<pre>
	var settings = {
		use_multipart : true
	}
</pre>

For Socket (this mode override the multipart method):
<pre>
	var settings = {
		use_socket : true
	}
</pre>

If you want to use chunks with multipart, you can set (the rules for size are the same as File Size Limit):
<pre>
	var settings = {
		use_chunk : true,
		chunk_size : "200 kb"
	}
</pre>

NOTE: Attention, the size of the chunk also refers to the packet size on socket write before flushing the memory.

Finally, for custom headers you can use the structure: 
<pre>
	var settings = {
		headers: { "HeaderName1": 'value', 
				   "HeaderName2": 'value',
				   "HeaderName3": {'param1': 'value', 'param2': 'value'}
				 }
	}
</pre>

Headers like Host, Referer, Origin, Content-Type, Content-Length, Content-Disposition, User-Agent are ignored.

Fixed Vulnerabilities
---------------------

 * CVE-2013-2205, in [c6165608855eeab00f8fea92606ed5be418124a4](https://github.com/wordpress/secure-swfupload/commit/c6165608855eeab00f8fea92606ed5be418124a4). Reported to WordPress by [Szymon Gruszecki](http://mars.iti.pk.edu.pl/~grucha/).
 * CVE-2012-3414, in [1127712c89f33a1324591de07a27fa2eb205673b](https://github.com/wordpress/secure-swfupload/commit/1127712c89f33a1324591de07a27fa2eb205673b). Reported to WordPress by [Neal Poole](http://nealpoole.com) and [Nathan Partlan](http://greywhind.wordpress.com).
 * CVE-2012-2399, in [f6e5097c32d4680fe66ed04c91926959ed763d52](https://github.com/wordpress/secure-swfupload/commit/f6e5097c32d4680fe66ed04c91926959ed763d52). Reported to WordPress by [Szymon Gruszecki](http://mars.iti.pk.edu.pl/~grucha/).

Acknowledgements
----------------

Thanks to WordPress Team by the security-swfupload
