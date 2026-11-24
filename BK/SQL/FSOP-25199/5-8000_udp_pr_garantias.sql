BEGIN  PRE_INI_APLICACION;  PAE_CNF.G_COD_MODULO := 1; END;
/
update pr_garantias a
set a.tipo='C'
where a.estado='C'
and   a.tipo='A'
and   a.cod_garantia in (32,33,34,38,39,40,41) ; --Cerrar garantias FOGAPY / FOGAMU 
commit; 
