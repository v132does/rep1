begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
/
insert into WF_TIP_CIRCUITOS (COD_TIP_CIRCUITO, DESCRIPCION, DETALLE, ESTADO, COD_OBJ_BASE, COD_TAR_INICIAL, USU_INSERCION, FEC_INSERCION, USU_MODIFICACION, FEC_MODIFICACION, REFERENCIA, DET_SQL, COD_PROGRAMA, COD_MODULO, COD_MODALIDAD, NOM_PAR_REFERENCIA, REF_VAL_LIMITE)
values (995, 'APROBACION ENVIO MT999 SIPAP', null, 'A', 'GE_SNP_MENSAJES', null, user, sysdate, user, sysdate, 'NRO_REFERENCIA', 'select 
		''Nro. Referencia:''||chr(9)||nro_referencia C1,
        ''Cod. Msj:''||chr(9)||chr(9)||chr(9)||cod_msj_swift C2,
        ''Fec. Valor:''||chr(9)||chr(9)||to_char(fec_valor,''dd/mm/yyyy'') C3,
        ''Monto:''||chr(9)||chr(9)||chr(9)||cod_moneda||'' ''||LTRIM(to_char(monto,''9,999,999,999,999,999.99'')) C4
  from ge_snp_mensajes
 where nro_referencia = ''&'||'REFERENCIA''', 'GMSNPEND', null, null, 'WK_NRO_REFERENCIA', null);

commit;
