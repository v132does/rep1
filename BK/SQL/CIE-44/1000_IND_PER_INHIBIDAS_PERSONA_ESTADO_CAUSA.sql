-- Create/Recreate indexes 
CREATE INDEX IT.IN_GPINH_PERSONA ON IT.GE_PER_INHIBIDAS (COD_PERSONA, ESTADO, COD_CAUSA);

CREATE INDEX IT.IN_GAUTO_cod_transaccion ON IT.GE_AUTORIZACIONES(nro_cuenta, cod_transaccion, cod_modulo, cod_modalidad, cod_tra_padre,cod_mod_padre, cod_mad_padre, cod_usu_utilizador, fec_vencimiento);