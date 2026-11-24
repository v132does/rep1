CREATE OR REPLACE TRIGGER IT.ta_ge_cta_clientes
 AFTER DELETE OR INSERT OR UPDATE
 ON GE_CTA_CLIENTES
 FOR EACH ROW
--https://itti-digital.atlassian.net/browse/NVB-3811
DECLARE
   --- Inicializar variables de cambio estado cliente
   v_cod_sec_con_act ge_clientes.cod_sec_contable%type;
   v_res_act         ge_clientes.residente%type;
   v_cod_tip_deu_act ge_clientes.cod_tip_deudor%type;
   v_cod_sec_con_ant ge_clientes.cod_sec_contable%type;
   v_res_ant         ge_clientes.residente%type;
   v_cod_tip_deu_ant ge_clientes.cod_tip_deudor%type;
   v_cod_moneda      ge_cuentas.cod_moneda%type;
   v_ver_cuenta      varchar2(01) := fug_obt_pardinamico('VER_CUENTA');
   v_cod_usuario     ba_usuarios.cod_usuario%type;
   v_dir_correo      ba_usuarios.dir_correo%type;
   --- ISSUE 1089 - AP 2902 - INTERFAZ SUMINISTRO DATOS IT Y RECOVERY STRATEGY
   v_relacion        co_cta_clientes.relacion%TYPE;
   v_secuencia       co_cta_clientes.secuencia%TYPE;
   v_adicion         NUMBER;
   v_cur_secuencia   co_cta_clientes.secuencia%TYPE;

   --CANCF-198 -- Clave Fácil - Cliente Nuevo -- 02/02/2015 CN
   v_clave           bw_ope_claves.clave%TYPE := NULL;
   v_cla_impresa     bw_ope_claves.cla_impresa%TYPE := NULL;
   v_cod_perfil      ge_clientes.cod_perfil%TYPE := 'FULL';
   v_actualizo       boolean;
   v_celular         varchar2(20);--ba_telefonos.telefono%type;
   v_dir_correo_ent  varchar2(100) := fug_obt_dir_correo; 
   v_asunto          varchar2(100);
   v_mensaje         varchar2(2000);
   v_resultado       number := 99;
   v_nom_cliente     ba_personas.nom_completo%type;
   v_cod_gestor      ge_clientes.cod_usu_oficial%type;
   v_cod_per_gestor  ba_usuarios.cod_persona%type;
   v_db_name         varchar2(20);
   v_terminal        varchar2(20);
   v_cod_usu         varchar2(10);
   v_cod_origen      varchar2(40);
   v_nro_documento   varchar2(40) := fue_obt_nro_doc_persona(:new.cod_persona);
   v_cod_persona     ge_clientes.cod_persona%TYPE := NULL;
   --CANCF-198 -- Clave Fácil - Cliente Nuevo --  CN: 02/02/2015

   /** Cursor que Recupera los datos de Relación Cuenta-Cliente excepto los principales. **/
   CURSOR relacion IS
      SELECT cod_persona, nro_cuenta, relacion, secuencia
        FROM co_cta_clientes
       WHERE cod_persona = :new.cod_persona
         AND (cod_persona, nro_cuenta) NOT IN
             (SELECT cod_persona, nro_cuenta
                FROM co_cta_clientes
               WHERE cod_persona = :new.cod_persona
                 AND nro_cuenta <> :new.nro_cuenta
                 AND relacion = 'T'
                 AND secuencia = 1)
       ORDER BY nro_cuenta;
   --- ISSUE 1089 - AP 2902 - INTERFAZ SUMINISTRO DATOS IT Y RECOVERY STRATEGY

   --- Insertar actividad en agenda
   PROCEDURE LP_INS_AGENDA
     (p_nro_cuenta in ge_cta_clientes.nro_cuenta%type
     ,p_cod_usuario in ba_usuarios.cod_usuario%type
     ,p_dir_correo  in ba_usuarios.dir_correo%type
     ,p_cod_persona in ba_personas.cod_persona%type
     ) IS
   BEGIN
      if p_cod_persona is not null then
        --- Generar agenda al verificador
        insert into cr_agendas
          (cod_agenda, cod_persona,cod_usu_encargado,
           cod_actividad, cod_estado, cod_mot_actividad, fec_actividad,
           det_actividad)
        values
          (s_cod_agenda.nextval, p_cod_persona, p_cod_usuario,
           3, 1, 21, pag_cal.FU_OBT_FEC_ACTUAL(3),
           'El usuario '||USER||' solicita verificación de la Cuenta '||p_nro_cuenta
        );
        --- Enviar mail al verificador
       if p_dir_correo is not null then
          it_mail.mail(fug_obt_dir_correo,
                     p_dir_correo,
                     'Solicitud de Verificacion',
                     'El usuario '||USER||' solicita verificación de datos de la Cuenta '||p_nro_cuenta||'.');
        end if;
      end if;

   END;
   --- ISSUE 1089 - AP 2902 - INTERFAZ SUMINISTRO DATOS IT Y RECOVERY STRATEGY
   /** Función que obtiene la siguiente secuencia para la Relación Cuenta-Cliente. **/
   FUNCTION lf_obt_sig_secuencia
   (
      p_cod_persona IN co_cta_clientes.cod_persona%TYPE,
      p_relacion    IN co_cta_clientes.relacion%TYPE,
      p_adicion     IN NUMBER
   ) RETURN NUMBER IS
      v_sig_secuencia co_cta_clientes.secuencia%TYPE;
   BEGIN
      BEGIN
         SELECT nvl(MAX(secuencia), 0) + 1
           INTO v_sig_secuencia
           FROM co_cta_clientes
          WHERE cod_persona = p_cod_persona
            AND relacion = p_relacion;
      EXCEPTION
         WHEN no_data_found THEN
            v_sig_secuencia := 1;
         WHEN OTHERS THEN
            raise_application_error(-20000, 'Error al buscar la máxima secuencia para la Persona ' ||
                                             p_cod_persona || SQLERRM);
      END;
      IF v_sig_secuencia = 1 THEN
         v_sig_secuencia := v_sig_secuencia + nvl(p_adicion, 0);
      END IF;
      RETURN v_sig_secuencia;
   END;
   --- ISSUE 1089 - AP 2902 - INTERFAZ SUMINISTRO DATOS IT Y RECOVERY STRATEGY

   --- fin del proceso de verificacion

  --CANCF-198 -- Clave Fácil - Cliente Nuevo --  CN: 02/02/2015
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
        raise_application_error(-20000, 'Error en LF_ACT_EST_CLAVE. ' || sqlerrm);
  end;
  --
  function lf_ver_est_clave(p_cod_persona IN ba_personas.cod_persona%TYPE,
                            p_est_clave   IN bw_ope_claves.tip_clave%TYPE)
     RETURN BOOLEAN IS
     v_existe VARCHAR2(1) := 'N';
  BEGIN
      SELECT 'S'
        INTO v_existe
        FROM bw_ope_claves
       WHERE cod_persona = p_cod_persona
         AND cod_per_vinculada IS NULL
         AND est_clave = p_est_clave
         AND tip_clave = 'A';
     IF v_existe = 'N' THEN
        RETURN FALSE;
     ELSIF v_existe = 'S' THEN
        RETURN TRUE;
     END IF;
  EXCEPTION
     WHEN no_data_found THEN
        RETURN FALSE;
     WHEN too_many_rows then
        RETURN TRUE;
     WHEN OTHERS THEN
        raise_application_error(-20000, 'Error en lf_ver_est_clave. ' || SQLERRM);
  END;
  --
  function lf_es_cta_nomina(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE)
     RETURN BOOLEAN IS
     v_existe VARCHAR2(1) := 'N';
  BEGIN
      SELECT 'S'
        INTO v_existe
        FROM ah_cta_vistas
       WHERE nro_cuenta = p_nro_cuenta
         AND cod_ente is not null
      UNION
      SELECT 'S'
        FROM cc_cta_corrientes
       WHERE nro_cuenta = p_nro_cuenta
         AND cod_ente is not null;
     IF v_existe = 'N' THEN
        RETURN FALSE;
     ELSIF v_existe = 'S' THEN
        RETURN TRUE;
     END IF;
  EXCEPTION
     WHEN no_data_found THEN
        RETURN FALSE;
     WHEN too_many_rows then
        RETURN TRUE;
     WHEN OTHERS THEN
        raise_application_error(-20000, 'Error en FUG_VER_OPE_CLAVE. ' || SQLERRM);
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
  --CANCF-198 -- Clave Fácil - Cliente Nuevo --  CN: 02/02/2015

  function lf_ver_atm_canal(p_nro_cuenta  in ge_cta_clientes.nro_cuenta%type)
     return varchar2 is
     v_result varchar2(1);
     begin
       select 'S'
         into v_result
         from pr_cta_prestamos a
        where a.nro_cuenta = p_nro_cuenta
          and a.cod_canal = 28; --ATM
       return v_result;
     exception
       when no_data_found then
         v_result := 'N';
         return v_result;
       when too_many_rows then
         v_result := 'N';
         return v_result;
     end;

BEGIN
--if user <> 'IT' then -- solo sino es interface
   if updating then
      --- Si se modifica el cliente principal Generar Cambio de Estado
      if :new.relacion = 'P' and :new.cod_persona <> :old.cod_persona
      -- FB: Se comenta hasta la fase 4, prestamos no debe controlar.
      and :new.cod_modulo IN (3,4,/*6,*/7,8) then
         pag_ccl.pr_obt_dat_con_cli(:new.cod_persona, v_cod_sec_con_act, v_res_act, v_cod_tip_deu_act);
         pag_ccl.pr_obt_dat_con_cli(:old.cod_persona, v_cod_sec_con_ant, v_res_ant, v_cod_tip_deu_ant);
         if  pag_ccl.fu_ver_tip_valido(v_cod_sec_con_act, v_res_act, v_cod_tip_deu_act) = 'S'
         and pag_ccl.fu_ver_tip_valido(v_cod_sec_con_ant, v_res_ant, v_cod_tip_deu_ant) = 'S' then
            pag_ccl.pr_gen_tra_cta(:new.cod_modulo, :new.cod_modalidad,
                                   :new.cod_oficina, :new.nro_cuenta,
                                   v_cod_sec_con_ant, v_res_ant, v_cod_tip_deu_ant,
                                   v_cod_sec_con_act, v_res_act, v_cod_tip_deu_act);
         end if;
      end if;
      begin
         select cod_moneda into v_cod_moneda
           from ge_cuentas
          where nro_cuenta = :new.nro_cuenta;
      exception
         when no_data_found then
            raise_application_error(-20000,
            'Cuenta no registrada');
      end;
      if v_ver_cuenta = 'S' and :new.cod_modulo != 6 then
         update ge_cuentas
            set est_verificacion = 'N'
          where nro_cuenta = :new.nro_cuenta;
      end if;
   end if;
  -- Cambio solicitado en BR, cuentas gerencia, cuentas certificado y todas las cuentas del modulo 8
  -- no deben ir a verificación mail 15/09/2005 y 13/10/2005
  if inserting and v_ver_cuenta = 'S'
  and :new.cod_modalidad not in (43,44)
  and :new.cod_modulo not in (6, 8) then
      -- Préstamos no debe ser verificado...
      update ge_cuentas
         set est_verificacion = 'N'
       where nro_cuenta = :new.nro_cuenta;
   end if;
   if deleting and v_ver_cuenta = 'S' then
      update ge_cuentas
         set est_verificacion = 'N'
       where nro_cuenta = :old.nro_cuenta;
   end if;
/*   if v_ver_cuenta = 'S' and :new.cod_modulo not in (6, 8) then  -- solo si se verifica la cuenta
      if :new.relacion = 'P' and inserting then
        -- si es el principal
        prg_obt_usu_verificador('GMVERCTA',user, v_cod_usuario, v_dir_correo,
        :new.cod_persona);
        if v_cod_usuario is not null then
           --- Generar agenda al verificador
           LP_INS_AGENDA(:new.nro_cuenta, v_cod_usuario, v_dir_correo,
                         :new.cod_persona);
        end if;
      end if;
   end if;*/
   /*
   -- solo para pruebas de circuitos
   if inserting then
      declare
        v_cod_error number := 0;
      begin
      if :new.cod_modalidad = 31 and :NEW.relacion = 'P' then
         v_cod_error := paw_cir.FU_INI_CIRCUITO(61, :new.nro_cuenta, :new.cod_persona); -- 61 es el tipo de circuito
      end if;
      if v_cod_error <> 0 then
         raise_application_error(-20067,'Error al generar Circuito '||paw_cir.G_MSJ_ERROR);
      end if;
      end;
   end if;
   */
--end if;

   --- ISSUE 1089 - AP 2902 - INTERFAZ SUMINISTRO DATOS IT Y RECOVERY STRATEGY
   IF inserting THEN
      IF :new.relacion IN ('P', 'O', 'Y', 'C', 'G') THEN
         IF :new.relacion = 'P' THEN
            v_relacion  := 'T';
            v_secuencia := 1;
         ELSIF :new.relacion = 'O' OR :new.relacion = 'Y' THEN
            v_relacion  := 'T';
            v_adicion   := 1;
            v_secuencia := lf_obt_sig_secuencia(:new.cod_persona, v_relacion, v_adicion);
         ELSIF :new.relacion = 'C' OR :new.relacion = 'G' THEN
            v_relacion  := 'A';
            v_adicion   := 0;
            v_secuencia := lf_obt_sig_secuencia(:new.cod_persona, v_relacion, v_adicion);
         END IF;

         --- Inserta la Relación entre Cuentas y Personas.
         INSERT INTO co_cta_clientes
            (cod_persona, nro_cuenta, relacion, secuencia)
         VALUES
            (:new.cod_persona, :new.nro_cuenta, v_relacion, v_secuencia);
      END IF;
   ELSIF updating THEN
      IF :new.relacion IN ('P', 'O', 'Y', 'C', 'G') THEN
        /*DYDMR-5742 MAR-2017 (ALV)*/
         IF :new.cod_persona <> :old.cod_persona THEN --si se actualiza el firmante se elimina el registro de co_cta_clientes
            delete co_cta_clientes c
             where c.cod_persona = :old.cod_persona
               and c.nro_cuenta = :new.nro_cuenta;
         END IF;
         IF :new.relacion <> :old.relacion THEN
            IF :new.relacion = 'P' THEN
               v_relacion  := 'T';
               v_secuencia := 1;
            ELSIF :new.relacion = 'O' OR :new.relacion = 'Y' THEN
               v_relacion := 'T';
            ELSIF :new.relacion = 'C' OR :new.relacion = 'G' THEN
               v_relacion := 'A';
            END IF;

            --- Actualiza la Relación entre Cuentas y Personas.
            UPDATE co_cta_clientes
               SET secuencia = NULL,
                   relacion  = v_relacion
             WHERE cod_persona = :new.cod_persona
               AND nro_cuenta = :new.nro_cuenta;
            --COMMIT;

            FOR i IN relacion LOOP
               UPDATE co_cta_clientes
                  SET secuencia = NULL
                WHERE cod_persona = i.cod_persona
                  AND nro_cuenta = i.nro_cuenta;
               --COMMIT;
            END LOOP;

            FOR x IN relacion LOOP
               IF x.nro_cuenta = :new.nro_cuenta AND :new.relacion = 'P' THEN
                  v_cur_secuencia := v_secuencia;
               ELSE
                  IF x.relacion = 'T' THEN
                     v_adicion := 1;
                  ELSIF x.relacion = 'A' THEN
                     v_adicion := 0;
                  END IF;
                  v_cur_secuencia := lf_obt_sig_secuencia(:new.cod_persona, x.relacion, v_adicion);
               END IF;

               UPDATE co_cta_clientes
                  SET secuencia = v_cur_secuencia
                WHERE cod_persona = x.cod_persona
                  AND nro_cuenta = x.nro_cuenta
                  AND relacion = x.relacion;
            END LOOP;
         END IF;
      END IF;
   ELSIF deleting THEN
      IF :old.relacion IN ('O', 'Y', 'C', 'G') THEN
         IF :old.relacion = 'O' OR :old.relacion = 'Y' THEN
            v_relacion := 'T';
         ELSIF :old.relacion = 'C' OR :old.relacion = 'G' THEN
            v_relacion := 'A';
         END IF;

         --- Borra la Relación entre Cuentas y Personas.
         DELETE FROM co_cta_clientes
          WHERE cod_persona = :old.cod_persona
            AND nro_cuenta = :old.nro_cuenta;
         --COMMIT;

         FOR i IN relacion LOOP
            UPDATE co_cta_clientes
               SET secuencia = NULL
             WHERE cod_persona = i.cod_persona
               AND nro_cuenta = i.nro_cuenta;
            --COMMIT;
         END LOOP;

         FOR x IN relacion LOOP
            IF x.relacion = 'T' THEN
               v_adicion := 1;
            ELSIF x.relacion = 'A' THEN
               v_adicion := 0;
            END IF;
            v_cur_secuencia := lf_obt_sig_secuencia(:old.cod_persona, x.relacion, v_adicion);

            UPDATE co_cta_clientes
               SET secuencia = v_cur_secuencia
             WHERE cod_persona = x.cod_persona
               AND nro_cuenta = x.nro_cuenta
               AND relacion = x.relacion;
         END LOOP;
   -- Cambio solicitado por MIS, la oficina a guardar debe ser la oficina del oficial de la cuenta - RABP 08/10/2013
         if :new.cod_oficina != FUG_OBT_OFI_OFICIAL(:new.Cod_Persona) and :new.relacion = 'P' then
            raise_application_error(-20000,'La Oficina de la cuenta debe llevar la oficina del Oficial: '||fue_obt_des_oficina(FUG_OBT_OFI_OFICIAL(:new.Cod_Persona))||' ('||FUG_OBT_OFI_OFICIAL(:new.Cod_Persona)||')');
         end if;
      END IF;
   END IF;
  begin
  --Unipersonal
  if nvl(fug_obt_pardinamico('VAL_INS_CTA_UNIPERSONAL'),'N') = 'S' then --Si el parametro esta en S
  
    if inserting and -- Si es un insert
      :new.relacion = 'P' and --si queremos insertar como principal
      nvl(fug_obt_naturaleza(:new.cod_persona),'N') = nvl(fug_obt_pardinamico('COD_NAT_UNIPERSONAL'), 'X') and --si es unipersonal 
      UPPER(LTRIM(RTRIM(nvl(fug_obt_pardinamico('USU_ONB_EMPRESAS'),'N')))) != UPPER(USER) AND --Si es dif. al user del onboarding
      instr(',' || fug_obt_pardinamico('USU_PRO_ARC_TAR_EMPRESAS') || ',', ',' || UPPER(USER) || ',') <= 0 THEN  --Si es dif. a los users de bancard 
       

      raise_application_error(-20000,
                              'No se pueden insertar cuentas para Personas Juridicas Unipersonales desde ITGF');
                              
    end if;     
  end if;
  
end;

END;
/

