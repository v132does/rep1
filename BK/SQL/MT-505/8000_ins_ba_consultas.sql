BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1; END;
/
insert into ba_consultas (COD_CONSULTA, DESCRIPCION, COD_USUARIO, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION)
values ('CD_CHQ_TED', 'Registro de cheques recibidos en el TED', null, 'G', 'INFORMATICA-INFORMATICA', 'En este reporte se puede visualizar todas los  cheques ingresados en el TED.', 'select a.id_dep_cheque,
       a.nro_documento,
       a.tip_documento,
       a.nom_completo,
       a.cod_lote,
       a.nro_transaccion,
       a.atm_id,
       a.cod_cheque,
       a.cod_banco,
       a.cta_libradora,
       a.nro_cheque,
       a.cod_moneda,
       a.cod_persona,
       a.tip_transaccion,
       a.nro_cuenta,
       a.monto_cheque,
       a.nro_solicitud,
       a.estado,
       a.fecha,
       a.est_cheque
  from (select a.id_dep_cheque,
               a.nro_documento,
               a.tip_documento,
               a.nom_completo,
               a.cod_lote,
               a.nro_transaccion,
               a.atm_id,
               a.cod_cheque,
               a.cod_banco,
               a.cta_libradora,
               a.nro_cheque,
               a.cod_moneda,
               a.cod_persona,
               a.tip_transaccion,
               a.nro_cuenta,
               a.monto_cheque,
               a.nro_solicitud,
               a.estado,
               trunc(a.fecha) fecha,
               a.est_cheque
          from it.cj_dep_chq_atm_reg a) a
 where '||chr(38)||'P_FILTROS', '   A.FECHA = TO_DATE(''24/08/2022'',''DD/MM/YYYY'')', null, null, 'IT', to_date('12-12-2024 14:19:51', 'dd-mm-yyyy hh24:mi:ss'), 'IT', to_date('09-01-2025 14:49:15', 'dd-mm-yyyy hh24:mi:ss'));

commit;
