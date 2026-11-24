CREATE OR REPLACE TRIGGER IT.AA_SB_LIQ_DIARIOS
    AFTER DELETE OR UPDATE
     ON "IT"."SB_LIQ_DIARIOS"
    FOR EACH ROW
  DECLARE
    /*
    || Archivo creado por el Generador de Triggers de Auditoría
    || (c) 2005 - IT Consultores
    || Generado el 04/12/2022 a las 16:59:06 Hs.
    */
    v_registro SB_AUDITORIAS%ROWTYPE; -- Registro de la tabla SB_AUDITORIAS
  BEGIN
    v_registro.tabla := 'SB_LIQ_DIARIOS';
    v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
    v_registro.clave := to_char(:old.fecha) ||'#'|| to_char(:old.cod_moneda) ||'#'|| to_char(:old.cod_cuenta);
    IF updating THEN
    v_registro.tip_novedad := 'M';
    ELSIF deleting THEN
    v_registro.tip_novedad := 'E';
    END IF;

    -- Registrar Detalle
    v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'FECHA', :old.fecha, :new.fecha, 'F' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_MONEDA', :old.cod_moneda, :new.cod_moneda, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_CUENTA', :old.cod_cuenta, :new.cod_cuenta, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'PLAZO', :old.plazo, :new.plazo, 'N' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMPORTE', :old.importe, :new.importe, 'M' );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'TIPO', :old.tipo, :new.tipo );
    v_registro.detalle := v_registro.detalle || pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'IMP_AJUSTADO', :old.imp_ajustado, :new.imp_ajustado, 'M' );

    -- Insertar tabla de auditoria
    prs_ins_sb_auditoria( v_registro );
  EXCEPTION
    when others then
    prs_ins_sb_auditoria( v_registro );
  END;
/

