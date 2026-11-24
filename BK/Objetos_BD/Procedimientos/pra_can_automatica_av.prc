CREATE OR REPLACE PROCEDURE IT.PRA_CAN_AUTOMATICA_AV
 IS
V_FCDEHOY      DATE;
V_DIA_INA      NUMBER(10);
V_COD_OFICINA  BA_USUARIOS.COD_OFICINA%TYPE;
V_HORA         GE_MOVIMIENTOS.HORA%TYPE;
V_COD_USUARIO  BA_USUARIOS.COD_USUARIO%TYPE;
V_NRO_SECUENCIA GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE := 1;
cursor cuentas is
   select nro_cuenta
     from ah_cta_vistas
     where estado = 'I'
       and nvl(sal_total,0)=0 and nvl(sal_bloqueado,0)=0 and nvl(sal_retenido,0)=0
       and (trunc(v_fcdehoy) - trunc(fec_ult_movimiento)) >= v_dia_ina;
begin
  v_fcdehoy     := pag_cal.fu_obt_fec_actual(3);
  v_dia_ina     := FUG_OBT_PARDINAMICO('DIA_INA_CAN_CTA');
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
  pag_cta.pr_set_variables(v_cod_usuario,v_fcdehoy,303,'N','N',v_nro_secuencia,'C',v_cod_oficina);
  for i in cuentas loop
    If pag_cta.fu_ver_tra_prohibida(i.nro_cuenta,303,3,31) = 'N' then
      v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      pag_cta.pr_act_estado(i.nro_cuenta,'C',v_fcdehoy,v_hora,null,'S');
    End if;
  End loop;
end;
/

