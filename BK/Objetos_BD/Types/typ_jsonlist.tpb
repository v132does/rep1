CREATE OR REPLACE TYPE BODY IT."TYP_JSONLIST" as

  constructor  function typ_jsonlist  return self as result as
  begin
    self.list_data := typ_jsonvaluearray();
    return;
  end;

  constructor  function typ_jsonlist (str varchar2) return self as result as
  begin
    self := PAG_JPR.parse_list(str);
    return;
  end;
  
  constructor  function typ_jsonlist (str clob) return self as result as
  begin
    self := PAG_JPR.parse_list(str);
    return;
  end;

  constructor  function typ_jsonlist (cast typ_jsonvalue) return self as result as
    x number;
  begin
    x := cast.object_or_array.getobject(self);
    return;
  end;


  member procedure append(self in out nocopy typ_jsonlist, elem typ_jsonvalue, position pls_integer default null) as
    indx pls_integer;
    insert_value typ_jsonvalue := NVL(elem, typ_jsonvalue);
  begin
    if(position is null or position > self.count) then --end of list
      indx := self.count + 1;
      self.list_data.extend(1);
      self.list_data(indx) := insert_value;
    elsif(position < 1) then --new first
      indx := self.count;
      self.list_data.extend(1);
      for x in reverse 1 .. indx loop
        self.list_data(x+1) := self.list_data(x);
      end loop;
      self.list_data(1) := insert_value;
    else
      indx := self.count;
      self.list_data.extend(1);
      for x in reverse position .. indx loop
        self.list_data(x+1) := self.list_data(x);
      end loop;
      self.list_data(position) := insert_value;
    end if;

  end;

  member procedure append(self in out nocopy typ_jsonlist, elem varchar2, position pls_integer default null) as
  begin
    append(typ_jsonvalue(elem), position);
  end;
  
  member procedure append(self in out nocopy typ_jsonlist, elem number, position pls_integer default null) as
  begin
    if(elem is null) then
      append(typ_jsonvalue(), position);
    else
      append(typ_jsonvalue(elem), position);
    end if;
  end;
  
  member procedure append(self in out nocopy typ_jsonlist, elem boolean, position pls_integer default null) as
  begin
    if(elem is null) then
      append(typ_jsonvalue(), position);
    else
      append(typ_jsonvalue(elem), position);
    end if;
  end;

  member procedure append(self in out nocopy typ_jsonlist, elem typ_jsonlist, position pls_integer default null) as
  begin
    if(elem is null) then
      append(typ_jsonvalue(), position);
    else
      append(elem.to_typ_jsonvalue, position);
    end if;
  end;
  
 member procedure replace(self in out nocopy typ_jsonlist, position pls_integer, elem typ_jsonvalue) as
    insert_value typ_jsonvalue := NVL(elem, typ_jsonvalue);
    indx number;
  begin
    if(position > self.count) then --end of list
      indx := self.count + 1;
      self.list_data.extend(1);
      self.list_data(indx) := insert_value;
    elsif(position < 1) then --maybe an error message here
      null;
    else
      self.list_data(position) := insert_value;
    end if;
  end;
  
  member procedure replace(self in out nocopy typ_jsonlist, position pls_integer, elem varchar2) as
  begin
    replace(position, typ_jsonvalue(elem));
  end;
  
  member procedure replace(self in out nocopy typ_jsonlist, position pls_integer, elem number) as
  begin
    if(elem is null) then
      replace(position, typ_jsonvalue());
    else
      replace(position, typ_jsonvalue(elem));
    end if;
  end;
  
  member procedure replace(self in out nocopy typ_jsonlist, position pls_integer, elem boolean) as 
  begin
    if(elem is null) then
      replace(position, typ_jsonvalue());
    else
      replace(position, typ_jsonvalue(elem));
    end if;
  end;
  
  member procedure replace(self in out nocopy typ_jsonlist, position pls_integer,  elem typ_jsonlist ) as 
  begin
    if(elem is null) then
      replace(position, typ_jsonvalue());
    else
      replace(position, elem.to_typ_jsonvalue);
    end if;
  end;

  member function count return number as
  begin
    return self.list_data.count;
  end;
  
  member procedure remove(self in out nocopy typ_jsonlist, position pls_integer) as
  begin
    if(position is null or position < 1 or position > self.count) then return; end if;
    for x in (position+1) .. self.count loop
      self.list_data(x-1) := self.list_data(x);
    end loop;
    self.list_data.trim(1);
  end;
  
  member procedure remove_first(self in out  NOCOPY typ_jsonlist ) as 
  begin
    for x in 2 .. self.count loop
      self.list_data(x-1) := self.list_data(x);
    end loop;
    if(self.count > 0) then 
      self.list_data.trim(1);
    end if;
  end;
  
  member procedure remove_last(self in out  NOCOPY typ_jsonlist ) as
  begin
    if(self.count > 0) then 
      self.list_data.trim(1);
    end if;
  end;
  
  member function get(position pls_integer) return typ_jsonvalue as
  begin
    if(self.count >= position and position > 0) then
      return self.list_data(position);
    end if;
    return null; -- do not throw error, just return null
  end;
  
  member function head return typ_jsonvalue as
  begin
    if(self.count > 0) then
      return self.list_data(self.list_data.first);
    end if;
    return null; -- do not throw error, just return null
  end;
  
  member function last return typ_jsonvalue as
  begin
    if(self.count > 0) then
      return self.list_data(self.list_data.last);
    end if;
    return null; -- do not throw error, just return null
  end;
  
  member function tail return typ_jsonlist as
    t typ_jsonlist;
  begin
    if(self.count > 0) then
      t :=typ_jsonlist(self.list_data);
      t.remove(1);
      return t;
    else return typ_jsonlist(); end if;
  end;

  member function to_char(spaces boolean default true, chars_per_line number default 0) return varchar2 as
  begin
    if(spaces is null) then
      return PAG_JPI.pretty_print_list(self, line_length => chars_per_line);
    else 
      return PAG_JPI.pretty_print_list(self, spaces, line_length => chars_per_line);
    end if;
  end;

  member procedure to_clob(self in typ_jsonlist, buf in out nocopy clob, spaces boolean default false, chars_per_line number default 0, erase_clob boolean default true) as
  begin
    if(spaces is null) then	
      PAG_JPI.pretty_print_list(self, false, buf, line_length => chars_per_line, erase_clob => erase_clob);
    else 
      PAG_JPI.pretty_print_list(self, spaces, buf, line_length => chars_per_line, erase_clob => erase_clob);
    end if;
  end;

  member procedure print(self in typ_jsonlist, spaces boolean default true, chars_per_line number default 8192, jsonp varchar2 default null) as --32512 is the real maximum in sqldeveloper
    my_clob clob;
  begin
    my_clob := empty_clob();
    dbms_lob.createtemporary(my_clob, true);
    PAG_JPI.pretty_print_list(self, spaces, my_clob, case when (chars_per_line>32512) then 32512 else chars_per_line end);
    PAG_JPI.dbms_output_clob(my_clob, PAG_JPI.newline_char, jsonp);
    dbms_lob.freetemporary(my_clob);  
  end;
  
  member procedure htp(self in typ_jsonlist, spaces boolean default false, chars_per_line number default 0, jsonp varchar2 default null) as 
    my_clob clob;
  begin
    my_clob := empty_clob();
    dbms_lob.createtemporary(my_clob, true);
    PAG_JPI.pretty_print_list(self, spaces, my_clob, chars_per_line);
    PAG_JPI.htp_output_clob(my_clob, jsonp);
    dbms_lob.freetemporary(my_clob);  
  end;

  /* typ_json path */
  member function path(json_path varchar2, base number default 1) return typ_jsonvalue as
    cp typ_jsonlist := self;
  begin
    return PAG_JEX.get_typ_jsonvalue(typ_json(cp), json_path, base);
  end path;


  /* typ_json path_put */
  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem typ_jsonvalue, base number default 1) as
    objlist typ_json;
    jp typ_jsonlist := PAG_JEX.parsePath(json_path, base); 
  begin
    while(jp.head().get_number() > self.count) loop
      self.append(typ_jsonvalue());
    end loop;
    
    objlist := typ_json(self);
    PAG_JEX.put(objlist, json_path, elem, base);
    self := objlist.get_values;
  end path_put;
  
  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem varchar2, base number default 1) as
    objlist typ_json;
    jp typ_jsonlist := PAG_JEX.parsePath(json_path, base); 
  begin
    while(jp.head().get_number() > self.count) loop
      self.append(typ_jsonvalue());
    end loop;
    
    objlist := typ_json(self);
    PAG_JEX.put(objlist, json_path, elem, base);
    self := objlist.get_values;
  end path_put;
  
  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem number, base number default 1) as
    objlist typ_json;
    jp typ_jsonlist := PAG_JEX.parsePath(json_path, base); 
  begin
    while(jp.head().get_number() > self.count) loop
      self.append(typ_jsonvalue());
    end loop;
    
    objlist := typ_json(self);
  
    if(elem is null) then 
      PAG_JEX.put(objlist, json_path, typ_jsonvalue, base);
    else 
      PAG_JEX.put(objlist, json_path, elem, base);
    end if;
    self := objlist.get_values;
  end path_put;

  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem boolean, base number default 1) as
    objlist typ_json;
    jp typ_jsonlist := PAG_JEX.parsePath(json_path, base); 
  begin
    while(jp.head().get_number() > self.count) loop
      self.append(typ_jsonvalue());
    end loop;
    
    objlist := typ_json(self);
    if(elem is null) then 
      PAG_JEX.put(objlist, json_path, typ_jsonvalue, base);
    else 
      PAG_JEX.put(objlist, json_path, elem, base);
    end if;
    self := objlist.get_values;
  end path_put;

  member procedure path_put(self in out nocopy typ_jsonlist, json_path varchar2, elem typ_jsonlist, base number default 1) as
    objlist typ_json;
    jp typ_jsonlist := PAG_JEX.parsePath(json_path, base); 
  begin
    while(jp.head().get_number() > self.count) loop
      self.append(typ_jsonvalue());
    end loop;
    
    objlist := typ_json(self);
    if(elem is null) then 
      PAG_JEX.put(objlist, json_path, typ_jsonvalue, base);
    else 
      PAG_JEX.put(objlist, json_path, elem, base);
    end if;
    self := objlist.get_values;
  end path_put;
  
  /* typ_json path_remove */
  member procedure path_remove(self in out nocopy typ_jsonlist, json_path varchar2, base number default 1) as
    objlist typ_json := typ_json(self);
  begin
    PAG_JEX.remove(objlist, json_path, base);
    self := objlist.get_values;
  end path_remove;
  

  member function to_typ_jsonvalue return typ_jsonvalue as
  begin
    return typ_jsonvalue(sys.anydata.convertobject(self));
  end;

  /*--backwards compatibility
  member procedure add_elem(self in out nocopy typ_jsonlist, elem typ_jsonvalue, position pls_integer default null) as begin append(elem,position); end;
  member procedure add_elem(self in out nocopy typ_jsonlist, elem varchar2, position pls_integer default null) as begin append(elem,position); end;
  member procedure add_elem(self in out nocopy typ_jsonlist, elem number, position pls_integer default null) as begin append(elem,position); end;
  member procedure add_elem(self in out nocopy typ_jsonlist, elem boolean, position pls_integer default null) as begin append(elem,position); end;
  member procedure add_elem(self in out nocopy typ_jsonlist, elem typ_jsonlist, position pls_integer default null) as begin append(elem,position); end;

  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer, elem typ_jsonvalue) as begin replace(position,elem); end;
  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer, elem varchar2) as begin replace(position,elem); end;
  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer, elem number) as begin replace(position,elem); end;
  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer, elem boolean) as begin replace(position,elem); end;
  member procedure set_elem(self in out nocopy typ_jsonlist, position pls_integer,  elem typ_jsonlist ) as begin replace(position,elem); end;
  
  member procedure remove_elem(self in out nocopy typ_jsonlist, position pls_integer) as begin remove(position); end;
  member function get_elem(position pls_integer) return typ_jsonvalue as begin return get(position); end;
  member function get_first return typ_jsonvalue as begin return head(); end;
  member function get_last return typ_jsonvalue as begin return last(); end;
--  */
 
end;
/

