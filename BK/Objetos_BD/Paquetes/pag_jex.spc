create or replace package it.PAG_JEX as
  /*
  Copyright (c) 2009 Jonas Krogsboell

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  */

  /* This package contains extra methods to lookup types and
     an easy way of adding date values in typ_json - without changing the structure */
  function parsePath(json_path varchar2, base number default 1)  RETURN typ_jsonlist ;

  --typ_json Path getters
  function get_typ_jsonvalue(obj typ_json, v_path varchar2, base number default 1) return typ_jsonvalue;
  function get_string(obj typ_json, path varchar2,       base number default 1) return varchar2;
  function get_number(obj typ_json, path varchar2,       base number default 1) return number;
  function get_typ_json(obj typ_json, path varchar2,         base number default 1) return typ_json;
  function get_json_list(obj typ_json, path varchar2,    base number default 1)  RETURN typ_jsonlist ;
  function get_bool(obj typ_json, path varchar2,         base number default 1) return boolean;

  --typ_json Path putters
  procedure put(obj in out nocopy typ_json, path varchar2, elem varchar2,   base number default 1);
  procedure put(obj in out nocopy typ_json, path varchar2, elem number,     base number default 1);
  procedure put(obj in out nocopy typ_json, path varchar2, elem typ_json,       base number default 1);
  procedure put(obj in out nocopy typ_json, path varchar2, elem typ_jsonlist,  base number default 1);
  procedure put(obj in out nocopy typ_json, path varchar2, elem boolean,    base number default 1);
  procedure put(obj in out nocopy typ_json, path varchar2, elem typ_jsonvalue, base number default 1);

  procedure remove(obj in out nocopy typ_json, path varchar2, base number default 1);

  --Pretty print with typ_json Path - obsolete in 0.9.4 - obj.path(v_path).(to_char,print,htp)
  function pp(obj typ_json, v_path varchar2) return varchar2;
  procedure pp(obj typ_json, v_path varchar2); --using dbms_output.put_line
  procedure pp_htp(obj typ_json, v_path varchar2); --using htp.print

  --extra function checks if number has no fraction
  function is_integer(v typ_jsonvalue) return boolean;

  format_string varchar2(30 char) := 'yyyy-mm-dd hh24:mi:ss';
  --extension enables typ_json to store dates without comprimising the implementation
  function to_typ_jsonvalue(d date) return typ_jsonvalue;
  --notice that a date type in typ_json is also a varchar2
  function is_date(v typ_jsonvalue) return boolean;
  --convertion is needed to extract dates
  --(PAG_JEX.to_date will not work along with the normal to_date function - any fix will be appreciated)
  function to_date2(v typ_jsonvalue) return date;
  --typ_json Path with date
  function get_date(obj typ_json, path varchar2, base number default 1) return date;
  procedure put(obj in out nocopy typ_json, path varchar2, elem date, base number default 1);

  --experimental support of binary data with base64
  function base64(binarydata blob)  RETURN typ_jsonlist ;
  function base64(l typ_jsonlist) return blob;

  function encode(binarydata blob) return typ_jsonvalue;
  function decode(v typ_jsonvalue) return blob;

end PAG_JEX;
/

