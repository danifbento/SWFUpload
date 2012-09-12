/******************************************************************************
*
*  Copyright 2012 sapo.pt  All Rights Reserved
*
*******************************************************************************
* @file: URLParser.as
* @date: 11-09-2012
* @lastmodified: Tue 11 Sep 2012 10:50:33 AM WEST
*
* @author: dfbento <danielbento@overdestiny.com>
*
* @description: Parse URL
*
******************************************************************************/

package {
    
    internal class URLParser {

        private static var url: String;
        
        private static var protocol: String = "";
        private static var host: String = "";
        private static var port: String = "";
        private static var path: String = "";
        private static var parameters: Object;
        public function URLParser() {
        }

        public static function parse(url: String): Object {
            URLParser.url = url;

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

            res["protocol"] = protocol;
            res["host"] = host;
            res["port"] = port;
            res["path"] = path;
            res["parameters"] = parameters;

            return res;
        }
    }
}
