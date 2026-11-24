begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/

update ge_arc_campos a
set a.tip_dato = 'VARCHAR2', a.longitud = 20, a.funcion = null, a.formato = null
where a.referencia = 'REGISTRO_PLANES'
and   a.nom_tabla ='GE_PLAN_DAS_TMP'
and (a.campo = 'fec_fin' or a.campo = 'fec_inicio');

COMMIT;