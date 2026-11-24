create or replace force view it.iv_tcupmmdd_t as
select '0007'||-- cd_agencia,
       rpad(a.nro_cuenta,30,' ')||-- nu_cta_SER,
       rpad(a.cod_persona,10,' ')||-- nu_cTA,
       decode(pai_dtm.fu_obt_cod_gru_economico(A.COD_PERSONA),
              NULL,rpad(A.COD_PERSONA,10,' '),
              rpad(pai_dtm.fu_obt_cod_gru_economico(A.COD_PERSONA),10,' '))||-- nu_parent_num,
       DECODE(pai_dtm.fu_obt_cod_gru_economico(A.COD_PERSONA),
              NULL,decode(pai_dtm.fu_obt_nom_cliente(A.COD_PERSONA),
                          null,rpad(' ',10,' ') ,
                          rpad(pai_dtm.fu_obt_nom_cliente(A.COD_PERSONA),10,' ')),
       rpad(pai_dtm.fu_obt_nom_gru_economico(pai_dtm.fu_obt_cod_gru_economico(A.COD_PERSONA)),10,' '))||-- sn_parent_num,
       rpad(to_char(a.cod_modalidad),5,' ')||-- cd_tipo_cuenta,
       rpad(pai_dtm.fu_obt_nom_cliente(a.cod_persona),35,' ')||-- nb_clte_cot
       '*'CADENA
from ge_cta_clientes a
inner join ge_clientes b on(b.cod_persona=a.cod_persona)
inner join ge_cuentas c on(c.nro_cuenta=a.nro_cuenta)
where a.relacion!='P'
--and exists (select 1 from dtm_ctupmmdd x where x.nu_cta_ser=a.nro_cuenta)
;

