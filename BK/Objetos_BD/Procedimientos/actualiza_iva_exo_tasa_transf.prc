create or replace procedure it.actualiza_iva_exo_tasa_transf is
  cursor c_datos is
  select *
    from it.ge_tas_fechas t
   where t.cod_persona is not null
     and t.cod_tasa in (30, 35, 36, 41, 42, 43, 44)
     and nvl(t.val_tasa, 0) <> 0;

  v_imp_iva_tasa ge_tas_fechas.val_tasa%type := 0;
  v_imp_iva ge_tas_fechas.val_tasa%type := 0;
begin
   for x in c_datos loop
      v_imp_iva := nvl(x.val_tasa,0) * 0.10;
      v_imp_iva_tasa := nvl(x.val_tasa,0) + nvl(v_imp_iva,0);
      ---Actualizar el importe de la exoneracion
      begin
         update it.ge_tas_fechas f
            set f.val_tasa = nvl(v_imp_iva_tasa,0)
          where f.cod_tasa = x.cod_tasa
            /*and f.fec_vigencia = x.fec_vigencia
            and f.cod_oficina = x.cod_oficina
            and f.cod_moneda = x.cod_moneda
            and f.cod_modulo = x.cod_modulo
            and f.cod_modalidad = x.cod_modalidad
            and f.nro_cuenta = x.nro_cuenta
            and f.tip_iva = x.tip_iva*/
            and f.cod_persona = x.cod_persona;
      exception
         when others then
            raise_application_error(-20000, 'Error al actualizar tasa, cliente: '||x.cod_persona||sqlerrm);
      end;
   end loop;
   commit;
exception
    when others then
       raise_application_error(-20000, 'Error al actualizar tasa, cliente: '||sqlerrm);
end;
/

