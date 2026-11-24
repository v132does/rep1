BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
update pr_cta_garantias a
set   a.cod_persona=9525191
where a.nro_garantia=3346
and   a.nro_cuenta=2324899
and   a.cod_persona is null
and   a.cod_garantia in (32,33,34,39,40,41);

update pr_cta_garantias a
set   a.cod_persona=8156281
where a.nro_garantia=4233
and   a.nro_cuenta=702163300023
and   a.cod_persona is null
and   a.cod_garantia in (32,33,34,39,40,41);

update pr_cta_garantias a
set   a.cod_persona=8598060
where a.nro_garantia=4323
and   a.nro_cuenta=702163700029
and   a.cod_persona is null
and   a.cod_garantia in (32,33,34,39,40,41);

update pr_cta_garantias a
set   a.cod_persona=9015900
where a.nro_garantia=3068
and   a.nro_cuenta=2305422
and   a.cod_persona is null
and   a.cod_garantia in (32,33,34,39,40,41);

update pr_cta_garantias a
set   a.cod_persona=8221561
where a.nro_garantia=3335
and   a.nro_cuenta=2321250
and   a.cod_persona is null
and   a.cod_garantia in (32,33,34,39,40,41);

update pr_cta_garantias a
set   a.cod_persona=8909946
where a.nro_garantia=3360
and   a.nro_cuenta=2354796
and   a.cod_persona is null
and   a.cod_garantia in (32,33,34,39,40,41);

update pr_cta_garantias a
set   a.cod_persona=9576916
where a.nro_garantia=3394
and   a.nro_cuenta=2343422
and   a.cod_persona is null
and   a.cod_garantia in (32,33,34,39,40,41);

update pr_cta_garantias a
set   a.cod_persona=8344066
where a.nro_garantia=3352
and   a.nro_cuenta=2327412
and   a.cod_persona is null
and   a.cod_garantia in (32,33,34,39,40,41);

commit;
