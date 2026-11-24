create or replace procedure it.cc_actualizar_mto_sob_suspenso is
  monto_total number := 0;

  cursor cur_ctas is
  select distinct s.nro_cuenta from cc_sob_suspenso s;
begin
 -- registrar_fase3('Inicio del procedimiento CC_ACTUALIZAR_MTO_SOB_SUSPENSO','CC');

  for x in cur_ctas loop
    begin
      select nvl(sum(s.monto),0) into monto_total
      from cc_sob_suspenso s
      where s.nro_cuenta=x.nro_cuenta;
    exception
      when others then
        NULL;
       -- registrar_error_fase3('CC_ACTUALIZAR_MTO_SOB_SUSPENSO',x.nro_cuenta,sqlerrm,'CC');
    end;

    begin
      update cc_cta_corrientes c
      set c.mto_sob_suspenso = monto_total
      where c.nro_cuenta=x.nro_cuenta;
    exception
      when others then
        NULL;
       -- registrar_error_fase3('CC_ACTUALIZAR_MTO_SOB_SUSPENSO',x.nro_cuenta,sqlerrm,'CC');
    end;
  end loop;
  commit;

  --registrar_fase3('Fin del procedimiento CC_ACTUALIZAR_MTO_SOB_SUSPENSO','CC');

end cc_actualizar_mto_sob_suspenso;
/

