BEGIN
	DROP TABLE 	IT.ta_cta_lin_tarjetas_tmp_ro;
	DROP TABLE  IT.ta_cta_sal_tarjetas_tmp_ro;
	DROP TABLE  IT.ta_cuentas_tmp_ro;
	DROP TABLE  IT.ta_int_per_tarjetas_tmp_ro;
	DROP TABLE  IT.ta_mov_diarios_tmp_ro;
	DROP TABLE  IT.ta_mov_intereses_tmp_ro;
	DROP TABLE  IT.ta_personas_tmp_ro;
	DROP TABLE  IT.ta_sal_fin_tarjetas_tmp_ro;	
	DROP TABLE  IT.ta_tar_cuentas_tmp_ro;	
	DROP TABLE  IT.ta_tas_int_tarjetas_tmp_ro;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error al eliminar la tabla: ' || SQLERRM);
END;