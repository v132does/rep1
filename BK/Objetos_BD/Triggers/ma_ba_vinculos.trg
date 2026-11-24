CREATE OR REPLACE TRIGGER IT.MA_BA_VINCULOS
 AFTER DELETE OR INSERT OR UPDATE
 ON BA_VINCULOS
 FOR EACH ROW
declare
  v_cod_tip_documento MI_IT_BA_PERSONAS_01.COD_TIP_DOCUMENTO%TYPE;
  v_nro_documento     MI_IT_BA_PERSONAS_01.NRO_DOCUMENTO%TYPE; 
begin
   -- Registrar campos de migracion
   if inserting then
      if :new.tipo in ('AC','E','RE','CD','CT','DI','DS','DT','P','R','S','V','A') then
         PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                       v_cod_tip_documento,
                                       v_nro_documento);

        insert
        into MI_IT_BA_VINCULOS
              (
                  COD_PERSONA,
                  COD_TIP_DOCUMENTO,
                  NRO_DOCUMENTO,
                  COD_PER_VINCULO,
                  TIPO,
                  FEC_VENCIMIENTO,
                  USU_INSERCION,
                  FEC_INSERCION,
                  USU_MODIFICACION,
                  FEC_MODIFICACION,
                  COD_PERFIL,
                  EST_MIGRACION
                )
         values
             (
                  :new.COD_PERSONA,
                  v_cod_tip_documento,
                  v_nro_documento,
                  :new.COD_PER_VINCULO,
                  :new.TIPO,
                  :new.FEC_VENCIMIENTO,
                  :new.USU_INSERCION,
                  :new.FEC_INSERCION,
                  :new.USU_MODIFICACION,
                  :new.FEC_MODIFICACION,
                  :new.COD_PERFIL,
                  'I');
      end if;
   elsif updating then
      if (:new.tipo in ('AC','E','RE','CD','CT','DI','DS','DT','P','R','S','V','A')
      or :old.tipo in ('AC','E','RE','CD','CT','DI','DS','DT','P','R','S','V','A'))
      and (:new.cod_persona <> :old.cod_persona or :new.cod_per_vinculo <> :old.cod_per_vinculo
        or :new.tipo <> :old.tipo) then
         PRA_ACT_MI_IT_BA_PERSONAS_01(:old.COD_PERSONA,
                                       v_cod_tip_documento,
                                       v_nro_documento);
        --- Siempre que hay un cambio en la PK se elimina el anterior e ingresa el nuevo
        --- Realizado por ICL 20090723
        if :new.tipo in ('AC','E','RE','CD','CT','DI','DS','DT','P','R','S','V','A') then
          insert
          into MI_IT_BA_VINCULOS
                (
                    COD_PERSONA,
                    COD_TIP_DOCUMENTO,
                    NRO_DOCUMENTO,
                    COD_PER_VINCULO,
                    TIPO,
                    FEC_VENCIMIENTO,
                    USU_INSERCION,
                    FEC_INSERCION,
                    USU_MODIFICACION,
                    FEC_MODIFICACION,
                    COD_PERFIL,
                    EST_MIGRACION
                  )
           values
               (
                    :old.COD_PERSONA,
                    v_cod_tip_documento,
                    v_nro_documento,                
                    :old.COD_PER_VINCULO,
                    :old.TIPO,
                    :old.FEC_VENCIMIENTO,
                    :old.USU_INSERCION,
                    :old.FEC_INSERCION,
                    :old.USU_MODIFICACION,
                    :old.FEC_MODIFICACION,
                    :old.COD_PERFIL,
                    'D');
        end if;
        if :old.tipo in ('AC','E','RE','CD','CT','DI','DS','DT','P','R','S','V','A') then
           PRA_ACT_MI_IT_BA_PERSONAS_01(:new.COD_PERSONA,
                                         v_cod_tip_documento,
                                         v_nro_documento);
          insert
          into MI_IT_BA_VINCULOS
                (
                    COD_PERSONA,
                    COD_TIP_DOCUMENTO,
                    NRO_DOCUMENTO,
                    COD_PER_VINCULO,
                    TIPO,
                    FEC_VENCIMIENTO,
                    USU_INSERCION,
                    FEC_INSERCION,
                    USU_MODIFICACION,
                    FEC_MODIFICACION,
                    COD_PERFIL,
                    EST_MIGRACION
                  )
           values
               (
                    :new.COD_PERSONA,
                    v_cod_tip_documento,
                    v_nro_documento,                
                    :new.COD_PER_VINCULO,
                    :new.TIPO,
                    :new.FEC_VENCIMIENTO,
                    :new.USU_INSERCION,
                    :new.FEC_INSERCION,
                    :new.USU_MODIFICACION,
                    :new.FEC_MODIFICACION,
                    :new.COD_PERFIL,
                    'I');
          end if;
      end if;
   elsif deleting then
      if :old.tipo in ('AC','E','RE','CD','CT','DI','DS','DT','P','R','S','V','A') then
           PRA_ACT_MI_IT_BA_PERSONAS_01(:old.COD_PERSONA,
                                         v_cod_tip_documento,
                                         v_nro_documento);

          insert
          into MI_IT_BA_VINCULOS
                (
                    COD_PERSONA,
                    COD_TIP_DOCUMENTO,
                    NRO_DOCUMENTO,                
                    COD_PER_VINCULO,
                    TIPO,
                    FEC_VENCIMIENTO,
                    USU_INSERCION,
                    FEC_INSERCION,
                    USU_MODIFICACION,
                    FEC_MODIFICACION,
                    COD_PERFIL,
                    EST_MIGRACION
                  )
           values
               (
                    :old.COD_PERSONA,
                    v_cod_tip_documento,
                    v_nro_documento,                
                    :old.COD_PER_VINCULO,
                    :old.TIPO,
                    :old.FEC_VENCIMIENTO,
                    :old.USU_INSERCION,
                    :old.FEC_INSERCION,
                    :old.USU_MODIFICACION,
                    :old.FEC_MODIFICACION,
                    :old.COD_PERFIL,
                    'D');
      end if;
   end if;
END;
/

