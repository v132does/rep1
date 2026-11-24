CREATE OR REPLACE TRIGGER IT.AA_TA_CON_PROMOCIONES
 AFTER DELETE OR UPDATE
 ON TA_CON_PROMOCIONES
 FOR EACH ROW


DECLARE
r_gaudi ta_auditorias%rowtype; -- Registro de la tabla TA_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'TA_CON_PROMOCIONES';
   r_gaudi.clave := to_char(:old.nro_convenio);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_CTA_DEB_COMERCIO',:old.nro_cta_deb_comercio,:new.nro_cta_deb_comercio);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_RUB_DEB_ENTIDAD',:old.cod_rub_deb_entidad,:new.cod_rub_deb_entidad);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COMERCIO',:old.comercio,:new.comercio);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'POR_DESCUENTO',:old.por_descuento,:new.por_descuento);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'POR_ENTIDAD',:old.por_entidad,:new.por_entidad);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'POR_COMERCIO',:old.por_comercio,:new.por_comercio);

   --- Insertar tabla de auditoria
   PRT_INS_TA_AUDITORIA(r_gaudi);
END;
/

