begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/

update bw_men_respuesta c
set  c.des_mensaje = 'Autorizacion De Operaciones: Error De Pago A Proveedores Interno'
where c.nombre = 'PRO_ERR_PRO_PAG';

update bw_men_respuestas c
set  c.des_mensaje = 'Autorizacion De Operaciones: Error De Pago A Proveedores Interno'
where c.nombre = 'PRO_ERR_PRO_PAG';


COMMIT;

