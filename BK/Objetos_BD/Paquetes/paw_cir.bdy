CREATE OR REPLACE PACKAGE BODY IT.PAW_CIR is

  /* Obtiene el codigo de error del registro del paquete. */
  FUNCTION FU_OBT_COD_ERROR
   RETURN NUMBER
   IS
  BEGIN
      return paw_cir.g_cod_error;
  END;
  /* Obtener el lugar en el que quedo cargado el registro del paquete. */
  FUNCTION FU_OBT_LUGAR
   RETURN VARCHAR2
   IS
  BEGIN
      return paw_cir.g_lugar;
  END;
  /* Obtiene el mensaje de error contenido en el registro del paquete. */
  FUNCTION FU_OBT_MSJ_ERROR
   RETURN VARCHAR2
   IS
  BEGIN
      return paw_cir.g_msj_error;
  END;
  
  /* Obtiene el mensaje de alerta contenido en el registro del paquete. */
  FUNCTION FU_OBT_MSJ_ALERTA RETURN VARCHAR2
  IS
    v_valor VARCHAR2(3000) := paw_cir.G_MSJ_ALERTA;
  BEGIN
     paw_cir.g_msj_alerta := null;
     return v_valor;
  END FU_OBT_MSJ_ALERTA;

  /* CANCELA UN CIRCUITO */
  FUNCTION FU_CAN_CIRCUITO(p_cod_circuito in number,
                           p_cod_tar_actual in number,
                           p_cod_tip_circuito in number,
                           p_cod_tip_tar_actual in number,
                           p_comentario in varchar2 default null,
                           p_cod_cau_rechazo    in ge_causales.cod_causa%type default null
                           )
    RETURN NUMBER IS
  v_condicion varchar2(3000);
  v_nom_objeto varchar2(100);
  v_nro_referencia varchar2(100);
  v_nom_referencia varchar2(100);
  v_retorno varchar2(2);
  v_plsql varchar2(4000);
  v_cod_persona varchar2(20);
  v_cir_fecha   varchar2(100); --GMPEREIRA TN-910 se obtiene este dato para diferenciar la fecha del encaje a aprobar
  
  BEGIN
    paw_cir.g_cod_error := 0;
    -- datos del circuito
    begin
       select x.cod_obj_base, x.referencia, j.referencia, cod_persona
         into v_nom_objeto, v_nom_referencia, v_nro_referencia, v_cod_persona
         from wf_tip_circuitos x, wf_circuitos j
        where x.cod_tip_circuito = p_cod_tip_circuito
          and j.cod_circuito = p_cod_circuito;
    exception
        when others then
            v_nom_objeto := '';
    end;
    
    --dato de la fecha del circuito --GMPEREIRA TN-910 se obtiene este dato para diferenciar la fecha del encaje a aprobar
    IF p_cod_tip_circuito = 998 THEN
        SELECT 'TO_DATE('||''''||SUBSTR(ct.comentario, 9, 10)||''''||', '||''''||'DD/MM/YYYY'||''''||')'
          INTO v_cir_fecha
          FROM wf_circuitos c, wf_cir_tareas ct
         WHERE c.cod_circuito = ct.cod_circuito
           AND c.cod_circuito = p_cod_circuito
           AND c.cod_tip_circuito = 998
           AND ct.cod_tip_tarea = 1
           AND ct.estado = 'P';
    END IF;
    
    -- datos del plsql de la tarea rechazada
    begin
       select x.det_sql
         into v_plsql
         from wf_tip_cir_tareas x
        where x.cod_tip_circuito = p_cod_tip_circuito
          and x.cod_tip_tarea = p_cod_tip_tar_actual;
    exception
        when others then
            v_plsql := '';
    end;
    v_plsql := replace(v_plsql,'&REFERENCIA',v_nro_referencia);
    v_plsql := replace(v_plsql,'&COD_PERSONA',v_cod_persona);
    v_plsql := replace(v_plsql,'&TIP_ACCION','C');
    v_plsql := replace(v_plsql,'&COMENTARIO',replace(p_comentario, chr(39), chr(39)||chr(39)));
    v_plsql := replace(v_plsql,'&COD_CIRCUITO',p_cod_circuito);
    v_plsql := replace(v_plsql,'&COD_TIP_TAREA',p_cod_tip_tar_actual);
    v_plsql := replace(v_plsql,'&COD_CAU_RECHAZO',p_cod_cau_rechazo);
    IF p_cod_tip_circuito = 998 THEN --GMPEREIRA TN-910
       v_plsql := replace(v_plsql,'&FECHA',v_cir_fecha);
    END IF;

    update wf_circuitos
       set fec_fin = sysdate,
           estado = 'C'
     where cod_circuito = p_cod_circuito;
    ---
    -- cancela la solicitud si existe
    --PR_ACT_EST_SOLICITUD(p_cod_tip_circuito, v_nro_referencia, 'N');
    --
    if v_plsql is not null then
      -- hay algo para ejecutar
      sql_util.ejecute_dml(v_plsql,g_msj_error);      
      if g_msj_error is not null then
         paw_cir.G_COD_ERROR := 999;
         raise_application_error(-20000,'Ejec.Rutina - '||'Cod_Circuito Nro. '||p_cod_circuito||chr(10)||
                                        'p/ cancelar cargar parametro COD_CIR_CAN_ERR_CIERRE y reprocesar'||chr(10)||
                                        g_msj_error);
      end if;
    end if;
    --
     RETURN paw_cir.g_cod_error;
  END;

  /* CANCELA UN CIRCUITO CON SOLO EL INDICADOR DEL CIRCUITO*/
  FUNCTION FU_CAN_CIRCUITO(p_cod_circuito in number)
    RETURN NUMBER IS
  v_cod_tar_actual  number;
  v_cod_tip_circuito number;
  v_cod_tip_tar_actual number;
  v_fila varchar2(500);
  BEGIN
    select cod_tarea, cod_tip_circuito, cod_tip_tarea, rowid
      into v_cod_tar_actual, v_cod_tip_circuito, v_cod_tip_tar_actual, v_fila
      from wf_cir_tareas p
     where p.cod_circuito = p_cod_circuito
       and p.estado = 'P'; -- se supone que hay un solo pendiente P
     --
     update wf_cir_tareas
        set estado = 'C'
      where rowid = v_fila;
      --
     return FU_CAN_CIRCUITO(p_cod_circuito,v_cod_tar_actual,v_cod_tip_circuito,v_cod_tip_tar_actual);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20000,'No existe circuito Nro '||p_cod_circuito||' para Cancelar.');
        return null;
  END;

  -- FUNCION QUE RETORNA SIGUIENTE TAREA DE ACUERDO A LAS CONDICIONES
  FUNCTION FU_GEN_SIG_TAREA(p_cod_circuito in number,
                            p_cod_tar_actual in number,
                            p_cod_tip_circuito in number,
                            p_cod_tip_tar_actual in number,
                            p_comentario in varchar2 default null,
                            p_tar_excepcion      in wf_tip_cir_tar_sig.tar_excepcion%type default null)
    RETURN NUMBER IS
   v_cod_tarea      number;
   v_estado         varchar2(1) := 'P';
   v_inserta boolean;
   -- cursor para verificar posibles siguientes tareas
   cursor v_sig_tareas is
     select a.cod_tip_tar_siguiente, b.descripcion, b.cod_gru_responsable, b.cod_tip_tarea, a.tar_excepcion
       from wf_tip_cir_tareas b, wf_tip_cir_tar_sig a
      where a.cod_tip_circuito = p_cod_tip_circuito
        and a.cod_tip_tarea = p_cod_tip_tar_actual
        and b.cod_tip_circuito = a.cod_tip_circuito
        and b.cod_tip_tarea = a.cod_tip_tar_siguiente;
   -- cursor para las condiciones del cada siguiente tarea
   cursor v_sig_tar_con(p_cod_tip_tar_siguiente in  number)  is
     select b.cod_campo, b.negado, b.val_defecto, c.tip_campo, c.nom_referencia, c.tip_dato
       from ge_filtros c, wf_tip_cir_tar_sig_con b
      where b.cod_tip_circuito = p_cod_tip_circuito
        and b.cod_tip_tarea = p_cod_tip_tar_actual
        and b.cod_tip_tar_siguiente = p_cod_tip_tar_siguiente
        and c.cod_campo = b.cod_campo;
  v_condicion varchar2(3000);
  v_nom_objeto varchar2(100);
  v_nro_referencia varchar2(100);
  v_nom_referencia varchar2(100);
  v_cod_persona varchar2(20);
  v_retorno varchar2(2);
  v_hay_sig_tarea boolean := false; --para ver si ya es el fin
  v_plsql varchar2(4000);
  v_cod_gru_res_actual varchar2(5);
  v_cir_fecha   varchar2(100); --GMPEREIRA TN-910 se obtiene este dato para diferenciar la fecha del encaje a aprobar
  BEGIN
      paw_cir.g_cod_error := 0;
      -- datos del circuito
      begin
         select x.cod_obj_base, x.referencia, j.referencia, cod_persona
           into v_nom_objeto, v_nom_referencia, v_nro_referencia, v_cod_persona
           from wf_tip_circuitos x, wf_circuitos j
          where x.cod_tip_circuito = p_cod_tip_circuito
            and j.cod_circuito = p_cod_circuito;
      exception
          when others then
              v_nom_objeto := '';
      end;
      
      --dato de la fecha del circuito --GMPEREIRA TN-910 se obtiene este dato para diferenciar la fecha del encaje a aprobar
      IF p_cod_tip_circuito = 998 THEN
          SELECT 'TO_DATE('||''''||SUBSTR(ct.comentario, 9, 10)||''''||', '||''''||'DD/MM/YYYY'||''''||')'
            INTO v_cir_fecha
            FROM wf_circuitos c, wf_cir_tareas ct
           WHERE c.cod_circuito = ct.cod_circuito
             AND c.cod_circuito = p_cod_circuito
             AND c.cod_tip_circuito = 998
             AND ct.cod_tip_tarea = 0
             AND ct.estado = 'A';
      END IF;
           
      -- datos del plsql de la tarea aprobada
      begin
         select x.det_sql
           into v_plsql
           from wf_tip_cir_tareas x
          where x.cod_tip_circuito = p_cod_tip_circuito
            and x.cod_tip_tarea = p_cod_tip_tar_actual;
      exception
          when others then
              v_plsql := '';
      end;
      v_plsql := replace(v_plsql,'&REFERENCIA',v_nro_referencia);
      v_plsql := replace(v_plsql,'&COD_PERSONA',v_cod_persona);
      v_plsql := replace(v_plsql,'&TIP_ACCION','A');
      v_plsql := replace(v_plsql,'&COMENTARIO',replace(p_comentario, chr(39), chr(39)||chr(39)));
      v_plsql := replace(v_plsql,'&COD_CIRCUITO',p_cod_circuito);
      v_plsql := replace(v_plsql,'&COD_TIP_TAREA',p_cod_tip_tar_actual);
      v_plsql := replace(v_plsql,'&COD_TIP_CIRCUITO',p_cod_tip_circuito);
      IF p_cod_tip_circuito = 998 THEN --GMPEREIRA TN-910
          v_plsql := replace(v_plsql,'&FECHA',v_cir_fecha);
      END IF;
      
     -- ciclo de busqueda de la siguiente tarea
     for t in v_sig_tareas loop
       v_inserta := true;
       
         --Si tiene una tarea de excepcion, envia directamente a la tarea indicada como excepcion
         If nvl(p_tar_excepcion,'N') = 'S' then
           If t.tar_excepcion = 'S' then
             v_inserta := true;
           else
             v_inserta := false;
           End if;
         else
           If nvl(t.tar_excepcion,'N') = 'N' then
         -- condiciones de la tarea
             v_condicion := '';
             for c in v_sig_tar_con(t.cod_tip_tar_siguiente) loop
                 if c.negado = 'S' then
                    v_condicion := v_condicion ||' AND NOT';
                 else
                    v_condicion := v_condicion ||' AND';
                 end if;
                 if c.tip_dato = 'V' then
                     v_condicion := v_condicion ||fue_obt_val_lista(c.nom_referencia,
                                                                           c.val_defecto,
                                                                           c.tip_campo);
                 elsif c.tip_dato = 'R' then
                     v_condicion := v_condicion ||fue_obt_val_rango(c.nom_referencia,
                                                                           c.val_defecto,
                                                                           c.tip_campo);
                 elsif c.tip_dato = 'M' then
                     v_condicion := v_condicion ||fue_obt_val_multiple(c.nom_referencia,
                                                                           c.val_defecto,
                                                                           c.tip_campo);
                 end if;
             end loop;
             if v_condicion is not null then
                v_condicion := 'SELECT ''S'' FROM '||v_nom_objeto||' P '||
                               ' WHERE '||v_nom_referencia||'='||v_nro_referencia||' '||v_condicion;

                v_retorno := fuj_pro_val_posibles(v_condicion,'N');
                if v_retorno = '#S' then
                   -- se cumplio la condicion
                   v_inserta := true;
                else
                   -- no se cumplio la condicion
                   v_inserta := false;
               end if;
              end if;
             else
               v_inserta := false;
           end if;
         end if;
         if v_inserta then
           -- inserto la nueva tarea
           v_hay_sig_tarea := true;
           insert into wf_cir_tareas
              (cod_circuito, cod_tarea, cod_tip_circuito, cod_tip_tarea,
               descripcion, estado, fec_asignacion, cod_gru_responsable, comentario)
           values
              (p_cod_circuito, p_cod_tar_actual + 1, p_cod_tip_circuito, t.cod_tip_tarea,
               t.descripcion, v_estado, sysdate, t.cod_gru_responsable, p_comentario);--TN-910 GMPEREIRA se incluye para identificar fecha de Encaje
           v_cod_gru_res_actual :=  t.cod_gru_responsable;
         end if;
     end loop;
     --
     if v_plsql is not null then
        -- hay algo para ejecutar
        sql_util.ejecute_dml(v_plsql,g_msj_error);
        if g_msj_error is not null then
           paw_cir.G_COD_ERROR := 999;
           raise_application_error(-20000,'Ejec.Rutina '||g_msj_error);
        end if;
     end if;
     --
     if not v_hay_sig_tarea then
        -- ya no hay tareas se debe cerrar el circuito
        update wf_circuitos
           set fec_fin = sysdate,
               estado = 'F'
         where cod_circuito = p_cod_circuito;
        -- finaliza la solicitud si existe
        --PR_ACT_EST_SOLICITUD(p_cod_tip_circuito, v_nro_referencia, 'A');
     elsif v_hay_sig_tarea then
        update wf_circuitos
           set cod_tar_actual = p_cod_tar_actual + 1,
               cod_gru_res_actual = v_cod_gru_res_actual
         where cod_circuito = p_cod_circuito;
     end if;
     RETURN paw_cir.g_cod_error;

  END;
  /* Genera la tarea por el rechazo de una tarea. Por ahora se genera una tarea para el anterior grupo */
  FUNCTION FU_GEN_TAR_RECHAZO(p_cod_circuito in number,
                              p_cod_tar_actual in number,
                              p_cod_tip_circuito in number,
                              p_cod_tip_tar_actual in number,
                              p_comentario in varchar2 default null,
                              p_cod_cau_rechazo    in ge_causales.cod_causa%type default null)
    RETURN NUMBER IS
   v_cod_tarea      number;
   v_estado         varchar2(1) := 'P';
   v_inserta boolean := true;
   v_condicionado        varchar2(10) := fug_obt_pardinamico('COD_CAU_CONDICIONADO');
   v_tip_tar_rechazo     ge_par_causales.val_parametro%type := null;
   v_asi_responsable     wf_tip_cir_tareas.asi_responsable%type;
   v_cod_usu_responsable wf_cir_tareas.cod_usu_responsable%type;
   v_descripcion         wf_tip_cir_tareas.descripcion%type;
   v_cod_gru_responsable wf_tip_cir_tareas.cod_gru_responsable%type;
   
   -- cursor para verificar posibles siguientes tareas
   cursor v_sig_tareas is
     select a.cod_tip_tar_siguiente, b.descripcion, b.cod_gru_responsable, b.cod_tip_tarea, b.cod_tip_tar_rechazo
       from wf_tip_cir_tareas b, wf_tip_cir_tar_sig a
      where a.cod_tip_circuito = p_cod_tip_circuito
        and a.cod_tip_tar_siguiente = p_cod_tip_tar_actual
        and b.cod_tip_circuito = a.cod_tip_circuito
        and b.cod_tip_tarea = a.cod_tip_tarea
        and b.cod_tip_tarea <> 0
        and rownum = 1; /* OJO! verificar si */

  v_condicion varchar2(3000);
  v_nom_objeto varchar2(100);
  v_nro_referencia varchar2(100);
  v_nom_referencia varchar2(100);
  v_retorno varchar2(2);
  v_plsql varchar2(4000);
  v_cod_persona varchar2(20);
  v_cir_fecha   varchar2(100); --GMPEREIRA TN-910 se obtiene este dato para diferenciar la fecha del encaje a aprobar
  
  BEGIN
    paw_cir.g_cod_error := 0;
    -- datos del circuito
    begin
       select x.cod_obj_base, x.referencia, j.referencia, cod_persona
         into v_nom_objeto, v_nom_referencia, v_nro_referencia, v_cod_persona
         from wf_tip_circuitos x, wf_circuitos j
        where x.cod_tip_circuito = p_cod_tip_circuito
          and j.cod_circuito = p_cod_circuito;
    exception
        when others then
            v_nom_objeto := '';
    end;
    
      --dato de la fecha del circuito --GMPEREIRA TN-910 se obtiene este dato para diferenciar la fecha del encaje a aprobar
    IF p_cod_tip_circuito = 998 THEN
       SELECT 'TO_DATE('||''''||SUBSTR(ct.comentario, 9, 10)||''''||', '||''''||'DD/MM/YYYY'||''''||')'
         INTO v_cir_fecha
         FROM wf_circuitos c, wf_cir_tareas ct
        WHERE c.cod_circuito = ct.cod_circuito
          AND c.cod_circuito = p_cod_circuito
          AND c.cod_tip_circuito = 998
          AND ct.cod_tip_tarea = 1
          AND ct.estado = 'P';
    END IF;
      
    -- datos del plsql de la tarea rechazada
    begin
       select x.det_sql
         into v_plsql
         from wf_tip_cir_tareas x
        where x.cod_tip_circuito = p_cod_tip_circuito
          and x.cod_tip_tarea = p_cod_tip_tar_actual;
    exception
        when others then
            v_plsql := '';
    end;
    v_plsql := replace(v_plsql,'&REFERENCIA',v_nro_referencia);
    v_plsql := replace(v_plsql,'&COD_PERSONA',v_cod_persona);
    v_plsql := replace(v_plsql,'&TIP_ACCION','R');
    v_plsql := replace(v_plsql,'&COMENTARIO',replace(p_comentario, chr(39), chr(39)||chr(39)));
    v_plsql := replace(v_plsql,'&COD_CIRCUITO',p_cod_circuito);
    v_plsql := replace(v_plsql,'&COD_TIP_TAREA',p_cod_tip_tar_actual);
    v_plsql := replace(v_plsql,'&COD_CAU_RECHAZO',p_cod_cau_rechazo);
    IF p_cod_tip_circuito = 998 THEN --GMPEREIRA TN-910
       v_plsql := replace(v_plsql,'&FECHA',v_cir_fecha);
    END IF;
    -- si fue rechazado no inserta una nueva tarea, se finaliza esta tarea 
    -- Proyecto Modificacion de datos sensibles 
    if p_cod_tip_circuito = fug_obt_pardinamico('COD_TIP_CIR_DAT_SENSIBLES') then
      v_inserta := false;
    end if;  -- condicion bankitti
    
    if p_cod_cau_rechazo is not null then
       v_tip_tar_rechazo := fug_obt_parcausales(p_cod_cau_rechazo,'COD_TAR_ASIGNADA');
    end if; -- condicion ueno
    
    -- 
   if nvl(v_tip_tar_rechazo,'0') = '0' then 
     for t in v_sig_tareas loop
       if v_inserta then
         --Verificar si la siguiente tarea tiene asignacion de usuario
             begin
                select asi_responsable
                  into v_asi_responsable
                  from wf_tip_cir_tareas
                 where cod_tip_circuito = p_cod_tip_circuito
                   and cod_tip_tarea = t.cod_tip_tarea;
             exception
                when others then
                   v_asi_responsable := 'N';
             end;
            -- raise_application_error(-20000,
             If nvl(v_asi_responsable,'N') = 'S' then
                v_cod_usu_responsable := FU_OBT_USU_RESPONSABLE(p_cod_circuito, p_cod_tip_circuito, t.cod_tip_tar_siguiente);
                If v_cod_usu_responsable is null then
                  raise_application_error(-20000,'No existe usuario responsable para la tarea');
               End if;
             End if;

             v_hor_actual := to_char(sysdate,'hh24:mi:ss');
             v_fec_actual := to_date(v_fecha||' '||v_hor_actual,'ddmmyyyy hh24:mi:ss');
         -- inserto la nueva tarea
         insert into wf_cir_tareas
            (cod_circuito, cod_tarea, cod_tip_circuito, cod_tip_tarea,
             descripcion, estado, fec_asignacion, cod_gru_responsable)
         values
            (p_cod_circuito, p_cod_tar_actual + 1, p_cod_tip_circuito, t.cod_tip_tarea,
             t.descripcion, v_estado, sysdate, t.cod_gru_responsable);
        update wf_circuitos
           set cod_tar_actual = p_cod_tar_actual + 1,
               cod_gru_res_actual = t.cod_gru_responsable
         where cod_circuito = p_cod_circuito;
       else
          -- ya no hay tareas se debe cerrar el circuito
          update wf_circuitos
             set fec_fin = sysdate,
                 estado = 'F'
           where cod_circuito = p_cod_circuito;  
       end if;
    end loop;
    --si el cursor no recupera datos finaliza el circuito
    if sql%notfound then
          update wf_circuitos
             set fec_fin = sysdate,
                 estado = 'F'
           where cod_circuito = p_cod_circuito;      
    end if;    
   else
     ---Se verifica si la tarea corresponde al circuito
       --v_cod_tip_tarea := pae_uti.fu_obt_valor(v_tip_tar_rechazo,v_posicion);
      ---Se verifica si la tarea corresponde al circuito

         begin
            select c.descripcion,c.cod_gru_responsable, asi_responsable
              into v_descripcion, v_cod_gru_responsable, v_asi_responsable
              from wf_tip_cir_tareas c
             where c.cod_tip_circuito = p_cod_tip_circuito
               and c.cod_tip_tarea = v_tip_tar_rechazo;

            If nvl(v_asi_responsable,'N') = 'S' then
               v_cod_usu_responsable := FU_OBT_USU_RESPONSABLE(p_cod_circuito, p_cod_tip_circuito, v_tip_tar_rechazo);
               If v_cod_usu_responsable is null then
                  raise_application_error(-20000,'No existe usuario responable para la tarea');
               End if;
            End if;
     --  raise_application_error(-20000,' p_cod_tar_actual '||p_cod_tar_actual);

        v_hor_actual := to_char(sysdate,'hh24:mi:ss');
        v_fec_actual := to_date(v_fecha||' '||v_hor_actual,'ddmmyyyy hh24:mi:ss');
          --inserto la nueva tarea


        if v_condicionado <> v_tip_tar_rechazo then
          insert into wf_cir_tareas
              (cod_circuito, cod_tarea, cod_tip_circuito, cod_tip_tarea,
               descripcion, estado, fec_asignacion, cod_gru_responsable, cod_usu_responsable)
          values
              (p_cod_circuito,p_cod_tar_actual + 1, p_cod_tip_circuito,v_tip_tar_rechazo,
               v_descripcion,v_estado,sysdate,v_cod_gru_responsable,v_cod_usu_responsable);
        else
      --Verificar siguiente tarea con condiciones
    ---  raise_application_error(-20000,' p_cod_tar_actual '||p_cod_tar_actual);
           paw_cir.g_cod_error := paw_cir.fu_gen_sig_tarea(p_cod_circuito, p_cod_tar_actual, p_cod_tip_circuito, v_tip_tar_rechazo);

         --raise_application_error(-20000,' p_cod_tar_actual '||p_cod_tar_actual);
            select c.cod_gru_responsable
              into v_cod_gru_responsable
                from wf_cir_tareas c
               where c.cod_tip_circuito = p_cod_tip_circuito
                 and c.cod_circuito = p_cod_circuito
                 and c.Cod_Tarea = p_cod_tar_actual + 1;
           ---  raise_application_error(-20000,' v_condicionado '||v_condicionado||' v_cod_gru_responsable '||v_cod_gru_responsable);
        end if;
          update wf_circuitos
             set cod_tar_actual = p_cod_tar_actual + 1,
                 cod_gru_res_actual = v_cod_gru_responsable
           where cod_circuito = p_cod_circuito;
       exception
          when no_data_found then
             raise_application_error(-20000,'La tarea '||v_tip_tar_rechazo||' no corresponde al tip. circuito '||p_cod_tip_circuito);
          when others then
             raise_application_error(-20001,'Error al buscar datos del tipo de tarea.'||sqlerrm);
       end;

   end if;
      
    ---
    if v_plsql is not null then
      -- hay algo para ejecutar
      sql_util.ejecute_dml(v_plsql,g_msj_error);
      if g_msj_error is not null then
         paw_cir.G_COD_ERROR := 999;
         raise_application_error(-20000,'Ejec.Rutina '||g_msj_error);
      end if;
    end if;
    RETURN paw_cir.g_cod_error;

  END;
  
  -- inicia un circuito
  FUNCTION FU_INI_CIRCUITO(p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%TYPE,
                           p_referencia       in wf_circuitos.referencia%TYPE,
                           p_cod_persona      in wf_circuitos.cod_persona%type default NULL,
                           p_comentario       in wf_cir_tareas.comentario%type default NULL)
   RETURN NUMBER IS
  v_cod_circuito number;
  v_cod_tip_tarea number;
  v_descripcion varchar2(100);
  v_cod_gru_responsable varchar2(10);
  v_cod_tar_actual number := 0;
  v_des_circuito varchar2(300);

  BEGIN
     select s_cod_circuito.nextval into v_cod_circuito from dual;

     select cod_tip_tarea, descripcion, cod_gru_responsable
       into v_cod_tip_tarea, v_descripcion, v_cod_gru_responsable
       from wf_tip_cir_tareas
      where cod_tip_circuito = p_cod_tip_circuito
        and cod_tip_tarea = (select min(cod_tip_tarea)
                               from wf_tip_cir_tareas
                              where cod_tip_circuito = p_cod_tip_circuito);
     select descripcion
       into v_des_circuito
       from wf_tip_circuitos
      where cod_tip_circuito = p_cod_tip_circuito;
      
     insert into wf_circuitos(cod_circuito,cod_tip_circuito, fec_inicio, referencia,
                              cod_tar_actual, descripcion, estado, cod_persona,
                              cod_gru_res_actual)
     values (v_cod_circuito, p_cod_tip_circuito, sysdate, p_referencia,
             v_cod_tar_actual,v_des_circuito, 'E', p_cod_persona,
             v_cod_gru_responsable);

     insert into wf_cir_tareas
        (cod_circuito, cod_tarea, cod_tip_circuito, cod_tip_tarea,
         descripcion, estado, fec_asignacion, cod_gru_responsable, fec_finalizacion,comentario)
     values
        (v_cod_circuito, v_cod_tar_actual, p_cod_tip_circuito, v_cod_tip_tarea,
         v_descripcion, 'A' /* realizado...fijo */, sysdate, v_cod_gru_responsable, sysdate,p_comentario);
     
	 --TN-910 GMPEREIRA se agrega la fecha de encaje en el comentario para MT998
	 IF p_cod_tip_circuito = 998 THEN
	    paw_cir.g_cod_error := paw_cir.FU_GEN_SIG_TAREA(v_cod_circuito, v_cod_tar_actual, p_cod_tip_circuito, v_cod_tip_tarea, p_comentario);
	 ELSE
        paw_cir.g_cod_error := paw_cir.FU_GEN_SIG_TAREA(v_cod_circuito, v_cod_tar_actual, p_cod_tip_circuito, v_cod_tip_tarea);
	 END IF;


     RETURN paw_cir.g_cod_error;
  END;
  -- Genera una hoja con los datos de la operacion asociada para visualizarlo en el seguimiento
  FUNCTION FU_OBT_DAT_OPERACION(p_cod_circuito in number)
    RETURN VARCHAR2 IS
  v_texto varchar2(4000) := '';
  v_nom_objeto varchar2(100);
  v_nro_referencia varchar2(100);
  v_nom_referencia varchar2(100);
  v_cod_tip_circuito number(5);
  v_select varchar2(4000);
  v_cod_persona varchar2(10);
  BEGIN
      begin
         select x.cod_obj_base, x.referencia, j.referencia, j.cod_tip_circuito, x.det_sql, j.cod_persona
           into v_nom_objeto, v_nom_referencia, v_nro_referencia, v_cod_tip_circuito, v_select,v_cod_persona
           from wf_tip_circuitos x, wf_circuitos j
          where x.cod_tip_circuito = j.cod_tip_circuito
            and j.cod_circuito = p_cod_circuito;
      exception
          when others then
              v_nom_objeto := '';
      end;
      v_select := replace(v_select,'&REFERENCIA',v_nro_referencia);
      v_select := replace(v_select,'&COD_PERSONA',v_cod_persona);
      
      v_texto := fuj_pro_val_posibles(v_select,'N');
      if length(v_texto) > 2 then
         -- se genero el dato
         v_texto := replace(substr(v_texto,2),'#',chr(10));
      else
         v_texto := null;
      end if;
     RETURN v_texto;
  exception
     when others then
        RETURN null;
  END;

/* retorna el tiempo insumido por una tarea, en la misma escala de tiempo definida
     para la tarea*/
  FUNCTION FU_OBT_TIEMPO(p_cod_tip_circuito in number,
                         p_cod_tip_tarea    in number,
                         p_fec_inicio       in date, 
                         p_fec_final        in date)
    RETURN number IS
     v_tip_tiempo  varchar2(1) := 'D';
     v_dif number;
   BEGIN
       select tip_tiempo
         into v_tip_tiempo 
         from wf_tip_cir_tareas
        where cod_tip_circuito = p_cod_tip_circuito
          and cod_tip_tarea    = p_cod_tip_tarea;  
             
       v_dif := nvl(p_fec_final,sysdate)-(p_fec_inicio);
       if v_tip_tiempo = 'D' then -- dia
          v_dif := v_dif;
       elsif v_tip_tiempo = 'H' then -- hora
          v_dif := v_dif * 24;
       elsif v_tip_tiempo = 'M' then -- minuto
          v_dif := v_dif * 24 * 60;
       elsif v_tip_tiempo = 'S' then -- segundo
          v_dif := v_dif * 24 * 60 * 60;
       end if;
       RETURN v_dif;
   END;

   /* retorna tiempo excedido de una tarea dada. Si no esta excedido en tiempo retorna 0(cero)*/   
   FUNCTION FU_TIE_EXCEDIDO(p_cod_circuito in number, p_cod_tarea in number)
    RETURN NUMBER IS
     v_retorno boolean := FALSE;
     v_cod_tip_circuito number;
     v_cod_tip_tarea  number; 
     v_fec_asignacion date;
     v_fec_finalizacion date;
     v_tie_estimado number;
     v_tie_insumido number;    
   BEGIN
      SELECT a.cod_tip_circuito, a.cod_tip_tarea, a.fec_asignacion, a.fec_finalizacion, b.tie_estimado
        into v_cod_tip_circuito, v_cod_tip_tarea, v_fec_asignacion, v_fec_finalizacion, v_tie_estimado
        from wf_tip_cir_tareas b, wf_cir_tareas a
       where a.cod_circuito = p_cod_circuito
         and a.cod_tarea = p_cod_tarea
         and b.cod_tip_circuito = a.cod_tip_circuito
         and b.cod_tip_tarea    = a.cod_tip_tarea;
      v_tie_insumido := fu_obt_tiempo(v_cod_tip_circuito, v_cod_tip_tarea,v_fec_asignacion, v_fec_finalizacion);
      if v_tie_insumido > nvl( v_tie_estimado, 0 ) then
         RETURN v_tie_insumido - nvl( v_tie_estimado, 0 );    
      else
         RETURN 0;
      end if;
   END;
   
   -- Obtiene el periodo de tiempo de una tarea 
   FUNCTION FU_OBT_PERIODO
   (  p_fec_insercion IN wf_circuitos.fec_insercion%TYPE,
      p_tip_tiempo    IN VARCHAR2
   ) RETURN NUMBER IS
      v_diferencia    NUMBER(10, 2);
      v_hor_desde     NUMBER(10, 2);
      v_hor_hasta     NUMBER(10, 2);
      v_min_desde     NUMBER(10, 2);
      v_min_hasta     NUMBER(10, 2);
      v_seg_desde     NUMBER(10, 2);
      v_seg_hasta     NUMBER(10, 2);
      v_tot_seg_desde NUMBER(10, 2);
      v_tot_seg_hasta NUMBER(10, 2);
   BEGIN
      IF p_tip_tiempo = 'D' THEN
         v_diferencia := trunc(SYSDATE) - trunc(p_fec_insercion);
      ELSIF p_tip_tiempo IN ('H', 'M') THEN
         v_hor_hasta := to_number(to_char(SYSDATE, 'HH24')) * 3600; --pasa a segundo las horas
         v_hor_desde := to_number(to_char(p_fec_insercion, 'HH24')) * 3600; --pasa a segundos las horas
         v_min_hasta := to_number(to_char(SYSDATE, 'MI')) * 60; --pasa a segundos los minutos
         v_min_desde := to_number(to_char(p_fec_insercion, 'MI')) * 60; --pasa a segundos los minutos
         v_seg_hasta := to_number(to_char(SYSDATE, 'SS'));
         v_seg_desde := to_number(to_char(p_fec_insercion, 'SS'));
      
         v_tot_seg_desde := nvl(v_hor_desde, 0) + nvl(v_min_desde, 0) + nvl(v_seg_desde, 0);
         v_tot_seg_hasta := nvl(v_hor_hasta, 0) + nvl(v_min_hasta, 0) + nvl(v_seg_hasta, 0);
         v_diferencia    := nvl(v_tot_seg_hasta, 0) - nvl(v_tot_seg_desde, 0);
      END IF;
      RETURN v_diferencia;
   END;
   
   --Obtiene la oficina de la operacion
   FUNCTION FU_OBT_OFICINA(p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type,
                           p_referencia in wf_circuitos.referencia%type)
     RETURN NUMBER IS
     v_cod_oficina ba_oficinas.cod_oficina%type;
     v_sql varchar2(1000);
     v_tabla wf_tip_circuitos.cod_obj_base%type;
     v_referencia wf_tip_circuitos.referencia%type;
     v_ref_cursor sql_util.T_cursor_tab;
      v_filas number;
      v_error varchar2(4000);
     BEGIN
       --Obtiene la tabla referencia del circuito
       begin
         select t.cod_obj_base,t.referencia
           into v_tabla,v_referencia
           from wf_tip_circuitos t
          where t.cod_tip_circuito = p_cod_tip_circuito;
       exception
         when no_data_found then
           raise_application_error(-20000,'No se ha encontrado el tipo de circuito '||p_cod_tip_circuito);
         when others then
           raise_application_error(-20001,'Error al buscar datos en la tabla WF_TIP_CIRCUITOS.'||SQLERRM);
       end;
       v_sql := 'select cod_oficina'||chr(10)||
                  'from '||v_tabla||chr(10)||
                 'where '||v_referencia||'= '||p_referencia;
       --ejecuta la consulta
       sql_util.ejecute_consulta(v_sql,1,v_filas,v_ref_cursor,v_error);
       if v_error is null then
          v_cod_oficina := v_ref_cursor(1).columna1;
       else
          v_cod_oficina := null;--si la tabla referencia no tiene el campo cod. oficina, esto se trata desde la pantalla  WMSEGUIM
          --raise_application_error(-20000,'Error al obtener datos de la oficina'||'-'||g_msj_error);
       end if;
       return v_cod_oficina;
   END;
   
   -- Verifica si el usuario puede ver todas las oficinas
   FUNCTION FU_VE_OFICINA(p_cod_circuito wf_circuitos.cod_circuito%TYPE,
                          p_cod_tarea   wf_cir_tareas.cod_tip_tarea%TYPE ) RETURN VARCHAR2 IS
      v_ve_oficina wf_gru_usuarios.ve_oficinas%TYPE := 'N';
      v_cod_tip_circuito wf_circuitos.cod_tip_circuito%TYPE;
      v_cod_tip_tarea   wf_tip_cir_tareas.cod_tip_tarea%TYPE;

   BEGIN 
     begin      
      select cod_tip_circuito, cod_tip_tarea
        into v_cod_tip_circuito, v_cod_tip_tarea
        from WF_CIR_TAREAS b
       where b.cod_circuito = p_cod_circuito
         and b.cod_tarea = p_cod_tarea;
   EXCEPTION
      WHEN OTHERS THEN
        null;
   END;
   
   BEGIN 
     /*SELECT nvl(ve_oficinas, 'N')
       INTO v_ve_oficina
       FROM wf_tip_cir_tareas t, wf_gru_usuarios b
      WHERE t.cod_tip_circuito = v_cod_tip_circuito
        AND t.cod_tip_tarea = v_cod_tip_tarea
        AND t.cod_gru_responsable = b.cod_grupo
        AND b.cod_usuario = USER
        AND b.estado = 'A';*/
     /** Control Dual Fase II **/
     SELECT DISTINCT nvl(ve_oficinas, 'N')
       INTO v_ve_oficina
       FROM wf_tip_cir_tareas t, wf_gru_roles b, ba_usu_roles r
      WHERE t.cod_tip_circuito = v_cod_tip_circuito
        AND t.cod_tip_tarea = v_cod_tip_tarea
        AND t.cod_gru_responsable = b.cod_grupo
        AND r.cod_usuario = USER
        AND b.estado = 'A'
        AND b.cod_rol = r.cod_rol
        AND NVL(b.ve_oficinas,'N') = 'S';
      RETURN v_ve_oficina;
   
   EXCEPTION
      WHEN no_data_found THEN
         RETURN v_ve_oficina;
      WHEN too_many_rows THEN
         RETURN v_ve_oficina;
      WHEN OTHERS THEN
         RETURN v_ve_oficina;
         end;
   END;
   
   --Procedimiento de cancelacin de automatica
   PROCEDURE PR_CAN_AUT_CIRCUITO
     IS
     cursor tip_cir_tareas is select t.cod_tip_circuito,
                                     t.tip_tiempo,
                                     t.tie_estimado,
                                     t.cod_tip_tarea,
                                     c.cod_obj_base,
                                     c.referencia,
                                     ci.cod_circuito,
                                     ci.fec_insercion,
                                     ci.cod_tar_actual,
                                     ci.referencia ref_relacion
                                from wf_tip_cir_tareas t,
                                     wf_tip_circuitos c,
                                     wf_circuitos ci,
                                     wf_cir_tareas ct
                               where ci.estado = 'E'--Estado en ejecucin                         
                                 and ci.cod_circuito = ct.cod_circuito 
                                 and ci.cod_tar_actual = ct.cod_tarea  
                                 and ci.cod_tip_circuito = ct.cod_tip_circuito 
                                 and ct.cod_tip_circuito = t.cod_tip_circuito
                                 and ct.cod_tip_tarea = t.cod_tip_tarea                                
                                 and t.act_automatica = 'S'
                                 and t.cod_tip_circuito = c.cod_tip_circuito;
     v_cod_error number(3) := 0;
     v_det_sql varchar2(1000);
     
     PROCEDURE lp_tra_env_email(p_error varchar2) IS
       -- Variables para mail
       v_para       VARCHAR2(4000);
       v_asunto     VARCHAR2(2000);
       v_texto      VARCHAR2(4000) := p_error;
       v_hin_mail ge_ra_log_mail.hor_inicio%type;
       v_hfi_mail ge_ra_log_mail.hor_fin%type;
       v_det_error ge_ra_log_mail.det_error%type;  
       v_fec_actual date;
       PRAGMA AUTONOMOUS_TRANSACTION; 
                
     BEGIN
       v_fec_actual := pag_cal.fu_obt_fec_actual(1);
       v_asunto     := 'Aviso Cancelacion de Circuito WF - Fecha '||to_char(v_fec_actual, 'DD/MM/YYYY');
       BEGIN
         v_hin_mail := to_char(sysdate, 'hh24:mi:ss');
         v_para := fug_obt_pardinamico('ENV_EMA_GUA_CIERRE');
         it_mail.mail(fug_obt_dir_correo, v_para, v_asunto, v_texto);
         v_hfi_mail := to_char(sysdate, 'hh24:mi:ss');
       EXCEPTION
         when others then
           v_det_error := substr(sqlerrm, 1, 4000);
           INSERT INTO ge_ra_log_mail 
           (fec_envio, nom_archivo, dir_correo, mensaje,
            det_error, hor_inicio, hor_fin)
           VALUES 
           (SYSDATE, null, v_para, v_asunto||'-'|| v_texto,
            v_det_error, v_hin_mail, v_hfi_mail);
        commit;
       END;        
     END lp_tra_env_email;
     
     procedure lp_ver_can_cir_error is 
       --Ref. DYDMR-8157--
       --Para cancelar circuitos cargados en parametro--
       v_cod_cir_can_err_cierre ge_par_dinamicos.val_parametro%type;
       v_det_cir_errores  varchar2(4000);
       v_con_cir_detalle  number(4);
       
       cursor c_cir_cancelar is 
          select x.cod_circuito, x.cod_tip_circuito, x.descripcion, 
                 x.referencia, x.cod_persona, x.rowid registro
            from WF_CIRCUITOS x
           where x.estado = 'E'--Estado en ejecucin  
             and instr(nvl(v_cod_cir_can_err_cierre, '0'), x.cod_circuito) > 0
             and exists (select 1
                           from wf_tip_cir_tareas t, wf_tip_circuitos c, wf_cir_tareas ct
                          where x.cod_circuito = ct.cod_circuito 
                            and x.cod_tar_actual = ct.cod_tarea  
                            and x.cod_tip_circuito = ct.cod_tip_circuito 
                            and ct.cod_tip_circuito = t.cod_tip_circuito
                            and ct.cod_tip_tarea = t.cod_tip_tarea                                
                            and t.act_automatica = 'S'
                            and t.cod_tip_circuito = c.cod_tip_circuito);
       
     begin
       v_cod_cir_can_err_cierre := fug_obt_pardinamico('COD_CIR_CAN_ERR_CIERRE');
       v_det_cir_errores := null;
       
       if v_cod_cir_can_err_cierre is not null then
          v_con_cir_detalle := 0;
          for det in c_cir_cancelar loop
              --Cancelar Circuitos cargados en parametro--
              update WF_CIRCUITOS t
                 set t.estado = 'C'
               where t.rowid = det.registro;
              v_con_cir_detalle := v_con_cir_detalle + 1;
              if v_con_cir_detalle = 1 then
                 v_det_cir_errores := 'Circuitos WF Cancelados por errores en el Cierre (11-25-PAW_CIR.PR_CAN_AUT_CIRCUITO)'||chr(10);
                 v_det_cir_errores := v_det_cir_errores || 
                                      'Codigo Circuito - Tipo de Circuito - Descripcion - Referencia - Cod_persona'||chr(10)||
                                      '---------------   ----------------   -----------   ----------   -----------'||chr(10);
              end if;
              v_det_cir_errores := v_det_cir_errores||
              det.cod_circuito||' - '||det.cod_tip_circuito||' - '||det.descripcion||' - '||
              det.referencia||' - '||det.cod_persona||chr(10);
          end loop;
          v_det_cir_errores := v_det_cir_errores||chr(10)||'Observacion:'||chr(10)||
                               'Realizar seguimiento operativo.';
          if v_con_cir_detalle > 0 then
             lp_tra_env_email(v_det_cir_errores);
          end if;
       end if;
     end;
   BEGIN
     --Ref. DYDMR-8157--
     --Agregado para cancelar circuitos cargados en parametro--
     lp_ver_can_cir_error;
     for t in tip_cir_tareas loop
        if t.tie_estimado is not null then
           if t.tip_tiempo = 'D' then
              if t.tie_estimado <= PAW_CIR.fu_obt_periodo(t.fec_insercion,t.tip_tiempo) then
                 v_cod_error := PAW_CIR.fu_can_circuito(t.cod_circuito,t.cod_tar_actual,t.cod_tip_circuito,t.cod_tip_tarea,'Cancelacin automtica porque no fu aprobado en el periodo establecido.');
                 if nvl(v_cod_error,0) = 0 then
                    v_det_sql := 'update '||t.cod_obj_base||chr(10)||
                                    'set estado ='||chr(39)||'C'||chr(39)||chr(10)||
                                  'where '||t.referencia||'='||t.ref_relacion;
                    sql_util.ejecute_dml(v_det_sql,g_msj_error);
                    if g_msj_error is not null then
                       PAW_CIR.G_COD_ERROR := 999;
                       raise_application_error(-20000,'Error al actualizar la tabla'||v_det_sql||t.cod_obj_base||'-'||g_msj_error);
                    end if;
                 else
                    raise_application_error(-20001,'Error al cancelar el circuito'||v_cod_error||'-'||
                    t.cod_circuito||'-'||t.cod_tar_actual||'-'||t.cod_tip_circuito||'-'||t.cod_tip_tarea);
                 end if;
              end if;
           else
              if t.tip_tiempo = 'H' then
                 if (t.tie_estimado*3600) < PAW_CIR.fu_obt_periodo(t.fec_insercion,t.tip_tiempo) then
                    v_cod_error := paw_cir.fu_can_circuito(t.cod_circuito,t.cod_tar_actual,t.cod_tip_circuito,t.cod_tip_tarea,'Cancelacion automatica porque no fue aprobado en el periodo establecido.');
                    if nvl(v_cod_error,0) = 0 then
                       v_det_sql := 'update '||t.cod_obj_base||chr(10)||
                                       'set estado ='||chr(39)||'C'||chr(39)||chr(10)||
                                     'where '||t.referencia||'='||t.ref_relacion;
                       sql_util.ejecute_dml(v_det_sql,g_msj_error);
                       if g_msj_error is not null then
                          PAW_CIR.G_COD_ERROR := 999;
                          raise_application_error(-20000,'Error al actualizar la tabla'||t.cod_obj_base||'-'||g_msj_error);
                       end if;
                    else
                      raise_application_error(-20001,'Error al cancelar el circuito.'||v_cod_error);
                    end if;
                 end if;
              elsif t.tip_tiempo = 'M' then
                 if (t.tie_estimado*60) < PAW_CIR.fu_obt_periodo(t.fec_insercion,t.tip_tiempo) then
                    v_cod_error := PAW_CIR.fu_can_circuito(t.cod_circuito,t.cod_tar_actual,t.cod_tip_circuito,t.cod_tip_tarea,'Cancelacin automtica porque no fu aprobado en el periodo establecido.');
                    if nvl(v_cod_error,0) = 0 then
                       v_det_sql := 'update '||t.cod_obj_base||chr(10)||
                                       'set estado ='||chr(39)||'C'||chr(39)||chr(10)||
                                     'where '||t.referencia||'='||t.ref_relacion;
                       sql_util.ejecute_dml(v_det_sql,g_msj_error);
                       if g_msj_error is not null then
                          PAW_CIR.G_COD_ERROR := 999;
                          raise_application_error(-20000,'Error al actualizar la tabla'||t.cod_obj_base||'-'||g_msj_error);
                       end if;
                    else
                      raise_application_error(-20001,'Error al cancelar el circuito.'||v_cod_error);
                    end if;
                 end if;
              end if;
           end if;
        end if;
     end loop;
   END;

   FUNCTION FU_VER_VAL_REFERENCIA(p_cod_obj_base     in wf_tip_circuitos.cod_obj_base%type,
                                  p_referencia       in wf_tip_circuitos.referencia%type,
                                  p_val_referencia   in wf_circuitos.referencia%type,
                                  p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type default null)
   RETURN VARCHAR2 IS
     v_existe varchar2(1) := 'N';
   BEGIN
     begin
       select 'S'
         into v_existe
         from wf_circuitos c
        where c.estado not in('C','F')
          and exists(select 1
                       from wf_tip_circuitos t
                      where t.cod_tip_circuito = c.cod_tip_circuito
                        and t.cod_obj_base = upper(p_cod_obj_base)
                        and t.referencia = upper(p_referencia))
          and c.referencia = p_val_referencia
          and (c.cod_tip_circuito = p_cod_tip_circuito or p_cod_tip_circuito is null)
          and rownum = 1;
     exception
       when no_data_found then
          v_existe := 'N';
       when others then
          raise_application_error(-20000,'Error al buscar la referencia del circuito.'||sqlerrm);
     end;
     return nvl(v_existe,'N');
   END FU_VER_VAL_REFERENCIA;
   
   /* Indica si el usuario pertenece o no al grupo */
FUNCTION FU_EXI_GRU_USUARIO (p_cod_grupo   in wf_grupos.cod_grupo%type,
                                p_cod_usuario in ba_usuarios.cod_usuario%type
                              ) RETURN VARCHAR2 DETERMINISTIC
  IS
    v_existe    varchar2(1);
    --v_retorno   varchar2(100);
    --v_sentencia wf_grupos.det_sql%type;
    --v_cursor    SYS_REFCURSOR;
  BEGIN
    begin
      select 'S'
        into v_existe
        from wf_gru_usuarios
       where cod_grupo = p_cod_grupo
         and cod_usuario = p_cod_usuario;
    exception
      when no_data_found then
        v_existe:= 'N';
        raise_application_error(-20000, 'No existe el Usuario '||p_cod_usuario||' en el grupo de workflow ' || p_cod_grupo);
    end;

    return v_existe;
  END FU_EXI_GRU_USUARIO;   
   
   /*Obtiene el usuario responsable para una tarea*/
   FUNCTION FU_OBT_USU_RESPONSABLE( p_cod_circuito       in wf_circuitos.cod_circuito%type,
                                    p_cod_tip_circuito   in wf_tip_circuitos.cod_tip_circuito%type,
                                    p_cod_tip_tar_actual in wf_tip_cir_tar_sig.cod_tip_tarea%type)
   RETURN VARCHAR2 IS
      v_can_tar_usuario     number(6);
      v_cod_usu_responsable wf_cir_tareas.cod_usu_responsable%TYPE;
      v_cod_gru_responsable wf_cir_tareas.cod_gru_responsable%TYPE;
      v_cod_persona         ba_personas.cod_persona%type;
      v_can_min             number;
      v_nro_solicitud       pr_solicitudes.nro_solicitud%type;

      cursor usuarios is
        select x.ver_otr_oficina,
               x.cod_usuario,
               h.referencia,
               (select count(1)
                  from wf_cir_tareas t, wf_circuitos c
                 where t.cod_tip_circuito = a.cod_tip_circuito
                   and cod_tip_tarea = a.cod_tip_tarea
                   and t.cod_circuito = c.cod_circuito
                   and t.cod_tip_circuito = c.cod_tip_circuito
                   and t.estado = 'P'
                   and c.estado = 'E'
                   and cod_usu_responsable = x.cod_usuario) can_tarea
          from wf_tip_cir_tareas a, wf_gru_usuarios x, wf_grupos t, wf_circuitos h, wf_cir_tareas g, ba_usuarios u
         where a.cod_tip_circuito    = p_cod_tip_circuito
           and a.cod_tip_tarea       = p_cod_tip_tar_actual
           and a.cod_gru_responsable = x.cod_grupo
           and x.cod_grupo           = t.cod_grupo
           and x.estado              = 'A'
           and h.estado              = 'E'
           and  nvl(x.exc_usuario,'N')= 'N'
           and x.cod_usuario         = u.cod_usuario
           and u.estado              = 'A'
           and a.cod_tip_circuito    = g.cod_tip_circuito
           and h.cod_circuito        = g.cod_circuito
           and h.cod_tip_circuito    = g.cod_tip_circuito
           and h.cod_tar_actual      = g.cod_tarea
           and g.cod_circuito        = p_cod_circuito
           and (paw_cir.fu_exi_gru_usuario(x.cod_grupo, x.cod_usuario) = 'S')
           and (((fug_obt_ofi_usuario(x.cod_usuario) = fug_obt_ofi_usuario(h.usu_insercion)) or x.ver_otr_oficina = 'S'))
        order by 1;

      cursor usu_tarea is
         select distinct cod_usu_responsable, count(*)
           from wf_cir_tareas a, wf_grupos c, wf_gru_usuarios x, ba_usuarios u
          where cod_tip_circuito      = p_cod_tip_circuito
            and cod_tip_tarea         = p_cod_tip_tar_actual
            and a.estado = 'P'
            and a.cod_gru_responsable  = c.cod_grupo
            and a.cod_gru_responsable = x.cod_grupo
            and x.estado              = 'A'
            and nvl(x.exc_usuario,'N') = 'N'
            and x.cod_usuario         = u.cod_usuario
            and u.estado              = 'A'
            and a.cod_usu_responsable = x.cod_usuario
            and (paw_cir.fu_exi_gru_usuario(a.cod_gru_responsable, a.cod_usu_responsable) = 'S')
            and (((fug_obt_ofi_usuario(a.cod_usu_responsable) = fug_obt_ofi_usuario(a.usu_insercion)) or x.ver_otr_oficina = 'S'))
         group by cod_usu_responsable
         order by 2;

   BEGIN
     --Verificar si el cliente ya fue asignado a un responsable anteriormente,y en otros circuitos del mismo tipo
      begin
         select cod_persona
           into v_cod_persona
           from wf_circuitos
          where cod_circuito     = p_cod_circuito
            and cod_tip_circuito = p_cod_tip_circuito;

          --Obtiene el usuario responsable
          select t.cod_usu_responsable
            into v_cod_usu_responsable
            from wf_cir_tareas t,
                 wf_gru_usuarios u,
                 wf_circuitos c,
                 wf_tip_cir_tareas d
           where t.cod_circuito <> p_cod_circuito
             and t.cod_tip_circuito = p_cod_tip_circuito
             and t.cod_tip_tarea = p_cod_tip_tar_actual
             and t.cod_circuito = c.cod_circuito
             and t.cod_tip_circuito = c.cod_tip_circuito
             and c.estado = 'E'
             and c.cod_persona = v_cod_persona
             and t.cod_tip_circuito = d.cod_tip_circuito
             and t.cod_tip_tarea = d.cod_tip_tarea
             and d.cod_gru_responsable = u.cod_grupo
             and t.cod_usu_responsable = u.cod_usuario
             and nvl(u.exc_usuario,'N') = 'N'
             and u.estado = 'A'
             and rownum = 1;

      exception
         when no_data_found then
            v_cod_usu_responsable := null;
      end;
     --- raise_application_error(-20000,'v_cod_usu_responsable '||v_cod_usu_responsable);

       if v_cod_usu_responsable is null then
          select cod_gru_responsable
           into v_cod_gru_responsable
           from wf_tip_cir_tareas t
          where cod_tip_circuito = p_cod_tip_circuito
            and cod_tip_tarea = p_cod_tip_tar_actual;


           if nvl(fug_obt_pardinamico('GEN_GRU_PROMOTOR'),'999')  = v_cod_gru_responsable then
                  select referencia
                    into v_nro_solicitud
                    from wf_circuitos
                   where cod_circuito = p_cod_circuito;

                 v_cod_usu_responsable := fug_obt_usu_sol_promotor( v_nro_solicitud );

           end if;
        end if;

     if v_cod_usu_responsable is null then
        --Si la tarea alguna vez estuvo en ejecucion debe volver al usuario que fue responsable de dicha tarea.
        begin
          select t.cod_usu_responsable
            into v_cod_usu_responsable
            from wf_cir_tareas t,
                 wf_circuitos c,
                 wf_tip_cir_tareas a,
                 wf_gru_usuarios u
           where t.cod_circuito = p_cod_circuito
             and t.cod_tip_tarea = p_cod_tip_tar_actual
             and t.cod_circuito = c.cod_circuito
             and c.estado = 'E'
             and t.cod_tip_circuito = a.cod_tip_circuito
             and t.cod_tip_tarea = a.cod_tip_tarea
             and a.cod_gru_responsable = u.cod_grupo
             and t.cod_usu_responsable = u.cod_usuario
             and u.estado = 'A'
             and nvl(u.exc_usuario,'N') = 'N'
             and rownum = 1;
        exception
          when no_data_found then
             v_cod_usu_responsable := null;
        end;
     end if;
     --Asigna al mismo usuario de la tarea anterior si se encuentra en el grupo responsable.
     if v_cod_usu_responsable is null then
        begin
          select u.cod_usuario
            into v_cod_usu_responsable
            from wf_tip_cir_tareas t,
                 wf_gru_usuarios u,
                 wf_cir_tareas a
           where t.cod_tip_circuito = p_cod_tip_circuito
             and t.cod_tip_tarea = p_cod_tip_tar_actual
             and t.cod_gru_responsable = u.cod_grupo
             and u.estado = 'A'
             and nvl(u.exc_usuario,'N') = 'N'
             and u.cod_usuario = a.cod_usu_responsable
             and a.cod_circuito = p_cod_circuito
             and a.cod_tip_circuito = p_cod_tip_circuito
             and a.estado = 'P';
        exception
          when no_data_found then
            v_cod_usu_responsable := null;
        end;
     end if;

     if v_cod_usu_responsable is null then

          for i in usuarios loop
             If (i.cod_usuario = fug_obt_usu_ofi_cliente(v_cod_persona) or i.ver_otr_oficina = 'S') or
                (user = fug_obt_usu_ofi_cliente( v_cod_persona ) or i.ver_otr_oficina = 'S') then
               --Obtener cuantas tareas tiene asignado un usuario
               select count(1)
                 into v_can_tar_usuario
                 from wf_cir_tareas t, wf_circuitos c
                where t.cod_tip_circuito      = p_cod_tip_circuito
                  and t.cod_tip_tarea         = p_cod_tip_tar_actual
                  and t.cod_circuito = c.cod_circuito
                  and t.cod_tip_circuito = c.cod_tip_circuito
                  and c.estado = 'E'
                  and t.estado in('P')
                   -- or (t.estado in ('R','C')/* and trunc(fec_insercion) = trunc(sysdate)*/))
                  and cod_usu_responsable   = i.cod_usuario;

                if v_can_min is null then
                   v_can_min := v_can_tar_usuario;
                   v_cod_usu_responsable := i.cod_usuario;
                elsif v_can_min > v_can_tar_usuario then
                   v_can_min := v_can_tar_usuario;
                   v_cod_usu_responsable := i.cod_usuario;
                end if;
             End if;
          end loop;
      End if;

      If v_cod_usu_responsable is null then

         select cod_gru_responsable
           into v_cod_gru_responsable
           from wf_tip_cir_tareas t
          where cod_tip_circuito = p_cod_tip_circuito
            and cod_tip_tarea = p_cod_tip_tar_actual;



         If nvl(fug_obt_pardinamico('GEN_GRU_OFI_WORKFLOW'),'999')  = v_cod_gru_responsable then
           v_cod_usu_responsable := fug_obt_usu_ofi_cliente( v_cod_persona );
         elsif nvl(fug_obt_pardinamico('GEN_GRU_PROMOTOR'),'999')  = v_cod_gru_responsable then
            select referencia
              into v_nro_solicitud
              from wf_circuitos
             where cod_circuito = p_cod_circuito;
           v_cod_usu_responsable := fug_obt_usu_sol_promotor( v_nro_solicitud );
         else
           for j in usu_tarea loop
             v_cod_usu_responsable := j.cod_usu_responsable;
             exit;
           End loop;
         End if;
      End if;

      return v_cod_usu_responsable;

   END FU_OBT_USU_RESPONSABLE;
   
   /* Veriifica si tiene tareas pendiente y cancela*/
   FUNCTION FU_CAN_CIR_PENDIENTES(p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type,
                                  p_cod_persona      in wf_circuitos.cod_persona%type)
     RETURN NUMBER IS
     /* Cancela WORKFLOW abierto */
     cursor cur_cir_pend is
       select cod_circuito
         from wf_circuitos
        where cod_tip_circuito = p_cod_tip_circuito
          and cod_persona = p_cod_persona
          and estado not in ('C', 'F');

   BEGIN
     paw_cir.g_cod_error := 0;
     --Se cancela el circuito
     for cp in cur_cir_pend loop
       --Se actualiza a cancelada las tareas para las tablas
       update wf_cir_tareas ct
          set ct.estado = 'C'
        where ct.cod_circuito = cp.cod_circuito
          and ct.estado = 'P';

       update wf_circuitos c
          set c.estado = 'C'
        where c.cod_circuito = cp.cod_circuito;
     end loop;
     RETURN paw_cir.g_cod_error;
   END;
   /* Veriifica si tiene tareas pendiente y Finaliza*/
   FUNCTION FU_FIN_CIR_PENDIENTES(p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type,
                                  p_cod_persona      in wf_circuitos.cod_persona%type)
     RETURN NUMBER IS
     /* Cancela WORKFLOW abierto */
     cursor cur_cir_pend is
       select cod_circuito
         from wf_circuitos
        where cod_tip_circuito = p_cod_tip_circuito
          and cod_persona = p_cod_persona
          and estado not in ('C', 'F');

   BEGIN
     paw_cir.g_cod_error := 0;
     --Se cancela el circuito
     for cp in cur_cir_pend loop
       --Se actualiza a cancelada las tareas para las tablas
       update wf_cir_tareas ct
          set ct.estado = 'A'
        where ct.cod_circuito = cp.cod_circuito
          and ct.estado = 'P';

       update wf_circuitos c
          set c.estado = 'F'
        where c.cod_circuito = cp.cod_circuito;
     end loop;
     RETURN paw_cir.g_cod_error;
   END;
    FUNCTION FU_FIN_CIR_PEN_COD (p_cod_tip_circuito in wf_circuitos.cod_tip_circuito%type,
                                p_cod_circuito     in wf_circuitos.cod_circuito%type,
                                p_estado           in wf_circuitos.estado%type)
     RETURN NUMBER IS
     /* Cancela WORKFLOW abierto */
     cursor cur_cir_pend is
       select cod_circuito
         from wf_circuitos
        where cod_tip_circuito = p_cod_tip_circuito
          and cod_circuito = p_cod_circuito
          and estado not in ('C', 'F');
   
   BEGIN
     paw_cir.g_cod_error := 0;
     --Se cancela el circuito
     for cp in cur_cir_pend loop
       --Se actualiza a cancelada las tareas para las tablas
       update wf_cir_tareas ct
          set ct.estado = p_estado
        where ct.cod_circuito = cp.cod_circuito
          and ct.estado = 'P';
       
       update wf_circuitos c
          set c.estado = 'F',
          c.fec_fin=sysdate
        where c.cod_circuito = cp.cod_circuito;
     end loop;
     RETURN paw_cir.g_cod_error;
   END;
end paw_cir;
/

