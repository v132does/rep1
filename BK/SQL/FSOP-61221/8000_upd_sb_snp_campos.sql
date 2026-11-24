--Setear módulo
BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/

update sb_snp_campos d
   set d.ind_detalle = 'S'
 where d.cod_mensaje = 'MT506'
   and campo = '35B';

update sb_snp_campos d
   set d.ind_detalle = 'S'
 where d.cod_mensaje = 'MT506'
   and campo = '36B';

commit;