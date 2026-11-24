CREATE OR REPLACE PROCEDURE IT.PRY_INS_APROBACION
 (P_COD_GRUPO IN AP_GRUPOS.COD_GRUPO%TYPE
 ,P_COD_TIP_REQUERIMIENTO IN AP_TIP_REQUERIMIENTOS.COD_TIP_REQUERIMIENTO%TYPE
 ,P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 ,P_ORDEN IN AP_GRU_TIP_REQ.ORDEN%TYPE
 )
 IS

/* Obtiene orden de aprobación segun grupo y tipo de requerimie */
FUNCTION LF_OBT_ORDEN
 (P_COD_GRUPO IN AP_GRU_TIP_REQ.COD_GRUPO%TYPE
 ,P_COD_TIP_REQUERIMIENTO IN AP_GRU_TIP_REQ.COD_TIP_REQUERIMIENTO%TYPE
 ,P_ORDEN IN AP_GRU_TIP_REQ.ORDEN%TYPE
 )
 RETURN NUMBER;
/* Obtiene grupo anterior de aprobación */
PROCEDURE LP_OBT_GRUPO_ANT
 (P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 ,P_COD_GRU_ANT OUT AP_GRUPOS.COD_GRUPO%TYPE
 ,P_COD_USU_ANT OUT BA_USUARIOS.COD_USUARIO%TYPE
 );
v_cod_gru_aprueba ap_grupos.cod_grupo%type;
   v_cod_gru_ant     ap_grupos.cod_grupo%type;
   v_cod_usu_ant     ba_usuarios.cod_usuario%type;
   v_estado          ap_grupos.estado%type;
   v_principal       ap_grupos.principal%type;
   v_orden           ap_gru_tip_req.orden%type;
   v_permiso         boolean;

   cursor c_ap_gru_tip_req is
       -- Selecciona el código de aprobación para el orden encontrado
       select gt.cod_gru_aprueba, ga.estado, gt.orden
       from ap_gru_tip_req   gt, ap_grupos g, ap_grupos ga
       where gt.cod_grupo = g.cod_grupo
       and gt.cod_gru_aprueba = ga.cod_grupo
       and gt.cod_tip_requerimiento = p_cod_tip_requerimiento
       and gt.cod_grupo = p_cod_grupo
       and gt.orden >= v_orden
       order by gt.cod_grupo, gt.orden;

/* Obtiene orden de aprobación segun grupo y tipo de requerimie */
FUNCTION LF_OBT_ORDEN
 (P_COD_GRUPO IN AP_GRU_TIP_REQ.COD_GRUPO%TYPE
 ,P_COD_TIP_REQUERIMIENTO IN AP_GRU_TIP_REQ.COD_TIP_REQUERIMIENTO%TYPE
 ,P_ORDEN IN AP_GRU_TIP_REQ.ORDEN%TYPE
 )
 RETURN NUMBER
 IS

V_ORDEN AP_GRU_TIP_REQ.ORDEN%TYPE;
V_MAX_ORDEN AP_GRU_TIP_REQ.ORDEN%TYPE;
Begin

    select max(orden)
    into v_max_orden
    from ap_gru_tip_req
    where cod_tip_requerimiento = p_cod_tip_requerimiento
    and cod_grupo = p_cod_grupo;

    if v_max_orden <> p_orden then
       select min(orden)
       into v_orden
       from ap_gru_tip_req
       where cod_tip_requerimiento = p_cod_tip_requerimiento
       and cod_grupo = p_cod_grupo
       and orden > p_orden;
    elsif v_max_orden = p_orden then
        v_orden := v_max_orden;
    end if;




    return v_orden;

End;
/* Obtiene grupo anterior de aprobación */
PROCEDURE LP_OBT_GRUPO_ANT
 (P_COD_REQUERIMIENTO IN AP_REQUERIMIENTOS.COD_REQUERIMIENTO%TYPE
 ,P_COD_GRU_ANT OUT AP_GRUPOS.COD_GRUPO%TYPE
 ,P_COD_USU_ANT OUT BA_USUARIOS.COD_USUARIO%TYPE
 )
 IS

V_COD_GRU_ANT AP_GRUPOS.COD_GRUPO%TYPE;
V_COD_USU_ANT VARCHAR2(240);
Begin
   Select cod_grupo, cod_usuario
   into p_cod_gru_ant, p_cod_usu_ant
   from ap_req_aprobaciones
   where cod_requerimiento = p_cod_requerimiento
   and orden = (select max(orden)
                from ap_req_aprobaciones
                where cod_requerimiento = p_cod_requerimiento);

/*exception
   when no_data_found then
   raise_application_error(-20000,'No existe Grupo y Usuario de Aprobac. para Req.:' || to_char(p_cod_requerimiento)) */

End;
Begin
      v_orden := p_orden;
      v_permiso := false;

      for r_cir in c_ap_gru_tip_req loop
          v_permiso := true;
          -- Busca el orden del circuito de aprobación
          --v_orden := lf_obt_orden(p_cod_grupo, p_cod_tip_requerimiento, v_orden);
          v_orden := r_cir.orden;

          if r_cir.estado = 'A' then
          --Inserta el registro de aprobación
             dbms_output.put_line('entro '|| r_cir.estado );
             if not r_cir.cod_gru_aprueba is null then
                Insert into ap_req_aprobaciones
                (cod_requerimiento,orden, cod_usuario, cod_grupo,estado, nota)
                values(p_cod_requerimiento, v_orden, null, r_cir.cod_gru_aprueba, 'P', null);
             end if;
             exit;
          else
             dbms_output.put_line('entro Pendiente '|| TO_CHAR(v_orden));
             lp_obt_grupo_ant( p_cod_requerimiento, v_cod_gru_ant, v_cod_usu_ant);

             if v_cod_gru_ant is null then
                v_cod_gru_ant := p_cod_grupo;
                v_cod_usu_ant := user;
             end if;
             Insert into ap_req_aprobaciones
             (cod_requerimiento,orden, cod_usuario, cod_grupo,estado, nota)
              values(p_cod_requerimiento, v_orden, v_cod_usu_ant, r_cir.cod_gru_aprueba, 'A', 'Aprobación automática por Ausencia');
          end if;
       end loop;

       if not v_permiso then
          raise_application_error(-20000,
          'Ud. no está autorizado p/ingresar este tipo de Requerimiento Grupo: ' ||to_char(p_cod_grupo) || ' - Tipo: ' ||to_char(p_cod_tip_requerimiento));
       end if;
    End;
/

