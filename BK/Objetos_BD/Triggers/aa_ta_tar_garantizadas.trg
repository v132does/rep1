CREATE OR REPLACE TRIGGER IT.AA_TA_TAR_GARANTIZADAS
 AFTER DELETE OR UPDATE
 ON TA_TAR_GARANTIZADAS
 FOR EACH ROW


DECLARE
r_taudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_taudi.tabla := 'TA_TAR_GARANTIZADAS';
   r_taudi.clave := :old.cod_persona;
   r_taudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_taudi.tip_novedad := 'M';
   elsif deleting then
      r_taudi.tip_novedad := 'E';
   end if;
   
   --- Registrar Detalle
    r_taudi.detalle := pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FEC_TYC',:old.FEC_TYC,:new.FEC_TYC,'F');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'TYC_VERSION',:old.TYC_VERSION,:new.TYC_VERSION);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'LIMITE',:old.LIMITE,:new.LIMITE);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'FEC_LIMITE',:old.FEC_LIMITE,:new.FEC_LIMITE,'F');
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'NRO_CUENTA',:old.NRO_CUENTA,:new.NRO_CUENTA);
    r_taudi.detalle := r_taudi.detalle||pae_cnf.fu_reg_auditoria(r_taudi.tip_novedad,'COD_ESTADO',:old.COD_ESTADO,:new.COD_ESTADO);

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_taudi);
END;
/

