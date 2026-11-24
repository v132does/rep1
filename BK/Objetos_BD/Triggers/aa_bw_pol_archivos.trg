CREATE OR REPLACE TRIGGER IT.AA_BW_POL_ARCHIVOS
AFTER DELETE OR UPDATE
ON BW_POL_ARCHIVOS FOR EACH ROW

DECLARE

    v_registro BW_AUDITORIAS%ROWTYPE;

BEGIN
  
    v_registro.tabla := 'BW_POL_ARCHIVOS';
    v_registro.clave := to_char(:old.cod_pol_seguro);
    v_registro.fec_calendario := pae_cnf.fu_obt_fec_actual(pae_cnf.g_cod_modulo);
    
IF updating THEN
  
    v_registro.tip_novedad := 'M';
    
ELSIF deleting THEN

    v_registro.tip_novedad := 'E';
    
END IF;

  -- Registrar Detalle
    v_registro.detalle := pae_cnf.fu_reg_auditoria( v_registro.tip_novedad, 'COD_POL_SEGURO', :old.cod_pol_seguro, :new.cod_pol_seguro );
  -- Insertar tabla de auditoria
    prw_ins_bw_auditoria( v_registro );
    
EXCEPTION
  when others then
    prw_ins_bw_auditoria( v_registro );
END;
/

