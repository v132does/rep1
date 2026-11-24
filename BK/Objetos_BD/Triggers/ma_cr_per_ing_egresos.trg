CREATE OR REPLACE TRIGGER IT.MA_CR_PER_ING_EGRESOS
 AFTER DELETE OR INSERT OR UPDATE
 ON CR_PER_ING_EGRESOS
 FOR EACH ROW
declare
  v_cod_tip_documento MI_IT_BA_PERSONAS_01.COD_TIP_DOCUMENTO%TYPE;
  v_nro_documento     MI_IT_BA_PERSONAS_01.NRO_DOCUMENTO%TYPE; 
begin
   -- Registrar campos de migracion
   if inserting then
      PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                    v_cod_tip_documento,
                                    v_nro_documento);


      insert
      into MI_IT_CR_PER_ING_EGRESOS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                COD_CONCEPTO,
                ING_EGRESO,
                IMPORTE,
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
                :new.COD_CONCEPTO,
                :new.ING_EGRESO,
                :new.IMPORTE,
                :new.USU_INSERCION,
                :new.FEC_INSERCION,
                :new.USU_MODIFICACION,
                :new.FEC_MODIFICACION,
                'I');
   elsif updating then
      PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                    v_cod_tip_documento,
                                    v_nro_documento);

      insert
      into MI_IT_CR_PER_ING_EGRESOS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,                
                COD_CONCEPTO,
                ING_EGRESO,
                IMPORTE,
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
                :new.COD_CONCEPTO,
                :new.ING_EGRESO,
                :new.IMPORTE,
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
      into MI_IT_CR_PER_ING_EGRESOS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,                
                COD_CONCEPTO,
                ING_EGRESO,
                IMPORTE,
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
                :old.COD_CONCEPTO,
                :old.ING_EGRESO,
                :old.IMPORTE,
                :old.USU_INSERCION,
                :old.FEC_INSERCION,
                :old.USU_MODIFICACION,
                :old.FEC_MODIFICACION,
                'D');
   end if;
END;
/

