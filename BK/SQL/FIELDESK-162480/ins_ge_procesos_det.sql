Begin PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO := 1; End;
/
insert into ba_programas (COD_PROGRAMA, DESCRIPCION, COD_TIP_PROGRAMA, COD_MODULO, UBI_EJECUTABLE, UBI_FISICO, DES_DETALLADA, COD_HERRAMIENTA, OBSERVACION, OPE_MOD_CERRADO, COD_PRO_EQUIVALENTE, DOCUMENTO, UBI_MENU, INA_CIERRE)
values ('CD_LCR_CON', 'INFORME DE CONTROL LCR', 30, 1, '-', '-', 'CONSULTA DE CONTROL DE LCR', null, null, 'S', null, null, 'PROCESOS->GENERACION AUTOMATICA DE ARCHIVOS ASCII', 'N');

insert into ba_consultas (COD_CONSULTA, DESCRIPCION, TIPO, PERMISO, OBSERVACION, DET_SQL, FILTROS, COL_CORTES, COL_SUMAS)
values ('CD_LCR_CON', 'INFORME DE CONTROL LCR', 'P', null, 'CONSULTA DE CONTROL DE LCR', null, null, null, null);

insert into ba_par_consultas (COD_CONSULTA, COD_CAMPO, ALIAS, VAL_DEFECTO, TIPO, USU_INSERCION, NRO_ORDEN, TIP_VAL_DEFECTO, MODIFICABLE, OBLIGATORIO, PER_FIL_RANGO)
values ('CD_LCR_CON', 'FEC_PROCES', null, null, 'F', 'IT', 1, 'S', 'S', 'S', null);

update BA_PAR_CONSULTAS T
   set T.VAL_DEFECTO ='select ''Igual_a ''||chr(39)||to_char(max(FEC_PROCESO),''dd/mm/yyyy'')||chr(39) from IT.SV_LCR_INF'
 where T.COD_CONSULTA='CD_LCR_CON';
 
COMMIT;

UPDATE ba_consultas t
   SET t.det_sql =
'SELECT linea,
        fec_proceso,
        id_bcp,
        nro_item,
        orden_visual,
        descripcion,
        sal_guaranies,
        sal_extranjera,
        sal_total,
        sal_gua_ponderado,
        sal_ext_ponderado,
        sal_tot_ponderado
   FROM it.sv_lcr_inf
  WHERE reporta = ''S''
    AND ' || CHR(38) || 'P_FILTROS'
 WHERE t.cod_consulta = 'CD_LCR_CON';

COMMIT;

insert into ge_procesos_det (COD_PROCESO, NRO_ORDEN, DESCRIPCION, COD_PROGRAMA, OBLIGATORIO, FRECUENCIA, HOR_INICIO, HOR_FIN, ERROR, DIR_DESTINATARIO, ACTIVO, FORMATO, CLAVE, CON_COPIA, NOM_ARCHIVO, CON_CABECERA, SEP_CAMPOS, SEP_TEXTO, VAR_SUSTITUCION)
values (912, 2, 'INFORME DE CONTROL LCR', 'CD_LCR_CON', 'S', 'D', null, null, null, null, 'S', 'CSV', null, null, null, 'N', null, null, null);

update GE_PROCESOS_DET T
   set T.NOM_ARCHIVO =chr(38)||'NA'
 where T.COD_PROGRAMA='CD_LCR_CON'
 AND T.NRO_ORDEN=2;
 
update GE_PROCESOS_DET R
   set R.VAR_SUSTITUCION =CHR(38)||'NA=select '||CHR(39)||'LCR_CON'||CHR(45)||CHR(39)||'||pag_gen.fu_obt_cod_entidad||'||CHR(39)||CHR(45)||CHR(39)||'||to_char (to_date('||CHR(38)||'FEC_PROCES),''yyyymmdd'') from dual;'
 where R.COD_PROGRAMA='CD_LCR_CON'
 AND R.NRO_ORDEN=2;

COMMIT;
