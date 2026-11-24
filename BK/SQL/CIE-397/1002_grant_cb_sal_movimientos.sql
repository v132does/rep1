begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
create public synonym cb_sal_movimientos for IT.cb_sal_movimientos;
grant all on IT.cb_sal_movimientos to it_temporal;
