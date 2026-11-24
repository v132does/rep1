create or replace force view it.gv_con_ofertas as
select 'PRESTAMO' oferta,
       a.fec_ini_oferta fec_inicio,
       a.fec_fin_oferta fec_fin,
       a.mon_pre_aprobado monto,
       a.estado,
       a.cod_persona
  from pr_pre_aprobados a
 where a.estado in ('C', 'G')
union
select 'TARJETA' oferta,
       b.fec_ini_oferta fec_inicio,
       b.fec_fin_oferta fec_fin,
       b.mon_lin_pre_aprobado monto,
       b.estado,
       b.cod_persona
  from ta_lin_pre_aprobado b
  where b.estado in ('C', 'G');

