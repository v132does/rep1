CREATE OR REPLACE TRIGGER IT.AA_GE_TRA_CAMPOS
 AFTER DELETE OR UPDATE
 ON GE_TRA_CAMPOS
 FOR EACH ROW


DECLARE
r_gaudi ge_auditorias%rowtype; -- Registro de la tabla GE_AUDITORIAS
BEGIN
   r_gaudi.tabla := 'GE_TRA_CAMPOS';
   r_gaudi.clave := to_char(:old.cod_transaccion)||'#'||:old.cod_campo||'#'||to_char(:old.cod_modulo)||'#'||to_char(:old.cod_modalidad);
   r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);

   if updating then
      r_gaudi.tip_novedad := 'M';
   elsif deleting then
      r_gaudi.tip_novedad := 'E';
   end if;

   --- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_ORDEN',:old.nro_orden,:new.nro_orden,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_CAMPO',:old.tip_campo,:new.tip_campo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LON_CAMPO',:old.lon_campo,:new.lon_campo,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_DESPLIEGUE',:old.tip_despliegue,:new.tip_despliegue);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'LON_DESPLIEGUE',:old.lon_despliegue,:new.lon_despliegue,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_LINEA',:old.nro_linea,:new.nro_linea,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_COLUMNA',:old.nro_columna,:new.nro_columna,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'FORMATO',:old.formato,:new.formato);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ALINEACION',:old.alineacion,:new.alineacion);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'ETIQUETA',:old.etiqueta,:new.etiqueta);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_LIN_ETIQUETA',:old.nro_lin_etiqueta,:new.nro_lin_etiqueta,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'NRO_COL_ETIQUETA',:old.nro_col_etiqueta,:new.nro_col_etiqueta,'N');
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_DEFECTO',:old.val_defecto,:new.val_defecto);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_MINIMO',:old.val_minimo,:new.val_minimo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VAL_MAXIMO',:old.val_maximo,:new.val_maximo);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'TIP_DATO',:old.tip_dato,:new.tip_dato);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'VALIDADO',:old.validado,:new.validado);
    r_gaudi.detalle := r_gaudi.detalle||pae_cnf.fu_reg_auditoria(r_gaudi.tip_novedad,'AYUDA',:old.ayuda,:new.ayuda);

   --- Insertar tabla de auditoria
   PRG_INS_GE_AUDITORIA(r_gaudi);
END;
/

