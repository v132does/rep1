CREATE OR REPLACE TRIGGER IT.TA_GE_BANCOS
  AFTER UPDATE ON ge_bancos
  REFERENCING OLD AS OLD NEW AS NEW
  for each row
declare
  cursor c_cuentas is
     select nro_cuenta
       from ge_cta_clientes a
      where a.relacion ='P'
        and cod_persona = :old.cod_persona
        and exists(select 1
                     from cx_cta_exportaciones e
                    where confirmado = 'S'
                      and e.nro_cuenta= a.nro_cuenta);

/* Verifica si cambia la persona relacionada al banco, si el banco
   esta registrado como banco emisor de CCE's confirmadas
   actualiza la persona principal de las CCE afectadas */
begin
  IF :new.cod_persona <> :old.cod_persona then
      For c In c_cuentas Loop
            update ge_cta_clientes
               set cod_persona = :new.cod_persona
             where cod_persona = :old.cod_persona
               and relacion ='P'
               and nro_cuenta = c.nro_cuenta;
          end loop;
   end if;
exception
  when no_data_found then
       null;
  when others then
        raise_application_error(-20000,'TA_GE_BANCOS '||sqlerrm);
end TA_GE_BANCOS;
/

