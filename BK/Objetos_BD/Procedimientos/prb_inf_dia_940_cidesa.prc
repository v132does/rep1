CREATE OR REPLACE PROCEDURE IT.PRB_INF_DIA_940_CIDESA is
--Genera informe para cidesa en forma diaria del MT940 SIPAP--
v_cod_mon_local   ba_monedas.cod_moneda%type;
v_fecha           date;
v_fec_anterior    date;
v_nom_solicitante varchar2(100);
v_nom_beneficiario varchar2(100);
v_nro_ref_externa varchar2(100);
v_cod_moneda  varchar2(10);
v_cod_mon_ori varchar2(10);
v_existe varchar2(1):='N';
v_nro_ref_transferencia number(18,2);
cursor mt940 is
  select a.fecha,a.tip_movimiento,a.monto,a.nro_referencia,
  a.nro_identificador,a.cod_swi_pte_solicitante,a.cod_swi_pte_beneficiario,
  b.nro_hoja,b.cod_moneda
  from GE_SNP_MSJ_MT940_DET a,GE_SNP_MSJ_MT940 B
  WHERE  A.FECHA=v_fecha     --- DYDMR-8459 OMM MAR/2018
  AND A.COD_MENSAJE=B.COD_MENSAJE
    order by b.cod_moneda;

begin
v_cod_mon_local := pag_gen.FU_OBT_MON_LOCAL;
v_fecha:=null;
v_fec_anterior:=null;
    begin
      execute immediate 'truncate table cb_inf_cid_940_tmp';
      execute immediate 'truncate table ge_msj_mt940_tmp';
      exception when others then null;
    end;
    --Busca la fecha actual del balance cerrado
    select max(fecha) into v_fecha from cb_sal_oficinas_dia d;
    select pag_cal.FU_OBT_FEC_ANT_HAB (v_fecha,31,1) into v_fec_anterior from dual;

        for m in mt940 loop
            v_existe:='N';
            v_nom_solicitante:=null;
            v_nom_beneficiario:=null;
            v_nro_ref_externa:=null;
            v_cod_moneda:=null;
            v_existe:=null;
            v_nro_ref_transferencia:=null;
            if m.cod_moneda = 'PYG' then
               v_cod_mon_ori := 'GS' ;
            else
               v_cod_mon_ori := m.cod_moneda ;
            end if ;
            begin
             select nvl(a.nom_solicitante,a.cod_swi_pte_solicitante) nom_solictante,nvl(a.nom_beneficiario,a.cod_swi_pte_beneficiario)  nom_beneficiario,a.nro_ref_externa,a.cod_moneda,'S',a.nro_referencia
                into v_nom_solicitante, v_nom_beneficiario,v_nro_ref_externa,v_cod_moneda,v_existe,v_nro_ref_transferencia
                 from ge_snp_transferencias a
                 where a.fec_valor = v_fecha --a.Fec_Ingreso= v_fecha (Debe ser Fecha Valor)"26/02/2014"
                  and a.cod_moneda= v_cod_mon_ori ---DYDMR-8459 OMM MAR/2018   decode(m.cod_moneda,'PYG','GS',m.cod_moneda )
                  and (to_char(a.nro_referencia) = m.nro_referencia  OR 
                       a.nro_ref_externa= m.nro_referencia )
                  and rownum=1;
            exception
              when no_data_found then
                   v_existe:='N';
               when too_many_rows then
                    v_existe:='N';
                when others then
                     v_existe:='N';
            end;
               --Insertamos en la Tabla Temporal
               insert into ge_msj_mt940_tmp(FECHA,TIP_MOVIMIENTO,MONTO,NRO_REFERENCIA,
                  NRO_REF_EXTERNA,NRO_IDENTIFICADOR,NOM_BENEFICIARIO,NOM_SOLICITANTE,
                  COD_SWI_PTE_SOLICITANTE,COD_SWI_PTE_BENEFICIARIO,COD_MONEDA,EXISTE,NRO_REF_TRANSFERENCIA)
               values (m.fecha,m.tip_movimiento,m.monto,m.nro_referencia,
                  v_nro_ref_externa,m.nro_identificador,nvl(v_nom_beneficiario,'OPE.GUI'),NVL(v_nom_solicitante,'OPE.GUI'),
                  m.cod_swi_pte_solicitante,m.cod_swi_pte_beneficiario,nvl(v_cod_moneda, v_cod_mon_ori),v_existe,v_nro_ref_transferencia);

       end loop;


    --Cabecera SIPAP
    -- SPI 3382 PN 07/05/2014: Se agrega el to_number a la busqueda del saldo final, debido a que consideraba a la hoja 9 como mayor al ser un campo varchar2
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
    TRUNC(nvl(abs(nvl(X.sal_final,0)),0)),13,CHR(32))
    ||''.''||
    substr(rpad(nvl(abs(nvl(X.sal_final,0)),0) - trunc(nvl(abs(nvl(X.sal_final,0)),0)),3,0),-2)
    ||'',''||'''||to_char(v_fecha,'ddmmyyyy')||'''
    ||'',''||'''||to_char(v_fecha,'ddmmyyyy')||'''
    ||'',''||decode(DECODE(c.cod_MONEDA,''PYG'',''GS'',c.cod_moneda),'''||v_cod_mon_local||''',''6900'',''USD'',''6100'',''EUR'',''6300'')
    cidesa, 7 cod_bco_central,DECODE(c.cod_moneda,''PYG'',''GS'',c.cod_moneda) cod_moneda,''455'' cod_modalidad,''I'',''D'',to_date('''||to_char(v_fecha,'dd/mm/yyyy')||''',''dd/mm/yyyy'')
    from
    GE_SNP_MSJ_MT940 c,
    ( SELECT W.SAL_FINAL, W.NRO_HOJA,W.COD_MONEDA,W.FEC_INICIAL,W.TIPO
         FROM GE_SNP_MSJ_MT940 W
           WHERE W.FEC_INICIAL= '''||v_fecha||'''
            AND W.NRO_HOJA IN (SELECT MAX(TO_NUMBER(Z.NRO_HOJA))
              FROM GE_SNP_MSJ_MT940 Z
                 WHERE Z.FEC_INICIAL='''||v_fecha||'''
                   and z.cod_moneda=W.cod_moneda

                 )) X
    where c.fec_inicial= '''||v_fecha||'''
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
    ||lpad(substr(NVL(decode(nvl(c.nro_ref_transferencia,0),0,c.nro_ref_transferencia,c.nro_ref_transferencia),0),1,15),15,0)
    ||'',''
    ||lpad(TRUNC(decode(c.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(c.monto),ABS(c.monto)),nvl(ABS(c.monto),ABS(c.monto)))),13,0)
    ||''.''
    ||substr(rpad(decode(c.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(c.monto),ABS(c.monto)),nvl(ABS(c.monto),
    ABS(c.monto)))-TRUNC(decode(c.cod_moneda,'''||v_cod_mon_local||''',nvl(ABS(c.monto),ABS(c.monto)),nvl(ABS(c.monto),ABS(c.monto)))),3,0),-2)
    ,''7'' cod_bco_central,c.cod_moneda,455 cod_modalidad,c.tip_movimiento,''D'',c.fecha
     from ge_msj_mt940_tmp c
    where c.fecha= '''||v_fecha||'''
    ';

end PRB_INF_DIA_940_CIDESA;
/

