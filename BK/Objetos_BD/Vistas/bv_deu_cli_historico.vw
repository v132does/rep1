create or replace force view it.bv_deu_cli_historico as
select to_char(h.fecha, 'yyyy') año,
       to_char(h.fecha, 'mm') mes,
       h.cod_persona cod_persona,
       fue_obt_nom_persona(h.cod_persona) nombre,
       r.significado cat_riesgo,
       h.cat_sistema cat_sistema,
       h.tot_deu_real tot_deu_real,
       h.tot_deu_sistema tot_deu_sistema,
       h.tot_deu_contingente tot_deu_contingente,
       h.tot_deu_con_sistema tot_deu_con_sistema,
       nvl(h.tot_deu_real, 0) + nvl(h.tot_deu_sistema, 0) +
       nvl(h.tot_deu_contingente, 0) + nvl(h.tot_deu_con_sistema, 0) rie_dir_total,

       trunc(((nvl(h.tot_deu_real, 0) + nvl(h.tot_deu_contingente, 0)) /
             decode(nvl(h.tot_deu_real, 0) + nvl(h.tot_deu_sistema, 0) +
                     nvl(h.tot_deu_contingente, 0) +
                     nvl(h.tot_deu_con_sistema, 0),
                     0,
                     1,
                     (nvl(h.tot_deu_real, 0) + nvl(h.tot_deu_sistema, 0) +
                     nvl(h.tot_deu_contingente, 0) +
                     nvl(h.tot_deu_con_sistema, 0)))) * 100) por_BBVA,

       nvl(h.tot_deu_codeudoria, 0) tot_deu_codeudoria,
       nvl(h.tot_deu_cod_sistema, 0) tot_deu_cod_sistema,
       (nvl(h.tot_deu_real, 0) + nvl(h.tot_deu_sistema, 0) +
       nvl(h.tot_deu_contingente, 0) + nvl(h.tot_deu_con_sistema, 0) +
       nvl(h.tot_deu_codeudoria, 0) + nvl(h.tot_deu_cod_sistema, 0)) rie_total
  from ge_clientes_his h, ba_cod_referencias r
 where h.fecha =
       (select max(fecha)
          from ge_clientes_his f
         where h.cod_persona = f.cod_persona
           and to_char(f.fecha, 'mmyyyy') = to_char(h.fecha, 'mmyyyy'))
 and h.cat_riesgo = r.val_minimo
 and r.dominio = 'CAT_RIESGO'
 group by to_char(h.fecha, 'yyyy'),
          to_char(h.fecha, 'mm'),
          h.cod_persona,
          h.cod_persona,
          r.significado,
          h.cat_sistema,
          h.tot_deu_real,
          h.tot_deu_sistema,
          h.tot_deu_contingente,
          h.tot_deu_con_sistema,
          tot_deu_cod_sistema,
          tot_deu_codeudoria,
          tot_deu_real,
          tot_deu_sistema
 order by 1;

