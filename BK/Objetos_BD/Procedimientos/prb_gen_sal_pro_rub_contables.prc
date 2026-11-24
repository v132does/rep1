CREATE OR REPLACE PROCEDURE IT.PRB_GEN_SAL_PRO_RUB_CONTABLES IS
  
  -- Variables Generales.
  v_cod_oficina        ba_oficinas.cod_oficina%type;
  v_des_oficina        ba_oficinas.descripcion%type;
  v_fec_actual         ge_calendarios.fec_actual%type         := pag_cal.fu_obt_fec_actual(2);
  v_ano_actual         cb_sal_promedios_tmp.ano%type          := to_char(v_fec_actual,'yyyy');
  v_mes_actual         cb_sal_promedios_tmp.mes%type          := to_char(v_fec_actual,'mm');
  v_cod_mon_fuerte     ge_par_generales.cod_mon_fuerte%type   := pag_gen.FU_OBT_MON_FUERTE;
  v_cot_mon_fuerte     ge_cotizaciones.val_conversion%type    := pag_gen.FU_OBT_COTIZACION(v_cod_mon_fuerte,v_fec_actual);
  v_sal_mon_local      cb_sal_promedios_tmp.tot_acu_mon_local%type;
  v_sal_equ_local      cb_sal_promedios_tmp.tot_acu_mon_local%type;
  v_sal_deu_equ_local  cb_sal_promedios_tmp.tot_acu_mon_local%type;
  v_sal_acr_equ_local  cb_sal_promedios_tmp.tot_acu_mon_local%type;
  v_sal_mon_rubro      cb_sal_promedios_tmp.tot_acumulado%type;
  v_sal_deu_mon_local  cb_sal_promedios_tmp.tot_acu_mon_local%type;
  v_sal_acr_mon_local  cb_sal_promedios_tmp.tot_acu_mon_local%type;
  v_sal_deu_mon_rubro  cb_sal_promedios_tmp.tot_acumulado%type;
  v_sal_acr_mon_rubro  cb_sal_promedios_tmp.tot_acumulado%type;
  v_cod_rubro          cb_rubros.cod_rubro%type;
  v_fec_anterior       ge_calendarios.fec_actual%type;
  v_fec_proxima        ge_calendarios.fec_actual%type;
  v_cod_moneda         ba_monedas.cod_moneda%type;
  v_dia_mes            cb_sal_promedios_tmp.can_dia_acumulado%type;
  v_dif_dias           NUMBER;
  v_diferencia         NUMBER;
  v_existe             NUMBER;
  v_msj                VARCHAR2(250);
  ---
  v_ult_fec_sal_promedio DATE;
  v_det_campos           VARCHAR2(4000);

  -- Cursores.
  CURSOR c_oficinas IS
     SELECT DISTINCT B.COD_OFICINA, B.DESCRIPCION
       FROM CB_SAL_OFICINAS A, BA_OFICINAS B
      WHERE A.COD_OFICINA = B.COD_OFICINA
        AND A.ANO = v_ano_actual
        AND A.MES = v_mes_actual;

  CURSOR c_sal_rubros IS
     SELECT COD_RUBRO,
            NVL(SAL_MON_LOC_ANT,0) + NVL(DEB_MON_LOCAL,0) - NVL(CRE_MON_LOCAL,0),
            NVL(DEB_MON_LOCAL,0),NVL(DEB_MON_RUBRO,0),
            NVL(CRE_MON_LOCAL,0),NVL(CRE_MON_RUBRO,0),
            NVL(SAL_MON_RUB_ANT,0) + NVL(DEB_MON_RUBRO,0) - NVL(CRE_MON_RUBRO,0),
            NVL(SAL_EQU_LOC_ANT,0) + NVL(DEB_EQU_LOCAL,0) - NVL(CRE_EQU_LOCAL,0),
            NVL(DEB_EQU_LOCAL,0),NVL(CRE_EQU_LOCAL,0)
       FROM CB_SAL_OFICINAS
      WHERE COD_OFICINA = v_cod_oficina
        AND ANO = v_ano_actual
        AND MES = v_mes_actual
        FOR UPDATE OF COD_RUBRO;
      
  -- Funciones Locales.
  FUNCTION lf_obt_mon_rubro(p_cod_rubro IN VARCHAR2)
  RETURN VARCHAR2 IS
     v_retorno VARCHAR2(5);
  BEGIN
     SELECT COD_MONEDA
       INTO v_retorno
       FROM CB_RUBROS
      WHERE COD_RUBRO = p_cod_rubro;
     RETURN v_retorno;
  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20000,'Error al leer moneda del Rubro '||SQLERRM);
  END;
  
  -- Procedimientos Locales.
  PROCEDURE lp_ins_sal_promedios(p_ano cb_sal_promedios_tmp.ano%type,
                                 p_mes cb_sal_promedios_tmp.mes%type) 
  IS
  BEGIN
     -- Inserto en la tabla cb_sal_promedios_tmp.
     INSERT INTO cb_sal_promedios_tmp(cod_oficina, cod_rubro, ano, mes, cod_moneda, tot_acumulado, tot_acu_mon_local, 
                                      tot_acu_mon_fuerte, tot_acu_debitos, tot_acu_creditos, tot_acu_deb_mon_local, 
                                      tot_acu_cre_mon_local, tot_acu_equ_local, tot_acu_deb_equ_local, tot_acu_cre_equ_local, 
                                      can_dia_acumulado)
          SELECT cb.cod_oficina, cb.cod_rubro, cb.ano, cb.mes, cb.cod_moneda, cb.tot_acumulado, cb.tot_acu_mon_local,
                 cb.tot_acu_mon_fuerte, cb.tot_acu_debitos, cb.tot_acu_creditos, cb.tot_acu_deb_mon_local, cb.tot_acu_cre_mon_local,
                 cb.tot_acu_equ_local, cb.tot_acu_deb_equ_loc, cb.tot_acu_cre_equ_loc, cb.can_dia_acumulado
            FROM cb_sal_promedios cb
           WHERE cb.ano = p_ano
             AND cb.mes = p_mes;
       
  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20000,' ERROR al insertar los saldos promedios del mes.'); 
  END;

-- Proceso Principal.
BEGIN

 -- Valida que no se haya corrido el proceso de depositos internos.
 SELECT COUNT(1)
   INTO v_existe
   FROM cb_asientos_det cb
  WHERE cb.fecha = v_fec_actual
    AND cb.referencia = 'DEP.INT';
   
 IF v_existe > 0 THEN
    return;
 END IF;

 -- Obtengo los datos para el calcular el promedio.
 sql_util.ejecute_dml('TRUNCATE TABLE CB_SAL_PROMEDIOS_TMP', v_msj);
 IF v_msj IS NOT NULL THEN
    raise_application_error(-20000, v_msj);
 END IF;
 -- Cargar fechas calendario del modulo contable.
 pag_cal.pr_obt_dat_calendar(2);
 v_fec_anterior := pag_cal.G_FEC_ANTERIOR;
 v_fec_proxima  := pag_cal.G_FEC_PROXIMA;
 v_mes_actual   := TO_CHAR(v_fec_actual, 'MM');
 v_ano_actual   := TO_CHAR(v_fec_actual, 'YYYY');
 /*
 || DYDMR-1 Balance de saldos medios DIC-12- URGENTE - SPI 1162
 || xpy0038 - 20/mayo/2014
 || días 30 y 31 de diciembre no deben registrarse asientos contables,
 || pero como se habilita el sistema (sin la marca de Feriado en el calendario),
 || al abrir y cerrar el módulo de contabilidad, se vuelve a promediar los saldos de los rubros,
 || triplicando el monto correspondiente al día 29
 */
 -- Si el mes de la fecha del sistema para el modulo 2 es diciembre,
 -- entonces se tomará la fecha del parámetro.
 if v_mes_actual = 12 then
    begin 
       v_det_campos := substr(fue_obt_det_campos('GE_CALENDARIOS',2, 'N'),1,10);
    exception
       when others then
          raise_application_error(-20000, 'Al obt.ULT_FEC_SAL_PROMEDIO:'||sqlerrm);
    end;
    if v_det_campos is null then
       raise_application_error(-20000, 'Parámetro ULT_FEC_SAL_PROMEDIO sin valor asignado.');
    end if;       
    -- Validar formato del parámetro DD/MM/YYYY.
    begin 
       select to_date(v_det_campos,'DD/MM/YYYY') into v_ult_fec_sal_promedio from dual;
    exception
       when others then
          raise_application_error(-20000, 'Al convertir ULT_FEC_SAL_PROMEDIO:'||sqlerrm);
    end;
    -- Validar que el año del parámetro sea el actual y que el mes del parámetro sea diciembre.
    if to_char(v_ult_fec_sal_promedio,'YYYY') <> v_ano_actual then
       raise_application_error(-20000, 'Parámetro ULT_FEC_SAL_PROMEDIO no posee año actual');
    end if;
    if to_char(v_ult_fec_sal_promedio,'MM') <> v_mes_actual then
       raise_application_error(-20000, 'Parámetro ULT_FEC_SAL_PROMEDIO no posee mes actual');
    end if;
    -- Si la fecha del sistema para el modulo 2 es mayor a la fecha del parámetro,
    -- no se procesará la generación de los saldos promedios.
    if v_fec_actual > v_ult_fec_sal_promedio then
       return;
    end if;
 end if;
 --> FIN DYDMR-1
 
 -- Diferencias de días.
 v_dif_dias     := v_fec_actual - v_fec_anterior;
 v_diferencia   := v_fec_proxima - v_fec_actual;
 IF v_diferencia > 1 AND v_fec_actual != pag_cal.G_ULT_DIA_MES_HABIL THEN
    v_dif_dias  := v_diferencia;    
 ELSIF v_diferencia > 1 AND v_fec_actual = pag_cal.G_ULT_DIA_MES_HABIL THEN
    v_dif_dias  := (LAST_DAY(v_fec_actual) + 1) - v_fec_actual;
 END IF;
 -- Obtengo los saldos promedios de las cuentas.
 lp_ins_sal_promedios(v_ano_actual, v_mes_actual);
 
 -- Calculo de los promedios de la fecha actual.
 IF c_oficinas%ISOPEN THEN
    CLOSE c_oficinas;
 END IF;
 OPEN c_oficinas;
 LOOP
   FETCH c_oficinas INTO v_cod_oficina, v_des_oficina;
   EXIT WHEN c_oficinas%NOTFOUND;
   -- Proceso que actualiza los saldos de las cuentas de la oficina.
   BEGIN
     IF c_sal_rubros%ISOPEN THEN
        CLOSE c_sal_rubros;
     END IF;
     OPEN c_sal_rubros;
     LOOP
        FETCH c_sal_rubros INTO v_cod_rubro, v_sal_mon_local, v_sal_deu_mon_local, v_sal_deu_mon_rubro,
                                v_sal_acr_mon_local, v_sal_acr_mon_rubro, v_sal_mon_rubro,
                                v_sal_equ_local, v_sal_deu_equ_local, v_sal_acr_equ_local;
        EXIT WHEN c_sal_rubros%NOTFOUND;
        
        -- 
        UPDATE CB_SAL_PROMEDIOS_TMP
           SET TOT_ACU_MON_LOCAL     = NVL(TOT_ACU_MON_LOCAL,0) + v_sal_mon_local * v_dif_dias,
               TOT_ACUMULADO         = NVL(TOT_ACUMULADO,0) + v_sal_mon_rubro * v_dif_dias,
               CAN_DIA_ACUMULADO     = NVL(CAN_DIA_ACUMULADO,0) + v_dif_dias,
               TOT_ACU_MON_FUERTE    = NVL(TOT_ACU_MON_FUERTE,0) + ((v_sal_mon_local * v_dif_dias)/v_cot_mon_fuerte),
               TOT_ACU_DEB_MON_LOCAL = NVL(TOT_ACU_DEB_MON_LOCAL,0) + v_sal_deu_mon_local,
               TOT_ACU_CRE_MON_LOCAL = NVL(TOT_ACU_CRE_MON_LOCAL,0) + v_sal_acr_mon_local,
               TOT_ACU_DEBITOS       = NVL(TOT_ACU_DEBITOS,0) + v_sal_deu_mon_rubro,
               TOT_ACU_CREDITOS      = NVL(TOT_ACU_CREDITOS,0) + v_sal_acr_mon_rubro,
               TOT_ACU_EQU_LOCAL     = NVL(TOT_ACU_EQU_LOCAL,0) + v_sal_equ_local * v_dif_dias,
               TOT_ACU_DEB_EQU_LOCAL = NVL(TOT_ACU_DEB_EQU_LOCAL,0) + v_sal_deu_equ_local,
               TOT_ACU_CRE_EQU_LOCAL = NVL(TOT_ACU_CRE_EQU_LOCAL,0) + v_sal_acr_equ_local
         WHERE COD_OFICINA = v_cod_oficina
           AND COD_RUBRO = v_cod_rubro
           AND ANO = v_ano_actual
           AND MES = v_mes_actual;
        
        -- Si no encontro genera un nuevo registro para la cuenta - oficina.
        IF SQL%NOTFOUND THEN
           v_cod_moneda := lf_obt_mon_rubro(v_cod_rubro);
           INSERT INTO CB_SAL_PROMEDIOS_TMP(COD_OFICINA, COD_RUBRO, ANO, MES, COD_MONEDA, TOT_ACU_MON_LOCAL, 
                                            TOT_ACUMULADO, CAN_DIA_ACUMULADO, TOT_ACU_MON_FUERTE, TOT_ACU_DEB_MON_LOCAL, 
                                            TOT_ACU_CRE_MON_LOCAL, TOT_ACU_DEBITOS, TOT_ACU_CREDITOS,TOT_ACU_EQU_LOCAL,
                                            TOT_ACU_DEB_EQU_LOCAL,TOT_ACU_CRE_EQU_LOCAL)
                 VALUES
                       (v_cod_oficina, v_cod_rubro, v_ano_actual, v_mes_actual, v_cod_moneda, v_sal_mon_local * v_dif_dias, 
                        v_sal_mon_rubro * v_dif_dias, v_dif_dias, (v_sal_mon_local * v_dif_dias)/v_cot_mon_fuerte,
                        v_sal_deu_mon_local,v_sal_acr_mon_local,v_sal_deu_mon_rubro,v_sal_acr_mon_rubro, v_sal_equ_local, 
                        v_sal_deu_equ_local, v_sal_acr_equ_local);
        END IF;
     END LOOP;
     --
     IF C_SAL_RUBROS%ROWCOUNT = 0 THEN
        CLOSE C_SAL_RUBROS;
           raise_application_error(-20000,' ERROR. No se encontraron registros del mes ' ||v_mes_actual|| '/' || v_ano_actual);
     END IF;
     IF C_SAL_RUBROS%ISOPEN THEN
        CLOSE C_SAL_RUBROS;
     END IF;
   END;   
 END LOOP;
 IF C_OFICINAS%rowcount = 0 THEN
    CLOSE C_OFICINAS;
       raise_application_error(-20000,'No existen saldos para generar. Verificar ');
 END IF;
 IF C_OFICINAS%isopen THEN
    CLOSE C_OFICINAS;
 END IF;
 -- Actualizo la cantida de días acumulado.
 BEGIN
    IF v_fec_actual = pag_cal.G_ULT_DIA_MES_HABIL THEN
       BEGIN
          -- Obtengo la cantidad de días del mes.
   	      SELECT TO_CHAR(LAST_DAY(v_fec_actual),'DD') 
			      INTO v_dia_mes 
		        FROM dual;
			    -- Actualizo la tabla cb_sal_promedios_tmp.
		      UPDATE cb_sal_promedios_tmp cb
			       SET cb.can_dia_acumulado = v_dia_mes
		       WHERE cb.ano = v_ano_actual
			       AND cb.mes = v_mes_actual;				
       EXCEPTION
		      WHEN OTHERS THEN 
			       raise_application_error(-20000,' ERROR al actualizar el acumulado del mes.');
	     END;    
    ELSE
       BEGIN
			    -- Obtengo la cantidad de días transcurridos del mes.
   	      SELECT TO_CHAR((v_fec_proxima - 1),'DD')
				    INTO v_dia_mes 
				    FROM dual;
			    -- Actualizo la tabla cb_sal_promedios_tmp.
			    UPDATE cb_sal_promedios_tmp cb
			       SET cb.can_dia_acumulado = v_dia_mes
		       WHERE cb.ano = v_ano_actual
			       AND cb.mes = v_mes_actual;					
		   EXCEPTION
		      WHEN OTHERS THEN 
			       raise_application_error(-20000,' ERROR al actualizar el acumulado de dias transcurridos del mes.');
	     END;    
    END IF;
 EXCEPTION
    WHEN OTHERS THEN 
		   raise_application_error(-20000,' ERROR al actualizar el acumulado de dias del mes.');
 END;
--
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    CLOSE C_OFICINAS;
    raise_application_error(-20000,' ERROR. No existen saldos para actualizar');
  WHEN OTHERS THEN
    CLOSE C_OFICINAS;
    raise_application_error(-20000,'Error en PRB_GEN_SAL_PRO_RUB_CONTABLES '||sqlerrm);
END;
/

