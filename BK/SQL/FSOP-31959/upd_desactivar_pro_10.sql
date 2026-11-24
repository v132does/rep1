Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
/

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 79; -- ENVIO MAIL CUPONES VENCIDOS

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 92; -- ENVIO MAIL BANCARD SALDO CTA TRANS

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 119; -- CALCULO DIAS MORA CAJAS SEG.

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 122; -- VALIDAR DESEMBOL PRE-APROBADOS ATM

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 123; -- ACTUALIZA NRO. TELEFONOS VIA ATM

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 160; -- COBRO AUTOMATICO DE SERVICIOS

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 165; -- REVERS. NO REALIZADAS POR CIERRE

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 301; -- ENVIO MAIL A CLIENTES PREF.

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 310; -- ENVIO MAIL POR VTO. REPO

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 313; -- REVERSO DE COBROS DE SERVICIOS

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 338; -- NOTIFICACION EXTRACTOS

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 350; -- ENVIO MAILS POR VENC FORWARD

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 360; -- GENERA DATOS CRED. DOMICILIACION

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 415; -- TASAS MARCADAMENTE SUPERIORES

update ge_procesos_det a 
set a.activo = 'N'
where a.cod_proceso = 10
and a.nro_orden = 998; -- INFORME INICIO DIA

commit;
