create or replace package it.PAG_JDY authid current_user as
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

  null_as_empty_string   boolean not null := true;  --varchar2
  include_dates          boolean not null := true;  --date
  include_clobs          boolean not null := true;
  include_blobs          boolean not null := false;

  /* list with objects */
  function executeList(stmt varchar2, bindvar typ_json default null, cur_num number default null)  RETURN typ_jsonlist ;

  /* object with lists */
  function executeObject(stmt varchar2, bindvar typ_json default null, cur_num number default null) return typ_json;


  /* usage example:
   * declare
   *   restyp_jsonlist;
   * begin
   *   res := PAG_JDY.executeList(
   *            'select :bindme as one, :lala as two from dual where dummy in :arraybind',
   *            typ_json('{bindme:"4", lala:123, arraybind:[1,2,3,"X"]}')
   *          );
   *   res.print;
   * end;
   */

/* --11g functions
  function executeList(stmt in out sys_refcursor)  RETURN typ_jsonlist ;
  function executeObject(stmt in out sys_refcursor) return typ_json;
*/
end PAG_JDY;
/

