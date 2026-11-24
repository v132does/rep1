create or replace force view it.ov_tar_atrasos as
select distinct b.cod_persona, a.nro_cuenta
  from ta_cta_tarjetas a,
       ge_cta_clientes b,
       ge_cla_operaciones_his c
 where a.nro_cuenta = b.nro_cuenta
   and b.relacion = 'P'
   and a.estado = 'N'
   and c.cod_modulo = 5
   and c.dia_atraso > 10
   and c.fecha >= add_months(pag_cal.fu_obt_fec_pri_dia_mes_habil(5),-3)
   and c.cod_persona = b.cod_persona
   and c.nro_cuenta = b.nro_cuenta;

