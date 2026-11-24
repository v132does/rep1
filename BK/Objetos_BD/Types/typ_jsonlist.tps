CREATE OR REPLACE TYPE IT."TYP_JSONLIST"                                          as object (
  /*
  Copyright (c) 2010 Jonas Krogsboell

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

  list_data typ_jsonvaluearray,
  constructor  function typ_jsonlist  return self as result,
  constructor  function typ_jsonlist (str varchar2) return self as result,
  constructor  function typ_jsonlist (str clob) return self as result,
  constructor  function typ_jsonlist (cast typ_jsonvalue) return self as result,
  
  member procedure append(self in out nocopy typ_jsonlist, elem typ_jsonvalue, position pls_integer default null),
  member procedure append(self in out nocopy typ_jsonlist, elem varchar2, position pls_integer default null),
  member procedure append(self in out nocopy typ_jsonlist, elem number, position pls_integer default null),
  member procedure append(self in out nocopy typ_jsonlist, elem boolean, position pls_integer default null),
  member procedure append(self in out nocopy typ_jsonlist, elem typ_jsonlist, position pls_integer default null),

  member procedure replace(self in out nocopy typ_jsonlist, position pls_integer, elem typ_jsonvalue),
  member procedure replace(self in out nocopy typ_jsonlist, position pls_integer, elem varchar2),
  member procedure replace(self in out nocopy typ_jsonlist, position pls_integer, elem number),
  member procedure replace(self in out nocopy typ_jsonlist, position pls_integer, elem boolean),
  member procedure replace(self in out nocopy typ_jsonlist, position pls_integer,  elem typ_jsonlist ),

  member function count return number,
  member procedure remove(self in out nocopy typ_jsonlist, position pls_integer),
  member procedure remove_first(self in out  NOCOPY typ_jsonlist ),
  member procedure remove_last(self in out  NOCOPY typ_jsonlist ),
  member function get(position pls_integer) return typ_jsonvalue,
  member function head return typ_jsonvalue,
  member function last return typ_jsonvalue,
  member function tail return typ_jsonlist,

  /* Output methods */ 
  member function to_char(spaces boolean default true, chars_per_line number default 0) return varchar2,
  member procedure to_clob(self in typ_jsonlist, buf in out nocopy clob, spaces boolean default false, chars_per_line number default 0, erase_clob boolean default true),
  member procedure print(self in typ_jsonlist, spaces boolean default true, chars_per_line number default 8192, jsonp varchar2 default null), --32512 is maximum
  member procedure htp(self in typ_jsonlist, spaces boolean default false, chars_per_line number default 0, jsonp varchar2 default null),

  /* typ_json path */
  member function path(json_path varchar2, base number default 1) return typ_jsonvalue,
  /* typ_json path_put */
  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem typ_jsonvalue, base number default 1),
  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem varchar2  , base number default 1),
  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem number    , base number default 1),
  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem boolean   , base number default 1),
  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem typ_jsonlist , base number default 1),

  /* typ_json path_remove */
  member procedure path_remove(self in out nocopy typ_jsonlist, json_path varchar2, base number default 1),

  member function to_typ_jsonvalue return typ_jsonvalue
  /* --backwards compatibility
  ,
  member procedure add_elem(self in out nocopy typ_jsonlist, elem typ_jsonvalue, position pls_integer default null),
  member procedure add_elem(self in out nocopy typ_jsonlist, elem varchar2, position pls_integer default null),
  member procedure add_elem(self in out nocopy typ_jsonlist, elem number, position pls_integer default null),
  member procedure add_elem(self in out nocopy typ_jsonlist, elem boolean, position pls_integer default null),
  member procedure add_elem(self in out nocopy typ_jsonlist, elem typ_jsonlist, position pls_integer default null),

  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer, elem typ_jsonvalue),
  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer, elem varchar2),
  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer, elem number),
  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer, elem boolean),
  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer,  elem typ_jsonlist ),
  
  member procedure remove_elem(self in out nocopy typ_jsonlist, position pls_integer),
  member function get_elem(position pls_integer) return typ_jsonvalue,
  member function get_first return typ_jsonvalue,
  member function get_last return typ_jsonvalue
--  */
  
) not final;
/

