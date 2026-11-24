CREATE OR REPLACE TRIGGER IT.AA_GE_TELEGRAMAS
 AFTER DELETE OR UPDATE
 ON GE_TELEGRAMAS
 FOR EACH ROW

DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_TELEGRAMAS
BEGIN
   r_gaudi.tabla := 'GE_TELEGRAMAS';
   r_gaudi.clave := to_char(:old.cod_telegrama);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;
   --- Registrar Detalle
   r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'REF_CUENTAS',:old.ref_cuentas,:new.ref_cuentas);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_CAUSA',:old.cod_causa,:new.cod_causa,'N');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ZONA',:old.zona,:new.zona);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_GENERACION',:old.fec_generacion,:new.fec_generacion,'F');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_IMPRESION',:old.fec_impresion,:new.fec_impresion,'F');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_ENTREGA',:old.fec_entrega,:new.fec_entrega,'F');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FEC_ENT_OFICIAL',:old.fec_ent_oficial,:new.fec_ent_oficial,'F');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_ENTREGA',:old.tip_entrega,:new.tip_entrega);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ACTA',:old.acta,:new.acta);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COBRADO',:old.cobrado,:new.cobrado);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_USU_IMPRESION',:old.cod_usu_impresion,:new.cod_usu_impresion);
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'SALDO',:old.saldo,:new.saldo,'M');
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'MONTO',:old.monto,:new.monto,'M');      
   r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);   
    --- Insertar tabla de auditoria
    PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

