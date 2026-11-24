create or replace procedure it.ah_actualizar_fec_sal_cap_trim is
  saldo_ult_cap number;

  cursor cur_ctas is
  select * from ah_cta_vistas v
  where v.tip_capitalizacion=3
  and v.fec_apertura<=to_date('311209','ddmmyy')
  and v.fec_ult_capitalizacion=to_date('300909','ddmmyy')
  and v.estado not in ('C','P');

begin
 -- registrar_fase3('Inicio del procedimiento AH_ACTUALIZAR_FEC_SAL_CAP_TRIM','AH');

  /*for x in cur_ctas loop
   begin
      select ma.m719sddiac into saldo_ult_cap
      from mae311209_arma719 ma
      where ma.m719suc=x.cod_oficina
      and ma.m719sub=to_number(substr(x.nro_cuenta,5,6));
    exception
      when others then
        registrar_error_fase3('AH_ACTUALIZAR_FEC_SAL_CAP_TRIM',x.nro_cuenta,sqlerrm,'AH');
    end;

    begin
      update ah_cta_vistas v
      set v.sal_ult_capitalizacion=saldo_ult_cap,
          v.fec_ult_capitalizacion=to_date('31/12/2009','dd/mm/yyyy')
      where v.nro_cuenta=x.nro_cuenta;
    exception
      when others then
        registrar_error_fase3('AH_ACTUALIZAR_FEC_SAL_CAP_TRIM',x.nro_cuenta,sqlerrm,'AH');
    end;
  end loop;
  commit;
*/
 -- registrar_fase3('Fin del procedimiento AH_ACTUALIZAR_FEC_SAL_CAP_TRIM','AH');
NULL;
end ah_actualizar_fec_sal_cap_trim;
/

