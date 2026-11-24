create or replace procedure it.parche_actualiza_residente is
  v_es_residente varchar2(1) := 'N';
  cursor c_clientes is
  select c.cod_persona,
         c.cod_tip_deudor,
         c.cod_sec_contable,
         c.residente
    from it.ge_clientes c;
begin
   for x in c_clientes loop
      v_es_residente := f_es_residente(x.cod_tip_deudor, x.cod_sec_contable);
      update it.ge_clientes cli
         set cli.residente = v_es_residente
       where cli.cod_persona = x.cod_persona;
   end loop;
   commit;
exception
   when others then
      raise_application_error(-20000, 'Error al ejecutar parche_actualiza_residente:'||sqlerrm);
end;
/

