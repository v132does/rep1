CREATE OR REPLACE TRIGGER IT.TA_BA_PERSONAS
  after INSERT OR UPDATE OR DELETE on "IT"."BA_PERSONAS"
  for each row

declare
  v_tip_doc_ofac ba_personas.cod_tip_documento%type := fug_obt_pardinamico('TIP_DOC_OFAC');
  -- Variables locales
   v_ver_persona     varchar2(01);
   v_existe_doc      varchar2(01);
   v_cod_usuario     ba_usuarios.cod_usuario%type;
   v_dir_correo      ba_usuarios.dir_correo%type;
   v_nro_cuenta      ge_cuentas.nro_cuenta%TYPE;
   v_nro_cta_gp      ge_cuentas.nro_cuenta%TYPE;    
   v_fec_actual      ge_calendarios.fec_actual%TYPE;
   v_resultado       varchar2(250);  --HA-1115
   --- Insertar actividad en agenda
   /* Anular envio de mail al verificador, comentado a pedido del cliente por AP 2659
   PROCEDURE LP_INS_AGENDA
     (p_cod_persona in ge_cta_clientes.cod_persona%type
     ,p_cod_usuario in ba_usuarios.cod_usuario%type
     ,p_dir_correo  in ba_usuarios.dir_correo%type
     ) IS
   BEGIN
      ---03-may-05 Ver Req: 451 - Ya no generar agenda al operativo, si mail
      --- Generar agenda al verificador
      --insert into cr_agendas
      --  (cod_agenda, cod_persona, cod_usu_encargado,
      --   cod_actividad, cod_estado, cod_mot_actividad, fec_actividad,
      --   det_actividad)
      --values
      --  (s_cod_agenda.nextval, p_cod_persona, p_cod_usuario,
      --   3, 1, 21, pag_cal.FU_OBT_FEC_ACTUAL(3),
      --   'El usuario '||USER||' solicita verificacion de la persona '||to_char(p_cod_persona)
      --);
      --anulado hasta aqui
      --- Enviar mail al verificador
      if p_dir_correo is not null then
        it_mail.mail(fug_obt_dir_correo,
                   p_dir_correo,
                   'Solicitud de Verificacion',
                   'El usuario '||USER||' solicita verificacion de datos de la persona '||to_char(p_cod_persona)||'.');
      end if;
   END;
   */
BEGIN
  -- Verificamos el origen del dato, si es compra de cartera debe retornar
    if (inserting or updating) and 
       pae_cnf.G_PROGRAMA = 'GPPROFIN' and 
       instr(fug_obt_pardinamico('USU_CAR_COMPRAS'),user) > 0 then
      return;
    end if;
if user <> 'IT' and :new.cod_tip_documento <> v_tip_doc_ofac then
  -- No se controlan los datos de interface hechos a traves de IT, o los datos
  -- ingresados a traves de la OFAC.
   If updating then
     If :old.tipo <> :new.tipo then
       if :old.tipo = 'F' then
         delete BA_PER_FISICAS where cod_persona = :old.cod_persona;
       elsif :old.tipo = 'J' then
         delete BA_PER_JURIDICAS where cod_persona = :old.cod_persona;
       End if;
     End if;
   End if;
   
     if inserting or updating then
       if instr(fug_obt_pardinamico('USU_ONB_PERSONAS'),','||user||',') = 0 then
        v_ver_persona := fug_obt_pardinamico('VER_PERSONA');
        prg_obt_usu_verificador('EMVERDPE',user, v_cod_usuario, v_dir_correo,
                                :new.cod_persona);
       end if;
     end if;
   /* Anular envio de mail al verificador, comentado a pedido del cliente por AP 2659
   if inserting and v_ver_persona = 'S'
   and v_cod_usuario is not null
   and :new.est_verificacion = 'N'
   then
      --- Generar agenda al verificador
      LP_INS_AGENDA(:new.cod_persona, v_cod_usuario, v_dir_correo);
   end if;
   if  updating
   and :new.est_verificacion <> :old.est_verificacion
   and :new.est_verificacion = 'N'
   and v_cod_usuario is not null
   and v_ver_persona = 'S' then
      --- Generar agenda al verificador
      LP_INS_AGENDA(:new.cod_persona, v_cod_usuario, v_dir_correo);
   end if;
   */
end if;
/*
|| Control de Datos para Ordenes de domiciliacion SIPAP (MT104)
*/
if updating then
  if  :old.cod_tip_documento <> :new.cod_tip_documento
       or  :old.nro_documento <> :new.nro_documento then
      
      update sb_snp_catastros a 
        set a.nro_doc_solicitante = :new.nro_documento,
            a.cod_tip_doc_solicitante = :new.cod_tip_documento
     where a.nro_doc_solicitante = :old.nro_documento;

      update sb_snp_catastros a 
        set a.nro_doc_receptor = :new.nro_documento,
            a.cod_tip_doc_receptor = :new.cod_tip_documento
     where a.nro_doc_receptor = :old.nro_documento;
      
  end if;
end if;

if inserting then
   IF :new.cod_persona IS NOT NULL THEN
      insert into cr_per_tip_operaciones(cod_persona, cod_moneda, fec_inicio, fec_vencimiento, mto_limite)
            values(:new.cod_persona, pag_gen.FU_OBT_MON_LOCAL, pag_cal.FU_OBT_FEC_ACTUAL(1), add_months(pag_cal.FU_OBT_FEC_ACTUAL(1),12), to_number(fug_obt_pardinamico('CRM_MTO_DEF_LOA')));
         if nvl(fug_obt_pardinamico('REQ_VER_PER_PERFIL'),'N') ='S'  and user not in ('PERSONS','APITRANSAC') then
            v_resultado := fuc_ver_per_persona(:new.cod_persona, 'M');
         elsif user IN ('PERSONS','APITRANSAC') then
            begin   
              pre_ins_dat_adicionales(:new.cod_persona, 'A');
            exception
              when others then
              null;
            end;          
         end if;
   END IF;
end if;

if updating then
   IF fug_obt_pardinamico( 'ENV_MOD_TARJETA' ) = 'S' THEN
       if  :old.cod_tip_documento <> :new.cod_tip_documento
       or  :old.nro_documento <> :new.nro_documento then
          DECLARE
            v_fec_actual DATE := pag_cal.fu_obt_fec_actual(5);
            CURSOR cuentas
                IS select c.nro_cuenta
                     from ge_cta_clientes c, ta_cta_tarjetas t
                    where c.cod_persona = :new.cod_persona
                      and c.nro_cuenta  = t.nro_cuenta
                      and c.relacion    = 'P'
                      and t.estado      <> 'C'
                      AND fut_obt_procesadora(c.nro_cuenta) != fug_obt_pardinamico('COD_ENT_GLOBAL');
          BEGIN
            FOR d IN cuentas LOOP
              BEGIN
                  update ta_cta_tarjetas_nov
                     set enviado   = 'N',
                         aprobado  = 'N',
                         nro_acta  = null,
                         niv_aprobacion = null,
                         nro_documento  = :new.nro_documento
                   where nro_cuenta = d.nro_cuenta
                     and fecha = v_fec_actual;
                  IF SQL%NOTFOUND THEN
                    BEGIN
                      insert into ta_cta_tarjetas_nov(nro_cuenta,
                                                      fecha,
                                                      enviado,
                                                      aprobado,
                                                      nro_documento)
                                               values(d.nro_cuenta,
                                                      v_fec_actual,
                                                      'N',
                                                      'N',
                                                      :new.nro_documento);
                    EXCEPTION
                      when others then
                        IF sqlcode <= -20000 THEN
                          RAISE;
                        ELSE
                          RAISE_APPLICATION_ERROR( -20412, 'No se pudo insertar la novedad para la tarjeta ' || sqlerrm );
                        END IF;
                    END;
                  END IF;
              EXCEPTION
                when others then
                  IF sqlcode <= -20000 THEN
                    RAISE;
                  ELSE
                    RAISE_APPLICATION_ERROR( -20413, 'No se pudo actualizar la novedad para la tarjeta ' || sqlerrm );
                  END IF;
              END;
          END LOOP;
        END;
    end if;
  end if;
    -- Novedades Global Processing --
  IF fug_obt_pardinamico('ENV_MOD_TARJETA_GP') = 'S' THEN
    IF :old.dir_correo <> :new.dir_correo THEN
      v_dir_correo := substr(:new.dir_correo,1,40);
      v_fec_actual := pag_cal.fu_obt_fec_actual(5);
      BEGIN
        SELECT c.nro_cuenta, t.nro_cta_global
          INTO v_nro_cuenta, v_nro_cta_gp
          FROM ge_cta_clientes c, ah_tar_debitos t
         WHERE c.nro_cuenta = t.nro_cuenta
           AND c.relacion = 'P'
           AND c.cod_persona = :old.cod_persona
           AND t.nro_cta_global IS NOT NULL
           AND t.cod_ent_procesadora = fug_obt_pardinamico('COD_ENT_GLOBAL')
           AND rownum = 1;
      EXCEPTION
        WHEN OTHERS THEN
          v_nro_cuenta := null;
          v_nro_cta_gp := null;
      END;
      IF v_nro_cuenta IS NOT NULL THEN
        BEGIN
          UPDATE ta_glp_cuentas_nov
             SET dir_correo = v_dir_correo, enviado = 'N'
           WHERE nro_cuenta = v_nro_cuenta
             AND nro_cta_global = v_nro_cta_gp
             AND fec_novedad = v_fec_actual;
          IF SQL%NOTFOUND THEN
            INSERT INTO ta_glp_cuentas_nov
              (nro_cuenta,
               nro_cta_global,
               dir_correo,
               fec_novedad,
               enviado)
            VALUES
              (v_nro_cuenta,
               v_nro_cta_gp,
               v_dir_correo,
               v_fec_actual,
               'N');
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            IF SQLCODE <= -20000 THEN
              RAISE;
            ELSE
              raise_application_error(-20414,
                                      'No se pudo insertar la novedad para la tarjeta ' ||
                                      SQLERRM);
            END IF;
        END;
      END IF;
    END IF;
  END IF;
 end if;
 /*
 || MDP-CON_ ARC_REC_BAN
 | Conciliacion Archivos Recibidos de Bancard
 */
 if (inserting and
    :new.cod_tip_documento = 10 and
    :new.obs_verificacion = 'DATOS DE SIPRO') then
    null; --- DYDMR-2087
 elsif inserting or (updating and
    (:new.cod_tip_documento <> :old.cod_tip_documento or
     :new.nro_documento <> :old.nro_documento)) THEN
    --Verifica si existe
    BEGIN
      SELECT DISTINCT ('S')
        INTO v_existe_doc
        FROM ba_per_documentos
       WHERE cod_persona = :new.cod_persona
         AND cod_tip_documento = :old.cod_tip_documento
         AND nro_documento = :old.nro_documento;
    EXCEPTION
      WHEN no_data_found THEN
         v_existe_doc := 'N'; 
    END;
    
    IF v_existe_doc = 'S' THEN
      DELETE FROM ba_per_documentos
       WHERE cod_persona = :new.cod_persona
         AND cod_tip_documento = :old.cod_tip_documento
         AND nro_documento = :old.nro_documento;
    END IF;
         
    BEGIN
       INSERT INTO ba_per_documentos
          (cod_persona, cod_tip_documento, nro_documento,
           fec_vto_documento, cod_pai_documento)
       VALUES
          (:new.cod_persona, :new.cod_tip_documento, :new.nro_documento,
           :new.fec_vto_documento, :new.cod_pai_documento);
    EXCEPTION
       WHEN DUP_VAL_ON_INDEX THEN
           update ba_per_documentos
             set fec_vto_documento = :new.fec_vto_documento,
                 cod_pai_documento = :new.cod_pai_documento
           where cod_persona = :new.cod_persona
             and cod_tip_documento = :new.cod_tip_documento
             and nro_documento = :new.nro_documento;
       WHEN OTHERS THEN
          RAISE_APPLICATION_ERROR( -20414, 'Al Act.Per.Documentos: ' || sqlerrm );
    END;
    ---      
 end if;
end TA_BA_PERSONAS;
/
