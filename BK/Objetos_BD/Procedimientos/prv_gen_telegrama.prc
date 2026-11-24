create or replace procedure it.PRV_GEN_TELEGRAMA(P_NRO_CUENTA IN VARCHAR2,
                                              P_COD_MODALIDAD IN NUMBER,
                                              P_MONTO IN NUMBER,
                                              P_SALDO IN NUMBER,
                                              P_MONEDA IN VARCHAR2,
                                              P_COD_PERSONA IN VARCHAR2) is

 v_cod_cau_telegrama ge_causales.cod_causa%type;
 v_fcdehoy ge_telegramas.fec_generacion%type;

begin
 v_fcdehoy := pag_cal.fu_obt_fec_actual(1);

 if p_cod_modalidad = 151 then -- Tarjetas Vencidas
  v_cod_cau_telegrama := nvl(fug_obt_pardinamico('COD_CAU_TEL_PAS_VEN_TC'),1);
   insert into ge_telegramas(cod_telegrama,cod_causa,zona,fec_generacion,
                             fec_impresion,tip_entrega,fec_entrega,fec_ent_oficial,
                             cod_persona,estado,acta,cobrado,cod_usu_impresion,monto,
                             saldo,cod_moneda,ref_cuentas)
                      values(s_cod_telegrama.nextval,v_cod_cau_telegrama,null,v_fcdehoy,
                             null,null,null,null,
                             p_cod_persona,'G','N','N',null,p_monto,
                             p_saldo,p_moneda,p_nro_cuenta);
 else /* SOBREGIROS A OPERACION VENCIDA */
   v_cod_cau_telegrama := nvl(fug_obt_pardinamico('COD_CAU_TEL_PAS_VEN_CC'),1);
   insert into ge_telegramas(cod_telegrama,cod_causa,zona,fec_generacion,
                             fec_impresion,tip_entrega,fec_entrega,fec_ent_oficial,
                             cod_persona,estado,acta,cobrado,cod_usu_impresion,monto,
                             saldo,cod_moneda,ref_cuentas)
                      values(s_cod_telegrama.nextval,v_cod_cau_telegrama,null,v_fcdehoy,
                             null,null,null,null,
                             p_cod_persona,'G','N','N',null,p_monto,
                             p_saldo,p_moneda,p_nro_cuenta);
 end if;
exception
   when others then
    If sqlcode <= -20000 then
      raise;
    else
      raise_application_error(-20001,'Error: En el proceso de telegramas por pase a Vencida... '||sqlerrm);
    End if;
end;
/

