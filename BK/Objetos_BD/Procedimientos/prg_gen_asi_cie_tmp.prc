CREATE OR REPLACE PROCEDURE IT.PRG_GEN_ASI_CIE_TMP IS
-- OBJETIVO   : Generar una simulacion de los asientos a ser generados por IT GF.
--              Al finalizar este proceso se generara la tabla ge_asientos_tmp,
--              que contendra
-- PROGRAMADOR: Agustin Meza
-- FECHA      : 09/Feb/2005
-- VERSION: 08/09/2009 Agrego el NRO_DOCUMENTO en GE_ASIENTOS_TMP: Ingrid Larrai??n

-- Definicion de variables
wk_lgofici       varchar2(1) := 'N';
wk_cdctaco       varchar2(20);
vh_cod_oficina   number(4);
wk_tip_mov_rubro varchar2(1);
v_tip_movimiento varchar2(1);
x_tip_movimiento varchar2(1);
--
v_monto         ge_movimientos.monto%type;
v_cotizacion    ge_cotizaciones.val_conversion%type;
v_cot_usd       ge_cotizaciones.val_conversion%type;
v_mto_equ_local ge_movimientos.mto_equ_local%type;
v_cod_mon_local ba_monedas.cod_moneda%type := pag_gen.fu_obt_mon_local;
v_tip_mov_rubro ge_movimientos.tip_mov_rubro%type;
v_cod_rubro     ge_movimientos.cod_rubro%type;
v_nro_documento ge_movimientos.nro_documento%type;
v_grabar        number(4) := 0;
v_msj           varchar2(3000);
v_redondeo_ml   number(5);
v_fecha         DATE;
v_hor_inicio    VARCHAR2(8);
v_hor_fin       VARCHAR2(8);
v_lugar         number;
v_cod_mon_fuerte ba_monedas.cod_moneda%type;
v_val_cot_eur    ge_cotizaciones.val_conversion%type;
v_dato           varchar2(2000);
v_niv_paralelismo     number := nvl(to_number(fug_obt_pardinamico('GE_VAL_NIV_PARAL_ASI_TMP')),6);
v_act_paralelismo     varchar2(1) := nvl(fug_obt_pardinamico('GE_ACT_PARAL_ASI_TMP'),'N');
/*Para parametros dinamicos*/
v_ge_par_dinamicos it.typ_ge_par_dinamicos_tab;

/* Obtiene el codigo de plazo a partir de la cantidad de dias. */
PROCEDURE LP_OBT_COD_PLAZO
 (P_CAN_DIAS IN GE_PLZ_CONTABLES.CAN_DIAS%TYPE
 ,P_COD_PLAZO IN OUT GE_PLZ_CONTABLES.COD_PLAZO%TYPE
 )
 IS
BEGIN
  SELECT COD_PLAZO
    INTO p_cod_plazo
    FROM GE_PLZ_CONTABLES
   WHERE CAN_DIAS = (SELECT MIN(CAN_DIAS)
                       FROM GE_PLZ_CONTABLES
                      WHERE CAN_DIAS >= p_can_dias);
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'En lp_obt_cod_plazo '||SQLERRM);
END;
--Obtener parametro dinamico
FUNCTION LF_OBT_PARDINAMICO(
        P_PARAMETRO IN GE_PAR_DINAMICOS.PARAMETRO%TYPE,
        P_CACHED_DATA IN it.typ_ge_par_dinamicos_tab,
        P_COD_MODULO IN NUMBER DEFAULT NULL,
        P_COD_MODALIDAD IN NUMBER DEFAULT NULL,
        P_COD_MONEDA IN VARCHAR2 DEFAULT NULL,
        P_COD_OFICINA IN NUMBER DEFAULT NULL,
        P_COD_SUB_MODALIDAD IN NUMBER DEFAULT NULL
    )
     RETURN VARCHAR2
     IS
    v_val_parametro ge_par_dinamicos.val_parametro%type;
    begin 
      FOR i IN 1 .. P_CACHED_DATA.COUNT LOOP
                IF P_CACHED_DATA(i).parametro = P_PARAMETRO 
                  AND NVL(P_CACHED_DATA(i).COD_MODULO,NVL(P_COD_MODULO,-1)) = NVL(P_COD_MODULO,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_MODALIDAD,NVL(P_COD_MODALIDAD,-1)) = NVL(P_COD_MODALIDAD,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_SUB_MODALIDAD,NVL(P_COD_SUB_MODALIDAD,-1)) = NVL(P_COD_SUB_MODALIDAD,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_OFICINA,NVL(P_COD_OFICINA,-1)) = NVL(P_COD_OFICINA,-1)
                  AND  NVL(P_CACHED_DATA(i).COD_MONEDA,NVL(P_COD_MONEDA,'x')) = NVL(P_COD_MONEDA,'x') THEN
                    v_val_parametro := P_CACHED_DATA(i).val_parametro;
                    RETURN v_val_parametro;
                    exit;
                END IF;
            END LOOP;
            if v_val_parametro is null then
             return null;
            end if;
    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,'Error al buscar en ge_par_dinamicos '||SQLERRM);
    END;
-- borrado de asientos que balancean
PROCEDURE LP_ELI_ASI_BALANCEADOS IS
   CURSOR c1 IS
     SELECT COD_MOD_PADRE, COD_MAD_PADRE, COD_OFI_ORIGEN, FECHA, COD_USUARIO, HORA,
            SUM(DECODE(TIP_MOV_RUBRO,'D',MTO_EQU_LOCAL,0)) "W_TOTDEBE",
            SUM(DECODE(TIP_MOV_RUBRO,'C',MTO_EQU_LOCAL,0)) "W_TOTHABE"
       FROM GE_ASIENTOS_TMP
      WHERE TIP_MOV_RUBRO IS NOT NULL
      GROUP BY COD_MOD_PADRE, COD_MAD_PADRE, COD_OFI_ORIGEN, FECHA, COD_USUARIO, HORA
      HAVING NVL(SUM(DECODE(TIP_MOV_RUBRO,'D',MTO_EQU_LOCAL,0)),0) =
             NVL(SUM(DECODE(TIP_MOV_RUBRO,'C',MTO_EQU_LOCAL,0)),0);
 REG c1%ROWTYPE;
BEGIN
  OPEN C1;
  LOOP
    FETCH C1 INTO REG;
    EXIT WHEN C1%NOTFOUND;
    IF REG.W_TOTDEBE = REG.W_TOTHABE THEN
       DELETE GE_ASIENTOS_TMP
        WHERE COD_MOD_PADRE = REG.COD_MOD_PADRE
          AND COD_MAD_PADRE = REG.COD_MAD_PADRE
          AND COD_OFI_ORIGEN = REG.COD_OFI_ORIGEN
          AND FECHA = REG.FECHA
          AND COD_USUARIO = REG.COD_USUARIO
          AND HORA = REG.HORA
          AND USU_INSERCION = USER;
    END IF;
  END LOOP;
  CLOSE C1;
exception
   when others then
       Raise_application_error(-20000,'ERROR: en Borrado Asientos '||sqlerrm);
END;

-- Proc. que genera los movimientos imputados directamente a cuentas contables
PROCEDURE LP_PRO_MOV_CONTABLES IS
cursor MOV_CONTABLES is
    select fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
           monto, mto_equ_local, tip_mov_rubro, cod_moneda,
           cod_modulo, cod_modalidad, cod_transaccion, nro_cuenta,
           cod_mod_padre, cod_mad_padre, cod_ofi_origen, cotizacion,
           cod_oficina, cod_tra_padre, nro_documento
      from ge_movimientos_ant
     where (monto <> 0 OR mto_equ_local <> 0)
       and estado IN ('N','H')
       and cod_rubro IS NOT NULL
       and (reversado = 'N' or (reversado='S' and (fecha > fec_valor)));
TYPE cursor1_type IS TABLE OF MOV_CONTABLES%ROWTYPE;
mv cursor1_type;
TYPE type_ge_asientos_tmp IS TABLE OF ge_asientos_tmp%ROWTYPE;
reg_type_ge_asi_tmp type_ge_asientos_tmp not null:= type_ge_asientos_tmp();

PROCEDURE lp_ins_GE_MOV_CONTABLES_TMP(p_asientos_tmp in type_ge_asientos_tmp) is
  BEGIN
  -- Insert masivo usando FORALL con el índice cargado
     v_hor_inicio := to_char(sysdate,'hh24:mi:ss');    
     FORALL  i IN 1.. reg_type_ge_asi_tmp.count
        INSERT INTO GE_MOV_CONTABLES_TMP
            (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
             monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
             cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda, observacion,
             cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
             nro_documento
            )
        VALUES
            (p_asientos_tmp(i).fecha, p_asientos_tmp(i).cod_usuario, p_asientos_tmp(i).hora,
             p_asientos_tmp(i).nro_secuencia, p_asientos_tmp(i).cod_rubro,
             p_asientos_tmp(i).monto, p_asientos_tmp(i).mto_equ_local, p_asientos_tmp(i).tip_mov_rubro,
             p_asientos_tmp(i).cod_mod_padre, p_asientos_tmp(i).cod_mad_padre,
             p_asientos_tmp(i).cod_ofi_origen, p_asientos_tmp(i).cotizacion, p_asientos_tmp(i).cod_moneda,
             p_asientos_tmp(i).observacion,
             p_asientos_tmp(i).cod_tra_padre, p_asientos_tmp(i).cod_modulo, p_asientos_tmp(i).cod_modalidad,
             p_asientos_tmp(i).cod_transaccion, p_asientos_tmp(i).cod_oficina, p_asientos_tmp(i).nro_cuenta,
             p_asientos_tmp(i).nro_documento);
        
     COMMIT;
  EXCEPTION
      WHEN OTHERS THEN
          v_hor_fin := to_char(sysdate,'hh24:mi:ss');                             
          prg_act_log_procesos('PRG_GEN_ASI_CIE_TMP','GE_MOV_CONTABLES_TMP - MOV_CONTABLES', v_fecha, v_hor_inicio, v_hor_fin,'ERROR AL INSERTAR A GE_MOV_CONTABLES_TMP - MOV_CONTABLES'||SQLERRM);                     
          --ROLLBACK;
END lp_ins_GE_MOV_CONTABLES_TMP;
begin
  --Limpiar tabla auxiliar
  sql_util.ejecute_dml('TRUNCATE TABLE GE_MOV_CONTABLES_TMP', v_msj);
  if mov_contables%ISOPEN then
    CLOSE mov_contables;
  end if;
  OPEN mov_contables;
  LOOP
    FETCH mov_contables BULK COLLECT
       INTO mv LIMIT 500000;
    -- ciclo de movimientos
    FOR i IN 1.. mv.count LOOP
       -- montos del movimiento
       v_monto         := mv(i).monto;
       v_cotizacion    := mv(i).cotizacion;
       v_mto_equ_local := mv(i).mto_equ_local;
       wk_lgofici := 'N';
       ----------------------------------------
       IF mv(i).cod_oficina <> mv(i).cod_ofi_origen THEN
           -- ES ASIENTO INTEROFICINA
           wk_lgofici := 'S';
       END IF;
       -- veo si no tiene cotizacion para el movimiento
       IF mv(i).cod_moneda <> v_cod_mon_local THEN
          IF mv(i).mto_equ_local is null THEN
             if mv(i).cod_moneda = v_cod_mon_fuerte then
                v_cotizacion := v_cot_usd;
             ELSIF mv(i).cod_moneda = 'EUR' then
                v_cotizacion := v_val_cot_eur;
             else
                v_cotizacion := pag_gen.fu_obt_cotizacion(mv(i).cod_moneda);
             end if;
             v_redondeo_ml := 0;
             v_mto_equ_local := ROUND(NVL(mv(i).monto,0)*NVL(v_cotizacion,0),v_redondeo_ml);
          END IF;
       ELSE
          -- si es moneda local, muevo el importe al equivalente en moneda local
          v_mto_equ_local := mv(i).monto;
          v_monto := 0;
       END IF;
       reg_type_ge_asi_tmp.EXTEND;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).fecha := mv(i).fecha;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_usuario := mv(i).cod_usuario;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).hora := mv(i).hora;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).nro_secuencia := mv(i).nro_secuencia;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_rubro := mv(i).cod_rubro;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).monto := v_monto;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).mto_equ_local := v_mto_equ_local;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).tip_mov_rubro := mv(i).tip_mov_rubro;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_mod_padre := mv(i).cod_mod_padre;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_mad_padre := mv(i).cod_mad_padre;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_ofi_origen := mv(i).cod_ofi_origen;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cotizacion := v_cotizacion;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_moneda := mv(i).cod_moneda;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_tra_padre := mv(i).cod_tra_padre;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_modulo := mv(i).cod_modulo;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_modalidad := mv(i).cod_modalidad;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_transaccion := mv(i).cod_transaccion;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_oficina := mv(i).cod_oficina;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).nro_cuenta := mv(i).nro_cuenta;
       reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).nro_documento := mv(i).nro_documento;       
       
       ---------------------------------------------------------------
        ------------------ INTEROFICINA --------------------
        ---------------------------
        IF wk_lgofici = 'S' THEN
           -- Recuperar cuenta contable interoficina
           wk_cdctaco := LF_OBT_PARDINAMICO('COD_RUB_INTEROFICINA', v_ge_par_dinamicos,null,null,mv(i).cod_moneda,mv(i).cod_oficina);
           if mv(i).tip_mov_rubro = 'D' then
              wk_tip_mov_rubro := 'C';
           else
              wk_tip_mov_rubro := 'D';
           end if;
           wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(mv(i).cod_ofi_origen,'000'))||substr(wk_cdctaco,14,2);
           reg_type_ge_asi_tmp.EXTEND;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).fecha := mv(i).fecha;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_usuario := mv(i).cod_usuario;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).hora := mv(i).hora;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).nro_secuencia := mv(i).nro_secuencia;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_rubro := wk_cdctaco;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).monto := v_monto;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).mto_equ_local := v_mto_equ_local;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).tip_mov_rubro := wk_tip_mov_rubro;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_mod_padre := mv(i).cod_mod_padre;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_mad_padre := mv(i).cod_mad_padre;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_ofi_origen := mv(i).cod_ofi_origen;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cotizacion := v_cotizacion;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_moneda := mv(i).cod_moneda;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_tra_padre := mv(i).cod_tra_padre;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_modulo := mv(i).cod_modulo;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_modalidad := mv(i).cod_modalidad;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_transaccion := mv(i).cod_transaccion;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_oficina := mv(i).cod_oficina;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).nro_cuenta := mv(i).nro_cuenta;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).nro_documento := mv(i).nro_documento;
           
           v_lugar := 2;
           ---
           wk_cdctaco := LF_OBT_PARDINAMICO('COD_RUB_INTEROFICINA', v_ge_par_dinamicos,null,null,mv(i).cod_moneda,mv(i).cod_ofi_origen);
           wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(mv(i).cod_oficina,'000'))||substr(wk_cdctaco,14,2);
           if mv(i).tip_mov_rubro = 'D' then
              wk_tip_mov_rubro := 'C';
           else
              wk_tip_mov_rubro := 'D';
           end if;
           reg_type_ge_asi_tmp.EXTEND;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).fecha := mv(i).fecha;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_usuario := mv(i).cod_usuario;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).hora := mv(i).hora;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).nro_secuencia := mv(i).nro_secuencia;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_rubro := wk_cdctaco;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).monto := v_monto;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).mto_equ_local := v_mto_equ_local;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).tip_mov_rubro := mv(i).tip_mov_rubro;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_mod_padre := mv(i).cod_mod_padre;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_mad_padre := mv(i).cod_mad_padre;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_ofi_origen := mv(i).cod_ofi_origen;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cotizacion := v_cotizacion;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_moneda := mv(i).cod_moneda;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_tra_padre := mv(i).cod_tra_padre;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_modulo := mv(i).cod_modulo;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_modalidad := mv(i).cod_modalidad;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_transaccion := mv(i).cod_transaccion;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).cod_oficina := mv(i).cod_oficina;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).nro_cuenta := mv(i).nro_cuenta;
           reg_type_ge_asi_tmp(reg_type_ge_asi_tmp.COUNT).nro_documento := mv(i).nro_documento;
        END IF;

        v_lugar := 3;
        ---------------- FIN INTEROFICINA ------------------
    END LOOP; -- Fin del ciclo
  EXIT WHEN mov_contables%NOTFOUND;
  END LOOP;
  CLOSE mov_contables;
  
  IF v_act_paralelismo = 'S' THEN
    --cargar en procedimiento autonomo para evitar commit parcial en el proc. principal
    lp_ins_GE_MOV_CONTABLES_TMP(reg_type_ge_asi_tmp);
    BEGIN
       -- Eliminar la tarea y los bloques relacionados
       DBMS_PARALLEL_EXECUTE.DROP_TASK('ge_mov_contables_tmp');
    EXCEPTION
       WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
          NULL;
    END;
    -- Crear la tarea
    DBMS_PARALLEL_EXECUTE.create_task('ge_mov_contables_tmp');

    -- Dividir la tabla por ROWID en intervalos de 50000
    DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID('ge_mov_contables_tmp', 'IT', 'GE_MOV_CONTABLES_TMP', true, 50000);

    -- Ejecutar el DML en paralelo
    DBMS_PARALLEL_EXECUTE.run_task(task_name      => 'ge_mov_contables_tmp',
                                   sql_stmt       =>
q'[
      INSERT INTO GE_ASIENTOS_TMP (
         fecha, cod_usuario, hora,
         nro_secuencia, cod_rubro,
         monto, mto_equ_local, tip_mov_rubro,
         cod_mod_padre, cod_mad_padre,
         cod_ofi_origen, cotizacion, cod_moneda,
         observacion,
         cod_tra_padre, cod_modulo, cod_modalidad,
         cod_transaccion, cod_oficina, nro_cuenta,
         nro_documento)
      SELECT fecha, cod_usuario, hora,
             nro_secuencia, cod_rubro,
             monto, mto_equ_local, tip_mov_rubro,
             cod_mod_padre, cod_mad_padre,
             cod_ofi_origen, cotizacion, cod_moneda,
             observacion,
             cod_tra_padre, cod_modulo, cod_modalidad,
             cod_transaccion, cod_oficina, nro_cuenta,
             nro_documento
      FROM GE_MOV_CONTABLES_TMP
      WHERE ROWID BETWEEN :start_id AND :end_id
   ]',
                                   language_flag  => DBMS_SQL.NATIVE,
                                   parallel_level => v_niv_paralelismo);--nivel paralelismo
    --Verificar el estatus de la ejecucion
    IF DBMS_PARALLEL_EXECUTE.FINISHED != DBMS_PARALLEL_EXECUTE.TASK_STATUS('ge_mov_contables_tmp') THEN
      raise_application_error(-20000, 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ge_mov_contables_tmp');
    END IF;    
  ELSE
    BEGIN
      v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
      FORALL i IN INDICES OF reg_type_ge_asi_tmp
            insert into ge_asientos_tmp
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda,
               cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
               nro_documento)
             VALUES
              (reg_type_ge_asi_tmp(i).fecha, reg_type_ge_asi_tmp(i).cod_usuario, reg_type_ge_asi_tmp(i).hora, reg_type_ge_asi_tmp(i).nro_secuencia, reg_type_ge_asi_tmp(i).cod_rubro,
               reg_type_ge_asi_tmp(i).monto, reg_type_ge_asi_tmp(i).mto_equ_local, reg_type_ge_asi_tmp(i).tip_mov_rubro, reg_type_ge_asi_tmp(i).cod_mod_padre,
               reg_type_ge_asi_tmp(i).cod_mad_padre, reg_type_ge_asi_tmp(i).cod_oficina, reg_type_ge_asi_tmp(i).cotizacion, reg_type_ge_asi_tmp(i).cod_moneda,
               reg_type_ge_asi_tmp(i).cod_tra_padre, reg_type_ge_asi_tmp(i).cod_modulo, reg_type_ge_asi_tmp(i).cod_modalidad, reg_type_ge_asi_tmp(i).cod_transaccion,
               reg_type_ge_asi_tmp(i).cod_oficina, reg_type_ge_asi_tmp(i).nro_cuenta, reg_type_ge_asi_tmp(i).nro_documento);
    EXCEPTION
        WHEN OTHERS THEN
            v_hor_fin := to_char(sysdate,'hh24:mi:ss');
            prg_act_log_procesos('PRG_GEN_ASI_CIE_TMP','GE_ASIENTOS_TMP - MOV_CONTABLES', v_fecha, v_hor_inicio, v_hor_fin,'ERROR AL INSERTAR A GE_ASIENTOS_TMP - MOV_CONTABLES'||SQLERRM);                                             
            ROLLBACK;
    END;
  END IF;
exception
   when others then
       raise_application_error(-20000,'ERROR: en lp_pro_mov_contables '||sqlerrm);
end;  -- fin del procedimiento

-- Proc. que genera los asientos de acuerdo a las transacciones
PROCEDURE LP_PRO_MOV_X_TRANSACCIONES IS
v_cod_tip_asiento  ge_tip_asientos.cod_tip_asiento%type;
v_cod_tip_asiento2 ge_tip_asientos.cod_tip_asiento%type;
v_cod_moneda       ge_movimientos.cod_moneda%type;
v_cod_usuario      ge_movimientos.cod_usuario%type;
v_hora             ge_movimientos.hora%type;
v_nro_secuencia    ge_movimientos.nro_secuencia%type;
V_COD_MODULO       GE_MOVIMIENTOS.COD_MODULO%TYPE;
V_COD_MODALIDAD    GE_MOVIMIENTOS.COD_MODALIDAD%TYPE;
V_FECHA            GE_MOVIMIENTOS.FECHA%TYPE;
V_COD_MAD_PADRE    GE_MOVIMIENTOS.COD_MAD_PADRE%TYPE;
V_COD_TRANSACCION  GE_MOVIMIENTOS.COD_TRANSACCION%TYPE;
V_COD_OFI_ORIGEN   GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE;
V_AFECTA           GE_TRANSACCIONES.AFECTA%TYPE;
V_NOM_RUTINA1      VARCHAR2(1000);
V_DETALLE          GE_TRANSACCIONES.TIPO%TYPE;
V_HAY_ERROR        VARCHAR2(1);
V_ERR_CLIENTE      NUMBER(1);
V_RESIDENTE        GE_TIP_DEUDORES.IND_RESIDENTE%TYPE;
V_COD_SECTOR       GE_TIP_ASIENTOS.COD_SEC_CONTABLE%TYPE;
V_TIP_DEUDOR       GE_TIP_DEUDORES.COD_TIP_DEUDOR%TYPE;
V_COD_PLAZO        GE_PLZ_CONTABLES.COD_PLAZO%TYPE;
V_CAN_DIAS         GE_PLZ_CONTABLES.CAN_DIAS%TYPE;
V_COD_OFICINA      GE_MOVIMIENTOS.COD_OFICINA%TYPE;
V_NRO_CUENTA       GE_MOVIMIENTOS.NRO_CUENTA%TYPE;
V_MONTO            GE_MOVIMIENTOS.MONTO%TYPE;
V_MTO_EQU_LOCAL    GE_MOVIMIENTOS.MTO_EQU_LOCAL%TYPE;
V_FEC_VALOR        GE_MOVIMIENTOS.FEC_VALOR%TYPE;
V_COD_TRA_PADRE    GE_MOVIMIENTOS.COD_TRA_PADRE%TYPE;
V_REVERSADO        GE_MOVIMIENTOS.REVERSADO%TYPE;
V_COD_MOD_PADRE    GE_MOVIMIENTOS.COD_MOD_PADRE%TYPE;
v_cod_ref_cambio   ge_movimientos.cod_ref_cambio%type;
v_nro_documento2   ge_movimientos.nro_documento2%type;
v_cat_automatica   ge_movimientos.nro_documento2%type;
v_cod_pro_contable number(3);
v_est_cuenta       varchar2(1);
v_tip_cuenta       varchar2(1);
v_tip_interes      varchar2(1);
v_tip_renovacion   varchar2(1);
v_cod_sit_contable number(30);
v_sigue            char(1);
--Variables--
v_residente_aux    GE_TIP_DEUDORES.IND_RESIDENTE%TYPE;
v_cod_sector_aux   GE_TIP_ASIENTOS.COD_SEC_CONTABLE%TYPE;
v_tip_deudor_aux   GE_TIP_DEUDORES.COD_TIP_DEUDOR%TYPE;
v_cod_sit_contable_aux number(30);

cursor MOV_TRANSACCIONES IS
  select a.cod_modulo, a.cod_modalidad, a.cod_transaccion, a.cod_oficina, a.nro_cuenta,
         fecha, fec_valor, reversado,
         cod_mod_padre, cod_mad_padre, cod_tra_padre,
         a.cod_moneda, monto, cotizacion, mto_equ_local,
         cod_ofi_origen, cod_usuario, hora, nro_secuencia,
         cod_tip_asiento, a.cod_ref_cambio, a.nro_documento2,
         est_cuenta, mo.cod_pro_contable, cod_tip_asiento2,
         a.cod_sit_contable, nro_documento,
         ----
         x.RESIDENTE as residente_aux, x.COD_SEC_CONTABLE as cod_sector_aux, x.COD_TIP_DEUDOR as tip_deudor_aux,
         nvl(a.cod_sit_contable,z.COD_SIT_CONTABLE) as cod_sit_contable_aux
    from ge_modalidades MO, ge_transacciones b, ge_movimientos_ant a, GE_CLIENTES x, GE_CTA_CLIENTES y, GE_CUENTAS z
   where (monto <> 0 OR mto_equ_local <> 0)  
     and a.estado IN ('N','H')
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.tipo IN ('C','D') -- solo debitos o creditos
     and (a.reversado = 'N' or (a.reversado='S' and (fecha > fec_valor)))
     AND a.cod_tra_padre not in (565,950,317,306)
     and a.cod_transaccion not in (760,560,196)
     and (b.batch = 'B') -- especial
     AND a.COD_MODULO = MO.COD_MODULO
     AND a.COD_MODALIDAD = MO.COD_MODALIDAD
     and (b.cod_tip_asiento is not null or b.cod_tip_asiento2 is not null)
     and a.nro_cuenta is not null
     ----
     and z.NRO_CUENTA = a.nro_cuenta
     AND y.NRO_CUENTA  = a.nro_cuenta
     AND y.RELACION = 'P'
     AND x.COD_PERSONA = y.COD_PERSONA
  union
  select a.cod_modulo, a.cod_modalidad, a.cod_transaccion, cod_oficina, nro_cuenta,
         fecha, fec_valor, reversado,
         cod_mod_padre, cod_mad_padre, cod_tra_padre,
         cod_moneda, monto, cotizacion, mto_equ_local,
         cod_ofi_origen, cod_usuario, hora, nro_secuencia,
         cod_tip_asiento, a.cod_ref_cambio, a.nro_documento2,
         est_cuenta, mo.cod_pro_contable, cod_tip_asiento2,
         cod_sit_contable, nro_documento, null, null, null, null
    from ge_modalidades MO, ge_transacciones b, ge_movimientos_ant a
   where (monto <> 0 OR mto_equ_local <> 0)
     and estado IN ('N','H')
     and a.cod_modulo = b.cod_modulo
     and a.cod_modalidad = b.cod_modalidad
     and a.cod_transaccion = b.cod_transaccion
     and b.tipo IN ('C','D') -- solo debitos o creditos
     and (a.reversado = 'N' or (a.reversado='S' and (fecha > fec_valor)))
     AND a.cod_tra_padre not in (565,950,317,306)
     and a.cod_transaccion not in (760,560,196)
     and (b.batch = 'B') -- especial
     AND a.COD_MODULO = MO.COD_MODULO
     AND a.COD_MODALIDAD = MO.COD_MODALIDAD
     and (b.cod_tip_asiento is not null or b.cod_tip_asiento2 is not null)
     and a.nro_cuenta is null;
-- asientos por transaccion
r_tp GE_TIP_ASIENTOS%rowtype;
CURSOR c_tip_asientos IS
   SELECT *
     FROM GE_TIP_ASIENTOS
    WHERE COD_TIP_ASIENTO in (v_cod_tip_asiento, v_cod_tip_asiento2)
      AND COD_MONEDA = v_cod_moneda
      and (tip_renovacion is null or tip_renovacion = v_tip_renovacion)
      and (tip_interes is null or tip_interes = v_tip_interes)
      and (cod_sit_contable is null or cod_sit_contable = v_cod_sit_contable)
      and ((nvl(v_tip_cuenta, 'x') = 'B' and tip_cuenta = v_tip_cuenta) or
          (nvl(v_tip_cuenta, 'x') <> 'B' and (tip_cuenta is null or tip_cuenta = v_tip_cuenta)))
      AND (nvl(cat_automatica,v_cat_automatica) = v_cat_automatica or cat_automatica is null)
      and (nvl(est_cuenta,v_est_cuenta) = v_est_cuenta or
           est_cuenta is null and v_est_cuenta is null)
      AND (COD_SEC_CONTABLE = v_cod_sector or COD_SEC_CONTABLE IS NULL)
      AND (IND_RESIDENTE = v_residente OR IND_RESIDENTE = 'X');
v_nro_cta_anterior VARCHAR2(15) := 'x';
wk_can_debitos number(5) := 0;
wk_can_creditos number(5) := 0;
v_cod_sec_rubro varchar2(3);
v_cod_sub_modalidad ge_sub_modalidades.cod_sub_modalidad%type;
--tcasco
v_indice PLS_INTEGER := 0; -- Índice para cargar datos en la colección
v_observacion ge_asientos_tmp.observacion%type;
TYPE cursor1_type IS TABLE OF MOV_TRANSACCIONES%ROWTYPE;
reg_mov_transacciones cursor1_type;
TYPE cursor3_type IS TABLE OF ge_asientos_tmp%ROWTYPE;
reg_ge_asientos_tmp_type cursor3_type := cursor3_type(); -- Inicializar la colección
PROCEDURE lp_ins_GE_MOV_TRANSACCIONES_TMP(p_asientos_tmp in cursor3_type) is
  BEGIN
  -- Insert masivo usando FORALL con el índice cargado
     v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
     FORALL  i IN 1.. reg_ge_asientos_tmp_type.count
        INSERT INTO GE_MOV_TRANSACCIONES_TMP
            (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
             monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
             cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda, observacion,
             cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
             nro_documento
            )
        VALUES
            (p_asientos_tmp(i).fecha, p_asientos_tmp(i).cod_usuario, p_asientos_tmp(i).hora,
             p_asientos_tmp(i).nro_secuencia, p_asientos_tmp(i).cod_rubro,
             p_asientos_tmp(i).monto, p_asientos_tmp(i).mto_equ_local, p_asientos_tmp(i).tip_mov_rubro,
             p_asientos_tmp(i).cod_mod_padre, p_asientos_tmp(i).cod_mad_padre,
             p_asientos_tmp(i).cod_ofi_origen, p_asientos_tmp(i).cotizacion, p_asientos_tmp(i).cod_moneda,
             p_asientos_tmp(i).observacion,
             p_asientos_tmp(i).cod_tra_padre, p_asientos_tmp(i).cod_modulo, p_asientos_tmp(i).cod_modalidad,
             p_asientos_tmp(i).cod_transaccion, p_asientos_tmp(i).cod_oficina, p_asientos_tmp(i).nro_cuenta,
             p_asientos_tmp(i).nro_documento);
        
     COMMIT;
  EXCEPTION
      WHEN OTHERS THEN
          v_hor_fin := to_char(sysdate,'hh24:mi:ss');
          prg_act_log_procesos('PRG_GEN_ASI_CIE_TMP','GE_MOV_TRANSACCIONES_TMP - MOV_TRANSACCIONES', v_fecha, v_hor_inicio, v_hor_fin,'ERROR AL INSERTAR A GE_MOV_TRANSACCIONES_TMP - MOV_TRANSACCIONES'||SQLERRM);                               
          --ROLLBACK;
END lp_ins_GE_MOV_TRANSACCIONES_TMP;
begin
  --Limpiar la tabla auxiliar
  execute immediate('TRUNCATE TABLE GE_MOV_TRANSACCIONES_TMP');
  v_grabar := 0;
  v_hay_error := 'N';
  v_err_cliente := 0;
  -------------------------------------------
  OPEN MOV_TRANSACCIONES;
  LOOP
  FETCH MOV_TRANSACCIONES BULK COLLECT
   INTO reg_mov_transacciones LIMIT 500000 ;
  FOR i IN 1 .. reg_mov_transacciones.count LOOP
     wk_lgofici := 'N';
     wk_can_debitos := 0;
     wk_can_creditos := 0;
     v_cod_sit_contable := reg_mov_transacciones(i).cod_sit_contable;
     v_est_cuenta:= reg_mov_transacciones(i).est_cuenta;
     v_mto_equ_local := reg_mov_transacciones(i).mto_equ_local;
     v_monto := reg_mov_transacciones(i).monto;
     v_cod_tip_asiento := reg_mov_transacciones(i).cod_tip_asiento;
     v_cod_tip_asiento2 := reg_mov_transacciones(i).cod_tip_asiento2;
     v_cod_moneda := reg_mov_transacciones(i).cod_moneda;
     v_cotizacion := reg_mov_transacciones(i).cotizacion;

     IF reg_mov_transacciones(i).cod_oficina <> reg_mov_transacciones(i).cod_ofi_origen THEN
         -- ES ASIENTO INTEROFICINA
         wk_lgofici := 'S';
     END IF;
     -- veo si no tiene cotizacion para el movimiento------------------
     v_dato := '5.1'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
     IF v_cod_moneda <> v_cod_mon_local THEN
        IF v_mto_equ_local is null THEN
           if v_cod_moneda = v_cod_mon_fuerte then
              v_cotizacion := v_cot_usd;
           ELSIF v_cod_moneda = 'EUR' then
              v_cotizacion := v_val_cot_eur;
           else
              v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda);
           end if;
           v_redondeo_ml := 0;
           v_mto_equ_local := ROUND(NVL(v_monto,0)*NVL(v_cotizacion,0),v_redondeo_ml);
        END IF;
     ELSE
        -- si es moneda local, muevo el importe al equiv. en mon.local--
        v_mto_equ_local := v_monto;
        v_monto := 0;
     END IF;
     v_hay_error := 'N';
     -- si cambio la cuenta del cliente---------------------------------
      v_nro_cta_anterior := reg_mov_transacciones(i).nro_cuenta;
      --- asigno valores por defecto, por si exista cuenta cliente ---
      v_residente  := 'S';
      v_cod_sector := 'N';
      v_tip_deudor := '2';
      v_cod_plazo  := 0;
      --- Comun a todos los modulos-----------------------------------
      v_dato := '5.2'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
        BEGIN
            SELECT lower(rtrim(RUTINA1)), TIPO, AFECTA
              INTO v_nom_rutina1, v_detalle, v_afecta
              FROM GE_TRANSACCIONES
             WHERE COD_MODULO = reg_mov_transacciones(i).cod_modulo
               AND COD_MODALIDAD = reg_mov_transacciones(i).cod_modalidad
               AND COD_TRANSACCION = reg_mov_transacciones(i).cod_transaccion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_hay_error := 'S';
              raise_application_error(-20000,'Trans. no existe '||to_char(reg_mov_transacciones(i).cod_modulo)||' '
                                      ||to_char(reg_mov_transacciones(i).cod_modalidad)||' '||TO_CHAR(reg_mov_transacciones(i).cod_transaccion));
        END;
        v_err_cliente := 0;
        v_cod_sec_rubro := '';
        IF v_hay_error = 'N' THEN
          --- busco el cliente principal de la cuenta ------------------
          v_dato := '5.3'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
          IF reg_mov_transacciones(i).nro_cuenta IS NOT NULL THEN
             v_residente := reg_mov_transacciones(i).residente_aux;
             v_cod_sector := reg_mov_transacciones(i).cod_sector_aux;
             v_tip_deudor := reg_mov_transacciones(i).tip_deudor_aux;
             v_cod_sit_contable := reg_mov_transacciones(i).cod_sit_contable_aux;
             v_tip_cuenta := null;
               -- si no hubo error en la busqueda de la Clte Principal---
               IF v_err_cliente = 0 THEN
                  IF reg_mov_transacciones(i).cod_modalidad in  (32,37,38) THEN
                     --Busqueda del Plazo de la Cuentas plazo fijo y CDA.---
                     v_dato := '5.4'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
                     begin
                          SELECT FEC_VENCIMIENTO - FEC_APERTURA
                           INTO v_can_dias
                           FROM AH_CTA_PLAZOS
                          WHERE COD_MODULO = reg_mov_transacciones(i).cod_modulo
                            AND COD_MODALIDAD = reg_mov_transacciones(i).cod_modalidad
                            AND COD_OFICINA = reg_mov_transacciones(i).cod_oficina
                            AND NRO_CUENTA = reg_mov_transacciones(i).nro_cuenta;
                            lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                    exception
                       when no_data_found then
                            raise_application_error(-20000,'AH_CTA_PLAZOS: '||reg_mov_transacciones(i).nro_cuenta||' Modulo '||reg_mov_transacciones(i).cod_modulo||' Modal '||reg_mov_transacciones(i).cod_modalidad||' Ofi '||reg_mov_transacciones(i).cod_oficina);
                     end;
                  ELSIF reg_mov_transacciones(i).cod_modalidad in (33,34,36) THEN
                  v_dato := '5.5'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
                     begin
                         SELECT FEC_VENCIMIENTO - FEC_APERTURA
                           INTO v_can_dias
                           FROM AH_CTA_CERTIFICADOS
                          WHERE COD_MODULO = reg_mov_transacciones(i).cod_modulo
                            AND COD_MODALIDAD = reg_mov_transacciones(i).cod_modalidad
                            AND COD_OFICINA = reg_mov_transacciones(i).cod_oficina
                            AND NRO_CUENTA = reg_mov_transacciones(i).nro_cuenta;
                            lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                      exception
                       when no_data_found then
                            raise_application_error(-20000,'AH_CTA_CERTIFICADOS: '||reg_mov_transacciones(i).nro_cuenta||' Modulo '||reg_mov_transacciones(i).cod_modulo||' Modal '||reg_mov_transacciones(i).cod_modalidad||' Ofi '||reg_mov_transacciones(i).cod_oficina);
                     end;
                  ELSIF reg_mov_transacciones(i).cod_modalidad = 31 then
                  v_dato := '5.6'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
                    begin
                      SELECT cod_sub_modalidad
                        INTO v_cod_sub_modalidad
                        FROM ah_cta_vistas
                       WHERE COD_MODULO = reg_mov_transacciones(i).cod_modulo
                         AND COD_MODALIDAD = reg_mov_transacciones(i).cod_modalidad
                         AND COD_OFICINA = reg_mov_transacciones(i).cod_oficina
                         AND NRO_CUENTA = reg_mov_transacciones(i).nro_cuenta;
                    exception
                      when others then
                        v_cod_sub_modalidad := 1;
                    end;
                    begin
                      v_tip_cuenta := fue_obt_val_max_refcodes('TIP_CTA_SUB_MOD_CONTABLE',trim(reg_mov_transacciones(i).cod_modulo)||trim(reg_mov_transacciones(i).cod_modalidad)||trim(v_cod_sub_modalidad));
                    exception
                      when others then
                        v_tip_cuenta := null;
                    end;
                  ELSIF reg_mov_transacciones(i).cod_modulo = 6 THEN
                  v_dato := '5.7'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
                     BEGIN
                     SELECT FEC_VENCIMIENTO - FEC_INICIO,
                            tipo, tip_interes, nvl(tip_renovacion,'A'),
                            nvl(v_est_cuenta,estado), FUP_OBT_SEC_RUBRO(cod_sec_credito)
                      INTO v_can_dias, v_tip_cuenta, v_tip_interes,
                           v_tip_renovacion, v_est_cuenta, v_cod_sec_rubro
                      FROM PR_CTA_PRESTAMOS
                     WHERE NRO_CUENTA = reg_mov_transacciones(i).nro_cuenta
                       AND COD_MODULO = reg_mov_transacciones(i).cod_modulo
                       AND COD_MODALIDAD = reg_mov_transacciones(i).cod_modalidad
                       AND COD_OFICINA = reg_mov_transacciones(i).cod_oficina;
                       lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                     EXCEPTION
                        WHEN no_data_found then
                           RAISE_APPLICATION_ERROR(-20000,'nro_cuenta '||reg_mov_transacciones(i).nro_cuenta||' - '||sqlerrm);
                       END;
                  ELSIF reg_mov_transacciones(i).cod_modulo = 10 THEN
                  v_dato := '5.8'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
                     BEGIN
                     SELECT NVL(FEC_VENCIMIENTO - FEC_INICIO,0)
                      INTO v_can_dias
                      FROM MD_CTA_DOCUMENTOS
                     WHERE NRO_CUENTA = reg_mov_transacciones(i).nro_cuenta;
                       lp_obt_cod_plazo(v_can_dias,v_cod_plazo);
                     EXCEPTION
                        WHEN no_data_found then
                           RAISE_APPLICATION_ERROR(-20000,'nro_cuenta'||reg_mov_transacciones(i).nro_cuenta);
                       END;

                  END IF;
                  v_dato := '5.9'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
                  if reg_mov_transacciones(i).cod_modulo in (4,5,6) then
                     --- Verifico categoria
                      if v_cat_automatica is null then
                           v_cat_automatica := 1;
                      end if;
                     --end;
                     --- Recuperar categoria para valuaciones
                     if reg_mov_transacciones(i).cod_modulo = 6 and reg_mov_transacciones(i).cod_tra_padre = 150 then
                        if reg_mov_transacciones(i).nro_documento2 is not null then
                           --- El movimiento trae categoria
                           v_cat_automatica := reg_mov_transacciones(i).nro_documento2;
                        end if;
                     end if;
                  else
                     v_cat_automatica := null;
                  end if;
               END IF;
          END IF;
        END IF;
      v_dato := '5.10'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
      IF v_hay_error = 'N' and v_err_cliente = 0 then
          ------- ----------ciclo de ge_tip_asientos --------------
          IF c_tip_asientos%isopen then
             CLOSE c_tip_asientos;
          END IF;
          OPEN c_tip_asientos;
          v_sigue := 'N';
          LOOP   -- para cada registro de tipos de asientos
            FETCH c_tip_asientos INTO r_tp;
            v_tip_mov_rubro := r_tp.tip_movimiento;
            EXIT WHEN c_tip_asientos%notfound;
            ---Reemplaza el tipo de deudor -----------------------
            IF r_tp.IND_DEUDOR = 'S' THEN
              v_cod_rubro := SUBSTR(r_tp.COD_RUBRO,1,8)||
                            LTRIM(TO_CHAR(v_tip_deudor,'00'))||
                            SUBSTR(r_tp.COD_RUBRO,11,5);
            ELSE
              v_cod_rubro := r_tp.COD_RUBRO;
            END IF;
            ---Reemplaza el codigo del plazo-----------------------
            IF r_tp.IND_PLAZO = 'S' THEN
              v_cod_rubro := SUBSTR(v_cod_rubro,1,2)||
                            LTRIM(TO_CHAR(v_cod_plazo))||
                            SUBSTR(v_cod_rubro,4,12);
            END IF;
            ---Reemplaza el codigo del producto -----------------------
            IF r_tp.IND_PRODUCTO = 'S' THEN
              v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                             LTRIM(TO_CHAR(v_cod_pro_contable,'000'))||
                             SUBSTR(v_cod_rubro,14,2);
            END IF;
            IF substr(v_cod_rubro,11,3)  = 'SEC' THEN
               -- es solo para prestamos, para contabilizar por sector
               v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                             LTRIM(TO_CHAR(v_cod_sec_rubro,'000'))||
                             SUBSTR(v_cod_rubro,14,2);
            END IF;
           -------------------------------------------------
            IF v_sigue = 'S' THEN
             -- ya hubo otra linea interoficina
             if v_tip_movimiento <>  r_tp.TIP_MOVIMIENTO and r_tp.NRO_LINEA = 1 then
                v_sigue := 'N'; -- se apaga para que no genere interoficina
             end if;
            ELSE
             IF wk_lgofici = 'S' AND r_tp.NRO_LINEA = 1 THEN
                v_tip_movimiento := r_tp.TIP_MOVIMIENTO;
                x_tip_movimiento := r_tp.tip_movimiento; -- para el interoficina
                v_sigue    := 'S'; /* se hara interoficina */
             END IF;
            END IF;
            -----------------------------------------------------------
            --
            IF r_tp.NRO_LINEA = 1 THEN
               vh_cod_oficina := reg_mov_transacciones(i).cod_oficina;
            ELSE
               vh_cod_oficina := reg_mov_transacciones(i).cod_ofi_origen;
            END IF;
            --
            if v_tip_mov_rubro = 'D' then
               wk_can_debitos := wk_can_debitos +1;
            else
               wk_can_creditos := wk_can_creditos + 1;
            end if;
            
            v_indice := v_indice + 1;
            reg_ge_asientos_tmp_type.EXTEND;
            reg_ge_asientos_tmp_type(v_indice).fecha := reg_mov_transacciones(i).fecha;
            reg_ge_asientos_tmp_type(v_indice).cod_usuario := reg_mov_transacciones(i).cod_usuario;
            reg_ge_asientos_tmp_type(v_indice).hora := reg_mov_transacciones(i).hora;
            reg_ge_asientos_tmp_type(v_indice).nro_secuencia := reg_mov_transacciones(i).nro_secuencia;
            reg_ge_asientos_tmp_type(v_indice).cod_rubro := v_cod_rubro;
            reg_ge_asientos_tmp_type(v_indice).monto := v_monto;
            reg_ge_asientos_tmp_type(v_indice).mto_equ_local := v_mto_equ_local;
            reg_ge_asientos_tmp_type(v_indice).tip_mov_rubro := v_tip_mov_rubro;
            reg_ge_asientos_tmp_type(v_indice).cod_mod_padre := reg_mov_transacciones(i).cod_mod_padre;
            reg_ge_asientos_tmp_type(v_indice).cod_mad_padre := reg_mov_transacciones(i).cod_mad_padre;
            reg_ge_asientos_tmp_type(v_indice).cod_ofi_origen := vh_cod_oficina;
            reg_ge_asientos_tmp_type(v_indice).cotizacion := v_cotizacion;
            reg_ge_asientos_tmp_type(v_indice).cod_moneda := v_cod_moneda;
            reg_ge_asientos_tmp_type(v_indice).cod_tra_padre := reg_mov_transacciones(i).cod_tra_padre;
            reg_ge_asientos_tmp_type(v_indice).cod_modulo := reg_mov_transacciones(i).cod_modulo;
            reg_ge_asientos_tmp_type(v_indice).cod_modalidad := reg_mov_transacciones(i).cod_modalidad;
            reg_ge_asientos_tmp_type(v_indice).cod_transaccion := reg_mov_transacciones(i).cod_transaccion;
            reg_ge_asientos_tmp_type(v_indice).cod_oficina := reg_mov_transacciones(i).cod_oficina;
            reg_ge_asientos_tmp_type(v_indice).nro_cuenta := reg_mov_transacciones(i).nro_cuenta;
            reg_ge_asientos_tmp_type(v_indice).nro_documento := reg_mov_transacciones(i).nro_documento;
            -----------------------------------------------------------
          END LOOP;
            ---------------------------
            v_dato := '5.11'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_oficina;
            IF wk_lgofici = 'S' AND v_sigue = 'S' THEN
               -- tomo el tipo de movimiento de la linea 1
               v_tip_movimiento := x_tip_movimiento;
               -- Recuperar cuenta contable interoficina
               wk_cdctaco := lf_obt_pardinamico('COD_RUB_INTEROFICINA',v_ge_par_dinamicos,null,null,v_cod_moneda,reg_mov_transacciones(i).cod_oficina);
               -------------------------------------------------------------
               --- VER SI EL TIPO DE MOVIMIENTO ES DE DEBITO O CREDITO
               ------------------------------------------------------------
               IF v_tip_movimiento = 'D' THEN
                  v_tip_movimiento := 'C';
               ELSE
                  v_tip_movimiento := 'D';
               END IF;
               wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(reg_mov_transacciones(i).cod_ofi_origen,'000'))||substr(wk_cdctaco,14,2);
               
               v_indice := v_indice + 1;
               reg_ge_asientos_tmp_type.EXTEND;
               reg_ge_asientos_tmp_type(v_indice).fecha := reg_mov_transacciones(i).fecha;
               reg_ge_asientos_tmp_type(v_indice).cod_usuario := reg_mov_transacciones(i).cod_usuario;
               reg_ge_asientos_tmp_type(v_indice).hora := reg_mov_transacciones(i).hora;
               reg_ge_asientos_tmp_type(v_indice).nro_secuencia := reg_mov_transacciones(i).nro_secuencia;
               reg_ge_asientos_tmp_type(v_indice).cod_rubro := wk_cdctaco;
               reg_ge_asientos_tmp_type(v_indice).monto := v_monto;
               reg_ge_asientos_tmp_type(v_indice).mto_equ_local := v_mto_equ_local;
               reg_ge_asientos_tmp_type(v_indice).tip_mov_rubro := v_tip_movimiento;
               reg_ge_asientos_tmp_type(v_indice).cod_mod_padre := reg_mov_transacciones(i).cod_mod_padre;
               reg_ge_asientos_tmp_type(v_indice).cod_mad_padre := reg_mov_transacciones(i).cod_mad_padre;
               reg_ge_asientos_tmp_type(v_indice).cod_ofi_origen := reg_mov_transacciones(i).cod_oficina;
               reg_ge_asientos_tmp_type(v_indice).cotizacion := v_cotizacion;
               reg_ge_asientos_tmp_type(v_indice).cod_moneda := v_cod_moneda;
               reg_ge_asientos_tmp_type(v_indice).cod_tra_padre := reg_mov_transacciones(i).cod_tra_padre;
               reg_ge_asientos_tmp_type(v_indice).cod_modulo := reg_mov_transacciones(i).cod_modulo;
               reg_ge_asientos_tmp_type(v_indice).cod_modalidad := reg_mov_transacciones(i).cod_modalidad;
               reg_ge_asientos_tmp_type(v_indice).cod_transaccion := reg_mov_transacciones(i).cod_transaccion;
               reg_ge_asientos_tmp_type(v_indice).cod_oficina := reg_mov_transacciones(i).cod_oficina;
               reg_ge_asientos_tmp_type(v_indice).nro_cuenta := reg_mov_transacciones(i).nro_cuenta;
               reg_ge_asientos_tmp_type(v_indice).nro_documento := reg_mov_transacciones(i).nro_documento;
               -- Recuperar cuenta contable interoficina
               v_dato := '5.12'||'-'||reg_mov_transacciones(i).nro_cuenta||'-'||reg_mov_transacciones(i).cod_modulo||'-'||reg_mov_transacciones(i).cod_modalidad||'-'|| reg_mov_transacciones(i).cod_transaccion ||'-'||reg_mov_transacciones(i).cod_ofi_origen;
               wk_cdctaco := lf_obt_pardinamico('COD_RUB_INTEROFICINA',v_ge_par_dinamicos,null,null,v_cod_moneda,reg_mov_transacciones(i).cod_ofi_origen);
               wk_cdctaco := substr(wk_cdctaco,1,10)||ltrim(to_char(reg_mov_transacciones(i).cod_oficina,'000'))||substr(wk_cdctaco,14,2);

               v_indice := v_indice + 1;
               reg_ge_asientos_tmp_type.EXTEND;
               reg_ge_asientos_tmp_type(v_indice).fecha := reg_mov_transacciones(i).fecha;
               reg_ge_asientos_tmp_type(v_indice).cod_usuario := reg_mov_transacciones(i).cod_usuario;
               reg_ge_asientos_tmp_type(v_indice).hora := reg_mov_transacciones(i).hora;
               reg_ge_asientos_tmp_type(v_indice).nro_secuencia := reg_mov_transacciones(i).nro_secuencia;
               reg_ge_asientos_tmp_type(v_indice).cod_rubro := wk_cdctaco;
               reg_ge_asientos_tmp_type(v_indice).monto := v_monto;
               reg_ge_asientos_tmp_type(v_indice).mto_equ_local := v_mto_equ_local;
               reg_ge_asientos_tmp_type(v_indice).tip_mov_rubro := x_tip_movimiento;
               reg_ge_asientos_tmp_type(v_indice).cod_mod_padre := reg_mov_transacciones(i).cod_mod_padre;
               reg_ge_asientos_tmp_type(v_indice).cod_mad_padre := reg_mov_transacciones(i).cod_mad_padre;
               reg_ge_asientos_tmp_type(v_indice).cod_ofi_origen := reg_mov_transacciones(i).cod_ofi_origen;
               reg_ge_asientos_tmp_type(v_indice).cotizacion := v_cotizacion;
               reg_ge_asientos_tmp_type(v_indice).cod_moneda := v_cod_moneda;
               reg_ge_asientos_tmp_type(v_indice).cod_tra_padre := reg_mov_transacciones(i).cod_tra_padre;
               reg_ge_asientos_tmp_type(v_indice).cod_modulo := reg_mov_transacciones(i).cod_modulo;
               reg_ge_asientos_tmp_type(v_indice).cod_modalidad := reg_mov_transacciones(i).cod_modalidad;
               reg_ge_asientos_tmp_type(v_indice).cod_transaccion := reg_mov_transacciones(i).cod_transaccion;
               reg_ge_asientos_tmp_type(v_indice).cod_oficina := reg_mov_transacciones(i).cod_ofi_origen;
               reg_ge_asientos_tmp_type(v_indice).nro_cuenta := reg_mov_transacciones(i).nro_cuenta;
               reg_ge_asientos_tmp_type(v_indice).nro_documento := reg_mov_transacciones(i).nro_documento;
            END IF;
            ---------------- FIN INTEROFICINA ------------------
          IF c_tip_asientos%ROWCOUNT = 0 THEN
            -- no existe asiento definido para la transaccion --
           IF (reg_mov_transacciones(i).cod_modalidad <> 455 ) AND
               (v_cod_tip_asiento  NOT IN (124,111,535) OR
               v_cod_moneda <> v_cod_mon_local) THEN
               v_observacion := substr('No existe Asiento.p/: Asi='||to_char(v_cod_tip_asiento)||
                                                                       ' Mon='||v_cod_moneda||' Sec='||v_cod_sector||' Res='||v_residente||
                                                                       ' Deu='||to_char(v_tip_deudor)||
                                                                       ' Cta='||reg_mov_transacciones(i).nro_cuenta||' Tranp='||to_char(reg_mov_transacciones(i).cod_tra_padre)||
                                                                       ' Trans='||to_char(reg_mov_transacciones(i).cod_modalidad)||'-'||
                                                                       to_char(reg_mov_transacciones(i).cod_transaccion)||' Usu='||reg_mov_transacciones(i).cod_usuario||' Hor='||reg_mov_transacciones(i).hora
                                                                       || ' Sit='||pab_asi.fu_obt_des_sit_contable(v_cod_sit_contable)||
                                                                       ' Est='||v_est_cuenta,1,1000);
               v_indice := v_indice + 1;
               reg_ge_asientos_tmp_type.EXTEND;
               reg_ge_asientos_tmp_type(v_indice).fecha := reg_mov_transacciones(i).fecha;
               reg_ge_asientos_tmp_type(v_indice).cod_usuario := reg_mov_transacciones(i).cod_usuario;
               reg_ge_asientos_tmp_type(v_indice).hora := reg_mov_transacciones(i).hora;
               reg_ge_asientos_tmp_type(v_indice).nro_secuencia := reg_mov_transacciones(i).nro_secuencia;
               reg_ge_asientos_tmp_type(v_indice).cod_rubro := NULL;
               reg_ge_asientos_tmp_type(v_indice).monto := v_monto;
               reg_ge_asientos_tmp_type(v_indice).mto_equ_local := v_mto_equ_local;
               reg_ge_asientos_tmp_type(v_indice).tip_mov_rubro := NULL;
               reg_ge_asientos_tmp_type(v_indice).cod_mod_padre := reg_mov_transacciones(i).cod_mod_padre;
               reg_ge_asientos_tmp_type(v_indice).cod_mad_padre := reg_mov_transacciones(i).cod_mad_padre;
               reg_ge_asientos_tmp_type(v_indice).cod_ofi_origen := reg_mov_transacciones(i).cod_oficina;
               reg_ge_asientos_tmp_type(v_indice).cotizacion := v_cotizacion;
               reg_ge_asientos_tmp_type(v_indice).cod_moneda := v_cod_moneda;
               reg_ge_asientos_tmp_type(v_indice).observacion := v_observacion;
               reg_ge_asientos_tmp_type(v_indice).cod_tra_padre := reg_mov_transacciones(i).cod_tra_padre;
               reg_ge_asientos_tmp_type(v_indice).cod_modulo := reg_mov_transacciones(i).cod_modulo;
               reg_ge_asientos_tmp_type(v_indice).cod_modalidad := reg_mov_transacciones(i).cod_modalidad;
               reg_ge_asientos_tmp_type(v_indice).cod_transaccion := reg_mov_transacciones(i).cod_transaccion;
               reg_ge_asientos_tmp_type(v_indice).cod_oficina := reg_mov_transacciones(i).cod_oficina;
               reg_ge_asientos_tmp_type(v_indice).nro_cuenta := reg_mov_transacciones(i).nro_cuenta;
               reg_ge_asientos_tmp_type(v_indice).nro_documento := reg_mov_transacciones(i).nro_documento;
            END IF;
          END IF;
          IF c_tip_asientos%ISOPEN THEN
             CLOSE c_tip_asientos;
          END IF;
          
       end if;
  END LOOP;
     EXIT WHEN MOV_TRANSACCIONES%NOTFOUND;
  END LOOP;
  CLOSE MOV_TRANSACCIONES;
  
  IF v_act_paralelismo = 'S' THEN
    --cargar en procedimiento autonomo para evitar commit parcial en el proc. principal
    lp_ins_GE_MOV_TRANSACCIONES_TMP(reg_ge_asientos_tmp_type);
    BEGIN
       -- Eliminar la tarea y los bloques relacionados
       DBMS_PARALLEL_EXECUTE.DROP_TASK('ge_mov_transacciones_tmp');
    EXCEPTION
       WHEN DBMS_PARALLEL_EXECUTE.TASK_NOT_FOUND THEN
          NULL;
    END;
    -- Crear la tarea
    DBMS_PARALLEL_EXECUTE.create_task('ge_mov_transacciones_tmp');

    -- Dividir la tabla por ROWID en intervalos de 50000
    DBMS_PARALLEL_EXECUTE.CREATE_CHUNKS_BY_ROWID('ge_mov_transacciones_tmp', 'IT', 'GE_MOV_TRANSACCIONES_TMP', true, 50000);

    -- Ejecutar el DML en paralelo
    DBMS_PARALLEL_EXECUTE.run_task(task_name      => 'ge_mov_transacciones_tmp',
                                   sql_stmt       =>
q'[
      INSERT INTO GE_ASIENTOS_TMP (
         fecha, cod_usuario, hora,
         nro_secuencia, cod_rubro,
         monto, mto_equ_local, tip_mov_rubro,
         cod_mod_padre, cod_mad_padre,
         cod_ofi_origen, cotizacion, cod_moneda,
         observacion,
         cod_tra_padre, cod_modulo, cod_modalidad,
         cod_transaccion, cod_oficina, nro_cuenta,
         nro_documento)
      SELECT fecha, cod_usuario, hora,
             nro_secuencia, cod_rubro,
             monto, mto_equ_local, tip_mov_rubro,
             cod_mod_padre, cod_mad_padre,
             cod_ofi_origen, cotizacion, cod_moneda,
             observacion,
             cod_tra_padre, cod_modulo, cod_modalidad,
             cod_transaccion, cod_oficina, nro_cuenta,
             nro_documento
      FROM GE_MOV_TRANSACCIONES_TMP
      WHERE ROWID BETWEEN :start_id AND :end_id
   ]',
                                   language_flag  => DBMS_SQL.NATIVE,
                                   parallel_level => v_niv_paralelismo);--nivel paralelismo
    --Verificar el estatus de la ejecucion
    IF DBMS_PARALLEL_EXECUTE.FINISHED != DBMS_PARALLEL_EXECUTE.TASK_STATUS('ge_mov_transacciones_tmp') THEN
      raise_application_error(-20000, 'ERROR DBMS_PARALLEL_EXECUTE. Revisar Tarea: ge_mov_transacciones_tmp');
    END IF;
  ELSE
    BEGIN
    -- Insert masivo usando FORALL con el índice cargado 
       v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
       FORALL  i IN 1.. reg_ge_asientos_tmp_type.count
          INSERT INTO GE_ASIENTOS_TMP
              (fecha, cod_usuario, hora, nro_secuencia, cod_rubro,
               monto, mto_equ_local, tip_mov_rubro, cod_mod_padre,
               cod_mad_padre, cod_ofi_origen, cotizacion, cod_moneda, observacion,
               cod_tra_padre, cod_modulo, cod_modalidad, cod_transaccion, cod_oficina, nro_cuenta,
               nro_documento
              )
          VALUES
              (reg_ge_asientos_tmp_type(i).fecha, reg_ge_asientos_tmp_type(i).cod_usuario, reg_ge_asientos_tmp_type(i).hora,
               reg_ge_asientos_tmp_type(i).nro_secuencia, reg_ge_asientos_tmp_type(i).cod_rubro,
               reg_ge_asientos_tmp_type(i).monto, reg_ge_asientos_tmp_type(i).mto_equ_local, reg_ge_asientos_tmp_type(i).tip_mov_rubro,
               reg_ge_asientos_tmp_type(i).cod_mod_padre, reg_ge_asientos_tmp_type(i).cod_mad_padre,
               reg_ge_asientos_tmp_type(i).cod_ofi_origen, reg_ge_asientos_tmp_type(i).cotizacion, reg_ge_asientos_tmp_type(i).cod_moneda,
               reg_ge_asientos_tmp_type(i).observacion,
               reg_ge_asientos_tmp_type(i).cod_tra_padre, reg_ge_asientos_tmp_type(i).cod_modulo, reg_ge_asientos_tmp_type(i).cod_modalidad,
               reg_ge_asientos_tmp_type(i).cod_transaccion, reg_ge_asientos_tmp_type(i).cod_oficina, reg_ge_asientos_tmp_type(i).nro_cuenta,
               reg_ge_asientos_tmp_type(i).nro_documento);
    EXCEPTION
        WHEN OTHERS THEN
            v_hor_fin := to_char(sysdate,'hh24:mi:ss');
            prg_act_log_procesos('PRG_GEN_ASI_CIE_TMP','GE_ASIENTOS_TMP - MOV_TRANSACCIONES', v_fecha, v_hor_inicio, v_hor_fin,'ERROR AL INSERTAR A GE_ASIENTOS_TMP - MOV_TRANSACCIONES'||SQLERRM);            
            ROLLBACK;
    END;
  END IF;
exception
   when others then
      raise_application_error(-20000,'ERROR: PRG_GEN_ASIENTOS_TMP '||SQLERRM || ' ' || v_lugar|| ' ' ||v_dato);
end;

PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
-- inicio del proceso principal
begin
  --Cargar la coleccion ge_par_dinamicos
  SELECT typ_ge_par_dinamicos(
         parametro,
         cod_modulo,
         cod_modalidad,
         cod_moneda,
         cod_oficina,
         cod_sub_modalidad,
         val_parametro
      )
  BULK COLLECT INTO v_ge_par_dinamicos
  FROM ge_par_dinamicos
  WHERE parametro IN ('COD_RUB_INTEROFICINA')
  ORDER BY decode(cod_modulo, NULL, 0, 1) +
           decode(cod_modalidad, NULL, 0, 1) +
           decode(cod_sub_modalidad, NULL, 0, 1) +
           decode(cod_oficina, NULL, 0, 1) +
           decode(cod_moneda, NULL, 0, 1) DESC;
  
  v_fecha := pag_cal.fu_obt_fec_anterior(1);
  v_cod_mon_fuerte := pag_gen.FU_OBT_MON_FUERTE;
  v_cot_usd := pag_gen.fu_obt_cotizacion(v_cod_mon_fuerte);
  v_val_cot_eur := pag_gen.fu_obt_cotizacion('EUR');
  -- borro los asientos generados anteriormente
  sql_util.ejecute_dml('TRUNCATE TABLE GE_ASIENTOS_TMP', v_msj);

  v_lugar := 2;
  if v_msj is not null then
      raise_application_error(-20000, v_msj);
  end if;

  v_lugar := 4;
  -- procesa los movimientos contables directos
  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  lp_pro_mov_contables;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('PRG_GEN_ASI_CIE_TMP','lp_pro_mov_contables', v_fecha, v_hor_inicio, v_hor_fin);

  v_lugar := 5;
  -- procesa los movimientos contables por transacciones
  v_hor_inicio := to_char(sysdate,'hh24:mi:ss');
  lp_pro_mov_x_transacciones;
  v_hor_fin := to_char(sysdate,'hh24:mi:ss');
  prg_act_log_procesos('PRG_GEN_ASI_CIE_TMP','lp_pro_mov_x_transacciones', v_fecha, v_hor_inicio, v_hor_fin);
  v_lugar := 6;
  commit;
end PRG_GEN_ASI_CIE_TMP;
/
