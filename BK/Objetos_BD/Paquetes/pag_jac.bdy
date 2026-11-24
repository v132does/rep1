create or replace package body it.PAG_JAC as
  procedure object_remove(p_self in out nocopy typ_json, pair_name varchar2) as
  begin p_self.remove(pair_name); end;
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value typ_jsonvalue, position pls_integer default null) as
  begin p_self.put(pair_name, pair_value, position); end;
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value varchar2, position pls_integer default null) as
  begin p_self.put(pair_name, pair_value, position); end;
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value number, position pls_integer default null) as
  begin p_self.put(pair_name, pair_value, position); end;
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value boolean, position pls_integer default null) as
  begin p_self.put(pair_name, pair_value, position); end;
  procedure object_check_duplicate(p_self in out nocopy typ_json, v_set boolean) as
  begin p_self.check_duplicate(v_set); end;
  procedure object_remove_duplicates(p_self in out nocopy typ_json) as
  begin p_self.remove_duplicates; end;

  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value typ_json, position pls_integer default null) as
  begin p_self.put(pair_name, pair_value, position); end;
  procedure object_put(p_self in out nocopy typ_json, pair_name varchar2, pair_value typ_jsonlist, position pls_integer default null) as
  begin p_self.put(pair_name, pair_value, position); end;

  function object_count(p_self in typ_json) return number as
  begin return p_self.count; end;
  function object_get(p_self in typ_json, pair_name varchar2) return typ_jsonvalue as
  begin return p_self.get(pair_name); end;
  function object_get(p_self in typ_json, position pls_integer) return typ_jsonvalue as
  begin return p_self.get(position); end;
  function object_index_of(p_self in typ_json, pair_name varchar2) return number as
  begin return p_self.index_of(pair_name); end;
  function object_exist(p_self in typ_json, pair_name varchar2) return boolean as
  begin return p_self.exist(pair_name); end;

  function object_to_char(p_self in typ_json, spaces boolean default true, chars_per_line number default 0) return varchar2 as
  begin return p_self.to_char(spaces, chars_per_line); end;
  procedure object_to_clob(p_self in typ_json, buf in out nocopy clob, spaces boolean default false, chars_per_line number default 0, erase_clob boolean default true) as
  begin p_self.to_clob(buf, spaces, chars_per_line, erase_clob); end;
  procedure object_print(p_self in typ_json, spaces boolean default true, chars_per_line number default 8192, jsonp varchar2 default null) as
  begin p_self.print(spaces, chars_per_line, jsonp); end;
  procedure object_htp(p_self in typ_json, spaces boolean default false, chars_per_line number default 0, jsonp varchar2 default null) as
  begin p_self.htp(spaces, chars_per_line, jsonp); end;

  function object_to_typ_jsonvalue(p_self in typ_json) return typ_jsonvalue as
  begin return p_self.to_typ_jsonvalue; end;
  function object_path(p_self in typ_json, json_path varchar2, base number default 1) return typ_jsonvalue as
  begin return p_self.path(json_path, base); end;

  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem typ_jsonvalue, base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem varchar2  , base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem number    , base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem boolean   , base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem typ_jsonlist , base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;
  procedure object_path_put(p_self in out nocopy typ_json, json_path varchar2, elem typ_json      , base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;

  procedure object_path_remove(p_self in out nocopy typ_json, json_path varchar2, base number default 1) as
  begin p_self.path_remove(json_path, base); end;

  function object_get_values(p_self in typ_json) return typ_jsonlist as
  begin return p_self.get_values; end;
  function object_get_keys(p_self in typ_json) return typ_jsonlist as
  begin return p_self.get_keys; end;

  --typ_jsonlist type
  procedure array_append(p_self in out nocopy typ_jsonlist, elem typ_jsonvalue, position pls_integer default null) as
  begin p_self.append(elem, position); end;
  procedure array_append(p_self in out nocopy typ_jsonlist, elem varchar2, position pls_integer default null) as
  begin p_self.append(elem, position); end;
  procedure array_append(p_self in out nocopy typ_jsonlist, elem number, position pls_integer default null) as
  begin p_self.append(elem, position); end;
  procedure array_append(p_self in out nocopy typ_jsonlist, elem boolean, position pls_integer default null) as
  begin p_self.append(elem, position); end;
  procedure array_append(p_self in out nocopy typ_jsonlist, elem typ_jsonlist, position pls_integer default null) as
  begin p_self.append(elem, position); end;

  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer, elem typ_jsonvalue) as
  begin p_self.replace(position, elem); end;
  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer, elem varchar2) as
  begin p_self.replace(position, elem); end;
  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer, elem number) as
  begin p_self.replace(position, elem); end;
  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer, elem boolean) as
  begin p_self.replace(position, elem); end;
  procedure array_replace(p_self in out nocopy typ_jsonlist, position pls_integer,  elem typ_jsonlist ) as
  begin p_self.replace(position, elem); end;

  function array_count(p_self in typ_jsonlist) return number as
  begin return p_self.count; end;
  procedure array_remove(p_self in out nocopy typ_jsonlist, position pls_integer) as
  begin p_self.remove(position); end;
  procedure array_remove_first(p_self in out  NOCOPY typ_jsonlist ) as
  begin p_self.remove_first; end;
  procedure array_remove_last(p_self in out  NOCOPY typ_jsonlist ) as
  begin p_self.remove_last; end;
  function array_get(p_self in typ_jsonlist, position pls_integer) return typ_jsonvalue as
  begin return p_self.get(position); end;
  function array_head(p_self in typ_jsonlist) return typ_jsonvalue as
  begin return p_self.head; end;
  function array_last(p_self in typ_jsonlist) return typ_jsonvalue as
  begin return p_self.last; end;
  function array_tail(p_self in typ_jsonlist) return typ_jsonlist as
  begin return p_self.tail; end;

  function array_to_char(p_self in typ_jsonlist, spaces boolean default true, chars_per_line number default 0) return varchar2 as
  begin return p_self.to_char(spaces, chars_per_line); end;
  procedure array_to_clob(p_self in typ_jsonlist, buf in out nocopy clob, spaces boolean default false, chars_per_line number default 0, erase_clob boolean default true) as
  begin p_self.to_clob(buf, spaces, chars_per_line, erase_clob); end;
  procedure array_print(p_self in typ_jsonlist, spaces boolean default true, chars_per_line number default 8192, jsonp varchar2 default null) as
  begin p_self.print(spaces, chars_per_line, jsonp); end;
  procedure array_htp(p_self in typ_jsonlist, spaces boolean default false, chars_per_line number default 0, jsonp varchar2 default null) as
  begin p_self.htp(spaces, chars_per_line, jsonp); end;

  function array_path(p_self in typ_jsonlist, json_path varchar2, base number default 1) return typ_jsonvalue as
  begin return p_self.path(json_path, base); end;
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem typ_jsonvalue, base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem varchar2  , base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem number    , base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem boolean   , base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;
  procedure array_path_put(p_self in out nocopy typ_jsonlist, json_path varchar2, elem typ_jsonlist , base number default 1) as
  begin p_self.path_put(json_path, elem, base); end;

  procedure array_path_remove(p_self in out nocopy typ_jsonlist, json_path varchar2, base number default 1) as
  begin p_self.path_remove(json_path, base); end;

  function array_to_typ_jsonvalue(p_self in typ_jsonlist) return typ_jsonvalue as
  begin return p_self.to_typ_jsonvalue; end;

  --typ_jsonvalue


  function jv_get_type(p_self in typ_jsonvalue) return varchar2 as
  begin return p_self.get_type; end;
  function jv_get_string(p_self in typ_jsonvalue, max_byte_size number default null, max_char_size number default null) return varchar2 as
  begin return p_self.get_string(max_byte_size, max_char_size); end;
  procedure jv_get_string(p_self in typ_jsonvalue, buf in out nocopy clob) as
  begin p_self.get_string(buf); end;
  function jv_get_number(p_self in typ_jsonvalue) return number as
  begin return p_self.get_number; end;
  function jv_get_bool(p_self in typ_jsonvalue) return boolean as
  begin return p_self.get_bool; end;
  function jv_get_null(p_self in typ_jsonvalue) return varchar2 as
  begin return p_self.get_null; end;

  function jv_is_object(p_self in typ_jsonvalue) return boolean as
  begin return p_self.is_object; end;
  function jv_is_array(p_self in typ_jsonvalue) return boolean as
  begin return p_self.is_array; end;
  function jv_is_string(p_self in typ_jsonvalue) return boolean as
  begin return p_self.is_string; end;
  function jv_is_number(p_self in typ_jsonvalue) return boolean as
  begin return p_self.is_number; end;
  function jv_is_bool(p_self in typ_jsonvalue) return boolean as
  begin return p_self.is_bool; end;
  function jv_is_null(p_self in typ_jsonvalue) return boolean as
  begin return p_self.is_null; end;

  function jv_to_char(p_self in typ_jsonvalue, spaces boolean default true, chars_per_line number default 0) return varchar2 as
  begin return p_self.to_char(spaces, chars_per_line); end;
  procedure jv_to_clob(p_self in typ_jsonvalue, buf in out nocopy clob, spaces boolean default false, chars_per_line number default 0, erase_clob boolean default true) as
  begin p_self.to_clob(buf, spaces, chars_per_line, erase_clob); end;
  procedure jv_print(p_self in typ_jsonvalue, spaces boolean default true, chars_per_line number default 8192, jsonp varchar2 default null) as
  begin p_self.print(spaces, chars_per_line, jsonp); end;
  procedure jv_htp(p_self in typ_jsonvalue, spaces boolean default false, chars_per_line number default 0, jsonp varchar2 default null) as
  begin p_self.htp(spaces, chars_per_line, jsonp); end;

  function jv_value_of(p_self in typ_jsonvalue, max_byte_size number default null, max_char_size number default null) return varchar2 as
  begin return p_self.value_of(max_byte_size, max_char_size); end;

end PAG_JAC;
/

