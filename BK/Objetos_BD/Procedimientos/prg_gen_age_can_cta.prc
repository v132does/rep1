CREATE OR REPLACE PROCEDURE IT.PRG_GEN_AGE_CAN_CTA
 (P_DESDE IN DATE
 ,P_HASTA IN DATE
 )
 IS
V_DIA_INA NUMBER(10);
V_FCDEHOY DATE;
cursor cuentas is
   select ahv.nro_cuenta, cli.cod_persona,cli.cod_usu_oficial,
          trunc(ahv.fec_ult_movimiento) + v_dia_ina fec_cancelacion
     from ah_cta_vistas ahv,
          ge_cta_clientes cta,
          ge_clientes cli
    where ahv.nro_cuenta = cta.nro_cuenta
      and cta.cod_persona = cli.cod_persona
      and cta.relacion = 'P'
      and ahv.estado = 'I'
      and (nvl(ahv.sal_total,0)-(nvl(ahv.sal_bloqueado,0)+ nvl(ahv.sal_retenido,0))) <= 0
      and trunc(ahv.fec_ult_movimiento) + v_dia_ina between p_desde and p_hasta;
begin
  v_dia_ina := FUG_OBT_PARDINAMICO('DIA_INA_CAN_CTA');
  v_fcdehoy := pag_cal.fu_obt_fec_proxima(3);
  for i in cuentas loop
    prg_gen_age_actividades(i.cod_persona, i.cod_usu_oficial,3,1,16,v_fcdehoy,
     'La cuenta '||i.nro_cuenta||' de tipo Ahorro a la Vista, será cancelada en forma '||
     'automatica el día '||to_char(i.fec_cancelacion,'dd/mm/rrrr')||' por permanecer '||
     'inactiva por mas de '||to_char(v_dia_ina)||' días y sin saldo. '||
     'Si desea evitar la cancelacion automatica, agregue la transaccion 3-31-303 entre '||
     'las transacciones prohibidas de la cuenta.');
  end loop;
end;
/

