CREATE OR REPLACE TRIGGER IT.MA_GE_DIR_ENVIOS
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_DIR_ENVIOS
 FOR EACH ROW
declare
  v_cod_tip_documento MI_IT_BA_PERSONAS_01.COD_TIP_DOCUMENTO%TYPE;
  v_nro_documento     MI_IT_BA_PERSONAS_01.NRO_DOCUMENTO%TYPE; 
begin
   -- Registrar campos de migracion
   if inserting then
     If :new.cod_persona is not null and :new.referencia is not null then
       PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                    v_cod_tip_documento,
                                    v_nro_documento);

       insert
       into MI_IT_GE_DIR_ENVIOS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                TIP_ENVIO,
                REFERENCIA,
                NRO_CUENTA,
                OBSERVACION,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION,
                EST_MIGRACION
              )
       values
           (
                :new.COD_PERSONA,
                v_cod_tip_documento,
                v_nro_documento,
                :new.TIP_ENVIO,
                :new.REFERENCIA,
                :new.NRO_CUENTA,
                :new.OBSERVACION,
                :new.USU_INSERCION,
                :new.FEC_INSERCION,
                :new.USU_MODIFICACION,
                :new.FEC_MODIFICACION,
                'I');
     End if;
   elsif updating then
       PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                    v_cod_tip_documento,
                                    v_nro_documento);

      insert
      into MI_IT_GE_DIR_ENVIOS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,                
                TIP_ENVIO,
                REFERENCIA,
                NRO_CUENTA,
                OBSERVACION,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION,
                EST_MIGRACION
              )
       values
           (
                :new.COD_PERSONA,
                v_cod_tip_documento,
                v_nro_documento,
                :new.TIP_ENVIO,
                :new.REFERENCIA,
                :new.NRO_CUENTA,
                :new.OBSERVACION,
                :new.USU_INSERCION,
                :new.FEC_INSERCION,
                :new.USU_MODIFICACION,
                :new.FEC_MODIFICACION,
                'U');
   elsif deleting then
        PRA_ACT_MI_IT_BA_PERSONAS_01(:old.COD_PERSONA,
                                    v_cod_tip_documento,
                                    v_nro_documento);

      insert
      into MI_IT_GE_DIR_ENVIOS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,                
                TIP_ENVIO,
                REFERENCIA,
                NRO_CUENTA,
                OBSERVACION,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION,
                EST_MIGRACION
              )
       values
           (
                :old.COD_PERSONA,
                v_cod_tip_documento,
                v_nro_documento,
                :old.TIP_ENVIO,
                :old.REFERENCIA,
                :old.NRO_CUENTA,
                :old.OBSERVACION,
                :old.USU_INSERCION,
                :old.FEC_INSERCION,
                :old.USU_MODIFICACION,
                :old.FEC_MODIFICACION,
                'D');
   end if;
END;
/

