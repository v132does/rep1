CREATE OR REPLACE PROCEDURE IT.PRE_EJE_DEPURACION (P_NRO_GRUPO IN NUMBER)
 IS

   v_fecha             date := pag_cal.FU_OBT_FEC_ACTUAL(1);
   v_fec_aux           varchar2(10) :=to_char(v_fecha,'dd/mm/yyyy');
   v_frecuencia        ge_procesos_det.frecuencia%type;
   v_error             varchar2(3000);
   v_sentencia         varchar2(8000);
   v_lectura           varchar2(200);
   v_borrado           varchar2(800);
   v_truncado          varchar2(800);
   v_ult_dia_habil     ge_calendarios.ult_dia_mes_habil%type;
   v_condicion         ba_tab_depuradas.condicion%type;
   rg_prodep           ba_tab_depuradas%rowtype;
   v_men               varchar2(4000) := null;
   v_men_err           varchar2(4000) := null;
   v_men_sub           varchar2(4000) := null;
   v_existe            varchar2(1);
   v_task_name         varchar2(35);
   v_con_dbms_parallel   ba_tab_depuradas.condicion%type;
   ---- Cursor de tablas a ser depuradas --- 
   cursor c_tablas is
    select g.nro_orden,
           g.nom_tabla,
           g.nom_tab_destino,
           g.frecuencia,
           g.condicion,
           g.hor_inicio,
           g.hor_fin,
           g.error,
           g.cod_usuario,
           g.obligatorio,
           g.can_registros,
           g.tip_fecha,
           g.borrar,
           g.reemplazar,
           g.nro_grupo,
           nvl(g.limite, 80000) limite,
           g.niv_paralell
      from ba_tab_depuradas g
     where (g.frecuencia = v_frecuencia or
           (v_frecuencia = 'M' and g.frecuencia = 'D'))
       and nro_grupo = P_NRO_GRUPO
      order by g.nro_orden;



procedure lp_act_tab_depuradas(rg_proact  ba_tab_depuradas%rowtype) is
--DESOPIMI-10-Optimizar el proceso PRE_EJE_DEPURACION (Depuracion de tablas) - DYD-SDSL-3206
--Proceso Interno de Actualizacion de tablas depuradas --
begin
  update ba_tab_depuradas r
     set r.hor_inicio  = rg_proact.hor_inicio,
         r.hor_fin     = rg_proact.hor_fin,
         r.error       = rg_proact.error,
         r.cod_usuario = rg_proact.cod_usuario
   where r.nom_tabla   = rg_proact.nom_tabla;
   commit;
exception
  when others then
    raise_application_error(-20001, 'Al Actualizar depuracion de tabla:'||rg_proact.nom_tabla||' '||sqlerrm);

end lp_act_tab_depuradas;

procedure lp_baj_con_tablas(p_tab_origen   in  ba_tab_depuradas.nom_tabla%type,
                            p_mensaje      in out varchar2) is
--DESOPIMI-10-Optimizar el proceso PRE_EJE_DEPURACION (Depuracion de tablas) - DYD-SDSL-3206
--Proceso para bajar control en tablas

v_men varchar2(1000) := null;
begin

   if p_tab_origen = 'GE_CLIENTES' then
      sql_util.ejecute_dml('alter trigger AB_GE_CLIENTES_HIS DISABLE',v_men);
   elsif p_tab_origen = 'GE_CLA_OPERACIONES' then
       sql_util.ejecute_dml('alter trigger AB_GE_CLA_OPERACIONES_HIS DISABLE',v_men);
   end if;

   if v_men is not null then
      p_mensaje := v_men;
   end if;

end;

procedure lp_sub_con_tablas(p_tab_origen  in   ba_tab_depuradas.nom_tabla%type,
                           p_mensaje     in out   varchar2) is
--DESOPIMI-10-Optimizar el proceso PRE_EJE_DEPURACION (Depuracion de tablas) - DYD-SDSL-3206
--proceso para subir/levantar controles de tablas
v_men varchar2(1000) := null;

begin

   if p_tab_origen = 'GE_CLIENTES' then
      sql_util.ejecute_dml('alter trigger AB_GE_CLIENTES_HIS ENABLE',v_men);
   elsif p_tab_origen = 'GE_CLA_OPERACIONES' then
       sql_util.ejecute_dml('alter trigger AB_GE_CLA_OPERACIONES_HIS ENABLE',v_men);
   end if;

  if v_men is not null then
     v_men := v_men ||' Al subir controles de: '||p_tab_origen;
   end if;

 p_mensaje := v_men;

end;
FUNCTION lf_ver_existencia ( p_tabla IN VARCHAR2, p_condicion  IN VARCHAR2)
RETURN VARCHAR2
IS 
    v_sql    VARCHAR2(1000);
    v_count  NUMBER := 0;
    v_condicion  varchar2(3000);
BEGIN
    -- 1. Construir la sentencia SQL Din mica
    -- (Es crucial que p_condicion sea una condicion WHERE valida, sin la palabra 'WHERE')
    IF TRIM(p_condicion) =';' THEN
      v_condicion:= replace(p_condicion,';', ' where rownum=1');
    else 
     v_condicion:=  replace(p_condicion, ';', ' and rownum=1');
    end if;
    v_sql := 'SELECT COUNT(*) FROM ' || p_tabla || ' ' || v_condicion; 
    -- 2. Ejecutar la sentencia dinamicamente y obtener el conteo
    EXECUTE IMMEDIATE v_sql INTO v_count;

    -- 3. Devolver el resultado
    IF v_count > 0 THEN
        RETURN 'S';
    ELSE
        RETURN 'N';
    END IF;

EXCEPTION
    WHEN OTHERS THEN
     -- Manejo de cualquier error (tabla inexistente, sintaxis invalida en p_condicion, etc.)
     -- En caso de error, siempre es seguro devolver 'N' o un codigo de error especifico.
     RETURN 'E'; 
END;

BEGIN

   -- DESOPIMI-10-Optimizar el proceso PRE_EJE_DEPURACION (Depuracion de tablas) - DYD-SDSL-3206
   -- LCABRERA - SETIEMBRE/2016
   -- Obtiene la fecha del calendario  
   -- PBC-70-Se agrega Validacion para saber si es ejecutado desde el cierre o desde el job
   pag_cal.pr_obt_dat_calendar(1);
   v_ult_dia_habil   := pag_cal.G_ULT_DIA_MES_HABIL;
   
   --- Calcular frecuencia del proceso
   if v_fecha = v_ult_dia_habil then
      v_frecuencia := 'M';
   else
      v_frecuencia := 'D';
   end if;

   if P_NRO_GRUPO is not null then
     for r_tab in c_tablas loop
      v_men_err := null;
      pag_cie.pr_ins_log(r_tab.nro_orden||'-Procesando depuracion de la tabla '||r_tab.nom_tabla, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      lp_baj_con_tablas(r_tab.nom_tabla, v_men_err);
      if nvl(v_men_err,'N') = 'N' then
        --- Datos para actualizar: hora inicio de la tabla
        rg_prodep.nom_tabla    :=  r_tab.nom_tabla;
        rg_prodep.hor_inicio   :=  to_char(sysdate,'hh24:mi:ss');
        rg_prodep.cod_usuario  :=  user;
        rg_prodep.error        :=  null;
        v_task_name            :='pre_eje_depuracion_task_'||r_tab.nro_orden;

        v_condicion      := replace(upper(r_tab.condicion),'PAG_CAL.FU_OBT_FEC_ACTUAL(1)', 'to_date('''||v_fec_aux||''',''dd/mm/yyyy'')');
        v_condicion      := replace(v_condicion,'1=1','');
        IF v_condicion IS NOT NULL THEN
           v_con_dbms_parallel := '              where '||v_condicion||' and rowid BETWEEN :start_id AND :end_id ;';
           v_condicion := '      where '||v_condicion||';';
        ELSE
           v_con_dbms_parallel := '              where '||v_condicion||' rowid BETWEEN :start_id AND :end_id ;';
           v_condicion := ';';
        END IF;

        v_lectura := r_tab.nom_tabla||'.*';
        if r_tab.tip_fecha = 'I' then
           -- agregar la fecha al INICIO
           v_lectura := 'v_fec_proceso,'||r_tab.nom_tabla||'.*';
        elsif r_tab.tip_fecha = 'F' then
           -- agregar la fecha al FINAL
           v_lectura := r_tab.nom_tabla||'.*,v_fec_proceso';
        end if;
        -- truncate de la tabla destino antes de la carga
        if r_tab.reemplazar = 'S' then
           v_truncado :=
           'DECLARE v_msj VARCHAR2(4000); ' ||
           'BEGIN ' ||
           '  sql_util.ejecute_dml(''truncate table '||r_tab.nom_tab_destino||''',v_msj); '||
           '  if v_msj is not null then '||
           '     raise_application_error(-20001, v_msj); '||
           '  end if; '||
           'END;';
        else
           v_truncado := '';
        end if;
        -- borra de tabla origen luego del traspaso
        if r_tab.borrar = 'S' then
          --se hace truncate por que el borrado es sin condicion
          if r_tab.condicion = '1=1' and r_tab.nom_tabla <> 'GE_AUTORIZACIONES' then
           v_borrado :=
           'DECLARE v_msj VARCHAR2(4000); ' ||
           'BEGIN ' ||
           '  sql_util.ejecute_dml(''truncate table '||r_tab.nom_tabla||''',v_msj);'||
           '  if v_msj is not null then'||
           '     raise_application_error(-20001, v_msj);'||
           '  end if; '||
           'END;';
          else
              v_borrado :=  
              'DECLARE v_msj VARCHAR2(4000); ' ||
              'BEGIN ' ||
              ' delete from '||r_tab.nom_tabla|| v_condicion||
              '     commit; '||
              'END; ';
           end if;
        else
          v_borrado := '';
        end if;
          v_existe := lf_ver_existencia(r_tab.nom_tabla, v_condicion);
          IF nvl(v_existe, 'N') = 'S' THEN 
           -- truncate table
           if v_truncado is not null then 
             sql_util.ejecute_dml(v_truncado, v_error);
             v_error := replace(v_error,'SQL_UTIL.EJECUTE_DML','*');
             pag_cie.pr_ins_log(r_tab.nro_orden||'-Proceso de truncado existoso en '||r_tab.nom_tab_destino, it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
              if v_error is not null then
                pag_cie.pr_ins_log('Error en depuracion en truncado de '||r_tab.nom_tabla ||' Error: '||v_error, it.pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
                raise_application_error(-20000, substr('Tabla '||r_tab.nom_tabla||' con el Sgte error '||v_error, 1, 3000));
              end if;
           end if;
           --
           BEGIN
            DBMS_PARALLEL_EXECUTE.DROP_TASK(v_task_name);
           EXCEPTION
            WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
              NULL;
           END;
           -- Crear la tarea
           DBMS_PARALLEL_EXECUTE.create_task(v_task_name);
           -- Dividir la tabla por ROWID en intervalos de 50000
           DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID(v_task_name, 'IT', r_tab.nom_tabla , true, r_tab.limite);
           -- Ejecutar el DML en paralelo
           DBMS_PARALLEL_EXECUTE.run_task(task_name      => v_task_name,
                                          sql_stmt       =>
'DECLARE
   v_info        VARCHAR2(512);
   v_cant        PLS_INTEGER;
   v_fec_proceso date := to_date('''||v_fec_aux||''',''dd/mm/yyyy'');
   v_nom_tarea   varchar2(35):= '''||v_task_name||''';
BEGIN
   pre_ini_aplicacion;
   pae_cnf.g_cod_modulo := 1;

   pag_cie.PR_SET_PARAMETROS(11, 386, ''PRE_EJE_DEPURACION'', ''CHUNK'', pag_cie.c_log_TRACE);

   SELECT ''{job:''||job_name||'' chid:''||chunk_id||''}''
   INTO v_info
   FROM user_parallel_execute_chunks
   WHERE task_name =v_nom_tarea
     AND start_rowid = :start_id
     AND end_rowid = :end_id;

   pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] '', pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');

   SELECT COUNT(1)
   INTO v_cant
   FROM user_parallel_execute_chunks
   WHERE task_name =v_nom_tarea
     AND status = ''PROCESSED_WITH_ERROR''
     AND rownum = 1;

   IF v_cant > 0 THEN
      raise_application_error(-20015, ''Fall  un Fragmento de la Tarea. Fin por Interrupcion temparana.'');
   END IF;

   INSERT INTO '|| r_tab.nom_tab_destino ||' '||
  'SELECT ' ||v_lectura ||' '||
  ' FROM ' ||r_tab.nom_tabla||' '||r_tab.nom_tabla ||' '||
  v_con_dbms_parallel||
' EXCEPTION
   WHEN OTHERS THEN
      pag_cie.PR_INS_LOG(v_info||'' [ ''||:start_id||'' ; ''||:end_id||'' ] EXCEPTION: ''||SQLERRM, pag_cie.c_log_TRACE, ''AUTONOMOUS_TRANSACTION'');
      RAISE;
END;',
                                       language_flag  => DBMS_SQL.NATIVE,
                                       parallel_level => r_tab.niv_paralell);--nivel paralelismo

         IF DBMS_PARALLEL_EXECUTE.FINISHED != DBMS_PARALLEL_EXECUTE.TASK_STATUS(v_task_name) THEN
           raise_application_error(-20000, 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ' || v_task_name);
         END IF;
          -- truncate table
         if v_borrado is not null then 
            sql_util.ejecute_dml(v_borrado, v_error);
            v_error := replace(v_error,'SQL_UTIL.EJECUTE_DML','*');
            pag_cie.pr_ins_log(r_tab.nro_orden||'-Proceso de borrado exitoso en tabla '||r_tab.nom_tabla, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
           IF v_error IS NOT NULL THEN
             pag_cie.pr_ins_log('Error en depuracion en borrado de '||r_tab.nom_tabla ||' Error: '||v_error, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
             raise_application_error(-20000, substr('Tabla '||r_tab.nom_tabla||' con el Sgte error '||v_error, 1, 3000));
           END IF;
         END if;
         ELSIF nvl(v_existe, 'N') = 'E' THEN
          raise_application_error(-20000, 'Error en count de v_existe para la Tabla '||r_tab.nom_tabla);   
        END IF;
        --
        v_men_sub := null;
        --Levantar Controles de tablas
        lp_sub_con_tablas(r_tab.nom_tabla,v_men_sub);

       if v_error is not null then
            -- hago rollback de lo que hizo el proceso
            rollback; -- to savepoint pro_ejecutado;

            rg_prodep.error := v_error||'-'||v_sentencia;
            rg_prodep.hor_fin := to_char(sysdate,'hh24:mi:ss');
            -- Actualizacion por depuracion de la tabla
            lp_act_tab_depuradas(rg_prodep);
            pag_cie.pr_ins_log(r_tab.nro_orden||'-Error al levantar control en  '||r_tab.nom_tabla, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION'); 
           if r_tab.obligatorio = 'S' then
              raise_application_error(-20000, substr('Tabla '||r_tab.nom_tabla||' con el Sgte error '||v_error, 1, 3000));
           end if;
        end if;
            rg_prodep.hor_fin := to_char(sysdate,'hh24:mi:ss');
            -- Actualizacion por depuracion de la tabla
            lp_act_tab_depuradas(rg_prodep);
       else
            --Si se encontraron datos que se duplicara si se procesa:
            rollback; -- to savepoint pro_ejecutado;
            rg_prodep.error := substr('Problemas al Desactivar/Activar controles de tabla '||'-'||v_error, 1,3000);
            rg_prodep.hor_fin := to_char(sysdate,'hh24:mi:ss');
            -- Actualizacion por depuracion de la tabla
            lp_act_tab_depuradas(rg_prodep);
            pag_cie.pr_ins_log(r_tab.nro_orden||'-Error al bajar trigger en '||r_tab.nom_tabla, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
       end if;
       pag_cie.PR_INS_LOG(r_tab.nro_orden||'-Fin de depuracion de la tabla '||r_tab.nom_tabla, pag_cie.c_log_TRACE, 'AUTONOMOUS_TRANSACTION');
      end loop;
    else
      raise_application_error(-20000, 'Error en PRE_EJE_DEPURACION. El parámetro P_NRO_GRUPO no puede ser nulo.');   
    end if;
END;
/
