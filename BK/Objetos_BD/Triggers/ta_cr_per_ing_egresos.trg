CREATE OR REPLACE TRIGGER IT.TA_CR_PER_ING_EGRESOS
 AFTER INSERT OR DELETE OR UPDATE
 ON CR_PER_ING_EGRESOS
 FOR EACH ROW
BEGIN
  if inserting or updating then
     if :new.cod_concepto = 1 and :new.ing_egreso = 'I' then
        --actualizar rh_empleados
        update rh_empleados a
           set sal_base = :new.importe
         where cod_persona = :new.cod_persona
           and exists (select 0
                         from ba_usuarios b
                        where a.cod_persona = b.cod_persona);
     end if;
  end if;
END;
/

