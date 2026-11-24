CREATE OR REPLACE TRIGGER IT.AA_BW_TYC_VERSIONES
    AFTER UPDATE OR DELETE
    ON BW_TYC_VERSIONES
    FOR EACH ROW
DECLARE
    -- Registro de la tabla BW_AUDITORIAS
    r_gaudi BW_AUDITORIAS%ROWTYPE;
BEGIN
    r_gaudi.tabla := 'BW_TYC_VERSIONES';
    r_gaudi.clave := :old.cod_version;
    r_gaudi.fec_calendario := pae_cnf.fu_obt_fec_actual( pae_cnf.g_cod_modulo );
    IF updating THEN
        r_gaudi.tip_novedad := 'M';
    ELSIF deleting THEN
        r_gaudi.tip_novedad := 'E';
    END IF;

    -- Registrar Detalle
    r_gaudi.detalle := pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'COD_VERSION', :old.cod_version, :new.cod_version );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'APLICACION', :old.aplicacion, :new.aplicacion );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'VERSION', :old.version, :new.version );
    r_gaudi.detalle := r_gaudi.detalle || pae_cnf.fu_reg_auditoria( r_gaudi.tip_novedad, 'TERMINOS', :old.terminos, :new.terminos );
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

