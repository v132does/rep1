create or replace force view it.ov_cli_resto as
select distinct cod_persona
from (
  select distinct c.cod_persona,
         c.tot_deu_real + c.tot_deu_contingente as riesgo
    from ge_cta_clientes a,
         pr_cta_prestamos b,
         ge_cla_operaciones c
   where a.nro_cuenta = b.nro_cuenta
     and a.relacion = 'P'
     and b.estado not in ('N','I')
     and c.cod_persona = a.cod_persona
     and c.cod_modulo = 6
     and b.cod_sec_credito in (994,992,902,804,802,806,792,610,616,612,614,608,606,604,602,
                               504,502,406,402,404,312,310,314,318,316,308,302,304,306,204,
                               202,206,208,110,106,108,102,104,112)
union
  select distinct d.cod_persona,
         d.tot_deu_real + d.tot_deu_contingente as riesgo
    from ge_cta_clientes a,
         cc_cta_corrientes b,
         cc_sobregiros_res c,
         ge_cla_operaciones d
   where a.nro_cuenta = b.nro_cuenta
     and c.nro_cuenta = b.nro_cuenta
     and d.cod_persona = a.cod_persona
     and d.cod_modalidad = 41
     and a.relacion = 'P'
     and c.can_dias > 31
) x
group by x.cod_persona having sum(riesgo) > fug_obt_pardinamico('MTO_RES_COB_TERCERIZADAS')
union
/*Resto_grupo*/
  select distinct e.cod_persona
    from ge_gru_economicos d,
         ge_clientes e
   where d.cod_gru_economico = e.cod_gru_economico
     and (d.tot_deu_real + d.tot_deu_contingente) >= fug_obt_pardinamico('MTO_RES_COB_TERCERIZADAS')
     and exists (select distinct a.cod_persona
                   from ge_cta_clientes a,
                        pr_cta_prestamos b
                  where e.cod_persona = a.cod_persona
                    and b.nro_cuenta = a.nro_cuenta
                    and a.relacion = 'P'
                    and b.estado not in ('N','I')
                    and b.cod_sec_credito in (994,992,902,804,802,806,792,610,616,612,614,608,606,604,602,504,
                                              502,406,402,404,312,310,314,318,316,308,302,304,306,204,202,206,
                                              208,110,106,108,102,104,112)
                union
                 select distinct a.cod_persona
                   from ge_cta_clientes a,
                        cc_cta_corrientes b,
                        cc_sobregiros_res c
                  where e.cod_persona = a.cod_persona
                    and a.nro_cuenta = b.nro_cuenta
                    and c.nro_cuenta = a.nro_cuenta
                    and a.cod_modalidad = 41
                    and a.relacion = 'P'
                    and c.can_dias > 31
                )
union
  select distinct a.cod_persona
    from ge_clientes a,
         ba_usuarios b,
         ba_oficinas c,
         ba_gru_oficinas d
   where b.cod_usuario = a.cod_usu_oficial
     and c.cod_oficina = b.cod_oficina
     and d.cod_gru_oficina = c.cod_gru_oficina
     and c.cod_oficina in (21,11);

