begin pre_ini_aplicacion;pae_cnf.g_cod_modulo := '1'; end;
/

alter table it.sb_lcr_definiciones add (sql_bal_cerrado clob, id_bcp number(10), reporta varchar2(1));
alter table it.sb_lcr_datos_tmp add (id_bcp number(10), reporta varchar2(1));
alter table it.sb_lcr_inf_final add (id_bcp number(10), reporta varchar2(1));

commit;
