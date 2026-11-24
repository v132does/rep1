CREATE OR REPLACE TRIGGER IT.AA_CR_SEG_FILTROS
 AFTER DELETE OR UPDATE
 ON CR_SEG_FILTROS
 FOR EACH ROW




DECLARE
r_raudi cr_auditorias%rowtype; -- Registro de la tabla CR_AUDITORIAS
BEGIN
   r_raudi.tabla := 'CR_SEG_FILTROS';
   r_raudi.clave := :old.cod_segmento||'#'||:old.cod_campo||'#'||:old.val_campo;
   r_raudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_raudi.tip_novedad := 'M';
   elsif deleting then
      r_raudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_raudi.detalle := pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_SEGMENTO',:old.cod_segmento,:new.cod_segmento);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'COD_CAMPO',:old.cod_campo,:new.cod_campo);
   r_raudi.detalle := r_raudi.detalle||pae_cnf.fu_reg_auditoria(r_raudi.tip_novedad,'VAL_CAMPO',:old.val_campo,:new.val_campo);

   --- Insertar tabla de auditoria
   PRR_INS_CR_AUDITORIA(r_raudi);
EXCEPTION
WHEN OTHERS THEN
   PRR_INS_CR_AUDITORIA(r_raudi);
END;
/

