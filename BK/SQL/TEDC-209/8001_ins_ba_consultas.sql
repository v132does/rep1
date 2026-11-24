BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CD_DEP_RET', 'Registro de RETENCIONES recibidos en el TED', null, 'G', 'INFORMATICA-INFORMATICA', 'En este reporte se puede visualizar todas los Depósitos con reten en el TED.', 'select a.nro_cuenta,
       a.cod_modulo,
       a.cod_modalidad,
       a.cod_oficina,
       a.nro_documento,
       a.cod_retencion,
       a.fec_final,
       a.cod_moneda,
       a.monto,
       a.fec_inicio,
       a.cod_usuario,
       a.cod_ofi_origen,
       a.liberado,
       a.detallado,
       a.lib_posterior,
       a.usu_insercion,
       a.fec_insercion,
       a.usu_modificacion,
       a.fec_modificacion,
       a.sal_retenido,
       a.lib_anticipada
  from (select nro_cuenta,
       cod_modulo,
       cod_modalidad,
       cod_oficina,
       nro_documento,
       cod_retencion,
       fec_final,
       cod_moneda,
       monto,
       fec_inicio,
       cod_usuario,
       cod_ofi_origen,
       liberado,
       detallado,
       lib_posterior,
       usu_insercion,
       fec_insercion,
       usu_modificacion,
       fec_modificacion,
       sal_retenido,
       lib_anticipada
  from ah_retenciones t) a
 where '||chr(38)||'P_FILTROS', '   A.FECHA = TO_DATE(''24/08/2022'',''DD/MM/YYYY'')', null, null, 'IT', to_date('12-12-2024 14:19:51', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('09-01-2025 14:49:15', 'dd-mm-yyyy hh24:mi:ss'));

commit;
