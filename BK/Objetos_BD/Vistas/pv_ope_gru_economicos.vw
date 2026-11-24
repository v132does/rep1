create or replace force view it.pv_ope_gru_economicos as
select b.cod_gru_economico cod_gru_economico,
       b.cod_persona,
       fue_obt_nom_persona(b.cod_persona) nom_completo,
       a.nro_linea,
       nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, ax.cod_moneda, a.monto), 0) monto,
       nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda,ax.cod_moneda,a.mto_aplicado),0) mto_aplicado,
       FUG_OBT_TOT_OPE_ESP_SOL(b.cod_persona, ax.cod_moneda, a.nro_linea) mto_ope_especifica,
       pag_gen.fu_con_mon_a_moneda(a.cod_moneda, nvl(ax.cod_moneda, a.cod_moneda),(nvl(a.monto, 0) - nvl(a.mto_aplicado, 0))) Saldo,
       'S' apl_linea, a.fec_vencimiento, fue_obt_des_refcodes('EST_LIMITE', a.estado) est_linea
  from pr_lineas a,
       ge_clientes b,
       (select distinct aa.cod_gru_economico, aa.cod_moneda
          from pr_gru_lineas aa) ax
 where a.cod_persona = b.cod_persona
   and b.cod_gru_economico = ax.cod_gru_economico
   and a.estado in ('A','B','P')
   and exists
 (select 1
          from pr_gru_lin_aplicaciones p
         where p.nro_linea = a.nro_linea
           and p.cod_gru_economico = ax.cod_gru_economico)
union all
---Clientes con lineas individuales NO APLICADAS a las lineas globales
select b.cod_gru_economico cod_gru_economico,
       b.cod_persona,
       fue_obt_nom_persona(b.cod_persona) nom_completo,
       a.nro_linea,
       nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, nvl(ax.cod_moneda,a.cod_moneda), a.monto), 0) monto,
       nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, nvl(ax.cod_moneda,a.cod_moneda), a.mto_aplicado), 0) mto_aplicado,
       CASE
        WHEN nvl(a.nro_linea,0) != 0 THEN
           fug_obt_tot_ope_esp_sol(b.cod_persona, nvl(ax.cod_moneda,a.cod_moneda), a.nro_linea)
        else
           fug_obt_tot_ope_especifica(a.cod_persona, nvl(ax.cod_moneda,a.cod_moneda))
        END  mto_ope_especifica,
       pag_gen.fu_con_mon_a_moneda(a.cod_moneda, nvl(ax.cod_moneda,a.cod_moneda),(nvl(a.monto, 0) - nvl(a.mto_aplicado, 0))) Saldo,
       'N' apl_linea, a.fec_vencimiento, fue_obt_des_refcodes('EST_LIMITE', a.estado) est_linea
  from pr_lineas a,
       ge_clientes b,
       (select distinct aa.cod_gru_economico, aa.cod_moneda
          from pr_gru_lineas aa) ax
 where a.cod_persona = b.cod_persona
   and b.cod_gru_economico = ax.cod_gru_economico(+)
   and a.estado in ('A','B')
   and not exists
 (select 1
          from pr_gru_lin_aplicaciones p
         where p.nro_linea = a.nro_linea
           and p.cod_gru_economico = ax.cod_gru_economico)
union all
select b.cod_gru_economico cod_gru_economico,
       b.cod_persona,
       fue_obt_nom_persona(b.cod_persona) nom_completo,
       a.nro_linea,
       nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, nvl(ax.cod_moneda,a.cod_moneda), a.monto), 0) monto,
       nvl(pag_gen.fu_con_mon_a_moneda(a.cod_moneda, nvl(ax.cod_moneda,a.cod_moneda), a.mto_aplicado), 0) mto_aplicado,
       CASE
        WHEN nvl(a.nro_linea,0) != 0 THEN
           fug_obt_tot_ope_esp_sol(b.cod_persona, nvl(ax.cod_moneda,a.cod_moneda), a.nro_linea)
        else
           fug_obt_tot_ope_especifica(a.cod_persona, nvl(ax.cod_moneda,a.cod_moneda))
        END  mto_ope_especifica,
       pag_gen.fu_con_mon_a_moneda(a.cod_moneda, nvl(ax.cod_moneda,a.cod_moneda),(nvl(a.monto, 0) - nvl(a.mto_aplicado, 0))) Saldo,
       'N' apl_linea, a.fec_vencimiento, fue_obt_des_refcodes('EST_LIMITE', a.estado) est_linea
  from pr_lineas a,
       ge_clientes b,
       (select distinct aa.cod_gru_economico, aa.cod_moneda
          from pr_gru_lineas aa) ax
 where a.cod_persona = b.cod_persona
   and b.cod_gru_economico = ax.cod_gru_economico(+)
   and a.estado in ('P')
   and not exists
 (select 1
          from pr_gru_lin_aplicaciones p
         where p.nro_linea = a.nro_linea
           and p.cod_gru_economico = ax.cod_gru_economico)
   and not exists (select 1 from pr_lineas p where p.cod_persona = a.cod_persona and p.estado in ('A', 'B'))
union all
---Clientes SIN lineas individuales por defecto APLICADAS a las lineas globales
Select a.cod_gru_economico cod_gru_economico,
       a.cod_persona,
       fue_obt_nom_persona(a.cod_persona) nom_completo,
       0 nro_linea,
       0 monto,
       0 mto_aplicado,
       fug_obt_tot_ope_especifica(a.cod_persona, ax.cod_moneda) mto_ope_especifica,
       0 saldo,
       'N' apl_linea, null fec_vencimiento, null est_linea
  from ge_clientes a,
       (select distinct aa.cod_gru_economico, aa.cod_moneda
          from pr_gru_lineas aa) ax
 where a.cod_gru_economico = ax.cod_gru_economico(+)
   and (exists (Select 1
                  from pr_lineas bx
                 where bx.cod_persona = a.cod_persona
                   and bx.estado not in ('A', 'B','P'))
         or not exists
        (Select 1 from pr_lineas li where li.cod_persona = a.cod_persona))
   and not exists (Select 1
                     from pr_lineas pe
                    where pe.cod_persona = a.cod_persona
                      and pe.estado in ('A', 'B','P'))
;

