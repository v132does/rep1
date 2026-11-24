CREATE OR REPLACE TRIGGER IT.AA_BW_EMA_LOGIN_BLACKLIST
    AFTER INSERT OR UPDATE OR DELETE
    ON BW_EMA_LOGIN_BLACKLIST
    FOR EACH ROW
DECLARE
    -- Registro de la tabla BW_AUDITORIAS
    r_gaudi BW_AUDITORIAS%ROWTYPE;
BEGIN
    r_gaudi.tabla := 'BW_EMA_LOGIN_BLACKLIST';
    r_gaudi.clave := :new.cod_persona;
    r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
    IF inserting THEN
        r_gaudi.tip_novedad := 'I';
    ELSIF updating THEN
        r_gaudi.tip_novedad := 'M';
    ELSIF deleting THEN
        r_gaudi.tip_novedad := 'E';
    END IF;

    -- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_PERSONA', :old.cod_persona, :new.cod_persona );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_EMPRESA', :old.cod_empresa, :new.cod_empresa );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_DISPOSITIVO', :old.cod_dispositivo, :new.cod_dispositivo );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'VERSION_EMA', :old.version_ema, :new.version_ema );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'MOBILE_OS', :old.mobile_os, :new.mobile_os );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'ESTADO', :old.estado, :new.estado );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_INSERCION', :old.fec_insercion, :new.fec_insercion, 'F' );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_INSERCION', :old.usu_insercion, :new.usu_insercion );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'FEC_MODIFICACION', :old.fec_modificacion, :new.fec_modificacion, 'F' );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'USU_MODIFICACION', :old.usu_modificacion, :new.usu_modificacion );

    -- Insertar tabla de auditoria
    prw_ins_bw_auditoria( r_gaudi );
EXCEPTION
    when others then
        prw_ins_bw_auditoria( r_gaudi );
END;
/

