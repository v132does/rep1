create or replace package it.PAG_JAC as
  --typ_json type methods

  procedure object_remove(p_self in out nocopy typ_json, pair_name varchar2);
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value typ_jsonvalue, position pls_integer default null);
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value varchar2, position pls_integer default null);
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value number, position pls_integer default null);
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value boolean, position pls_integer default null);
  procedure object_check_duplicate(p_self in out nocopy typ_json, v_set boolean);
  procedure object_remove_duplicates(p_self in out nocopy typ_json);

  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value typ_json, position pls_integer default null);
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value typ_jsonlist, position pls_integer default null);

  function object_count(p_self in typ_json) return number;
  function object_get(p_self in typ_json, pair_name varchar2) return typ_jsonvalue;
  function object_get(p_self in typ_json, position pls_integer) return typ_jsonvalue;
  function object_index_of(p_self in typ_json, pair_name varchar2) return number;
  function object_exist(p_self in typ_json, pair_name varchar2) return boolean;

  function object_to_char(p_self in typ_json, spaces boolean default true, chars_per_line number default 0) return varchar2;
  procedure object_to_clob(p_self in typ_json, buf in out nocopy clob, spaces boolean default false, chars_per_line number default 0, erase_clob boolean default true);
  procedure object_print(p_self in typ_json, spaces boolean default true, chars_per_line number default 8192, jsonp varchar2 default null);
  procedure object_htp(p_self in typ_json, spaces boolean default false, chars_per_line number default 0, jsonp varchar2 default null);

  function object_to_typ_jsonvalue(p_self in typ_json) return typ_jsonvalue;
  function object_path(p_self in typ_json, json_path varchar2, base number default 1) return typ_jsonvalue;

  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem typ_jsonvalue, base number default 1);
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem varchar2  , base number default 1);
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem number    , base number default 1);
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem boolean   , base number default 1);
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem typ_jsonlist , base number default 1);
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem typ_json      , base number default 1);

  procedure object_path_remove(p_self in out nocopy typ_json, json_path varchar2, base number default 1);

  function object_get_values(p_self in typ_json)  RETURN typ_jsonlist ;
  function object_get_keys(p_self in typ_json)  RETURN typ_jsonlist ;

  --typ_jsonlist type methods
  procedure array_append(p_self in out nocopy typ_jsonlist, elem typ_jsonvalue, position pls_integer default null);
  procedure array_append(p_self in out nocopy typ_jsonlist, elem varchar2, position pls_integer default null);
  procedure array_append(p_self in out nocopy typ_jsonlist, elem number, position pls_integer default null);
  procedure array_append(p_self in out nocopy typ_jsonlist, elem boolean, position pls_integer default null);
  procedure array_append(p_self in out nocopy typ_jsonlist, elem typ_jsonlist, position pls_integer default null);

  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer, elem typ_jsonvalue);
  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer, elem varchar2);
  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer, elem number);
  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer, elem boolean);
  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer,  elem typ_jsonlist );

  function array_count(p_self in typ_jsonlist) return number;
  procedure array_remove(p_self in out nocopy typ_jsonlist, position pls_integer);
  procedure array_remove_first(p_self in out  NOCOPY typ_jsonlist );
  procedure array_remove_last(p_self in out  NOCOPY typ_jsonlist );
  function array_get(p_self in typ_jsonlist, position pls_integer) return typ_jsonvalue;
  function array_head(p_self in typ_jsonlist) return typ_jsonvalue;
  function array_last(p_self in typ_jsonlist) return typ_jsonvalue;
  function array_tail(p_self in typ_jsonlist)  RETURN typ_jsonlist ;

  function array_to_char(p_self in typ_jsonlist, spaces boolean default true, chars_per_line number default 0) return varchar2;
  procedure array_to_clob(p_self in typ_jsonlist, buf in out nocopy clob, spaces boolean default false, chars_per_line number default 0, erase_clob boolean default true);
  procedure array_print(p_self in typ_jsonlist, spaces boolean default true, chars_per_line number default 8192, jsonp varchar2 default null);
  procedure array_htp(p_self in typ_jsonlist, spaces boolean default false, chars_per_line number default 0, jsonp varchar2 default null);

  function array_path(p_self in typ_jsonlist, json_path varchar2, base number default 1) return typ_jsonvalue;
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem typ_jsonvalue, base number default 1);
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem varchar2  , base number default 1);
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem number    , base number default 1);
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem boolean   , base number default 1);
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem typ_jsonlist , base number default 1);

  procedure array_path_remove(p_self in out nocopy typ_jsonlist, json_path varchar2, base number default 1);

  function array_to_typ_jsonvalue(p_self in typ_jsonlist) return typ_jsonvalue;

  --typ_jsonvalue


  function jv_get_type(p_self in typ_jsonvalue) return varchar2;
  function jv_get_string(p_self in typ_jsonvalue, max_byte_size number default null, max_char_size number default null) return varchar2;
  procedure jv_get_string(p_self in typ_jsonvalue, buf in out nocopy clob);
  function jv_get_number(p_self in typ_jsonvalue) return number;
  function jv_get_bool(p_self in typ_jsonvalue) return boolean;
  function jv_get_null(p_self in typ_jsonvalue) return varchar2;

  function jv_is_object(p_self in typ_jsonvalue) return boolean;
  function jv_is_array(p_self in typ_jsonvalue) return boolean;
  function jv_is_string(p_self in typ_jsonvalue) return boolean;
  function jv_is_number(p_self in typ_jsonvalue) return boolean;
  function jv_is_bool(p_self in typ_jsonvalue) return boolean;
  function jv_is_null(p_self in typ_jsonvalue) return boolean;

  function jv_to_char(p_self in typ_jsonvalue, spaces boolean default true, chars_per_line number default 0) return varchar2;
  procedure jv_to_clob(p_self in typ_jsonvalue, buf in out nocopy clob, spaces boolean default false, chars_per_line number default 0, erase_clob boolean default true);
  procedure jv_print(p_self in typ_jsonvalue, spaces boolean default true, chars_per_line number default 8192, jsonp varchar2 default null);
  procedure jv_htp(p_self in typ_jsonvalue, spaces boolean default false, chars_per_line number default 0, jsonp varchar2 default null);

  function jv_value_of(p_self in typ_jsonvalue, max_byte_size number default null, max_char_size number default null) return varchar2;


end PAG_JAC;
/

