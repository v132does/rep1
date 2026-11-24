BEGIN pre_ini_aplicacion; END;
/
delete 
from sb_snp_mensajes m
where m.nro_referencia in (
select nro_referencia from ge_snp_mensajes
where fec_valor = '28/06/2024'
and cod_msj_swift in (940));

delete 
from ge_snp_mensajes
where fec_valor = '28/06/2024'
and cod_msj_swift in (940);

commit;
