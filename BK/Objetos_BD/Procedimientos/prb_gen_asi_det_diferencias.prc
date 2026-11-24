create or replace procedure it.PRB_GEN_ASI_DET_DIFERENCIAS(p_fecha in date)
is
    ts_ini_proc TIMESTAMP;
    ts_fin_proc TIMESTAMP;
    ts_inicio   TIMESTAMP;
    ts_fin      TIMESTAMP;
    
    procedure lp_log(p_etiqueta in varchar2, p_detalle in varchar2) is
    begin
        PRG_INS_LOG_PROGRAMAS( p_cod_programa => 'PRB_GEN_ASI_DET_DIF',
                                 p_det_error    => p_detalle,
                                 p_cod_persona  => to_char(p_fecha, 'DD/MM/YYYY'),
                                 p_nro_cuenta   => p_etiqueta);
    end;
    
    procedure lp_limpiar_tablas is
    begin
        ts_inicio := systimestamp;
        
        EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.CB_ASI_MOV_TMP';
        EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.CB_ASI_DET_TMP';
        EXECUTE IMMEDIATE 'TRUNCATE TABLE IT.CB_ASI_MOV_AUX_TMP';
        
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Limpieza de tablas. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
    end;
    
    procedure lp_ins_movimientos is
        v_rows number := 0;
		TYPE t_mov IS TABLE OF IT.CB_ASI_MOV_TMP%ROWTYPE;
		v_mov t_mov;
		CURSOR c_mov IS
			WITH ASIENTOS_VALIDOS AS (
			  SELECT FECHA, NRO_ASIENTO
				FROM CB_ASI_AUTOMATICOS_DET A
				WHERE A.FECHA = p_fecha
				AND A.COD_RUBRO IN ('240402600277799', '240402600277701')
				AND COD_TRA_PADRE IS NULL
			),
			TRA_PADRES_VALIDOS AS (
			  SELECT D.FECHA, D.NRO_ASIENTO, D.COD_TRA_PADRE
				FROM CB_ASI_AUTOMATICOS_DET D
				JOIN ASIENTOS_VALIDOS A ON D.NRO_ASIENTO = A.NRO_ASIENTO AND D.FECHA = A.FECHA
			   GROUP BY D.FECHA, D.NRO_ASIENTO, D.COD_TRA_PADRE
			  HAVING SUM(CASE
						   WHEN D.TIP_MOVIMIENTO = 'D' THEN D.MTO_MON_LOCAL
						   WHEN D.TIP_MOVIMIENTO = 'C' THEN D.MTO_MON_LOCAL * -1
						 END) <> 0
			)
			SELECT A.FECHA,
				   A.HORA,
				   A.COD_USUARIO,
				   B.NRO_ASIENTO,
				   A.COD_MOD_PADRE,
				   A.COD_MAD_PADRE,
				   A.COD_TRA_PADRE,
				   REPLACE(A.DES_TRA_PADRE, '"', '') AS DES_TRA_PADRE,
				   A.COD_MODULO,
				   A.COD_MODALIDAD,
				   A.COD_TRANSACCION,
				   A.DES_TRANSACCION,
				   B.COD_RUBRO,
				   A.NRO_DOCUMENTO,
				   A.NRO_DOCUMENTO2,
				   A.NRO_DOCUMENTO3,
				   A.NRO_DOCUMENTO4 AS REF_MOVIMIENTO,
				   A.NRO_CUENTA,
				   A.COD_MONEDA,
				   B.TIP_MOVIMIENTO,
				   NVL(A.MONTO, 0) AS MONTO,
				   NVL(A.MTO_EQU_LOCAL, 0) AS MTO_EQU_LOCAL, A.COTIZACION,
				   CASE
					 WHEN A.COD_MONEDA IN ('EUR', 'USD', 'BRL', 'ARS') THEN
					   CASE
						 WHEN B.TIP_MOVIMIENTO = 'D' THEN ABS(NVL(A.MONTO, 0))
						 WHEN B.TIP_MOVIMIENTO = 'C' THEN ABS(NVL(A.MONTO, 0)) * -1 
					   END
					 ELSE 0
				   END AS DOLARES,
				   NVL(CASE
						 WHEN A.COD_MONEDA IN ('EUR', 'USD', 'BRL', 'ARS') THEN
						   CASE
							 WHEN B.TIP_MOVIMIENTO = 'D' THEN ABS(NVL(A.MTO_EQU_LOCAL, 0))
							 WHEN B.TIP_MOVIMIENTO = 'C' THEN ABS(NVL(A.MTO_EQU_LOCAL, 0)) * -1 
						   END
						 WHEN A.COD_MONEDA = 'GS' THEN
						   CASE
							 WHEN B.TIP_MOVIMIENTO = 'D' THEN ABS(NVL(A.MONTO, 0))
							 WHEN B.TIP_MOVIMIENTO = 'C' THEN ABS(NVL(A.MONTO, 0)) * -1 
							 WHEN B.TIP_MOVIMIENTO IS NULL AND A.TIP_MOV_RUBRO = 'D' THEN ABS(NVL(A.MONTO, 0))
						   END
					   END, 0) AS GUARANIES,
				   A.HORA || '-' || A.NRO_DOCUMENTO4 AS HORA_DOC4,
				   '--' AS CONTROL
			  FROM GV_MOVIMIENTOS A
			  JOIN CB_ASI_AUTOMATICOS_DET B
				ON A.NRO_DOCUMENTO4 = B.REF_MOVIMIENTO
			   AND A.FECHA = B.FECHA
			  JOIN TRA_PADRES_VALIDOS V
				ON B.COD_TRA_PADRE = V.COD_TRA_PADRE AND B.NRO_ASIENTO = V.NRO_ASIENTO AND A.FECHA = V.FECHA
			   WHERE A.TIPO = 'H'
			   AND (NVL (A.MONTO,0) + NVL (A.MTO_EQU_LOCAL,0)) <> 0;
    begin
        ts_inicio := systimestamp;
        
        EXECUTE IMMEDIATE 'ALTER INDEX IT.IDX_CBASIMOV_NRODOC UNUSABLE';
        EXECUTE IMMEDIATE 'ALTER INDEX IT.IDX_CBASIMOV_NRODOC2 UNUSABLE';
        EXECUTE IMMEDIATE 'ALTER INDEX IT.IDX_CBASIMOV_NRODOC3 UNUSABLE';
        EXECUTE IMMEDIATE 'ALTER INDEX IT.IDX_CBASIMOV_REFMOV UNUSABLE';
        
        OPEN c_mov;
		
		LOOP
			FETCH c_mov BULK COLLECT INTO v_mov LIMIT 100000;
			EXIT WHEN v_mov.COUNT = 0;
			
			FORALL i IN 1..v_mov.COUNT
				INSERT INTO CB_ASI_MOV_TMP VALUES v_mov(i);
				
			v_rows := v_rows + v_mov.COUNT; 
			
			COMMIT;
		END LOOP;
        
		CLOSE c_mov;
                
        EXECUTE IMMEDIATE 'ALTER INDEX IT.IDX_CBASIMOV_NRODOC REBUILD';
        EXECUTE IMMEDIATE 'ALTER INDEX IT.IDX_CBASIMOV_NRODOC2 REBUILD';
        EXECUTE IMMEDIATE 'ALTER INDEX IT.IDX_CBASIMOV_NRODOC3 REBUILD';
        EXECUTE IMMEDIATE 'ALTER INDEX IT.IDX_CBASIMOV_REFMOV REBUILD';
           
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Insercion en CB_ASI_MOV_TMP. ' || v_rows || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
        
        COMMIT;
           
    exception
        when others then
            lp_log('ERROR', 'Error al insertar en CB_ASI_MOV_TMP. '||sqlerrm);
            RAISE;
    end;
    
    procedure lp_ins_asientos is
		v_rows number := 0;
		TYPE t_asi IS TABLE OF CB_ASI_DET_TMP%ROWTYPE;
		v_asi t_asi;
		CURSOR c_asi IS
			WITH
			ASIENTOS_VALIDOS AS (
			  SELECT FECHA, NRO_ASIENTO
				FROM CB_ASI_AUTOMATICOS_DET A
				WHERE A.FECHA = p_fecha
				AND A.COD_RUBRO IN ('240402600277799', '240402600277701')
				AND COD_TRA_PADRE IS NULL
			),
			TRA_PADRES_VALIDOS AS (
			  SELECT D.COD_TRA_PADRE
				FROM CB_ASI_AUTOMATICOS_DET D
				JOIN ASIENTOS_VALIDOS A ON D.NRO_ASIENTO = A.NRO_ASIENTO AND D.FECHA = A.FECHA
			   GROUP BY D.COD_TRA_PADRE
			  HAVING SUM(CASE
						   WHEN D.TIP_MOVIMIENTO = 'D' THEN D.MTO_MON_LOCAL
						   WHEN D.TIP_MOVIMIENTO = 'C' THEN D.MTO_MON_LOCAL * -1
						 END) <> 0
			)
			SELECT B.FECHA,
				   B.NRO_ASIENTO,
				   B.REF_MOVIMIENTO,
				   B.COD_RUBRO,
				   B.DESCRIPCION,
				   B.COD_TRA_PADRE,
				   B.TIP_MOVIMIENTO,
				   B.VAL_COTIZACION,
				   CASE
					 WHEN B.TIP_MOVIMIENTO = 'D' THEN B.MTO_MON_RUBRO
					 WHEN B.TIP_MOVIMIENTO = 'C' THEN B.MTO_MON_RUBRO * -1
				   END AS DOLARES,
				   CASE
					 WHEN B.TIP_MOVIMIENTO = 'D' THEN B.MTO_MON_LOCAL
					 WHEN B.TIP_MOVIMIENTO = 'C' THEN B.MTO_MON_LOCAL * -1
				   END AS GUARANIES
			  FROM CB_ASI_AUTOMATICOS_DET B
			  JOIN TRA_PADRES_VALIDOS V ON B.COD_TRA_PADRE = V.COD_TRA_PADRE
			  JOIN ASIENTOS_VALIDOS A ON B.NRO_ASIENTO = A.NRO_ASIENTO AND B.FECHA = A.FECHA;
    begin
        ts_inicio := systimestamp;
		
		OPEN c_asi;
		
		LOOP
			FETCH c_asi BULK COLLECT INTO v_asi LIMIT 100000;
			EXIT WHEN v_asi.COUNT = 0;
			
			FORALL i IN 1..v_asi.COUNT
				INSERT INTO CB_ASI_DET_TMP VALUES v_asi(i);
				
			v_rows := v_rows + v_asi.COUNT; 
			
			COMMIT;
		END LOOP;
        
		CLOSE c_asi;
        
          
        ts_fin := systimestamp;
          
        lp_log('INFO', 'Insercion en CB_ASI_DET_TMP. ' || v_rows || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
          
        COMMIT;
    exception
        when others then
            lp_log('ERROR', 'Error al insertar en CB_ASI_DET_TMP. '||sqlerrm);
            RAISE;
    end;
        
    procedure lp_act_signos is
        TYPE t_ref_mov IS TABLE OF CB_ASI_MOV_TMP.REF_MOVIMIENTO%TYPE; 
        v_ref_mov t_ref_mov;
        v_rows number := 0;
        CURSOR c_positivo IS
            SELECT REF_MOVIMIENTO
            FROM CB_ASI_MOV_TMP
            GROUP BY REF_MOVIMIENTO
            HAVING 
                SUM(CASE WHEN MTO_EQU_LOCAL = 0 THEN MONTO ELSE MTO_EQU_LOCAL END) != ABS(SUM(GUARANIES)) 
                AND COUNT(DISTINCT TIP_MOVIMIENTO) = 1
                AND COUNT(1) > 1
                AND CASE WHEN SUM(CASE WHEN MTO_EQU_LOCAL = 0 THEN MONTO ELSE MTO_EQU_LOCAL END) < 0 THEN 'C' ELSE 'D' END = MIN(TIP_MOVIMIENTO);
        
        CURSOR c_negativo IS
            SELECT REF_MOVIMIENTO
            FROM CB_ASI_MOV_TMP
            GROUP BY REF_MOVIMIENTO
            HAVING 
                SUM(CASE WHEN MTO_EQU_LOCAL = 0 THEN MONTO ELSE MTO_EQU_LOCAL END) != ABS(SUM(GUARANIES)) 
                AND COUNT(DISTINCT TIP_MOVIMIENTO) = 1
                AND COUNT(1) > 1
                AND CASE WHEN SUM(CASE WHEN MTO_EQU_LOCAL = 0 THEN MONTO ELSE MTO_EQU_LOCAL END) < 0 THEN 'C' ELSE 'D' END != MIN(TIP_MOVIMIENTO);
        
    begin
        ts_inicio := systimestamp;
        -- correccion de signos (GUARANIES = MONTO*-1)
        IF c_positivo%ISOPEN THEN
            CLOSE c_positivo;
        END IF;
        
        OPEN c_positivo;
        
        LOOP
            FETCH c_positivo BULK COLLECT INTO v_ref_mov LIMIT 50000;
            EXIT WHEN v_ref_mov.COUNT = 0;
            
            FORALL i IN 1..v_ref_mov.COUNT
                UPDATE CB_ASI_MOV_TMP
                SET GUARANIES = CASE WHEN MTO_EQU_LOCAL = 0 THEN MONTO ELSE MTO_EQU_LOCAL END, 
                    DOLARES = CASE WHEN COD_MONEDA = 'GS' THEN 0 ELSE MONTO END
                WHERE REF_MOVIMIENTO = v_ref_mov(i);
                
            v_rows := v_rows + v_ref_mov.COUNT;
        
        END LOOP;
        
        CLOSE c_positivo;
        
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Actualizacion de signos (GUARANIES = MONTO) en CB_ASI_MOV_TMP. ' || v_rows || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
        
        ts_inicio := systimestamp;
        
        -- correccion de signos (GUARANIES = MONTO*-1)
        IF c_negativo%ISOPEN THEN
            CLOSE c_negativo;
        END IF;
        
        OPEN c_negativo;
        
        v_rows := 0;
        
        LOOP
            FETCH c_negativo BULK COLLECT INTO v_ref_mov LIMIT 50000;
            EXIT WHEN v_ref_mov.COUNT = 0;
            
            FORALL i IN 1..v_ref_mov.COUNT
                UPDATE CB_ASI_MOV_TMP
                SET GUARANIES = CASE WHEN MTO_EQU_LOCAL = 0 THEN MONTO ELSE MTO_EQU_LOCAL END * -1, 
                    DOLARES = CASE WHEN COD_MONEDA = 'GS' THEN 0 ELSE MONTO END * -1
                WHERE REF_MOVIMIENTO = v_ref_mov(i);
            
            v_rows := v_rows + v_ref_mov.COUNT;
        END LOOP;
       
        CLOSE c_negativo;
        
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Actualizacion de signos (GUARANIES = MONTO*-1) en CB_ASI_MOV_TMP. ' || v_rows || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
        
    exception
        when others then
            lp_log('ERROR', 'Error al actualizar signos en CB_ASI_MOV_TMP. '||sqlerrm);
            RAISE;
    end;
    
    procedure lp_eli_mov_balanceados is 
        v_rows number := 0;
        TYPE t_rid IS TABLE OF ROWID; 
        v_rids t_rid;
        
        CURSOR c_eliminar IS
        SELECT RID
            FROM (
                SELECT 
                    ROWID AS RID,
                    -- Totales por diferentes niveles
                    SUM(GUARANIES) OVER(PARTITION BY NRO_ASIENTO) AS SUM_ASIENTO,
                    SUM(GUARANIES) OVER(PARTITION BY NRO_ASIENTO, COD_TRA_PADRE) AS SUM_PADRE,
                    SUM(GUARANIES) OVER(PARTITION BY NRO_ASIENTO, COD_TRA_PADRE, NRO_DOCUMENTO) AS SUM_DOC1,
                    SUM(GUARANIES) OVER(PARTITION BY NRO_ASIENTO, COD_TRA_PADRE, NRO_DOCUMENTO2) AS SUM_DOC2,
                    SUM(GUARANIES) OVER(PARTITION BY NRO_ASIENTO, COD_TRA_PADRE, NRO_DOCUMENTO3) AS SUM_DOC3,
                    -- Condición especial de REF_MOVIMIENTO
                    SUM(GUARANIES) OVER(PARTITION BY REF_MOVIMIENTO) AS SUM_REF,
                    COUNT(DISTINCT TIP_MOVIMIENTO) OVER(PARTITION BY REF_MOVIMIENTO) AS COUNT_TIP_REF
                FROM CB_ASI_MOV_TMP
            )
            WHERE SUM_ASIENTO <> 0 
              AND (
                  SUM_PADRE = 0 
                  OR SUM_DOC1 = 0 
                  OR SUM_DOC2 = 0 
                  OR SUM_DOC3 = 0
                  OR (SUM_REF = 0 AND COUNT_TIP_REF = 2) 
              );
    begin
        ts_inicio := systimestamp;
        
        OPEN c_eliminar;
        
        LOOP
            FETCH c_eliminar BULK COLLECT INTO v_rids LIMIT 50000;
            EXIT WHEN v_rids.COUNT = 0;
            
            FORALL i IN 1..v_rids.COUNT
                DELETE FROM CB_ASI_MOV_TMP WHERE ROWID = v_rids(i);
            
            v_rows := v_rows + v_rids.COUNT;
            COMMIT;
            
        END LOOP;
        
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Eliminacion de mov anulados en CB_ASI_MOV_TMP. ' || v_rows || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
    exception
        when others then
            lp_log('ERROR', 'Error al eliminar en CB_ASI_MOV_TMP. '||sqlerrm);
            RAISE;
    end;
    
    procedure lp_act_signos_casos is
    begin
        for caso in (
            select to_number(substr(parametro, 26)) cod_tra_padre, to_number(val_parametro) cod_transaccion
            from ge_par_dinamicos
            where substr(parametro, 1, 24) = 'ASI_DET_ACT_SIGNOS_CASO1'
        )loop
            ts_inicio := systimestamp;
            
            UPDATE CB_ASI_MOV_TMP A
            SET GUARANIES = MONTO
            WHERE COD_TRA_PADRE = caso.cod_tra_padre
            AND COD_TRANSACCION = caso.cod_transaccion
            AND EXISTS (
                SELECT 1
                FROM GV_MOVIMIENTOS
                WHERE FECHA = A.FECHA
                AND NRO_DOCUMENTO4 = A.REF_MOVIMIENTO
                AND COD_TIP_MOVIMIENTO = A.TIP_MOVIMIENTO
            );
            
            ts_fin := systimestamp;
            
             lp_log('INFO', 'Actualizacion de signos ([' || caso.cod_tra_padre || '-' || caso.cod_transaccion || '] ASIENTO.TIP_MOVIMIENTO = MOVIMIENTOS.TIP_MOVIMIENTO) en CB_ASI_MOV_TMP ' || sql%rowcount || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
        end loop;
        
        for caso in (
            select to_number(substr(parametro, 26)) cod_tra_padre, to_number(val_parametro) cod_transaccion
            from ge_par_dinamicos
            where substr(parametro, 1, 24) = 'ASI_DET_ACT_SIGNOS_CASO2'
        )loop
            ts_inicio := systimestamp;
            
            UPDATE CB_ASI_MOV_TMP A
            SET GUARANIES = MONTO
            WHERE COD_TRA_PADRE = caso.cod_tra_padre
            AND COD_TRANSACCION = caso.cod_transaccion
            AND EXISTS (
                SELECT 1
                FROM GV_MOVIMIENTOS
                WHERE FECHA = A.FECHA
                AND NRO_DOCUMENTO4 = A.REF_MOVIMIENTO
                AND COD_TIP_MOVIMIENTO != A.TIP_MOVIMIENTO
            );    
            
            ts_fin := systimestamp;
            
            lp_log('INFO', 'Actualizacion de signos ([' || caso.cod_tra_padre || '-' || caso.cod_transaccion || '] ASIENTO.TIP_MOVIMIENTO != MOVIMIENTOS.TIP_MOVIMIENTO) en CB_ASI_MOV_TMP ' || sql%rowcount || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
        end loop;
    
        for caso in (
            select to_number(substr(parametro, 26)) cod_tra_padre, to_number(val_parametro) cod_transaccion
            from ge_par_dinamicos
            where substr(parametro, 1, 24) = 'ASI_DET_ACT_SIGNOS_CASO3'
        )loop
            ts_inicio := systimestamp;
        
            UPDATE CB_ASI_MOV_TMP A
            SET GUARANIES = MONTO*-1
            WHERE COD_TRA_PADRE = caso.cod_tra_padre
            AND COD_TRANSACCION = caso.cod_transaccion
            AND EXISTS (
                SELECT 1
                FROM GV_MOVIMIENTOS
                WHERE FECHA = A.FECHA
                AND NRO_DOCUMENTO4 = A.REF_MOVIMIENTO
                AND COD_TIP_MOVIMIENTO = A.TIP_MOVIMIENTO
            );    
            
            ts_fin := systimestamp;
            
            lp_log('INFO', 'Actualizacion de signos ([' || caso.cod_tra_padre || '-' || caso.cod_transaccion || '] ASIENTO.TIP_MOVIMIENTO = MOVIMIENTOS.TIP_MOVIMIENTO) en CB_ASI_MOV_TMP ' || sql%rowcount || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
       end loop; 
       
       for caso in (
            select to_number(substr(parametro, 26)) cod_tra_padre, to_number(val_parametro) cod_transaccion
            from ge_par_dinamicos
            where substr(parametro, 1, 24) = 'ASI_DET_ACT_SIGNOS_CASO4'
        )loop
            ts_inicio := systimestamp;
        
            UPDATE CB_ASI_MOV_TMP A
            SET GUARANIES = MONTO*-1
            WHERE COD_TRA_PADRE = caso.cod_tra_padre
            AND COD_TRANSACCION = caso.cod_transaccion
            AND EXISTS (
                SELECT 1
                FROM GV_MOVIMIENTOS
                WHERE FECHA = A.FECHA
                AND NRO_DOCUMENTO4 = A.REF_MOVIMIENTO
                AND COD_TIP_MOVIMIENTO != A.TIP_MOVIMIENTO
            );    
            
            ts_fin := systimestamp;
            
            lp_log('INFO', 'Actualizacion de signos ([' || caso.cod_tra_padre || '-' || caso.cod_transaccion || '] ASIENTO.TIP_MOVIMIENTO != MOVIMIENTOS.TIP_MOVIMIENTO) en CB_ASI_MOV_TMP ' || sql%rowcount || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
       end loop; 
    exception
        when others then
            lp_log('ERROR', 'Error al actualizar signos en CB_ASI_MOV_TMP. '||sqlerrm);
            RAISE;
    end;
    
    procedure lp_ins_dif_mon_extranjera_aux is
    begin
        ts_inicio := systimestamp;
        
        INSERT INTO CB_ASI_MOV_AUX_TMP(FECHA, NRO_ASIENTO, COD_TRA_PADRE, DES_TRA_PADRE, DES_TRANSACCION, COD_RUBRO, REF_MOVIMIENTO, COD_MONEDA, GUARANIES, CONTROL)
        WITH RESUMEN_MOV AS (
            SELECT 
                NRO_ASIENTO, 
                REF_MOVIMIENTO, 
                TIP_MOVIMIENTO, 
                COD_RUBRO, 
                COD_MONEDA, 
                ABS(SUM(NVL(MTO_EQU_LOCAL, 0))) AS MTO_SUMADO
            FROM CB_ASI_MOV_TMP
            WHERE COD_MONEDA != 'GS'
            GROUP BY NRO_ASIENTO, REF_MOVIMIENTO, TIP_MOVIMIENTO, COD_RUBRO, COD_MONEDA
        )
        SELECT 
            A.FECHA, 
            A.NRO_ASIENTO, 
            A.COD_TRA_PADRE, 
            'DIFERENCIA POR TIPO DE CAMBIO' AS DES_TRA_PADRE, 
            'DIFERENCIA POR TIPO DE CAMBIO' AS DES_TRANSACCION, 
            A.COD_RUBRO, 
            A.REF_MOVIMIENTO, 
            B.COD_MONEDA,
            A.GUARANIES - (B.MTO_SUMADO * DECODE(a.TIP_MOVIMIENTO, 'C', -1, 1)) AS GUARANIES, 
            '--' AS CONTROL
        FROM CB_ASI_DET_TMP A
        JOIN RESUMEN_MOV B 
            ON  A.NRO_ASIENTO = B.NRO_ASIENTO
            AND A.REF_MOVIMIENTO = B.REF_MOVIMIENTO
            AND A.COD_RUBRO = B.COD_RUBRO
            AND B.TIP_MOVIMIENTO = a.TIP_MOVIMIENTO
        WHERE B.MTO_SUMADO != ABS(A.GUARANIES)
        AND (
            SELECT COUNT(1) 
            FROM CB_ASI_DET_TMP sub 
            WHERE sub.NRO_ASIENTO = A.NRO_ASIENTO 
              AND sub.REF_MOVIMIENTO = A.REF_MOVIMIENTO 
              AND sub.COD_RUBRO = A.COD_RUBRO
              AND a.TIP_MOVIMIENTO= B.TIP_MOVIMIENTO
        ) = 1;
        
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Insercion de diferencias por cotizacion en CB_ASI_MOV_AUX_TMP. ' || sql%rowcount || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
       
    exception
        when others then
            lp_log('ERROR', 'Error al insertar movimientos en moneda extranjera en CB_ASI_MOV_AUX_TMP. '||sqlerrm);
            RAISE;
    end;
    
    procedure lp_ins_dif_cot_mon_extranjera is
    begin
        ts_inicio := systimestamp;
        
        INSERT INTO CB_ASI_MOV_TMP
        SELECT FECHA, HORA, COD_USUARIO, NRO_ASIENTO, COD_MOD_PADRE, COD_MAD_PADRE, COD_TRA_PADRE, DES_TRA_PADRE, 
                COD_MODULO, COD_MODALIDAD, COD_TRANSACCION, DES_TRANSACCION, COD_RUBRO, NRO_DOCUMENTO, NRO_DOCUMENTO2, 
                NRO_DOCUMENTO3, REF_MOVIMIENTO, NRO_CUENTA, COD_MONEDA, TIP_MOVIMIENTO, MONTO, MTO_EQU_LOCAL, COTIZACION, 
                DOLARES, GUARANIES, HORA_DOC4, CONTROL
        FROM CB_ASI_MOV_AUX_TMP;
        
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Insercion de diferencias por cotizacion en CB_ASI_MOV_TMP. ' || sql%rowcount || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
        
    exception
        when others then
            lp_log('ERROR', 'Error al insertar movimientos en moneda extranjera en CB_ASI_MOV_TMP. '||sqlerrm);
            RAISE;
    end;
    procedure lp_ins_mov_ope_devengados is
    begin
        ts_inicio := systimestamp;
        
        INSERT INTO CB_ASI_MOV_TMP (FECHA, NRO_ASIENTO, DES_TRA_PADRE, DES_TRANSACCION, GUARANIES, CONTROL)
        SELECT FECHA, NRO_ASIENTO, DESCRIPCION DES_TRA_PADRE, DESCRIPCION DES_TRANSACCION, GUARANIES, '--' CONTROL
        FROM CB_ASI_DET_TMP A
        WHERE REF_MOVIMIENTO IS NULL
        AND EXISTS (
            SELECT 1
            FROM CB_ASI_DET_TMP
            WHERE REF_MOVIMIENTO IS NULL
            AND NRO_ASIENTO = A.NRO_ASIENTO
            AND COD_TRA_PADRE = A.COD_TRA_PADRE
            GROUP BY NRO_ASIENTO, COD_TRA_PADRE
            HAVING SUM(GUARANIES) != 0
        );
        
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Insercion de devengados en CB_ASI_MOV_TMP. ' || sql%rowcount || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
        
    exception
        when others then
            lp_log('ERROR', 'Error al insertar devengados en CB_ASI_MOV_TMP. '||sqlerrm);
            RAISE;
    end;
    
    procedure lp_ins_ope_wepa_faltantes is
    begin
        ts_inicio := systimestamp;
        
        INSERT INTO CB_ASI_MOV_TMP (NRO_ASIENTO, REF_MOVIMIENTO, FECHA, HORA, COD_TRA_PADRE, DES_TRA_PADRE, DES_TRANSACCION, COD_RUBRO, COD_MONEDA, GUARANIES, CONTROL)
        SELECT NRO_ASIENTO, MIN(REF_MOVIMIENTO) REF_MOVIMIENTO, FECHA, HORA, COD_TRA_PADRE, 'DIFERENCIA POR OPERACION WEPA FALTANTE' DES_TRA_PADRE, 'DIFERENCIA POR OPERACION WEPA FALTANTE' DES_TRANSACCION, MIN(COD_RUBRO) COD_RUBRO, COD_MONEDA, SUM(GUARANIES)*-1 GUARANIES, '--' CONTROL
        FROM CB_ASI_MOV_TMP
        WHERE FECHA = p_fecha
        AND COD_TRA_PADRE = 8950
        AND COD_TRANSACCION IN (8916, 8917)
        GROUP BY NRO_ASIENTO, FECHA, HORA, COD_TRA_PADRE, COD_MONEDA
        HAVING MOD(COUNT(1), 2) = 1;
        
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Insercion de operaciones WEPA en CB_ASI_MOV_TMP. ' || sql%rowcount || ' registros. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
    end;
    
    procedure lp_log_diferencias is
    begin
        FOR DIF IN (
            WITH ASI AS(
                SELECT FECHA, NRO_ASIENTO, MTO_MON_LOCAL*DECODE(TIP_MOVIMIENTO, 'C', -1, 1) MTO_ASIENTO
                FROM CB_ASI_AUTOMATICOS_DET A
                WHERE A.FECHA = p_fecha
                AND A.COD_RUBRO IN ('240402600277799', '240402600277701')
                AND COD_TRA_PADRE IS NULL
            ), MOV AS(
                SELECT FECHA, NRO_ASIENTO, SUM(GUARANIES) MTO_MOVIMIENTO
                FROM CB_ASI_MOV_TMP
                GROUP BY FECHA, NRO_ASIENTO
            )
            SELECT a.FECHA, a.NRO_ASIENTO, a.MTO_ASIENTO, b.MTO_MOVIMIENTO, a.MTO_ASIENTO + NVL(b.MTO_MOVIMIENTO, 0) DIFERENCIA
            FROM ASI a, MOV b
            WHERE a.FECHA = b.FECHA(+)
            AND a.NRO_ASIENTO = b.NRO_ASIENTO(+)
            AND a.MTO_ASIENTO + NVL(b.MTO_MOVIMIENTO, 0) != 0
        )LOOP
            lp_log('DIFASI', 'Diferencia encontrada entre el monto del asiento 777 y los movimientos. ' ||
                                                    'FECHA = ' || to_char(DIF.FECHA, 'DD/MM/YYYY') || 
                                                    ', NRO_ASIENTO = ' || DIF.NRO_ASIENTO || 
                                                    ', MTO_ASIENTO = ' || DIF.MTO_ASIENTO || 
                                                    ', MTO_MOVIMIENTO = ' || DIF.MTO_MOVIMIENTO || 
                                                    ', DIFERENCIA = '||DIF.DIFERENCIA);
        END LOOP;
    exception
        when others then
            lp_log('ERROR', 'Error al insertar resumen historico en CB_ASI_RESU_DIF_HIS. '||sqlerrm);
            RAISE;
    end;
    
    procedure lp_log_ini_proceso is
    begin
        ts_ini_proc := systimestamp;        
        
        lp_log('INFO', 'Inicia ejecucion del proceso. Fecha: ' || p_fecha || ' [' || ts_ini_proc || ']');
    end;
    
    procedure lp_log_fin_proceso is
    begin
        ts_fin_proc := systimestamp;
        
        lp_log('INFO', 'Finaliza ejecucion del proceso. ' || ts_fin_proc || '. Duracion: ' || substr(ts_fin_proc - ts_ini_proc, -18, 10));
    end;
    
    procedure lp_gen_asi_det_diferencias is 
        V_NOM varchar2(100) := '';
        V_CAB varchar2(1000) := '';
        V_SQL varchar2(1000) := '';
        v_archivo varchar2(100);
        v_cant_max_dias number := nvl(fug_obt_pardinamico('ASI_DET_DIF_MAX_DIAS'), 5);
        v_seq_archivo number := mod(nvl(fug_obt_pardinamico('ASI_DET_DIF_SEQ_ARCHIVO'), 0), v_cant_max_dias)+1;
    begin
        ts_inicio := systimestamp;
        
        prg_act_par_dinamico(
            p_parametro => 'ASI_DET_DIF_SEQ_ARCHIVO',
            p_valor     => to_char(v_seq_archivo)
        );
        
        v_archivo  := 'ASI_DET_DIFERENCIAS_' || v_seq_archivo;
        v_nom  := v_archivo || '.csv';
        
        V_CAB := 'SELECT ''NRO_ASIENTO;OPERACION;NRO_CUENTA;NRO_DOCUMENTO;FECHA;HORA;COD_TRA_PADRE;DES_TRA_PADRE;COD_TRA_HIJO;DES_TRA_HIJO;COD_RUBRO;TIP_MOVIMIENTO;MONTO;COD_MONEDA;COTIZACION;MTO_EQU_LOCAL;COD_MODALIDAD;COD_USUARIO;DOLARES;GUARANIES'' FROM dual';

        PRG_GEN_ARCHIVO_TXT(trim(V_NOM),V_CAB,'N',null,'N');
        
        V_SQL := '
                SELECT  NRO_ASIENTO,
                        TO_CHAR(REF_MOVIMIENTO) OPERACION,
                        TO_CHAR(NRO_CUENTA) NRO_CUENTA,
                        NRO_DOCUMENTO,
                        FECHA,
                        HORA,
                        COD_TRA_PADRE,
                        DES_TRA_PADRE,
                        COD_TRANSACCION COD_TRA_HIJO,
                        DES_TRANSACCION DES_TRA_HIJO,
                        TO_CHAR(COD_RUBRO) COD_RUBRO,
                        TIP_MOVIMIENTO,
                        MONTO,
                        COD_MONEDA,
                        COTIZACION,
                        MTO_EQU_LOCAL,
                        COD_MODALIDAD,
                        COD_USUARIO,
                        DOLARES,
                        GUARANIES
                FROM CB_ASI_MOV_TMP
        ';
        
        PRG_GEN_ARCHIVO_TXT(trim(V_NOM),V_SQL,'N',';','S');
        
        ts_fin := systimestamp;
        
        lp_log('INFO', 'Generacion del archivo. Duracion: ' || substr(ts_fin - ts_inicio, -18, 10));
                                 
    exception
        when others then
            lp_log('ERROR', 'Error al generar el archivo. '||sqlerrm);
            RAISE;
    end;
begin
    -- loguea inicio de proceso
    lp_log_ini_proceso;
    -- limpiar tablas
    lp_limpiar_tablas;
    --insert crudo movimientos
    lp_ins_movimientos;
    -- insert asientos
    lp_ins_asientos;
    -- inserta diferencia monto del asiento y del movimiento por diferencia de cotizacion en operaciones de moneda extranjera
    lp_ins_dif_mon_extranjera_aux;
    -- purga de movimientos que se cancelan entre si por nro_documento, nro_docuemnto2, nro_documento3, ref_movimiento
    lp_eli_mov_balanceados; 
    -- correccion de signos en el calculo de guaranies por inconsistencia ASIENTO - MOVIMIENTO
    lp_act_signos;
    -- purga de movimientos que se cancelan entre si por nro_documento, nro_docuemnto2, nro_documento3, ref_movimiento
    lp_eli_mov_balanceados; 
    -- correccion de signos
    lp_act_signos_casos;
    -- inserta diferencia monto del asiento y del movimiento por diferencia de cotizacion en operaciones de moneda extranjera
    lp_ins_dif_cot_mon_extranjera;
    -- inserta movimiento por desbalance en devengados
    lp_ins_mov_ope_devengados;
    -- inserta movimientos por desbalance de operaciones WEPA
    lp_ins_ope_wepa_faltantes;
    -- inserta resumen de montos por nro de asiento
    lp_log_diferencias;
    -- Genera archivo de detalle de asientos condiferencias
    lp_gen_asi_det_diferencias;
    -- loguea fin de proceso
    lp_log_fin_proceso;
    
    COMMIT;
exception
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, sqlerrm);
end;
