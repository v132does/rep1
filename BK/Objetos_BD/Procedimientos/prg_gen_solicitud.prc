CREATE OR REPLACE PROCEDURE IT.PRG_GEN_SOLICITUD
 (P_COD_PERSONA IN varchar2
 ,P_COD_MODALIDAD IN number
 ,P_COD_MONEDA IN varchar2
 ,P_MONTO IN number
 ,P_CAN_CUOTAS IN number
 ,P_GRABAR IN varchar2 := 'S'
 ,P_TIP_MONTO IN varchar2 := 'B'
 ,P_FEC_INICIO IN date := null
 ,P_FEC_PRI_VENCIMIENTO IN date := null
 ,P_VAL_TASA IN number := null
 ,P_COD_CANAL IN number
 ,P_COD_CAMPANA IN number
 ,P_DESCRIPCION IN varchar2 := null  -- descripcion de la oper.
 ,P_MTO_CUOTA IN OUT NUMBER
 )
 IS
v_nro_solicitud  pr_solicitudes.nro_solicitud%type;
 v_redondeo number(2) := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',6,p_cod_modalidad,p_cod_moneda);
BEGIN
   savepoint gen_solicitud;
   prp_gen_solicitud(p_cod_persona, p_cod_modalidad, p_cod_moneda,
                     p_monto, p_can_cuotas, p_grabar, p_tip_monto,
                     p_fec_inicio, p_fec_pri_vencimiento, p_val_tasa,
                     p_cod_canal, p_cod_campana, p_descripcion);
   --- Recuperar promedio de la cuota del nuevo credito negativo para la persona
   begin
      select nro_solicitud
      into   v_nro_solicitud
      from   pr_solicitudes
      where  cod_persona = p_cod_persona
      and    nro_solicitud < 0;
   exception
      when too_many_rows then
         raise_application_error(-20000,
         'Existe mas de una solicitud negativa para la persona '||p_cod_persona);
   end;
   --- Recuperar importe de la cuota
   begin
      select round(sum(nvl(mto_capital,0)+nvl(val_interes,0))/count(*),v_redondeo)
      into   p_mto_cuota
      from   pr_sol_cuotas
      where  nro_solicitud = v_nro_solicitud
      and    (nvl(mto_capital,0) > 0 or nvl(val_interes,0) > 0)
      and    nro_cuota > 0;
   end;
   rollback to savepoint gen_solicitud;
exception
   when others then
      raise_application_error(-20000,
      'Cal.Cuota '||sqlerrm);
END;
/

