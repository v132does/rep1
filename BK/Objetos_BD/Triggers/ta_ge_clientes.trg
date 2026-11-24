CREATE OR REPLACE TRIGGER IT.TA_GE_CLIENTES
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_CLIENTES
 FOR EACH ROW

DECLARE
   --- Inicializar variables de cambio de Grupos Economicos
   --v_cod_persona       ge_clientes.cod_persona%type;
   --v_nom_completo      ba_personas.nom_completo%type;
   --v_old_descripcion   ge_gru_economicos.descripcion%type;
   --v_new_descripcion   ge_gru_economicos.descripcion%type;
   v_fec_actual        ge_calendarios.fec_actual%type;-- := pag_cal.FU_OBT_FEC_ACTUAL(1);
   v_observacion       GE_CLI_INFORMACIONES.Observacion%type;
   --v_remitente         VARCHAR2(100);--:= fug_obt_dir_correo;
   --v_dir_cor_varios    VARCHAR2(100);--:= FUG_OBT_PARDINAMICO('DIR_COR_CAM_GRU_ECONOMICO');
   --- Inicializar variables de verificación
   v_ver_persona     varchar2(01);
   v_can_cli_grupo   number(5);
   v_error           varchar2(1000);

   --- Cursor de cuentas del cliente donde es Principal
   CURSOR c_ge_cta_clientes IS
   SELECT cod_modulo, cod_modalidad, cod_oficina, nro_cuenta
   FROM ge_cta_clientes
   WHERE cod_modulo IN (3,4,6,7,8)
   AND cod_persona = :new.cod_persona
   AND relacion = 'P';

BEGIN
   IF updating THEN
      --- Si se modifica el datos del tipo de deudor Generar Cambio de Estado si posee cuentas
      IF :new.residente        <> :old.residente
      OR :new.cod_sec_contable <> :old.cod_sec_contable
      OR :new.cod_tip_deudor   <> :old.cod_tip_deudor   THEN
         --- Verificar si posee cuentas
		IF  pag_ccl.fu_ver_tip_valido(:new.cod_sec_contable, :new.residente, :new.cod_tip_deudor) = 'S'
         AND pag_ccl.fu_ver_tip_valido(:old.cod_sec_contable, :old.residente, :old.cod_tip_deudor) = 'S' THEN 
         --AND NVL(PAE_CNF.FU_OBT_COD_PROGRAMA,'X') <> 'EMSECCLI' THEN  --DYDMR-2915
            FOR ctas IN c_ge_cta_clientes LOOP
               pag_ccl.pr_gen_tra_cta(ctas.cod_modulo, ctas.cod_modalidad,
               ctas.cod_oficina, ctas.nro_cuenta,
               :old.cod_sec_contable, :old.residente, :old.cod_tip_deudor,
               :new.cod_sec_contable, :new.residente, :new.cod_tip_deudor);
            END LOOP;
         END IF;
      END IF;

      --- verifico si existe verificacion de personas
      v_ver_persona := fug_obt_pardinamico('VER_PERSONA');
      IF (:new.residente                <> :old.residente
      OR :new.cod_sec_contable          <> :old.cod_sec_contable
      OR :new.cod_tip_deudor            <> :old.cod_tip_deudor
      OR nvl(:new.cod_gru_economico,-1) <> nvl(:old.cod_gru_economico,-1))
      AND v_ver_persona = 'S' THEN
         UPDATE ba_personas
         SET est_verificacion = 'N'
         WHERE cod_persona = :new.cod_persona
         AND est_verificacion = 'V';
      END IF;
      
      IF nvl(:new.cat_subjetiva,0) <> nvl(:old.cat_subjetiva, 0) then
         begin
           select observacion
             into v_observacion
             from GE_CLI_INFORMACIONES
            where COD_PERSONA = :new.cod_persona 
              and INFORMACION = 'CATEGORIA'
              and DAT_INFORMACION = :new.cat_subjetiva;
         exception
           when others then
             v_observacion := null;
         end;
         v_fec_actual := pag_cal.FU_OBT_FEC_ACTUAL(1);
         insert into ge_cat_subjetiva_his (fecha,
                                           cod_persona,
                                           cod_gru_economico,
                                           cat_subjetiva,
                                           cat_subjetiva_ant,
                                           cat_automatica,
                                           observacion,
                                           tot_deu_real,
                                           tot_gar_computables)
          values ( v_fec_actual,
                   :new.cod_persona,
                   :new.cod_gru_economico,
                   :new.cat_subjetiva,
                   :old.cat_subjetiva,
                   :new.cat_automatica,
                   v_observacion,
                   :new.tot_deu_real,
                   :new.tot_gar_computables);
                   
     END IF;                                                      
   END IF;

   /*IF (inserting AND :new.cod_gru_economico IS NOT NULL)
   OR (updating AND nvl(:new.cod_gru_economico,0) <> nvl(:old.cod_gru_economico,0))
   OR (deleting AND :old.cod_gru_economico IS NOT NULL) THEN

      IF :new.cod_gru_economico is not null THEN
         SELECT g.descripcion
         INTO   v_new_descripcion
         FROM   ge_gru_economicos g
         WHERE  g.cod_gru_economico = :new.cod_gru_economico;
      END IF;
      IF :old.cod_gru_economico is not null THEN
         SELECT g.descripcion
         INTO   v_old_descripcion
         FROM   ge_gru_economicos g
         WHERE  g.cod_gru_economico = :old.cod_gru_economico;
      END IF;

      IF inserting OR updating THEN
         v_cod_persona := :new.cod_persona;
      ELSE
         v_cod_persona := :old.cod_persona;
      END IF;

      SELECT b.nom_completo
      INTO   v_nom_completo
      FROM   ba_personas b
      WHERE  b.cod_persona = v_cod_persona;
      
      v_remitente := fug_obt_dir_correo;
      v_dir_cor_varios := FUG_OBT_PARDINAMICO('DIR_COR_CAM_GRU_ECONOMICO');
      it_mail.mail (v_remitente,
                    v_dir_cor_varios,
                    'Modificacion de integrantes de Grupo Economico.',
                    'Esta persona fue modificada (incluida o excluida) de un grupo economico'||CHR(10)||
                    'Codigo de Persona: '||v_cod_persona||' '||v_nom_completo||CHR(10)||
                    'Viejo Cod del Grupo economico: '||:old.cod_gru_economico||' '||v_old_descripcion||CHR(10)||
                    'Nuevo Cod del Grupo economico: '||:new.cod_gru_economico||' '||v_new_descripcion);
	END IF;*/

   IF updating THEN

    if nvl(:old.cod_gru_economico,0) <> nvl(:new.cod_gru_economico,0) then
      if :old.cod_gru_economico is not null then
         begin
          ---Verifica cantidad de clientes con el mismo grupo
          select count(*)
            into v_can_cli_grupo
            from pr_gru_lin_aplicaciones gr
           where gr.cod_gru_economico = :old.cod_gru_economico;
         exception
            when no_data_found then
              v_can_cli_grupo := 0;
            when others then
              v_can_cli_grupo := -1;
         end;
      ---No se realiza ninguna acción por que no se encontraron datos para procesar
      If nvl(v_can_cli_grupo,0) != 0 then
         If nvl(v_can_cli_grupo,0) > 1 then
           ----Se debe enviar los datos al proceso para que se pueda recalcular los limites globales
           PRG_ACT_GRU_ECO_CLIENTES(:new.cod_persona, :old.cod_gru_economico, :new.cod_gru_economico);
         Else
           raise_application_error(-20000,'TA_GE_CLIENTES - No se puede actualizar Grupo Econ. sin antes eliminar la linea Global :'
                                        ||' Favor vuelva asignar el mismo grupo. -'||sqlerrm);
         End if;
       End if;
      End if;
    End if;
  END IF;

  IF inserting THEN
    begin --DYDMR-4542
     insert into ba_per_dat_adicionales ( cod_persona,parametro,val_parametro) values
     (:new.cod_persona,'ENV_INFORMCONF','S');
    exception
      when others then
        /* Para que no cancele el proceso de carga de cliente si el 
           cliente ya tiene registro en ba_per_dat_adionales (ERROR DE PK)
        */
       NULL;
    end;
  END IF;
  ----CRO-CAT_FAS_DOS: se excluye porción de código por que el control de Catastros se realizará por Cuenta
  ---LCabrera Octubre/2014
  /*IF inserting or updating THEN
    ----CROOC-6 - OFICINA DE CATASTRO : ITC-LCABRERA 05/2014
    ---procedimiento para insertar datos en documentos de catastros.
    PRG_INS_DOC_CATASTRO(:new.cod_persona);
   END IF;*/

  IF deleting THEN
     delete ba_per_dat_adicionales
     where cod_persona=:old.cod_persona
     and parametro = 'ENV_INFORMCONF';
  END IF;
  
   if updating then
    if (nvl(:new.cod_seg_cliente,0) <> nvl(:old.cod_seg_cliente,0)) or
       (nvl(:new.cod_usu_oficial,0) <> nvl(:old.cod_usu_oficial,0)) then
      begin
        insert into IT.CR_ACT_CLIENTES
          (CODIGO, FECHA_CREACION)
        values
          (:new.cod_persona, sysdate);
      exception
        when others then
          v_error :='En insert CR_ACT_CLIENTES Persona: '||:new.cod_persona||' Error: '||substr(sqlerrm,1,1000);
          prg_ins_log_errores('TA_GE_CLIENTES',v_error);
      end;
    end if;
  end if;
  
  if inserting or deleting then
      begin
        insert into IT.CR_ACT_CLIENTES
          (CODIGO, FECHA_CREACION)
        values
          (nvl(:new.cod_persona,:old.cod_persona), sysdate);
      exception
        when others then
          v_error :='En insert CR_ACT_CLIENTES Persona: '||:new.cod_persona||' Error: '||substr(sqlerrm,1,1000);
          prg_ins_log_errores('TA_GE_CLIENTES',v_error);
      end;
  end if;
  
END;
/
