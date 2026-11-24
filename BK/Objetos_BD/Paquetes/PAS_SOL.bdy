create or replace PACKAGE BODY IT.PAS_SOL AS
G_SUB_TOT_GS        NUMBER := 0;
G_SUB_TOT_USD_GS    NUMBER := 0;
G_TOT_USD_GS        NUMBER := 0;
G_TOT_GS            NUMBER := 0;
    -- ===================================================================
    -- FU_GENERAR_UUID: Genera identificador Ãºnico para ejecuciones
    -- ===================================================================
    FUNCTION FU_GENERAR_UUID RETURN VARCHAR2 IS
    BEGIN
        RETURN LOWER(
            SUBSTR(SYS_GUID(), 1, 8) || '-' ||
            SUBSTR(SYS_GUID(), 9, 4) || '-' ||
            SUBSTR(SYS_GUID(), 13, 4) || '-' ||
            SUBSTR(SYS_GUID(), 17, 4) || '-' ||
            SUBSTR(SYS_GUID(), 21, 12)
        );
    END FU_GENERAR_UUID;

    -- ===================================================================
    -- PR_REGISTRAR_LOG: Registra eventos en la tabla de logs
    -- ===================================================================
    PROCEDURE PR_REGISTRAR_LOG (
        p_id_ejecucion      IN VARCHAR2,
        p_tipo_log          IN VARCHAR2,
        p_mensaje           IN VARCHAR2,
        p_detalle_error     IN CLOB DEFAULT NULL,
        p_cantidad_registros IN NUMBER DEFAULT NULL,
        p_tiempo_ms         IN NUMBER DEFAULT NULL
    ) IS PRAGMA AUTONOMOUS_TRANSACTION ;
        v_id_ejecucion_log  VARCHAR2(36);
    BEGIN
        v_id_ejecucion_log := NVL(TRIM(p_id_ejecucion), FU_GENERAR_UUID());

        INSERT INTO IT.SB_SOL_LOGS (
            id_ejecucion,
            tipo_log,
            mensaje,
            detalle_error,
            cantidad_registros,
            tiempo_ejecucion_ms
        ) VALUES (
            v_id_ejecucion_log,
            UPPER(p_tipo_log),
            p_mensaje,
            p_detalle_error,
            p_cantidad_registros,
            p_tiempo_ms
        );
        commit;
       

    EXCEPTION
        WHEN OTHERS THEN
            raise;
    END PR_REGISTRAR_LOG;

    -- ===================================================================
    -- PR_ACTUALIZAR_EJECUCION: Actualiza estado de ejecución
    -- ===================================================================
    PROCEDURE PR_ACTUALIZAR_EJECUCION (
        p_id_ejecucion      IN VARCHAR2,
        p_estado            IN VARCHAR2,
        p_registros_procesados IN NUMBER DEFAULT NULL,
        p_registros_error   IN NUMBER DEFAULT NULL,
        p_tiempo_ms         IN NUMBER DEFAULT NULL
    ) IS
    BEGIN
        UPDATE IT.SB_SOL_EJECUCIONES
        SET
            estado = UPPER(p_estado),
            registros_procesados = NVL(p_registros_procesados, registros_procesados),
            registros_error = NVL(p_registros_error, registros_error),
            tiempo_ejecucion_ms = NVL(p_tiempo_ms, tiempo_ejecucion_ms),
            fecha_fin = CASE WHEN UPPER(p_estado) IN ('COMPLETADO', 'ERROR') 
                            THEN SYSTIMESTAMP 
                            ELSE fecha_fin 
                       END
        WHERE id_ejecucion = p_id_ejecucion;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR actualizando ejecución: ' || SQLERRM);
    END PR_ACTUALIZAR_EJECUCION;

    -- ===================================================================
    -- FU_VALIDAR_PARAMETROS: Valida parámetros de entrada
    -- ===================================================================
    FUNCTION FU_VALIDAR_PARAMETROS (
        p_ano               IN NUMBER,
        p_mes               IN NUMBER,
        p_fuente_datos      IN VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        -- Validar aÃ±o
        IF p_ano < 2000 OR p_ano > EXTRACT(YEAR FROM SYSDATE) + 1 THEN
            RETURN FALSE;
        END IF;

        -- Validar mes
        IF p_mes < 1 OR p_mes > 12 THEN
            RETURN FALSE;
        END IF;

        -- Validar fuente de datos
        IF TRIM(p_fuente_datos) IS NULL THEN
            RETURN FALSE;
        END IF;

        RETURN TRUE;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END FU_VALIDAR_PARAMETROS;
    -- ==============================================================
    -- FU_GET_TOT_GARANTIAS: Obtener total por los anexo de garantias 
    -- ==============================================================
    function FU_GET_TOT_GARANTIAS (p_anexo in varchar2)return number
    is 
    v_tot number;
    begin
        select round(MONTO_GS / 1000000)
          into v_tot
           from  IT.SB_ANX_RES_TOTALES a 
          where upper(FUENTE_DATOS) = upper(p_anexo) 
          and cod_moneda = 'TOT'
          and id_anexo = (select max(id_anexo) from IT.SB_ANX_RES_TOTALES b where b.FUENTE_DATOS = a.FUENTE_DATOS);

          return v_tot;
    exception 
        when others then
         return 0;
    end;
    -- ===================================================================
    -- PR_PROCESAR_SOLVENCIA: Procedimiento principal
    -- ===================================================================
    PROCEDURE PR_PROCESAR_SOLVENCIA (
        p_id_ejecucion      IN VARCHAR2,
        P_fecha             IN DATE,
        p_fuente_datos      IN VARCHAR2,
        p_resultado         OUT NUMBER
    ) IS
        v_id_ejecucion      VARCHAR2(36);
        v_timestamp_inicio  TIMESTAMP;
        v_timestamp_fin     TIMESTAMP;
        v_tiempo_ms         NUMBER;
        v_contador          NUMBER := 0;
        v_contador_error    NUMBER := 0;
        v_sql_query         VARCHAR2(4000);
        v_id_resultado      NUMBER;
        v_ano               number := EXTRACT(YEAR from p_fecha);
        v_mes               number := EXTRACT(MONTH from p_fecha);
        v_total_activo      number := 0;
        v_cat4_residual     number := 0;
        v_viv_deduccion     number := 0;
        v_garantias         number := 0;
    BEGIN
        -- Inicializar salidas
        p_resultado := 0;
        v_timestamp_inicio := SYSTIMESTAMP;

        PR_REGISTRAR_LOG(P_id_ejecucion, 'INFO', 
            'Iniciando proceso de solvencia - fECHA: ' || SYSDATE || ', Fuente: ' || p_fuente_datos);

        -- Preparar id_resultado para todos los inserts del proceso
        v_id_resultado := IT.S_ID_RESULTADO.NEXTVAL;

          -- Total activo = suma rubros '10%' de cb_sal_consolidados_his
          SELECT round(SUM(nvl(sal_mon_loc_ant,0) + nvl(deb_mon_local,0)- nvl(cre_mon_local,0)) / 1000000)
             into v_total_activo
             FROM cb_sal_consolidados_his
            WHERE cod_rubro LIKE '10%'
              AND ano = v_ano AND mes = v_mes ;

      -- Bug Cat II: Pre-computar prestamos vivienda (mod 970/971) a deducir de rubro personal Cat II
        BEGIN
            SELECT ROUND(SUM(NVL(g.tot_deu_real,0)+NVL(g.dev_no_cobrado,0))/1000000)
              INTO v_viv_deduccion
              FROM ge_cla_operaciones_his g
             WHERE g.fecha = p_fecha
               AND g.cod_rub_economico IN (970000, 970001, 970002)
               AND g.cod_modalidad IN (970, 971);
        EXCEPTION WHEN OTHERS THEN v_viv_deduccion := 0; END;

        -- OBETENER RESUTADO GARANTIA HIPOTECAS
            select round(sum(total) / 1000000) total --411614 - 212969
            into v_garantias
            from (
            SELECT ROUND(NVL(t.tot_deu_real, 0), 0) total,
                            t.NRO_CUENTA
            FROM (
                -- Pr_Cta_Garantias: préstamos, créditos personales
                SELECT cg.NRO_CUENTA, cg.COD_GARANTIA, max(FEC_INICIO)FEC_INICIO
                FROM Pr_Cta_Garantias cg JOIN pr_garantias pg  ON  pg.NRO_GARANTIA = cg.NRO_GARANTIA
                WHERE cg.COD_GARANTIA IN (3, 8, 13)
                AND pg.ESTADO IN ('C')      
                GROUP BY cg.NRO_CUENTA, cg.COD_GARANTIA
            ) s
                 -- Confirmado + Vigente
            JOIN ge_cla_operaciones_his t
                ON  t.NRO_CUENTA     = s.NRO_CUENTA
                AND t.FECHA          = p_fecha    
            WHERE t.COD_MODALIDAD NOT IN (970, 971, 154)
            AND t.cod_rub_economico not IN (970000, 970001, 970002) );


        -- Ejecutar query y guardar resultados
        BEGIN
            INSERT INTO IT.SB_SOL_RESULTADOS 
            (
                id_resultado,
                fecha,
                clasificacion,
                cod_rubro,
                categoria,
                --subcategoria,
                descripcion,
                total_balance,
                fuente_datos,
                ORDEN
            )
            SELECT
                id_resultado,
                fecha,
                clasificacion,
                cod_rubro,
                categoria,
                initcap(descripcion)descripcion,
                ROUND(agg_balance   - CASE WHEN cod_rubro = '110201090300000' and categoria = 2 then 
                                            ROUND(
                                                SUM(CASE WHEN cod_rubro = '110201090300000' AND categoria = 4
                                                         THEN agg_balance ELSE 0 END) OVER () 
                                            ) 
                                        when initcap(descripcion) = 'Aquellos Que El Bcp Determine' and categoria = 2 
                                            then v_viv_deduccion 
                                        else 0 end 
                    ) AS total_balance,
                fuente_datos,
                ORDEN

            FROM (
                    SELECT
                        v_id_resultado id_resultado,
                        b.fecha,
                        b.clasificacion,
                        b.cod_rubro,
                        b.categoria,
                        b.descripcion,
                        case  
                            when initcap(b.descripcion) = 'Créditos Colaterizados En Dinero Efectivo' then 
                                FU_GET_TOT_GARANTIAS('Cash Colateral')
                            when initcap(b.descripcion) = 'Préstamos Garantizados Por Hipotecas, Prendas Y Warants' then
                                0 
                            when initcap(b.descripcion) = 'Préstamos Garantizados Por Hipotecas' then 
                                 v_garantias --FU_GET_TOT_GARANTIAS('Inf. Hipotecas')
                            when initcap(b.descripcion) = 'Préstamos Garantizados Por Prendas' then 
                                FU_GET_TOT_GARANTIAS('Inf. Prendas')
                            when initcap(b.descripcion) = 'Préstamos Garantizados Por Warrants' then 
                                0
                            when initcap(b.descripcion) = 'Préstamos Garantizados Por Fogamu' then 
                                FU_GET_TOT_GARANTIAS('Inf. FOGAMU')
                            when initcap(b.descripcion) = 'Préstamos Garantizados Por Fogapy' then  
                                FU_GET_TOT_GARANTIAS('Inf. FOGAPY') 
                            when initcap(b.descripcion) = 'Aquellos Que El Bcp Determine' and b.categoria = 4 then 
                                0
                        else
                        round(nvl(sum(b.balance) , 0)/ 1000000) end as agg_balance,
                        fuente_datos,
                        ORDEN
                    FROM (
                        SELECT p_fecha fecha, 
                               cfg.clasificacion,
                               cfg.categoria AS categoria,
                               cfg.descripcion AS descripcion,
                               cfg.cod_rubro_rtp cod_rubro,
                               nvl(C.sal_mon_loc_ant, 0) + nvl(C.deb_mon_local, 0) - nvl(C.cre_mon_local, 0)  AS balance,
                               'Historico' fuente_datos,
                               cfg.orden
                        FROM cb_sal_consolidados_his c RIGHT JOIN IT.SB_SOL_CONFIGURACIONES cfg 
                                ON (c.cod_rubro = cfg.cod_rubro AND c.ano = extract(year FROM p_fecha) AND c.mes = extract(month FROM p_fecha))
                        where UPPER(p_fuente_datos) = 'H'
                        UNION ALL
                        SELECT c.fecha,
                               cfg.clasificacion,
                               cfg.categoria AS categoria,
                               cfg.descripcion AS descripcion,
                               cfg.cod_rubro_rtp cod_rubro,
                               nvl(C.sal_mon_loc_ant, 0) + nvl(C.deb_mon_local, 0) - nvl(C.cre_mon_local, 0) AS balance,
                               'Provisorio' fuente_datos,
                               cfg.orden
                        FROM cb_sal_consolidados_dia c RIGHT JOIN IT.SB_SOL_CONFIGURACIONES cfg ON (c.cod_rubro = cfg.cod_rubro AND c.fecha = p_fecha)
                        WHERE UPPER(p_fuente_datos) = 'P'
                    ) b
                    GROUP BY b.fecha, b.clasificacion, b.cod_rubro, b.orden, b.categoria, b.descripcion, b.fuente_datos
                )
            ORDER BY ORDEN ASC;

            v_contador := SQL%ROWCOUNT;

            COMMIT;


            select v_total_activo - sum(total)
              into v_cat4_residual
              from (
            SELECT SUM(case when UPPER(descripcion) = 'AQUELLOS QUE EL BCP DETERMINE' and categoria = 4 then 0 else total_balance end ) total
              FROM it.SB_SOL_RESULTADOS WHERE id_resultado = v_id_resultado
              union all 
              select round(nvl(sum(nvl(TOT_DEU_REAL, 0) - CASE WHEN COD_MONEDA != 'GS' THEN NVL(TOT_PREVISION, 0) ELSE 0 END), 0 )/ 1000000) as total
              from ge_cla_operaciones_his
                where  1= 1
                and fecha = p_fecha 
                and COD_RUB_ECONOMICO in (970002, 970000, 970001)
                AND NRO_CUENTA NOT IN (
                                        SELECT cg.NRO_CUENTA
                                          FROM Pr_Cta_Garantias cg, pr_garantias pg
                                         WHERE cg.NRO_GARANTIA = pg.NRO_GARANTIA
                                           AND pg.ESTADO = 'C'
                                           AND cg.cod_garantia = 5
                                        )
                );

              update it.SB_SOL_RESULTADOS set total_balance = v_cat4_residual
               where id_resultado = v_id_resultado
                 and UPPER(descripcion) = 'AQUELLOS QUE EL BCP DETERMINE' 
                 and categoria = 4;
            commit;

            insert into IT.SB_SOL_RESULTADOS_TOT(id_resultado, fecha, categoria, total, fuente_datos)
            select id_resultado,
                   fecha,
                   categoria,
                   total,
                   fuente_datos
            from( 
                    select id_resultado, 
                            fecha, 
                            categoria, 
                            round(SUM(total_balance)) total,
                            fuente_datos
                    from IT.SB_SOL_RESULTADOS
                    where id_resultado = v_id_resultado
                    group by fecha,categoria,id_resultado , fuente_datos)
            union all 
            select v_id_resultado, 
                   fecha, 
                   '22', 
                   round(nvl(sum(nvl(TOT_DEU_REAL, 0) - CASE WHEN COD_MONEDA != 'GS' THEN NVL(TOT_PREVISION, 0) ELSE 0 END), 0 )/ 1000000) as total ,
                   'Historico' fuente_datos
            from ge_cla_operaciones_his
            where  1= 1
            and fecha = p_fecha 
            and COD_RUB_ECONOMICO in (970002, 970000, 970001)
            AND NRO_CUENTA NOT IN (
                                        SELECT cg.NRO_CUENTA
                                          FROM Pr_Cta_Garantias cg, pr_garantias pg
                                         WHERE cg.NRO_GARANTIA = pg.NRO_GARANTIA
                                           AND pg.ESTADO = 'C'
                                           AND cg.cod_garantia = 5
                                      )
            group by fecha;

            commit;
            p_resultado := 1;
            
            PR_REGISTRAR_LOG(v_id_ejecucion, 'SUCCESS', 
                'Proceso completado exitosamente. ');

            PR_ACTUALIZAR_EJECUCION(v_id_ejecucion, 'COMPLETADO', v_contador, 0, v_tiempo_ms);

            

        EXCEPTION
            WHEN OTHERS THEN
                v_contador_error := v_contador_error + 1;

                PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 
                    'Error durante la ejecución del query',
                    'Error: ' || SQLERRM || ' - Codigo: ' || SQLCODE);

                ROLLBACK;
                p_resultado := -1;

        END;

    EXCEPTION
        WHEN OTHERS THEN
            PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 
                'Error critico en procedimiento principal',
                'Error: ' || SQLERRM || ' - Codigo: ' || SQLCODE);

            PR_ACTUALIZAR_EJECUCION(p_id_ejecucion, 'ERROR', 0, 1);
            p_resultado := -1;

    END PR_PROCESAR_SOLVENCIA;
    -- ============================================================================
    -- FU_GET_TOT_CAT: Funcion para betener el total por categoria 
    -- =============================================================================
    Function FU_GET_TOT_CAT (p_categoria varchar2) return number
    is
    v_tot number;
    begin
        select total
          into v_tot
          from IT.SB_SOL_RESULTADOS_TOT a
          where id_resultado = (select max(id_resultado) from IT.SB_SOL_RESULTADOS_TOT b where a.categoria = b.categoria)
          and a.categoria = p_categoria;

        return v_tot;
    exception 
    when others then
        return 0;
    end;    
    -- ===================================================================
    -- PR_DESCARGAR_EXCEL: Genera archivo Excel con resultados (Pantilla de Solvencia)
    -- ===================================================================
    PROCEDURE PR_GEN_EXCEL_PLT_SOL (p_id_ejecucion varchar2, p_resultado out number)
    IS
        V_MAX_ID            NUMBER;
        V_COUNT             NUMBER := 0;
        v_blob              blob;
        V_CAT_1             NUMBER := 0;
        V_CAT_2             NUMBER := 0;
        V_CAT_2_VIVIENDA    NUMBER := 0;
        V_CAT_3             NUMBER := 0;
        V_CAT_4             NUMBER := 0;
        g_row               NUMBER := 0;
        g_col               NUMBER := 0;
        v_header            varchar2(4000);
        v_cod_rubro_ant     varchar2(60);
        CURSOR C_SOLVENCIA IS
            SELECT 
                fecha,
                clasificacion,
                case when cod_rubro = '510106510403001' and categoria = 'I' then null else cod_rubro end cod_rubro,
                categoria,
                subcategoria,
                descripcion,
                total_balance,
                fuente_datos,
                ORDEN,
                SUM(total_balance) over (partition by categoria) total_cat
            FROM IT.SB_SOL_RESULTADOS
            WHERE id_resultado = (SELECT MAX(id_resultado) FROM IT.SB_SOL_RESULTADOS)
            ORDER BY ORDEN ASC;
    BEGIN


        -- Generar archivo Excel
        PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 
            'Iniciando generacion de archivo Excel Pantilla de Solvencia');

        SELECT valor
          INTO v_header
          FROM it.SB_SOL_PARAMETROS
         WHERE nombre = 'HEADER_ARCHIVO';

        it.as_xlsx.clear_workbook;
        it.as_xlsx.new_sheet('Pantilla de Solvencia');
        it.as_xlsx.set_column_width(p_col => 1, p_width => 10);
        it.as_xlsx.set_column_width(p_col => 2, p_width => 20);
        it.as_xlsx.set_column_width(p_col => 3, p_width => 20);
        it.as_xlsx.set_column_width(p_col => 4, p_width => 70);
        it.as_xlsx.set_column_width(p_col => 5, p_width => 30);
        it.as_xlsx.set_row(
                    p_row    => 1,
                    p_height => 40
                );

        FOR R IN C_SOLVENCIA LOOP

            IF R.CATEGORIA = 1 THEN
                IF V_COUNT = 0 THEN
                    it.as_xlsx.cell(1,1,v_header||last_day(R.fecha), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 12
                                                                                    , p_bold => TRUE
                                                                                    )
                                                                                    , p_alignment => it.as_xlsx.get_alignment( p_wraptext => true ));
                       it.as_xlsx.mergecells(
                        p_tl_col => 1,  -- A
                        p_tl_row => 1,  -- 1
                        p_br_col => 5,  -- A
                        p_br_row => 6   -- 6
                      );
                    it.as_xlsx.cell(1,7,'PLANILLA COMPLEMENTARIA DE SOLVENCIA PATRIMONIAL', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 15
                                                                        , p_bold => TRUE
                                                                        )
                                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                    as_xlsx.mergecells( 1, 7, 5, 7);
                    it.as_xlsx.cell(1,8,'Articulo 56 de la Ley N° 861/96', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                                )
                                                                          , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
                    as_xlsx.mergecells( 1, 8, 5, 8);
                    it.as_xlsx.cell(1,9,'Montos de Activos segun Riesgos', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                                )
                                                                          , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
                    as_xlsx.mergecells( 1, 9, 5, 9);
                    it.as_xlsx.cell(1,10,'(detalle CATEGORIA III)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                                )
                                                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
                    as_xlsx.mergecells( 1, 10, 5, 10);

                    g_row := 12;
                    g_col := 1;

                    it.as_xlsx.cell(g_col, g_row, '1) CATEGORIA I (Activos sin Riesgos)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 11
                                                                    , p_bold => TRUE
                                                                    )
                                                                    , p_borderId => as_xlsx.get_border( '', 'thin', '', '' )
                                                );
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    as_xlsx.mergecells( 1, g_row, 4, g_row);
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, (FU_GET_TOT_CAT(R.CATEGORIA)), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                                    , p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := 1;
                    g_row := g_row+1;
                    V_COUNT := V_COUNT + 1;
                END IF;

            ELSIF R.CATEGORIA = 2 THEN
                IF V_COUNT = 1 THEN
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := 1;
                    g_row := g_row+1;
                    it.as_xlsx.cell(g_col, g_row, '2) CATEGORIA II (Activos de Muy Bajo Riesgo)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 11
                                                                    , p_bold => TRUE
                                                                    )
                                                                    , p_borderId => as_xlsx.get_border( '', 'thin', '', '' )
                                                );
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    as_xlsx.mergecells( 1, g_row, 4, g_row);
                    it.as_xlsx.cell(g_col, g_row, (FU_GET_TOT_CAT(R.CATEGORIA)), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 11
                                                                    , p_bold => TRUE
                                                                    )
                                                    , p_borderId => as_xlsx.get_border( '', 'thin', '', '' )
                                                    );
                    g_col := 1;
                    g_row := g_row+1;
                    V_COUNT := V_COUNT + 1;
                END IF;
           ELSIF R.CATEGORIA = 3 THEN
                IF V_COUNT = 2 THEN
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := 1;
                    g_row := g_row+1;
                    it.as_xlsx.cell(g_col, g_row, '3) CATEGORIA III (Activos de Bajo Riesgo)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 11
                                                                    , p_bold => TRUE
                                                                    )
                                                    , p_borderId => as_xlsx.get_border( '', 'thin', '', '' )
                                                );
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    as_xlsx.mergecells( 1, g_row, 4, g_row);
                    it.as_xlsx.cell(g_col, g_row, (FU_GET_TOT_CAT(R.CATEGORIA)), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    )
                                                                    , p_borderId => as_xlsx.get_border( '', 'thin', '', '' )
                                                        );
                    g_col := 1;
                    g_row := g_row+1;

                    V_COUNT := V_COUNT + 1;
                END IF;
            ELSIF R.CATEGORIA = 4 THEN
                IF V_COUNT = 3 THEN
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                    g_col := 1;
                    g_row := g_row+1;
                    it.as_xlsx.cell(g_col, g_row, '4) CATEGORIA IV (Activos de Riesgo Normal )', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    )
                                                            , p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := g_col + 1;
                    as_xlsx.mergecells( 1, g_row, 4, g_row);
                    it.as_xlsx.cell(g_col, g_row, (FU_GET_TOT_CAT(R.CATEGORIA)), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    )
                                                    , p_borderId => as_xlsx.get_border( '', 'thin', '', '' ));
                    g_col := 1;
                    g_row := g_row+1;
                    V_COUNT := V_COUNT + 1; 
                end if;
            END IF;         

            it.as_xlsx.cell(g_col, g_row, r.clasificacion ||case when r.clasificacion is not null then ')' else '' end
                                                , p_borderId => as_xlsx.get_border( '', '', 'thin', '' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col, g_row, case when v_cod_rubro_ant = substr(R.cod_rubro,1,5) then '' else substr(R.cod_rubro,1,5) end );
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col, g_row, substr(R.cod_rubro,6,6) );
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col, g_row, R.descripcion);
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col, g_row, R.total_balance, p_borderId => as_xlsx.get_border( '', '', '', 'thin' ));

            if upper(R.descripcion) = 'AQUELLOS QUE EL BCP DETERMINE' and r.categoria = 1 then 
                g_col := 1;
                g_row := g_row +1;
                it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
                g_col := 1;
                g_row := g_row+1;
                it.as_xlsx.cell(g_col, g_row, '2) CATEGORIA II (Activos de Muy Bajo Riesgo)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 11
                                                                    , p_bold => TRUE
                                                                    )
                                                );
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '');
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '');
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '');
                as_xlsx.mergecells( 1, g_row, 4, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, (FU_GET_TOT_CAT(22)), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 11
                                                                    , p_bold => TRUE
                                                                    ));
                g_col := 1;
                g_row := g_row+1;
                it.as_xlsx.cell(g_col, g_row, 'e)', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', '' ) , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', 'thin', '', '' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', 'thin', '', '' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, 'Aquellos que el BCP determine - Vivienda', p_borderId => as_xlsx.get_border( 'thin', 'thin', '', '' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, (FU_GET_TOT_CAT(22)), p_borderId => as_xlsx.get_border( 'thin', 'thin', '', 'thin' ));
            elsif upper(R.descripcion) = 'AQUELLOS QUE EL BCP DETERMINE' and r.categoria = 4 then 
                g_col := 1;
                g_row := g_row+1;
                it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( '', '', 'thin', '' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '' );
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, '' );
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, 'Menos:');
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col, g_row, 0, p_borderId => as_xlsx.get_border( '', '', '', 'thin' ));
            end if;

            v_cod_rubro_ant := substr(R.cod_rubro,1,5);
            g_col := 1;
            g_row := g_row+1;

        END LOOP;
        it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col, g_row, '', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        g_col := 1;
        g_row := g_row +2;

        it.as_xlsx.cell(g_col,g_row,'Este formulario tiene carácter de declaración jurada');
        g_row := g_row +1;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'Fecha '||to_char(sysdate, 'DD "de" Month "de" YYYY'));

        v_blob := it.as_xlsx.finish;
        INSERT INTO IT.SB_SOL_ARCHIVOS ( nombre_archivo, contenido_blob, ID_EJECUCION ) VALUES ('Plantilla de Solvencia', v_blob, p_id_ejecucion );
        COMMIT;
        p_resultado := 1;
    Exception
    when others then
        p_resultado := -1;

    END;

    -- ===================================================================
    -- PR_LIMPIAR_DATOS_ANTIGUOS: Elimina registros antiguos
    -- ===================================================================
    PROCEDURE PR_LIMPIAR_DATOS_ANTIGUOS (
        p_meses_atras       IN NUMBER DEFAULT 12,
        p_registros_eliminados OUT NUMBER
    ) IS
        v_fecha_limite      DATE;
    BEGIN
        v_fecha_limite := ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -p_meses_atras);

        DELETE FROM IT.SB_SOL_RESULTADOS
        WHERE TRUNC(fecha_creacion) < v_fecha_limite;

        p_registros_eliminados := SQL%ROWCOUNT;

        DELETE FROM IT.SB_SOL_LOGS
        WHERE TRUNC(fecha_log) < v_fecha_limite;

        DELETE FROM IT.SB_SOL_AUDITORIA
        WHERE TRUNC(fecha_cambio) < v_fecha_limite;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Se eliminaron ' || p_registros_eliminados || 
                            ' registros anteriores a ' || v_fecha_limite);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('ERROR limpiando datos: ' || SQLERRM);
    END PR_LIMPIAR_DATOS_ANTIGUOS;

    -- ===================================================================
    -- FU_OBTENER_RESUMEN_EJECUCIONES: Genera reporte de ejecuciones
    -- ===================================================================
    FUNCTION FU_OBTENER_RESUMEN_EJECUCIONES (
        p_dias              IN NUMBER DEFAULT 7
    ) RETURN VARCHAR2 IS
        v_resumen           VARCHAR2(4000);
    BEGIN
        SELECT
            CHR(10) ||
            'RESUMEN DE EJECUCIONES (Ãšltimos ' || p_dias || ' dÃ­as)' || CHR(10) ||
            '======================================================' || CHR(10) ||
            'Total ejecuciones: ' || COUNT(*) || CHR(10) ||
            'Completadas: ' || SUM(CASE WHEN estado = 'COMPLETADO' THEN 1 ELSE 0 END) || CHR(10) ||
            'Con error: ' || SUM(CASE WHEN estado = 'ERROR' THEN 1 ELSE 0 END) || CHR(10) ||
            'Tiempo promedio (ms): ' || 
                ROUND(AVG(tiempo_ejecucion_ms), 2) || CHR(10) ||
            'Registros totales procesados: ' || 
                SUM(registros_procesados)
        INTO v_resumen
        FROM IT.SB_SOL_EJECUCIONES
        WHERE fecha_inicio >= SYSDATE - p_dias;

        RETURN v_resumen;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'ERROR obteniendo resumen: ' || SQLERRM;
    END FU_OBTENER_RESUMEN_EJECUCIONES;
    -- ===================================================================
    -- PR_SET_TOTALES: Setea totales para los anexos al momento de generar excel 
    -- ===================================================================
    PROCEDURE PR_SET_TOTALES (P_ID_ANEXO NUMBER, P_ANEXO VARCHAR2)
    IS
    CURSOR R_TOTALES IS 
    SELECT COD_MONEDA, MONTO_GS, MONTO_USD 
        FROM IT.SB_ANX_RES_TOTALES 
        where fuente_datos = P_ANEXO
        and id_anexo = P_ID_ANEXO;
    BEGIN
    G_SUB_TOT_GS := null;
    G_SUB_TOT_USD_GS := null;
    G_TOT_USD_GS := null;
    G_TOT_GS := null;

    FOR i in R_TOTALES loop
        if i.COD_MONEDA = 'GS' then
            G_SUB_TOT_GS := I.MONTO_GS;
        elsif i.COD_MONEDA = 'USD' then 
            G_SUB_TOT_USD_GS := I.MONTO_GS;
            G_TOT_USD_GS := I.MONTO_USD;
        elsif i.COD_MONEDA = 'TOT' then 
            G_TOT_GS := I.MONTO_GS;
        end if;
    end loop;
    END;

    PROCEDURE PR_PROCESAR_ANEXOS (
        p_fecha             IN DATE,
        p_id_ejecucion      OUT VARCHAR2,
        p_resultado         OUT NUMBER
    ) IS
        v_id_ejecucion      VARCHAR2(36);
        v_id_resultado      NUMBER;
        v_contador          NUMBER := 0;
        v_cotizacion        NUMBER;
        v_vivienda          NUMBER := 0;    
    BEGIN
        -- Este procedimiento se puede implementar de manera similar a PR_PROCESAR_SOLVENCIA
        -- pero con lógica especÃ­fica para Creditos colateralizados en dinero efectivo.
        -- Por simplicidad, aquÃ­ solo se registra un log indicando que se ha llamado al procedimiento.

        v_id_ejecucion := FU_GENERAR_UUID();
        p_id_ejecucion := v_id_ejecucion;
        v_id_resultado := IT.S_ID_ANX_RES.NEXTVAL;

        PR_REGISTRAR_LOG(v_id_ejecucion, 'INFO', 
            'Iniciando procesamiento de garantias - Fecha: ' || 
            TO_CHAR(p_fecha, 'DD/MM/YYYY') ) ;

        --obtener cotizacion
          select val_conversion
            into v_cotizacion
            from ge_cotizaciones
            where fecha = p_fecha
            and cod_moneda = 'USD';

        -- AquÃ­ se implementarÃ­a la lógica especÃ­fica para este caso
        insert into IT.SB_ANX_RESULTADOS (
            id_anexo,
            fecha_anexo,
            nro_operacion,
            nombre_cliente,                      
            cod_moneda,
            total_balance,
            fuente_datos,
            MONTO_USD
        )select v_id_resultado, 
                fecha, 
                nro_cuenta,
                NOM_COMPLETO,
                COD_MONEDA,
                total,
                fuente_datos,
                round((total / v_cotizacion))  MONTO
         from (       
        select  t.fecha,
                t.nro_cuenta, 
                c.NOM_COMPLETO, 
                T.COD_MONEDA, 
                CASE
                    WHEN (s.cod_garantia IN (3, 8, 13)
                         AND EXISTS (SELECT 1
                                     FROM pr_cta_garantias g46
                                     WHERE g46.nro_cuenta = t.nro_cuenta
                                       AND g46.cod_garantia = 46 ))
                        or  (s.cod_garantia = 46 
                             AND EXISTS (SELECT 1
                                         FROM pr_cta_garantias g46
                                         WHERE g46.nro_cuenta = t.nro_cuenta
                                           AND g46.cod_garantia in (3, 8, 13) ))
                     THEN 
                        case when s.FEC_INICIO > '31/05/2026' then 
                             ROUND((NVL(t.tot_deu_real, 0) - NVL(DEV_NO_COBRADO, 0) ) * 0.8
                                + case when s.cod_garantia != 46 then NVL(DEV_NO_COBRADO, 0) else 0
                                end, 0) 
                           when s.FEC_INICIO <= '31/05/2026' then
                                ROUND((NVL(t.tot_deu_real, 0) - NVL(DEV_NO_COBRADO, 0) ) * 0.5
                                + case when s.cod_garantia != 46 then NVL(DEV_NO_COBRADO, 0) else 0
                                            end, 0) end 
                ELSE ROUND(NVL(t.tot_deu_real, 0), 0)
                END  total, 
                case when s.cod_garantia = 5 then 'Cash Colateral'
                     when s.cod_garantia = 4 then 'Inf. Prendas'
                     when s.cod_garantia in (3,8,13) then 'Inf. Hipotecas'
                     when s.cod_garantia in (45, 32, 33, 34) then 'Inf. FOGAMU'
                     when s.cod_garantia = 46 then 'Inf. FOGAVI'
                     when s.cod_garantia in (39, 40, 41) then 'Inf. FOGAPY'
                     end AS fuente_datos
          from ge_cla_operaciones_his t join ba_personas c on (t.cod_persona = c.cod_persona)
          JOIN (
                     SELECT cg.NRO_CUENTA, cg.COD_GARANTIA, MAX(pg.FEC_INICIO) FEC_INICIO
                    FROM cc_cta_garantias cg
                    JOIN pr_garantias pg ON cg.NRO_GARANTIA = pg.NRO_GARANTIA
                    WHERE pg.ESTADO = 'C'
                      AND cg.COD_GARANTIA IN (5) 
                    GROUP BY cg.NRO_CUENTA, cg.COD_GARANTIA
                union all
                -- Pr_Cta_Garantias para Prendas, FOGAVI, FOGAPY, FOGAMU (ya exactos)
                SELECT cg.NRO_CUENTA, cg.COD_GARANTIA, MAX(pg.FEC_INICIO) FEC_INICIO
                FROM Pr_Cta_Garantias cg
                JOIN pr_garantias pg ON cg.NRO_GARANTIA = pg.NRO_GARANTIA
                WHERE pg.ESTADO = 'C'
                  AND cg.COD_GARANTIA IN (4, 32, 33, 34, 39, 40, 41, 45, 46, 3, 5, 8, 13 ) -- se volvieron a agregar 3, 5, 8, 13
                GROUP BY cg.NRO_CUENTA, cg.COD_GARANTIA
            ) s ON (t.nro_cuenta=s.nro_cuenta)
         Where 1= 1
           and t.fecha = p_fecha
           --and s.cod_garantia  in (4, 5, 3, 8, 13, 45, 32, 33, 34, 46, 39, 40, 41)
           and t.cod_modalidad not in(970,971,154)
         order by s.cod_garantia);

        v_contador := SQL%ROWCOUNT;
        COMMIT;

        insert into IT.SB_ANX_RES_TOTALES
            (id_anexo,
             fecha_anexo,
             cod_moneda,
             MONTO_GS,
             MONTO_USD,
             fuente_datos) 
        SELECT
            ID_ANEXO,
            FECHA_ANEXO,
            NVL(COD_MONEDA, 'TOT') COD_MONEDA,
            SUM(TOTAL_BALANCE) AS TOTAL_BALANCE,
            SUM(MONTO_USD)     AS MONTO_USD,
            FUENTE_DATOS
        FROM IT.SB_ANX_RESULTADOS
        WHERE ID_ANEXO = v_id_resultado
        GROUP BY GROUPING SETS (
            (ID_ANEXO, FECHA_ANEXO, COD_MONEDA, FUENTE_DATOS), -- parciales
            (ID_ANEXO, FECHA_ANEXO, FUENTE_DATOS)              -- total general
        )
        ORDER BY
            CASE WHEN COD_MONEDA IS NULL THEN 1 ELSE 0 END, COD_MONEDA;

        commit;

        PR_REGISTRAR_LOG(v_id_ejecucion, 'SUCCESS', 
            'Procesamiento de Anexos completado exitosamente. ' ||
            'Registros insertados: ' || v_contador);

        p_resultado := 1;

    EXCEPTION
        WHEN OTHERS THEN
            PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 
                'Error en procesamiento de Anexos',
                'Error: ' || SQLERRM || ' - Codigo: ' || SQLCODE);
            ROLLBACK;
            p_resultado := -1;
    end;
    -- ===================================================================
    -- PR_PROCESAR_ANEXO_SOLVENCIA: Insert de data anexo solvenia (Banco Pais)
    -- ===================================================================
    PROCEDURE PR_PROCESAR_ANEXO_SOLVENCIA (
        p_fecha             IN DATE,
        p_fuente_datos      IN VARCHAR2,
        p_id_ejecucion      IN VARCHAR2,
        p_resultado         OUT NUMBER
    ) IS
        v_id_ejecucion      VARCHAR2(36);
        v_id_resultado      NUMBER;
        v_ano               number := EXTRACT(YEAR from p_fecha);
        v_mes               number := EXTRACT(MONTH from p_fecha);
        v_contador_error    NUMBER := 0;
    BEGIN


        -- Este procedimiento se puede implementar de manera similar a PR_PROCESAR_SOLVENCIA
        -- pero con lógica especÃ­fica para Creditos colateralizados en dinero efectivo.
        -- Por simplicidad, aquÃ­ solo se registra un log indicando que se ha llamado al procedimiento.
        v_id_resultado := IT.S_ID_ANX_SOL.NEXTVAL;

        PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 
            'Procedimiento especifico para Creditos colateralizados en dinero efectivo - Fecha: ' || 
            TO_CHAR(p_fecha, 'DD/MM/YYYY') || ', Fuente: ' || p_fuente_datos);

        -- AquÃ­ se implementarÃ­a la lógica especÃ­fica para este caso
        INSERT INTO it.SB_ANX_SOL_RESULTADOS (
            id_anexo,
            fecha,
            rubro,
            descripcion,
            cod_moneda,
            total_balance, 
            seccion,
            fuente_datos
        ) SELECT v_id_resultado,
                 p_fecha,  
                 rubro, 
                 descripcion, 
                 cod_moneda,
                 SUM(sal_mon_local) sal_mon_local, 
                 seccion,
                 fuente_datos
        FROM (
            SELECT   
                 case seccion 
                    when 'Bancos Oficiales del Pais' then '109102' 
                    when 'Bancos del Pais' then '109104'
                    when 'Colocaciones Bancos Privados del Pais' then '131004'
                    when 'Call Money Concedidos' then '391004'
                    end  rubro, 
                 R.descripcion descripcion,
                 'GS' cod_moneda,
                 nvl(SUM(nvl(C.sal_mon_loc_ant, 0) + nvl(C.deb_mon_local, 0) - nvl(C.cre_mon_local, 0)), 0) sal_mon_local,
                 seccion,
                 'HISTORICO' fuente_datos
             FROM cb_sal_consolidados_his C, it.cb_rubros_bco_pais R
            WHERE C.cod_rubro = R.rubro
              AND ano = v_ano
              AND mes = v_mes
              AND UPPER(TRIM(p_fuente_datos)) = 'H'
            GROUP BY rubro, R.descripcion, seccion
         UNION ALL
            SELECT   
                case seccion 
                    when 'Bancos Oficiales del Pais' then '109102' 
                    when 'Bancos del Pais' then '109104'
                    when 'Colocaciones Bancos Privados del Pais' then '131004'
                    when 'Call Money Concedidos' then '391004'
                    end rubro, 
                 R.descripcion descripcion,
                 'GS' cod_moneda,
                 nvl(SUM(nvl(C.sal_mon_loc_ant, 0) + nvl(C.deb_mon_local, 0) - nvl(C.cre_mon_local, 0)), 0) sal_mon_local,
                 seccion,
                 'PROVISORIO' fuente_datos
             FROM cb_sal_consolidados_dia C, it.cb_rubros_bco_pais R
            WHERE C.cod_rubro = R.rubro
              AND fecha = p_fecha
              AND UPPER(TRIM(p_fuente_datos)) = 'P'
            GROUP BY rubro, R.descripcion, seccion
            union all --- invetario ( colocaciones banco privados)
            select case when substr(cod_rubro, 6, 5) = '13104' then '131004' 
                        when substr(cod_rubro, 6, 5) = '13102' then '131002'
                        end rubro, 
                 NOMBRE descripcion,
                 'GS' cod_moneda,
                 case when si.cod_moneda = 'USD' then (g.val_conversion * SAL_ACTUAL) else SAL_ACTUAL end sal_mon_local,
                 case when substr(si.cod_rubro, 6, 5) = '13102' then 'Bancos Oficiales del Pais' 
                    else 'Colocaciones Bancos Privados del Pais' end seccion,
                 'HISTORICO' fuente_datos
            from it.CB_SOLVENCIA_INV si, ge_cotizaciones g
            where si.fecha = p_fecha
             and g.fecha = si.fecha
             and g.cod_moneda = 'USD'
             and substr(si.cod_rubro, 6, 5) in ('13104', '13102')
          --  where TIP_DEUDOR in ( 'BANCOS PRIVADOS DEL PAIS', 'EMPRESAS FINANCIERAS DEL PAIS')
            --GROUP by nombre
        )
         GROUP BY rubro, descripcion, seccion, cod_moneda, fuente_datos;

        v_contador_error := SQL%ROWCOUNT;
        COMMIT;

        PR_REGISTRAR_LOG(v_id_ejecucion, 'SUCCESS', 
            'Procesamiento de Banco Pais completado exitosamente. ' ||
            'Registros insertados: ' || v_contador_error);

        p_resultado := 1;    
    EXCEPTION
        WHEN OTHERS THEN
            PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 
                'Error critico en procedimiento principal PR_PROCESAR_ANEXO_SOLVENCIA',
                'Error: ' || SQLERRM || ' - Codigo: ' || SQLCODE);

            PR_ACTUALIZAR_EJECUCION(v_id_ejecucion, 'ERROR', 0, 1);
            p_resultado := -1;
    end;
    -- ===================================================================
    -- FU_GET_TOTAL_COD_RUBRO : Traer el total del rubro completo  
    -- ===================================================================
    FUNCTION FU_GET_TOTAL_COD_RUBRO (P_COD_RUBRO NUMBER) RETURN NUMBER
    AS
    V_TOTAL NUMBER := 0;
    BEGIN
        SELECT SUM(total_balance)
         INTO V_TOTAL
         FROM IT.SB_ANX_SOL_RESULTADOS a
        WHERE id_anexo in (SELECT MAX(id_anexo) 
                             FROM IT.SB_ANX_SOL_RESULTADOS b)
          AND RUBRO = P_COD_RUBRO;

          RETURN V_TOTAL;
    EXCEPTION
        WHEN OTHERS THEN
         RETURN 0;
    END FU_GET_TOTAL_COD_RUBRO;
    -- ===================================================================
    -- PR_ANEXOS_SOLVENCIA_GENERAR_EXCEL: Genera archivo excel del Anexo de solvencia (Banco Pais)
    -- ===================================================================  
    PROCEDURE PR_ANEXOS_SOLVENCIA_GENERAR_EXCEL (
        p_id_ejecucion      IN VARCHAR2
    ) IS 
        V_MAX_ID                NUMBER;
        v_blob                  blob;
        g_row                   NUMBER := 0;
        g_col                   NUMBER := 0;
        v_seccion               VARCHAR2(100);
        v_count                 NUMBER := 0;
        v_header                VARCHAR2(4000);
        v_rubro_ant             VARCHAR2(6);
        CURSOR C_ANEXOS IS
            SELECT 
                fecha,
                RUBRO, 
                DESCRIPCION,
                cod_moneda,
                total_balance,
                SECCION
            FROM IT.SB_ANX_SOL_RESULTADOS a
            WHERE id_anexo in (SELECT MAX(id_anexo) 
                                FROM IT.SB_ANX_SOL_RESULTADOS b)
            ORDER BY /*case 
                    SECCION 
                        when 'Bancos Oficiales del Pais' then 1
                        when 'Bancos del Pais' then 2
                        when 'Colocaciones Bancos Privados del Pais' then 3
                    end ASC ,*/ to_number(rubro) asc
                    ;
     BEGIN       
        PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 
            'Iniciando generacion de archivo Excel con anexos de solvencia');

                SELECT valor
                    INTO v_header
                    FROM it.SB_SOL_PARAMETROS
          WHERE nombre = 'HEADER_ARCHIVO';

        it.as_xlsx.clear_workbook;
        it.as_xlsx.new_sheet('Anexo Banco Pais');
        it.as_xlsx.set_column_width(p_col => 1, p_width => 30);
        it.as_xlsx.set_column_width(p_col => 2, p_width => 35);
        it.as_xlsx.set_column_width(p_col => 3, p_width => 30);
        it.as_xlsx.set_column_width(p_col => 4, p_width => 30);
        it.as_xlsx.set_column_width(p_col => 5, p_width => 30);
        it.as_xlsx.set_row(
                    p_row    => 1,
                    p_height => 40
                );

        FOR R IN C_ANEXOS LOOP
            if v_count = 0 then
                it.as_xlsx.cell(1,1,v_header||last_day(R.fecha), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                            , p_alignment => it.as_xlsx.get_alignment( p_wraptext => true ));
               it.as_xlsx.mergecells(
                p_tl_col => 1,  -- A
                p_tl_row => 1,  -- 1
                p_br_col => 5,  -- A
                p_br_row => 6   -- 6
              );
            it.as_xlsx.cell(1,7,'PLANILLA COMPLEMENTARIA DE SOLVENCIA PATRIMONIAL', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                , p_fontsize => 15
                                                                , p_bold => TRUE
                                                                )
                                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, 7, 5, 7);
            it.as_xlsx.cell(1,8,'Articulo 56 de la Ley N° 861/96', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 12
                                                                        , p_bold => TRUE
                                                                        )
                                                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
            as_xlsx.mergecells( 1, 8, 5, 8);
            it.as_xlsx.cell(1,9,'Montos de Activos segun Riesgos', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 12
                                                                        , p_bold => TRUE
                                                                        )
                                                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
            as_xlsx.mergecells( 1, 9, 5, 9);
            it.as_xlsx.cell(1,10,'(detalle CATEGORIA III)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 12
                                                                        , p_bold => TRUE
                                                                        )
                                                          , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
            as_xlsx.mergecells( 1, 10, 5, 10);

            g_row := 12;
            g_col := 1;
            it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', '', 'thin', '' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'SALDOS EN BANCOS DEL PAIS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 11
                                                                        , p_bold => TRUE
                                                                        )
                                                                ,p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', '', '', 'thin' ));
            g_row := g_row +1;

            g_col := 1;
            it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( '', '', 'thin', '' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'En Guaranies', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                , p_fontsize => 11
                                                                , p_bold => TRUE
                                                                )
                                                    ,p_borderId => as_xlsx.get_border( '', '', '', 'thin' ));
            g_row := g_row +1;
            g_col := 1;
            v_count := v_count +1;
            end if;

         IF (v_seccion IS NULL OR v_seccion != R.SECCION) or (R.rubro != v_rubro_ant) THEN 
            v_seccion := R.SECCION;
            v_rubro_ant := R.rubro;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', '' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', '', 'thin' ));
            g_row := g_row +1;
            g_col := 1;

            it.as_xlsx.cell(g_col,g_row, R.rubro, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                            , p_fontsize => 11
                                                            , p_bold => TRUE
                                                            )
                                                , p_borderId => as_xlsx.get_border( '', '', 'thin', '' )); 
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,R.SECCION, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                    , p_fontsize => 11
                                    , p_bold => TRUE
                                    ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,FU_GET_TOTAL_COD_RUBRO(R.rubro), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                    , p_fontsize => 11
                                    , p_bold => TRUE
                                    )
                                    , p_borderId => as_xlsx.get_border( '', '', '', 'thin' ));
            g_col := 1;
            g_row := g_row +1;
         END IF;

         it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', '' ));
         g_col := g_col + 1;
         it.as_xlsx.cell(g_col,g_row, R.DESCRIPCION); 
         g_col := g_col + 1;
         it.as_xlsx.cell(g_col,g_row,''); 
         g_col := g_col + 1;
         it.as_xlsx.cell(g_col,g_row,''); 
         g_col := g_col + 1;
         it.as_xlsx.cell(g_col,g_row,R.total_balance, p_borderId => as_xlsx.get_border( '', '', '', 'thin' )); 
         g_col := 1;
         g_row := g_row +1;

        END LOOP;

         IF v_seccion = 'Colocaciones Bancos Privados del Pais' then 
         it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', '' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', '', 'thin' ));
            g_row := g_row +1;
            g_col := 1;

            it.as_xlsx.cell(g_col,g_row, '391004', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                            , p_fontsize => 11
                                                            , p_bold => TRUE
                                                            )
                                                , p_borderId => as_xlsx.get_border( '', '', 'thin', '' )); 
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Call Money Concedidos', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                    , p_fontsize => 11
                                    , p_bold => TRUE
                                    ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'');
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'-', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                    , p_fontsize => 11
                                    , p_bold => TRUE
                                    )
                                    , p_borderId => as_xlsx.get_border( '', '', '', 'thin' ));
            g_col := 1;
            g_row := g_row +1;
         end if;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', '', '' ));
        --as_xlsx.mergecells( 1, 11, 1, g_row -1);
        g_row := g_row +2;
        g_col := 1;

        it.as_xlsx.cell(g_col,g_row,'Este formulario tiene carácter de declaración jurada');
        g_row := g_row +1;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'Fecha '||to_char(sysdate, 'DD "de" Month "de" YYYY'));

        v_blob := it.as_xlsx.finish;
        INSERT INTO IT.SB_SOL_ARCHIVOS ( nombre_archivo, contenido_blob, id_ejecucion) VALUES ('Anexo Banco Pais', v_blob, p_id_ejecucion);
        COMMIT;
        
     end;
    -- ===================================================================
    -- PR_ANEXOS_GENERAR_EXCEL: Genera archivo excel para Garantias (Anexos)
    -- ===================================================================   
    PROCEDURE PR_ANEXOS_GENERAR_EXCEL (
        p_id_ejecucion      IN VARCHAR2,
        p_anexo             IN VARCHAR2,
        p_resultado         OUT NUMBER
    ) IS 
        V_MAX_ID                NUMBER;
        V_BLOB                  BLOB := null;
        V_COUNT                 NUMBER := 0;
        V_COD_MONEDA            VARCHAR2(3) := null;
        V_EXISTS_USD_ROWS       BOOLEAN := FALSE;
        g_row                   NUMBER := 0;
        g_col                   NUMBER := 0;
        v_header                VARCHAR2(4000);
        CURSOR C_ANEXOS IS
            SELECT id_anexo,
                fecha_anexo,
                nro_operacion,
                nombre_cliente,                      
                cod_moneda,
                to_number(total_balance) total_balance,
                fuente_datos,
                monto_usd
            FROM IT.SB_ANX_RESULTADOS a
            WHERE id_anexo in (SELECT MAX(id_anexo) 
                                FROM IT.SB_ANX_RESULTADOS b
                                where upper(a.fuente_datos) = upper(b.fuente_datos))
            AND upper(fuente_datos)  = upper( p_anexo)
            order by case cod_moneda when 'GS' then 1 else 2 end, nro_operacion, nombre_cliente;
    BEGIN
        PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 
            'Iniciando generacion de archivo Excel con anexo '||p_anexo);

                SELECT valor
                    INTO v_header
                    FROM it.SB_SOL_PARAMETROS
          WHERE nombre = 'HEADER_ARCHIVO';

        it.as_xlsx.clear_workbook;
        FOR R IN C_ANEXOS LOOP

             IF  V_COUNT = 0 THEN
                PR_SET_TOTALES (R.id_anexo, R.fuente_datos);
                it.as_xlsx.new_sheet(R.fuente_datos);
                it.as_xlsx.set_column_width(p_col => 1, p_width => 30);
                it.as_xlsx.set_column_width(p_col => 2, p_width => 30);
                it.as_xlsx.set_column_width(p_col => 3, p_width => 40);
                it.as_xlsx.set_column_width(p_col => 4, p_width => 30);
                it.as_xlsx.set_column_width(p_col => 5, p_width => 30);
                it.as_xlsx.set_column_width(p_col => 6, p_width => 30);

                it.as_xlsx.set_row(
                    p_row    => 1,
                    p_height => 40
                );
                it.as_xlsx.cell(1,1,v_header||last_day(R.fecha_anexo), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                            , p_alignment => it.as_xlsx.get_alignment( p_wraptext => true ));
               it.as_xlsx.mergecells(
                p_tl_col => 1,  -- A
                p_tl_row => 1,  -- 1
                p_br_col => 5,  -- A
                p_br_row => 6   -- 6
              );


               -- FOR I IN 1..6 LOOP
                --as_xlsx.mergecells( 1, I, 5, i);
                --END LOOP;
                it.as_xlsx.cell(1,7,'Montos de Activos segun Riesgos', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                            , p_fontsize => 15
                                                            , p_bold => TRUE
                                                            )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));               
                as_xlsx.mergecells( 1, 7, 5, 7);
                it.as_xlsx.cell(1,8,'(Detalle de Creditos Garantizados por '||case when R.FUENTE_DATOS = 'Cash Colateral' then R.FUENTE_DATOS else substr(R.FUENTE_DATOS,6) end||')', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                            , p_fontsize => 15
                                                            , p_bold => TRUE
                                                            )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));               
                as_xlsx.mergecells( 1, 8, 5, 8);

                g_col := 1;
                g_row := 10;

                it.as_xlsx.cell(g_col,g_row,'Operacion', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                , p_alignment => as_xlsx.get_alignment( p_horizontal => 30 ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Fecha', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                    , p_fontsize => 10
                                    , p_bold => TRUE
                                    )
                                    ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Nombre Cliente', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                    , p_fontsize => 10
                                    , p_bold => TRUE)
                                    ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
               it.as_xlsx.cell(g_col,g_row,'Moneda', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                    , p_fontsize => 10
                                    , p_bold => TRUE
                                    )
                                    ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Saldo', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                    , p_fontsize => 10
                                    , p_bold => TRUE
                                    )
                                    ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                V_COUNT := V_COUNT + 1;
                g_col := 1;
                g_row := g_row + 1;
                END IF;
                if  nvl(v_cod_moneda, 'GS') != R.cod_moneda then
                    V_EXISTS_USD_ROWS := TRUE;
                    --g_row := g_row +1;
                    g_col := 1;
                    it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'SUB TOTAL EN GUARANIES',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row, G_SUB_TOT_GS,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));

                    g_row := g_row +2;
                    g_col := 1;
                    it.as_xlsx.cell(g_col,g_row,'Operacion', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                            ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'Fecha', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'Nombre Cliente', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'Moneda', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'Dolares', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'Saldo Equivalente en GS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_row := g_row +1;
                    g_col := 1;
                end if;

                it.as_xlsx.cell(g_col,g_row,R.nro_operacion,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,to_char(R.fecha_anexo, 'DD/MM/YYYY'),p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,R.nombre_cliente,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,R.cod_moneda,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                if R.cod_moneda = 'USD' then 
                    it.as_xlsx.cell(g_col,g_row,R.monto_usd,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                end if;                
                it.as_xlsx.cell(g_col,g_row,R.total_balance,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                v_cod_moneda := R.cod_moneda;
                g_row := g_row +1;
                g_col := 1;

        END LOOP;
        IF V_EXISTS_USD_ROWS THEN

            it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'SUB TOTAL EN USD',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,G_TOT_USD_GS,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,G_SUB_TOT_USD_GS,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_row := g_row +1;
            g_col := 1;
        END IF;

        g_row := g_row +1;
        it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'TOTALES EN GUARANIES',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,G_TOT_GS,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +2;
        g_col := 1;



        g_row := g_row +2;

        it.as_xlsx.cell(g_col,g_row,'Este formulario tiene carácter de declaración jurada');
        g_row := g_row +1;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'Fecha '||to_char(sysdate, 'DD "de" Month "de" YYYY'));

        v_blob := it.as_xlsx.finish;
        INSERT INTO IT.SB_SOL_ARCHIVOS ( nombre_archivo, contenido_blob, id_ejecucion) VALUES (p_anexo, v_blob, p_id_ejecucion);
        COMMIT;

        p_resultado := 1;

        PR_REGISTRAR_LOG(p_id_ejecucion, 'SUCCESS', 
            'Archivo Excel de '||p_anexo||' generado exitosamente.');

    EXCEPTION
        WHEN OTHERS THEN
            PR_REGISTRAR_LOG(p_id_ejecucion, 'ERROR', 
                'Error durante la generacion del archivo Excel de anexos',
                'Error: ' || SQLERRM || ' - Codigo: ' || SQLCODE);
                p_resultado := -1;
            ROLLBACK;
    END PR_ANEXOS_GENERAR_EXCEL;
    -- ===================================================================
    -- PR_GENERAR_RES_GARANTIAS: Genera archivo excel 
    -- ===================================================================  
    PROCEDURE PR_GENERAR_RES_GARANTIAS (
        p_id_ejecucion      IN VARCHAR2,
        p_resultado         OUT NUMBER)
    IS
    V_COUNT                 NUMBER := 0;
    V_BLOB                  BLOB;
    g_row                   NUMBER := 0;
    g_col                   NUMBER := 0;
    v_header                VARCHAR2(4000);
    CURSOR C_TOTALES IS 
    select case when FUENTE_DATOS = 'Cash Colateral' then 'Creditos Colaterizados en Dinero Efectivo'
            when FUENTE_DATOS = 'Inf. Hipotecas' then 'Prestamos Garantizados por Hipotecas'
            when FUENTE_DATOS = 'Inf. Prendas' then 'Prestamos Garantizados por Prendas'
            when FUENTE_DATOS = 'Inf. FOGAPY' then 'Prestamos Garantizados por FOGAPY'
            when FUENTE_DATOS = 'Inf. FOGAMU' then 'Prestamos Garantizados por FOGAMU'
            when FUENTE_DATOS = 'Inf. FOGAVI' then 'Prestamos Garantizados por FOGAVI'
            end FUENTE_DATOS ,  
          sum(case when COD_MONEDA = 'USD' then 0 else monto_gs end ) monto_gs, 
          sum(monto_usd) monto_usd, 
          sum(case when COD_MONEDA = 'USD' then monto_gs else 0  end )monto_equivalente,
          FECHA_ANEXO
    from IT.SB_ANX_RES_TOTALES 
    where id_anexo = (select max(id_anexo) from IT.SB_ANX_RES_TOTALES)
    and COD_MONEDA != 'TOT'
    group by FUENTE_DATOS, FECHA_ANEXO;

    CURSOR C_SUMARIO IS 
    select sum(case when COD_MONEDA = 'TOT' then 0 else monto_USD end ) monto_usd,
           sum(case when COD_MONEDA = 'USD' then monto_gs else 0  end )monto_equivalente,        
           sum(case when COD_MONEDA = 'GS' then monto_gs else 0 end ) monto_gs 
    from IT.SB_ANX_RES_TOTALES 
    where id_anexo = (select max(id_anexo) from IT.SB_ANX_RES_TOTALES);
    BEGIN
    PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 'Generacion de archivo Resumen de garantias');

        SELECT valor
            INTO v_header
            FROM it.SB_SOL_PARAMETROS
      WHERE nombre = 'HEADER_ARCHIVO';

    it.as_xlsx.clear_workbook;
            it.as_xlsx.new_sheet('Resumen de Garantias');
            it.as_xlsx.set_row(
                    p_row    => 1,
                    p_height => 40
                );
            it.as_xlsx.set_column_width(p_col => 1, p_width => 40);
            it.as_xlsx.set_column_width(p_col => 2, p_width => 20);
            it.as_xlsx.set_column_width(p_col => 3, p_width => 20);
            it.as_xlsx.set_column_width(p_col => 4, p_width => 20);
            it.as_xlsx.set_column_width(p_col => 5, p_width => 20);
            it.as_xlsx.set_column_width(p_col => 6, p_width => 20);
            it.as_xlsx.set_column_width(p_col => 7, p_width => 20);

    FOR R IN C_TOTALES LOOP
        IF  V_COUNT = 0 THEN
            it.as_xlsx.cell(1,1,v_header||last_day(R.fecha_anexo), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                            , p_alignment => it.as_xlsx.get_alignment( p_wraptext => true ));
               it.as_xlsx.mergecells(
                p_tl_col => 1,
                p_tl_row => 1, 
                p_br_col => 5,
                p_br_row => 6 
              );
            it.as_xlsx.cell(1,7,'PLANILLA COMPLEMENTARIA DE SOLVENCIA PATRIMONIAL', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                , p_fontsize => 15
                                                                , p_bold => TRUE
                                                                )
                                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, 7, 5, 7);
            it.as_xlsx.cell(1,8,'Articulo 56 de la Ley N° 861/96', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 12
                                                                        , p_bold => TRUE
                                                                        )
                                                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
            as_xlsx.mergecells( 1, 8, 5, 8);
            it.as_xlsx.cell(1,9,'Montos de Activos segun Riesgos', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 12
                                                                        , p_bold => TRUE
                                                                        )
                                                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
            as_xlsx.mergecells( 1, 9, 5, 9);
            it.as_xlsx.cell(1,10,'(detalle CATEGORIA III)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 12
                                                                        , p_bold => TRUE
                                                                        )
                                                          , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
            as_xlsx.mergecells( 1, 10, 5, 10);
            g_col := 1;
            g_row := 12;

            it.as_xlsx.cell(g_col,g_row,'NOMBRE DE GARANTIAS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'USD', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'EQUIVALENTE', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'GUARANIES', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            V_COUNT := V_COUNT +1;
            g_col := 1;
            g_row := g_row +1;
        END IF;

        it.as_xlsx.cell(g_col,g_row,r.FUENTE_DATOS,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.monto_usd,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.monto_equivalente,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.monto_gs,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;
        g_col := 1;
    END LOOP;
    FOR I IN C_SUMARIO LOOP

        it.as_xlsx.cell(g_col,g_row,'TOTALES', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE
                                        )
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,I.monto_usd,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,I.monto_equivalente,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,I.monto_gs,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;
        g_col := 1;
    END LOOP;

    g_row := g_row +2;

    it.as_xlsx.cell(g_col,g_row,'Este formulario tiene carácter de declaración jurada');
    g_row := g_row +1;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row,'Fecha '||to_char(sysdate, 'DD "de" Month "de" YYYY'));

    v_blob := it.as_xlsx.finish;
    INSERT INTO IT.SB_SOL_ARCHIVOS ( nombre_archivo, contenido_blob, id_ejecucion) VALUES ('Resumen de Garantias', v_blob, p_id_ejecucion);
    COMMIT;
    p_resultado := 1;

    PR_REGISTRAR_LOG(p_id_ejecucion, 'SUCCESS', 
        'Archivo Excel de Resumen de Garantias generado exitosamente.');

    END;
    -- ===================================================================
    -- PR_BONOS_SUBORDINADOS_GEN_EXCEL: Genera archivo excel 
    -- ===================================================================   
    PROCEDURE PR_BONOS_SUBORDINADOS_GEN_EXCEL (
        p_id_ejecucion      IN VARCHAR2,
        p_fecha             IN DATE, 
        p_resultado         OUT NUMBER
    ) IS 
    V_COUNT         NUMBER := 0;
    V_BLOB          BLOB;
    v_header        VARCHAR2(4000);
    g_row                   NUMBER := 0;
    g_col                   NUMBER := 0;
    v_merge_usd_rows        NUMBER := 0;
    v_merge_usd_2           NUMBER := 0;
    v_cotizacion            NUMBER;
    v_subtotal_gs           NUMBER := 0;
    v_subtotal_equi         NUMBER := 0;
    v_bonos_menor_540       NUMBER := 0;
    cursor c_bonos is 
    select FEC_APERTURA Fecha_de_Emision, 
           FEC_VENCIMIENTO, 
           CAPITAL, 
           (TRUNC(FEC_VENCIMIENTO) - TRUNC(FEC_APERTURA)) Plazo_emision_original, 
           0 AS VALOR_CUOTA_PROXIMOS_18_M,
           CAPITAL VARLOR_MERCADO_FECHA_REPORTE,
           COD_MONEDA,
            (TRUNC(FEC_VENCIMIENTO) - TRUNC(FEC_APERTURA)) - (TRUNC(p_fecha) - TRUNC(FEC_APERTURA)) Plazo_por_Vencer
    from ah_cta_certificados t
    where t.cod_modulo = 3 
    and t.cod_modalidad = 36
    and t.estado = 'N'
    order by case COD_MONEDA when 'GS' then 1 else 2 end, FEC_APERTURA ASC;

    cursor c_bonos_usd (p_cotizacion number) is 
    select FEC_APERTURA Fecha_de_Emision, 
           FEC_VENCIMIENTO, 
           ROUND((CAPITAL * p_cotizacion)/1000) CAPITAL, 
           (TRUNC(FEC_VENCIMIENTO) - TRUNC(FEC_APERTURA)) Plazo_emision_original, 
           0 AS VALOR_CUOTA_PROXIMOS_18_M,
           ROUND((CAPITAL * p_cotizacion)/1000) VARLOR_MERCADO_FECHA_REPORTE,
           COD_MONEDA,
            (TRUNC(FEC_VENCIMIENTO) - TRUNC(FEC_APERTURA)) - (TRUNC(p_fecha) - TRUNC(FEC_APERTURA)) Plazo_por_Vencer
    from ah_cta_certificados t
    where t.cod_modulo = 3 
    and t.cod_modalidad = 36
    and t.estado = 'N'
    and COD_MONEDA = 'USD'
    ORDER BY FEC_APERTURA ASC;

    BEGIN

    SELECT VAL_CONVERSION 
      INTO V_COTIZACION
      FROM ge_cotizaciones 
     WHERE fecha = nvl(p_fecha, it.pag_cal.FU_OBT_FEC_ACTUAL(1))
       AND cod_moneda = 'USD';

        SELECT valor
            INTO v_header
            FROM it.SB_SOL_PARAMETROS
      WHERE nombre = 'HEADER_ARCHIVO';

    it.as_xlsx.clear_workbook;
    it.as_xlsx.new_sheet('Bonos Subordinados');
    it.as_xlsx.set_row(
                    p_row    => 1,
                    p_height => 40
                );
    it.as_xlsx.set_column_width(p_col => 1, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 2, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 3, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 4, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 5, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 6, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 7, p_width => 20);
    it.as_xlsx.cell(1,1,'BANCO CENTRAL DEL PARAGUAY', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            ));

    it.as_xlsx.cell(6,1,'Resolución Nº 5, Acta N° 212 /96', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            ));

    it.as_xlsx.cell(1,2,'SUPERINTENDENCIA DE BANCOS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            ));
    it.as_xlsx.cell(6,2,'ENTIDAD: ueno bank S.A.', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            ));
    it.as_xlsx.cell(1,3,'DIVISION DE CONTROL DE EMPRESAS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            ));
    it.as_xlsx.cell(6,3,'RUC :     80026157-7', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            ));
    it.as_xlsx.cell(1,4,'FINANCIERAS Y CASAS DE CAMBIO', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            ));
    it.as_xlsx.cell(6,4,'Datos al:  '||last_day(p_fecha), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            ));
    /*it.as_xlsx.cell(1,1,v_header||last_day(p_fecha), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                            , p_alignment => it.as_xlsx.get_alignment( p_wraptext => true ));
    it.as_xlsx.mergecells(
     p_tl_col => 1,
     p_tl_row => 1,
     p_br_col => 7,
     p_br_row => 6
   );*/

    it.as_xlsx.cell(1,7,'CONTROL DE BONOS SUBORDINADOS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                    , p_fontsize => 15
                                                    , p_bold => TRUE
                                                    )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
    as_xlsx.mergecells( 1, 7, 7, 7);

    it.as_xlsx.cell(1,9,'IDENTIFICACION SERIE EMITIDA', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                        , p_fontsize => 10
                                        , p_bold => TRUE)
                                        ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                        , p_alignment => as_xlsx.get_alignment( p_wraptext => true ));
    it.as_xlsx.cell(2,9,'FECHA DE EMISION ORIGINAL', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_wraptext => true ));
    it.as_xlsx.cell(3,9,'PLAZO DE EMISION ORIGINAL', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_wraptext => true ));
    it.as_xlsx.cell(4,9,'VALOR NOMINAL DE EMISION ORIGINAL', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_wraptext => true ));
    it.as_xlsx.cell(5,9,'PLAZO POR VENCER A FECHA DE REPORTE', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_wraptext => true ));
    it.as_xlsx.cell(6,9,'VALOR CUOTA DE PROXIMOS 18 MESES', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_wraptext => true ));
    it.as_xlsx.cell(7,9,'VALOR MERCADO FECHA REPORTE', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_wraptext => true ));
    g_row := 10;
    g_col := 1;
    FOR R IN c_bonos LOOP
        IF g_col = 1 THEN
        it.as_xlsx.cell(1,g_row, CASE WHEN R.COD_MONEDA = 'GS' THEN 'MONEDA NACIONAL' ELSE 'MONEDA EXTRANJERA' END
                                            , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                            , p_fontsize => 8
                                            , p_bold => TRUE)
                                            ,p_borderId => it.as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true )); 
        g_col := g_col + 1;
        if R.COD_MONEDA = 'USD' and v_count = 0 then

            v_merge_usd_rows := g_row;
            if v_merge_usd_rows != 10 then 
                as_xlsx.mergecells( 1, 10, 1, g_row -1);
            end if;
            v_count := v_count+1;
        end if;

        ELSE
        it.as_xlsx.cell(g_col,g_row, ''
                                , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 8
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( '', 'thin', 'thin', '' )
                                , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center',p_wraptext => true )); 
        g_col := g_col + 1;
        END IF;                                    
        it.as_xlsx.cell(g_col,g_row, R.Fecha_de_Emision,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.Plazo_emision_original,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.CAPITAL,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        if r.cod_moneda = 'GS' then
         v_subtotal_gs := v_subtotal_gs + r.CAPITAL;
        end if;
        it.as_xlsx.cell(g_col,g_row,r.Plazo_por_Vencer,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1; 
        it.as_xlsx.cell(g_col,g_row,r.VALOR_CUOTA_PROXIMOS_18_M,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.VARLOR_MERCADO_FECHA_REPORTE,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        g_col := 1;
        g_row := g_row + 1;  
    END LOOP;
    as_xlsx.mergecells( 1, v_merge_usd_rows, 1, g_row -1);
    v_count := 0;

    FOR R IN c_bonos_usd(V_COTIZACION) LOOP
        if v_count = 0 then 
            it.as_xlsx.cell(g_col,g_row, '(Equiv. En M.E.)'
                                , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 8
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
            g_col := g_col + 1;
            v_merge_usd_2 := g_row;
            v_count := v_count+1;

        ELSE
            it.as_xlsx.cell(g_col,g_row, ''
                                    , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                    , p_fontsize => 8
                                    , p_bold => TRUE)
                                    ,p_borderId => as_xlsx.get_border( '', 'thin', 'thin', '' )
                                    , p_alignment => as_xlsx.get_alignment( p_wraptext => true )); 
            g_col := g_col + 1;
        end if;                       
        it.as_xlsx.cell(g_col,g_row, R.Fecha_de_Emision,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.Plazo_emision_original,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.CAPITAL,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        v_subtotal_equi := v_subtotal_equi + r.CAPITAL;
        it.as_xlsx.cell(g_col,g_row,r.Plazo_por_Vencer,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        if r.Plazo_por_Vencer < 540 then
            v_bonos_menor_540 := v_bonos_menor_540 + r.CAPITAL;
        end if;
        g_col := g_col + 1; 
        it.as_xlsx.cell(g_col,g_row,r.VALOR_CUOTA_PROXIMOS_18_M,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.VARLOR_MERCADO_FECHA_REPORTE,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        g_col := 1;
        g_row := g_row + 1;  
    end loop;
    as_xlsx.mergecells( 1, v_merge_usd_2, 1, g_row -1);

    it.as_xlsx.cell(g_col,g_row, ' Sub-Total'
                                , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 8
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( '', 'thin', 'thin', '' )
                                , p_alignment => as_xlsx.get_alignment( p_wraptext => true )); 
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, v_subtotal_equi,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, v_subtotal_equi,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_row := g_row +1;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row, ' Sub-Total Moneda Nacional'
                                , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 8
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( '', 'thin', 'thin', '' )
                                , p_alignment => as_xlsx.get_alignment( p_wraptext => true )); 
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, v_subtotal_gs,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, v_subtotal_gs,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_row := g_row +1;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row, 'Total'
                                , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 8
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( '', 'thin', 'thin', '' )
                                , p_alignment => as_xlsx.get_alignment( p_wraptext => true )); 
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, (v_subtotal_equi + v_subtotal_gs),p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, '',p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, (v_subtotal_equi + v_subtotal_gs),p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));

    g_row := g_row +2;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row,'Monto a ser considerado en el patrimonio efectivo', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 12
                                , p_bold => TRUE));
    g_col := g_col + 6;
    it.as_xlsx.cell(g_col,g_row, ((v_subtotal_equi + v_subtotal_gs) - v_bonos_menor_540), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 12
                                , p_bold => TRUE));
    g_row := g_row +1;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row,'OBSERVACION: Este formulario tiene carácter de declaración jurada y sera remitido a la Superintendencia de Bancos a fin de mes');

    v_blob := it.as_xlsx.finish;
    INSERT INTO IT.SB_SOL_ARCHIVOS ( nombre_archivo, contenido_blob, id_ejecucion) VALUES ('Bonos Subordinados', v_blob, p_id_ejecucion);
    COMMIT;
    p_resultado := 1;

    PR_REGISTRAR_LOG(p_id_ejecucion, 'SUCCESS', 
        'Archivo Excel de Bonos Subordinados generado exitosamente.');

    EXCEPTION
    when others then
        PR_REGISTRAR_LOG(p_id_ejecucion, 'ERROR', 
            'Error bonos subordinados ' || 
            TO_CHAR(sysdate, 'DD/MM/YYYY')||
            'Error: '|| SQLERRM);
            p_resultado := -1;
    END;
    -- ===================================================================
    -- PR_ANEXO_BANCOS_EXTERIOR: Guardar informacion de bancos del exterior
    -- =================================================================== 
    PROCEDURE PR_ANEXO_BANCOS_EXTERIOR (
        p_id_ejecucion      IN VARCHAR2,
        p_fecha             IN DATE DEFAULT NULL,
        P_fuente_datos      IN VARCHAR2,
        p_resultado         OUT NUMBER
    ) IS 
    v_id                number;
    v_contador_error    number;
    v_ano               number := EXTRACT(YEAR from p_fecha);
    v_mes               number := EXTRACT(MONTH from p_fecha);
    BEGIN
        PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 
            'Iniciando proceso de insercion de informacion de anexo Banco del Exterior - Fecha: ' || 
            TO_CHAR(p_fecha, 'DD/MM/YYYY') );

        v_id := IT.S_ID_ANX_BCO_EXT.NEXTVAL;

        INSERT INTO IT.SB_SOL_ANX_BCO_EXT (ID, FECHA, COD_RUBRO, DESCRIPCION, COD_MONEDA, COTIZACION, PAIS, CIUDAD, MONTO_ORIGINAL, EQUIVALENTE, TOTAL_GUARANIES, FUENTE_DATOS)
        SELECT ID, FECHA, COD_RUBRO, DESCRIPCION,  COD_MONEDA, COTIZACION, PAIS, CIUDAD, MONTO_ORIGINAL, EQUIVALENTE, TOTAL_GUARANIES, FUENTE_DATOS
        FROM (
            SELECT v_id ID,
                   A.FECHA,
                   A.COD_RUBRO,
                   B.DESCRIPCION,
                   CASE
                     WHEN B.COD_MONEDA = 'USD' THEN 'DOLARES ESTADOUNIDENSES'
                     WHEN B.COD_MONEDA = 'EUR' THEN 'EUROS'
                     WHEN B.COD_MONEDA = 'BRL' THEN 'REAL BRASILEÑO'
                   END COD_MONEDA,
                   C.VAL_CONVERSION COTIZACION,
                   B.PAIS,
                   B.CIUDAD,
                   round(A.SAL_MON_RUB_ANT + A.DEB_MON_RUBRO - A.CRE_MON_RUBRO,2)MONTO_ORIGINAL,
                   round(A.SAL_EQU_LOC_ANT + A.DEB_EQU_LOCAL - A.CRE_EQU_LOCAL,2) EQUIVALENTE,
                   round(A.SAL_MON_LOC_ANT + A.DEB_MON_LOCAL - A.CRE_MON_LOCAL,2) TOTAL_GUARANIES,
                   'PROVISORIO' FUENTE_DATOS
              FROM CB_SAL_CONSOLIDADOS_DIA A
              JOIN IT.CB_RUBROS_BCO_EXTERIOR B ON A.COD_RUBRO = B.COD_RUBRO
              JOIN GE_COTIZACIONES C ON A.FECHA = C.FECHA
             WHERE A.FECHA = p_fecha
               AND UPPER(TRIM(P_fuente_datos)) = 'P'
               AND C.COD_MONEDA = 'USD'
               AND (A.SAL_MON_LOC_ANT + A.DEB_MON_LOCAL - A.CRE_MON_LOCAL
                    - (A.SAL_EQU_LOC_ANT + A.DEB_EQU_LOCAL - A.CRE_EQU_LOCAL))
                 + (A.SAL_MON_RUB_ANT + A.DEB_MON_RUBRO - A.CRE_MON_RUBRO)
                 + (A.SAL_EQU_LOC_ANT + A.DEB_EQU_LOCAL - A.CRE_EQU_LOCAL)
                 + (A.SAL_MON_LOC_ANT + A.DEB_MON_LOCAL - A.CRE_MON_LOCAL) <> 0

            UNION ALL

            SELECT v_id ID,
                   p_fecha FECHA,
                   A.COD_RUBRO,
                   B.DESCRIPCION,
                   CASE
                     WHEN B.COD_MONEDA = 'USD' THEN 'DOLARES ESTADOUNIDENSES'
                     WHEN B.COD_MONEDA = 'EUR' THEN 'EUROS'
                     WHEN B.COD_MONEDA = 'BRL' THEN 'REAL BRASILEÑO'
                   END COD_MONEDA,
                   C.VAL_CONVERSION COTIZACION,
                   B.PAIS,
                   B.CIUDAD,
                   round(A.SAL_MON_RUB_ANT + A.DEB_MON_RUBRO - A.CRE_MON_RUBRO,2) MONTO_ORIGINAL,
                   round(A.SAL_EQU_LOC_ANT + A.DEB_EQU_LOCAL - A.CRE_EQU_LOCAL,2) EQUIVALENTE,
                   round(A.SAL_MON_LOC_ANT + A.DEB_MON_LOCAL - A.CRE_MON_LOCAL,2) TOTAL_GUARANIES,
                   'HISTORICO' FUENTE_DATOS
              FROM CB_SAL_CONSOLIDADOS_HIS A
              JOIN IT.CB_RUBROS_BCO_EXTERIOR B ON A.COD_RUBRO = B.COD_RUBRO
              JOIN GE_COTIZACIONES C ON C.FECHA = p_fecha
             WHERE A.ANO = v_ano
               AND A.MES = v_mes
               AND UPPER(TRIM(P_fuente_datos)) = 'H'
               AND C.COD_MONEDA = 'USD'
               AND (A.SAL_MON_LOC_ANT + A.DEB_MON_LOCAL - A.CRE_MON_LOCAL
                    - (A.SAL_EQU_LOC_ANT + A.DEB_EQU_LOCAL - A.CRE_EQU_LOCAL))
                 + (A.SAL_MON_RUB_ANT + A.DEB_MON_RUBRO - A.CRE_MON_RUBRO)
                 + (A.SAL_EQU_LOC_ANT + A.DEB_EQU_LOCAL - A.CRE_EQU_LOCAL)
                 + (A.SAL_MON_LOC_ANT + A.DEB_MON_LOCAL - A.CRE_MON_LOCAL) <> 0
        )
        ORDER BY COD_RUBRO;
        v_contador_error := SQL%ROWCOUNT;
         p_resultado := 1;
         COMMIT;

        PR_REGISTRAR_LOG(p_id_ejecucion, 'SUCCESS', 
            'Procesamiento de anexo Banco del Exterior exitosamente. ' ||
            'Registros insertados: ' || v_contador_error);
    EXCEPTION
    WHEN OTHERS THEN
        PR_REGISTRAR_LOG(p_id_ejecucion, 'ERROR', 
            'Error en el proceso de insercion de informacion de anexo Banco del Exterior - Fecha: ' || 
            TO_CHAR(p_fecha, 'DD/MM/YYYY')||' Error: '||SQLERRM   );
         p_resultado := -1;

     END;

    -- ===================================================================
    -- PR_GEN_EXCEL_BANCOS_EXTERIOR: GENERA ARCHIVO EXCEL PARA BANCOS EXTERIOR
    -- ===================================================================   

    PROCEDURE PR_GEN_EXCEL_BANCOS_EXTERIOR (
        p_id_ejecucion      IN VARCHAR2,
        p_resultado         OUT NUMBER
    ) IS 
    V_COUNT                 NUMBER := 0;
    V_BLOB                  BLOB;
    g_row                   NUMBER := 0;
    g_col                   NUMBER := 0;
    v_header                VARCHAR2(4000);
    cursor c_bco_exterior is 
    select FECHA, 
            COD_RUBRO, 
            DESCRIPCION, 
            COD_MONEDA, 
            COTIZACION, 
            PAIS, 
            CIUDAD, 
            MONTO_ORIGINAL, 
            EQUIVALENTE, 
            TOTAL_GUARANIES
      from IT.SB_SOL_ANX_BCO_EXT
     where id = (select max(id) from IT.SB_SOL_ANX_BCO_EXT);

    BEGIN
     PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 
            'Iniciando proceso de generacion de anexo Banco del Exterior - Fecha: ' || 
            TO_CHAR(sysdate, 'DD/MM/YYYY') );

        SELECT valor
            INTO v_header
            FROM it.SB_SOL_PARAMETROS
          WHERE nombre = 'HEADER_ARCHIVO';

    it.as_xlsx.clear_workbook;
    it.as_xlsx.new_sheet('Bancos del Exterior');
    it.as_xlsx.set_column_width(p_col => 1, p_width => 40);
    it.as_xlsx.set_column_width(p_col => 2, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 3, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 4, p_width => 30);
    it.as_xlsx.set_column_width(p_col => 5, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 6, p_width => 20);
    it.as_xlsx.set_row(
                    p_row    => 1,
                    p_height => 40
                );

    for r in c_bco_exterior loop
        if V_COUNT = 0 then
        it.as_xlsx.cell(1,1,v_header||last_day(R.fecha), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                            , p_alignment => it.as_xlsx.get_alignment( p_wraptext => true ));
       it.as_xlsx.mergecells(
        p_tl_col => 1,  -- A
        p_tl_row => 1,  -- 1
        p_br_col => 6,  -- A
        p_br_row => 6   -- 6
      );
        it.as_xlsx.cell(1,7,'INFORME DE BANCOS EN EL EXTERIOR', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                        , p_fontsize => 15
                                                        , p_bold => TRUE
                                                        )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        as_xlsx.mergecells( 1, 7, 6, 7);
        it.as_xlsx.cell(1,8,'Artículo 56 de la Ley N° 861/96', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                      , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
        as_xlsx.mergecells( 1, 8, 6, 8);
        it.as_xlsx.cell(1,9,'(detalle CATEGORIA III)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    )
                                                      , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
        as_xlsx.mergecells( 1, 9, 6, 9);
        g_col := 1;
        g_row := 11;


        it.as_xlsx.cell(g_col,g_row,'INSTITUCION FINANCIERA DEL EXTERIOR', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => false ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col,g_row,'PAIS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
        g_col := g_col+1;  
        it.as_xlsx.cell(g_col,g_row,'CIUDAD', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
        g_col := g_col+1; 
        it.as_xlsx.cell(g_col,g_row,'MONEDA', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
        g_col := g_col+1; 
        it.as_xlsx.cell(g_col,g_row,'MONTO', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
        g_col := g_col+1; 
        it.as_xlsx.cell(g_col,g_row,'EQUIVALENTE MILLONES DE GS.', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                , p_fontsize => 10
                                , p_bold => TRUE)
                                ,p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
        g_col := 1; 
        g_row := g_row + 1;
        v_count := v_count+1;
        end if ;

        it.as_xlsx.cell(g_col, g_row,r.DESCRIPCION, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row,r.pais, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                             , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row,r.ciudad, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                              , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row,r.cod_moneda, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                  , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row,r.MONTO_ORIGINAL, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                      , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));
        g_col := g_col+1;
        it.as_xlsx.cell(g_col, g_row,r.TOTAL_GUARANIES, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                        , p_alignment => as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center', p_wraptext => true ));        
        g_col := 1; 
        g_row := g_row + 1;

    end loop;
    g_row := g_row +2;

    it.as_xlsx.cell(g_col,g_row,'Este formulario tiene carácter de declaración jurada');
    g_row := g_row +1;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row,'Fecha '||to_char(sysdate, 'DD "de" Month "de" YYYY'));

    v_blob := it.as_xlsx.finish;

    INSERT INTO IT.SB_SOL_ARCHIVOS ( nombre_archivo, contenido_blob, id_ejecucion) VALUES ('Anexo Banco del Exterior', v_blob, p_id_ejecucion);
    COMMIT;
    p_resultado := 1;
        PR_REGISTRAR_LOG(p_id_ejecucion, 'SUCCESS', 'Se ha generado correctamente el archivo de Bancos del Exterior');
    EXCEPTION 
    WHEN OTHERS THEN 
      p_resultado := -1;
    END;
    -- ===================================================================
    -- PR_GEN_MTO_CONTIGENCIA: Genera la insercion de Monto Contingencia
    -- =================================================================== 
    PROCEDURE PR_GEN_MTO_CONTIGENCIA (
        p_id_ejecucion      IN VARCHAR2,
        p_fecha             IN DATE DEFAULT NULL,
        p_fuente_datos      IN VARCHAR2,
        p_resultado         OUT NUMBER
    ) is
    v_contador_error    NUMBER;
    V_ANO               NUMBER := EXTRACT(YEAR from p_fecha);
    V_MES               NUMBER := EXTRACT(MONTH from p_fecha);
    V_ID                NUMBER;
    BEGIN
    PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 
            'Iniciando proceso de insercion de datos de Monto Contingencia - Fecha: ' || 
            TO_CHAR(p_fecha, 'DD/MM/YYYY') );

    V_ID := IT.S_ID_MTO_CONTINGENCIA.NEXTVAL;

    INSERT INTO IT.CB_MTO_CONTINGENCIA(ID, FECHA, COD_RUBRO, DESCRIPCION, MONTO, PONDERACION, FUENTE_DE_DATOS, ORDEN) 
    SELECT V_ID, a.fecha, nvl(a.COD_RUBRO, b.COD_RUBRO) COD_RUBRO, 
        descripcion, round( (nvl(A.SAL_MON_LOC_ANT,0) + nvl(A.DEB_MON_LOCAL,0) - nvl(A.CRE_MON_LOCAL,0)) /1000000 ), 
        PONDERACION, 'PROVISORIO', B.ORDEN
    FROM cb_sal_consolidados_dia  A RIGHT JOIN it.CB_MTO_CONTG_RUBROS b on(a.cod_rubro = b.cod_rubro and fecha = p_fecha)
    WHERE upper(p_fuente_datos) = 'P'
    union all
    SELECT V_ID, p_fecha, nvl(a.COD_RUBRO, b.COD_RUBRO) COD_RUBRO, 
            descripcion, round( (nvl(A.SAL_MON_LOC_ANT,0) + nvl(A.DEB_MON_LOCAL,0) - nvl(A.CRE_MON_LOCAL,0)) /1000000 ), 
            PONDERACION, 'HISTORICO', B.ORDEN
    FROM cb_sal_consolidados_his  A 
        RIGHT JOIN it.CB_MTO_CONTG_RUBROS b on (a.cod_rubro = b.cod_rubro and ANO = V_ANO AND MES  = V_MES)
    WHERE upper(p_fuente_datos) = 'H'
    ;

     v_contador_error := SQL%ROWCOUNT;
     p_resultado := 1;
     COMMIT;

    PR_REGISTRAR_LOG(p_id_ejecucion, 'SUCCESS', 
        'Procesamiento de Monto Contigencia ejecutado exitosamente. ' ||
        'Registros insertados: ' || v_contador_error);
    EXCEPTION 
        WHEN OTHERS THEN
            PR_REGISTRAR_LOG(p_id_ejecucion, 'ERROR', 
            'Error en el proceso de insercion de datos de Monto Contingencia - Fecha: ' || 
            TO_CHAR(p_fecha, 'DD/MM/YYYY')|| ' Error: '|| SQLERRM );
        p_resultado := -1;
    END;
    -- ===================================================================
    -- P_PATRIMONIO_EFECTIVO: Genera Archivo de Monto Contingencia
    -- ===================================================================    
    PROCEDURE PR_GEN_EXCEL_MONTO_CONTINGENCIA (
        p_id_ejecucion      IN VARCHAR2,
        p_resultado         OUT NUMBER
    ) IS 
    V_COUNT                 NUMBER := 0;
    V_BLOB                  BLOB;
    g_row                   NUMBER := 0;
    g_col                   NUMBER := 0;
    v_header                VARCHAR2(4000);
    V_COD_RUBRO_ANT         VARCHAR2(100);
    CURSOR c_mto_conting is 
    select ID, fecha, COD_RUBRO, DESCRIPCION, case when ponderacion = 0 then 0 else MONTO end monto, PONDERACION, FUENTE_DE_DATOS
                , round(sum(case when ponderacion = 0 then 0 else MONTO end) over( partition by ponderacion)) total_pond
    from IT.CB_MTO_CONTINGENCIA
    WHERE ID = (SELECT MAX(ID) FROM IT.CB_MTO_CONTINGENCIA)
    order by ORDEN ASC;
    BEGIN
     PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 
            'Iniciando proceso de generación de Monto Contingencia - Fecha: ' || 
            TO_CHAR(sysdate, 'DD/MM/YYYY') );

        SELECT valor
            INTO v_header
            FROM it.SB_SOL_PARAMETROS
          WHERE nombre = 'HEADER_ARCHIVO';

    it.as_xlsx.clear_workbook;
    it.as_xlsx.new_sheet('Monto Contingencia');
    it.as_xlsx.set_column_width(p_col => 1, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 2, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 3, p_width => 70);
    it.as_xlsx.set_column_width(p_col => 4, p_width => 30);
    it.as_xlsx.set_column_width(p_col => 5, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 6, p_width => 20);
    it.as_xlsx.set_row(
                    p_row    => 1,
                    p_height => 40
                );

     FOR R IN c_mto_conting LOOP
        if V_COUNT = 0 then
        it.as_xlsx.cell(1,1,v_header||last_day(r.fecha), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                            , p_alignment => it.as_xlsx.get_alignment( p_wraptext => true ));
       it.as_xlsx.mergecells(
        p_tl_col => 1,  -- A
        p_tl_row => 1,  -- 1
        p_br_col => 6,  -- A
        p_br_row => 6   -- 6
      );
        it.as_xlsx.cell(1,7,'PLANILLAS COMPLEMENTARIAS DE SOLVENCIA PATRIMONIAL', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                        , p_fontsize => 15
                                                        , p_bold => TRUE
                                                        )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        as_xlsx.mergecells( 1, 7, 6, 7);
        it.as_xlsx.cell(1,8,'Articulo 56 de la Ley N° 861/96', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                      , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
        as_xlsx.mergecells( 1, 8, 6, 8);
        it.as_xlsx.cell(1,9,'');
        as_xlsx.mergecells( 1, 9, 6, 9);
        it.as_xlsx.cell(1,10,'Montos de Contingencia por Nivel de Ponderación', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 12
                                                                    , p_bold => TRUE
                                                                    )
                                                      , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
        as_xlsx.mergecells( 1, 10, 6, 10);
        g_col := 1;
        g_row := 12;
       V_COUNT:= V_COUNT +1;
       end if;

       --comienza tabla 
       IF R.PONDERACION = 0 THEN
        if V_COUNT = 1 then
           it.as_xlsx.cell(g_col,g_row,' 1)      CONTINGENCIAS PARA 0,00 % DE PONDERACION', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                                ));
           g_col := g_col +1;
           it.as_xlsx.cell(g_col,g_row,'');
           g_col := g_col +1;
           it.as_xlsx.cell(g_col,g_row,'');
           g_col := g_col +1;
           as_xlsx.mergecells( 1, g_row, 3, g_row);
           it.as_xlsx.cell(g_col,g_row,R.total_pond, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                            ));
           g_col := 1;
           g_row := g_row +2;
           V_COUNT:= V_COUNT +1;
        end if;

        it.as_xlsx.cell(g_col,g_row,CASE WHEN V_COD_RUBRO_ANT = SUBSTR(r.cod_rubro, 1,5) THEN '' ELSE SUBSTR(r.cod_rubro, 1,5) END, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
       g_col := g_col +1;
       it.as_xlsx.cell(g_col,g_row,SUBSTR(r.cod_rubro, 6,6), p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
       g_col := g_col +1;
       it.as_xlsx.cell(g_col,g_row,R.DESCRIPCION, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
       g_col := g_col +1;
       it.as_xlsx.cell(g_col,g_row,R.MONTO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
       g_col := 1;
       g_row := g_row +1;  
       V_COD_RUBRO_ANT := SUBSTR(r.cod_rubro, 1,5);

       ELSIF R.PONDERACION = 20 THEN
           IF V_COUNT = 2 THEN
            g_col := 1;
             g_row := g_row +1;
               it.as_xlsx.cell(g_col,g_row,'2)      CONTINGENCIAS PARA 0,20 % DE PONDERACIÓN', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 12
                                                                                    , p_bold => TRUE
                                                                                    ));
                                                                                    g_col := g_col +1;
               it.as_xlsx.cell(g_col,g_row,'');
               g_col := g_col +1;
               it.as_xlsx.cell(g_col,g_row,'');
               g_col := g_col +1;
               as_xlsx.mergecells( 1, g_row, 3, g_row);
               it.as_xlsx.cell(g_col,g_row,R.total_pond, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                            ));
               g_col := 1;
                V_COUNT := V_COUNT+1;
                g_row := g_row +2;
           END IF;           

           it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
           g_col := g_col +1;
           it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
           g_col := g_col +1;
           it.as_xlsx.cell(g_col,g_row,R.DESCRIPCION, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
           g_col := g_col +1;
           it.as_xlsx.cell(g_col,g_row,R.MONTO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_row := g_row +1; 
            g_col := 1;

      ELSIF R.PONDERACION = 50 THEN
        IF V_COUNT = 3 THEN
           g_col := 1;
           g_row := g_row +1; 
           it.as_xlsx.cell(g_col,g_row,'3)      CONTINGENCIAS PARA 0,50 % DE PONDERACIÓN', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                            ));
            g_col := g_col +1;
           it.as_xlsx.cell(g_col,g_row,'');
           g_col := g_col +1;
           it.as_xlsx.cell(g_col,g_row,'');
           g_col := g_col +1;
           as_xlsx.mergecells( 1, g_row, 3, g_row);
           it.as_xlsx.cell(g_col,g_row,R.total_pond, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                            ));
           g_col := 1;
            V_COUNT := V_COUNT + 1;
            g_row := g_row +2;
        END IF;     

       it.as_xlsx.cell(g_col,g_row,SUBSTR(r.cod_rubro, 1,5), p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
       g_col := g_col +1;
       it.as_xlsx.cell(g_col,g_row,SUBSTR(r.cod_rubro, 6,6), p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
       g_col := g_col +1;
       it.as_xlsx.cell(g_col,g_row,R.DESCRIPCION, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
       g_col := g_col +1;
       it.as_xlsx.cell(g_col,g_row,R.MONTO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));

        g_row := g_row +1;
        g_col := 1;
        ELSIF R.PONDERACION = 100 THEN
        IF V_COUNT = 4 THEN
            g_col := 1;
            g_row := g_row +1;
           it.as_xlsx.cell(g_col,g_row,'3)      CONTINGENCIAS PARA 1,00 % DE PONDERACIÓN', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                            ));
            g_col := g_col +1;
           it.as_xlsx.cell(g_col,g_row,'');
           g_col := g_col +1;
           it.as_xlsx.cell(g_col,g_row,'');
           g_col := g_col +1;
           as_xlsx.mergecells( 1, g_row, 3, g_row);
           it.as_xlsx.cell(g_col,g_row,R.total_pond, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 12
                                                                                , p_bold => TRUE
                                                                            ));
           g_col := 1;
            V_COUNT := V_COUNT+1;
            g_row := g_row +2;
        END IF;

        it.as_xlsx.cell(g_col,g_row,SUBSTR(r.cod_rubro, 1,5), p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col +1;
        it.as_xlsx.cell(g_col,g_row,SUBSTR(r.cod_rubro, 6,6), p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col +1;
        it.as_xlsx.cell(g_col,g_row,R.DESCRIPCION, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col +1;
        it.as_xlsx.cell(g_col,g_row,R.MONTO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
       end if;
       end loop;
        g_row := g_row +2;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'Este formulario tiene carácter de declaración jurada');
        g_row := g_row +1;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'Fecha '||to_char(sysdate, 'DD "de" Month "de" YYYY'));

        v_blob := it.as_xlsx.finish;

        INSERT INTO IT.SB_SOL_ARCHIVOS ( nombre_archivo, contenido_blob, id_ejecucion) VALUES ('Monto Contingencia', v_blob, p_id_ejecucion);
        COMMIT;

        p_resultado:= 1;
        PR_REGISTRAR_LOG(p_id_ejecucion, 'SUCCESS', 'Se ha generado correctamente el archivo de Monto Contingencia');
    EXCEPTION 
    WHEN OTHERS THEN 
        PR_REGISTRAR_LOG(p_id_ejecucion, 'ERROR', 
            'Error en el proceso de creación de archivo excel Monto Contigencia - Fecha: ' || 
            TO_CHAR(sysdate, 'DD/MM/YYYY')||' Error: '||SQLERRM   );
        p_resultado := -1;

    end;
    -- ===================================================================
    -- PR_GEN_PATRIMONIO_EFT: Genera Data de Patrimonio Efectivo
    -- ===================================================================
    PROCEDURE PR_GEN_PATRIMONIO_EFT (
        p_id_ejecucion      IN VARCHAR2,
        p_fecha             IN DATE,
        p_fuente_Datos      IN VARCHAR2,
        P_auditoria         IN VARCHAR2 DEFAULT 'N',
        p_fecha_aud         IN DATE DEFAULT NULL,
        p_resultado         OUT NUMBER
    ) IS
    V_ID    NUMBER;
    v_ano   NUMBER := EXTRACT(YEAR from p_fecha);
    v_mes   NUMBER := EXTRACT(MONTH from p_fecha);
    BEGIN
    V_ID := IT.S_ID_PAT_EFT.NEXTVAL;

    insert into it.sb_pat_eft (ID, fecha,DESCRIPCION, SECCION, MONTO, TOTAL, COD_RUBRO, ORDEN)
    SELECT V_ID, p_fecha, DESCRIPCION, SECCION, MONTO, SUM(MONTO) OVER (PARTITION BY SECCION) TOTAL, COD_RUBRO, orden
    FROM 
    (
    SELECT TMP.DESCRIPCION, SECCION, 
         round(case when c.cod_rubro = '310600000000000' and P_auditoria = 'N' then 0
                    when c.cod_rubro = '310600000000000' and P_auditoria = 'Y' then 
                        (select sum(NVL(b.SAL_MON_LOC_ANT, 0) +NVL(b.DEB_MON_LOCAL, 0) - NVL(b.CRE_MON_LOCAL, 0)) / 1000000
                           FROM cb_sal_consolidados_his b 
                           where b.cod_rubro = c.cod_rubro
                            and ano = EXTRACT(YEAR from p_fecha_aud)
                            and mes = EXTRACT(MONTH from p_fecha_aud))
              else
                case when c.cod_rubro in ('190103410000000')
                    then 1 else -1 end 
                    *(sum(NVL(C.SAL_MON_LOC_ANT, 0) +NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0)) / 1000000)
              * case when c.cod_rubro = '310304080100000' then 0.7 else 1 end
              end 
              )MONTO, 
         C.COD_RUBRO,
         ORDEN
    FROM cb_sal_consolidados_his c JOIN IT.TMP_COD_RUBRO_FILTRO TMP ON (C.COD_RUBRO = TMP.COD_RUBRO)
       where c.ano = v_ano 
       AND c.mes = v_mes
       and upper (p_fuente_Datos) = 'H'
     group by C.COD_RUBRO, TMP.DESCRIPCION, TMP.SECCION, ORDEN
     union all
     SELECT TMP.DESCRIPCION, SECCION, 
         round(case when c.cod_rubro = '310600000000000' and P_auditoria = 'N' then 0
                    when c.cod_rubro = '310600000000000' and P_auditoria = 'Y' then 
                        (select sum(NVL(b.SAL_MON_LOC_ANT, 0) +NVL(b.DEB_MON_LOCAL, 0) - NVL(b.CRE_MON_LOCAL, 0)) / 1000000
                           FROM cb_sal_consolidados_his b 
                           where b.cod_rubro = c.cod_rubro
                            and ano = EXTRACT(YEAR from p_fecha_aud)
                            and mes = EXTRACT(MONTH from p_fecha_aud))
              else
                case when c.cod_rubro in ('190103410000000')
                    then 1 else -1 end 
                    *(sum(NVL(C.SAL_MON_LOC_ANT, 0) +NVL(C.DEB_MON_LOCAL, 0) - NVL(C.CRE_MON_LOCAL, 0)) / 1000000)
              * case when c.cod_rubro = '310304080100000' then 0.7 else 1 end
              end 
              )MONTO,
         C.COD_RUBRO,
         ORDEN
    FROM cb_sal_consolidados_dia c JOIN IT.TMP_COD_RUBRO_FILTRO TMP ON (C.COD_RUBRO = TMP.COD_RUBRO)
       where c.fecha = p_fecha
       and upper (p_fuente_Datos) = 'P'
     group by C.COD_RUBRO, TMP.DESCRIPCION, TMP.SECCION, ORDEN
     UNION ALL 
     SELECT 'Bonos Subordinados' DESCRIPCION, 'Bonos Subordinados' SECCION, 
            ROUND(SUM(case when Plazo_por_Vencer > 540 then VARLOR_MERCADO_FECHA_REPORTE else 0 end)) MONTO,
             null COD_RUBRO, 11 orden
     FROM (
             select (CAPITAL * G.VAL_CONVERSION)/1000000 VARLOR_MERCADO_FECHA_REPORTE,
                (TRUNC(T.FEC_VENCIMIENTO) - TRUNC(T.FEC_APERTURA)) - (TRUNC(p_fecha) - TRUNC(T.FEC_APERTURA)) Plazo_por_Vencer
            from ah_cta_certificados t, GE_COTIZACIONES G
            where t.cod_modulo = 3 
            AND G.FECHA = P_FECHA
            and t.cod_modalidad = 36
            and t.estado = 'N'
            and T.COD_MONEDA = 'USD'
            and T.COD_MONEDA = g.COD_MONEDA
            ORDER BY FEC_APERTURA ASC)
       );
        p_resultado := 1;

    END;
    -- ===================================================================
    -- PR_GEN_EXCEL_PATRIMONIO_EFT: Genera Archivo de Patrimonio Efectivo
    -- =================================================================== 
    PROCEDURE PR_GEN_EXCEL_PATRIMONIO_EFT (
        p_id_ejecucion      IN VARCHAR2,
        p_resultado         OUT NUMBER
    ) IS 
    V_COUNT                 NUMBER := 0;
    V_BLOB                  BLOB;
    g_row                   NUMBER := 0;
    g_col                   NUMBER := 0;
    v_header                VARCHAR2(4000);
    V_CAPITAL_N1            NUMBER := 0;
    V_PATRIMONIO_EFECTIVO   NUMBER := 0;
    V_SALDO_ACTIVOS         NUMBER := 0;
    V_SALDO_CONTINGENCIA    NUMBER := 0;
    V_ACTIVOS_CONT_TOT      NUMBER := 0;
    v_seccion               VARCHAR2(60) := null;
    v_descipcion            VARCHAR2(60) := 'N';
    v_total_cap_integrado   NUMBER := 0;

    cursor c_circular_1119 is 
    SELECT fecha, DESCRIPCION, SECCION, MONTO, SUM(MONTO) OVER (PARTITION BY SECCION) TOTAL, COD_RUBRO, orden,
            SUM(case when orden < 6 then MONTO else 0 end) OVER () capital_n1_TOTAL,
            SUM(case when orden between 7 and 13 then MONTO else 0 end) OVER () - sum(case when orden >= 14 then MONTO else 0 end) OVER () capital_n2_TOTAL,
            SUM(case when orden < 14 then MONTO else 0 end) OVER () - sum(case when orden >= 14 then MONTO else 0 end) OVER ()capital_TOTAL,
            sum(case when orden between 1 and 2 then monto else 0 end) OVER () capital_integrado,
            sum(case when orden between 3 and 9 then monto else 0 end) OVER ()resevas_total
    FROM it.sb_pat_eft 
    WHERE ID = (SELECT MAX(ID) FROM it.sb_pat_eft)
    ORDER BY ORDEN,fecha;
 --
    CURSOR C_ACTIVOS IS
    select FECHA, 
           CASE WHEN CATEGORIA = '1' THEN 'I'
                     WHEN CATEGORIA = '2' THEN 'II'
                     WHEN CATEGORIA = '22'THEN 'II'
                     WHEN CATEGORIA = '3' THEN 'III'
                     WHEN CATEGORIA = '4' THEN 'IV'
                    END CATEGORIA, 
           TOTAL, 
           TOTAL_ACT,
           DESCRIPCION,
           PONDERACION,
           ROUND(TOTAL * (PONDERACION/100))SALDO,
           SUM(ROUND(TOTAL * (PONDERACION/100))) OVER () AS SALDO_TOTAL
      FROM (
            select FECHA, 
                   CATEGORIA, 
                   TOTAL, 
                   SUM(TOTAL) OVER()TOTAL_ACT,
                   CASE WHEN CATEGORIA = '1' THEN 'Activos sin riesgo'
                     WHEN CATEGORIA = '2' THEN ' Activos de muy bajo riesgo'
                     WHEN CATEGORIA = '22' THEN ' Activos de muy bajo riesgo'
                     WHEN CATEGORIA = '3' THEN 'Activos de bajo riesgo '
                     WHEN CATEGORIA = '4' THEN 'Activos de riesgo normal'
                    END DESCRIPCION,
                  CASE WHEN CATEGORIA = '1' THEN 0
                     WHEN CATEGORIA = '2' THEN 20
                     WHEN CATEGORIA = '22'THEN 10
                     WHEN CATEGORIA = '3' THEN 50
                     WHEN CATEGORIA = '4' THEN 100
                END PONDERACION
            from IT.SB_SOL_RESULTADOS_TOT 
            where ID_RESULTADO = (select max(ID_RESULTADO)from IT.SB_SOL_RESULTADOS_TOT ))
    order by PONDERACION asc;

    CURSOR C_CONTINGENCIA IS 
    SELECT MONTO, 
          'CONTINGENCIA' DESCRIPCION, 
          PONDERACION, 
          ROUND(MONTO * (PONDERACION/100))SALDO,
          SUM(MONTO) OVER () AS MONTO_TOTAL,
          SUM(ROUND(MONTO * (PONDERACION/100))) OVER () AS SALDO_TOTAL
    FROM (
    select round (SUM(case when ponderacion = 0 then 0 else MONTO end))MONTO, PONDERACION
        from IT.CB_MTO_CONTINGENCIA
        WHERE ID = (SELECT MAX(ID) FROM IT.CB_MTO_CONTINGENCIA)
        GROUP BY PONDERACION)
    ORDER BY PONDERACION ASC;
    BEGIN
     PR_REGISTRAR_LOG(p_id_ejecucion, 'INFO', 
            'Iniciando proceso de generación de Patrimonio Efectivo - Fecha: ' || 
            TO_CHAR(sysdate, 'DD/MM/YYYY') );

        SELECT valor
            INTO v_header
            FROM it.SB_SOL_PARAMETROS
          WHERE nombre = 'HEADER_ARCHIVO';

    it.as_xlsx.clear_workbook;
    it.as_xlsx.new_sheet('Circular N 1199_2015');
    it.as_xlsx.set_column_width(p_col => 1, p_width => 10);
    it.as_xlsx.set_column_width(p_col => 2, p_width => 30);
    it.as_xlsx.set_column_width(p_col => 3, p_width => 30);
    it.as_xlsx.set_column_width(p_col => 4, p_width => 30);
    it.as_xlsx.set_column_width(p_col => 5, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 6, p_width => 20);
    it.as_xlsx.set_row(
                    p_row    => 1,
                    p_height => 40
                );
    for r in c_circular_1119 loop
    if v_count = 0 then
    it.as_xlsx.cell(1,1,v_header||last_day(r.fecha), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                            , p_alignment => it.as_xlsx.get_alignment( p_wraptext => true ));
       it.as_xlsx.mergecells(
        p_tl_col => 1,  -- A
        p_tl_row => 1,  -- 1
        p_br_col => 6,  -- A
        p_br_row => 6   -- 6
      );
        it.as_xlsx.cell(1,7,'RELACION ENTRE PATRIMONIO EFECTIVO Y EL TOTAL DE ACTIVOS Y CONTINGENTES PONDERADOS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                        , p_fontsize => 15
                                                        , p_bold => TRUE
                                                        )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        as_xlsx.mergecells( 1, 7, 6, 7);
        it.as_xlsx.cell(1,8,'Articulo 56 de la Ley N° 861/96', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                      , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
        as_xlsx.mergecells( 1, 8, 6, 8);
        it.as_xlsx.cell(1,9,'');
        as_xlsx.mergecells( 1, 9, 6, 9);
        v_count := v_count +1;
    g_col := 1;
    g_row := 12;
    end if;

        if r.orden < 6 then
            if v_seccion != r.seccion then
                it.as_xlsx.cell(g_col,g_row,r.orden, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,r.seccion, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,r.total, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                v_descipcion := r.descripcion;
            end if;

            if v_descipcion != r.seccion then
                if r.descripcion = 'Capital Integrado' then
                    it.as_xlsx.cell(g_col,g_row,r.orden 
                                                , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                        , p_fontsize => 10
                                                        , p_bold => TRUE
                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                    as_xlsx.mergecells( 1, g_row, 1, g_row);
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,r.descripcion, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                                            , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,r.monto, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                        , p_fontsize => 10
                                                        , p_bold => TRUE
                                                        )
                                                        , p_borderId => as_xlsx.get_border( 'thin', '', 'thin', 'thin' ));
                    as_xlsx.mergecells( 2, g_row, 5, g_row);
                    g_row := g_row +1;
                    g_col := 1;
                    v_seccion := r.seccion;
                    v_descipcion := r.descripcion;
                    v_total_cap_integrado := v_total_cap_integrado + r.monto;

                else
                    it.as_xlsx.cell(g_col,g_row,case when v_descipcion != nvl(v_seccion, 'N') then '' else r.orden end
                                    , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                    as_xlsx.mergecells( 1, g_row, 1, g_row);
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'       '||r.descripcion, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,r.monto, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    as_xlsx.mergecells( 2, g_row, 5, g_row);
                    g_row := g_row +1;
                    g_col := 1;
                    v_seccion := r.seccion;
                    v_descipcion := r.descripcion;
                    v_total_cap_integrado := v_total_cap_integrado + r.monto;
                end if;
           end if; 

        elsif r.orden between 6 and 8 then
              if v_count = 1 then
                it.as_xlsx.cell(g_col,g_row,4, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Menos', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'       Participación en Entidades Filiales', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                it.as_xlsx.cell(g_col,g_row,5, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Capital Principal (Nivel 1)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,r.capital_n1_TOTAL, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                , p_fontsize => 10
                                                                                , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                V_CAPITAL_N1 := r.capital_n1_TOTAL;
                g_row := g_row +1;
                g_col := 1;
                it.as_xlsx.cell(g_col,g_row,6, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Capital Secundario', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                v_count := v_count +1;
             end if;
            it.as_xlsx.cell(g_col,g_row, r.orden, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, g_row, 1, g_row);
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.descripcion, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.monto, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);
            g_row := g_row +1;
            g_col := 1;
            v_seccion := r.seccion;
            v_descipcion := r.descripcion;
            v_total_cap_integrado := v_total_cap_integrado + r.monto; 

        elsif r.orden between 9 and 13 then
            if v_count = 2 and r.orden = 11 then
                it.as_xlsx.cell(g_col,g_row, 10, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Otras Reservas', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
             v_count := v_count +1;
            end if;
            it.as_xlsx.cell(g_col,g_row, r.orden, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, g_row, 1, g_row);
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.descripcion, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.monto, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);
            g_row := g_row +1;
            g_col := 1;
            v_seccion := r.seccion;
            v_descipcion := r.descripcion;
            v_total_cap_integrado := v_total_cap_integrado + r.monto; 

         elsif r.orden >= 14 then
                if v_count = 3 then
                    it.as_xlsx.cell(g_col,g_row,14, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 10
                                                                                    , p_bold => TRUE
                                                                                )
                                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'Menos', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 10
                                                                                    , p_bold => TRUE
                                                                                )
                                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,r.monto, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 10
                                                                                    , p_bold => TRUE
                                                                                )
                                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                    as_xlsx.mergecells( 2, g_row, 5, g_row);
                    g_row := g_row +1;
                    g_col := 1;
                    v_count := v_count +1;
                end if;
                it.as_xlsx.cell(g_col,g_row, '', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,r.descripcion, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,r.monto, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                it.as_xlsx.cell(g_col,g_row, '', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Déficit de Previsiones', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                it.as_xlsx.cell(g_col,g_row, '', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Reservas de Revalúo  Capitalizadas ( Res. Nº 2, Acta N° 3 del 31/01/12)', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                it.as_xlsx.cell(g_col,g_row, 15, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'Capital  Complementario  (Nivel 2) (limitado al 100% del Capital Nivel 1)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,r.capital_n2_TOTAL, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                it.as_xlsx.cell(g_col,g_row, 16, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'PATRIMONIO EFECTIVO', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,r.capital_TOTAL, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                V_PATRIMONIO_EFECTIVO := r.capital_TOTAL;
                g_row := g_row +1;
                g_col := 1;
            end if;

    end loop;
    g_row := g_row +1;
    g_col := 1;
    --aca deberia ir activos ponderados
    V_COUNT := 0;
    FOR R IN C_ACTIVOS LOOP
        IF V_COUNT = 0 THEN
            V_COUNT := V_COUNT +1;
            it.as_xlsx.cell(g_col,g_row,17, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Activos Ponderados', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Categoría', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Monto', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Ponderación', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Saldo', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_row := g_row +1;
            g_col := 1;
            it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Total del Activo', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,R.TOTAL_ACT, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;
        g_col := 1;
        END IF;

        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.DESCRIPCION, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.categoria, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,R.TOTAL, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,TO_CHAR(R.PONDERACION, '999,990.00')||'%'
                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,R.SALDO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;
        g_col := 1;

        IF R.PONDERACION = 100 THEN 
            as_xlsx.mergecells( 1, g_row-6, 1, g_row-1);
            it.as_xlsx.cell(g_col,g_row,18, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Activos Ponderados', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,R.SALDO_TOTAL, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                      , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);

            V_SALDO_ACTIVOS:= R.SALDO_TOTAL;
            g_row := g_row +1;
            g_col := 1;
            END IF;
    END LOOP;
    -- contingencia poderadas
    V_COUNT := 0;
    FOR R IN C_CONTINGENCIA LOOP
        IF V_COUNT = 0 THEN
            V_COUNT := V_COUNT +1;
            it.as_xlsx.cell(g_col,g_row,19, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Contingencias Ponderadas', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Total de Contingencias', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,R.MONTO_TOTAL, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;
        END IF;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.DESCRIPCION, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,R.MONTO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,TO_CHAR(R.PONDERACION, '999,990.00')||'%'
                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,R.SALDO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;
        g_col := 1;

        IF R.PONDERACION = 100 THEN
            as_xlsx.mergecells( 1, (g_row -5), 1, (g_row -1));
    --20
        it.as_xlsx.cell(g_col,g_row,20, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'CONTINGENCIAS PONDERADOS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,R.SALDO_TOTAL, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);

        V_SALDO_CONTINGENCIA := R.SALDO_TOTAL;
            V_ACTIVOS_CONT_TOT := ROUND(V_SALDO_CONTINGENCIA + V_SALDO_ACTIVOS);
        g_row := g_row +1;
        g_col := 1;
        END IF;
    END LOOP;

    --21
        it.as_xlsx.cell(g_col,g_row,21, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'ACTIVOS Y CONTINGENCIAS PONDERADOS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row, V_ACTIVOS_CONT_TOT, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;

    --22
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 5;
    as_xlsx.mergecells( 2, g_row, 5, g_row);
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_row := g_row +1;
        g_col := 1;
    it.as_xlsx.cell(g_col,g_row,22, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'Capital Principal Exigido ( Nivel 1 ) (8 % de la Linea 19)', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,ROUND(V_ACTIVOS_CONT_TOT * 0.08), p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;
    --23
    it.as_xlsx.cell(g_col,g_row,23, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'Posición (Capital Principal - Capital Principal Exigido Linea 20)'
                                        , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;

    --23 A)
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'    a) Superavit'
                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,ROUND(CASE WHEN V_CAPITAL_N1 > (V_ACTIVOS_CONT_TOT * 0.08) THEN V_CAPITAL_N1 - (V_ACTIVOS_CONT_TOT * 0.08) ELSE 0 END)
                                    , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;
    --23 B)    
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'    b) Deficit'
                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,ROUND(CASE WHEN (V_ACTIVOS_CONT_TOT * 0.08) > V_PATRIMONIO_EFECTIVO THEN (V_ACTIVOS_CONT_TOT * 0.08) - V_PATRIMONIO_EFECTIVO  ELSE 0 END), p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;
    --24   
    it.as_xlsx.cell(g_col,g_row,24, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'Patrimonio Exigido (Capital Principal + Capital Complementario) ( 12 % de la Linea 19)'
                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,ROUND(V_ACTIVOS_CONT_TOT * 0.12), p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;
    --25   
    it.as_xlsx.cell(g_col,g_row,25, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'Posición (Patrim. Efectivo - Patrimonio Exigido)'
                                    , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;
    --25 A)
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'    a) Superavit'
                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,ROUND(CASE WHEN V_PATRIMONIO_EFECTIVO > (V_ACTIVOS_CONT_TOT * 0.12) THEN V_PATRIMONIO_EFECTIVO - (V_ACTIVOS_CONT_TOT * 0.12)  ELSE 0 END), p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;
    --25 B)    
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'    b) Deficit'
                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'');
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,ROUND(CASE WHEN (V_ACTIVOS_CONT_TOT * 0.12) > V_PATRIMONIO_EFECTIVO THEN (V_ACTIVOS_CONT_TOT * 0.12) - V_PATRIMONIO_EFECTIVO  ELSE 0 END), p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;
    --26
    it.as_xlsx.cell(g_col,g_row,26, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'Relación entre Capital Nivel 1 /ACPR', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,ROUND((V_CAPITAL_N1 / V_ACTIVOS_CONT_TOT) *100 , 2)|| '%'
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'right', p_vertical => 'right'));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;
    --27
    it.as_xlsx.cell(g_col,g_row,27, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'Relación entre Capital Nivel 1 + Nivel 2 /ACPR', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                        , p_fontsize => 10
                                                                        , p_bold => TRUE
                                                                        )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row, ROUND((V_PATRIMONIO_EFECTIVO / V_ACTIVOS_CONT_TOT) *100, 2)|| '%'
                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'right', p_vertical => 'right'));
        as_xlsx.mergecells( 2, g_row, 5, g_row);
        g_row := g_row +1;
        g_col := 1;

        -- footer
        g_row := g_row +2;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'OBSERVACION : Esta planilla tiene carácter de declaración jurada  y será remitida a la Superintendencia de Bancos mensualmente, 
        dentro de los cinco días hábiles del mes siguiente, con los Datos correspondientes al mes anterior,  adjuntadas con las respectivas
        planillas complementarias de cálculo.');
        --as_xlsx.mergecells( 1, (g_row-2), 6, g_row);
        g_row := g_row +1;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'Fecha '||to_char(sysdate, 'DD "de" Month "de" YYYY'));

    ---Empieza la 2da hoja
    v_count := 0;

    it.as_xlsx.new_sheet('Patrimonio nivel 1 y 2 8 y 12%');
    it.as_xlsx.set_column_width(p_col => 1, p_width => 10);
    it.as_xlsx.set_column_width(p_col => 2, p_width => 30);
    it.as_xlsx.set_column_width(p_col => 3, p_width => 30);
    it.as_xlsx.set_column_width(p_col => 4, p_width => 30);
    it.as_xlsx.set_column_width(p_col => 5, p_width => 20);
    it.as_xlsx.set_column_width(p_col => 6, p_width => 20);
    it.as_xlsx.set_row(
                    p_row    => 1,
                    p_height => 40
                );

    --empieza reporte
    for r in c_circular_1119 loop
    if v_count = 0 then
    it.as_xlsx.cell(1,1,v_header||last_day(r.fecha), p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                            , p_alignment => it.as_xlsx.get_alignment( p_wraptext => true ));
       it.as_xlsx.mergecells(
        p_tl_col => 1,  -- A
        p_tl_row => 1,  -- 1
        p_br_col => 6,  -- A
        p_br_row => 6   -- 6
      );
        it.as_xlsx.cell(1,7,'RELACION ENTRE PATRIMONIO EFECTIVO Y EL TOTAL DE ACTIVOS Y CONTINGENTES PONDERADOS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                        , p_fontsize => 15
                                                        , p_bold => TRUE
                                                        )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        as_xlsx.mergecells( 1, 7, 6, 7);
        it.as_xlsx.cell(1,8,'Articulo 56 de la Ley N° 861/96', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 12
                                                                            , p_bold => TRUE
                                                                            )
                                                                      , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center')); 
        as_xlsx.mergecells( 1, 8, 6, 8);
        it.as_xlsx.cell(1,9,'');
        as_xlsx.mergecells( 1, 9, 6, 9);
        v_count := v_count +1;
    g_col := 1;
    g_row := 12;
    end if;

        if v_count = 1 then
            it.as_xlsx.cell(g_col,g_row,1, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, g_row, 1, g_row);
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Capital Integrado', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.capital_integrado, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);
            g_row := g_row +1;
            g_col := 1;
            v_count := v_count +1;
        end if;

        if r.orden between 1 and 2 then
            it.as_xlsx.cell(g_col,g_row,''
                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, g_row, 1, g_row);
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'       '||case when r.descripcion = 'Capital Integrado' then 'Capital' else r.descripcion end, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.monto, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);
            g_row := g_row +1;
            g_col := 1;
            if r.descripcion = 'Capital Integrado' then 
                it.as_xlsx.cell(g_col,g_row,''
                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'       Capital Secundario', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
            end if;
        elsif r.orden between 3 and 9 then
            if v_count = 2 then
            it.as_xlsx.cell(g_col,g_row,2, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, g_row, 1, g_row);
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Reservas', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.resevas_total, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);
            g_row := g_row +1;
            g_col := 1;
            v_count := v_count +1;
            end if;

            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, g_row, 1, g_row);
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'       '||r.descripcion 
                                                , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.monto, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);
            g_row := g_row +1;
            g_col := 1;
        elsif r.orden = 11 then
            if v_count = 3 then 
                it.as_xlsx.cell(g_col,g_row,''
                                            , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'       Para Valuación de Activos', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                v_count:= v_count+1;
            end if;
            it.as_xlsx.cell(g_col,g_row,3, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, g_row, 1, g_row);
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.descripcion, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.monto, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);
            g_row := g_row +1;
            g_col := 1;
        elsif r.orden between 12 and 13 then
            it.as_xlsx.cell(g_col,g_row,case r.orden when 12 then 4 
                                                     when 13 then 5 end
                                            , p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            as_xlsx.mergecells( 1, g_row, 1, g_row);
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.descripcion, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,r.monto, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);
            g_row := g_row +1;
            g_col := 1;
            elsif r.orden >= 14 then
                if v_count = 4 then
                    it.as_xlsx.cell(g_col,g_row,6, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 10
                                                                                    , p_bold => TRUE
                                                                                )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'Menos:', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 10
                                                                                    , p_bold => TRUE
                                                                                )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,r.monto, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 10
                                                                                    , p_bold => TRUE
                                                                                )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    as_xlsx.mergecells( 2, g_row, 5, g_row);
                    g_row := g_row +1;
                    g_col := 1;
                    v_count := v_count +1;
                end if;
                it.as_xlsx.cell(g_col,g_row, '', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'          Participación en Entidades Filiales', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                it.as_xlsx.cell(g_col,g_row, '', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'          '||r.descripcion, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,r.monto, p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +1;
                g_col := 1;
                it.as_xlsx.cell(g_col,g_row, '', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                as_xlsx.mergecells( 1, g_row, 1, g_row);
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'          Déficit de Previsiones', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                g_col := g_col + 1;
                it.as_xlsx.cell(g_col,g_row,0, p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
                as_xlsx.mergecells( 2, g_row, 5, g_row);
                g_row := g_row +2;
                g_col := 1;
                -- patrimonio total
                it.as_xlsx.cell(g_col,g_row,7, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 10
                                                                                    , p_bold => TRUE
                                                                                )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'PATRIMONIO EFECTIVO', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 10
                                                                                    , p_bold => TRUE
                                                                                )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    g_col := g_col + 1;
                    it.as_xlsx.cell(g_col,g_row,r.CAPITAL_TOTAL, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                                    , p_fontsize => 10
                                                                                    , p_bold => TRUE
                                                                                )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
                    as_xlsx.mergecells( 2, g_row, 5, g_row);

                    g_row := g_row +1;
                    g_col := 1;
        end if;
    end loop;
    g_row := g_row +1;
    g_col := 1;
    -- 8 activos
    V_COUNT := 0;
    FOR R IN C_ACTIVOS LOOP
        IF V_COUNT = 0 THEN
            V_COUNT := V_COUNT +1;
            it.as_xlsx.cell(g_col,g_row,8, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Categoría', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Monto', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Ponderación', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Saldo', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_row := g_row +1;
            g_col := 1;
            it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Total del Activo', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,R.TOTAL_ACT, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;
        g_col := 1;
        END IF;

        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.DESCRIPCION, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.categoria, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                                , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,R.TOTAL, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,TO_CHAR(R.PONDERACION, '999,990.00')||'%'
                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                        , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,R.SALDO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;
        g_col := 1;

        IF R.PONDERACION = 100 THEN 
            as_xlsx.mergecells( 1, g_row-6, 1, g_row-1);
            g_row := g_row +1;
            it.as_xlsx.cell(g_col,g_row,9, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Activos Ponderados', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,R.SALDO_TOTAL, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                      , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            as_xlsx.mergecells( 2, g_row, 5, g_row);

            V_SALDO_ACTIVOS:= R.SALDO_TOTAL;
            g_row := g_row +1;
            g_col := 1;
            END IF;
    END LOOP;

    -- 10 CONTINGENCIA  
    V_COUNT := 0;
    FOR R IN C_CONTINGENCIA LOOP
        IF V_COUNT = 0 THEN
            V_COUNT := V_COUNT +1;
            g_row := g_row +1;
            V_SALDO_CONTINGENCIA := R.SALDO_TOTAL;
            it.as_xlsx.cell(g_col,g_row,10, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                           , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                           , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'Total de Contingencias', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,R.MONTO_TOTAL, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                            , p_fontsize => 10
                                                                            , p_bold => TRUE
                                                                            )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
            g_col := g_col + 1;
            it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;
        END IF;
        g_col := 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,r.DESCRIPCION, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,R.MONTO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,TO_CHAR(R.PONDERACION, '999,990.00')||'%'
                    , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                    , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
        g_col := g_col + 1;
        it.as_xlsx.cell(g_col,g_row,R.SALDO, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
        g_row := g_row +1;

    END LOOP;
    as_xlsx.mergecells( 1, (g_row -4), 1, (g_row -1));
    -- Punto 11 
    g_col := 1;
    g_row := g_row +1;
    it.as_xlsx.cell(g_col,g_row,11, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                  , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'CONTINGENCIAS PONDERADOS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,V_SALDO_CONTINGENCIA, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    as_xlsx.mergecells( 2, g_row, 5, g_row);
    g_row := g_row +1;

    -- 12
    g_col := 1;
    g_row := g_row +1;
    it.as_xlsx.cell(g_col,g_row,12, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                  , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'ACTIVOS Y CONTINGENTES PONDERADOS', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row, V_ACTIVOS_CONT_TOT, p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    as_xlsx.mergecells( 2, g_row, 5, g_row);
    g_row := g_row +1;

    --13 
    g_col := 1;
    g_row := g_row +1;
    it.as_xlsx.cell(g_col,g_row,13, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                  , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'Patrimonio Exigido  (10% de la línea 12)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,round(V_ACTIVOS_CONT_TOT * 0.1), p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    as_xlsx.mergecells( 2, g_row, 5, g_row);
    g_row := g_row +1;
    -- 14
    g_col := 1;
    g_row := g_row +1;
    it.as_xlsx.cell(g_col,g_row,14, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                  , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'Posición  (Pat.Efect. + Pat. Exig.)', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    as_xlsx.mergecells( 2, g_row, 5, g_row);
    g_row := g_row +1;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                  , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    as_xlsx.mergecells( 2, g_row, 5, g_row);
    g_row := g_row +1;    
    --
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                  , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'       a)Superavit', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,case when V_PATRIMONIO_EFECTIVO > round(V_ACTIVOS_CONT_TOT * 0.1) then V_PATRIMONIO_EFECTIVO + round(V_ACTIVOS_CONT_TOT * 0.1) else 0 end
                                , p_borderId => as_xlsx.get_border( '', '', 'thin', 'thin' ));
    as_xlsx.mergecells( 2, g_row, 5, g_row);
    g_row := g_row +1;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                  , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'       b) Deficit', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,case when V_PATRIMONIO_EFECTIVO < round(V_ACTIVOS_CONT_TOT * 0.1) then V_PATRIMONIO_EFECTIVO + round(V_ACTIVOS_CONT_TOT * 0.1) else 0 end
                            , p_borderId => as_xlsx.get_border( '', 'thin', 'thin', 'thin' ));
    as_xlsx.mergecells( 2, g_row, 5, g_row);
    g_row := g_row +1;    
    as_xlsx.mergecells( 1, (g_row -3), 1, (g_row -1));

    -- 15
    g_col := 1;
    g_row := g_row +1;
    it.as_xlsx.cell(g_col,g_row,15, p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                  , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                  , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'center', p_vertical => 'center'));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'PATRIMONIO EFECTIVO / ACT. Y CONTING. PONDERADOS ', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                        , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_fontId => it.as_xlsx.get_font( 'Calibri'
                                                                    , p_fontsize => 10
                                                                    , p_bold => TRUE
                                                                    )
                                                , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,'', p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' ));
    as_xlsx.mergecells( 2, g_row, 5, g_row);
    g_col := g_col + 1;
    it.as_xlsx.cell(g_col,g_row,round( V_PATRIMONIO_EFECTIVO / (V_ACTIVOS_CONT_TOT) * 100, 2)||'%'
                                            , p_borderId => as_xlsx.get_border( 'thin', 'thin', 'thin', 'thin' )
                                            , p_alignment => it.as_xlsx.get_alignment( p_horizontal => 'right', p_vertical => 'right'));

    -- footer
    g_row := g_row +2;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row,'Este formulario tiene carácter de declaración jurada');
    g_row := g_row +1;
    g_col := 1;
    it.as_xlsx.cell(g_col,g_row,'Fecha '||to_char(sysdate, 'DD "de" Month "de" YYYY'));

    v_blob := it.as_xlsx.finish;

    INSERT INTO IT.SB_SOL_ARCHIVOS ( nombre_archivo, contenido_blob, id_ejecucion) VALUES ('Patrimonio Efectivo', v_blob, p_id_ejecucion);
    COMMIT;

    p_resultado:= 1;
    PR_REGISTRAR_LOG(p_id_ejecucion, 'SUCCESS', 'Se ha generado correctamente el archivo de Patrimonio Efectivo');
    END;
    -- ===================================================================
    -- PR_GENERAR_ANEXOS: Procesa los datos y guarda los archivos 
    -- ===================================================================   
    PROCEDURE PR_GENERAR_ANEXOS (
        p_fecha             IN DATE,
        p_fuente_datos      IN VARCHAR2 DEFAULT NULL,
        p_id_ejecucion      OUT VARCHAR2,
        p_resultado         OUT NUMBER,
        p_anexo             IN VARCHAR2 DEFAULT NULL,
        p_aud               IN VARCHAR2 DEFAULT 'N',
        p_fecha_aud         IN DATE DEFAULT NULL
    )
    IS
        v_id_ejecucion      VARCHAR2(36);
        v_resultado         NUMBER;
        v_timestamp_inicio  TIMESTAMP;
        v_tiene_error       NUMBER := 0;

    BEGIN
        v_id_ejecucion := FU_GENERAR_UUID();
        v_timestamp_inicio := SYSTIMESTAMP; 
        PR_REGISTRAR_LOG(v_id_ejecucion, 'INFO', 
            'Iniciando proceso de generación de anexos - Fecha: ' || 
            TO_CHAR(p_fecha, 'DD/MM/YYYY') || ', Fuente: ' || NVL(p_fuente_datos, 'N/A'));
        -- Llamar a procedimientos especificos para cada anexo
        if p_anexo is null then 
            PR_PROCESAR_ANEXOS(p_fecha, v_id_ejecucion, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error en PR_PROCESAR_ANEXOS'); v_tiene_error := -1; END IF;
            PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Cash Colateral', v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Cash Colateral'); v_tiene_error := -1; END IF;
            PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. Prendas', v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Inf. Prendas'); v_tiene_error := -1; END IF;
            PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. Hipotecas', v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Inf. Hipotecas'); v_tiene_error := -1; END IF;
            PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. FOGAMU', v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Inf. FOGAMU'); v_tiene_error := -1; END IF;
            PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. FOGAVI', v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Inf. FOGAVI'); v_tiene_error := -1; END IF;
            PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. FOGAPY', v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Inf. FOGAPY'); v_tiene_error := -1; END IF;
            PR_GENERAR_RES_GARANTIAS(v_id_ejecucion, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error en PR_GENERAR_RES_GARANTIAS'); v_tiene_error := -1; END IF;
            PR_PROCESAR_ANEXO_SOLVENCIA(p_fecha, p_fuente_datos, v_id_ejecucion, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error en PR_PROCESAR_ANEXO_SOLVENCIA'); v_tiene_error := -1; END IF;
            PR_ANEXOS_SOLVENCIA_GENERAR_EXCEL(v_id_ejecucion);
            PR_BONOS_SUBORDINADOS_GEN_EXCEL (v_id_ejecucion, p_fecha, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error en PR_BONOS_SUBORDINADOS_GEN_EXCEL'); v_tiene_error := -1; END IF;
            PR_ANEXO_BANCOS_EXTERIOR(v_id_ejecucion, p_fecha, p_fuente_datos, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error en PR_ANEXO_BANCOS_EXTERIOR'); v_tiene_error := -1; END IF;
            PR_GEN_EXCEL_BANCOS_EXTERIOR(v_id_ejecucion, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Bancos Exterior'); v_tiene_error := -1; END IF;
            PR_GEN_MTO_CONTIGENCIA(v_id_ejecucion, p_fecha, p_fuente_datos, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error en PR_GEN_MTO_CONTIGENCIA'); v_tiene_error := -1; END IF;
            PR_GEN_EXCEL_MONTO_CONTINGENCIA(v_id_ejecucion, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Monto Contingencia'); v_tiene_error := -1; END IF;
            PR_PROCESAR_SOLVENCIA (v_id_ejecucion, P_fecha, p_fuente_datos, p_resultado);
            IF p_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error en PR_PROCESAR_SOLVENCIA'); v_tiene_error := -1; END IF;
            PR_GEN_EXCEL_PLT_SOL (v_id_ejecucion, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Plantilla Solvencia'); v_tiene_error := -1; END IF;
            PR_GEN_PATRIMONIO_EFT (v_id_ejecucion, p_fecha, p_fuente_datos, p_aud, p_fecha_aud, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error en PR_GEN_PATRIMONIO_EFT'); v_tiene_error := -1; END IF;
            PR_GEN_EXCEL_PATRIMONIO_EFT(v_id_ejecucion, v_resultado);
            IF v_resultado = -1 THEN PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error generando Excel: Patrimonio Efectivo'); v_tiene_error := -1; END IF;
            v_resultado := NVL(v_tiene_error, v_resultado);
        else    
            if upper(p_anexo) in 
                ('BONOS SUBORDINADOS', 'BANCOS EXTERIOR', 'RESUMEN GARANTIAS', 'BANCO PAIS', 'MONTO CONTINGENCIA',
                  'CASH COLATERAL', 'INF. PRENDAS', 'INF. HIPOTECAS', 'INF. FOGAMU', 'INF. FOGAVI', 'INF. FOGAPY',
                  'PATRIMONIO EFECTIVO', 'PLANTILLA SOLVENCIA') then 

                case upper(p_anexo) 
                    when 'BONOS SUBORDINADOS' then
                    PR_BONOS_SUBORDINADOS_GEN_EXCEL (v_id_ejecucion, p_fecha, v_resultado);
                    when 'BANCOS EXTERIOR' then 
                    PR_ANEXO_BANCOS_EXTERIOR(v_id_ejecucion, p_fecha, p_fuente_datos, v_resultado);
                    PR_GEN_EXCEL_BANCOS_EXTERIOR(v_id_ejecucion, v_resultado);
                    when 'RESUMEN GARANTIAS' then 
                    PR_PROCESAR_ANEXOS(p_fecha, v_id_ejecucion, v_resultado);
                    PR_GENERAR_RES_GARANTIAS(v_id_ejecucion, v_resultado);
                    when 'BANCO PAIS' then
                    PR_PROCESAR_ANEXO_SOLVENCIA(p_fecha, p_fuente_datos, v_id_ejecucion, v_resultado);
                    PR_ANEXOS_SOLVENCIA_GENERAR_EXCEL(v_id_ejecucion);
                    when 'CASH COLATERAL' then
                    PR_PROCESAR_ANEXOS(p_fecha, v_id_ejecucion, v_resultado);
                    PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Cash Colateral', v_resultado);
                    when 'INF. PRENDAS' then
                    PR_PROCESAR_ANEXOS(p_fecha, v_id_ejecucion, v_resultado);
                    PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. Prendas', v_resultado);
                    when 'INF. HIPOTECAS' then
                    PR_PROCESAR_ANEXOS(p_fecha, v_id_ejecucion, v_resultado);
                    PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. Hipotecas', v_resultado);
                    when 'INF. FOGAMU' then
                    PR_PROCESAR_ANEXOS(p_fecha, v_id_ejecucion, v_resultado);
                    PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. FOGAMU', v_resultado);
                    when 'INF. FOGAVI' then
                    PR_PROCESAR_ANEXOS(p_fecha, v_id_ejecucion, v_resultado);
                    PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. FOGAVI', v_resultado);
                    when 'INF. FOGAPY' then
                    PR_PROCESAR_ANEXOS(p_fecha, v_id_ejecucion, v_resultado);
                    PR_ANEXOS_GENERAR_EXCEL(v_id_ejecucion, 'Inf. FOGAPY', v_resultado);
                    when 'MONTO CONTINGENCIA' then
                    PR_GEN_MTO_CONTIGENCIA(v_id_ejecucion, p_fecha, p_fuente_datos, v_resultado);
                    PR_GEN_EXCEL_MONTO_CONTINGENCIA(v_id_ejecucion, v_resultado);
                    WHEN 'PATRIMONIO EFECTIVO' THEN
                    PR_GEN_MTO_CONTIGENCIA(v_id_ejecucion, p_fecha, p_fuente_datos, v_resultado);
                    PR_PROCESAR_SOLVENCIA (v_id_ejecucion, P_fecha, p_fuente_datos, v_resultado);
                    PR_GEN_PATRIMONIO_EFT (v_id_ejecucion, p_fecha, p_fuente_datos, p_aud, p_fecha_aud, v_resultado);
                    PR_GEN_EXCEL_PATRIMONIO_EFT(v_id_ejecucion, v_resultado);
                    when 'PLANTILLA SOLVENCIA' THEN 
                    PR_PROCESAR_ANEXOS(p_fecha, v_id_ejecucion, v_resultado);
                    PR_ANEXO_BANCOS_EXTERIOR(v_id_ejecucion, p_fecha, p_fuente_datos, v_resultado);
                    PR_PROCESAR_ANEXO_SOLVENCIA(p_fecha, p_fuente_datos, v_id_ejecucion, v_resultado);
                    PR_PROCESAR_SOLVENCIA (v_id_ejecucion, P_fecha, p_fuente_datos, v_resultado);
                    PR_GEN_EXCEL_PLT_SOL (v_id_ejecucion, v_resultado);
                end case;
            else 
            PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Nombre de anexo no valido');
            end if;
        end if ;
        IF v_resultado = 1 THEN
            PR_REGISTRAR_LOG(v_id_ejecucion, 'INFO', 'Anexo de solvencia procesado exitosamente');
            PR_REGISTRAR_LOG(v_id_ejecucion, 'SUCCESS', 'Proceso completo finalizado exitosamente. Archivo generado: Anexos');
            p_id_ejecucion := v_id_ejecucion;
            p_resultado := 1;
        ELSE
            PR_REGISTRAR_LOG(v_id_ejecucion, 'ERROR', 'Error en procesamiento de Anexos');
            p_resultado := -1;
            p_id_ejecucion := v_id_ejecucion;
        END IF;
    END;
END;