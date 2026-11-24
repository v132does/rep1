begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:=1; end; 
/
--
insert into ba_cod_referencias (DOMINIO, SIGNIFICADO, FEC_INSERCION, USU_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, VAL_MINIMO, VAL_MAXIMO, ABREVIATURA, ACTIVO)
values ('CAJ_PAR_PRODEP', 'Usuario que se envia en el link', to_date('15-12-2023 17:06:20', 'dd-mm-yyyy hh24:mi:ss'), 'IT', 'IT', to_date('15-12-2023 17:07:07', 'dd-mm-yyyy hh24:mi:ss'), 'T', null, 'Usuario que se envia en el link', 'S');

update it.ba_cod_referencias b
set   b.val_maximo = 'N'
where b.val_minimo = 'B'
and   b.dominio = 'CAJ_PAR_PRODEP';

update it.ba_cod_referencias b
set   b.val_maximo = '1'
where b.val_minimo = 'C'
and   b.dominio = 'CAJ_PAR_PRODEP';

update it.ba_cod_referencias b
set   b.val_maximo = 'http://192.168.40.116:4268/prodep-caja/services/callprodep?'
where b.val_minimo = 'D'
and   b.dominio = 'CAJ_PAR_PRODEP';

update it.ba_cod_referencias b
set   b.val_maximo = '192.168.40.116'
where b.val_minimo = 'I'
and   b.dominio = 'CAJ_PAR_PRODEP';


update it.ba_cod_referencias b
set   b.val_maximo = 'PRODEP'
where b.val_minimo = 'U'
and   b.dominio = 'CAJ_PAR_PRODEP';

commit;
/

