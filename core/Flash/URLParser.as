/******************************************************************************
* @file: URLParser.as
* @date: 11-09-2012
* @lastmodified: Tue 25 Sep 2012 03:05:35 PM WEST
*
* @author: dfbento <danielbento@overdestiny.com>
*
* @description: Parse URL
*
******************************************************************************/

package {
    
    internal class URLParser {

        public function URLParser() {
        }

        public static function parse(_url: String): Object {
            var url:String = _url, 
                protocol: String = "",  
                host: String = "", 
                port: String = "", 
                path: String = "", 
                parameters: Object = "";

            var reg:RegExp = /(?P<protocol>[a-zA-Z]+) : \/\/  (?P<host>[^:\/]*) (:(?P<port>\d+))?  ((?P<path>[^?]*))? ((?P<parameters>.*))? /x;
            var results: Array = reg.exec(url);
            var res: Object = new Object();
            
            protocol = results.protocol;
            host = results.host;
            port = results.port;
            path = results.path;

            var param: String = results.parameters;

            if (param != "") {
                parameters = new Object();

                if (param.charAt(0) == "?") {
                    param = param.substring(1);
                }

                var params:Array = param.split("&");

                for each(var prm: String in params) {
                    var tuple: Array = prm.split("=");
                    parameters[tuple[0]] = tuple[1];
                }
            }
            res["url"] = url;
            res["protocol"] = protocol;
            res["host"] = host;
            res["port"] = port;
            res["path"] = path;
            res["parameters"] = parameters;

            return res;
        }
    }
}
