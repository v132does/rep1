create or replace procedure it.GestTriggers(p_opcion char, p_owner varchar2) is

  -- p_opcion = 'D' -> deshabilita los triggers
  -- p_opcion = 'H' -> habilita los triggers
  cursor disableTriggerIT is
    select 'alter table IT.' || a.object_name || ' disable all triggers' sentencia
      from all_objects a
     where a.owner = 'IT'
       and a.object_type = 'TABLE';
  cursor enableTriggerIT is
    select 'alter table IT.' || a.object_name || ' enable all triggers' sentencia
      from all_objects a
     where a.owner = 'IT'
       and a.object_type = 'TABLE';
begin
  if p_opcion = 'D' then
    if p_owner = 'IT' then
      for dt in disableTriggerIT loop
        execute immediate dt.sentencia;
      end loop;
    end if;
  elsif p_opcion = 'H' then
    if p_owner = 'IT' then
      for dt in enableTriggerIT loop
        execute immediate dt.sentencia;
      end loop;
    end if;
  end if;
exception
  when others then
     raise_application_error(-20000, 'Error al ejecutar GestTriggers:'||sqlerrm);
end GestTriggers;
/

