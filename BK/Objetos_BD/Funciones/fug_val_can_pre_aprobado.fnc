CREATE OR REPLACE FUNCTION IT.FUG_VAL_CAN_PRE_APROBADO (p_cod_persona  in pr_solicitudes.cod_persona%type,
                                                     p_cod_modulo in ba_modulos.cod_modulo%type default null,
                                                     p_cod_modalidad in ge_modalidades.cod_modalidad%type default null,
                                                     p_nro_solicitud in ge_pro_pre_aprobados.nro_solicitud%type default null)
   RETURN VARCHAR2 IS   /* Verifica si el canal corresponde a un producto pre-aprobado */
   v_exi_pre_aprobado VARCHAR2(1) := 'N';
BEGIN
  if p_cod_modulo = 6 then
           SELECT distinct 'S'
             INTO v_exi_pre_aprobado
             FROM ge_pro_pre_aprobados a
            WHERE a.cod_persona = p_cod_persona
              AND a.cod_modulo = p_cod_modulo
              AND nvl(a.cod_modalidad,p_cod_modalidad) = p_cod_modalidad
              AND (a.estado = 'V' OR (a.estado = 'C' AND a.nro_solicitud = nvl(p_nro_solicitud,0)));
  else
        BEGIN
           SELECT distinct 'S'
             INTO v_exi_pre_aprobado
             FROM ge_pro_pre_aprobados a
            WHERE a.cod_persona = p_cod_persona
              AND a.cod_modulo = p_cod_modulo
              AND nvl(a.cod_modalidad, p_cod_modalidad) = p_cod_modalidad
              AND (a.estado = 'V' OR EXISTS (SELECT 1
                                             FROM  ta_solicitudes t
                                             WHERE t.cod_persona = a.cod_persona
                                               AND t.nro_solicitud = nvl(p_nro_solicitud,0)
                                               AND t.cod_modulo = a.cod_modulo
                                               AND nvl(t.cod_modalidad,p_cod_modalidad) = nvl(a.cod_modalidad,p_cod_modalidad)));
        EXCEPTION
          WHEN no_data_found THEN
             SELECT distinct 'S'
               INTO v_exi_pre_aprobado
               FROM ge_cli_aprobados_atm m,
                    ta_solicitudes       t
              WHERE m.cod_persona = t.cod_persona 
                AND m.nro_solicitud = t.nro_solicitud
                AND m.cod_persona = p_cod_persona
                AND t.nro_solicitud = nvl(p_nro_solicitud,0)
                AND nvl(t.cod_modalidad,p_cod_modalidad) =  nvl( p_cod_modalidad,t.cod_modalidad);
        END;
  end if;  
  /* SELECT 'S'
     INTO v_exi_pre_aprobado
     FROM ge_canales
    WHERE cod_canal = p_cod_canal
      AND cod_tip_canal = fug_obt_pardinamico('TIP_CAN_PRE_APROBADOS',p_cod_modulo,p_cod_modalidad);*/
   RETURN v_exi_pre_aprobado;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 'N';
END;
/

