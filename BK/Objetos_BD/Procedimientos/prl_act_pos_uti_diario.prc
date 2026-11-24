CREATE OR REPLACE PROCEDURE IT.PRL_ACT_POS_UTI_DIARIO
 IS

/* Transfiere monedas */
PROCEDURE LP_TRA_MON_EXT;
/* Transfiere moneda local. */
PROCEDURE LP_TRA_MON_LOCAL;
--- OBS: Cuarto Proceso del cierre de Cambios
--- Actualizacion de utilidad y posicion del dia
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;

/* Transfiere monedas */
PROCEDURE LP_TRA_MON_EXT
 IS
CURSOR MONEDA IS
   SELECT COD_MONEDA, COD_OFICINA
     FROM LC_SAL_DIARIOS
     FOR UPDATE OF COD_MONEDA;
   ------------------------------------------------------------------
   W_CDMONED BA_MONEDAS.COD_MONEDA%TYPE;
   W_CDOFICI NUMBER;
   W_POSCOME LC_RES_OPERACIONES.MTO_POS_COMPRA%TYPE;
   W_POSVEME LC_RES_OPERACIONES.MTO_POS_VENTA%TYPE;
   W_POSREDI LC_RES_OPERACIONES.MTO_POS_DIA_REAL%TYPE;
   ------------------------------------------------------------------
BEGIN
   -------------------------------------------------------------
   UPDATE LC_SAL_DIARIOS
      SET MTO_UTI_EFE_REAL    = 0, MTO_UTI_EFE_NETA    = 0,
          MTO_POS_COM_EFE_ANT = 0, MTO_POS_VTA_EFE_ANT = 0,
          MTO_UTI_NEF_REAL    = 0, MTO_UTI_NEF_NETA    = 0,
          MTO_POS_COM_NEF_ANT = 0, MTO_POS_VTA_NEF_ANT = 0,
          MTO_POS_COM_EFE_LOC = 0, MTO_POS_COM_NEF_LOC = 0,
          MTO_POS_VTA_EFE_LOC = 0, MTO_POS_VTA_NEF_LOC = 0;
   -------------------------------------------------------------
   IF MONEDA%ISOPEN THEN
      CLOSE MONEDA;
   END IF;
   OPEN MONEDA;
   LOOP
      FETCH MONEDA INTO W_CDMONED, W_CDOFICI;
      EXIT WHEN MONEDA%NOTFOUND;
      BEGIN
         SELECT MTO_POS_COMPRA,MTO_POS_VENTA,MTO_POS_DIA_REAL
           INTO W_POSCOME, W_POSVEME, W_POSREDI
           FROM LC_RES_OPERACIONES
          WHERE LC_RES_OPERACIONES.COD_MONEDA = W_CDMONED
            AND LC_RES_OPERACIONES.COD_OFI_CAMBIO = W_CDOFICI
            AND SUBSTR(LC_RES_OPERACIONES.TIP_MONEDA,5,1) = 'E';
         -------------------------------------------------------------
         UPDATE LC_SAL_DIARIOS
            SET MTO_UTI_EFE_REAL    = W_POSREDI * -1,
                MTO_UTI_EFE_NETA    = W_POSREDI * -1,
                MTO_POS_COM_EFE_ANT = W_POSCOME,
                MTO_POS_VTA_EFE_ANT = W_POSVEME
          WHERE CURRENT OF MONEDA;
          -------------------------------------------------------------
      EXCEPTION
         WHEN OTHERS THEN NULL;
      END;
      -------------------------------------------------------------
      BEGIN
         SELECT MTO_POS_COMPRA,MTO_POS_VENTA,MTO_POS_DIA_REAL
           INTO  W_POSCOME, W_POSVEME, W_POSREDI
           FROM LC_RES_OPERACIONES
          WHERE LC_RES_OPERACIONES.COD_MONEDA = W_CDMONED
            AND LC_RES_OPERACIONES.COD_OFI_CAMBIO = W_CDOFICI
            AND SUBSTR(LC_RES_OPERACIONES.TIP_MONEDA,5,1) = 'N';
         -------------------------------------------------------------
         UPDATE LC_SAL_DIARIOS
            SET MTO_UTI_NEF_REAL    = W_POSREDI * -1,
                MTO_UTI_NEF_NETA    = W_POSREDI * -1,
                MTO_POS_COM_NEF_ANT = W_POSCOME,
                MTO_POS_VTA_NEF_ANT = W_POSVEME
          WHERE CURRENT OF MONEDA;
         -------------------------------------------------------------
      EXCEPTION
         WHEN OTHERS THEN NULL;
      END;
   END LOOP;
   --IF MONEDA%ROWCOUNT = 0 THEN
   --  raise_application_error(-20000,'No existen datos a procesar.');
   --END IF;
   IF MONEDA%ISOPEN THEN
      CLOSE MONEDA;
   END IF;
END;
/* Transfiere moneda local. */
PROCEDURE LP_TRA_MON_LOCAL
 IS
CURSOR MONEDA IS
   SELECT COD_OFICINA
     FROM LC_SAL_DIARIOS
    WHERE COD_MONEDA = v_cod_mon_local
      FOR UPDATE OF COD_OFICINA;
   ------------------------------------------------------------------
   W_CDMONED BA_MONEDAS.COD_MONEDA%TYPE;
   W_CDOFICI NUMBER;
   W_OPECOGS LC_RES_OPERACIONES.MTO_COM_LOCAL%TYPE;
   W_OPEVEGS LC_RES_OPERACIONES.MTO_VTA_LOCAL%TYPE;
   W_POSREDI LC_RES_OPERACIONES.MTO_POS_DIA_REAL%TYPE;
   ------------------------------------------------------------------
BEGIN
   -------------------------------------------------------------
   IF MONEDA%ISOPEN THEN
      CLOSE MONEDA;
   END IF;
   OPEN MONEDA;
   LOOP
      FETCH MONEDA INTO W_CDOFICI;
      EXIT WHEN MONEDA%NOTFOUND;
      BEGIN
         SELECT SUM(MTO_COM_LOCAL)-SUM(MTO_VTA_LOCAL)+SUM(MTO_POS_DIA_REAL* -1)
           INTO W_OPECOGS
           FROM LC_RES_OPERACIONES
          WHERE LC_RES_OPERACIONES.COD_OFI_CAMBIO = W_CDOFICI;
         -------------------------------------------------------------
         UPDATE LC_SAL_DIARIOS
            SET MTO_UTI_EFE_REAL = W_OPECOGS,
                MTO_UTI_EFE_NETA = W_OPECOGS
          WHERE CURRENT OF MONEDA;
         -------------------------------------------------------------
      EXCEPTION
         WHEN OTHERS THEN NULL;
      END;
      -------------------------------------------------------------
   END LOOP;
   --IF MONEDA%ROWCOUNT = 0 THEN
   --   raise_application_error(-20000,'No existen datos a procesar.');
   --END IF;
   IF MONEDA%ISOPEN THEN
      CLOSE MONEDA;
   END IF;
END;
BEGIN
   --- Recuperar fecha del modulo
   v_fec_actual    := pag_cal.fu_obt_fec_actual(7);
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   lp_tra_mon_ext;
   lp_tra_mon_local;
END;
/

