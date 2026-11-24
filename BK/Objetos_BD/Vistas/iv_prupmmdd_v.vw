create or replace force view it.iv_prupmmdd_v as
select '0007'||-- cd_agencia,
       rpad(to_char(a.cod_modalidad),5,' ')|| --cd_tipo_cuenta
       rpad(a.descripcion,35,' ')|| --nb_tipo_cuenta
       '000'||--nu_max_sufijo
       '*'CADENA

from ge_modalidades a
where  a.cod_modalidad in(31,32,33,41)
;

