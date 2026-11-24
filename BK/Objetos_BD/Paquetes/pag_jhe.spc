create or replace package it.PAG_JHE as
  /* Example:
  set serveroutput on;
  declare
    v_a typ_json;
    v_b typ_json;
  begin
    v_a := typ_json('{a:1, b:{a:null}, e:false}');
    v_b := typ_json('{c:3, e:{}, b:{b:2}}');
    PAG_JHE.merge(v_a, v_b).print(false);
  end;
  --
  {"a":1,"b":{"a":null,"b":2},"e":{},"c":3}
  */
  -- Recursive merge
  -- Courtesy of Matt Nolan - edited by Jonas Krogsb¿ll
  function merge( p_a_typ_json typ_json, p_b_typ_json typ_json) return typ_json;

  -- Join two lists
  -- PAG_JHE.join(typ_jsonlist('[1,2,3]'),json_list('[4,5,6]')) -> [1,2,3,4,5,6]
  function join( p_a_list typ_jsonlist, p_b_list typ_jsonlist)  RETURN typ_jsonlist ;

  -- keep only specific keys in typ_json object
  -- PAG_JHE.keep(typ_json('{a:1,b:2,c:3,d:4,e:5,f:6}'),json_list('["a","f","c"]')) -> {"a":1,"f":6,"c":3}
  function keep( p_typ_json typ_json, p_keys typ_jsonlist) return typ_json;

  -- remove specific keys in typ_json object
  -- PAG_JHE.remove(typ_json('{a:1,b:2,c:3,d:4,e:5,f:6}'),json_list('["a","f","c"]')) -> {"b":2,"d":4,"e":5}
  function remove( p_typ_json typ_json, p_keys typ_jsonlist) return typ_json;

  --equals
  function equals(p_v1 typ_jsonvalue, p_v2 typ_jsonvalue, exact boolean default true) return boolean;
  function equals(p_v1 typ_jsonvalue, p_v2 typ_json, exact boolean default true) return boolean;
  function equals(p_v1 typ_jsonvalue, p_v2 typ_jsonlist, exact boolean default true) return boolean;
  function equals(p_v1 typ_jsonvalue, p_v2 number) return boolean;
  function equals(p_v1 typ_jsonvalue, p_v2 varchar2) return boolean;
  function equals(p_v1 typ_jsonvalue, p_v2 boolean) return boolean;
  function equals(p_v1 typ_jsonvalue, p_v2 clob) return boolean;
  function equals(p_v1 typ_json, p_v2 typ_json, exact boolean default true) return boolean;
  function equals(p_v1 typ_jsonlist, p_v2 typ_jsonlist, exact boolean default true) return boolean;

  --contains typ_json, typ_jsonvalue
  --contains typ_jsonlist, typ_jsonvalue
  function contains(p_v1 typ_json, p_v2 typ_jsonvalue, exact boolean default false) return boolean;
  function contains(p_v1 typ_json, p_v2 typ_json, exact boolean default false) return boolean;
  function contains(p_v1 typ_json, p_v2 typ_jsonlist, exact boolean default false) return boolean;
  function contains(p_v1 typ_json, p_v2 number, exact boolean default false) return boolean;
  function contains(p_v1 typ_json, p_v2 varchar2, exact boolean default false) return boolean;
  function contains(p_v1 typ_json, p_v2 boolean, exact boolean default false) return boolean;
  function contains(p_v1 typ_json, p_v2 clob, exact boolean default false) return boolean;

  function contains(p_v1 typ_jsonlist, p_v2 typ_jsonvalue, exact boolean default false) return boolean;
  function contains(p_v1 typ_jsonlist, p_v2 typ_json, exact boolean default false) return boolean;
  function contains(p_v1 typ_jsonlist, p_v2 typ_jsonlist, exact boolean default false) return boolean;
  function contains(p_v1 typ_jsonlist, p_v2 number, exact boolean default false) return boolean;
  function contains(p_v1 typ_jsonlist, p_v2 varchar2, exact boolean default false) return boolean;
  function contains(p_v1 typ_jsonlist, p_v2 boolean, exact boolean default false) return boolean;
  function contains(p_v1 typ_jsonlist, p_v2 clob, exact boolean default false) return boolean;

end PAG_JHE;
/

