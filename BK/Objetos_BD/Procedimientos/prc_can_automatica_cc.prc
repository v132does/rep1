CREATE OR REPLACE PROCEDURE IT.PRC_CAN_AUTOMATICA_CC
 IS
/* Cancelación por saldo cero y sin movimiento */
PROCEDURE LP_CAN_SAL_CERO;
/* Actualizar el estado del telegrama */
PROCEDURE LP_ACT_EST_TELEGRAMA
 (P_NRO_CUENTA IN GE_TELEGRAMAS.REF_CUENTAS%TYPE
 ,P_COD_CAUSA IN GE_TELEGRAMAS.COD_CAUSA%TYPE
 );
V_FCDEHOY      DATE;
  V_COD_OFICINA  BA_USUARIOS.COD_OFICINA%TYPE;
  V_HORA         GE_MOVIMIENTOS.HORA%TYPE;
  V_COD_USUARIO  BA_USUARIOS.COD_USUARIO%TYPE;
  V_NRO_SECUENCIA GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE := 1;
/* Cancelación por saldo cero y sin movimiento */
PROCEDURE LP_CAN_SAL_CERO
 IS
cursor cuentas is
   select cc.nro_cuenta
     from cc_cta_corrientes cc
     where cc.estado = 'I'
       and nvl(cc.sal_total,0) =0
       and nvl(sal_bloqueado,0)=0
       and nvl(sal_retenido,0) =0
       and cc.nro_cuenta in (select nro_cuenta
                               from ge_telegramas
                              where nro_cuenta = cc.nro_cuenta
                                and (trunc(v_fcdehoy) - trunc(fec_entrega)) >=30
                                and cod_causa = 45
                                and estado <> 'N'); --Cancelado
begin
  pag_cta.pr_set_variables(v_cod_usuario,v_fcdehoy,303,'N','N',v_nro_secuencia,'C',v_cod_oficina);
  for i in cuentas loop
    If pag_cta.fu_ver_tra_prohibida(i.nro_cuenta,303,4,41) = 'N' then
      v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      pag_cta.pr_act_estado(i.nro_cuenta,'C',v_fcdehoy,v_hora,null,'S');
      lp_act_est_telegrama(i.nro_cuenta,45);
    End if;
  End loop;
end;
/* Actualizar el estado del telegrama */
PROCEDURE LP_ACT_EST_TELEGRAMA
 (P_NRO_CUENTA IN GE_TELEGRAMAS.REF_CUENTAS%TYPE
 ,P_COD_CAUSA IN GE_TELEGRAMAS.COD_CAUSA%TYPE
 )
 IS
begin
   update ge_telegramas
      set estado = 'N'
    where ref_cuentas = p_nro_cuenta
      and cod_causa  = p_cod_causa;
exception
  when others then
    raise_application_error(-20000,'Error: Al actualizar el estado del telegrama');
end;
begin
  v_fcdehoy     := pag_cal.fu_obt_fec_actual(4);
  v_hora        := to_char(sysdate,'hh24:mi:ss');
  v_cod_usuario := user;
  begin
    select cod_oficina
      into v_cod_oficina
      from ba_usuarios
      where cod_usuario = v_cod_usuario;
  exception
    when no_data_found then
      raise_application_error(-20000,'Error al obtener la oficina del usuario');
  end ;
  LP_CAN_SAL_CERO;
end;
/

