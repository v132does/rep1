CREATE OR REPLACE PROCEDURE IT.PRL_ACT_GRU_IMPRESO
 (P_MES NUMBER 
 ,P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE 
 )
 IS
 
-- Consultar todos los movimientos de cambios del
-- cliente en el mes indicado por el parametro P_MES
-- para setear como 1 el campo protegido los movimientos
-- historico y/o del dia que sumados alcancen
-- el mto del parametro OPE_SUP_MON_FUERTE

CURSOR MOV_CAMBIOS IS
   select LV.fecha,
          LV.hora,
          LV.cod_usuario,
          LV.nro_secuencia,
          LV.cod_mod_padre,
          LV.cod_mad_padre,
          LV.cod_modulo,
          LV.cod_modalidad,
          LV.nro_documento,
          LV.nro_documento2,
          LV.protegido,
          LV.monto,
          LV.nro_cuenta
     from LV_MOVIMIENTOS_HIS LV,
          BA_MONEDAS B
    where LV.COD_MONEDA = B.COD_MONEDA
      and nvl(lv.PROTEGIDO,'0') <> '1'
      and exists (select 1
                   from ba_personas, ge_movimientos gv_movimientos
                  where gv_movimientos.nro_documento2 = ba_personas.cod_persona
                    and gv_movimientos.cod_transaccion = 760
                    and gv_movimientos.COD_MOD_PADRE = 7
                    and gv_movimientos.fecha(+) = LV.fecha
                    and gv_movimientos.cod_usuario(+) = LV.cod_usuario
                    and gv_movimientos.hora(+) = LV.hora 
                    and ba_personas.cod_persona = P_COD_PERSONA
                    and to_number(to_char(gv_movimientos.fecha,'mm')) = P_MES) 
UNION 
     select LV.fecha,
            LV.hora,
            LV.cod_usuario,
            LV.nro_secuencia,
            LV.cod_mod_padre,
            LV.cod_mad_padre,
            LV.cod_modulo,
            LV.cod_modalidad,
            LV.nro_documento,
            LV.nro_documento2,
            LV.protegido,
            LV.monto,
            LV.nro_cuenta
       from GE_MOVIMIENTOS LV,
            BA_MONEDAS B
      where LV.COD_MONEDA = B.COD_MONEDA
        and nvl(lv.PROTEGIDO,'0') <> '1'
        and exists (select 1
                     from ba_personas, ge_movimientos gv_movimientos
                    where gv_movimientos.nro_documento2 = ba_personas.cod_persona
                      and gv_movimientos.cod_transaccion = 760
                      and gv_movimientos.COD_MOD_PADRE = 7
                      and gv_movimientos.fecha(+) = LV.fecha
                      and gv_movimientos.cod_usuario(+) = LV.cod_usuario
                      and gv_movimientos.hora(+) = LV.hora 
                      and ba_personas.cod_persona = P_COD_PERSONA
                      and to_number(to_char(gv_movimientos.fecha,'mm')) = P_MES)                    ;
BEGIN


   PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:=1;
   FOR MOV IN MOV_CAMBIOS LOOP
      
      IF MOV.FECHA = PAG_CAL.FU_OBT_FEC_ACTUAL(1) THEN
         UPDATE GE_MOVIMIENTOS MO
            SET PROTEGIDO = '1'
         WHERE MO.COD_MOD_PADRE = 7
           /*and ((MO.COD_MAD_PADRE IN (71,72) AND MO.NRO_SECUENCIA = 1)
            or (MO.COD_MAD_PADRE IN (73,74) AND MO.NRO_SECUENCIA IN (1,2)) )  */    
            and nvl(MO.PROTEGIDO,'0') <> '1' -- indicador 1 grupo de 10000 ya impreso
            and MO.FECHA = MOV.FECHA
            and MO.COD_USUARIO = MOV.COD_USUARIO
            and MO.HORA = MOV.HORA;
      ELSIF MOV.FECHA != PAG_CAL.FU_OBT_FEC_ACTUAL(1) THEN
         IF MOV.COD_MODULO = 7 THEN
            UPDATE LC_MOVIMIENTOS_HIS MO
               SET PROTEGIDO = '1'
            WHERE MO.COD_MOD_PADRE = 7
              /*and ((MO.COD_MAD_PADRE IN (71,72) AND MO.NRO_SECUENCIA = 1)
               or (MO.COD_MAD_PADRE IN (73,74) AND MO.NRO_SECUENCIA IN (1,2)) )  */    
              and nvl(MO.PROTEGIDO,'0') <> '1' -- indicador 1 grupo de 10000 ya impreso
              and MO.FECHA = MOV.FECHA
              and MO.COD_USUARIO = MOV.COD_USUARIO
              and MO.HORA = MOV.HORA;
         ELSIF MOV.COD_MODULO = 3 THEN
            UPDATE AH_MOVIMIENTOS_HIS MO
               SET PROTEGIDO = '1'
            WHERE MO.COD_MOD_PADRE = 7
              /*and ((MO.COD_MAD_PADRE IN (71,72) AND MO.NRO_SECUENCIA = 1)
               or (MO.COD_MAD_PADRE IN (73,74) AND MO.NRO_SECUENCIA IN (1,2)) )*/      
              and nvl(MO.PROTEGIDO,'0') <> '1' -- indicador 1 grupo de 10000 ya impreso
              and MO.FECHA = MOV.FECHA
              and MO.COD_USUARIO = MOV.COD_USUARIO
              and MO.HORA = MOV.HORA;              
         ELSIF MOV.COD_MODULO = 4 THEN
            UPDATE CC_MOVIMIENTOS_HIS MO
               SET PROTEGIDO = '1'
            WHERE MO.COD_MOD_PADRE = 7
              /*and ((MO.COD_MAD_PADRE IN (71,72) AND MO.NRO_SECUENCIA = 1)
               or (MO.COD_MAD_PADRE IN (73,74) AND MO.NRO_SECUENCIA IN (1,2)) ) */     
              and nvl(MO.PROTEGIDO,'0') <> '1' -- indicador 1 grupo de 10000 ya impreso
              and MO.FECHA = MOV.FECHA
              and MO.COD_USUARIO = MOV.COD_USUARIO
              and MO.HORA = MOV.HORA;              
         END IF;
      END IF;
                     
   END LOOP;
commit;

EXCEPTION
   WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR(-20000,'ERROR.PRL_ACT_GRU_IMPRESO'||sqlerrm);
END;
/

