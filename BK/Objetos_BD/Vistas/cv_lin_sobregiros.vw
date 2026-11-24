create or replace force view it.cv_lin_sobregiros as
select nvl(to_date(f.val_parametro, 'DD/MM/YYYY'), s.fec_inicio) fec_origen, s.nro_secuencia, s.fec_inicio, s.fec_vencimiento, s.cod_persona,
     p.nom_completo, cl.cod_oficina, o.descripcion des_oficina, cl.cod_usu_oficial, u.nombre nom_oficial,
     CASE WHEN(s.estado = 'C') THEN 'CANCELADO'
     WHEN (nvl(e.val_parametro,'S') ='N') THEN 'NO RENOVAR'
     WHEN (s.tipo = 'T' and p.tipo = 'F' and instr(','|| pa.val_parametro ||',' ,  ','||S.cod_campana||',') > 0
           and  nvl(e.val_parametro,'S') = 'S') THEN 'RENOVAR'
     WHEN (s.tipo = 'T' and s.cod_campana = pc.val_parametro and  nvl(e.val_parametro,'S') = 'S') THEN 'RENOVAR'
     ELSE 'NO APLICA' END EST_RENOVACION,
     s.cod_campana cod_campana, ca.descripcion des_campana, s.cod_rub_economico, r.descripcion des_rub_economico,
     m.val_parametro motivo, decode(s.tipo, 'P', 'Permanente', 'Transitoria') tip_lin_sobregiro, s.nro_linea,
     decode(s.cod_campana, pc.val_parametro, 'C', 'P') tip_renovacion,
     decode(s.cod_campana, pc.val_parametro, 'CUENTA COMERCIO', 'PREAPROBADO') des_renovacion
from cc_lin_sobregiros s,  ba_personas p, ge_clientes cl,
     ba_tab_dat_adicionales f, ba_tab_dat_adicionales e, ba_tab_dat_adicionales m,
     ba_oficinas o, cr_campanas ca, pr_rub_economicos r, ge_par_dinamicos pa, ba_usuarios u,
     ge_par_dinamicos ru, ge_par_dinamicos pc
where s.cod_persona = p.cod_persona
and p.cod_persona = cl.cod_persona
and cl.cod_oficina = o.cod_oficina
and f.tab_relacion(+) = 'CC_LIN_SOBREGIROS'
and f.parametro(+) = 'FEC_ORIGEN'
and s.nro_secuencia = f.referencia(+)
and e.tab_relacion(+) = 'CC_LIN_SOBREGIROS'
and e.parametro(+) = 'RENOVAR'
and s.nro_secuencia = e.referencia(+)
and m.tab_relacion(+) = 'CC_LIN_SOBREGIROS'
and m.parametro(+) = 'DES_MOT_NO_RENOVACION'
and s.nro_secuencia = m.referencia(+)
AND s.cod_campana = ca.cod_campana
AND s.cod_rub_economico = r.cod_rub_economico
AND pa.parametro = 'COD_CAM_REN_LIN_SOB'
AND ru.parametro = 'COD_RUB_ECO_REN_LIN_SOB'
and pc.parametro = 'CCO_CAM_CTA_COMERCIO'
AND cl.cod_usu_oficial = u.cod_usuario
union all
select nvl(to_date(f.val_parametro, 'DD/MM/YYYY'), s.fec_inicio) fec_origen, s.nro_secuencia, s.fec_inicio, s.fec_vencimiento, s.cod_persona,
     p.nom_completo, cl.cod_oficina, o.descripcion, cl.cod_usu_oficial, u.nombre nom_oficial,
     'CANCELADO' estado,
     s.cod_campana cod_campana, ca.descripcion, s.cod_rub_economico cod_sector, r.descripcion,
     m.val_parametro motivo,decode(s.tipo, 'P', 'Permanente', 'Transitoria') tip_lin_sobregiro,
     s.nro_linea, decode(s.cod_campana, pc.val_parametro, 'C', 'P') tip_renovacion,
     decode(s.cod_campana, pc.val_parametro, 'CUENTA COMERCIO', 'PREAPROBADO') des_renovacion
from cc_lin_sobregiros_his s,  ba_personas p, ge_clientes cl,
     ba_tab_dat_adicionales f, ba_tab_dat_adicionales m,
     ba_oficinas o, cr_campanas ca, pr_rub_economicos r, ba_usuarios u, ge_par_dinamicos pc
where s.cod_persona = p.cod_persona
and p.cod_persona = cl.cod_persona
AND s.estado = 'C'
and cl.cod_oficina = o.cod_oficina
and f.tab_relacion(+) = 'CC_LIN_SOBREGIROS'
and f.parametro(+) = 'FEC_ORIGEN'
and s.nro_secuencia = f.referencia(+)
and m.tab_relacion(+) = 'CC_LIN_SOBREGIROS'
and m.parametro(+) = 'DES_MOT_NO_RENOVACION'
and s.nro_secuencia = m.referencia(+)
AND s.cod_campana = ca.cod_campana(+)
AND s.cod_rub_economico = r.cod_rub_economico(+)
and pc.parametro = 'CCO_CAM_CTA_COMERCIO'
AND cl.cod_usu_oficial = u.cod_usuario
union all
select nvl(to_date(f.val_parametro, 'DD/MM/YYYY'), s.fec_inicio) fec_origen, s.nro_secuencia, s.fec_inicio, s.fec_vencimiento, s.cod_persona,
     p.nom_completo, cl.cod_oficina, o.descripcion, cl.cod_usu_oficial, u.nombre nom_oficial,
     'CANCELADO' estado,
     s.cod_campana cod_campana, ca.descripcion, s.cod_rub_economico cod_sector, r.descripcion,
     m.val_parametro motivo,decode(s.tipo, 'P', 'Permanente', 'Transitoria') tip_lin_sobregiro,
     s.nro_linea, decode(s.cod_campana, pc.val_parametro, 'C', 'P') tip_renovacion,
     decode(s.cod_campana, pc.val_parametro, 'CUENTA COMERCIO', 'PREAPROBADO') des_renovacion
from cc_lin_sobregiros s,  ba_personas p, ge_clientes cl,
     ba_tab_dat_adicionales f, ba_tab_dat_adicionales m,
     ba_oficinas o, cr_campanas ca, pr_rub_economicos r, ba_usuarios u, ge_par_dinamicos pc
where s.cod_persona = p.cod_persona
and p.cod_persona = cl.cod_persona
AND s.estado = 'C'
and cl.cod_oficina = o.cod_oficina
and f.tab_relacion(+) = 'CC_LIN_SOBREGIROS'
and f.parametro(+) = 'FEC_ORIGEN'
and s.nro_secuencia = f.referencia(+)
and m.tab_relacion(+) = 'CC_LIN_SOBREGIROS'
and m.parametro(+) = 'DES_MOT_NO_RENOVACION'
and s.nro_secuencia = m.referencia(+)
AND s.cod_campana = ca.cod_campana(+)
AND s.cod_rub_economico = r.cod_rub_economico(+)
and pc.parametro = 'CCO_CAM_CTA_COMERCIO'
AND cl.cod_usu_oficial = u.cod_usuario;

