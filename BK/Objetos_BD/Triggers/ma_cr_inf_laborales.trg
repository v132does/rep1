CREATE OR REPLACE TRIGGER IT.MA_CR_INF_LABORALES
 AFTER DELETE OR INSERT OR UPDATE
 ON CR_INF_LABORALES
 FOR EACH ROW
declare
  v_cod_tip_documento MI_IT_BA_PERSONAS_01.COD_TIP_DOCUMENTO%TYPE;
  v_nro_documento     MI_IT_BA_PERSONAS_01.NRO_DOCUMENTO%TYPE; 
  v_tip_operacion     varchar2(01);
begin
   -- Registrar campos de migracion
   if inserting then
       PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                     v_cod_tip_documento,
                                     v_nro_documento);

      if :new.nro_secuencia <= 1 then
         v_tip_operacion := 'I';
      else   
         v_tip_operacion := 'U';
      end if;
      /*insert
      into MI_IT_CR_INF_LABORALES
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                NRO_SECUENCIA,
                LUG_TRABAJO,
                FEC_INGRESO,
                FEC_SALIDA,
                MTO_INGRESO,
                COD_MONEDA,
                DES_PUESTO,
                TIP_CARGO,
                TIP_INGRESO,
                ACTUAL,
                TIP_EMPLEO,
                COD_RAMO,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION,
                OBSERVACION,
                COD_DIRECCION,
                COD_TELEFONO,
                DIR_CORREO,
                NOM_PER_CONTACTO,
                MTO_FIJO,
                EST_MIGRACION
               )
       values
           (
                :new.COD_PERSONA,
                v_cod_tip_documento,
                v_nro_documento,
                :new.NRO_SECUENCIA,
                :new.LUG_TRABAJO,
                :new.FEC_INGRESO,
                :new.FEC_SALIDA,
                :new.MTO_INGRESO,
                :new.COD_MONEDA,
                :new.DES_PUESTO,
                :new.TIP_CARGO,
                :new.TIP_INGRESO,
                :new.ACTUAL,
                :new.TIP_EMPLEO,
                :new.COD_RAMO,
                :new.USU_INSERCION,
                :new.FEC_INSERCION,
                :new.USU_MODIFICACION,
                :new.FEC_MODIFICACION,
                :new.OBSERVACION,
                :new.COD_DIRECCION,
                :new.COD_TELEFONO,
                :new.DIR_CORREO,
                :new.NOM_PER_CONTACTO,
                :new.MTO_FIJO,
                v_tip_operacion);*/
   elsif updating then
       PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                     v_cod_tip_documento,
                                     v_nro_documento);

      /*insert
      into MI_IT_CR_INF_LABORALES
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                NRO_SECUENCIA,
                LUG_TRABAJO,
                FEC_INGRESO,
                FEC_SALIDA,
                MTO_INGRESO,
                COD_MONEDA,
                DES_PUESTO,
                TIP_CARGO,
                TIP_INGRESO,
                ACTUAL,
                TIP_EMPLEO,
                COD_RAMO,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION,
                OBSERVACION,
                COD_DIRECCION,
                COD_TELEFONO,
                DIR_CORREO,
                NOM_PER_CONTACTO,
                MTO_FIJO,
                EST_MIGRACION
               )
       values
           (
                :new.COD_PERSONA,
                v_cod_tip_documento,
                v_nro_documento,                
                :new.NRO_SECUENCIA,
                :new.LUG_TRABAJO,
                :new.FEC_INGRESO,
                :new.FEC_SALIDA,
                :new.MTO_INGRESO,
                :new.COD_MONEDA,
                :new.DES_PUESTO,
                :new.TIP_CARGO,
                :new.TIP_INGRESO,
                :new.ACTUAL,
                :new.TIP_EMPLEO,
                :new.COD_RAMO,
                :new.USU_INSERCION,
                :new.FEC_INSERCION,
                :new.USU_MODIFICACION,
                :new.FEC_MODIFICACION,
                :new.OBSERVACION,
                :new.COD_DIRECCION,
                :new.COD_TELEFONO,
                :new.DIR_CORREO,
                :new.NOM_PER_CONTACTO,
                :new.MTO_FIJO,
                'U');*/
   elsif deleting then
       PRA_ACT_MI_IT_BA_PERSONAS_01(:old.COD_PERSONA,
                                     v_cod_tip_documento,
                                     v_nro_documento);

      /*insert
      into MI_IT_CR_INF_LABORALES
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,                
                NRO_SECUENCIA,
                LUG_TRABAJO,
                FEC_INGRESO,
                FEC_SALIDA,
                MTO_INGRESO,
                COD_MONEDA,
                DES_PUESTO,
                TIP_CARGO,
                TIP_INGRESO,
                ACTUAL,
                TIP_EMPLEO,
                COD_RAMO,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION,
                OBSERVACION,
                COD_DIRECCION,
                COD_TELEFONO,
                DIR_CORREO,
                NOM_PER_CONTACTO,
                MTO_FIJO,
                EST_MIGRACION
               )
       values
           (
                :old.COD_PERSONA,
                v_cod_tip_documento,
                v_nro_documento,                
                :old.NRO_SECUENCIA,
                :old.LUG_TRABAJO,
                :old.FEC_INGRESO,
                :old.FEC_SALIDA,
                :old.MTO_INGRESO,
                :old.COD_MONEDA,
                :old.DES_PUESTO,
                :old.TIP_CARGO,
                :old.TIP_INGRESO,
                :old.ACTUAL,
                :old.TIP_EMPLEO,
                :old.COD_RAMO,
                :old.USU_INSERCION,
                :old.FEC_INSERCION,
                :old.USU_MODIFICACION,
                :old.FEC_MODIFICACION,
                :old.OBSERVACION,
                :old.COD_DIRECCION,
                :old.COD_TELEFONO,
                :old.DIR_CORREO,
                :old.NOM_PER_CONTACTO,
                :old.MTO_FIJO,
                'D');*/
   end if;
END;
/

