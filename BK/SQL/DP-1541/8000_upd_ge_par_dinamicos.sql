begin  pre_ini_aplicacion;  pae_cnf.g_cod_modulo := 1; end; 
/
update ge_par_dinamicos set val_parametro = '585385' /*'557510'-'539000'*/ where parametro in ('IMP_MIN_GAS');

update ge_par_dinamicos set val_parametro = '585385' /*'557510'-'539000'*/ where parametro in ('MTO_MAX_COM_ADM') and cod_moneda ='GS';

update ge_par_dinamicos set val_parametro = '76100000' /*'72476200'-'63757675'*/ where parametro in ('MTO_TAE');

update ge_par_dinamicos set val_parametro = '76100000' /*'72476200'-'63757675'*/ where parametro in ('MTO_SOL_MAX_ADM') and cod_moneda ='GS';

update ge_par_dinamicos set val_parametro = '85' /*'75'*/ where parametro in ('MTO_MAX_COM_ADM') and cod_moneda ='USD';

update ge_par_dinamicos set val_parametro = '11324' /*'9000'*/ where parametro in ('MTO_SOL_MAX_ADM') and cod_moneda ='USD';

commit;
