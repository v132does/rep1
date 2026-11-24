Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

delete it.ba_par_reportes a
where a.cod_programa = 'GLSALCLI'
and   a.cod_campo = 'PERSONA';


insert into it.ba_par_reportes (COD_PROGRAMA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN)
values ('GLSALCLI', 'NRO_DOCU', 'ba_personas', null, 'F', 1);

commit; 