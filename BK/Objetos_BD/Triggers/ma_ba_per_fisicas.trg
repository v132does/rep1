CREATE OR REPLACE TRIGGER IT.MA_BA_PER_FISICAS
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_PER_FISICAS
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

     /* insert
      into MI_IT_BA_PER_FISICAS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                PRI_NOMBRE,
                PRI_APELLIDO,
                EST_CIVIL,
                COD_SEXO,
                COD_NIV_ESTUDIO,
                COD_TIP_VIVIENDA,
                COD_PAI_NACIONALIDAD,
                SEG_NOMBRE,
                SEG_APELLIDO,
                FEC_NACIMIENTO,
                CAN_HIJOS,
                COD_PROFESION,
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
                :new.PRI_NOMBRE,
                :new.PRI_APELLIDO,
                :new.EST_CIVIL,
                :new.COD_SEXO,
                :new.COD_NIV_ESTUDIO,
                :new.COD_TIP_VIVIENDA,
                :new.COD_PAI_NACIONALIDAD,
                :new.SEG_NOMBRE,
                :new.SEG_APELLIDO,
                :new.FEC_NACIMIENTO,
                :new.CAN_HIJOS,
                :new.COD_PROFESION,
                :new.USU_INSERCION,
                :new.FEC_INSERCION,
                :new.USU_MODIFICACION,
                :new.FEC_MODIFICACION,
                'U'
           );*/
   elsif updating then
       PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                    v_cod_tip_documento,
                                    v_nro_documento);

      /*insert
      into MI_IT_BA_PER_FISICAS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                PRI_NOMBRE,
                PRI_APELLIDO,
                EST_CIVIL,
                COD_SEXO,
                COD_NIV_ESTUDIO,
                COD_TIP_VIVIENDA,
                COD_PAI_NACIONALIDAD,
                SEG_NOMBRE,
                SEG_APELLIDO,
                FEC_NACIMIENTO,
                CAN_HIJOS,
                COD_PROFESION,
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
                :new.PRI_NOMBRE,
                :new.PRI_APELLIDO,
                :new.EST_CIVIL,
                :new.COD_SEXO,
                :new.COD_NIV_ESTUDIO,
                :new.COD_TIP_VIVIENDA,
                :new.COD_PAI_NACIONALIDAD,
                :new.SEG_NOMBRE,
                :new.SEG_APELLIDO,
                :new.FEC_NACIMIENTO,
                :new.CAN_HIJOS,
                :new.COD_PROFESION,
                :new.USU_INSERCION,
                :new.FEC_INSERCION,
                :new.USU_MODIFICACION,
                :new.FEC_MODIFICACION,
                'U'
           );*/
   elsif deleting then
       PRA_ACT_MI_IT_BA_PERSONAS_01(:old.COD_PERSONA,
                                    v_cod_tip_documento,
                                    v_nro_documento);

      /*insert
      into MI_IT_BA_PER_FISICAS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                PRI_NOMBRE,
                PRI_APELLIDO,
                EST_CIVIL,
                COD_SEXO,
                COD_NIV_ESTUDIO,
                COD_TIP_VIVIENDA,
                COD_PAI_NACIONALIDAD,
                SEG_NOMBRE,
                SEG_APELLIDO,
                FEC_NACIMIENTO,
                CAN_HIJOS,
                COD_PROFESION,
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
                :old.PRI_NOMBRE,
                :old.PRI_APELLIDO,
                :old.EST_CIVIL,
                :old.COD_SEXO,
                :old.COD_NIV_ESTUDIO,
                :old.COD_TIP_VIVIENDA,
                :old.COD_PAI_NACIONALIDAD,
                :old.SEG_NOMBRE,
                :old.SEG_APELLIDO,
                :old.FEC_NACIMIENTO,
                :old.CAN_HIJOS,
                :old.COD_PROFESION,
                :old.USU_INSERCION,
                :old.FEC_INSERCION,
                :old.USU_MODIFICACION,
                :old.FEC_MODIFICACION,
                'D'
           );*/
   end if;
END;
/

