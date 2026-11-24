CREATE OR REPLACE TRIGGER IT.TA_CC_CHE_REC_REGISTROS
 AFTER INSERT
 ON CC_CHE_REC_REGISTROS
 FOR EACH ROW

DECLARE
r_che cc_che_recibidos_tmp%rowtype;
v_for_archivo varchar2(100) := 'CHE_REC_CIDESA02';

---
BEGIN
   if inserting then
     
      r_che                  := null; 
      if length(trim(:new.linea)) > 80 and
         substr(:new.linea,8,2) = '01' then

          r_che.COD_BCO_RECEPTOR := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_RECIBIDOS_TMP',:new.linea,'COD_BCO_RECEPTOR');
          r_che.NRO_CUENTA       := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_RECIBIDOS_TMP',:new.linea,'NRO_CUENTA');
          r_che.NRO_CHEQUE       := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_RECIBIDOS_TMP',:new.linea,'NRO_CHEQUE');
          r_che.MONTO            := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_RECIBIDOS_TMP',:new.linea,'MONTO');
          r_che.NRO_LINEA        := paw_bce.fu_obt_dato(v_for_archivo,'CC_CHE_RECIBIDOS_TMP',:new.linea,'NRO_LINEA');
           
          insert into cc_che_recibidos_tmp
             (cod_bco_receptor, nro_cuenta, nro_cheque, monto, nro_linea)
           values
             (r_che.cod_bco_receptor, r_che.nro_cuenta, r_che.nro_cheque, r_che.monto, r_che.nro_linea);
      end if;       
   end if;
END;
/

