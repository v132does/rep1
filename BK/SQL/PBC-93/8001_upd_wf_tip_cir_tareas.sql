BEGIN pre_ini_aplicacion; pae_cnf.G_COD_MODULO := 1; END; 
/      
update wf_tip_cir_tareas c 
set c.descripcion = 'VERIFICAR CUENTA POR ACREDITACIÓN DE CUPONES VENCIDOS'
       c.detalle = 'Verificar saldo o estado de cuenta de Crédito o del CDA.'
where c.cod_tip_circuito = 14
and c.cod_tip_tarea = 0;

commit;
/
update wf_tip_cir_tareas c 
set c.descripcion = 'VERIFICAR CUENTA POR ACREDITACIÓN DE CUPONES VENCIDOS'
where c.cod_tip_circuito = 14
and c.cod_tip_tarea = 1;

commit;





