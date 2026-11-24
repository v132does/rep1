create or replace force view it.wv_cla_clientes as
select cc.cod_persona, cc.nom_cliente,
       cc.cod_per_vinculada, cc.nom_empresa,
       cc.tip_clave, cc.tipo, cc.estado, cc.nro_telefono
from
(select c.cod_persona,
       substr( fue_obt_nom_persona(c.cod_persona),1,200) nom_cliente,
       c.cod_per_vinculada,
       case
    when c.cod_per_vinculada is null then ' '
    else  substr(fue_obt_nom_persona(c.cod_per_vinculada),1,200)
       end nom_empresa,
       decode(c.tip_clave, 'A', 'Acceso', 'T', 'Transaccional') tip_clave,
       ' ' tipo,
       fue_obt_des_refcodes('EST_CLAVE', c.est_clave) estado,
       null as Nro_telefono
 from bw_ope_claves c

union all
select c.cod_persona,
       substr( fue_obt_nom_persona(c.cod_persona),1,200) nom_cliente,
       c.cod_per_vinculada,
       case
    when c.cod_per_vinculada is null then  ' '
    else  substr(fue_obt_nom_persona(c.cod_per_vinculada),1,200)
       end nom_empresa,
       'Token' tip_clave,
       fue_obt_des_refcodes('TIP_CLA_OTP', c.tipo) tipo,
       fue_obt_des_refcodes('EST_CLA_OTP', c.estado) estado,
       null as Nro_telefono
  from bw_otp_seriales c
 where  (c.tipo ='V' or c.tipo='F') and c.cod_persona is not null
union all
select d.cod_persona,
       substr( fue_obt_nom_persona(d.cod_persona),1,200) nom_cliente,
       d.cod_per_vinculada,
       case
    when d.cod_per_vinculada is null then  ' '
    else  substr(fue_obt_nom_persona(d.cod_per_vinculada),1,200)
       end nom_empresa,
       'Token Digital' tip_clave,
       fue_obt_des_refcodes('TIP_CLA_SOFT', d.tipo) tipo,
       fue_obt_des_refcodes('EST_CLA_SOFT', d.estado) estado,
       e.nro_tel_enrolado as Nro_telefono
  from bw_otp_seriales d, BW_SOF_SERIALES e
 where d.tipo ='S' and d.cod_persona is not null
 and d.cod_persona= e.cod_persona
 and e.dominio='RETAILPY'
 union all
 select e.cod_persona,
       substr( fue_obt_nom_persona(e.cod_persona),1,200) nom_cliente,
       d.cod_per_vinculada,
       case
       when d.cod_per_vinculada is null then  ' '
       else  substr(fue_obt_nom_persona(d.cod_per_vinculada),1,200)
       end nom_empresa,
       'Token Digital' tip_clave,
       'Soft Token' as tipo,
       fue_obt_des_refcodes('EST_CLA_SOFT', d.estado) estado,
       f.telefono as Nro_telefono
  from BW_SOF_EMPRESAS d, BW_SOF_SERIALES e, bw_td_configuraciones f
 where D.ESTADO='A'
 and d.sof_ser_id=e.id
 and e.dominio='CASHPY'
 and d.cod_per_vinculada= f.cod_persona
 and e.cod_persona= f.cod_per_vinculo

 ) cc;

