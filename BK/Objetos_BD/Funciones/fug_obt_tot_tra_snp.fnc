create or replace function it.fug_obt_tot_tra_snp(p_cod_persona in varchar2,
                                                  p_cod_moneda in varchar2,
                                                  p_fecha in date,
                                                  p_hor_ini in varchar2,
                                                  p_hor_fin in varchar2,
                                                  p_cod_msj_swift in number)
                                                  return number is

  --Funcion para traer el total de Transferencias Enviadas--
  --por tipo de mensaje y por hora--
  v_tot_tra_snp ge_snp_transferencias.monto%type;
begin
  select sum(nvl(t.monto,0))
    into v_tot_tra_snp
    from ge_snp_transferencias t
   where trunc(t.fec_insercion) = p_fecha
     --and trunc(t.fec_insercion) = p_fecha
     and t.cod_per_solicitante = p_cod_persona
     --and t.nro_ref_externa is null
     --and t.fec_recepcion is null
     and t.estado in ('A','S','V')
     and t.situacion in ('D','V','L','I','P','O','S')
     and t.cod_moneda = p_cod_moneda
     and t.cod_tra_padre = 303 --Transferencai Interbancaria--
     and t.cod_msj_swift = p_cod_msj_swift
     --and t.msj_swift like '%{2:I%'
     and to_char(t.fec_insercion,'hh24mi') between p_hor_ini and p_hor_fin;
  return nvl(v_tot_tra_snp,0);
exception
  when others then
    raise_application_error(-20000, 'Error em fug_obt_tot_tra_snp. ' || SQLERRM);
end;
/

