create or replace force view it.iv_dinupmmdd as
select a.nro_cuenta nu_cta_clte,
       b.cod_persona nu_clte,
       decode(c.cod_gru_economico,
              null,b.cod_persona,
              c.cod_gru_economico) nu_grupo_clte,
       decode(d.descripcion,
              null,e.nom_completo,
              d.descripcion) nb_sn_cliente,
       a.cod_modalidad cd_tp_cta,
       f.fec_apertura fh_inicio,
       f.fec_vencimiento fh_fin
from ah_cta_certificados a
inner join ge_cta_clientes b on(a.nro_cuenta=b.nro_cuenta)
inner join ge_clientes c on(b.cod_persona=c.cod_persona)
left outer join ge_gru_economicos d on(c.cod_gru_economico=d.cod_gru_economico)
inner join ba_personas e on(e.cod_persona=b.cod_persona)
inner join ge_cuentas f on(a.nro_cuenta=f.nro_cuenta);

