CREATE OR REPLACE PROCEDURE IT.PRG_EJE_CRC_MENSUAL  IS
  ------------------------------------------------------------------------------
  -- PROCEDURE: PRG_EJE_CRC_MENSUAL
  --
  -- Orquestador del proceso CRC mensual. Itera sobre los subprocesos configurados
  -- (PAS_CRI.PR_CRC_GEN_DATOS, PR_CRC_GEN_SALDOS, PR_CRC_GEN_CLASIF, etc.) y los
  -- ejecuta si sus tablas destino no tienen datos para la fecha del ultimo dia
  -- habil del mes.
  --
  -- Validaciones previas:
  --   - Verifica que la base actual sea la base objetivo (BA_OBJ_CRC_MENSUAL).
  --   - Bloquea ejecucion en base productiva (BA_PRO_CRC_CONTROL).
  --
  -- Registra inicio y fin de cada subproceso en GE_LOG_PROCESOS.
  -- En caso de error en un subproceso, registra el error y detiene la iteracion.
  --
  -- Invocado por: IT.JOB_PRO_CRC_MENSUAL (DBMS_SCHEDULER)
  -- Ambientes: FINMES
  --
  -- Modificaciones:
  --   SRER-5770 (14/07/2026) - DDBAINOTTI: Se agrega este header descriptivo.
  ------------------------------------------------------------------------------

   -- Type para mapear procesos con tablas asociadas
    TYPE t_tabla_info IS RECORD (
    nombre_tabla    VARCHAR2(100),
    campo_fecha     VARCHAR2(100)
    );
    TYPE t_tablas IS TABLE OF t_tabla_info;

    TYPE t_proceso_info IS RECORD (
        nombre  VARCHAR2(200),
        tablas  t_tablas
    );
    TYPE t_procesos IS TABLE OF t_proceso_info;

    v_procesos t_procesos := t_procesos(
                             t_proceso_info('IT.PAS_CRI.PR_CRC_GEN_DATOS',
                             t_tablas(
                             --t_tabla_info('sb_crc_operaciones', 'fec_periodo'),
                             t_tabla_info('sb_crc_operaciones_det','fecha'))),

                             t_proceso_info('IT.PAS_CRI.PR_CRC_GEN_SALDOS',
                             t_tablas(
                             t_tabla_info('sb_crc_saldos','fec_periodo'),
                             t_tabla_info('sb_crc_saldos_det','fecha'))),

                             t_proceso_info('IT.PAS_CRI.PR_CRC_GEN_CLASIF',
                             t_tablas(
                             t_tabla_info('sb_crc_clasificaciones','fec_periodo'),
                             t_tabla_info('sb_crc_clasificaciones_det','fecha'))),

                             t_proceso_info('IT.PAS_CRI.PR_CRC_GEN_GARANTIAS',
                             t_tablas(
                             t_tabla_info('sb_crc_garantias','fec_periodo'),
                             t_tabla_info('sb_crc_garantias_det','fecha'))),

                             t_proceso_info('IT.PAS_CRI.PR_CRC_OPE_GAR',
                             t_tablas(
                             t_tabla_info('sb_crc_ope_garantias', 'fec_periodo'),
                             t_tabla_info('sb_crc_ope_garantias_det', 'fecha'))),

                             t_proceso_info('IT.PAS_CRI.PR_CRC_GEN_ACT_VIN',
                             t_tablas(
                             --t_tabla_info('sb_crc_act_vinculos', 'fec_periodo'),
                             t_tabla_info('sb_crc_act_vinculos_det', 'fecha'))),

                             t_proceso_info('IT.PAS_CRI.PR_CRC_GEN_MOVIMIENTOS',
                             t_tablas(
                             t_tabla_info('sb_crc_movimientos','fec_periodo'),
                             t_tabla_info('sb_crc_movimientos_det','fecha'))));

   v_cant             NUMBER;
   v_con_reg          BOOLEAN;
   v_error            varchar2(1) := 'N';

   v_fec_cierre       DATE                   := fug_obt_pardinamico('FEC_CIE_CRC_MENSUAL');
   v_base_objetivo    CONSTANT VARCHAR2(20)  := UPPER(TRIM(fug_obt_pardinamico('BA_OBJ_CRC_MENSUAL')));
   v_base_actual      CONSTANT VARCHAR2(20)  := UPPER(TRIM(SYS_CONTEXT('USERENV','DB_UNIQUE_NAME')));
   v_base_prod        CONSTANT VARCHAR2(20)  := UPPER(TRIM(fug_obt_pardinamico('BA_PRO_CRC_CONTROL')));
   v_fec_actual       DATE                   := pag_cal.fu_obt_fec_actual(1);
   v_fec_ult_dia_mes_habil  DATE;
   v_fec_ult_dia_mes        DATE;
   v_rowid_log ROWID;
   v_error_msg VARCHAR2(4000);

procedure prg_act_log_procesos_rowid(
    p_cod_programa in varchar2,
    p_cod_proceso  in varchar2,
    p_fecha        in date,
    p_hor_inicio   in varchar2,
    p_hor_fin      in varchar2,
    p_observacion  in varchar2 default null,
    p_rowid_out    out rowid
) is
    pragma autonomous_transaction;
begin
    insert into ge_log_procesos (
        cod_programa, cod_proceso, fecha, hor_inicio, hor_fin, observacion
    )
    values (
        upper(p_cod_programa), upper(p_cod_proceso), p_fecha, p_hor_inicio, p_hor_fin, p_observacion
    )
    returning rowid into p_rowid_out;

    commit;
exception
    when others then
        raise_application_error(-20004, 'Error en PRG_ACT_LOG_PROCESOS_ROWID: ' || sqlerrm);
end;


 BEGIN
  pag_cal.pr_obt_dat_calendar(1);
  v_fec_ult_dia_mes_habil    := pag_cal.G_ULT_DIA_MES_HABIL;
  v_fec_ult_dia_mes          := pag_cal.G_ULT_DIA_MES;

  begin pre_ini_aplicacion;
  pae_cnf.g_cod_modulo := 1;
  end;

    --verificar si es finmes
    IF v_base_actual != v_base_objetivo THEN
      RAISE_APPLICATION_ERROR(-20001, 'Inserción prohibida en base que no sea finmes  |  Base actual: ' || v_base_actual);
    END IF;

    --Controlar que no se permita insertar en base productiva
    IF v_base_actual = v_base_prod THEN
      RAISE_APPLICATION_ERROR(-20001, 'Inserción prohibida en base productiva  |  Base actual: ' ||v_base_actual);
    END IF;

    --abrimos el modulo 1
    update ba_modulos
      set estado = 2
    where cod_modulo = 1;

    -- 1) Revisar si las tablas de los procesos tienen datos para la fecha
    FOR i IN 1 .. v_procesos.COUNT LOOP
        EXIT WHEN v_error = 'S';

        DBMS_OUTPUT.PUT_LINE('Verificando proceso: ' || v_procesos(i).nombre);
        v_con_reg := TRUE;

        -- Verificación de datos en las tablas
        FOR j IN 1 .. v_procesos(i).tablas.COUNT LOOP
            EXECUTE IMMEDIATE
                'SELECT COUNT(*) FROM ' || v_procesos(i).tablas(j).nombre_tabla ||
                ' WHERE TRUNC(' || v_procesos(i).tablas(j).campo_fecha || ') >= :1'
            INTO v_cant
            USING v_fec_ult_dia_mes_habil;

            IF v_cant > 0 THEN
                DBMS_OUTPUT.PUT_LINE('La tabla ' || v_procesos(i).tablas(j).nombre_tabla ||
                    ' tiene ' || v_cant || ' registros para la fecha ' || TO_CHAR(v_fec_ult_dia_mes_habil, 'DD-MM-YYYY') ||
                    '. No se ejecutará este proceso.');
                v_con_reg := FALSE;
                EXIT;
            END IF;
        END LOOP;

        -- Si no hay datos, y no hubo errores
        IF v_con_reg AND v_error = 'N' THEN
            BEGIN
                PRG_ACT_LOG_PROCESOS_ROWID('PRG_EJE_CRC_MENSUAL', v_procesos(i).nombre,
                    TRUNC(SYSDATE), TO_CHAR(SYSDATE,'HH24:MI:SS'), TO_CHAR(SYSDATE,'HH24:MI:SS'),
                    'Inicio ejecución del proceso.', v_rowid_log);
                IF v_procesos(i).nombre = 'IT.PAS_CRI.PR_CRC_GEN_DATOS' THEN
                   IT.PAS_CRI.PR_CRC_GEN_DATOS(P_TIP_PERIODO => 'D');
                ELSIF v_procesos(i).nombre = 'IT.PAS_CRI.PR_CRC_GEN_CLASIF' THEN
                   IF v_fec_actual = v_fec_ult_dia_mes_habil AND  v_fec_ult_dia_mes = v_fec_ult_dia_mes_habil THEN
                     IT.PAS_CRI.PR_CRC_GEN_CLASIF(P_TIP_PROCESO => 'M');
                   ELSE
                     IT.PAS_CRI.PR_CRC_GEN_CLASIF(P_TIP_PROCESO => 'M');
                     IT.PAS_CRI.PR_CRC_GEN_CLASIF(P_TIP_PROCESO => 'D');
                   END IF;
                ELSE
                  EXECUTE IMMEDIATE 'BEGIN ' || v_procesos(i).nombre || '; END;';
                END IF; 
              
                UPDATE GE_LOG_PROCESOS
                SET HOR_FIN = TO_CHAR(SYSDATE,'HH24:MI:SS'),
                    OBSERVACION = 'Fin del proceso con éxito.'
                WHERE ROWID = v_rowid_log;

            EXCEPTION
                WHEN OTHERS THEN
                    v_error := 'S';
                    v_error_msg := 'Error en el procedimiento: ' || SQLERRM;
                    UPDATE GE_LOG_PROCESOS
                    SET HOR_FIN = TO_CHAR(SYSDATE,'HH24:MI:SS'),
                        OBSERVACION = v_error_msg
                    WHERE ROWID = v_rowid_log;
            END;

        ELSE
            PRG_ACT_LOG_PROCESOS_ROWID('PRG_EJE_CRC_MENSUAL', v_procesos(i).nombre,
                TRUNC(SYSDATE), TO_CHAR(SYSDATE,'HH24:MI:SS'), TO_CHAR(SYSDATE,'HH24:MI:SS'),
                'El proceso tiene tablas con datos para la fecha ' || TO_CHAR(v_fec_ult_dia_mes_habil, 'DD-MM-YYYY') || '. No se ejecutará.',
                v_rowid_log);
        END IF;

      COMMIT;
     END LOOP;
   

  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20099, 'Error en el procedimiento: ' || SQLERRM);
  END;
/
