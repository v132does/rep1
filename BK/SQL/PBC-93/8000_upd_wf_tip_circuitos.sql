BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/
update wf_tip_circuitos c
set c.descripcion = 'VERIFICACION DE CUENTA POR ACREDITACIÓN DE CUPONES VENCIDOS',
    c.detalle = 'Verificación del estado o saldo de la cuenta de crédito o del CDA.'
where c.cod_tip_circuito = 14;

commit;
