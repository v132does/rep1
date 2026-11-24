Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end; 
/
update ba_consultas
set    det_sql = 'SELECT g.nro_cuenta nro_cuenta,
       g.cod_persona cod_persona,
       fue_obt_nom_persona(g.cod_persona) nombre,
       g.fecha fecha,
       g.hora hora,
       g.cod_usuario cod_usuario,
       nvl(g.cod_moneda,''USD'') cod_moneda,
       nvl(g.monto_operacion,(g.monto_total-g.monto_acumulado)) monto_operacion,
       g.monto_loa monto_loa,
       g.monto_acumulado monto_acumulado,
       g.monto_total monto_total,
       g.cod_usu_autorizador cod_usu_autorizador,
       g.fec_hor_autorizacion fec_hor_autorizacion,
       decode(g.estado,''S'',''Solicitado'',''C'',''Confirmado'',''A'',''Rechazado'') estado,
       g.observacion observacion
  FROM ge_aut_umbral g
 WHERE &'||'P_FILTROS
 ORDER BY 4,5'
where  cod_consulta = 'CD_AUT_UMB';

insert into BA_PAR_CONSULTAS (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_AUT_UMB', 'COD_MONEDA', 'g', null, 'F', 4, 'V', 'S', 'N', 'S');

commit;
