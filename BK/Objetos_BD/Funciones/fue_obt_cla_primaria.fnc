CREATE OR REPLACE FUNCTION IT."FUE_OBT_CLA_PRIMARIA"
 (p_nom_tabla in varchar2)
  return varchar2 is
  Result varchar2(500) := null; -- variable de resultado
  -- para que esta funcion se active, se debe en la base con sysdba, se debe
  -- dar el sgte. comando: grant select on v_$session to it;
cursor columnas is
select column_name
from all_cons_columns b, all_constraints a
where a.table_name = upper(p_nom_tabla)
and a.constraint_type = 'P'
and a.owner = 'IT' -- fijo para IT
and a.constraint_name = b.constraint_name
and a.owner = b.owner
order by position;

cursor columnas2 is
select column_name
from all_cons_columns b, all_constraints a
where a.table_name = upper(p_nom_tabla)
and a.constraint_type = 'U'
and a.owner = 'IT' -- fijo para IT
and a.constraint_name = b.constraint_name
and a.owner = b.owner
order by position;

begin
  for c in columnas loop
     if Result is null then
        Result := Result || c.column_name;
     else
        Result := Result ||'#'||c.column_name;
     end if;
  end loop;
  If Result is null then
    for c in columnas2 loop
       if Result is null then
          Result := Result || c.column_name;
       else
          Result := Result ||'#'||c.column_name;
       end if;
        --Exit; CRO-JM-11/2014: DYDMR-987
    end loop;
  End if;
  return(Result);
exception
    when others then
     raise_application_error(-20000,'FUE_OBT_CLA_PRIMARIA '||sqlerrm);
end FUE_OBT_CLA_PRIMARIA;
/

