CREATE OR REPLACE TRIGGER IT.AA_GE_PAQUETES
 AFTER DELETE OR UPDATE
 ON GE_PAQUETES
 FOR EACH ROW
DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_PAQUETES';
   r_gaudi.clave := to_char(:old.cod_paquete);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'DESCRIPCION',:old.descripcion,:new.descripcion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_MONEDA',:old.cod_moneda,:new.cod_moneda);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_PERSONA',:old.tip_persona,:new.tip_persona);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'COD_SEG_PREFERENTE',:old.cod_seg_preferente,:new.cod_seg_preferente, 'N' );
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ESTADO',:old.estado,:new.estado);

--- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

