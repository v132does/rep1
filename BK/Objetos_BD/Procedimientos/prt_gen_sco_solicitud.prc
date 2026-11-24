CREATE OR REPLACE PROCEDURE IT.PRT_GEN_SCO_SOLICITUD
  (p_cod_persona         in varchar2,
   p_ind_val_scoring     in varchar2 default 'N', -- indica si se validará el scoring
   p_ant_nro_solicitud   in varchar2,    -- Nro de Solicitud "padre"
   p_nro_solicitud       in varchar2,    -- Nro de Solicitud a reutilizar (mto_reconducido)
   p_nvo_nro_solicitud   out varchar2,   -- Retorna el nro de solicitud creado
   p_sco_dic_final       out varchar2,   -- Retorna el resultado del scoring
   p_sco_error           out varchar2,   -- Retorna el error del scoring
   p_mto_reconducido     in out number,  -- Retorna el monto reconducido.
   p_tip_producto        out varchar2) is -- Retorna el producto creado/actualizado. TA=Tarjeta, AL=Aum. de Línea
   
   -- SDHSCORM-1
   v_mot_ret_sol_cli   ge_par_dinamicos.parametro%TYPE := fug_obt_pardinamico('MOT_RET_SOL_CLIENTE');
   v_fec_actual        ge_calendarios.fec_actual%TYPE := pae_cnf.fu_obt_fec_actual(5);
   v_cod_oficina       ba_oficinas.cod_oficina%TYPE := fug_obt_ofi_oficial(p_cod_persona);
   v_mon_local         ba_monedas.cod_moneda%TYPE := pag_gen.fu_obt_mon_local;
   v_nro_solicitud     ta_solicitudes.nro_solicitud%type;
   v_sum_mto_tar       ta_cta_tarjetas.lin_credito%type;
   v_cod_rol           ba_roles.cod_rol%TYPE;
   v_error             varchar2(4000);
   v_descripcion       varchar2(100):= nvl(FUE_OBT_SIG_REFCODES('COD_DESTINO','29'), 'SCORING MULTIPRODUCTO');
   v_embozo            varchar2(20); 
   v_tip_plastico      varchar2(1);
   v_tip_envio         varchar2(1);
   v_referencia        varchar2(1);
   v_sub_afinidad      varchar2(3);
   v_afinidad          varchar2(6);
   v_nro_intento       number(3);
   v_cod_modalidad     number(3);
   v_cod_tip_cierre    number(3)   := 4;
   v_cod_modulo        number(3)   := 5;
   v_cod_sub_modalidad number(3)   := fug_obt_pardinamico('SCO_MUL_COD_SUB_MODALIDAD', 5);
   v_cod_canal         number(3)   := fug_obt_pardinamico('SCO_MUL_CANAL', 5);
   v_cod_campana       number(3)   := fug_obt_pardinamico('SCO_MUL_CAMPANA', 5);
   v_monto             number(18,2):= fug_obt_pardinamico('SCO_MUL_MONTO', 5);
   v_mto_max_linea     number(18,2):= fug_obt_pardinamico('SCO_MUL_MTO_MAX_TAR', 5);
   v_cod_rub_economico varchar2(6) := fug_obt_pardinamico('SCO_MUL_COD_RUB_ECO', 5);
   
   
   v_nro_cuenta        ta_cta_tarjetas.nro_cuenta%type;
   v_mto_lin_anterior  ta_sol_lineas.mto_lin_anterior%type;
   v_mto_lin_nuevo     ta_sol_lineas.lin_credito%type;
   v_max_linea         ta_tipos.max_linea%type;
   
   FUNCTION LF_VAL_SUM_LIN_CRE RETURN number IS
      v_return number;
   BEGIN
      SELECT nvl(trunc(sum(b.lin_credito),-6)+1000000, 0)
        INTO v_return
        FROM ge_cta_clientes a, ta_cta_tarjetas b, ge_est_cuentas c
       WHERE a.nro_cuenta=b.nro_cuenta 
         AND a.relacion='P' 
         AND a.cod_persona = p_cod_persona
         AND b.cod_modulo=c.cod_modulo AND b.cod_modalidad=c.cod_modalidad AND b.estado=c.estado 
         AND c.activo='S';
      RETURN v_return;
   EXCEPTION
      WHEN others THEN
         return 0;
   END;
   
   FUNCTION LF_CLI_TIE_TARJETA (p_cod_persona   ta_solicitudes.cod_persona%type,
                                p_cod_modulo    ta_solicitudes.cod_modulo%type,
                                p_cod_modalidad ta_solicitudes.cod_modalidad%type,
                                p_obt_dat_cuenta varchar2) RETURN varchar2 IS
      v_mto_lin_ant_aux  number(18,2);
      v_nro_cuenta_aux   varchar2(15);
      v_afinidad_aux     varchar2(10);
      v_sub_afinidad_aux varchar2 (3);
   BEGIN
      SELECT b.nro_cuenta, b.lin_credito, b.afinidad, b.sub_afinidad
        INTO v_nro_cuenta_aux, v_mto_lin_ant_aux, v_afinidad_aux, v_sub_afinidad_aux
        FROM ge_cta_clientes a, ta_cta_tarjetas b, ge_est_cuentas c
       WHERE a.nro_cuenta=b.nro_cuenta AND a.relacion='P' 
         AND b.cod_modulo=c.cod_modulo AND b.cod_modalidad=c.cod_modalidad AND b.estado=c.estado 
         AND c.activo='S'
         AND a.cod_persona = p_cod_persona
         AND a.cod_modulo = p_cod_modulo
         AND a.cod_modalidad = p_cod_modalidad
         AND rownum=1;
      -- Obtener datos de la cuenta
      IF nvl(p_obt_dat_cuenta, 'N') = 'S' THEN
         BEGIN
            SELECT a.max_linea
              INTO v_max_linea
              FROM ta_tipos a
             WHERE a.cod_modulo=p_cod_modulo
               AND a.cod_modalidad=p_cod_modalidad
               AND a.afinidad=v_afinidad_aux
               AND nvl(a.sub_afinidad,'ZZ')=nvl(v_sub_afinidad_aux,'ZZ')
               AND rownum = 1;
         EXCEPTION
            WHEN others THEN
               v_max_linea := null;
         END;
         v_afinidad        := v_afinidad_aux;
         v_sub_afinidad    := v_sub_afinidad_aux;
         v_mto_lin_anterior:= v_mto_lin_ant_aux;
      END IF;
      
      RETURN v_nro_cuenta_aux;
   EXCEPTION
      WHEN others THEN
         return null;
   END;
   
   PROCEDURE LP_ASI_MODALIDAD (p_cod_persona ta_solicitudes.cod_persona%type,
                               p_monto       ta_solicitudes.monto%type) IS
      v_cod_grupo  varchar2(3);
      v_mto_min    number;
      v_mto_max    number;
      v_cod_modalidad1 ta_solicitudes.cod_modalidad%type;
      v_cod_modalidad2 ta_solicitudes.cod_modalidad%type;
      v_cod_afinidad1  ta_solicitudes.afinidad%type;
      v_cod_afinidad2  ta_solicitudes.afinidad%type;
      v_cod_sub_afi1   ta_solicitudes.sub_afinidad%type;
      v_cod_sub_afi2   ta_solicitudes.sub_afinidad%type;
   BEGIN
      v_afinidad      := null;
      v_sub_afinidad  := null;
      v_cod_modalidad := null;
      v_nro_cuenta    := null;
      v_mto_lin_nuevo := 0;
      /* Este procedimiento asignará la modalidad correspondiente según lógica definida:
         1- Identificar a que grupo (según importe) pertenece (Si no pertenece a ninguno NO SE ASIGNA).
         2- Obtener las 2 opciones que ofrece ese grupo
         3- Si el cliente NO tiene la modalidad de la 1ra opción, asignar el mismo.
         4- Si tiene la 1ra y NO la 2da opción, asignar la 2da.
         5- Si tiene la 1ra y la 2da opción:
            5.1- Otorgar un Aumento de Línea a la modalidad de la 1ra opción. Obs: Validar (ta_tipos) que este en el rango permitido
            5.2- Si supera el rango de la 1ra opción, otorgar el Aumento de Linea a la modalidad de la 2da opción.
            5.3- Si ambos superan el rango, NO se le otorga.
      */
      -- 1- Identficar a que grupo pertenece
      BEGIN
         SELECT t.significado, t.val_minimo, t.val_maximo
           INTO v_cod_grupo, v_mto_min, v_mto_max 
           FROM ba_cod_referencias t 
          WHERE t.dominio = 'SCO_MUL_TAR_CONF' AND t.abreviatura='RANGO'
            AND p_monto BETWEEN t.val_minimo AND t.val_maximo;
      EXCEPTION
         WHEN others THEN
            v_cod_grupo := null;
      END;
      IF v_cod_grupo is not null THEN
         -- 2- Obtener las 2 opciones que ofrece ese grupo
         BEGIN
            SELECT a.val_minimo, a.val_maximo, b.val_minimo, b.val_maximo, c.val_minimo, c.val_maximo
              INTO v_cod_modalidad1, v_cod_modalidad2, v_cod_afinidad1, v_cod_afinidad2, v_cod_sub_afi1, v_cod_sub_afi2
              FROM ba_cod_referencias a, ba_cod_referencias b, ba_cod_referencias c
             WHERE a.dominio = 'SCO_MUL_TAR_CONF' and a.abreviatura='MODALIDAD_GRU'||v_cod_grupo
               AND b.dominio = 'SCO_MUL_TAR_CONF' and b.abreviatura='AFINIDAD_GRU'||v_cod_grupo
               AND c.dominio = 'SCO_MUL_TAR_CONF' and c.abreviatura='SUB_AFINIDAD_GRU'||v_cod_grupo;
         EXCEPTION
            WHEN others THEN
               v_cod_modalidad1 := null;
               v_cod_modalidad2 := null;
               v_cod_afinidad1  := null;
               v_cod_afinidad2  := null;
               v_cod_sub_afi1   := null;
               v_cod_sub_afi2   := null;
         END;
         -- 3- Si el cliente NO tiene la modalidad de la 1ra opción, asignar el mismo.
         IF lf_cli_tie_tarjeta(p_cod_persona, 5, v_cod_modalidad1, 'N') is null THEN
            v_afinidad      := v_cod_afinidad1;
            v_sub_afinidad  := v_cod_sub_afi1;
            v_cod_modalidad := v_cod_modalidad1;
            p_tip_producto  := 'TA';
         ELSE
            -- 4- Si tiene la 1ra y NO la 2da opción, asignar la 2da.
            IF lf_cli_tie_tarjeta(p_cod_persona, 5, v_cod_modalidad2, 'N') is null THEN
               v_afinidad      := v_cod_afinidad2;
               v_sub_afinidad  := v_cod_sub_afi2;
               v_cod_modalidad := v_cod_modalidad2;
               p_tip_producto  := 'TA';
            ELSE -- 5- Si tiene la 1ra y la 2da opción:
               -- 5.1- Otorgar un Aumento de Línea a la modalidad de la 1ra opción. Obs: Validar (ta_tipos) que este en el rango permitido
               v_nro_cuenta := lf_cli_tie_tarjeta(p_cod_persona, 5, v_cod_modalidad1, 'S');   
               v_mto_lin_nuevo := v_mto_lin_anterior + p_monto;
               v_cod_modalidad := v_cod_modalidad1;
               p_tip_producto  := 'AL';
               IF v_mto_lin_nuevo > v_max_linea THEN -- v_max_linea de la opción1
                  -- 5.2- Si supera el rango de la 1ra opción, otorgar el Aumento de Linea a la modalidad de la 2da opción.
                  v_nro_cuenta := lf_cli_tie_tarjeta(p_cod_persona, 5, v_cod_modalidad2, 'S');
                  v_mto_lin_nuevo := v_mto_lin_anterior + p_monto;
                  v_cod_modalidad := v_cod_modalidad2;
                  p_tip_producto  := 'AL';
                  IF v_mto_lin_nuevo > v_max_linea THEN -- v_max_linea de la opción2
                     -- 5.3- Si ambos superan el rango, NO se le otorga.
                     v_nro_cuenta    := null;
                     v_cod_modalidad := null;
                     p_tip_producto  := null;
                     v_mto_lin_nuevo := 0;
                  END IF;
               END IF;
            END IF;
         END IF;
      ELSE
         v_afinidad      := null;
         v_sub_afinidad  := null;
         v_cod_modalidad := null;
      END IF;
   END;   

BEGIN
   v_sum_mto_tar := lf_val_sum_lin_cre; -- Obtener total de linea de TDC que ya tiene el cliente.
   IF p_nro_solicitud is not null THEN
      IF v_sum_mto_tar + nvl(p_mto_reconducido, v_monto) > v_mto_max_linea THEN
         v_monto := v_mto_max_linea - v_sum_mto_tar;
      ELSE
         v_monto := nvl(p_mto_reconducido, v_monto);
      END IF;
      --
      lp_asi_modalidad(p_cod_persona, v_monto); --Asignar modalidad
      --
      v_nro_solicitud := p_nro_solicitud; -- Para utilizar en el control de validar scoring (p_ind_val_scoring)
      --
      IF v_monto > 0 AND p_tip_producto = 'TA' THEN
         BEGIN
            UPDATE ta_solicitudes
               SET monto = v_monto,
                   cod_modalidad = nvl(v_cod_modalidad, cod_modalidad),
                   cod_sub_modalidad = nvl(cod_sub_modalidad, cod_sub_modalidad),
                   afinidad = nvl(v_afinidad, afinidad),
                   sub_afinidad = nvl(v_sub_afinidad, sub_afinidad),
                   cod_estado = 'PAN',
                   cod_causa = null,
                   observacion = null
             WHERE nro_solicitud = v_nro_solicitud;
         EXCEPTION
            WHEN others THEN
               raise_application_error(-20003,'Error al actualizar TA_SOLICITUDES '||sqlerrm);
         END;
      ELSIF v_mto_lin_nuevo > 0 AND p_tip_producto = 'AL' THEN
         BEGIN
            UPDATE ta_sol_lineas
               SET lin_credito = v_mto_lin_nuevo,
                   cod_estado = 'PAN',
                   cod_causa = null,
                   observacion = null
             WHERE nro_solicitud = v_nro_solicitud;
         EXCEPTION
            WHEN others THEN
               raise_application_error(-20003,'Error al actualizar TA_SOLICITUDES '||sqlerrm);
         END;
      ELSE
         p_mto_reconducido := 0;
      END IF;
   ELSE
      IF v_sum_mto_tar + v_monto > v_mto_max_linea THEN
         v_monto := v_mto_max_linea - v_sum_mto_tar;
      END IF;
      -- 
      lp_asi_modalidad(p_cod_persona, v_monto); -- Asignar modalidad
      --
      IF v_monto > 0 AND p_tip_producto = 'TA' THEN
         SELECT s_nro_solicitud.nextval INTO v_nro_solicitud FROM dual;
           
         SELECT REPLACE(substr(pri_nombre||' '||pri_apellido,1,20),';',' ')
           INTO v_embozo
           FROM ba_per_fisicas
          WHERE cod_persona = p_cod_persona;
         
         BEGIN
            SELECT cod_direccion
              INTO v_referencia
              FROM ba_direcciones
             WHERE cod_persona = p_cod_persona
               AND principal = 'S';
         EXCEPTION
            WHEN others THEN
               v_referencia := null;
         END;
        
         IF v_referencia is null THEN
            v_tip_envio := 'R';
            v_referencia:= v_cod_oficina; 
         ELSE
            v_tip_envio := 'D';
         END IF;
         -- DYDMR-11446 Implementa Plastico Contactless
         IF nvl(fug_val_dat_parametros('TRC_TIP_PLA_CLESS',v_cod_modulo,v_cod_modalidad,null,v_afinidad,'N'),0) > 0 then
           v_tip_plastico := 'L';
         ELSE
           IF nvl(INSTR(fug_obt_pardinamico('TRC_TIP_PLA_CHIP', v_cod_modulo, v_cod_modalidad), v_afinidad),0) > 0 THEN
              IF nvl(instr(fug_obt_pardinamico('TRC_OBL_TIP_PLA_CHIP', v_cod_modulo, v_cod_modalidad), v_afinidad),0) > 0 THEN
                 IF v_monto >= to_number(fug_obt_pardinamico('MTO_MIN_LIN_CRE_CHIP', null, null, 'GS')) THEN
                    v_tip_plastico := 'C';
                 ELSE
                    v_tip_plastico := 'N';
                 END IF;
              ELSE
                 v_tip_plastico := 'C';
              END IF;
           ELSE
              v_tip_plastico := 'N';
           END IF;
         END IF;
         --
         BEGIN 
            INSERT INTO ta_solicitudes (nro_solicitud, cod_persona, cod_oficina, cod_modulo, cod_modalidad, cod_sub_modalidad,
                fec_solicitud, fec_aprobacion, nom_embozado, monto, cod_estado, tip_envio, referencia, 
                observacion, cod_moneda, cod_campana, 
                cod_canal, afinidad, sub_afinidad, ind_evaluacion, cod_tip_cierre, cod_rub_economico, tip_plastico)
            VALUES (v_nro_solicitud, p_cod_persona, v_cod_oficina, v_cod_modulo, v_cod_modalidad, v_cod_sub_modalidad,
                v_fec_actual, v_fec_actual, v_embozo, v_monto, 'PAN', v_tip_envio, v_referencia, 
                v_descripcion, v_mon_local, v_cod_campana,
                v_cod_canal, v_afinidad, v_sub_afinidad, 'N', v_cod_tip_cierre, v_cod_rub_economico, 
                v_tip_plastico);
         EXCEPTION
            WHEN others THEN
               raise_application_error(-20003,'Error al insertar en TA_SOLICITUDES '||sqlerrm);
         END;
         -- 
         BEGIN    
            INSERT INTO ba_tab_dat_adicionales ( tab_relacion, referencia, parametro, val_parametro)
            VALUES ( 'TA_SOLICITUDES', v_nro_solicitud, 'RET_EXTRACTO', 'S');
         EXCEPTION
            WHEN others THEN
               raise_application_error(-20003,'Error al insertar dato adicional RET_EXTRACTO '||sqlerrm);
         END;
         --
         BEGIN
            INSERT INTO ba_tab_dat_adicionales ( tab_relacion, referencia, parametro, val_parametro)
            VALUES ( 'TA_SOLICITUDES', v_nro_solicitud, 'MOT_RET_EXTRACTO', nvl(v_mot_ret_sol_cli, 5));
         EXCEPTION
            WHEN others THEN
               raise_application_error(-20003,'Error al insertar dato adicional MOT_RET_EXTRACTO '||sqlerrm);
         END;
         --
         BEGIN
            INSERT INTO ba_tab_dat_adicionales (tab_relacion, referencia, parametro, val_parametro)
            VALUES ( 'TA_SOLICITUDES', v_nro_solicitud, 'SCO_MUL_NRO_SOL_ORI', p_ant_nro_solicitud);
         EXCEPTION
            WHEN others THEN
               raise_application_error(-20003,'Error al insertar dato adicional SCO_MUL_NRO_SOL_ORI '||sqlerrm);
         END;
      ELSIF v_mto_lin_anterior > 0 AND p_tip_producto = 'AL' THEN
         SELECT s_nro_solicitud.nextval INTO v_nro_solicitud FROM dual;
         BEGIN
            INSERT INTO ta_sol_lineas (nro_solicitud, tip_solicitud, nro_cuenta, cod_persona, cod_moneda, 
                        mto_lin_anterior, lin_credito, fec_ingreso, cod_usu_autoriza, cod_usu_promotor, 
                        cod_usu_oficial, observacion, cod_estado, cod_canal, cod_campana, env_bancard)
            VALUES (v_nro_solicitud, 'A', v_nro_cuenta, p_cod_persona, 'GS', v_mto_lin_anterior,
                    v_mto_lin_nuevo, v_fec_actual, null, fug_obt_cod_usu_oficial(p_cod_persona), null, 
                    v_descripcion, 'PAN', v_cod_canal, v_cod_campana, 'N');
         EXCEPTION
            WHEN others THEN
               raise_application_error(-20004,'Error al insertar en TA_SOL_LINEAS '||sqlerrm);
         END;
         --
         BEGIN
            INSERT INTO ba_tab_dat_adicionales (tab_relacion, referencia, parametro, val_parametro)
            VALUES ( 'TA_SOL_LINEAS', v_nro_solicitud, 'SCO_MUL_NRO_SOL_ORI', p_ant_nro_solicitud);
         EXCEPTION
            WHEN others THEN
               raise_application_error(-20003,'Error al insertar dato adicional SCO_MUL_NRO_SOL_ORI '||sqlerrm);
         END;
      END IF;
   END IF;  
   IF nvl(p_ind_val_scoring, 'N') = 'S' AND v_nro_solicitud is not null AND v_cod_modalidad is not null THEN
      par_per.pr_gen_rie_evaluaciones(v_nro_solicitud, v_nro_intento, v_error, v_cod_modulo, v_cod_modalidad);
      BEGIN
         SELECT a.dic_final, trunc(a.lim_max_operacion, -6)
           INTO p_sco_dic_final, p_mto_reconducido
           FROM ge_dat_rie_evaluaciones a
          WHERE a.nro_solicitud = v_nro_solicitud
            AND a.nro_intento = v_nro_intento
            AND a.cod_modulo = v_cod_modulo
            AND a.cod_modalidad = v_cod_modalidad;
      EXCEPTION
         WHEN others THEN
            p_sco_dic_final   := 'X';
            p_mto_reconducido := 0;
      END;
      -- Descontar los llamados automáticos
      IF fug_val_usu_rol('ROL_DPTO_COM_EVALUACION', USER) THEN
         v_cod_rol := fug_obt_pardinamico('ROL_DPTO_COM_EVALUACION');
      END IF;

      IF fug_val_usu_rol('ROL_DPTO_RIE_EVALUACION', USER) THEN
         v_cod_rol := fug_obt_pardinamico('ROL_DPTO_RIE_EVALUACION');
      END IF;
      BEGIN
         UPDATE ge_dat_rie_eva_intentos
            SET can_intentos = can_intentos - 1
          WHERE nro_solicitud = v_nro_solicitud
            AND cod_rol = v_cod_rol
            AND cod_modulo = v_cod_modulo
            AND cod_modalidad = v_cod_modalidad;
      EXCEPTION
         WHEN others THEN
            null;
      END;
   END IF;
   p_nvo_nro_solicitud := v_nro_solicitud; 
   p_sco_error         := v_error;
   IF p_tip_producto = 'TA' THEN
      p_tip_producto := 'Tarjeta ('||fug_obt_des_modalidad(v_cod_modalidad)||') por valor de Gs '||trim(to_char(v_monto,'999G999G999'));
   ELSIF p_tip_producto = 'AL' THEN
      p_tip_producto := 'Aumento de Línea a la cuenta: '||v_nro_cuenta||' a Gs '||trim(to_char(v_mto_lin_nuevo,'999G999G999'));
   END IF;

EXCEPTION
   WHEN others THEN
      IF sqlcode <= -20000 THEN
         raise;
      ELSE
         raise_application_error(-20000,'Error en PRT_GEN_SCO_SOLICITUD '||sqlerrm);
      END IF;
END PRT_GEN_SCO_SOLICITUD;
/

