Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
insert into ge_tas_rangos (cod_tasa, fec_vigencia, cod_moneda, val_hasta, val_tasa, no_actualizable)
(select 520, trunc(sysdate), 'USD', cod_seg_cliente, 0.00, 'N'
from ge_seg_clientes);

commit;
