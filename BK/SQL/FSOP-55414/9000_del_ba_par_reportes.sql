Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/
delete it.ba_par_reportes a
where a.cod_programa = 'PLCHEDES'
and   a.cod_campo = 'PERSONA';

delete it.ba_par_reportes a
where a.cod_programa = 'LLTRADET'
and   a.cod_campo = 'PERSONA';

commit;
