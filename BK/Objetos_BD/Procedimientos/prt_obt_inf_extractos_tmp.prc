create or replace procedure it.PRT_OBT_INF_EXTRACTOS_TMP is
  -- Proceso de desparseo y copia de Archivo PBEXTDET NAF 2022-08
  -- El proceso de importacion IT copia los datos de toda la linea a la tabla TA_ARC_EXTRACTO_TMP
  -- Este proceso recupera cada columna y la copia en la tabla de procesamiento TA_DET_EXTRACTO_TMP
  v_sep_decimal varchar2(2);
  v_sep_dec_bancard varchar2(2);
  v_error varchar2(1000);
--
procedure lp_obt_sep_decimal is
  v_numero varchar2(100);
  v_texto varchar2(100);
  begin
      PRG_ACT_LOG_PROCESOS('PRT_OBT_INF_EXTRACTOS_TMP',
                                                 '1',
                                                 sysdate,
                                                 to_char(sysdate,'HH24:MI:SS'),
                                                 to_char(sysdate,'HH24:MI:SS'),
                                                 '02 OBT SEPARADORES DECIMALES');
      begin
        --obtiene separador decimal del archivo      
        select distinct regexp_replace(substr(trim(substr(t.linea, instr(t.linea,';',1,13)+1, instr(t.linea,';',1,14)-instr(t.linea,';',1,13)-1)),1,20), '[^,.]', '')
        into v_sep_dec_bancard
        from TA_ARC_EXTRACTO_TMP t
        where rownum < 15;
      exception
         when others then
           v_sep_dec_bancard := ',';
      end;
      --obtiene separador decimal de la sesion oracle
      select regexp_replace(10000/3, '[^,.]', ''), 10000/3
      into v_sep_decimal, v_numero
      from dual;
      --si la sesion tiene mas de dos separadores (decimal y miles) se utiliza el ultimo
      if length(v_sep_decimal) > 1 then
         v_sep_decimal := substr(trim(v_sep_decimal),-1,1);
      end if;
      PRG_ACT_LOG_PROCESOS('PRT_OBT_INF_EXTRACTOS_TMP',
                             '1',
                             sysdate,
                             to_char(sysdate,'HH24:MI:SS'),
                             to_char(sysdate,'HH24:MI:SS'),
                             '04 SEPARADORES DECIMALES sesion:'||v_sep_decimal||' - bancard:'||v_sep_dec_bancard||' - numero test:'||v_numero);
end;
--
procedure lp_mod_sep_decimal is
begin
      if v_sep_dec_bancard != v_sep_decimal then      
         PRG_ACT_LOG_PROCESOS('PRT_OBT_INF_EXTRACTOS_TMP',
                               '1',
                               sysdate,
                               to_char(sysdate,'HH24:MI:SS'),
                               to_char(sysdate,'HH24:MI:SS'),
                               '05 ADECUA SEPARADORES DECIMALES sesion:'||v_sep_decimal||' - bancard:' || v_sep_dec_bancard);

         update TA_ARC_EXTRACTO_TMP 
         set linea = replace(linea, v_sep_dec_bancard, v_sep_decimal)
         where 1=1;
         commit;
      end if;
end;
--
procedure lp_ins_dat_extracto is
  --PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    PRG_ACT_LOG_PROCESOS('PRT_OBT_INF_EXTRACTOS_TMP',
                                                   '1',
                                                   sysdate,
                                                   to_char(sysdate,'HH24:MI:SS'),
                                                   to_char(sysdate,'HH24:MI:SS'),
                                                   '06 INSERTA DATOS');

    --parsea e inserta los datos
    INSERT INTO TA_DET_EXTRACTO_TMP (FEC_CIERRE,NRO_CUENTA,SEC_DETALLE,NRO_TARJETA,CUP_USUARIO,MOV_USUARIO,TIP_SALDO,TIP_CARGO,AGR_TIP_CARGO,FEC_OPERACION, 
         FEC_PROCESO,NRO_CUPON,DES_OPERACION,MTO_LIQ_DETALLE,COD_MONEDA,COD_PLAN,NRO_CUOTA,CAN_CUOTAS,MTO_INT_CUOTA,
         EST_CUOTA,DES_EST_CUOTA,FOR_CAL_IVA,DES_FOR_CAL_IVA,IMP_MOVIMIENTO,MTO_IMPUESTO,POR_IMPUESTO,ORI_TRANSACCION,
         MTO_ORIGEN,COD_MON_ORIGEN,COD_PAI_ORIGEN,LOC_COMERCIO,FIN_PAG_MINIMO,TIP_MOVIMIENTO,COD_ENTIDAD,MARCA,PRO_MARCA,
         AFINIDAD,NUM_CAL_INT_COMPRA,CAN_TRA_ATM,FEC_ULT_ACT,MOM_GENERACION,TIP_CIERRE,AFE_DETALLE,IMP_TIP_CARGO,
         MOT_NO_AFE_DETALLE,RUBRO,AGR_EXTRACTO,ORD_AGR_EXTRACTO,TIP_TARJETA)
    select to_date(substr(t.linea, 1, instr(t.linea,';')-1),'YYYYMMDD') fec_cierre, --DATE not null
         substr(trim(substr(t.linea, instr(t.linea,';',1,1)+1, instr(t.linea,';',1,2)-instr(t.linea,';',1,1)-1)),1,15) nro_cuenta, --VARCHAR2(15) not null
         substr(trim(substr(t.linea, instr(t.linea,';',1,2)+1, instr(t.linea,';',1,3)-instr(t.linea,';',1,2)-1)),1,4) sec_detalle,     --NUMBER(4),  
         substr(trim(substr(t.linea, instr(t.linea,';',1,3)+1, instr(t.linea,';',1,4)-instr(t.linea,';',1,3)-1)),1,19) nro_tarjeta, --varchar(19)
         substr(trim(substr(t.linea, instr(t.linea,';',1,4)+1, instr(t.linea,';',1,5)-instr(t.linea,';',1,4)-1)),1,15) CUP_USUARIO, --number(15)
         substr(trim(substr(t.linea, instr(t.linea,';',1,5)+1, instr(t.linea,';',1,6)-instr(t.linea,';',1,5)-1)),1,15) MOV_USUARIO, --number(15)
         substr(trim(substr(t.linea, instr(t.linea,';',1,6)+1, instr(t.linea,';',1,7)-instr(t.linea,';',1,6)-1)),1,3) TIP_SALDO, --number(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,7)+1, instr(t.linea,';',1,8)-instr(t.linea,';',1,7)-1)),1,3) TIP_CARGO, --number(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,8)+1, instr(t.linea,';',1,9)-instr(t.linea,';',1,8)-1)),1,3) AGR_TIP_CARGO, --number(3)
         to_date(trim(substr(t.linea, instr(t.linea,';',1,9)+1, instr(t.linea,';',1,10)-instr(t.linea,';',1,9)-1)),'YYYYMMDD') FEC_OPERACION, --date
         to_date(trim(substr(t.linea, instr(t.linea,';',1,10)+1, instr(t.linea,';',1,11)-instr(t.linea,';',1,10)-1)),'YYYYMMDD') FEC_PROCESO, --date
         substr(trim(substr(t.linea, instr(t.linea,';',1,11)+1, instr(t.linea,';',1,12)-instr(t.linea,';',1,11)-1)),1,15) NRO_CUPON, --number(15)
         substr(trim(substr(t.linea, instr(t.linea,';',1,12)+1, instr(t.linea,';',1,13)-instr(t.linea,';',1,12)-1)),1,40) DES_OPERACION, --varchar2(40)
         to_number(substr(trim(substr(t.linea, instr(t.linea,';',1,13)+1, instr(t.linea,';',1,14)-instr(t.linea,';',1,13)-1)),1,20)) MTO_LIQ_DETALLE, --NUMBER(18,2)
         substr(trim(substr(t.linea, instr(t.linea,';',1,14)+1, instr(t.linea,';',1,15)-instr(t.linea,';',1,14)-1)),1,3) COD_MONEDA, --number(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,15)+1, instr(t.linea,';',1,16)-instr(t.linea,';',1,15)-1)),1,2) COD_PLAN, --varchar2(2)
         substr(trim(substr(t.linea, instr(t.linea,';',1,16)+1, instr(t.linea,';',1,17)-instr(t.linea,';',1,16)-1)),1,2) NRO_CUOTA, -- number(2)
         substr(trim(substr(t.linea, instr(t.linea,';',1,17)+1, instr(t.linea,';',1,18)-instr(t.linea,';',1,17)-1)),1,2) CAN_CUOTAS,-- number(2)
         to_number(substr(trim(substr(t.linea, instr(t.linea,';',1,18)+1, instr(t.linea,';',1,19)-instr(t.linea,';',1,18)-1)),1,20)) MTO_INT_CUOTA,-- number(18,2)
         substr(trim(substr(t.linea, instr(t.linea,';',1,19)+1, instr(t.linea,';',1,20)-instr(t.linea,';',1,19)-1)),1,1) EST_CUOTA, --varchar2(1)
         substr(trim(substr(t.linea, instr(t.linea,';',1,20)+1, instr(t.linea,';',1,21)-instr(t.linea,';',1,20)-1)),1,15) DES_EST_CUOTA, --varchar2(15)
         substr(trim(substr(t.linea, instr(t.linea,';',1,21)+1, instr(t.linea,';',1,22)-instr(t.linea,';',1,21)-1)),1,1) FOR_CAL_IVA,--varchar2(1)
         substr(trim(substr(t.linea, instr(t.linea,';',1,22)+1, instr(t.linea,';',1,23)-instr(t.linea,';',1,22)-1)),1,30) DES_FOR_CAL_IVA,--varchar2(30)
         substr(trim(substr(t.linea, instr(t.linea,';',1,23)+1, instr(t.linea,';',1,24)-instr(t.linea,';',1,23)-1)),1,3) IMP_MOVIMIENTO, --number(3)
         to_number(substr(trim(substr(t.linea, instr(t.linea,';',1,24)+1, instr(t.linea,';',1,25)-instr(t.linea,';',1,24)-1)),1,20)) MTO_IMPUESTO, --NUMBER(18,2)
         to_number(substr(trim(substr(t.linea, instr(t.linea,';',1,25)+1, instr(t.linea,';',1,26)-instr(t.linea,';',1,25)-1)),1,13)) POR_IMPUESTO, --NUMBER(8,5)
         substr(trim(substr(t.linea, instr(t.linea,';',1,26)+1, instr(t.linea,';',1,27)-instr(t.linea,';',1,26)-1)),1,15) ORI_TRANSACCION, --VARCHAR2(15)
         to_number(substr(trim(substr(t.linea, instr(t.linea,';',1,27)+1, instr(t.linea,';',1,28)-instr(t.linea,';',1,27)-1)),1,20)) MTO_ORIGEN, --NUMBER(18,2)
         substr(trim(substr(t.linea, instr(t.linea,';',1,28)+1, instr(t.linea,';',1,29)-instr(t.linea,';',1,28)-1)),1,3) COD_MON_ORIGEN, --NUMBER(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,29)+1, instr(t.linea,';',1,30)-instr(t.linea,';',1,29)-1)),1,3) COD_PAI_ORIGEN, --NUMBER(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,30)+1, instr(t.linea,';',1,31)-instr(t.linea,';',1,30)-1)),1,40) LOC_COMERCIO, --varchar2(40)
         substr(trim(substr(t.linea, instr(t.linea,';',1,31)+1, instr(t.linea,';',1,32)-instr(t.linea,';',1,31)-1)),1,2) FIN_PAG_MINIMO, --VARCHAR2(2)
         substr(trim(substr(t.linea, instr(t.linea,';',1,32)+1, instr(t.linea,';',1,33)-instr(t.linea,';',1,32)-1)),1,15) TIP_MOVIMIENTO,--VARCHAR2(15)
         substr(trim(substr(t.linea, instr(t.linea,';',1,33)+1, instr(t.linea,';',1,34)-instr(t.linea,';',1,33)-1)),1,3) COD_ENTIDAD, --number(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,34)+1, instr(t.linea,';',1,35)-instr(t.linea,';',1,34)-1)),1,3) MARCA, --VARCHAR2(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,35)+1, instr(t.linea,';',1,36)-instr(t.linea,';',1,35)-1)),1,3) PRO_MARCA, --VARCHAR2(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,36)+1, instr(t.linea,';',1,37)-instr(t.linea,';',1,36)-1)),1,6) AFINIDAD, --NUMBER(6)
         substr(trim(substr(t.linea, instr(t.linea,';',1,37)+1, instr(t.linea,';',1,38)-instr(t.linea,';',1,37)-1)),1,15) NUM_CAL_INT_COMPRA, --NUMBER(15)
         substr(trim(substr(t.linea, instr(t.linea,';',1,38)+1, instr(t.linea,';',1,39)-instr(t.linea,';',1,38)-1)),1,5) CAN_TRA_ATM, --NUMBER(5)
         substr(trim(substr(t.linea, instr(t.linea,';',1,39)+1, instr(t.linea,';',1,40)-instr(t.linea,';',1,39)-1)),1,26) FEC_ULT_ACT, --VARCHAR2(26)
         substr(trim(substr(t.linea, instr(t.linea,';',1,40)+1, instr(t.linea,';',1,41)-instr(t.linea,';',1,40)-1)),1,15) MOM_GENERACION, --VARCHAR2(15)
         substr(trim(substr(t.linea, instr(t.linea,';',1,41)+1, instr(t.linea,';',1,42)-instr(t.linea,';',1,41)-1)),1,2) TIP_CIERRE, --VARCHAR2(2)
         substr(trim(substr(t.linea, instr(t.linea,';',1,42)+1, instr(t.linea,';',1,43)-instr(t.linea,';',1,42)-1)),1,2) AFE_DETALLE, --VARCHAR2(2)
         substr(trim(substr(t.linea, instr(t.linea,';',1,43)+1, instr(t.linea,';',1,44)-instr(t.linea,';',1,43)-1)),1,3) IMP_TIP_CARGO, -- NUMBER(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,44)+1, instr(t.linea,';',1,45)-instr(t.linea,';',1,44)-1)),1,15) MOT_NO_AFE_DETALLE, --VARCHAR2(15)
         substr(trim(substr(t.linea, instr(t.linea,';',1,45)+1, instr(t.linea,';',1,46)-instr(t.linea,';',1,45)-1)),1,2) RUBRO,--NUMBER(2)
         substr(trim(substr(t.linea, instr(t.linea,';',1,46)+1, instr(t.linea,';',1,47)-instr(t.linea,';',1,46)-1)),1,3) AGR_EXTRACTO, --NUMBER(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,47)+1, instr(t.linea,';',1,48)-instr(t.linea,';',1,47)-1)),1,3) ORD_AGR_EXTRACTO, --NUMBER(3)
         substr(trim(substr(t.linea, instr(t.linea,';',1,48)+1, instr(t.linea,';',1,49)-instr(t.linea,';',1,48)-1)),1,15) TIP_TARJETA --VARCHAR2(15)
    from TA_ARC_EXTRACTO_TMP t;
    commit;
end;
begin
  --se trunca la tabla destino
  PRG_ACT_LOG_PROCESOS('PRT_OBT_INF_EXTRACTOS_TMP',
                       '1',
                       sysdate,
                       to_char(sysdate,'HH24:MI:SS'),
                       to_char(sysdate,'HH24:MI:SS'),
                       '01 TRUNCA TABLA');
  execute immediate 'truncate table TA_DET_EXTRACTO_TMP';
  
  --obtiene separadores de decimales  
  lp_obt_sep_decimal;
  --reemplaza separadores de decimales 
  lp_mod_sep_decimal;
  --insera los datos en la tabla de procesamiento
  lp_ins_dat_extracto;
  --log finalizacion 
  PRG_ACT_LOG_PROCESOS('PRT_OBT_INF_EXTRACTOS_TMP',
                                                 '1',
                                                 sysdate,
                                                 to_char(sysdate,'HH24:MI:SS'),
                                                 to_char(sysdate,'HH24:MI:SS'),
                                                 '07 FINALIZA');

 -- commit;
exception
   when others then
     v_error := substr(sqlerrm,1,1000);
      PRG_ACT_LOG_PROCESOS('PRT_OBT_INF_EXTRACTOS_TMP',
                                                 '1',
                                                 sysdate,
                                                 to_char(sysdate,'HH24:MI:SS'),
                                                 to_char(sysdate,'HH24:MI:SS'),
                                                 '10 ERROR - ' || v_error);
     raise_application_error(-20000, 'PRT_OBT_INF_EXTRACTOS_TMP Error: ' || v_error);
end;
/

