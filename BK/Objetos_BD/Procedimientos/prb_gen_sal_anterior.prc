CREATE OR REPLACE PROCEDURE IT.PRB_GEN_SAL_ANTERIOR IS
  /* transfiere los saldos actuales a saldos de ayer */
  v_cod_oficina    ba_oficinas.cod_oficina%type;
  v_des_oficina    ba_oficinas.descripcion%type;
  v_fec_actual     ge_calendarios.fec_actual%type         := pag_cal.fu_obt_fec_actual(2);
  v_ano_actual     cb_sal_promedios.ano%type              := to_char(v_fec_actual,'yyyy');
  v_mes_actual     cb_sal_promedios.mes%type              := to_char(v_fec_actual,'mm');
  v_cod_mon_fuerte ge_par_generales.cod_mon_fuerte%type   := pag_gen.FU_OBT_MON_FUERTE;
  v_cot_mon_fuerte ge_cotizaciones.val_conversion%type    := pag_gen.FU_OBT_COTIZACION(v_cod_mon_fuerte,v_fec_actual);
  -- 
  -- Requerimiento: CNFGHDBS-5.
  -- Fecha: 27/08/2015.
  v_fec_historico  ge_calendarios.fec_actual%type;
  v_can_dias_his   NUMBER := fug_obt_pardinamico('CBT_CAN_DIA_ACU_PROMEDIOS_HIS');
  v_existe         NUMBER := 0;
  --------------------------------------------------------------------
  CURSOR c_oficinas is
    SELECT DISTINCT B.COD_OFICINA, B.DESCRIPCION
      FROM CB_SAL_OFICINAS A, BA_OFICINAS B
     WHERE A.COD_OFICINA = B.COD_OFICINA
       AND A.ANO = v_ano_actual
       AND A.MES = v_mes_actual;
  --------------------------------------------------------------------
  CURSOR c_sal_rubros is
     SELECT COD_RUBRO,
            NVL(SAL_MON_LOC_ANT,0) + NVL(DEB_MON_LOCAL,0) - NVL(CRE_MON_LOCAL,0),
            NVL(DEB_MON_LOCAL,0),NVL(DEB_MON_RUBRO,0),
            NVL(CRE_MON_LOCAL,0),NVL(CRE_MON_RUBRO,0),
            NVL(SAL_MON_RUB_ANT,0) + NVL(DEB_MON_RUBRO,0) - NVL(CRE_MON_RUBRO,0),
            NVL(SAL_EQU_LOC_ANT,0) + NVL(DEB_EQU_LOCAL,0) - NVL(CRE_EQU_LOCAL,0),
            NVL(DEB_EQU_LOCAL,0),NVL(CRE_EQU_LOCAL,0)
     FROM   CB_SAL_OFICINAS
     WHERE  COD_OFICINA = v_cod_oficina
     AND    ANO = v_ano_actual
     AND    MES = v_mes_actual
     FOR UPDATE OF COD_RUBRO;
  --------------------------------------------------------------------
  v_sal_mon_local      cb_sal_promedios.tot_acu_mon_local%type;
  v_sal_equ_local      cb_sal_promedios.tot_acu_mon_local%type;
  v_sal_deu_equ_loc    cb_sal_promedios.tot_acu_mon_local%type;
  v_sal_acr_equ_loc    cb_sal_promedios.tot_acu_mon_local%type;
  v_sal_mon_rubro      cb_sal_promedios.tot_acumulado%type;
  v_sal_deu_mon_loc    cb_sal_promedios.tot_acu_mon_local%type;
  v_sal_acr_mon_loc    cb_sal_promedios.tot_acu_mon_local%type;
  v_sal_deu_mon_rub    cb_sal_promedios.tot_acumulado%type;
  v_sal_acr_mon_rub    cb_sal_promedios.tot_acumulado%type;
  v_cod_rubro          cb_rubros.cod_rubro%type;
  v_fec_anterior       ge_calendarios.fec_actual%type;
  v_ano_anterior       cb_sal_promedios.ano%type;
  v_mes_anterior       cb_sal_promedios.mes%type;
  v_dif_dias           NUMBER;
  v_dif_dias_2         NUMBER;
  v_cod_moneda         ba_monedas.cod_moneda%type;
  v_dia_mes            cb_sal_promedios.can_dia_acumulado%type;
  v_lugar              varchar2(50);
  v_error 	       varchar2(4000);
  --------------------------------------------------------------------
  FUNCTION lf_obt_mon_rubro(p_cod_rubro in varchar2)
    return varchar2 is
  v_retorno varchar2(5);
  BEGIN
     SELECT COD_MONEDA
       INTO v_retorno
       FROM CB_RUBROS
      WHERE COD_RUBRO = p_cod_rubro;
     return v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20000,'Error al leer moneda del Rubro '||sqlerrm);
  END;
BEGIN
 -- Cargar fechas calendario -----------------------------------
 pag_cal.PR_OBT_DAT_CALENDAR(2);
 -- las fechas utiles del calendario ---------------------------
 v_fec_anterior := pag_cal.G_FEC_ANTERIOR;
 --v_fec_proxima  := pag_cal.G_FEC_PROXIMA;
 --------------------------------------------------------------
 v_mes_anterior := TO_CHAR(v_fec_anterior, 'MM');
 v_ano_anterior := TO_CHAR(v_fec_anterior, 'YYYY');
 v_mes_actual   := TO_CHAR(v_fec_actual, 'MM');
 v_ano_actual   := TO_CHAR(v_fec_actual, 'YYYY');
 --RAMG: marcado porque no se usa
 --wmes_fcprx := TO_CHAR(v_fec_proxima, 'MM');
 --wani_fcprx := TO_CHAR(v_fec_proxima, 'YYYY');
 --w_dias     := v_fec_actual - v_fec_anterior;
 --------------------------------------------------------------
 IF v_mes_anterior <> v_mes_actual THEN
    v_dif_dias := (LAST_DAY(v_fec_anterior) + 1) - v_fec_anterior;
    v_dif_dias_2 := TO_NUMBER(TO_CHAR(v_fec_actual,'DD'))-1;
 ELSE
    v_dif_dias := v_fec_actual - v_fec_anterior;
    v_dif_dias_2 := 0;
 END IF;
 ------------------------------------------------------------------
 IF C_OFICINAS%ISOPEN THEN
    CLOSE C_OFICINAS;
 END IF;
 OPEN C_OFICINAS;
 LOOP
   FETCH C_OFICINAS INTO v_cod_oficina, v_des_oficina;
   EXIT WHEN C_OFICINAS%notfound;
   ---- proceso de los saldos de las cuentas de la oficina actual ----
   BEGIN
     IF C_SAL_RUBROS%isopen THEN
        CLOSE C_SAL_RUBROS;
     END IF;
     OPEN C_SAL_RUBROS;
     LOOP

        FETCH c_sal_rubros INTO v_cod_rubro, v_sal_mon_local, v_sal_deu_mon_loc, v_sal_deu_mon_rub,
                               v_sal_acr_mon_loc, v_sal_acr_mon_rub, v_sal_mon_rubro,
                               v_sal_equ_local, v_sal_deu_equ_loc, v_sal_acr_equ_loc;
        EXIT WHEN c_sal_rubros%notfound;
        --- MODIFICA SALDOS PROMEDIOS DEL MES DE LA FECHA ANTERIOR ----
        BEGIN
          v_lugar := 'UPDATE 1';
        UPDATE CB_SAL_PROMEDIOS
           SET TOT_ACU_MON_LOCAL = NVL(TOT_ACU_MON_LOCAL,0) + v_sal_mon_local * v_dif_dias,
               TOT_ACUMULADO = NVL(TOT_ACUMULADO,0) + v_sal_mon_rubro * v_dif_dias,
               CAN_DIA_ACUMULADO = NVL(CAN_DIA_ACUMULADO,0) + v_dif_dias,
               TOT_ACU_MON_FUERTE = NVL(TOT_ACU_MON_FUERTE,0) +
                            ((v_sal_mon_local * v_dif_dias)/v_cot_mon_fuerte),
               TOT_ACU_DEB_MON_LOCAL = NVL(TOT_ACU_DEB_MON_LOCAL,0) + v_sal_deu_mon_loc,
               TOT_ACU_CRE_MON_LOCAL = NVL(TOT_ACU_CRE_MON_LOCAL,0) + v_sal_acr_mon_loc,
               TOT_ACU_DEBITOS = NVL(TOT_ACU_DEBITOS,0) + v_sal_deu_mon_rub,
               TOT_ACU_CREDITOS = NVL(TOT_ACU_CREDITOS,0) + v_sal_acr_mon_rub,
               TOT_ACU_EQU_LOCAL = NVL(TOT_ACU_EQU_LOCAL,0) + v_sal_equ_local * v_dif_dias,
               TOT_ACU_DEB_EQU_LOC = NVL(TOT_ACU_DEB_EQU_LOC,0) + v_sal_deu_equ_loc,
               TOT_ACU_CRE_EQU_LOC = NVL(TOT_ACU_CRE_EQU_LOC,0) + v_sal_acr_equ_loc
         WHERE COD_OFICINA = v_cod_oficina
           AND COD_RUBRO = v_cod_rubro
           AND ANO = v_ano_anterior
           AND MES = v_mes_anterior;
        ------------------------------------------------------------
        -- si no encontro genera un nuevo registro para la cuenta --
        ------------------------------------------------------------
        IF SQL%NOTFOUND THEN
           v_cod_moneda := lf_obt_mon_rubro(v_cod_rubro);
           v_lugar := 'INSERT 1';
           INSERT INTO CB_SAL_PROMEDIOS
               (COD_OFICINA, COD_RUBRO, ANO, MES,
                COD_MONEDA, TOT_ACU_MON_LOCAL, TOT_ACUMULADO, CAN_DIA_ACUMULADO,
                TOT_ACU_MON_FUERTE, TOT_ACU_DEB_MON_LOCAL, TOT_ACU_CRE_MON_LOCAL, TOT_ACU_DEBITOS,
                TOT_ACU_CREDITOS,TOT_ACU_EQU_LOCAL,TOT_ACU_DEB_EQU_LOC,TOT_ACU_CRE_EQU_LOC)
           VALUES
               (v_cod_oficina, v_cod_rubro, v_ano_anterior, v_mes_anterior,
                v_cod_moneda, v_sal_mon_local * v_dif_dias, v_sal_mon_rubro * v_dif_dias,
                v_dif_dias, (v_sal_mon_local * v_dif_dias)/v_cot_mon_fuerte,
                v_sal_deu_mon_loc,v_sal_acr_mon_loc,v_sal_deu_mon_rub,v_sal_acr_mon_rub,
                v_sal_equ_local, v_sal_deu_equ_loc, v_sal_acr_equ_loc);
        END IF;
        EXCEPTION 
          WHEN OTHERS THEN
	    v_error := substr(sqlerrm,1,4000);
            PRG_INS_LOG_ERRORES('PRB_GEN_SAL_ANTERIOR',v_error,'Oficina',v_cod_oficina,'Rubro',v_cod_rubro,'Lugar',v_lugar);
        END;
        IF v_dif_dias_2 <> 0 THEN
           ------------------------------------------------
           -- agrega registro del nuevo mes              --
           ------------------------------------------------
           v_cod_moneda := lf_obt_mon_rubro(v_cod_rubro);
           v_lugar := 'INSERT 2';
           begin
           INSERT INTO CB_SAL_PROMEDIOS
               (COD_OFICINA, COD_RUBRO, ANO, MES,
                COD_MONEDA, TOT_ACU_MON_LOCAL, TOT_ACUMULADO, CAN_DIA_ACUMULADO,
                TOT_ACU_MON_FUERTE, TOT_ACU_DEB_MON_LOCAL, TOT_ACU_CRE_MON_LOCAL, TOT_ACU_DEBITOS,
                TOT_ACU_CREDITOS,TOT_ACU_EQU_LOCAL,TOT_ACU_DEB_EQU_LOC,TOT_ACU_CRE_EQU_LOC)
           VALUES
               (v_cod_oficina, v_cod_rubro, v_ano_actual, v_mes_actual,
                v_cod_moneda, v_sal_mon_local *v_dif_dias_2, v_sal_mon_rubro *v_dif_dias_2,
                v_dif_dias_2, (v_sal_mon_local *v_dif_dias_2)/v_cot_mon_fuerte,
                v_sal_deu_mon_loc,v_sal_acr_mon_loc,v_sal_deu_mon_rub,v_sal_acr_mon_rub,
                v_sal_equ_local, v_sal_deu_equ_loc, v_sal_acr_equ_loc);
           EXCEPTION 
          WHEN OTHERS THEN
            v_error := substr(sqlerrm,1,4000);
            PRG_INS_LOG_ERRORES('PRB_GEN_SAL_ANTERIOR',v_error,'Oficina',v_cod_oficina,'Rubro',v_cod_rubro,'Lugar',v_lugar);
          END;
        END IF;
        ---------- MODIFICA SALDOS POR OFICINA -----------
        v_lugar:='UPDATE 2';
        begin
        UPDATE CB_SAL_OFICINAS
          SET SAL_MON_LOC_ANT = v_sal_mon_local,
              DEB_MON_LOCAL = 0,
              CRE_MON_LOCAL = 0,
              SAL_MON_RUB_ANT = v_sal_mon_rubro,
              DEB_MON_RUBRO = 0,
              CRE_MON_RUBRO = 0,
              SAL_EQU_LOC_ANT = v_sal_equ_local,
              DEB_EQU_LOCAL = 0,
              CRE_EQU_LOCAL = 0
        WHERE CURRENT OF C_SAL_RUBROS;
         EXCEPTION 
          WHEN OTHERS THEN
            v_error := substr(sqlerrm,1,4000);
            PRG_INS_LOG_ERRORES('PRB_GEN_SAL_ANTERIOR',v_error,'Oficina',v_cod_oficina,'Rubro',v_cod_rubro,'Lugar',v_lugar);
        END;
     END LOOP;
     IF C_SAL_RUBROS%ROWCOUNT = 0 THEN
        CLOSE C_SAL_RUBROS;
        raise_application_error(-20000,' ERROR. No se encontraron registros del mes ' ||
                v_mes_actual|| '/' || v_ano_actual);
     END IF;
     IF C_SAL_RUBROS%ISOPEN THEN
        CLOSE C_SAL_RUBROS;
     END IF;
   END;
   ----- FIN del proceso de los saldos de la oficina actual --------
 END LOOP;
 IF C_OFICINAS%rowcount = 0 THEN
    CLOSE C_OFICINAS;
    raise_application_error(-20000,'No existen saldos para generar. Verificar ');
 END IF;
 IF C_OFICINAS%isopen THEN
    CLOSE C_OFICINAS;
 END IF;
 -- Unificación de criterios de cálculo de saldos promedios con AS400.- JF 07/10/2011.-
 IF v_mes_anterior <> v_mes_actual THEN
    BEGIN
			-- Obtengo la cantidad de días del mes.
			SELECT TO_CHAR(LAST_DAY(v_fec_anterior),'DD') 
				INTO v_dia_mes 
				FROM dual;
			-- Actualizo la tabla cb_sal_promedios.
			UPDATE cb_sal_promedios cb
				 SET cb.can_dia_acumulado = v_dia_mes
			 WHERE cb.ano = v_ano_anterior
				 AND cb.mes = v_mes_anterior;				
		EXCEPTION
		  WHEN OTHERS THEN 
			   raise_application_error(-20000,' ERROR al actualizar el acumulado de dias del mes.');
	  END;
 ELSIF v_mes_anterior = v_mes_actual THEN
    BEGIN
			-- Obtengo la cantidad de días transcurridos del mes.
			SELECT TO_CHAR((v_fec_actual - 1),'DD')
				INTO v_dia_mes 
				FROM dual;
			-- Actualizo la tabla cb_sal_promedios.
			UPDATE cb_sal_promedios cb
				 SET cb.can_dia_acumulado = v_dia_mes
			 WHERE cb.ano = v_ano_actual
				 AND cb.mes = v_mes_actual;				
		EXCEPTION
		  WHEN OTHERS THEN 
			   raise_application_error(-20000,' ERROR al actualizar el acumulado de dias del mes.');
	  END;
 END IF;
 -- Requerimiento: CNFGHDBS-5.
 -- Fecha: 27/08/2015.
 -- Elimina/Inserta los registros en la tabla historica.
 -- Verifica que exista registro a ser insertados en el historico.
 BEGIN
    SELECT COUNT(1)
      INTO v_existe
      FROM cb_sal_promedios a
     WHERE a.ano = v_ano_anterior
       AND a.mes = v_mes_anterior;
 EXCEPTION
    WHEN OTHERS THEN
       v_existe := 0;
 END;
 -- Requerimiento: DYDMR-2715.
 -- Fecha: 28/12/2015.
 -- Ajustes por error generado en la simulación de Fin de Año 2015.
 -- Cual se realiza el Inicio del Primer Día habil del Año no debe acumular en el historico.
 IF v_mes_actual = 1 and v_fec_actual = pag_cal.FU_OBT_FEC_PRI_DIA_MES_HABIL(2) THEN
    v_existe := 0;
 END IF;
 --
 IF v_existe > 0 THEN    
    -- Obtengo la fecha a ser eliminada del historico. 
    v_fec_historico := v_fec_anterior - v_can_dias_his; 
    -- Elimina los registros del historico.
    delete cb_sal_promedios_dia a where a.fecha <= v_fec_historico;
    -- Inserta los registro del día actual;
    begin
       insert into cb_sal_promedios_dia select v_fec_anterior, t.* from cb_sal_promedios t where t.ano = v_ano_anterior and t.mes = v_mes_anterior;
    exception
       when dup_val_on_index then
          null;
       when others then
          raise_application_error(-20000,'Al Ins.CB_SAL_PROMEDIOS_DIA');
    end;
 END IF;
 
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    CLOSE C_OFICINAS;
    raise_application_error(-20000,' ERROR. No existen saldos para actualizar');
  WHEN OTHERS THEN
    CLOSE C_OFICINAS;
    raise_application_error(-20000,'Error en prb_gen_sal_anterior '||sqlerrm);
END;
/
