CREATE OR REPLACE PROCEDURE IT.prg_ext_clic_masivo IS
   --- Variables --
   rg_bwecm              bw_ext_clic_masivo%rowtype;
   v_fecha               bw_ext_clic_masivo.fecha%type         := trunc(sysdate);
   v_fec_actual          ge_calendarios.fec_actual%type        := pag_cal.fu_obt_fec_actual(5);
   v_usuario             bw_ext_clic_masivo.usu_insercion%type := USER;
   v_nro_lote            bw_ext_clic_masivo.nro_lote%type;
   v_nro_cuenta          bw_ext_clic_masivo.nro_tarjeta%type;
   v_nro_tarjeta         bw_ext_clic_masivo.nro_tarjeta%type;
   v_msj_not_bienvenida  ge_par_dinamicos.val_parametro%type;
   v_mot_ret_def         ge_par_dinamicos.val_parametro%type   := nvl(fug_obt_pardinamico('MOT_RET_SOL_CLIENTE'),5);
   v_direccion           bw_not_cli_destino.direccion%type;
   v_email               ba_personas.dir_correo%type;
   v_can_registro        NUMBER := 0;
   v_can_reg_tar         NUMBER := 0;
   v_ret                 NUMBER;
   v_imp_extracto        VARCHAR2(1);
   v_retener             VARCHAR2(1);
   v_es_gourmet          VARCHAR2(1); 
   v_ret_extracto        VARCHAR2(1);
   -- Constantes -- 
   ERR_DAT_INVALIDO      CONSTANT VARCHAR2(50) := 'Datos inválidos.';
   ERR_CTA_SUSCRITA      CONSTANT VARCHAR2(50) := 'Cuenta suscrita previamente.';
   ERR_CTA_PROPIETARIO   CONSTANT VARCHAR2(50) := 'Cuenta de Tarjeta no corresponde al cliente.';
   -- Cursor de Datos --   
   CURSOR c_datos IS
      SELECT nro_orden, cod_persona, ret_cuentas, ret_tarjetas, nro_tarjeta
        FROM bw_ext_clic_masivo a
       WHERE fecha = v_fec_actual
         AND nro_lote = v_nro_lote
         AND nvl(procesado, 'N') = 'N'
         AND mensaje is null
         AND trunc(fec_insercion) = v_fecha
         AND usu_insercion = v_usuario
         order by nro_orden;
   -- Cursor de Cuentas --
   CURSOR c_ext_cuentas( p_cod_modulo  IN ba_modulos.cod_modulo%TYPE,
                         p_nro_cuenta  IN ge_cuentas.nro_cuenta%TYPE DEFAULT NULL,
                         p_cod_persona IN ba_personas.cod_persona%TYPE DEFAULT NULL ) IS
       SELECT a.nro_cuenta, a.cod_modalidad cod_modalidad, fug_obt_des_modal(a.cod_modulo, a.cod_modalidad) des_tip_cuenta, 
              a.cod_moneda cod_moneda, a.denominacion nom_cuenta, 
              a.cod_modulo, a.estado,b.relacion, paw_bce.fu_tip_cuenta(a.cod_modulo, a.cod_modalidad) cod_tip_cuenta 
         FROM ge_est_cuentas c, ge_cuentas a, ge_cta_clientes b
        WHERE b.cod_persona = nvl(p_cod_persona,b.cod_persona)           
          AND b.relacion = 'P'
          AND a.nro_cuenta = b.nro_cuenta
          AND a.cod_modulo = c.cod_modulo
          AND a.cod_modalidad = c.cod_modalidad
          AND a.estado = c.estado
          AND (
                 (p_cod_modulo IN (3, 4) AND c.cod_modulo IN (3,4) AND b.cod_modalidad IN (31, 41)) OR
                 (p_cod_modulo = 5 AND c.cod_modulo = 5)
              )
          AND a.nro_cuenta = nvl(p_nro_cuenta, a.nro_cuenta)           
          AND c.activo = 'S' -- solo cuentas activas
          AND a.estado <> 'X' -- pendiente de verificacion
        ORDER BY decode(b.cod_modalidad, 31, 1, decode(b.cod_modulo, 5, 2, decode(b.cod_modalidad, 33, 4, 34, 4, 36, 4, decode(b.cod_modulo, 4, 3, 7))));            
   -- Procedimiento para insertar datos en bw_ext_clic_masivo --
   PROCEDURE lp_ins_datos IS
   BEGIN
      LOCK TABLE bw_ext_clic_masivo IN EXCLUSIVE MODE NOWAIT;
      BEGIN
         SELECT MAX(nro_lote)
           INTO v_nro_lote
           FROM bw_ext_clic_masivo
          WHERE fecha = v_fec_actual;
         v_nro_lote := nvl(v_nro_lote, 0) + 1;
      EXCEPTION
         WHEN no_data_found THEN
            v_nro_lote := 1;
      END;
      INSERT INTO bw_ext_clic_masivo
         (fecha, nro_lote, nro_orden, cod_persona, ret_cuentas, ret_tarjetas, nro_tarjeta)
         SELECT v_fec_actual, v_nro_lote, nro_orden, cod_persona, ret_cuentas, ret_tarjetas, nro_tarjeta
           FROM bw_ext_clic_masivo_tmp
          WHERE trunc(fec_insercion) = v_fecha
            AND usu_insercion = v_usuario;
      DELETE FROM bw_ext_clic_masivo_tmp
       WHERE trunc(fec_insercion) = v_fecha
         AND usu_insercion = v_usuario;

   END;
   -- Procedimiento para actualizar mensaje en bw_ext_clic_masivo --
   PROCEDURE lp_act_datos(p_tipo in varchar2 default 'M') IS
     -- p_tipo: M = Mensaje, P = Procesado
   BEGIN
      IF p_tipo = 'M' then
         UPDATE bw_ext_clic_masivo a
            SET a.mensaje = decode(a.mensaje,null,rg_bwecm.mensaje, substr(a.mensaje||chr(10)||rg_bwecm.mensaje,1,2000) )
          WHERE a.fecha = rg_bwecm.fecha
            AND a.nro_lote = rg_bwecm.nro_lote
            AND a.nro_orden = rg_bwecm.nro_orden
            AND a.cod_persona = rg_bwecm.cod_persona;
      ELSE
         UPDATE bw_ext_clic_masivo a
            SET a.procesado = 'S'
          WHERE a.fecha = rg_bwecm.fecha
            AND a.nro_lote = rg_bwecm.nro_lote
            AND a.nro_orden = rg_bwecm.nro_orden
            AND a.cod_persona = rg_bwecm.cod_persona; 
      END IF;
   END;  
   -- Funcion para validar Cuenta de Tarjeta --
   FUNCTION lf_cta_valida(p_cta_tarjeta VARCHAR2, p_cod_persona IN VARCHAR2) RETURN VARCHAR2 IS
      v_result VARCHAR2(1) := 'N';
   BEGIN 
      SELECT 'S'
        INTO v_result
        FROM ba_personas b, ge_cta_clientes a
       WHERE a.cod_persona = b.cod_persona
         AND a.nro_cuenta = p_cta_tarjeta
         AND a.cod_persona = p_cod_persona
         AND a.relacion = 'P'
         AND a.cod_modulo = 5
         AND rownum = 1;     
      RETURN v_result;
   EXCEPTION
     WHEN OTHERS THEN
       v_result := 'N';
       RETURN v_result;
   END;

BEGIN
   -- Insertar datos --
   lp_ins_datos; 
   FOR reg IN c_datos
   LOOP  
      rg_bwecm.fecha        := v_fec_actual;
      rg_bwecm.nro_lote     := v_nro_lote;
      rg_bwecm.nro_orden    := reg.nro_orden;
      rg_bwecm.cod_persona  := reg.cod_persona;  
      rg_bwecm.mensaje      := null;
      v_can_registro        := 0;
      v_can_reg_tar         := 0;   
      -- Validar datos --
      IF nvl(reg.ret_tarjetas, 'x') NOT IN ('S', 'N') OR nvl(reg.ret_cuentas, 'x') NOT IN ('S', 'N') THEN
         rg_bwecm.mensaje := 'ERROR: '||ERR_DAT_INVALIDO||' Retener Cuentas o Retener Tarjetas distintos a S ó N.';
         lp_act_datos;
         GOTO siguiente;
      END IF;
      -- Al menos un producto se debe solicitar --
      IF reg.ret_tarjetas = 'N' AND reg.ret_cuentas = 'N' THEN
         rg_bwecm.mensaje := 'ERROR: '||ERR_DAT_INVALIDO||' Se debe solicitar Retener Cuentas o Retener Tarjetas.';
         lp_act_datos;
         GOTO siguiente;
      END IF;  
      -- Destino Activo --
      v_direccion := substr(paw_not.fu_obt_cli_des_activo(reg.cod_persona), 1, 200); 
      -- Retener Extracto Cuentas --
      IF reg.ret_cuentas = 'S' then
         v_imp_extracto := paw_uti.fu_imp_extracto(reg.cod_persona); -- Verificamos si el cliente imprime sus extractos. 
         IF v_imp_extracto = 'N' THEN -- El cliente no imprime sus extractos   
            v_can_registro := 0;
         ELSE -- se cambia el tipo de extracto del cliente     
            UPDATE ge_clientes c
               SET c.tip_extracto = decode(c.tip_extracto, 'C', 'N', -- de impreso a no impreso
                                                           'X', 'Z', -- de mail e impreso a mail
                                                           c.tip_extracto ) -- sino, no se modifica
             WHERE c.cod_persona = reg.cod_persona
               AND c.tip_extracto IN ('C', 'X');
             v_can_registro := sql%rowcount;        
         END IF;    
      END IF;  
      -- Validar tarjeta
      v_nro_tarjeta  := paw_bel.depurarAlfanumerico(reg.nro_tarjeta, 16);
      v_retener      := 'S';
      IF v_nro_tarjeta IS NOT NULL THEN -- Se solicita Alta para una Tarjeta
         IF reg.ret_tarjetas != 'S' THEN -- Validar que se haya marcado como Retener Tarjeta
             rg_bwecm.mensaje := 'ERROR: '||ERR_DAT_INVALIDO||' Nro. de Tarjeta ingresada pero Retener Tarjetas es distinto a S.';
             lp_act_datos;
             v_retener := 'N';
         ELSE -- Validar Cuenta Tarjeta
            v_nro_cuenta := pat_imp.fu_obt_nro_cuenta(v_nro_tarjeta); -- obtenemos la cuenta asociada al plastico        
            IF lf_cta_valida(v_nro_cuenta,reg.cod_persona) = 'N' THEN -- validamos que la cuenta pertenezca al cliente
               v_nro_cuenta := v_nro_tarjeta;
               IF lf_cta_valida(v_nro_cuenta,reg.cod_persona) = 'N' THEN -- Si se ingresa directamente la cuenta de la tarjeta
                  rg_bwecm.mensaje := 'ERROR: '||ERR_DAT_INVALIDO||' '||ERR_CTA_PROPIETARIO;
                  lp_act_datos;
                  v_retener := 'N';
               ELSE -- validamos que la cuenta no retenga extracto
                  IF pat_imp.fu_ret_extracto(v_nro_cuenta) = 'S' THEN
                     v_retener  := 'N';
                  END IF;
               END IF;
            ELSE -- validamos que la cuenta no retenga extracto
               IF pat_imp.fu_ret_extracto(v_nro_cuenta) = 'S' THEN
                  v_retener  := 'N';
               END IF;
            END IF;
         END IF;
      ELSE
         IF reg.ret_tarjetas = 'S' THEN  -- Retener Todas las Tarjetas
            v_nro_cuenta := null;
         ELSE 
            v_retener  := 'N';
         END IF;
      END IF;     
      -- Retener Extracto Tarjetas
      IF reg.ret_tarjetas = 'S' and v_retener = 'S' THEN      
        FOR ta IN c_ext_cuentas(5, v_nro_cuenta, reg.cod_persona) 
        LOOP
          BEGIN
            v_es_gourmet := paw_not.lf_es_gourmet(ta.cod_modalidad);
            v_ret_extracto := pat_imp.FU_RET_EXTRACTO(ta.nro_cuenta);
            IF v_ret_extracto = 'N' AND v_es_gourmet = 'N' THEN
               UPDATE ta_cta_tarjetas_nov
                  SET ret_extracto = 'S', 
                      mot_ret_extracto = v_mot_ret_def
                WHERE nro_cuenta = ta.nro_cuenta
                  AND fecha = v_fec_actual;
               IF SQL%NOTFOUND THEN
                   INSERT INTO ta_cta_tarjetas_nov
                     (nro_cuenta, fecha, ret_extracto, mot_ret_extracto)
                   VALUES
                     (ta.nro_cuenta, v_fec_actual, 'S', v_mot_ret_def); 
               END IF;   
               UPDATE ge_cta_dat_adicionales
                  SET val_parametro = 'S'
                WHERE nro_cuenta = ta.nro_cuenta
                  AND parametro = 'RET_EXTRACTO';
               IF SQL%NOTFOUND THEN
                  INSERT INTO ge_cta_dat_adicionales
                    (nro_cuenta, parametro, val_parametro)
                  VALUES
                    (ta.nro_cuenta, 'RET_EXTRACTO','S'); 
               END IF;    
               UPDATE ge_cta_dat_adicionales
                  SET val_parametro = v_mot_ret_def
                WHERE nro_cuenta = ta.nro_cuenta
                  AND parametro = 'MOT_RET_EXTRACTO';
               IF SQL%NOTFOUND THEN
                  INSERT INTO ge_cta_dat_adicionales
                    (nro_cuenta,parametro,val_parametro)
                  VALUES
                    (ta.nro_cuenta,'MOT_RET_EXTRACTO',v_mot_ret_def);
               END IF;                        
               v_can_reg_tar := nvl(v_can_reg_tar,0) + 1;
            END IF;
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               NULL;
         END;  
        END LOOP;
      END IF;   
      -- Verificar si hubo insercion
      IF v_can_registro = 0 AND v_can_reg_tar = 0 THEN
         IF rg_bwecm.mensaje IS NULL THEN
            rg_bwecm.mensaje := 'ERROR: '||ERR_CTA_SUSCRITA;
            lp_act_datos;
         END IF;
      ELSE
         -- si no tiene servicio de notificacion, se le adhiere de forma compulsiva
         IF paw_not.fu_obt_suscripcion(reg.cod_persona) = 'N' OR v_direccion IS NULL THEN
            v_ret := paw_not.fu_alt_notificacion(reg.cod_persona, v_direccion);        
         END IF;               
         INSERT INTO GE_REG_TIP_EXTRACTO
            (fecha, canal, tip_novedad, cod_usuario, ret_cuenta, ret_tarjeta, nro_cuenta, cod_persona, motivo)
         VALUES
            (v_fec_actual, 'ITGF-MAS', 'A', user, reg.ret_cuentas, v_retener, null,reg.cod_persona, 5);
         -- Procesado
         rg_bwecm.mensaje := 'INFO: '||'Procesado correctamente.';
         lp_act_datos;   
         -- Mail de Bienvenida al servicio de Extractos Digitales
         v_email := substr(fug_obt_dir_mail_per(reg.cod_persona), 1, 80);
         IF v_email IS NOT NULL THEN
            v_msj_not_bienvenida := nvl(fug_obt_pardinamico('EXT_MSG_MAIL_BIENVENIDA'),'Estimado usuario, Banco GNB Paraguay S.A. le da la bienvenida al servicio de Extracto Clic');
            v_ret := paw_not.fu_env_email_prueba( v_email,
                                                 utl_url.escape(v_msj_not_bienvenida, TRUE, 'UTF-8'), 'ITGF' );
            -- Registrar en caso de mail no enviado
            IF v_ret = -99 THEN -- No enviado
               rg_bwecm.mensaje := 'INFO: '||'Error en envio de mail de notificacion.';
               lp_act_datos; 
            END IF;                                                                     
         END IF;
         -- Marcar como procesado         
         lp_act_datos('P'); 
      END IF; 
      <<siguiente>> null;    
   END LOOP;          
EXCEPTION
  WHEN OTHERS THEN
    Raise_application_error(-20000, 'Error en el Proceso - '||SQLERRM);
END prg_ext_clic_masivo;
/

