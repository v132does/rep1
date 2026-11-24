CREATE OR REPLACE PROCEDURE IT.PRT_GEN_CLA_ACCESO IS
  v_dir_correo      ba_usuarios.dir_correo%type;
  v_clave           bw_ope_claves.clave%TYPE := NULL;
  v_cla_impresa     bw_ope_claves.cla_impresa%TYPE := NULL;
  v_cod_perfil      ge_clientes.cod_perfil%TYPE := 'FULL';
  v_actualizo       boolean;
  v_celular         varchar2(20);
  v_dir_correo_ent  varchar2(100) := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--fug_obt_dir_correo; --'bbvanet@bbva.com.py'
  v_asunto          varchar2(100);
  v_mensaje         varchar2(2000);
  v_resultado       number := 99;
  v_nom_cliente     ba_personas.nom_completo%type;
  v_cod_gestor      ge_clientes.cod_usu_oficial%type;
  v_cod_per_gestor  ba_usuarios.cod_persona%type;
  v_db_name         varchar2(20);
  v_terminal        varchar2(20);
  v_cod_usu         varchar2(10);
  v_cod_origen      varchar2(20);
  v_nro_documento   varchar2(40);
  v_nom_proceso     varchar2(100) := 'PRT_GEN_CLA_ACCESO';
  v_fecha           date := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_ACTUAL(1),fug_obt_ofi_matriz,5);

  CURSOR cuentas
      IS select distinct a.cod_persona
           from ta_tarjetas a, ba_per_fisicas bb, ge_cta_clientes c
          where a.cod_persona = bb.cod_persona
            and a.cod_persona = c.cod_persona
            and a.cod_estado = 6
            and a.fec_activacion >= v_fecha
            and a.vigente = 'S'
            and c.relacion = 'P'
            and not exists (select *
                              from bw_ope_claves b
                             where b.cod_persona = a.cod_persona
                               and b.tip_clave = 'A'
                               and b.est_clave in ('A','M')
                               and b.cod_per_vinculada is null);

  --
  function lf_act_est_clave(p_cod_persona       bw_ope_claves.cod_persona%TYPE,


                            p_cod_per_vinculada bw_ope_claves.cod_per_vinculada%TYPE,
                            p_tipo              varchar2,
                            p_est_clave         bw_ope_claves.est_clave%TYPE )
  return boolean IS
    v_actualizo  boolean;
    v_fec_actual date := pag_cal.fu_obt_fec_actual(1);
    --p_tipo Tipo Clave. Valores: (T/Transaccional, A/Acceso)
  begin
     -- actualizar el valor del estado de la clave a IMPRESA.
     begin
        pre_ini_aplicacion;
        pae_cnf.g_cod_modulo := 1;
     end;
     v_actualizo := true;
     if p_tipo in ('A', 'T') then -- si el tipo de clave es acceso o transaccional
        if p_est_clave = 'A' then
           insert into bw_cla_acciones(usu_insercion, cod_persona, cod_per_vinculada, accion, tip_clave)
           values (user, p_cod_persona, p_cod_per_vinculada, 'A', p_tipo/*'T'*/);
        end if;
        -- Se le llama desde el report GLCLAOPE para tip_clave = 'T'
        -- Se le llama desde el report GLCLAVE  para tip_clave = 'A'
        update bw_ope_claves
           set est_clave         = nvl(p_est_clave, 'I'),
               fec_est_clave     = v_fec_actual,
               cla_impresa       = null,
               usu_impresion     = user,
               fec_impresion     = v_fec_actual,
               cod_ofi_impresion = fug_obt_ofi_usuario(user)
         where cod_persona       = p_cod_persona
           and (
                (p_cod_per_vinculada is null and cod_per_vinculada is null) or
                (p_cod_per_vinculada is not null and cod_per_vinculada = p_cod_per_vinculada)
               )
           and tip_clave = p_tipo;
        if SQL%NOTFOUND then
           v_actualizo := false;
        end if;
     else
        v_actualizo := false;
     end if;
     return(v_actualizo);
  exception
     when others then
        pat_imp.pr_log( substr(v_nom_proceso ||'. Error en LF_ACT_EST_CLAVE '|| sqlerrm, 1,4000) );
        -- raise_application_error(-20000, 'Error en LF_ACT_EST_CLAVE. ' || sqlerrm);
  end;
  --
  FUNCTION lf_obt_cod_per_usuario( p_cod_gestor ge_clientes.cod_usu_oficial%type ) RETURN ba_personas.cod_persona%type is
    v_result ba_personas.cod_persona%type;
  BEGIN
    select cod_persona
      into v_result
      from ba_usuarios
     where cod_usuario = p_cod_gestor;
     RETURN v_result;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  --
  PROCEDURE lp_reg_sol( p_cod_persona IN VARCHAR2,
                        p_tipo_documento IN NUMBER,
                        p_nro_documento IN VARCHAR2,
                        p_fec_nacimiento IN DATE,
                        p_tip_tarjeta IN VARCHAR2,
                        p_nro_tarjeta IN VARCHAR2,
                        p_cod_origen IN VARCHAR2,
                        p_token IN VARCHAR2,
                        p_nro_ip IN VARCHAR2,
                        p_cod_canal IN VARCHAR2,
                        p_cod_oficina in varchar2,
                        p_tip_clave IN VARCHAR2) IS
  BEGIN
     insert into bw_sol_claves( cod_persona, tipo_documento, nro_documento, fec_nacimiento,
                                tip_tarjeta, nro_tarjeta, cod_origen, token,
                                estado, fec_verificacion, nro_ip, cod_canal,
                                cod_oficina, tipo )
     values( p_cod_persona, p_tipo_documento, p_nro_documento, p_fec_nacimiento,
             p_tip_tarjeta, p_nro_tarjeta, p_cod_origen, p_token,
             'S', sysdate, p_nro_ip, p_cod_canal,
             p_cod_oficina, p_tip_clave );
  END;
  --
  function lf_obt_nro_celular(p_cod_persona IN ba_personas.cod_persona%TYPE)
     RETURN ba_telefonos.telefono%type IS
     v_result ba_telefonos.telefono%type;
  BEGIN
      SELECT area||telefono
        INTO v_result
        FROM ba_telefonos
       WHERE cod_persona = p_cod_persona
         AND principal = 'S'
         AND tip_linea = 'C';
     RETURN v_result;
  EXCEPTION
     WHEN no_data_found THEN
        RETURN null;
     WHEN OTHERS THEN
        RETURN null;
  END;

BEGIN

  FOR x IN cuentas LOOP
    BEGIN
      --Limpio variable de resultado
      v_resultado := 99;
      -- Actualizar perfil del cliente
      --lock table ge_clientes in exclusive mode nowait;
      update ge_clientes
         set cod_perfil  = v_cod_perfil
       where cod_persona = x.cod_persona;
      -- Obtener la clave en v_cla_impresa
      v_clave := paw_bce.fu_gen_ope_clave( v_clave,       -- p_clave
                                           x.cod_persona, -- p_cod_persona
                                           null,          -- p_cod_per_vinculada
                                           'C',           -- p_accion
                                           'A',           -- p_tip_clave
                                           v_cla_impresa  -- p_cla_operacion
                                          );
      -- Actualizar el valor del estado de la clave a IMPRESA.
      v_actualizo := lf_act_est_clave( x.cod_persona, --p_cod_persona
                                       null,          --p_cod_per_vinculada,
                                       'A',           --p_tipo
                                       'I'            --p_est_clave
                                       );
      -- Actualizar  el valor del estado de la clave a ACTIVO
      IF v_actualizo THEN
         v_actualizo := lf_act_est_clave( x.cod_persona, --p_cod_persona
                                           null,         --p_cod_per_vinculada,
                                           'A',          --p_tipo
                                           'A'           --p_est_clave
                                           );
      END IF;

      -- Obtener datos para el insert en tm_mails si es necesario
      SELECT upper(sys_context('USERENV', 'DB_NAME')), upper(sys_context('USERENV', 'TERMINAL'))
        INTO v_db_name, v_terminal
        FROM dual;
      v_cod_usu := substr(USER, 1, 10);

      --Obtengo el programa llamado
      v_cod_origen := 'TARJETAS';

      IF NOT v_actualizo THEN
        -- Envío de correo electrónico al gestor del cliente
        v_nom_cliente := fue_obt_nom_persona(x.cod_persona);
        v_cod_gestor  := fug_obt_cod_usu_oficial(x.cod_persona);
        v_cod_per_gestor := lf_obt_cod_per_usuario(v_cod_gestor);
        IF v_cod_per_gestor IS NOT NULL THEN
          v_dir_correo  := fug_obt_dir_mail_usu(v_cod_gestor);--Debe notificar al correo corporativo del gestor BSEVOCORE-5
          v_asunto     := 'Generación automática de su clave de acceso a '||fug_obt_pardinamico('NOM_BANCO')||' Net';
          v_mensaje    := 'Error en la Actualización de la Clave del Cliente '||
                           x.cod_persona||' - '||v_nom_cliente||'. Favor verificar.';
          IF v_dir_correo IS NOT NULL THEN
            begin
             PRG_ENV_MAIL( v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje );
            exception
              when others then
                -- Si hay error al enviar mail se inserta en la tabla tm_mails
                 v_mensaje := v_mensaje||'. Error al enviar mail al Gestor '||v_cod_per_gestor||
                              '. Generación de clave de Acceso a Persona '||x.cod_persona||'.';
                 INSERT INTO tm_mails
                    (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
                 VALUES
                    (v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje, SYSDATE, v_terminal, v_cod_usu, v_db_name);
            end;
          END IF;
        END IF;
      ELSE
        lp_reg_sol( x.cod_persona,                     -- p_cod_persona
                    null,                              -- p_tipo_documento
                    v_nro_documento,                   -- p_nro_documento
                    null,                              -- p_fec_nacimiento
                    null,                              -- p_tip_tarjeta
                    null,                              -- p_nro_tarjeta
                    v_cod_origen,                      -- p_cod_origen
                    null,                              -- p_token
                    null,                              -- p_nro_ip
                    null,                              -- p_cod_canal
                    fug_obt_ofi_cliente(x.cod_persona),-- p_cod_oficina
                    'A'                                -- p_tip_clave
                   );

        -- Envío de SMS al cliente
        v_nom_cliente := fue_obt_nom_persona(x.cod_persona);
        v_celular := lf_obt_nro_celular(x.cod_persona); -- Ver Celular del Cliente
        IF v_celular IS NOT NULL THEN
          v_mensaje    := fug_obt_parentes(6331, 'COD_MEA_CLA_FACIL') || ' Clave: '||v_cla_impresa;
          v_resultado:= paw_not.fu_env_sms_prueba( v_celular,
                                                   v_mensaje,
                                                   v_cod_origen );
        ELSE
          --cancelo la clave generada
          Update bw_ope_claves a
             Set a.est_clave   = 'X'
           Where a.cod_persona = x.cod_persona
             and a.est_clave = 'A'
             and a.tip_clave = 'A'
             and a.cod_per_vinculada is null
             and trunc(a.fec_modificacion) = trunc(sysdate);
          --
          v_asunto  := 'Generación automática de su clave de acceso a '||fug_obt_pardinamico('NOM_BANCO')||' Net';
          v_mensaje := 'Error en envio de SMS. Cliente '||x.cod_persona||' - '||v_nom_cliente||' sin telefono asignado.';
          INSERT INTO tm_mails
             (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
          VALUES
             (v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje, SYSDATE, v_terminal, v_cod_usu, v_db_name);
        END IF;

        --mensaje enviado con error
        IF v_resultado <> 0 THEN
          --cancelo la clave generada
          Update bw_ope_claves a
             Set a.est_clave   = 'X'
           Where a.cod_persona = x.cod_persona
             and a.est_clave = 'A'
             and a.tip_clave = 'A'
             and a.cod_per_vinculada is null
             and trunc(a.fec_modificacion) = trunc(sysdate);
          --
          v_asunto  := 'Generación automática de su clave de acceso a '||fug_obt_pardinamico('NOM_BANCO')||' Net';
          v_mensaje := 'La clave de acceso a '||fug_obt_pardinamico('NOM_BANCO')||' Net generada al cliente '||x.cod_persona||' - '||v_nom_cliente||' ha sido anulada, debido a que el Servicio de Mensajería no está disponible';
          INSERT INTO tm_mails
             (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
          VALUES
             (v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje, SYSDATE, v_terminal, v_cod_usu, v_db_name);
        ELSE
          -- Envío de correo electrónico al cliente
          v_dir_correo := fug_obt_dir_mail_per(x.cod_persona);
          v_asunto     := 'Generación automática de su clave de acceso a '||fug_obt_pardinamico('NOM_BANCO')||' Net';
          v_mensaje    := 'Le informamos que se ha generado automáticamente su Clave de Acceso a '||
                          fug_obt_pardinamico('NOM_BANCO')||' Net. Ya puede ingresar con su clave recibida vía SMS a su cuenta '||
                          'en '||fug_obt_pardinamico('URL_BANCO')||' opción "Acceso de Usuarios." '||CHR(13)||
                          'Facilite todas sus consultas de cuenta, pagos y operaciones desde donde esté, '||
                          'descargando el aplicativo de Banca Móvil "'||fug_obt_pardinamico('NOM_BANCO')||'" desde el Play Store '||
                          'o Appstore, o haciendo click en https://goo.gl/KjlkPl ';
          IF v_dir_correo IS NOT NULL THEN
            begin
               PRG_ENV_MAIL( v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje );
            exception
              when others then
                 --El correo no ha sido enviado
                 v_mensaje := v_mensaje||'. Error al enviar mail al Cliente'||
                              '. Generación de clave de Acceso a Persona '||x.cod_persona||'.';
                 INSERT INTO tm_mails
                    (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
                 VALUES
                    (v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje, SYSDATE, v_terminal, v_cod_usu, v_db_name);
            end;
          ELSE
             --El correo del cliente es nulo
             v_mensaje := v_mensaje||'. Error. Cliente sin dirección de correo'||
                          '. Generación de clave de Acceso a Persona '||x.cod_persona||'.';
             INSERT INTO tm_mails
                (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
             VALUES
                (v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje, SYSDATE, v_terminal, v_cod_usu, v_db_name);
          END IF;

          -- Envío de correo electrónico al gestor del cliente
          v_cod_gestor  := fug_obt_cod_usu_oficial(x.cod_persona);
          v_cod_per_gestor := lf_obt_cod_per_usuario(v_cod_gestor);
          IF v_cod_per_gestor IS NOT NULL THEN
            v_dir_correo  := fug_obt_dir_mail_usu(v_cod_gestor);--Debe notificar al correo corporativo del gestor BSEVOCORE-5
            v_mensaje     := 'Se ha generado una clave de acceso a '||fug_obt_pardinamico('NOM_BANCO')||' Net de forma automática a su cliente '||
                             x.cod_persona||' - '||v_nom_cliente;
            IF v_dir_correo IS NOT NULL THEN
              begin
               PRG_ENV_MAIL( v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje );
              exception
                when others then
                   --El correo no ha sido enviado
                   v_mensaje := v_mensaje||'. Error al enviar mail al Gestor'||
                                '. Generación de clave de Acceso a Persona '||x.cod_persona||'.';
                   INSERT INTO tm_mails
                      (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
                   VALUES
                      (v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje, SYSDATE, v_terminal, v_cod_usu, v_db_name);
              end;
            ELSE
               --El correo del gestor es nulo
               v_mensaje := v_mensaje||'. Error. Gestor sin dirección de correo'||
                            '. Generación de clave de Acceso a Persona '||x.cod_persona||'.';
               INSERT INTO tm_mails
                  (env_por, env_para, asunto, detalles, fec_sistema, nom_maquina, cod_usuario, sid_base)
               VALUES
                  (v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje, SYSDATE, v_terminal, v_cod_usu, v_db_name);
            END IF;
          END IF;
        END IF;
      END IF;
    END;
  END LOOP;
EXCEPTION
  when others then
    pat_imp.pr_log( substr(v_nom_proceso ||'. Error en el proceso de Generación de Clave. '|| sqlerrm, 1,4000) );
    --RAISE_APPLICATION_ERROR(-20251, 'El ultimo numero de tarjeta ejecutado es ' ||'. '||SQLERRM );
END PRT_GEN_CLA_ACCESO;
/

