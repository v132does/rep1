create or replace force view it.gv_cta_sec_incompatible as
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  pr_cta_prestamos t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('F', 'P')
and  not exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
UNION ALL
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  pr_cta_prestamos t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('I', 'N')
and exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
UNION ALL
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  cx_cta_importaciones t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('F', 'P')
and  not exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
UNION ALL
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  cx_cta_importaciones t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('I', 'N')
and exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
UNION ALL
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  cx_cta_exportaciones t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('F', 'P')
and  not exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
UNION ALL
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  cx_cta_exportaciones t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('I', 'N')
and exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
UNION ALL
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  ov_cta_vencidas t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('F', 'P')
and  not exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
UNION ALL
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  ov_cta_vencidas t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('I', 'N')
and exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
UNION ALL
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  md_cta_documentos t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('F', 'P')
and  not exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
UNION ALL
select t3.cod_persona, t1.nro_cuenta, t6.cod_modulo, t6.descripcion as des_modulo, t7.cod_modalidad as modalidad, t7.descripcion,
t5.descripcion as sector_contable, t4.cod_rub_economico, t4.descripcion as sector_economico , trunc(t1.fec_insercion) as fec_insercion
from  md_cta_documentos t1
inner join ge_cta_clientes t2 on  t1.nro_cuenta = t2.nro_cuenta
inner join ge_clientes t3 on t3.cod_persona = t2.cod_persona
inner join pr_rub_economicos t4 on t1.cod_rub_economico = t4.cod_rub_economico
inner join ge_sec_contables t5 on t3.cod_sec_contable = t5.cod_sec_contable
inner join ba_modulos t6 on t1.cod_modulo = t6.cod_modulo
inner join ge_modalidades t7 on t1.cod_modalidad = t7.cod_modalidad
where  t2.relacion = 'P'
and t3.cod_sec_contable  in ('I', 'N')
and exists (select 1 from ba_cod_referencias t where t.dominio =  'ACT_ECONOMICA' and t.val_minimo = t1.cod_rub_economico and t.val_maximo = t3.cod_sec_contable)
order by  cod_modulo, modalidad, fec_insercion desc;

