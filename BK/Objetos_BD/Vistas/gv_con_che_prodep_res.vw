create or replace force view it.gv_con_che_prodep_res as
select q.fecha, q.cod_tip_conc, q.des_tip_conc, q.tie_dif_conc, q.cod_moneda, q.can_dif_conc, q.monto1, q.monto2, q.mto_dif_conc
from
(select p.fecha, '1' cod_tip_conc, fue_obt_des_refcodes('TIP_CON_PRODEP','1') des_tip_conc,
       case when (nvl(p.monto,0) - nvl(o.monto,0)) <> 0 then 'S' else 'N' end tie_dif_conc,
       p.cod_moneda,
       count(*) can_dif_conc,
       sum(nvl(p.monto,0)) monto1,
       sum(nvl(o.monto,0)) monto2,
       sum((nvl(p.monto,0) - nvl(o.monto,0))) mto_dif_conc
from
(select t.nro_boleta, t.monto
   from CC_CHE_REMITIDOS_RES t
  where t.fecha = pag_cal.fu_obt_fec_actual(1)) o,
(select t.fecha, '1' cod_tip_conc, fue_obt_des_refcodes('TIP_CON_PRODEP','1') des_tip_conc,
       t.hora, t.cod_usuario, t.nro_caja, t.nro_cuenta, t.nro_documento, t.cod_mod_padre, t.cod_tra_padre,
       t.nro_referencia ref_prodep, null nro_lote, t.cod_oficina, t.cod_oficina cod_ofi_origen,
       t.cod_moneda, sum(nvl(t.monto,0)) monto,
       count(*) can_cheques
from CJ_MOV_PRODEP t
where t.fecha = pag_cal.fu_obt_fec_actual(1)
  and t.estado = 'N'
  and ((fuj_obt_tip_caja(t.nro_caja) <> 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') <= (select k.val_maximo||':00'
                                                  from ba_cod_referencias k
                                                 where k.dominio = 'HOR_COR_CAMARA'
                                                   and k.val_minimo = '1')) or
       (fuj_obt_tip_caja(t.nro_caja) = 'S' and
         ((to_char(t.fec_insercion,'hh24:mi:ss') <= (select k.val_maximo||':00'
                                                    from ba_cod_referencias k
                                                   where k.dominio = 'HOR_COR_CAMARA'
                                                     and k.val_minimo = 'T') and
           trunc(t.fec_insercion) = pag_cal.fu_obt_fec_actual(1)) or
          (to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                    from ba_cod_referencias k
                                                   where k.dominio = 'HOR_COR_CAMARA'
                                                     and k.val_minimo = 'T') and
           trunc(t.fec_insercion) < pag_cal.fu_obt_fec_actual(1)))))
group by t.fecha, '1', fue_obt_des_refcodes('TIP_CON_PRODEP','1'),
       t.hora, t.cod_usuario, t.nro_caja, t.nro_cuenta, t.nro_documento, t.cod_mod_padre, t.cod_tra_padre,
       t.nro_referencia, null, t.cod_oficina, t.cod_oficina,
       t.cod_moneda
union all
select t.fecha, '1' cod_tip_conc, fue_obt_des_refcodes('TIP_CON_PRODEP','1') des_tip_conc,
       t.hora, t.cod_usuario, t.nro_caja, t.nro_cuenta, t.nro_documento, t.cod_mod_padre, t.cod_tra_padre,
       t.nro_referencia ref_prodep, null nro_lote, t.cod_oficina, t.cod_oficina cod_ofi_origen,
       t.cod_moneda, sum(nvl(t.monto,0)) monto,
       count(*) can_cheques
from CJ_MOV_PRODEP t
where t.fecha = fug_obt_fec_anterior(1)
  and t.estado = 'N'
  and ((fuj_obt_tip_caja(t.nro_caja) <> 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                  from ba_cod_referencias k
                                                 where k.dominio = 'HOR_COR_CAMARA'
                                                   and k.val_minimo = '1')) or
       (fuj_obt_tip_caja(t.nro_caja) = 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                   from ba_cod_referencias k
                                                  where k.dominio = 'HOR_COR_CAMARA'
                                                    and k.val_minimo = 'T')))
group by t.fecha, '1', fue_obt_des_refcodes('TIP_CON_PRODEP','1'),
       t.hora, t.cod_usuario, t.nro_caja, t.nro_cuenta, t.nro_documento, t.cod_mod_padre, t.cod_tra_padre,
       t.nro_referencia, null, t.cod_oficina, t.cod_oficina,
       t.cod_moneda) p
where p.ref_prodep = o.nro_boleta(+)
group by p.fecha, '1', fue_obt_des_refcodes('TIP_CON_PRODEP','1'),
       case when (nvl(p.monto,0) - nvl(o.monto,0)) <> 0 then 'S' else 'N' end, p.cod_moneda
union all
select t.fecha, '2' cod_tip_conc, fue_obt_des_refcodes('TIP_CON_PRODEP','2') des_tip_conc,
       case when (nvl(t.monto,0) - nvl(o.monto,0)) <> 0 then 'S' else 'N' end tie_difer,
       PAG_GEN.FU_OBT_MON_LOCAL mon,
       count(*) can_difer,
       sum(nvl(t.monto,0)) monto1,
       sum(nvl(o.monto,0)) monto2,
       sum((nvl(t.monto,0) - nvl(o.monto,0))) mto_difer
from CC_CHE_REMITIDOS_RES t,
(select t.nro_referencia, t.hora, t.cod_usuario, t.nro_cuenta,
        t.nro_documento, sum(nvl(t.monto,0)) monto, count(*) can_che
   from CJ_MOV_PRODEP t
  where t.fecha = pag_cal.fu_obt_fec_actual(1)
    and t.estado = 'N'
    and ((fuj_obt_tip_caja(t.nro_caja) <> 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') <= (select k.val_maximo||':00'
                                                  from ba_cod_referencias k
                                                 where k.dominio = 'HOR_COR_CAMARA'
                                                   and k.val_minimo = '1')) or
       (fuj_obt_tip_caja(t.nro_caja) = 'S' and
         ((to_char(t.fec_insercion,'hh24:mi:ss') <= (select k.val_maximo||':00'
                                                    from ba_cod_referencias k
                                                   where k.dominio = 'HOR_COR_CAMARA'
                                                     and k.val_minimo = 'T') and
           trunc(t.fec_insercion) = pag_cal.fu_obt_fec_actual(1)) or
          (to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                    from ba_cod_referencias k
                                                   where k.dominio = 'HOR_COR_CAMARA'
                                                     and k.val_minimo = 'T') and
           trunc(t.fec_insercion) < pag_cal.fu_obt_fec_actual(1)))))
    group by t.nro_referencia, t.hora, t.cod_usuario, t.nro_cuenta, t.nro_documento
union all
select t.nro_referencia, t.hora, t.cod_usuario, t.nro_cuenta,
        t.nro_documento, sum(nvl(t.monto,0)) monto, count(*) can_che
   from CJ_MOV_PRODEP t
  where t.fecha = fug_obt_fec_anterior(1)
    and t.estado = 'N'
    and ((fuj_obt_tip_caja(t.nro_caja) <> 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                  from ba_cod_referencias k
                                                 where k.dominio = 'HOR_COR_CAMARA'
                                                   and k.val_minimo = '1')) or
       (fuj_obt_tip_caja(t.nro_caja) = 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                   from ba_cod_referencias k
                                                  where k.dominio = 'HOR_COR_CAMARA'
                                                    and k.val_minimo = 'T')))
    group by t.nro_referencia, t.hora, t.cod_usuario, t.nro_cuenta, t.nro_documento) o
where t.fecha = pag_cal.fu_obt_fec_actual(1)
  and t.nro_boleta = o.nro_referencia(+)
group by t.fecha, '2', fue_obt_des_refcodes('TIP_CON_PRODEP','2'),
       case when (nvl(t.monto,0) - nvl(o.monto,0)) <> 0 then 'S' else 'N' end,
       PAG_GEN.FU_OBT_MON_LOCAL
union all
select t.fecha, '3' cod_tip_conc, fue_obt_des_refcodes('TIP_CON_PRODEP','3') des_tip_conc,
       case
         when (((nvl(t.mto_00,0) - nvl(o.mto_00,0)) <> 0) OR
               ((nvl(t.mto_24,0) - nvl(o.mto_24,0)) <> 0) OR
               ((nvl(t.mto_48,0) - nvl(o.mto_48,0)) <> 0)) then 'S'
         else 'N' end tie_difer,
       PAG_GEN.FU_OBT_MON_LOCAL||
       case
         when ((nvl(t.mto_00,0) - nvl(o.mto_00,0)) <> 0) then '-RET_00_Y_MTO'
         when ((nvl(t.mto_24,0) - nvl(o.mto_24,0)) <> 0) then '-RET_24_Y_MTO'
         when ((nvl(t.mto_48,0) - nvl(o.mto_48,0)) <> 0) then '-RET_48_Y_MTO'
         else NULL end cod_moneda,
       count(*) can_difer,
       sum(nvl(t.monto,0)) monto1,
       sum(nvl(o.monto,0)) monto2,
       sum((nvl(t.monto,0) - nvl(o.monto,0))) mto_difer
from
(select k.fecha, k.cod_oficina, k.nro_lote,
        x.nro_boleta, x.cod_ofi_origen, x.nro_referencia, x.nro_caja,
        sum(decode(decode(k.retencion,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',k.retencion)),'00',1,0)) can_00,
        sum(decode(decode(k.retencion,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',k.retencion)),'24',1,0)) can_24,
        sum(decode(decode(k.retencion,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',k.retencion)),'48',1,0)) can_48,
        count(*) cant,
        sum(decode(decode(k.retencion,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',k.retencion)),'00',k.monto,0)) mto_00,
        sum(decode(decode(k.retencion,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',k.retencion)),'24',k.monto,0)) mto_24,
        sum(decode(decode(k.retencion,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',k.retencion)),'48',k.monto,0)) mto_48,
        sum(nvl(k.monto,0)) monto
   from CC_CHE_REMITIDOS k, CC_CHE_REMITIDOS_RES x
  where k.fecha = pag_cal.fu_obt_fec_actual(1)
    and k.fecha = x.fecha
    and k.cod_oficina = x.cod_oficina
    and k.nro_lote = x.nro_lote
  group by k.fecha, k.cod_oficina, k.nro_lote, x.nro_boleta, x.cod_ofi_origen, x.nro_referencia, x.nro_caja) t,
(select z.nro_referencia, z.hora, z.cod_usuario, z.nro_cuenta, z.nro_documento,
        sum(decode(decode(z.tip_monto,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',z.tip_monto)),'00',z.monto,0)) mto_00,
        sum(decode(decode(z.tip_monto,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',z.tip_monto)),'24',z.monto,0)) mto_24,
        sum(decode(decode(z.tip_monto,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',z.tip_monto)),'48',z.monto,0)) mto_48,
        sum(nvl(z.monto,0)) monto
   from CJ_MOV_PRODEP z
  where z.fecha = pag_cal.fu_obt_fec_actual(1)
    and z.estado = 'N'
    and ((fuj_obt_tip_caja(z.nro_caja) <> 'S' and
        to_char(z.fec_insercion,'hh24:mi:ss') <= (select k.val_maximo||':00'
                                                  from ba_cod_referencias k
                                                 where k.dominio = 'HOR_COR_CAMARA'
                                                   and k.val_minimo = '1')) or
       (fuj_obt_tip_caja(z.nro_caja) = 'S' and
         ((to_char(z.fec_insercion,'hh24:mi:ss') <= (select k.val_maximo||':00'
                                                    from ba_cod_referencias k
                                                   where k.dominio = 'HOR_COR_CAMARA'
                                                     and k.val_minimo = 'T') and
           trunc(z.fec_insercion) = pag_cal.fu_obt_fec_actual(1)) or
          (to_char(z.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                    from ba_cod_referencias k
                                                   where k.dominio = 'HOR_COR_CAMARA'
                                                     and k.val_minimo = 'T') and
           trunc(z.fec_insercion) < pag_cal.fu_obt_fec_actual(1)))))
    group by z.nro_referencia, z.hora, z.cod_usuario, z.nro_cuenta, z.nro_documento
union all
select z.nro_referencia, z.hora, z.cod_usuario, z.nro_cuenta, z.nro_documento,
        sum(decode(decode(z.tip_monto,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',z.tip_monto)),'00',z.monto,0)) mto_00,
        sum(decode(decode(z.tip_monto,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',z.tip_monto)),'24',z.monto,0)) mto_24,
        sum(decode(decode(z.tip_monto,null,null,fue_obt_des_refcodes('TIP_MTO_PRODEP',z.tip_monto)),'48',z.monto,0)) mto_48,
        sum(nvl(z.monto,0)) monto
   from CJ_MOV_PRODEP z
  where z.fecha = fug_obt_fec_anterior(1)
    and z.estado = 'N'
    and ((fuj_obt_tip_caja(z.nro_caja) <> 'S' and
        to_char(z.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                  from ba_cod_referencias k
                                                 where k.dominio = 'HOR_COR_CAMARA'
                                                   and k.val_minimo = '1')) or
       (fuj_obt_tip_caja(z.nro_caja) = 'S' and
        to_char(z.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                   from ba_cod_referencias k
                                                  where k.dominio = 'HOR_COR_CAMARA'
                                                    and k.val_minimo = 'T')))
    group by z.nro_referencia, z.hora, z.cod_usuario, z.nro_cuenta, z.nro_documento) o
where t.fecha = pag_cal.fu_obt_fec_actual(1)
  and t.nro_boleta = o.nro_referencia(+)
group by t.fecha, '3', fue_obt_des_refcodes('TIP_CON_PRODEP','3'),
       case
         when (((nvl(t.mto_00,0) - nvl(o.mto_00,0)) <> 0) OR
               ((nvl(t.mto_24,0) - nvl(o.mto_24,0)) <> 0) OR
               ((nvl(t.mto_48,0) - nvl(o.mto_48,0)) <> 0)) then 'S'
         else 'N' end,
       PAG_GEN.FU_OBT_MON_LOCAL||
       case
         when ((nvl(t.mto_00,0) - nvl(o.mto_00,0)) <> 0) then '-RET_00_Y_MTO'
         when ((nvl(t.mto_24,0) - nvl(o.mto_24,0)) <> 0) then '-RET_24_Y_MTO'
         when ((nvl(t.mto_48,0) - nvl(o.mto_48,0)) <> 0) then '-RET_48_Y_MTO'
         else NULL end
union all
select p.fecha, '4' cod_tip_conc, fue_obt_des_refcodes('TIP_CON_PRODEP','4') des_tip_conc,
       case when (nvl(p.monto,0) - nvl(o.monto,0)) <> 0 then 'S' else 'N' end tie_difer,
       p.cod_moneda mon,
       count(*) can_difer,
       sum(nvl(p.monto,0)) monto1,
       sum(nvl(o.monto,0)) monto2,
       sum((nvl(p.monto,0) - nvl(o.monto,0))) mto_difer
from
(select t.nro_boleta, t.monto
   from CC_CHE_REMITIDOS_RES t
  where t.fecha = pag_cal.fu_obt_fec_proxima(1)) o,
(select t.fecha, '4' cod_tip_conc, fue_obt_des_refcodes('TIP_CON_PRODEP','4') des_tip_conc,
       t.hora, t.cod_usuario, t.nro_caja, t.nro_cuenta, t.nro_documento, t.cod_mod_padre, t.cod_tra_padre,
       t.nro_referencia ref_prodep, null nro_lote, t.cod_oficina, t.cod_oficina cod_ofi_origen,
       t.cod_moneda, sum(nvl(t.monto,0)) monto,
       count(*) can_cheques
from CJ_MOV_PRODEP t
where t.fecha = pag_cal.fu_obt_fec_actual(1)
  and t.estado = 'N'
  and ((fuj_obt_tip_caja(t.nro_caja) <> 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                  from ba_cod_referencias k
                                                 where k.dominio = 'HOR_COR_CAMARA'
                                                   and k.val_minimo = '1')) or
       (fuj_obt_tip_caja(t.nro_caja) = 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                   from ba_cod_referencias k
                                                  where k.dominio = 'HOR_COR_CAMARA'
                                                    and k.val_minimo = 'T')))
group by t.fecha, '4', fue_obt_des_refcodes('TIP_CON_PRODEP','4'),
       t.hora, t.cod_usuario, t.nro_caja, t.nro_cuenta, t.nro_documento, t.cod_mod_padre, t.cod_tra_padre,
       t.nro_referencia, null, t.cod_oficina, t.cod_oficina,
       t.cod_moneda) p
where p.fecha = pag_cal.fu_obt_fec_actual(1)
  and p.ref_prodep = o.nro_boleta(+)
group by p.fecha, '4', fue_obt_des_refcodes('TIP_CON_PRODEP','4'),
       case when (nvl(p.monto,0) - nvl(o.monto,0)) <> 0 then 'S' else 'N' end, p.cod_moneda
union all
select t.fecha, '5' cod_tip_conc, fue_obt_des_refcodes('TIP_CON_PRODEP','5') des_tip_conc,
       case when (nvl(t.monto,0) - nvl(o.monto,0)) <> 0 then 'S' else 'N' end tie_difer,
       PAG_GEN.FU_OBT_MON_LOCAL mon,
       count(*) can_difer,
       sum(nvl(t.monto,0)) monto1,
       sum(nvl(o.monto,0)) monto2,
       sum((nvl(t.monto,0) - nvl(o.monto,0))) mto_difer
  from CC_CHE_REMITIDOS_RES t,
(select t.nro_referencia, t.hora, t.cod_usuario, t.nro_cuenta,
        t.nro_documento, sum(nvl(t.monto,0)) monto, count(*) can_che
from CJ_MOV_PRODEP t
where t.fecha = pag_cal.fu_obt_fec_actual(1)
  and t.estado = 'N'
  and ((fuj_obt_tip_caja(t.nro_caja) <> 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                  from ba_cod_referencias k
                                                 where k.dominio = 'HOR_COR_CAMARA'
                                                   and k.val_minimo = '1')) or
       (fuj_obt_tip_caja(t.nro_caja) = 'S' and
        to_char(t.fec_insercion,'hh24:mi:ss') > (select k.val_maximo||':00'
                                                   from ba_cod_referencias k
                                                  where k.dominio = 'HOR_COR_CAMARA'
                                                    and k.val_minimo = 'T')))
group by t.fecha, '5', fue_obt_des_refcodes('TIP_CON_PRODEP','5'),
       t.hora, t.cod_usuario, t.nro_caja, t.nro_cuenta, t.nro_documento, t.cod_mod_padre, t.cod_tra_padre,
       t.nro_referencia, null, t.cod_oficina, t.cod_oficina,
       t.cod_moneda) o
where t.fecha = pag_cal.fu_obt_fec_proxima(1)
  and t.nro_boleta = o.nro_referencia(+)
group by t.fecha, '5', fue_obt_des_refcodes('TIP_CON_PRODEP','5'),
       case when (nvl(t.monto,0) - nvl(o.monto,0)) <> 0 then 'S' else 'N' end,
       PAG_GEN.FU_OBT_MON_LOCAL) q;

