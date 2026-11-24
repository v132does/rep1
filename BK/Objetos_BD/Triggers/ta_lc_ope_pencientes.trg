CREATE OR REPLACE TRIGGER IT.TA_LC_OPE_PENCIENTES
 AFTER DELETE OR INSERT OR UPDATE
 ON LC_OPE_PENDIENTES
 FOR EACH ROW

DECLARE
PROCEDURE LP_INS_OPE_ANULADAS
 IS
 v_ope_pend lc_ope_pendientes_his%rowtype;
begin
  if :old.liquidado = 'N' then
       v_ope_pend.fec_anulacion := sysdate;
       v_ope_pend.usu_anulacion := substr(user,1,10);
       if nvl(PAE_CNF.G_PROGRAMA,'x') = 'GPPROFIN' then
         v_ope_pend.cierre := 'S';
       else
         v_ope_pend.cierre := 'N';
       end if;
       v_ope_pend.nro_operacion := :old.nro_operacion;
       v_ope_pend.cod_tip_operacion := :old.cod_tip_operacion;
       v_ope_pend.referenciado := :old.referenciado;
       v_ope_pend.cod_tip_referencia := :old.cod_tip_referencia;
       v_ope_pend.nro_referencia := :old.nro_referencia;
       v_ope_pend.cod_tip_ope_bcp := :old.cod_tip_ope_bcp;
       v_ope_pend.cod_moneda := :old.cod_moneda;
       v_ope_pend.cod_persona := :old.cod_persona;
       v_ope_pend.cod_oficina := :old.cod_oficina;
       v_ope_pend.fec_operacion := :old.fec_operacion;
       v_ope_pend.monto := :old.monto;
       v_ope_pend.cotizacion := :old.cotizacion;
       v_ope_pend.mto_equ_local := :old.mto_equ_local;
       v_ope_pend.cta_referencia := :old.cta_referencia;
       v_ope_pend.cod_tra_cargo1 := :old.cod_tra_cargo1;
       v_ope_pend.mto_cargo1 := :old.mto_cargo1;
       v_ope_pend.cod_tra_cargo2 := :old.cod_tra_cargo2;
       v_ope_pend.mto_cargo2 := :old.mto_cargo2;
       v_ope_pend.cod_tra_cargo3 := :old.cod_tra_cargo3;
       v_ope_pend.mto_cargo3 := :old.mto_cargo3;
       v_ope_pend.cod_tra_cargo4 := :old.cod_tra_cargo4;
       v_ope_pend.mto_cargo4 := :old.mto_cargo4;
       v_ope_pend.cta_ref_contra1 := :old.cta_ref_contra1;
       v_ope_pend.mto_contra1 := :old.mto_contra1;
       v_ope_pend.cta_ref_contra2 := :old.cta_ref_contra2;
       v_ope_pend.mto_contra2 := :old.mto_contra2;
       v_ope_pend.cta_ref_contra3 := :old.cta_ref_contra3;
       v_ope_pend.mto_contra3 := :old.mto_contra3;
       v_ope_pend.cta_ref_contra4 := :old.cta_ref_contra4;
       v_ope_pend.mto_contra4 := :old.mto_contra4;
       v_ope_pend.nro_cuenta := :old.nro_cuenta;
       v_ope_pend.nro_cta_bancaria := :old.nro_cta_bancaria;
       v_ope_pend.nro_cheque := :old.nro_cheque;
       v_ope_pend.nro_boleta := :old.nro_boleta;
       v_ope_pend.concepto := :old.concepto;
       v_ope_pend.usu_insercion := :old.usu_insercion;
       v_ope_pend.fec_insercion := :old.fec_insercion;
       v_ope_pend.usu_modificacion := :old.usu_modificacion;
       v_ope_pend.fec_modificacion := :old.fec_modificacion;
       v_ope_pend.observacion := :old.observacion;
       v_ope_pend.nro_documento := :old.nro_documento;
       v_ope_pend.liquidado := :old.liquidado;
       v_ope_pend.cod_usu_liquidacion := :old.cod_usu_liquidacion;
       v_ope_pend.fec_liquidacion := :old.fec_liquidacion;
       v_ope_pend.cta_ref_contra5 := :old.cta_ref_contra5;
       v_ope_pend.mto_contra5 := :old.mto_contra5;
       v_ope_pend.cod_retencion := :old.cod_retencion;
       v_ope_pend.nro_diario := :old.nro_diario;
       v_ope_pend.ope_homebanking := :old.ope_homebanking;
       v_ope_pend.cod_mon_destino := :old.cod_mon_destino;
       insert into lc_ope_pendientes_his values v_ope_pend;
  end if;     
end;

BEGIN   
   IF deleting THEN
      LP_INS_OPE_ANULADAS;
   end if;   
END;
/

