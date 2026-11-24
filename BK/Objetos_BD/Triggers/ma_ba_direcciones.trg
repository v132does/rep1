CREATE OR REPLACE TRIGGER IT.MA_BA_DIRECCIONES
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_DIRECCIONES
 FOR EACH ROW
declare
  v_cod_tip_documento MI_IT_BA_PERSONAS_01.COD_TIP_DOCUMENTO%TYPE;
  v_nro_documento     MI_IT_BA_PERSONAS_01.NRO_DOCUMENTO%TYPE; 
begin
   -- Registrar campos de migracion
   if inserting then
      if :new.principal = 'S' and :new.tipo = 'P' then
        PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                      v_cod_tip_documento,
                                      v_nro_documento);
       /* insert
        into MI_IT_BA_DIRECCIONES
              (
              COD_PERSONA,
              COD_TIP_DOCUMENTO,
              NRO_DOCUMENTO,
              COD_DIRECCION,
              TIPO,
              PRINCIPAL,
              DIRECCION,
              COD_PAIS,
              COD_CIUDAD,
              COD_BARRIO,
              OBSERVACION,
              NUMERO,
              DEPARTAMENTO,
              PISO,
              EDIFICIO,
              COD_POSTAL,
              USU_INSERCION,
              FEC_INSERCION,
              USU_MODIFICACION,
              FEC_MODIFICACION,
              EST_MIGRACION
              )
         values
             (:new.COD_PERSONA,
              v_cod_tip_documento,
              v_nro_documento,
              :new.COD_DIRECCION,
              :new.TIPO,
              :new.PRINCIPAL,
              :new.DIRECCION,
              :new.COD_PAIS,
              :new.COD_CIUDAD,
              :new.COD_BARRIO,
              :new.OBSERVACION,
              :new.NUMERO,
              :new.DEPARTAMENTO,
              :new.PISO,
              :new.EDIFICIO,
              :new.COD_POSTAL,
              :new.USU_INSERCION,
              :new.FEC_INSERCION,
              :new.USU_MODIFICACION,
              :new.FEC_MODIFICACION,
              'U');*/
         end if;
      elsif updating then
         if :new.principal = 'S' and :new.tipo = 'P' then
           PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                      v_cod_tip_documento,
                                      v_nro_documento);

           /* insert
            into MI_IT_BA_DIRECCIONES
              (
              COD_PERSONA,
              COD_TIP_DOCUMENTO,
              NRO_DOCUMENTO,
              COD_DIRECCION,
              TIPO,
              PRINCIPAL,
              DIRECCION,
              COD_PAIS,
              COD_CIUDAD,
              COD_BARRIO,
              OBSERVACION,
              NUMERO,
              DEPARTAMENTO,
              PISO,
              EDIFICIO,
              COD_POSTAL,
              USU_INSERCION,
              FEC_INSERCION,
              USU_MODIFICACION,
              FEC_MODIFICACION,
              EST_MIGRACION
              )
            values
             (:new.COD_PERSONA,
              v_cod_tip_documento,
              v_nro_documento,           
              :new.COD_DIRECCION,
              :new.TIPO,
              :new.PRINCIPAL,
              :new.DIRECCION,
              :new.COD_PAIS,
              :new.COD_CIUDAD,
              :new.COD_BARRIO,
              :new.OBSERVACION,
              :new.NUMERO,
              :new.DEPARTAMENTO,
              :new.PISO,
              :new.EDIFICIO,
              :new.COD_POSTAL,
              :new.USU_INSERCION,
              :new.FEC_INSERCION,
              :new.USU_MODIFICACION,
              :new.FEC_MODIFICACION,
              'U');*/
         end if;
      elsif deleting then
         if :old.principal = 'S' and :old.tipo = 'P' then
            PRA_ACT_MI_IT_BA_PERSONAS_01(:old.COD_PERSONA,
                                      v_cod_tip_documento,
                                      v_nro_documento);

           /* insert into MI_IT_BA_DIRECCIONES
              (
              COD_PERSONA,
              COD_TIP_DOCUMENTO,
              NRO_DOCUMENTO,
              COD_DIRECCION,
              TIPO,
              PRINCIPAL,
              DIRECCION,
              COD_PAIS,
              COD_CIUDAD,
              COD_BARRIO,
              OBSERVACION,
              NUMERO,
              DEPARTAMENTO,
              PISO,
              EDIFICIO,
              COD_POSTAL,
              USU_INSERCION,
              FEC_INSERCION,
              USU_MODIFICACION,
              FEC_MODIFICACION,
              EST_MIGRACION
              )
            values
             (:old.COD_PERSONA,
              v_cod_tip_documento,
              v_nro_documento,            
              :old.COD_DIRECCION,
              :old.TIPO,
              :old.PRINCIPAL,
              :old.DIRECCION,
              :old.COD_PAIS,
              :old.COD_CIUDAD,
              :old.COD_BARRIO,
              :old.OBSERVACION,
              :old.NUMERO,
              :old.DEPARTAMENTO,
              :old.PISO,
              :old.EDIFICIO,
              :old.COD_POSTAL,
              :old.USU_INSERCION,
              :old.FEC_INSERCION,
              :old.USU_MODIFICACION,
              :old.FEC_MODIFICACION,
              'U');*/
       end if;
   end if;
END;
/

