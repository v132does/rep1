BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 2; END;
/
delete from pr_cta_garantias t
where t.nro_cuenta in (612360805583,612361311456,612360805591)
and   t.nro_garantia in (5508,5504,5502); 

delete ov_cta_garantias a
where a.nro_cuenta=6115002574
and a.nro_garantia=3337 ; 

commit;
