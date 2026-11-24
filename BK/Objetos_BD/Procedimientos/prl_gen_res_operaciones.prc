CREATE OR REPLACE PROCEDURE IT.PRL_GEN_RES_OPERACIONES
 IS

/* Genera resultado del efectivo */
PROCEDURE LP_GEN_EFECTIVO;
PROCEDURE LP_GEN_NO_EFECTIVO;
PROCEDURE LP_COT_CAL_EFECTIVO;
PROCEDURE LP_COT_CAL_NEF;
--- OBS: Segundo Proceso del cierre de Cambios
   v_fec_actual  ge_calendarios.fec_actual%type;
   v_error       varchar2(250);
   v_redondeo_ml number(5);

/* Genera resultado del efectivo */
PROCEDURE LP_GEN_EFECTIVO
 IS
-------------------------- VARIABLES DEL CURSOR -----------------------
   WE_CDMONED                ba_monedas.cod_moneda%type;
   WE_CDMONEQ                NUMBER(03);
   WE_CDOFCAM                ba_oficinas.cod_oficina%type;
   WW_CDMONED                ba_monedas.cod_moneda%type;
   WW_CDMONEQ                NUMBER(03);
   WW_CDOFCAM                ba_oficinas.cod_oficina%type;
   WE_POSANSU                NUMBER(16,2) := 0;
   WE_POSANRE                NUMBER(16,2) := 0;
   WE_POSANTE                NUMBER(16,2) := 0;
   WE_ANTSCME                NUMBER(16,2) := 0;
   WE_ANTSVME                NUMBER(16,2) := 0;
   WE_OPECOME                NUMBER(16,2) := 0;
   WE_OPECOTP                NUMBER(14,4) := 0;
   WE_OPECOGS                NUMBER(16,2) := 0;
   WE_OPEVEME                NUMBER(16,2) := 0;
   WE_OPEVETP                NUMBER(14,4) := 0;
   WE_OPEVEGS                NUMBER(16,2) := 0;
   WE_POSACTU                NUMBER(16,2) := 0;
   WE_POSCOME                NUMBER(16,2) := 0;
   WE_POSVEME                NUMBER(16,2) := 0;
   ----------------------- CURSOR SUMA PARA EFECTIVO ----------------------
   CURSOR EFECTIVO IS
   SELECT COD_OFICINA,s.COD_MONEDA,COD_NUMERICO,MTO_POS_COM_EFE_ANT,MTO_POS_VTA_EFE_ANT
     FROM LC_SAL_DIARIOS s,BA_MONEDAS m
    WHERE s.COD_MONEDA = m.COD_MONEDA;
------------------------ COMIENZO DEL PROCESO --------------------------
BEGIN
   IF EFECTIVO%ISOPEN THEN
      CLOSE EFECTIVO;
   END IF;
   ------------------------ APERTURA DEL CURSOR ---------------------------
   OPEN EFECTIVO;
   LOOP
      FETCH EFECTIVO INTO WE_CDOFCAM,WE_CDMONED,WE_CDMONEQ,
                          WE_POSANSU,WE_POSANRE;
      EXIT WHEN EFECTIVO%NOTFOUND;
      BEGIN
         SELECT COD_OFI_CAMBIO,m.COD_MONEDA,m.COD_NUMERICO,
                SUM(NVL(MTO_COM_EFE_ACT,0) + NVL(MTO_ARB_COM_EFE_ACT,0) +
                    NVL(MTO_CJE_COM_EFE_ACT,0)),
                SUM(NVL(MTO_COM_EFE_LOC,0)),
                SUM(NVL(MTO_VTA_EFE_ACT,0) + NVL(MTO_ARB_VTA_EFE_ACT,0) +
                    NVL(MTO_CJE_VTA_EFE_ACT,0)),
                SUM(NVL(MTO_VTA_EFE_LOC,0))
           INTO WW_CDOFCAM,WW_CDMONED,WW_CDMONEQ,WE_OPECOME,WE_OPECOGS,
                WE_OPEVEME,WE_OPEVEGS
           FROM LC_POSICIONES p,BA_MONEDAS m
          WHERE p.COD_MONEDA = m.COD_MONEDA
            AND m.COD_MONEDA = WE_CDMONED
            AND p.COD_OFI_CAMBIO = WE_CDOFCAM
          GROUP BY p.COD_OFI_CAMBIO,m.COD_MONEDA,m.COD_NUMERICO;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            WE_OPECOME := 0;
            WE_OPECOGS := 0;
            WE_OPEVEME := 0;
            WE_OPEVEGS := 0;
         WHEN TOO_MANY_ROWS THEN
            raise_application_error(-20000,
            'Muchos registros en LC_POSICIONES y BA_MONEDAS');
      END;
      WE_POSANTE := NVL(WE_POSANSU,0) - NVL(WE_POSANRE,0);
      IF WE_POSANTE > 0 THEN
         WE_ANTSCME := WE_POSANTE;
      ELSE
         WE_ANTSCME := 0;
      END IF;
      IF WE_POSANTE < 0 THEN
         WE_ANTSVME := WE_POSANTE * -1;
      ELSE
         WE_ANTSVME := 0;
      END IF;
      IF  NVL(WE_OPECOME,0) = 0 THEN
          WE_OPECOTP := WE_OPECOGS;
      ELSE
          WE_OPECOTP := WE_OPECOGS / WE_OPECOME;
      END IF;
      IF  NVL(WE_OPEVEME,0) = 0 THEN
          WE_OPEVETP := WE_OPEVEGS;
      ELSE
          WE_OPEVETP := WE_OPEVEGS / WE_OPEVEME;
      END IF;
      WE_POSACTU := WE_POSANTE + WE_OPECOME - WE_OPEVEME;
      IF WE_POSACTU > 0 THEN
         WE_POSCOME := WE_POSACTU;
      ELSE
         WE_POSCOME := 0;
      END IF;
      IF WE_POSACTU < 0 THEN
         WE_POSVEME := WE_POSACTU * -1;
      ELSE
         WE_POSVEME := 0;
      END IF;
      INSERT INTO LC_RES_OPERACIONES(COD_OFI_CAMBIO,COD_MODULO,COD_MONEDA,TIP_MONEDA,
                           COD_MON_NUMERICO,MTO_POS_ANTERIOR,
                           MTO_SOB_COM_ANT,MTO_SOB_VTA_ANT,MTO_COMPRA,COT_COMPRA,
                           MTO_COM_LOCAL,MTO_VENTA,COT_VENTA,MTO_VTA_LOCAL,
                           MTO_POS_ACTUAL,MTO_POS_COMPRA,MTO_POS_VENTA)
                    VALUES(WE_CDOFCAM,7,WE_CDMONED,
                           RPAD(WE_CDMONED,3,' ')||' E',
                           WE_CDMONEQ,WE_POSANTE,
                           WE_ANTSCME,WE_ANTSVME,WE_OPECOME,WE_OPECOTP,
                           WE_OPECOGS,WE_OPEVEME,WE_OPEVETP,WE_OPEVEGS,
                           WE_POSACTU,WE_POSCOME,WE_POSVEME);
      WE_OPECOME := 0;
      WE_OPECOTP := 0;
      WE_OPECOGS := 0;
      WE_OPEVEME := 0;
      WE_OPEVETP := 0;
      WE_OPEVEGS := 0;
      WE_POSACTU := 0;
      WE_POSCOME := 0;
      WE_POSVEME := 0;
      WE_ANTSCME := 0;
      WE_ANTSVME := 0;
      WE_POSANTE := 0;
   END LOOP;
   CLOSE EFECTIVO;
END;
PROCEDURE LP_GEN_NO_EFECTIVO
 IS
-------------------------- VARIABLES DEL CURSOR -----------------------
   WE_CDMONED                ba_monedas.cod_moneda%type;
   WE_CDMONEQ                NUMBER(03);
   WE_CDOFCAM                ba_oficinas.cod_oficina%type;
   WW_CDMONED                ba_monedas.cod_moneda%type;
   WW_CDMONEQ                NUMBER(03);
   WW_CDOFCAM                ba_oficinas.cod_oficina%type;
   WE_POSANSU                NUMBER(16,2) := 0;
   WE_POSANRE                NUMBER(16,2) := 0;
   WE_POSANTE                NUMBER(16,2) := 0;
   WE_ANTSCME                NUMBER(16,2) := 0;
   WE_ANTSVME                NUMBER(16,2) := 0;
   WE_OPECOME                NUMBER(16,2) := 0;
   WE_OPECOTP                NUMBER(14,4) := 0;
   WE_OPECOGS                NUMBER(16,2) := 0;
   WE_OPEVEME                NUMBER(16,2) := 0;
   WE_OPEVETP                NUMBER(14,4) := 0;
   WE_OPEVEGS                NUMBER(16,2) := 0;
   WE_POSACTU                NUMBER(16,2) := 0;
   WE_POSCOME                NUMBER(16,2) := 0;
   WE_POSVEME                NUMBER(16,2) := 0;
   ----------------------- CURSOR SUMA PARA EFECTIVO ----------------------
   CURSOR NOEFECTIVO IS
   SELECT d.COD_OFICINA,d.COD_MONEDA,COD_NUMERICO,MTO_POS_COM_NEF_ANT,MTO_POS_VTA_NEF_ANT
     FROM LC_SAL_DIARIOS d,BA_MONEDAS m
    WHERE d.COD_MONEDA = m.COD_MONEDA;

------------------------ COMIENZO DEL PROCESO --------------------------
BEGIN
   IF NOEFECTIVO%ISOPEN THEN
      CLOSE NOEFECTIVO;
   END IF;
   ------------------------ APERTURA DEL CURSOR ---------------------------
   OPEN NOEFECTIVO;
   LOOP
      FETCH NOEFECTIVO INTO WE_CDOFCAM,WE_CDMONED,WE_CDMONEQ,
                          WE_POSANSU,WE_POSANRE;
      EXIT WHEN NOEFECTIVO%NOTFOUND;
      BEGIN
         SELECT COD_OFI_CAMBIO,m.COD_MONEDA,m.COD_NUMERICO,
                        SUM(NVL(MTO_COM_NEF_ACT,0) + NVL(MTO_ARB_COM_NEF_ACT,0) +
                            NVL(MTO_CJE_COM_NEF_ACT,0)),
                        SUM(NVL(MTO_COM_NEF_LOC,0)),
                        SUM(NVL(MTO_VTA_NEF_ACT,0) + NVL(MTO_ARB_VTA_NEF_ACT,0) +
                            NVL(MTO_CJE_VTA_NEF_ACT,0)),
                        SUM(NVL(MTO_VTA_NEF_LOC,0))
           INTO WW_CDOFCAM,WW_CDMONED,WW_CDMONEQ,
                WE_OPECOME, WE_OPECOGS,WE_OPEVEME,WE_OPEVEGS
           FROM LC_POSICIONES p,BA_MONEDAS m
          WHERE p.COD_MONEDA = m.COD_MONEDA
            AND m.COD_MONEDA = WE_CDMONED
            AND p.COD_OFI_CAMBIO = WE_CDOFCAM
          GROUP BY p.COD_OFI_CAMBIO,M.COD_MONEDA,m.COD_NUMERICO;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            WE_OPECOME := 0;
            WE_OPECOGS := 0;
            WE_OPEVEME := 0;
            WE_OPEVEGS := 0;
      END;
      WE_POSANTE := NVL(WE_POSANSU,0) - NVL(WE_POSANRE,0);
      IF WE_POSANTE > 0 THEN
         WE_ANTSCME := WE_POSANTE;
      ELSE
         WE_ANTSCME := 0;
      END IF;
      IF WE_POSANTE < 0 THEN
         WE_ANTSVME := WE_POSANTE * -1;
      ELSE
         WE_ANTSVME := 0;
      END IF;
      IF NVL(WE_OPECOME,0) = 0 THEN
         WE_OPECOTP := WE_OPECOGS;
      ELSE
         WE_OPECOTP := WE_OPECOGS / WE_OPECOME;
      END IF;
      IF NVL(WE_OPEVEME,0) = 0 THEN
         WE_OPEVETP := WE_OPEVEGS;
      ELSE
         WE_OPEVETP := WE_OPEVEGS / WE_OPEVEME;
      END IF;
      WE_POSACTU := WE_POSANTE + WE_OPECOME - WE_OPEVEME;
      IF WE_POSACTU > 0 THEN
         WE_POSCOME := WE_POSACTU;
      ELSE
         WE_POSCOME := 0;
      END IF;
      IF WE_POSACTU < 0 THEN
         WE_POSVEME := WE_POSACTU * -1;
      ELSE
         WE_POSVEME := 0;
      END IF;
      INSERT INTO LC_RES_OPERACIONES(COD_OFI_CAMBIO,COD_MODULO,COD_MONEDA,TIP_MONEDA,
                           COD_MON_NUMERICO,MTO_POS_ANTERIOR,
                           MTO_SOB_COM_ANT,MTO_SOB_VTA_ANT,MTO_COMPRA,COT_COMPRA,
                           MTO_COM_LOCAL,MTO_VENTA,COT_VENTA,MTO_VTA_LOCAL,
                           MTO_POS_ACTUAL,MTO_POS_COMPRA,MTO_POS_VENTA)
                    VALUES(WE_CDOFCAM,7,WE_CDMONED,
                           RPAD(WE_CDMONED,3,' ')||' N',
                           WE_CDMONEQ,WE_POSANTE,
                           WE_ANTSCME,WE_ANTSVME,WE_OPECOME,WE_OPECOTP,
                           WE_OPECOGS,WE_OPEVEME,WE_OPEVETP,WE_OPEVEGS,
                           WE_POSACTU,WE_POSCOME,WE_POSVEME);
      WE_OPECOME := 0;
      WE_OPECOTP := 0;
      WE_OPECOGS := 0;
      WE_OPEVEME := 0;
      WE_OPEVETP := 0;
      WE_OPEVEGS := 0;
      WE_POSACTU := 0;
      WE_POSCOME := 0;
      WE_POSVEME := 0;
      WE_ANTSCME := 0;
      WE_ANTSVME := 0;
      WE_POSANTE := 0;
   END LOOP;
   CLOSE NOEFECTIVO;
END;
PROCEDURE LP_COT_CAL_EFECTIVO
 IS
--------------------- DEFINICION DE VARIABLE AUXILIAR ------------------
   WK_CDMONED             ba_monedas.cod_moneda%type;
   WK_CDOFICI             ba_oficinas.cod_oficina%type;
   ----------------- DEFINICION DE CURSOR PARA ACTUALIZACION --------------
   CURSOR COTIZAC IS
   SELECT COD_MONEDA,COD_OFI_CAMBIO
     FROM LC_RES_OPERACIONES
    WHERE COD_MODULO = 7
      AND SUBSTR(TIP_MONEDA,5,1) = 'E'
      FOR UPDATE OF COD_MONEDA;
------------------------- LOOP DE ACTUALIZACION ------------------------
BEGIN
   IF COTIZAC%ISOPEN THEN
      CLOSE COTIZAC;
   END IF;
   OPEN COTIZAC;
   LOOP
      FETCH COTIZAC INTO WK_CDMONED,WK_CDOFICI;
      EXIT WHEN COTIZAC%NOTFOUND;
      ---------------------- ACTUALIZACION COTIZACION ANTERIOR y actual-------
      UPDATE LC_RES_OPERACIONES SET
        COT_ANTERIOR =  fug_obt_cotizacion(WK_CDMONED,v_fec_actual-1),
        COT_ACTUAL = fug_obt_cotizacion(WK_CDMONED,v_fec_actual)
      WHERE CURRENT OF COTIZAC;
      ------------ ACTUALIZACION ANTERIOR, POS. NETA ACTUAL GS ---------------
      UPDATE LC_RES_OPERACIONES SET
          MTO_SOB_COM_LOC_ANT = ROUND(NVL(MTO_SOB_COM_ANT * COT_ANTERIOR,0),v_redondeo_ml),
          MTO_SOB_VTA_LOC_ANT = ROUND(NVL(MTO_SOB_VTA_ANT * COT_ANTERIOR,0),v_redondeo_ml),
          MTO_POS_COM_NETO    = ROUND(NVL(MTO_POS_COMPRA * COT_ACTUAL,0),v_redondeo_ml),
          MTO_POS_VTA_NETO    = ROUND(NVL(MTO_POS_VENTA * COT_ACTUAL,0),v_redondeo_ml)
      WHERE CURRENT OF COTIZAC;
      ------------------- ACTUALIZACION RESULTADO DEL DIA --------------------
      UPDATE LC_RES_OPERACIONES SET
          MTO_POS_DIA_REAL =
           ROUND(((NVL(MTO_COM_LOCAL,0) - NVL(MTO_VTA_LOCAL,0) + NVL(MTO_SOB_COM_LOC_ANT,0) -
             NVL(MTO_SOB_VTA_LOC_ANT,0)) -
           ROUND(((NVL(MTO_POS_COMPRA,0) - NVL(MTO_POS_VENTA,0)) * NVL(COT_ACTUAL,0)),v_redondeo_ml)),v_redondeo_ml)
      WHERE CURRENT OF COTIZAC;
   END LOOP;
   CLOSE COTIZAC;
END;
PROCEDURE LP_COT_CAL_NEF
 IS
--------------------- DEFINICION DE VARIABLE AUXILIAR ------------------
   WK_CDMONED             ba_monedas.cod_moneda%type;
   WK_CDOFICI             ba_oficinas.cod_oficina%type;
   v_error                varchar2(100);
   ----------------- DEFINICION DE CURSOR PARA ACTUALIZACION --------------
   CURSOR COTIZAC IS
   SELECT COD_MONEDA,COD_OFI_CAMBIO
     FROM LC_RES_OPERACIONES
    WHERE COD_MODULO = 7
      AND SUBSTR(TIP_MONEDA,5,1) = 'N'
      FOR UPDATE OF COD_MONEDA;
   ------------------------- LOOP DE ACTUALIZACION ------------------------
BEGIN
   IF COTIZAC%ISOPEN THEN
      CLOSE COTIZAC;
   END IF;
   OPEN COTIZAC;
   LOOP
      FETCH COTIZAC INTO WK_CDMONED,WK_CDOFICI;
      EXIT WHEN COTIZAC%NOTFOUND;
      ---------------------- ACTUALIZACION COTIZACION ANTERIOR Y ACTUAL-------
      v_ERROR := 'COT.ANT.';
      UPDATE LC_RES_OPERACIONES SET
            COT_ANTERIOR = fug_obt_cotizacion(wk_cdmoned, v_fec_actual-1),
            COT_ACTUAL   = fug_obt_cotizacion(wk_cdmoned, v_fec_actual)
      WHERE CURRENT OF COTIZAC;
      ------------ ACTUALIZACION ANTERIOR, POS. NETA ACTUAL GS ---------------
      v_ERROR := 'ACT.ANT.';
      UPDATE LC_RES_OPERACIONES SET
          MTO_SOB_COM_LOC_ANT = ROUND(NVL(MTO_SOB_COM_ANT * COT_ANTERIOR,0),v_redondeo_ml),
          MTO_SOB_VTA_LOC_ANT = ROUND(NVL(MTO_SOB_VTA_ANT * COT_ANTERIOR,0),v_redondeo_ml),
          MTO_POS_COM_NETO    = ROUND(NVL(MTO_POS_COMPRA * COT_ACTUAL,0),v_redondeo_ml),
          MTO_POS_VTA_NETO    = ROUND(NVL(MTO_POS_VENTA * COT_ACTUAL,0),v_redondeo_ml)
      WHERE CURRENT OF COTIZAC;
      ------------------- ACTUALIZACION RESULTADO DEL DIA --------------------
      v_ERROR := 'ACT.RES.DIA';
      UPDATE LC_RES_OPERACIONES SET
          MTO_POS_DIA_REAL =
           ROUND(((NVL(MTO_COM_LOCAL,0) - NVL(MTO_VTA_LOCAL,0) + NVL(MTO_SOB_COM_LOC_ANT,0) -
             NVL(MTO_SOB_VTA_LOC_ANT,0)) -
           ROUND(((NVL(MTO_POS_COMPRA,0) - NVL(MTO_POS_VENTA,0)) * NVL(COT_ACTUAL,0)),v_redondeo_ml)),v_redondeo_ml)
      WHERE CURRENT OF COTIZAC;
   END LOOP;
   CLOSE COTIZAC;
   EXCEPTION
      WHEN OTHERS THEN
         raise_application_error(-20000,v_error||' '||sqlerrm);
END;
BEGIN
   --- Recuperar fecha del modulo
   v_fec_actual  := pag_cal.fu_obt_fec_actual(7);
   v_redondeo_ml := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,71,pag_gen.FU_OBT_MON_LOCAL);
   --- Eliminar tabla de saldos de posiciones
   
   --sql_util.ejecute_dml('truncate table LC_RES_OPERACIONES', v_error);
   -- Se reemplaza porque hace commit implicito y no puede reprocesarse
   delete LC_RES_OPERACIONES;
   --
   if v_error is not null then
      raise_application_error(-20000,
      'Elimina LC_RES_OPERACIONES '||v_error);
   end if;
   lp_gen_efectivo;
   lp_gen_no_efectivo;
   lp_cot_cal_nef;
   lp_cot_cal_efectivo;
END;
/

