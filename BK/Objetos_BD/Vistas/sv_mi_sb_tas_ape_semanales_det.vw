create or replace force view it.sv_mi_sb_tas_ape_semanales_det as
select s.corcod corcod, s.cod_modulo, s.cod_modalidad, s.nro_cuenta nro_cuenta, s.entcod entcod, s.codcta codcta,
       s.cod_moneda  cod_moneda, s.acod acod, to_char(s.fec_apertura, 'DDMMYYYY') fec_apertura, s.fec_apertura fecha,
       trim(replace(to_char(s.val_tas_nominal, '00.99'), '.', '')) val_tas_nominal,
       trim(to_char(round(s.monto, 0), '999999999999999')) || '00' monto,
       lpad(trim(to_char(s.periodo, '9999')), 4, '0') periodo, s.tasreg tasreg,
       -- En caso de CALL MONEY PERIODO=30. CB. 17/03/2014. DYDMR-297.
       case when s.cod_modulo = 10 and s.cod_modalidad = 109 then
          trim(replace(to_char(fus_obt_tae_tasa(S.VAL_TAS_NOMINAL,30,S.TASREG), '00.99'),'.',''))
       else
          trim(replace(to_char(fus_obt_tae_tasa(S.VAL_TAS_NOMINAL,S.PERIODO,S.TASREG), '00.99'),'.',''))
       end tae  from mi_sb_tas_ape_semanales s
 where (s.cod_modulo = 6 or (s.cod_modulo = 3 and s.cod_modalidad <> 31)or s.cod_modulo =  10) -- BBVANOR-90
   and not exists(select 1 from ah_cta_certificados cda
                   where cda.nro_cuenta= s.nro_cuenta
                     and cda.cod_modalidad = s.cod_modalidad
                     and cda.estado = 'C'
                     and cda.fec_apertura = cda.fec_pago ) --- DE-2595
   and not exists(select 1 from pr_cta_prestamos pp
                   where pp.nro_cuenta= s.nro_cuenta
                     and pp.cod_modalidad = s.cod_modalidad
                     and pp.estado = 'N'
                     and pp.fec_cancelacion = pp.fec_inicio ) --- DE-2595
  and s.fec_insercion > trunc(SYSDATE)-180
UNION ALL
select a.corcod , a.cod_modulo, a.cod_modalidad, a.nro_cuenta nro_cuenta, a.entcod , a.codcta ,
       a.cod_moneda , a.acod , to_char(a.fec_apertura, 'DDMMYYYY') fec_apertura, a.fec_apertura fecha,
       trim(replace(to_char(round(nvl(a.val_tas_nominal, 0),2), '00.99'), '.', '')) val_tas_nominal,
       trim(to_char(round(a.monto, 0), '999999999999999'))|| '00' monto,
       lpad(trim(to_char(a.periodo, '9999')), 4, '0') periodo ,a.tasreg,
       trim(replace(to_char(fus_obt_tae_tasa(round(nvl(a.val_tas_nominal, 0),2),a.PERIODO,a.TASREG),'00.99'),'.','')) tae
  from mi_sb_tas_ape_semanales a
 where (a.cod_modulo = 5) or (a.cod_modulo = 3 and a.cod_modalidad = 31)
 and a.fec_insercion > trunc(SYSDATE)-180
UNION ALL
select m.corcod , m.cod_modulo, m.cod_modalidad, m.nro_cuenta nro_cuenta, m.entcod , m.codcta ,
       m.cod_moneda , m.acod , to_char(m.fec_apertura, 'DDMMYYYY') fec_apertura, m.fec_apertura fecha,
       trim(replace(to_char(round(nvl(m.VAL_TAS_NOMINAL,0),2), '00.99'), '.', '')) val_tas_nominal,
       trim(to_char(round(m.monto, 0), '999999999999999'))|| '00'  monto,
       lpad(trim(to_char(m.periodo, '9999')), 4, '0') periodo ,m.tasreg,
       trim(replace(to_char(pas_bcp.FU_OBT_TAE(nvl(m.VAL_TAS_NOMINAL, 0),m.periodo),'00.99'),'.','')) tae
  from mi_sb_tas_ape_semanales m
 where m.cod_modulo = 4
  and  m.fec_insercion > trunc(SYSDATE)-180
;

