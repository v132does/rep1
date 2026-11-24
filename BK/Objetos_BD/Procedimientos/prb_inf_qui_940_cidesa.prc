CREATE OR REPLACE PROCEDURE IT.PRB_INF_QUI_940_CIDESA is
--Genera informe para cidesa en forma quincenal
v_cod_mon_local   ba_monedas.cod_moneda%type;
v_fecha_ini           date;
v_fecha_fin           date;
v_fecha               date;
-- DYDMR-8459 Mejora para generación de informe

cursor mt940 is
  select distinct a.fecha, g.fec_valor, a.tip_movimiento, a.monto, a.nro_referencia, a.nro_identificador,
         a.cod_swi_pte_solicitante, a.cod_swi_pte_beneficiario, b.nro_hoja, g.cod_moneda,
         nvl(g.nom_solicitante, g.cod_swi_pte_solicitante) nom_solictante,
         nvl(g.nom_beneficiario, g.cod_swi_pte_beneficiario) nom_beneficiario,
         g.nro_ref_externa, g.nro_referencia nro_ref_transf, 'S' existe --dydmr-10591-se obtiene el nro_referencia de la tabla ge_snp_transferencia en vez de GE_SNP_MSJ_MT940_DET
  from GE_SNP_MSJ_MT940_DET a,GE_SNP_MSJ_MT940 B, ge_snp_transferencias g
  WHERE A.FECHA between v_fecha_ini and v_fecha_fin
    AND a.fecha = g.fec_valor 
    AND a.nro_referencia = g.nro_ref_externa 
    AND g.cod_moneda=decode(B.Cod_Moneda,'PYG','GS',B.cod_moneda )
    AND A.COD_MENSAJE=B.COD_MENSAJE 
    AND substr(decode(nvl(a.cod_swi_pte_solicitante,'NONREF'),'NONREF',g.cod_swi_pte_solicitante,a.cod_swi_pte_solicitante),1,8) = substr(g.cod_swi_pte_solicitante,1,8)  

 union all
   select distinct a.fecha, g.fec_valor, a.tip_movimiento, a.monto, a.nro_referencia, a.nro_identificador,
         a.cod_swi_pte_solicitante, a.cod_swi_pte_beneficiario, b.nro_hoja, g.cod_moneda,
         nvl(g.nom_solicitante, g.cod_swi_pte_solicitante) nom_solictante,
         nvl(g.nom_beneficiario, g.cod_swi_pte_beneficiario) nom_beneficiario,
         g.nro_ref_externa, g.nro_referencia nro_ref_transf, 'S' existe --dydmr-10591-se obtiene el nro_referencia de la tabla ge_snp_transferencia en vez de GE_SNP_MSJ_MT940_DET
  from GE_SNP_MSJ_MT940_DET a,GE_SNP_MSJ_MT940 B, ge_snp_transferencias g
  WHERE A.FECHA between v_fecha_ini and v_fecha_fin
    AND a.fecha = g.fec_valor 
    AND translate(a.nro_referencia,'T 0123456789','T') is null -- Solo para campo numérico 
    AND a.nro_referencia = g.nro_referencia
    AND g.cod_moneda=decode(B.Cod_Moneda,'PYG','GS',B.cod_moneda )
    AND A.COD_MENSAJE=B.COD_MENSAJE 
    AND substr(decode(nvl(a.cod_swi_pte_solicitante,'NONREF'),'NONREF',g.cod_swi_pte_solicitante,a.cod_swi_pte_solicitante),1,8) = substr(g.cod_swi_pte_solicitante,1,8) 
 
 union all
   select distinct a.fecha, a.fecha, a.tip_movimiento, a.monto, a.nro_referencia, a.nro_identificador,
        a.cod_swi_pte_solicitante, a.cod_swi_pte_beneficiario, b.nro_hoja, decode(b.cod_moneda,'PYG','GS',b.cod_moneda ) cod_moneda,
        'OPE.GUI' nom_solictante,
        'OPE.GUI' nom_beneficiario,
        null nro_ref_externa, null nro_ref_transf, 'N' existe
  from GE_SNP_MSJ_MT940_DET a,GE_SNP_MSJ_MT940 B
  WHERE A.FECHA between v_fecha_ini and v_fecha_fin
    AND A.COD_MENSAJE=B.COD_MENSAJE
    AND not exists (Select 1 from ge_snp_transferencias g
                    where g.fec_valor = a.fecha
                      AND g.cod_moneda=decode(B.cod_moneda,'PYG','GS',B.cod_moneda )
                      AND a.nro_referencia = g.nro_ref_externa )
     AND not exists (Select 1 from ge_snp_transferencias g
                    where g.fec_valor = a.fecha
                      AND g.cod_moneda=decode(B.cod_moneda,'PYG','GS',B.cod_moneda )
                      AND translate(a.nro_referencia,'T 0123456789','T') is null
                      AND a.nro_referencia = g.nro_referencia)
  order by cod_moneda, fecha;


begin
v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
v_fecha :=pag_cal.FU_OBT_FEC_ACTUAL(1);
v_fecha_fin:=pag_cal.FU_OBT_FEC_ANTERIOR(2);--trae la ultima fecha del balance
 begin
    execute immediate 'truncate table cb_inf_cid_940_tmp';
    execute immediate 'truncate table ge_msj_mt940_tmp';
    exception when others then null;
  end;

 select to_date('01/'||to_char(v_fecha,'mm/yyyy'),'dd/mm/yyyy') into v_fecha_ini from dual;
 
     for m in mt940 loop
         --Insertamos en la Tabla Temporal
         insert into ge_msj_mt940_tmp(FECHA, TIP_MOVIMIENTO, MONTO, NRO_REFERENCIA, NRO_REF_EXTERNA,
                     NRO_IDENTIFICADOR, NOM_BENEFICIARIO, NOM_SOLICITANTE, COD_SWI_PTE_SOLICITANTE,
                     COD_SWI_PTE_BENEFICIARIO, COD_MONEDA, EXISTE, NRO_REF_TRANSFERENCIA)
          values (m.fecha, m.tip_movimiento, m.monto, m.nro_referencia, m.nro_ref_externa,
                  m.nro_identificador, m.nom_beneficiario, m.nom_solictante, m.cod_swi_pte_solicitante,
                  m.cod_swi_pte_beneficiario, m.cod_moneda, m.existe, m.nro_ref_transf);
     end loop;


   ---cuando es Quincenal
   --Cabecera SIPAP
    execute immediate 'insert into cb_inf_cid_940_tmp
    select distinct ''I''||'',''||''1007''||'',''||lpad(7,4,0)
    ||'',''||
    lpad(DECODE(c.tipo,''C'',''+'',''D'',''-'')
    ||
    TRUNC(nvl(abs(c.sal_inicial),0)),13,CHR(32))||''.''||
    substr(rpad(nvl(abs(c.sal_inicial),0) - trunc(nvl(abs(c.sal_inicial),0)),3,0),-2)
    ||'',''||
    lpad(DECODE(X.tipo,''C'',''+'',''D'',''-'')
    ||
    TRUNC(nvl(abs(nvl(x.sal_final,0)),0)),13,CHR(32))
    ||''.''||
    substr(rpad(nvl(abs(nvl(x.sal_final,0)),0) - trunc(nvl(abs(nvl(x.sal_final,0)),0)),3,0),-2)
    ||'',''||'''||to_char(v_fecha_ini,'ddmmyyyy')||'''
    ||'',''||'''||to_char(v_fecha_fin,'ddmmyyyy')||'''
    ||'',''||decode(DECODE(c.cod_MONEDA,''PYG'',''GS'',c.cod_moneda),'''||v_cod_mon_local||''',''6900'',''USD'',''6100'',''EUR'',''6300'')
    cidesa, 7 cod_bco_central,DECODE(c.cod_moneda,''PYG'',''GS'',c.cod_moneda) cod_moneda,''455'' cod_modalidad,''I'',''Q'',to_date('''||to_char(v_fecha_ini,'dd/mm/yyyy')||''',''dd/mm/yyyy'')
    from
    GE_SNP_MSJ_MT940 c,
    ( SELECT W.SAL_FINAL, W.NRO_HOJA,W.COD_MONEDA,W.FEC_INICIAL,W.TIPO
         FROM GE_SNP_MSJ_MT940 W
           WHERE w.fec_inicial between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
            AND W.NRO_HOJA IN (SELECT MAX(Z.NRO_HOJA)
              FROM GE_SNP_MSJ_MT940 Z
                 WHERE z.fec_inicial between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
                   and z.cod_moneda=W.cod_moneda

                 )) X
    where
    c.fec_inicial between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
    AND C.FEC_INICIAL= X.FEC_INICIAL
    AND C.COD_MONEDA= X.COD_MONEDA
    AND C.NRO_HOJA=1
    ';

    --Detalle SIPAP
    execute immediate 'insert into cb_inf_cid_940_tmp
    select c.tip_movimiento
    ||'',''
    ||to_char(c.fecha,''ddmmyyyy'')
    ||'',''
    ||to_char(c.fecha,''ddmmyyyy'')
    ||'',''
    ||lpad(substr(NVL(NVL(decode(c.tip_movimiento,''C'',TRIM(c.NOM_BENEFICIARIO),trim(c.nom_solicitante)),null),CHR(32)),1,20),20,CHR(32))
    ||'',''
    ||lpad(substr(NVL(c.nro_ref_transferencia,0),1,15),15,0)
    ||'',''
    ||lpad(TRUNC(decode(c.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(c.monto),ABS(c.monto)),nvl(ABS(c.monto),ABS(c.monto)))),13,0)
    ||''.''
    ||substr(rpad(decode(c.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(c.monto),ABS(c.monto)),nvl(ABS(c.monto),
    ABS(c.monto)))-TRUNC(decode(c.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(c.monto),ABS(c.monto)),nvl(ABS(c.monto),ABS(c.monto)))),3,0),-2)
    ,''7'' cod_bco_central,c.cod_moneda,455 cod_modalidad,c.tip_movimiento,''Q'',c.fecha
     from ge_msj_mt940_tmp c
     where c.fecha between to_date('''||to_char(v_fecha_ini, 'dd/mm/yyyy')||''',''dd/mm/yyyy'') and to_date('''||to_char(v_fecha_fin, 'dd/mm/yyyy')||''',''dd/mm/yyyy'')
     ';

end prb_inf_qui_940_cidesa;
/

