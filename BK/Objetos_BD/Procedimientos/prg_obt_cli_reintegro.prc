create or replace procedure it.prg_obt_cli_reintegro(p_cod_persona in ge_cta_clientes.cod_persona%type,
                                                     p_monto_mes   out gv_movimientos.monto%type,
                                                     p_monto_anual out gv_movimientos.monto%type,
                                                     p_cod_error   out number,
                                                     p_msj_error   out varchar2) is

/*Los reintegros son devoluciones que se hacen mediante una operacion,
  tenes un limite de reintegro y un porcentaje de cuanto se va a realizar el reintegro
  en base al monto de la operacion*/

v_ult_dia_mes   date;
v_pri_dia_mes   date;
v_det_error     ge_log_errores.DET_ERROR%type;

begin
v_pri_dia_mes := trunc(trunc(sysdate), 'MM');
v_ult_dia_mes := LAST_DAY(trunc(sysdate));

 -- Obtener el reintegro de un cliente en el mes actual, para las formas de pagos DEBITO/QR
   begin
     select nvl(sum(a.mto_reintegro),0) monto_reint_mes
        into p_monto_mes
        from ge_mov_reintegros a, ge_cta_clientes b
        where trunc(a.fec_insercion) between v_pri_dia_mes and v_ult_dia_mes
         and a.reversado = 'N'
         and a.cod_tra_padre in (702,8951)
         and b.nro_cuenta = a.NRO_CUENTA
         and b.relacion = 'P'
         and b.cod_persona = p_cod_persona
         and exists (select 1 from ge_com_adheridos g
                     where trunc(sysdate) between g.fec_inicio and g.fec_fin
                       and g.cod_cli_comercio = a.cod_cli_comercio);
   exception
      when no_data_found then
        p_monto_mes := 0;
      when others then
        p_cod_error := 500;
        p_msj_error :='Error al obtener monto reintegro mensual';
        v_det_error :='Error al obtener monto reintegro mensual. ' || sqlerrm;
        p_monto_mes := 0;
    end;

   -- Obtener el reintegro de un cliente en el a?o, para las formas de pagos DEBITO/QR
   begin
     select nvl(sum(a.mto_reintegro),0) monto_reint_mes
        into p_monto_anual
        from ge_mov_reintegros a, ge_cta_clientes b
        where trunc(a.fec_insercion) between add_months(trunc(sysdate),-12) and trunc(sysdate)
         and a.reversado = 'N'
         and a.cod_tra_padre in (702,8951)
         and b.nro_cuenta = a.NRO_CUENTA
         and b.relacion = 'P'
         and b.cod_persona = p_cod_persona
         and exists (select 1 from ge_com_adheridos g
                     where trunc(sysdate) between add_months(trunc(sysdate),-12) and trunc(sysdate)
                       and g.cod_cli_comercio = a.cod_cli_comercio);
   exception
      when no_data_found then
        p_monto_anual := 0;
      when others then
        p_cod_error := 500;
        p_msj_error :='Error al obtener monto reintegro anual';
        v_det_error :='Error al obtener monto reintegro anual. ' || sqlerrm;
        p_monto_anual := 0;
    end;

    if nvl(p_cod_error,0) !=0 then
       prg_ins_log_programas('PRG_OBT_CLI_REINTEGRO',substr(v_det_error, 1, 4000),p_cod_persona);
    else
        p_cod_error := 200;
        p_msj_error :='OK';
    end if;

 exception
  when others then
    p_cod_error := 99;
    p_msj_error := 'Ocurrio un error inesperado.';
    v_det_error := 'Ocurrio un error inesperado. ' || sqlerrm;
    prg_ins_log_programas('PRG_OBT_CLI_REINTEGRO',substr(v_det_error, 1, 4000),p_cod_persona);

end prg_obt_cli_reintegro;
/

