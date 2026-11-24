create or replace package it.PAG_JUT authid current_user as

  /*

  Purpose:    typ_json utilities for PL/SQL
  see http://ora-00001.blogspot.com/

  Remarks:

  Who     Date        Description
  ------  ----------  -------------------------------------
  MBR     30.01.2010  Created
  JKR     01.05.2010  Edited to fit in PL/JSON
  JKR     19.01.2011  Newest stylesheet + bugfix handling

  */

  -- generate typ_json from REF Cursor
  function ref_cursor_to_typ_json (p_ref_cursor in sys_refcursor,
                               p_max_rows in number := null,
                               p_skip_rows in number := null)  RETURN typ_jsonlist ;

  -- generate typ_json from SQL statement
  function sql_to_typ_json (p_sql in varchar2,
                        p_max_rows in number := null,
                        p_skip_rows in number := null)  RETURN typ_jsonlist ;


end PAG_JUT;
/

