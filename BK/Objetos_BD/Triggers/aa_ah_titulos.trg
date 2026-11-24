CREATE OR REPLACE TRIGGER IT.AA_AH_TITULOS
 AFTER DELETE OR UPDATE
 ON AH_TITULOS
 FOR EACH ROW

DECLARE
   r_eaudi ge_auditorias%rowtype; -- Registro de la tabla BA_AUDITORIAS
BEGIN
   r_eaudi.tabla := 'AH_TITULOS';
   r_eaudi.clave := :old.serie||'#'||:old.nro_titulo;
   r_eaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_eaudi.tip_novedad := 'M';
   elsif deleting then
      r_eaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
   r_eaudi.detalle := pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'SERIE',:old.SERIE,:new.SERIE);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_TITULO',:old.nro_titulo,:new.nro_titulo);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PERSONA',:old.cod_persona,:new.cod_persona);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'CAPITAL',:old.capital,:new.capital);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_PER_ENDOSADO',:old.cod_per_endosado,:new.cod_per_endosado);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'BENEFICIARIO',:old.beneficiario,:new.beneficiario);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_APERTURA',:old.fec_apertura,:new.fec_apertura,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'FEC_VENCIMIENTO',:old.fec_vencimiento,:new.fec_vencimiento,'N');
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'SER_ORIGEN',:old.ser_origen,:new.ser_origen);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'NRO_TIT_ORIGEN',:old.nro_tit_origen,:new.nro_tit_origen);
   r_eaudi.detalle := r_eaudi.detalle||pae_cnf.fu_reg_auditoria(r_eaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);


   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_eaudi);
END;
/

