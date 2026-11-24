CREATE OR REPLACE TRIGGER IT.MA_BA_PER_JURIDICAS
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_PER_JURIDICAS
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
      into MI_IT_BA_PER_JURIDICAS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                RAZ_SOCIAL,
                NOM_COMERCIAL,
                NATURALEZA,
                FEC_APERTURA,
                COD_RAMO,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION,
                GAR_TERCERO,
                CAP_OPERATIVO,
                COD_AREA, 
                FEC_VTO_SOCIEDAD, 
                AGE_RETENCION, 
                CAN_SUCURSALES, 
                CAN_SOCIOS, 
                CAN_EMPLEADOS, 
                TIP_ACT_INTERNACIONAL, 
                EST_MIGRACION
            )
       values
           (
                :new.COD_PERSONA,
                v_cod_tip_documento,
                v_nro_documento,
                :new.RAZ_SOCIAL,
                :new.NOM_COMERCIAL,
                :new.NATURALEZA,
                :new.FEC_APERTURA,
                :new.COD_RAMO,
                :new.USU_INSERCION,
                :new.FEC_INSERCION,
                :new.USU_MODIFICACION,
                :new.FEC_MODIFICACION,
                :new.GAR_TERCERO,
                :new.CAP_OPERATIVO,                
                :new.COD_AREA, 
                :new.FEC_VTO_SOCIEDAD, 
                :new.AGE_RETENCION, 
                :new.CAN_SUCURSALES, 
                :new.CAN_SOCIOS, 
                :new.CAN_EMPLEADOS, 
                :new.TIP_ACT_INTERNACIONAL, 
                'U');
   elsif updating then
      PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                    v_cod_tip_documento,
                                    v_nro_documento);

      insert
      into MI_IT_BA_PER_JURIDICAS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                RAZ_SOCIAL,
                NOM_COMERCIAL,
                NATURALEZA,
                FEC_APERTURA,
                COD_RAMO,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION,
                GAR_TERCERO,
                CAP_OPERATIVO,
                COD_AREA, 
                FEC_VTO_SOCIEDAD, 
                AGE_RETENCION, 
                CAN_SUCURSALES, 
                CAN_SOCIOS, 
                CAN_EMPLEADOS, 
                TIP_ACT_INTERNACIONAL, 
                EST_MIGRACION
            )
       values
           (
                :new.COD_PERSONA,
                v_cod_tip_documento,
                v_nro_documento,                
                :new.RAZ_SOCIAL,
                :new.NOM_COMERCIAL,
                :new.NATURALEZA,
                :new.FEC_APERTURA,
                :new.COD_RAMO,
                :new.USU_INSERCION,
                :new.FEC_INSERCION,
                :new.USU_MODIFICACION,
                :new.FEC_MODIFICACION,
                :new.GAR_TERCERO,
                :new.CAP_OPERATIVO,                
                :new.COD_AREA, 
                :new.FEC_VTO_SOCIEDAD, 
                :new.AGE_RETENCION, 
                :new.CAN_SUCURSALES, 
                :new.CAN_SOCIOS, 
                :new.CAN_EMPLEADOS, 
                :new.TIP_ACT_INTERNACIONAL, 
                'U');
  elsif deleting then
      PRA_ACT_MI_IT_BA_PERSONAS_01(:old.COD_PERSONA,
                                    v_cod_tip_documento,
                                    v_nro_documento);

      insert
      into MI_IT_BA_PER_JURIDICAS
            (
                COD_PERSONA,
                COD_TIP_DOCUMENTO,
                NRO_DOCUMENTO,
                RAZ_SOCIAL,
                NOM_COMERCIAL,
                NATURALEZA,
                FEC_APERTURA,
                COD_RAMO,
                USU_INSERCION,
                FEC_INSERCION,
                USU_MODIFICACION,
                FEC_MODIFICACION,
                GAR_TERCERO,
                CAP_OPERATIVO,                
                COD_AREA, 
                FEC_VTO_SOCIEDAD, 
                AGE_RETENCION, 
                CAN_SUCURSALES, 
                CAN_SOCIOS, 
                CAN_EMPLEADOS, 
                TIP_ACT_INTERNACIONAL, 
                EST_MIGRACION
            )
       values
           (
                :old.COD_PERSONA,
                v_cod_tip_documento,
                v_nro_documento,                
                :old.RAZ_SOCIAL,
                :old.NOM_COMERCIAL,
                :old.NATURALEZA,
                :old.FEC_APERTURA,
                :old.COD_RAMO,
                :old.USU_INSERCION,
                :old.FEC_INSERCION,
                :old.USU_MODIFICACION,
                :old.FEC_MODIFICACION,
                :old.GAR_TERCERO,
                :old.CAP_OPERATIVO,                
                :old.COD_AREA, 
                :old.FEC_VTO_SOCIEDAD, 
                :old.AGE_RETENCION, 
                :old.CAN_SUCURSALES, 
                :old.CAN_SOCIOS, 
                :old.CAN_EMPLEADOS, 
                :old.TIP_ACT_INTERNACIONAL, 
                'D');
   end if;
END;
/

