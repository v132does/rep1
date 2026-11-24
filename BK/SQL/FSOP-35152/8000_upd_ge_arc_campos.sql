begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end; 
/
update ge_arc_campos c
set c.campo = 'COD_CAU_SECUNDARIA'
where c.referencia = 'CHE_RECHBC'
and   c.campo      = 'COD_CAU_DEV_BCP_DET';

update ge_arc_campos c
set c.campo = 'COD_SUB_MOTIVO'
where c.referencia = 'CHE_RECHBC'
and   c.campo      = 'COD_SUBMOTIVO_DET';
--COD_CAU_PRINCIPAL
update ge_arc_campos c
set c.campo = 'COD_CAU_PRINCIPAL',
     c.tip_dato= 'VARCHAR2'
where c.referencia = 'CHE_RECHBC'
and   c.campo      = 'COD_CAU_DEV_BCP';


update ge_arc_campos c
set c.campo = 'COD_CAU_SECUNDARIA'
where c.referencia = 'CHE_RECHBC_USD'
and   c.campo      = 'COD_CAU_DEV_BCP_DET';

update ge_arc_campos c
set c.campo = 'COD_SUB_MOTIVO'
where c.referencia = 'CHE_RECHBC_USD'
and   c.campo      = 'COD_SUBMOTIVO_DET';

--COD_CAU_PRINCIPAL
update ge_arc_campos c
set c.campo = 'COD_CAU_PRINCIPAL',
    c.tip_dato= 'VARCHAR2'
where c.referencia = 'CHE_RECHBC_USD'
and   c.campo      = 'COD_CAU_DEV_BCP';

commit;
--
-- Add/modify columns 
alter table IT.CC_CHE_DEVUELTOS_TMP modify cod_sub_motivo VARCHAR2(50);
-- ampliamos para sub-motivos de rechazo
alter table IT.CC_CHE_DEVUELTOS modify cod_sub_motivo VARCHAR2(50);


