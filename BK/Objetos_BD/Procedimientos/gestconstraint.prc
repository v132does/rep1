create or replace procedure it.GesTConstraint(p_opcion char, p_owner varchar2) is

  -- p_opcion = 'D' -> deshabilita
  -- p_opcion = 'H' -> habilita
  cursor disableIT is
    select 'alter table IT.' || table_name || ' disable constraint ' ||
           constraint_name sentencia
      from all_constraints
     where owner = 'IT'
       AND CONSTRAINT_TYPE not in ('P', 'C');
  cursor enableIT is
    select 'alter table IT.' || table_name || ' enable constraint ' ||
           constraint_name sentencia
      from all_constraints
     where owner = 'IT'
       AND CONSTRAINT_TYPE not in ('P', 'C');

begin
  if p_opcion = 'D' then
    if p_owner = 'IT' then
      for dt in disableIT loop
        execute immediate dt.sentencia;
      end loop;
    end if;
  elsif p_opcion = 'H' then
    if p_owner = 'IT' then
      for dt in enableIT loop
        execute immediate dt.sentencia;
      end loop;
    end if;
  end if;
exception
  when others then
    raise_application_error(-20000, 'Error al ejecutar GesTConstraint:'||sqlerrm);
end GesTConstraint;
/

